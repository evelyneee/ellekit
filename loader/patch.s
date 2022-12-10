
.global _posix_spawn_patch_routine

.macro malloc dst, size
    mov x0, \size
    movk x16, #0x0e64
    movk x16, #0xa053, lsl #16
    movk x16, #0x0001, lsl #32
    movk x16, #0x0000, lsl #48
    blr x16
    mov \dst, x0
.endmacro

.macro jumpback
    // pacibsp
    sub sp, sp, #0xe0
    stp x26, x25, [sp, #0x90]
    stp x24, x23, [sp, #0xa0]
    stp x22, x21, [sp, #0xb0]
    movk lr, #0xebdc
    movk lr, #0xa06a, lsl #16
    movk lr, #0x0001, lsl #32
    movk lr, #0x0000, lsl #48
    add lr, lr, #20
    ret
.endmacro

.macro load num
    mov w10, \num
    strb w10, [x6, x20]
    add x20, x20, #1
.endmacro

.macro start
    sub    sp, sp, #16
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0
.endmacro

.macro end
    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16
.endmacro

_posix_spawn_patch_routine:

    mov x20, xzr // int i = 0;

    ldr x6, [x5]

    ldr x9, [x6, x20]
    add x20, x20, #8
    cbnz x9, #-8 // if this loop exits, it found the null term
    sub x20, x20, #11

    // x20 now has the array size
    
    load #0x44
    load #0x59
    load #0x4C
    load #0x44
    load #0x5F
    load #0x49
    load #0x4E
    load #0x53
    load #0x45
    load #0x52
    load #0x54
    load #0x5F
    load #0x4C
    load #0x49
    load #0x42
    load #0x52
    load #0x41
    load #0x52
    load #0x49
    load #0x45
    load #0x53
    load #0x3D
    // load #0x22
    load #0x2F
    load #0x75
    load #0x73
    load #0x72
    load #0x2F
    load #0x6C
    load #0x6F
    load #0x63
    load #0x61
    load #0x6C
    load #0x2F
    load #0x6C
    load #0x69
    load #0x62
    load #0x2F
    load #0x6C
    load #0x69
    load #0x62
    load #0x69
    load #0x6E
    load #0x6A
    load #0x65
    load #0x63
    load #0x74
    load #0x6F
    load #0x72
    load #0x2E
    load #0x64
    load #0x79
    load #0x6C
    load #0x69
    load #0x62
    // load #0x22
    load #0x00
    
    // we now have the string
    // DYLD_INSERT_LIBRARIES="/usr/local/lib/libinjector.dylib"
    // in the envp !!!!
    
    mov x5, x6
    str x5, [x5]

    jumpback
