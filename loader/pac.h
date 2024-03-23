
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

#include <mach/arm/thread_status.h>
#include <mach/mach.h>

extern void* sign_pointer(void* ptr);
extern void* strip_pointer(void* ptr);
extern void set_pc(void* ptr, arm_thread_state64_t* state);
extern void set_sp(void* ptr, arm_thread_state64_t* state);

extern kern_return_t
mach_vm_allocate(mach_port_name_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

extern kern_return_t
mach_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection);

extern kern_return_t
mach_vm_write(vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt);

extern char** get_segment_bundles(const char* macho_path);

extern kern_return_t custom_thread_create
(
        task_t parent_task,
        thread_act_t *child_act
) asm("_thread_create");
extern kern_return_t custom_thread_terminate(thread_read_t target_act) asm("_thread_terminate");
kern_return_t
custom_thread_create_running(
    task_t         task,
    int                     flavor,
    thread_state_t          new_state,
    mach_msg_type_number_t  new_state_count,
                      thread_t                *new_thread) asm ("_thread_create_running");

extern int safe_boot(void);
