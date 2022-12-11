
.global _posix_spawn_patch_routine

.macro start
    stp    fp, lr, [sp, #0]
    add    fp, sp, #0
.endmacro

.macro end
    ldp    fp, lr, [sp, #0]
    add    sp, sp, #16
.endmacro

.macro spawn_prefix // the original instructions
    pacibsp
    sub sp, sp, #0xe0
    stp x26, x25, [sp, #0x90]
    stp x24, x23, [sp, #0xa0]
    stp x22, x21, [sp, #0xb0]
.endmacro

.macro jumpback
    movk x14, #0x6bdc // load posix_spawn original address in x16
    movk x14, #0x883b, lsl #16
    movk x14, #0x0001, lsl #32
    movk x14, #0x0000, lsl #48
    add x14, x14, #20 // skip first (patched) instructions
    br x14
.endmacro

.macro load num
    mov w10, \num
    strb w10, [x14], #1
.endmacro

.macro get_array_count dst
ldr     x8, [x5]
mov     \dst, xzr // int i = 0;
add     x7, x5, #8 // first pointer
// loop start
mov     x9, \dst
mov     \dst, x8
ldr     x8, [x7, x9, lsl #3]
add     \dst, x9, #1
cbnz    x8, #-16 // goto loop start if the read byte isn't 0
.endmacro

.macro get_last_env_var dst, count
    mov x12, #8
    sub \count, \count, #1 // we take out one, because we want the previous env var
    mul \count, \count, x12 // get sizeof the pointer array
    add x13, x5, \count // x13 now has the first character of the last env var
    ldr \dst, [x13] // load the last env var's string pointer
.endmacro

.macro get_next_terminator dst
    mov x16, xzr
    ldrb w12, [\dst], #1
    cbnz w12, #-4 // if this loop exits, it found the next term
.endmacro

.macro load_string
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
    load #0x00
.endmacro

// REGISTERS:
// - x14: value of x5
_posix_spawn_patch_routine:

    pacibsp
    //spawn_prefix
    
    xpacd x5

    get_array_count x15 // x15 now has the array count
    
    get_last_env_var x14, x15 // put the last env var pointer in x14, with count in x15
    
    get_next_terminator x14 // now we have the current null terminator in x14

    load_string

    add x15, x15, #8
    sub x14, x14, #55 // go back to the start of the string

    str x14, [x5, #16]

    // we now have the string
    // DYLD_INSERT_LIBRARIES=/usr/local/lib/libinjector.dylib
    // in the envp !!!!

    mov x2, #0
    mov x3, x4
    mov x4, x5
    mov x5, #0

    mov x16, #0xF4
    svc #0x80

    retab
