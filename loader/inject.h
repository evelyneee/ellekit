//
//  inject.h
//  loader
//
//  Created by charlotte on 2022-12-06.
//

#ifndef inject_h
#define inject_h

#include <stdio.h>
#include <mach/mach_types.h>

kern_return_t inject_to_task(mach_port_t task, const char *argument);
kern_return_t get_thread_port_for_task(mach_port_t task, mach_port_t *thread);

#endif /* inject_h */
