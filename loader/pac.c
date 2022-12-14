
#include "pac.h"
#include <ptrauth.h>
#include <mach/arm/thread_status.h>

void* sign_pointer(void* ptr) {
#if __arm64e__
    return ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
#else
    return ptr;
#endif
}

void set_pc(void* ptr, arm_thread_state64_t* state) {
    __darwin_arm_thread_state64_set_pc_fptr(
        *state,
        ptr
    );
}

void set_sp(void* ptr, arm_thread_state64_t* state) {
    __darwin_arm_thread_state64_set_sp(*state, ptr);
}

void* strip_pointer(void* ptr) {
#if __arm64e__
    return ptrauth_strip(ptr, ptrauth_key_function_pointer);
#else
    return ptr;
#endif
}
