
#if __arm64e__
#include <ptrauth.h>
#endif

#include <mach/mach.h>

#import "API/libhooker.h"

extern int hook(void* target, const unsigned char code[], mach_vm_size_t size);

extern const void* assembly(const unsigned char code[], size_t);

extern void* replacement_ptr(void);
extern void* target_ptr(void);

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

#define _STRUCT_ARM_THREAD_STATE64      struct arm_thread_state64
_STRUCT_ARM_THREAD_STATE64
{
    __uint64_t __x[29]; /* General purpose registers x0-x28 */
    __uint64_t __fp;    /* Frame pointer x29 */
    __uint64_t __lr;    /* Link register x30 */
    __uint64_t __sp;    /* Stack pointer x31 */
    __uint64_t __pc;    /* Program counter */
    __uint32_t __cpsr;  /* Current program status register */
    __uint32_t __pad;   /* Same size for 32-bit or 64-bit clients */
};
