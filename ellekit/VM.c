
#include <mach/mach.h>

extern kern_return_t
mach_vm_allocate(mach_port_name_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

extern kern_return_t
mach_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection);

const void* assembly(const unsigned char code[], size_t codesize) {
    mach_vm_address_t addr = 0;
    mach_vm_allocate(mach_task_self(), &addr, vm_page_size, VM_FLAGS_ANYWHERE);
    mach_vm_protect(mach_task_self(), addr, vm_page_size, 0, VM_PROT_READ | VM_PROT_WRITE);
    memcpy((void *)addr, code, codesize);
    mach_vm_protect(mach_task_self(), addr, vm_page_size, 0, VM_PROT_READ | VM_PROT_EXECUTE);
    const void* (*myFunction)(void) = (typeof(myFunction))addr;
    return myFunction();
}

// PAC: strip target pointer before calling
int hook(void* target, const unsigned char code[], mach_vm_size_t size) {
    void *address = target;
    vm_prot_t newPermissions = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY;
    mach_vm_protect(mach_task_self(), (mach_vm_address_t)address, (mach_vm_size_t)size, FALSE, newPermissions);
            
    memcpy((void *)address, code, size);
        
    vm_prot_t originalPerms = VM_PROT_READ | VM_PROT_EXECUTE;
    kern_return_t err2 = mach_vm_protect(mach_task_self(),
                                        (mach_vm_address_t)address,
                                        (mach_vm_size_t)size,
                                        FALSE, originalPerms);
    
    if (err2 != 0) return 1;
        
    return 0;
}

