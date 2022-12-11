
.global _posix_spawn_patch_routine

.macro start
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0
.endmacro

.macro end
    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16
.endmacro

.macro spawn_prefix
    pacibsp
    sub sp, sp, #0xe0
    stp x26, x25, [sp, #0x90]
    stp x24, x23, [sp, #0xa0]
    stp x22, x21, [sp, #0xb0]
    stp x29, x30, [sp, #0xD0]
.endmacro

.macro jumpback
    movk x14, #0xebdc // load posix_spawn original address in x16
    movk x14, #0xa06a, lsl #16
    movk x14, #0x0001, lsl #32
    movk x14, #0x0000, lsl #48
    add x14, x14, #20 // skip first (patched) instructions
    br x14
.endmacro

.macro load num
    mov w10, \num
    strb w10, [x14, x15]
    add x15, x15, #1
.endmacro

// REGISTERS:
// - x14: value of x5
_posix_spawn_patch_routine:

    spawn_prefix

    mov x15, xzr // int i = 0;

    mov x14, x5

    ldr x13, [x14, x15]
    add x15, x15, #8
    cbnz x13, #-8 // if this loop exits, it found the null term

    ldr x14, [x14]

    // x15 now has the array size
    load #0x00
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
    
    jumpback
