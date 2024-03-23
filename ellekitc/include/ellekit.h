
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

#include <mach/mach.h>

#include <mach-o/dyld.h>

#include <stdio.h>

#include <stdlib.h>

#include <spawn.h>

#import "sandbox.h"

#import "mach.h"

#if __has_include(<xpc/xpc.h>)
#import <xpc/xpc.h>
#else
#import "xpc.h"
#endif

struct sCSRange {
   unsigned long long location;
   unsigned long long length;
};
typedef struct sCSRange CSRange;

// MARK: - CPU

extern void sys_icache_invalidate(void *start, size_t length);

// MARK: - Libhooker

struct LHFunctionHook {
    void *function;
    void *replacement;
    void *oldptr;
    struct LHFunctionHookOptions *options;
};

enum LHOptions {
    LHOptionsNone,
    LHOptionsSetJumpReg
};

struct LHFunctionHookOptions {
    enum LHOptions options;
    int jmp_reg;
};

enum LIBHOOKER_ERR {
    LIBHOOKER_OK = 0,
    LIBHOOKER_ERR_SELECTOR_NOT_FOUND = 1,
    LIBHOOKER_ERR_SHORT_FUNC = 2,
    LIBHOOKER_ERR_BAD_INSN_AT_START = 3,
    LIBHOOKER_ERR_VM = 4,
    LIBHOOKER_ERR_NO_SYMBOL = 5
};

struct LHMemoryPatch {
    void *destination;
    const void *data;
    size_t size;
    void *options;
};

// MARK: - PAC

extern void* sign_pointer(void* ptr);
extern void* strip_pointer(void* ptr);
extern void* sign_pc(void* ptr);

// MARK: - The rest

extern const void* assembly(const unsigned char code[], size_t);

extern kern_return_t
mach_vm_allocate(mach_port_name_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

extern kern_return_t
mach_vm_deallocate(vm_map_t target, mach_vm_address_t address, mach_vm_size_t size);

extern kern_return_t
mach_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection);

extern kern_return_t
custom_mach_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection);

extern kern_return_t
mach_vm_write(vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt);

extern kern_return_t
mach_vm_remap(vm_map_t target_task, mach_vm_address_t *target_address, mach_vm_size_t size, mach_vm_offset_t mask, int flags, vm_map_t src_task, mach_vm_address_t src_address, boolean_t copy, vm_prot_t *cur_protection, vm_prot_t *max_protection, vm_inherit_t inheritance);

extern int     custom_posix_spawn(pid_t * __restrict, const char * __restrict,
    const posix_spawn_file_actions_t *,
    const posix_spawnattr_t * __restrict,
    char *const __argv[__restrict],
                                  char *const __envp[__restrict])
asm("_posix_spawn");


int     custom_posix_spawnp(pid_t * __restrict, const char * __restrict,
    const posix_spawn_file_actions_t *,
    const posix_spawnattr_t * __restrict,
    char *const __argv[__restrict],
                     char *const __envp[__restrict])
asm("_posix_spawnp");

extern void manual_memcpy(void *restrict dest, const void *src, size_t len);
extern kern_return_t (*EKHookMemoryRaw)(void *target, const void *data, size_t size);

#pragma pack(4)
typedef struct {
  mach_msg_header_t Head;
  mach_msg_body_t msgh_body;
  mach_msg_port_descriptor_t thread;
  mach_msg_port_descriptor_t task;
  NDR_record_t NDR;
} exception_raise_request; // the bits we need at least

typedef struct {
  mach_msg_header_t Head;
  NDR_record_t NDR;
  kern_return_t RetCode;
} exception_raise_reply;
#pragma pack()

struct arm_thread_state64
{
#if __arm64e__
    __uint64_t __x[29];     /* General purpose registers x0-x28 */
    void*      __opaque_fp; /* Frame pointer x29 */
    void*      __opaque_lr; /* Link register x30 */
    void*      __opaque_sp; /* Stack pointer x31 */
    void*      __opaque_pc; /* Program counter */
    __uint32_t __cpsr;      /* Current program status register */
    __uint32_t __opaque_flags; /* Flags describing structure format */
#else
    __uint64_t __x[29]; /* General purpose registers x0-x28 */
    __uint64_t __fp;    /* Frame pointer x29 */
    __uint64_t __lr;    /* Link register x30 */
    __uint64_t __sp;    /* Stack pointer x31 */
    __uint64_t __pc;    /* Program counter */
    __uint32_t __cpsr;  /* Current program status register */
    __uint32_t __pad;   /* Same size for 32-bit or 64-bit clients */
#endif
};

#include <unistd.h>

extern int shared_region_check(uint64_t* address);

#include "dyld.h"

extern void test();

extern void dmb_sy();

#define CS_VALID 0x0000001    /* dynamically valid */
#define CS_ADHOC                        0x0000002    /* ad hoc signed */
#define CS_GET_TASK_ALLOW               0x0000004    /* has get-task-allow entitlement */
#define CS_INVALID_ALLOWED              0x00000020
#define CS_INSTALLER                    0x0000008    /* has installer entitlement */

#define CS_HARD                         0x0000100    /* don't load invalid pages */
#define CS_KILL                         0x0000200    /* kill process if it becomes invalid */
#define CS_CHECK_EXPIRATION             0x0000400    /* force expiration checking */
#define CS_RESTRICT                     0x0000800    /* tell dyld to treat restricted */
#define CS_ENFORCEMENT                  0x0001000    /* require enforcement */
#define CS_REQUIRE_LV                   0x0002000    /* require library validation */
#define CS_ENTITLEMENTS_VALIDATED       0x0004000

#define CS_ALLOWED_MACHO                0x00ffffe

#define CS_EXEC_SET_HARD                0x0100000    /* set CS_HARD on any exec'ed process */
#define CS_EXEC_SET_KILL                0x0200000    /* set CS_KILL on any exec'ed process */
#define CS_EXEC_SET_ENFORCEMENT         0x0400000    /* set CS_ENFORCEMENT on any exec'ed process */
#define CS_EXEC_SET_INSTALLER           0x0800000    /* set CS_INSTALLER on any exec'ed process */

#define CS_KILLED                       0x1000000    /* was killed by kernel for invalidity */
#define CS_DYLD_PLATFORM                0x2000000    /* dyld used to load this is a platform binary */
#define CS_PLATFORM_BINARY              0x4000000    /* this is a platform binary */
#define CS_PLATFORM_PATH                0x8000000    /* platform binary by the fact of path (osx only) */

#define CS_DEBUGGED                     0x10000000  /* process is currently or has previously been debugged and allowed to run with invalid pages */
#define CS_SIGNED                       0x20000000  /* process has a signature (may have gone invalid) */
#define CS_DEV_CODE                     0x40000000  /* code is dev signed, cannot be loaded into prod signed code */

#include <sys/types.h>
/* csops  operations */
#define    CS_OPS_STATUS        0    /* return status */
#define    CS_OPS_MARKINVALID    1    /* invalidate process */
#define    CS_OPS_MARKHARD        2    /* set HARD flag */
#define    CS_OPS_MARKKILL        3    /* set KILL flag (sticky) */
#define    CS_OPS_PIDPATH        4    /* get executable's pathname */
#define    CS_OPS_CDHASH        5    /* get code directory hash */

/* code sign operations */
extern int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);
