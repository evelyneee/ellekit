
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
#include "include/mach.h"

extern mach_port_t EKLaunchExceptionHandler(void);
extern void EKAddHookToRegistry(void* target, void* replacement);

/*
void EKOrigPrelog(void) {
    thread_act_t thread = mach_thread_self();
    struct arm_debug_state64 state = {};
    thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&state, ARM_DEBUG_STATE64_COUNT_);
}

void EKOrigEpilog(void) {
    thread_act_t thread = mach_thread_self();
    thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&globalDebugState, ARM_DEBUG_STATE64_COUNT_);
}
 */

int hookCount = 0;

void* hook1;
void* hook1rep;

__attribute__((naked))
extern void orig1(void) {
#if __arm64__
    __asm__ volatile(
                     ".extern _hook1\n"
                     "adrp x16, _hook1@PAGE\n"
                     "ldr x16, [x16, _hook1@PAGEOFF]\n"
                     "add x16, x16, #4\n"
                     "pacibsp\n"
                     "br x16\n"
                     );
#endif
}

void* hook2;
void* hook2rep;

__attribute__((naked))
static void orig2(void) {
#if __arm64__
    __asm__ volatile(
                     ".extern _hook2\n"
                     "adrp x16, _hook2@PAGE\n"
                     "ldr x16, [x16, _hook2@PAGEOFF]\n"
                     "add x16, x16, #4\n"
                     "pacibsp\n"
                     "br x16\n"
                     );
#endif
}

void* hook3;
void* hook3rep;

__attribute__((naked))
static void orig3(void) {
#if __arm64__
    __asm__ volatile(
                     ".extern _hook3\n"
                     "adrp x16, _hook3@PAGE\n"
                     "ldr x16, [x16, _hook3@PAGEOFF]\n"
                     "add x16, x16, #4\n"
                     "pacibsp\n"
                     "br x16\n"
                     );
#endif
}

void* hook4;
void* hook4rep;

__attribute__((naked))
static void orig4(void) {
#if __arm64__
    __asm__ volatile(
                     ".extern _hook4\n"
                     "adrp x16, _hook4@PAGE\n"
                     "ldr x16, [x16, _hook4@PAGEOFF]\n"
                     "add x16, x16, #4\n"
                     "pacibsp\n"
                     "br x16\n"
                     );
#endif
}

void* hook5;
void* hook5rep;

__attribute__((naked))
static void orig5(void) {
#if __arm64__
    __asm__ volatile(
                     ".extern _hook5\n"
                     "adrp x16, _hook5@PAGE\n"
                     "ldr x16, [x16, _hook5@PAGEOFF]\n"
                     "add x16, x16, #4\n"
                     "pacibsp\n"
                     "br x16\n"
                     );
#endif
}

void* hook6;
void* hook6rep;

__attribute__((naked))
static void orig6(void) {
#if __arm64__
    __asm__ volatile(
                     ".extern _hook6\n"
                     "adrp x16, _hook6@PAGE\n"
                     "ldr x16, [x16, _hook6@PAGEOFF]\n"
                     "add x16, x16, #4\n"
                     "pacibsp\n"
                     "br x16\n"
                     );
#endif
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
#define ARM_DEBUG_STATE64_COUNT_ ((mach_msg_type_number_t) \
   (sizeof (struct arm_debug_state64)/sizeof(uint32_t)))

struct arm_debug_state64 globalDebugState = {};

void EKJITLessHook(void* _target, void* _replacement, void** orig) {
    
    EKLaunchExceptionHandler();
    
    void* target = (void*)((uint64_t)_target & 0x0000007fffffffff);
    void* replacement = (void*)((uint64_t)_replacement & 0x0000007fffffffff);
    
    EKAddHookToRegistry(target, replacement);
            
    uint32_t firstISN = *(uint32_t*)target;
    
    printf("pacibsp? : %02X\n", firstISN);
    
    if (hookCount == 6) {
        return;
    }
    
    switch (hookCount) {
        case 0:
            hook1 = target;
            hook1rep = replacement;
            
            globalDebugState.bvr[0] = (uint64_t)target;
            globalDebugState.bcr[0] = 0x1e5;
            
            if (orig && firstISN == 0xD503237F) {
                *orig = &orig1;
            }
            
            printf("[+] ellekit: hook #1 set\n");
            
            break;
        case 1:
            hook2 = target;
            hook2rep = replacement;
            
            globalDebugState.bvr[1] = (uint64_t)target;
            globalDebugState.bcr[1] = 0x1e5;
            
            if (orig && firstISN == 0xD503237F) {
                *orig = &orig2;
            }
            
            printf("[+] ellekit: hook #2 set\n");
            break;
        case 2:
            hook3 = target;
            hook3rep = replacement;
            
            globalDebugState.bvr[2] = (uint64_t)target;
            globalDebugState.bcr[2] = 0x1e5;
            
            if (orig && firstISN == 0xD503237F) {
                *orig = &orig3;
            }
            
            printf("[+] ellekit: hook #3 set\n");
            break;
        case 3:
            hook4 = target;
            hook4rep = replacement;
            
            globalDebugState.bvr[3] = (uint64_t)target;
            globalDebugState.bcr[3] = 0x1e5;
            
            if (orig && firstISN == 0xD503237F) {
                *orig = &orig4;
            }
            
            printf("[+] ellekit: hook #4 set\n");
            break;
        case 4:
            hook5 = target;
            hook5rep = replacement;
            
            globalDebugState.bvr[4] = (uint64_t)target;
            globalDebugState.bcr[4] = 0x1e5;
            
            if (orig && firstISN == 0xD503237F) {
                *orig = &orig5;
            }
            
            printf("[+] ellekit: hook #5 set\n");
            break;
        case 5:
            hook6 = target;
            hook6rep = replacement;
            
            globalDebugState.bvr[5] = (uint64_t)target;
            globalDebugState.bcr[5] = 0x1e5;
            
            if (orig && firstISN == 0xD503237F) {
                *orig = &orig6;
            }
            
            printf("[+] ellekit: hook #6 set\n");
            break;
    }
    
    hookCount++;
    
    kern_return_t task_setstate_ret = custom_task_set_state(mach_task_self(), ARM_DEBUG_STATE64, (thread_state_t)&globalDebugState, ARM_DEBUG_STATE64_COUNT_);
    
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
        
        thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&globalDebugState, ARM_DEBUG_STATE64_COUNT_);
        
        mach_port_deallocate(mach_task_self_, thread);
    }
    
    mach_vm_deallocate(mach_task_self_, (mach_vm_address_t)act_list, listCnt * sizeof(thread_t));
}
