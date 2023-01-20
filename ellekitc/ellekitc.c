
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

#if __arm64e__
#include <ptrauth.h>
#endif

// MARK: - PAC

void* sign_pointer(void* ptr) {
#if __arm64e__
    return ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
#else
    return ptr;
#endif
}

void* sign_pc(void* ptr) {
#if __arm64e__
    return ptrauth_sign_unauthenticated(ptr, ptrauth_key_process_independent_code, 0x7481);
#else
    return ptr;
#endif
}

void* strip_pointer(void* ptr) {
#if __arm64e__
    return ptrauth_strip(ptr, ptrauth_key_function_pointer);
#else
    return ptr;
#endif
}

extern int shared_region_check(void* address);

#include <stdarg.h>
#include <sys/types.h>
#include <string.h>

// This is taken from Substitute, because I don't write C, and I can't use va_list in Swift

extern int sandbox_check(pid_t, const char *, int type, ...);

extern int hook_sandbox_check(pid_t pid, const char *op, int type, ...);
int hook_sandbox_check(pid_t pid, const char *op, int type, ...) {
    va_list ap;
    va_start(ap, type);
    long blah[5];
    for (int i = 0; i < 5; i++)
        blah[i] = va_arg(ap, long);
    va_end(ap);
    if (!strcmp(op, "mach-lookup")) {
        const char *name = (void *) blah[0];
        if (!memcmp(name, "cy:", 3) || !memcmp(name, "lh:", 3)) {
            /* always allow */
            return 0;
        }
    }
    return sandbox_check(pid, op, type, blah[0], blah[1], blah[2], blah[3], blah[4]);
}
