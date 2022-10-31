//
//  Assembly.c
//  Assembler
//
//  Created by evelyn on 2022-10-15.
//

#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <string.h>

#include <mach/mach.h>
#include <libkern/OSCacheControl.h>
#include <dlfcn.h>

extern kern_return_t
mach_vm_allocate(mach_port_name_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

extern kern_return_t
mach_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection);

#define NOP 0x1F2003D5

const void* assembly(const unsigned char code[], size_t codesize) {
    mach_vm_address_t addr = 0;
    mach_vm_allocate(mach_task_self(), &addr, vm_page_size, VM_FLAGS_ANYWHERE);
    mach_vm_protect(mach_task_self(), addr, vm_page_size, 0, VM_PROT_READ | VM_PROT_WRITE);
    memcpy((void *)addr, code, codesize);
    mach_vm_protect(mach_task_self(), addr, vm_page_size, 0, VM_PROT_READ | VM_PROT_EXECUTE);
    //now cast the address to a function pointer and call it
    const void* (*myFunction)(void) = (typeof(myFunction))addr;
    return myFunction();
}

void target1(void) {
    puts("uwu");
}

void replacement(void) {
    puts("owo");
}

int hook(void* target, const unsigned char code[], mach_vm_size_t size) {
    void *address = target; // 0x1B53AB984
    vm_prot_t newPermissions = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY;
    mach_vm_protect(mach_task_self(), (mach_vm_address_t)address, (mach_vm_size_t)size, FALSE, newPermissions);
    
    unsigned char* writable = (unsigned char*)address;
    
    printf("orig:  0x%02X%02X%02X%02X\n", writable[0], writable[1], writable[2], writable[3]);
    
    memcpy((void *)address, code, size);
    
    printf("patch: 0x%02X%02X%02X%02X\n", writable[0], writable[1], writable[2], writable[3]);
    
    vm_prot_t originalPerms = VM_PROT_READ | VM_PROT_EXECUTE;
    kern_return_t err2 = mach_vm_protect(mach_task_self(),
                                        (mach_vm_address_t)address,
                                        (mach_vm_size_t)size,
                                        FALSE, originalPerms);
    
    if (err2 != 0) return 1;
        
    return 0;
}

void* target_ptr(void) {
    target1();
    return *target1;
}

void* replacement_ptr(void) {
    return *replacement;
}

