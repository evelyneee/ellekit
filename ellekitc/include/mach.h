
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

#ifndef _ELLEKITC_MACH_H
#define _ELLEKITC_MACH_H
#include <mach/vm_types.h>
#include <mach/vm_prot.h>
#include <mach/vm_inherit.h>
#include <mach/mach_types.h>

extern kern_return_t
mach_vm_allocate(mach_port_name_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

extern kern_return_t
mach_vm_deallocate(vm_map_t target, mach_vm_address_t address, mach_vm_size_t size);

extern kern_return_t
mach_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection);

extern kern_return_t
mach_vm_write(vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt);

extern kern_return_t
mach_vm_remap(vm_map_t target_task, mach_vm_address_t *target_address, mach_vm_size_t size, mach_vm_offset_t mask, int flags, vm_map_t src_task, mach_vm_address_t src_address, boolean_t copy, vm_prot_t *cur_protection, vm_prot_t *max_protection, vm_inherit_t inheritance);

extern kern_return_t custom_task_set_state
(
        task_t task,
        thread_state_flavor_t flavor,
        thread_state_t new_state,
        mach_msg_type_number_t new_stateCnt
) asm ("_task_set_state");

mach_msg_return_t  custom_mach_msg(
                                                mach_msg_header_t *msg,
                                                mach_msg_option_t option,
                                                mach_msg_size_t send_size,
                                                mach_msg_size_t rcv_size,
                                                mach_port_name_t rcv_name,
                                                mach_msg_timeout_t timeout,
                                                mach_port_name_t notify) asm ("_mach_msg");

extern kern_return_t custom_task_set_exception_ports(task_t task, exception_mask_t exception_mask, mach_port_t new_port, exception_behavior_t behavior, thread_state_flavor_t new_flavor)
asm ("_task_set_exception_ports");
#endif
