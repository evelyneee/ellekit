//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include <stdlib.h>
#include <mach/mach.h>
#include <stdio.h>

extern int hook(void* target, const unsigned char code[], mach_vm_size_t size);

extern const void* assembly(const unsigned char code[], size_t);

void assembly2(void) {
    
    const unsigned char code[] = {
        0x20, 0x00, 0x80, 0xd2, // mov x0, #1
        0x30, 0x00, 0x80, 0xd2, // mov x16, #1
        0x01, 0x10, 0x00, 0xd4, // svc #0x80
        0xc0, 0x03, 0x5f, 0xd6 // ret
    };
    
    assembly(code, sizeof(code));
}

extern void* replacement_ptr(void);
extern void* target_ptr(void);

void* fnPtr(uint64_t fn) {
    return (void*)fn;
}

extern kern_return_t
mach_vm_allocate(mach_port_name_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

extern kern_return_t
mach_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection);

struct LHFunctionHook {
    void* function;
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
