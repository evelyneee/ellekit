
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

#include <stdio.h>

#if __has_feature(ptrauth_calls)
#include <ptrauth.h>
#endif

#include <mach/mach.h>
#include <mach/task.h>
#include <mach/thread_act.h>
#include <mach/thread_state.h>
#include <mach/thread_status.h>

extern void EKLaunchExceptionHandler(void);
extern void EKAddHookToRegistry(void* target, void* replacement);

int hookCount = 0;

void* hook1;
void* hook1rep;

__attribute__((naked))
static void orig1(void) {
    __asm__ volatile(
                     "extern hook1\n"
                     "adr x16, hook1\n"
                     "ldr x16, [x16]\n"
                     "add x16, x16, #4\n"
#if __has_feature(ptrauth_calls)
                     "pacibsp\n"
#endif
                     "br x16\n"
                     );
}

struct arm_debug_state64
{
    __uint64_t        bvr[16];
    __uint64_t        bcr[16];
    __uint64_t        wvr[16];
    __uint64_t        wcr[16];
    __uint64_t      mdscr_el1; /* Bit 0 is SS (Hardware Single Step) */
};

#define ARM_DEBUG_STATE64 15
#define ARM_DEBUG_STATE64_COUNT ((mach_msg_type_number_t) \
   (sizeof (struct arm_debug_state64)/sizeof(uint32_t)))

struct arm_debug_state64 globalDebugState = {};
void EKJITLessHook(void* target, void* replacement, void** orig) {
    
    EKLaunchExceptionHandler();
    
    EKAddHookToRegistry(target, replacement);
            
    switch (hookCount) {
        case 0:
            hook1 = target;
            hook1rep = replacement;
            
            globalDebugState.bvr[0] = ((uint64_t)target & 0x0000007fffffffff);
            globalDebugState.bcr[0] = 0x1e5;
            
            if (!orig) {
                *orig = target;
            }
            
            printf("[+] ellekit: hook #1 set\n");
    }
    
    hookCount++;
    
    kern_return_t task_setstate_ret = task_set_state(mach_task_self(), ARM_DEBUG_STATE64, (thread_state_t)&globalDebugState, ARM_DEBUG_STATE64_COUNT);
    
    if (task_setstate_ret != KERN_SUCCESS) {
        printf("[-] ellekit: JIT hook did not work, task_set_state failed with err: %s\n", mach_error_string(task_setstate_ret));
        return;
    }
    
    thread_act_array_t act_list;
    mach_msg_type_number_t listCnt;
    
    kern_return_t task_threads_ret = task_threads(mach_task_self(), &act_list, &listCnt);
    
    if (task_threads_ret != KERN_SUCCESS) {
        printf("[-] ellekit: JIT hook did not work, task_threads failed with err: %s\n", mach_error_string(task_threads_ret));
        return;
    }
    
    for (int i = 0; i < listCnt; i++) {
        thread_t thread = act_list[i];
        
        thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&globalDebugState, ARM_DEBUG_STATE64_COUNT);
    }
}
