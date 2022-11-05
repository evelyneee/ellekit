//
//  Misc.h
//  ellekit
//
//  Created by charlotte on 2022-11-05.
//

#import <stdio.h>

void* sign(void* ptr) {
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

uint64_t getOpaquePC(arm_thread_state64_t state) {
#if __arm64e__
    return (uint64_t)ptrauth_strip(state.__opaque_pc, ptrauth_key_process_independent_code);
#else
    return state.__pc;
#endif
}

void* strip(void* ptr) {
#if __arm64e__
    return ptrauth_strip(ptr, ptrauth_key_function_pointer);
#else
    return ptr;
#endif
}
