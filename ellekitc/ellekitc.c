
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

#if __arm64e__
#include <ptrauth.h>
#endif

#include <mach/message.h>
#include <mach/vm_region.h>
#include <mach/vm_map.h>
#include <mach/mach.h>
#include <stdbool.h>
#include <libkern/OSCacheControl.h>

#include "include/mach.h"

// MARK: - PAC

void* sign_pointer(void* ptr) {
#if __has_feature(ptrauth_calls)
    return ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
#else
    return ptr;
#endif
}

void* sign_pc(void* ptr) {
#if __has_feature(ptrauth_calls)
    return ptrauth_sign_unauthenticated(ptr, ptrauth_key_process_independent_code, 0x7481);
#else
    return ptr;
#endif
}

void* strip_pointer(void* ptr) {
#if __has_feature(ptrauth_calls)
    return ptrauth_strip(ptr, ptrauth_key_function_pointer);
#else
    return ptr;
#endif
}

extern int shared_region_check(void* address);

#include <stdarg.h>
#include <sys/types.h>
#include <string.h>
#include <sys/fcntl.h>

// This is taken from tihmstar/jbinit, because I don't write C, and I can't use va_list in Swift

extern int sandbox_check_by_audit_token(audit_token_t au, const char *operation, int sandbox_filter_type, ...);

extern int hook_sandbox_check(audit_token_t au, const char *operation, int sandbox_filter_type, ...);
int hook_sandbox_check(audit_token_t au, const char *operation, int sandbox_filter_type, ...) {
    va_list a;
    va_start(a, sandbox_filter_type);
    const char *name = va_arg(a, const char *);
    const void *arg2 = va_arg(a, void *);
    const void *arg3 = va_arg(a, void *);
    const void *arg4 = va_arg(a, void *);
    const void *arg5 = va_arg(a, void *);
    const void *arg6 = va_arg(a, void *);
    const void *arg7 = va_arg(a, void *);
    const void *arg8 = va_arg(a, void *);
    const void *arg9 = va_arg(a, void *);
    const void *arg10 = va_arg(a, void *);
    va_end(a);
    if (name && operation) {
        if (strcmp(operation, "mach-lookup") == 0) {
            if (strncmp((char *)name, "cy:", 3) == 0 || strncmp((char *)name, "lh:", 3) == 0) {
                /* always allow */
                return 0;
            }
        }
    }
    return sandbox_check_by_audit_token(au, operation, sandbox_filter_type, name, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10);
}

#include <mach/arm/kern_return.h>
#include <mach/port.h>
#include <mach/vm_prot.h>

__attribute__((noinline, naked)) volatile kern_return_t custom_mach_vm_protect(mach_port_name_t target, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection)
{
#if __arm64__
    __asm("mov x16, #0xFFFFFFFFFFFFFFF2");
    __asm("svc 0x80");
    __asm("ret");
#else
    __asm(".intel_syntax noprefix; \
           mov rax, 0xFFFFFFFFFFFFFFF2; \
           syscall; \
           ret");
#endif
}

void manual_memcpy(void *restrict dest, const void *src, size_t len) {
    volatile uint8_t *d8 = dest;
    const uint8_t *s8 = src;
    while (len--)
        *d8++ = *s8++;
}

kern_return_t EKHookMemoryRaw_impl(void *target, const void *data, size_t size)
{
    kern_return_t kr = KERN_SUCCESS;

    vm_address_t machTarget = (vm_address_t)target;
    vm_size_t machSize = size;
    struct vm_region_submap_short_info_64 info;
    mach_msg_type_number_t infoCount = VM_REGION_SUBMAP_SHORT_INFO_COUNT_64;
    natural_t maxDepth = 99999;
    kr = vm_region_recurse_64(mach_task_self_, &machTarget, &machSize,
                                            &maxDepth,
                                            (vm_region_recurse_info_t) &info,
                                            &infoCount);
    machTarget = (vm_address_t)target;

    if (kr != KERN_SUCCESS) return kr;

    bool needsRemap = !(info.protection & VM_PROT_WRITE);

    if (needsRemap) {
        int newFlags = VM_PROT_READ | VM_PROT_WRITE;
        if (!(info.max_protection & VM_PROT_WRITE)) {
            newFlags |= VM_PROT_COPY;
        }

        kr = custom_mach_vm_protect(mach_task_self_, machTarget, size, 0, newFlags);
		
        if (kr != KERN_SUCCESS) return kr;
    }

    manual_memcpy(target, data, size);

    if (needsRemap) {
        kr = custom_mach_vm_protect(mach_task_self_, machTarget, size, 0, info.protection);
        if (kr != KERN_SUCCESS) return kr;
    }

    sys_icache_invalidate(target, size);
    return kr;
}

__attribute__((visibility ("default"))) kern_return_t (*EKHookMemoryRaw)(void *, const void *, size_t) = EKHookMemoryRaw_impl;
