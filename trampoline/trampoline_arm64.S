
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

#if defined(__arm64__) || defined(__arm64e__)
.extern _execl, _setenv, _puts
.global _main

.text

/*
    sub    sp, sp, #16
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0
 */

/*
    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16
 */

_main:

    sub    sp, sp, #16
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0

    bl _hello_world
    bl _set_app_env
    bl _call_app_binary
    bl _goodbye

    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16

    ret

_goodbye:

    sub    sp, sp, #16
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0

    adr x0, goodbye
    bl _puts

    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16

    ret

_hello_world:

    sub    sp, sp, #16
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0

    adr x0, hello_world
    bl _puts

    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16

    ret

_set_app_env:

    sub    sp, sp, #16
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0

    // Call setenv
    adr x0, dyld_insert
    adr x1, dylib_path
    mov x2, #1
    bl _setenv
    
    // Check result
    cmp x0, #0
    adr x1, success
    adr x2, failure
    csel x0, x1, x2, EQ
    bl _puts
    
    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16

    ret
    
_call_app_binary:

    sub    sp, sp, #16
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0

    adr x0, bin_path
    adr x1, bin_path
    bl _execl
    
    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16
    
    ret

.align 4

hello_world:
.asciz "[Trampoline] Hello world!"

goodbye:
.asciz "[Trampoline] Called binary, goodbye"

success:
.asciz "[Trampoline] Env setting success"

failure:
.asciz "[Trampoline] Env setting failed"

dyld_insert:
.ascii "DYLD_INSERT_LIBRARIES"

bin_path:
.asciz  "/Applications/Messages.app/Contents/MacOS/Messages_original"

dylib_path:
.asciz  "/Applications/Messages.app/Contents/MacOS/hook.dylib"

#endif
