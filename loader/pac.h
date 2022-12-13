
#include <mach/arm/thread_status.h>

extern void* sign_pointer(void* ptr);
extern void* strip_pointer(void* ptr);
extern void set_pc(void* ptr, arm_thread_state64_t* state);
extern void set_sp(void* ptr, arm_thread_state64_t* state);
