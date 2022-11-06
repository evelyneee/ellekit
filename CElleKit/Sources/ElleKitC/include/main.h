
#if __arm64e__
#include <ptrauth.h>
#endif

#include <mach/mach.h>

#import "libhooker.h"

#import <mach-o/dyld.h>

#import <stdio.h>

#import "PAC.h"

extern const void* assembly(const unsigned char code[], size_t);

extern kern_return_t
mach_vm_allocate(mach_port_name_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

extern kern_return_t
mach_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection);

extern int testExceptionPort(void);

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

int getExceptionPorts(void) {
    exception_mask_t       exception_masks[EXC_TYPES_COUNT];
    mach_msg_type_number_t exception_count = 0;
    mach_port_t            exception_ports[EXC_TYPES_COUNT];
    exception_behavior_t   exception_behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t  exception_flavors[EXC_TYPES_COUNT];

    kern_return_t kr = task_get_exception_ports(
        mach_task_self(),
        // In earlier header versions EXC_MASK_ALL could have been used, but it now includes too much.
        EXC_MASK_BREAKPOINT,
        exception_masks,
        &exception_count,
        exception_ports,
        exception_behaviors,
        exception_flavors
    );
    
    printf("Exception port: %02X\n", exception_behaviors[0]);
    return exception_behaviors[0];
}
