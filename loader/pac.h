//
//  pac.h
//  loader
//
//  Created by charlotte on 2022-12-12.
//

#ifndef pac_h
#define pac_h

#include <stdio.h>

extern void* sign_pointer(void* ptr);
extern void* strip_pointer(void* ptr);
extern void* sign_pc(void* ptr);

#endif /* pac_h */
