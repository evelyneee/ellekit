
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
    movk x9, #0xebdc
    movk x9, #0xa06a, lsl #16
    movk x9, #0x0001, lsl #32
    movk x9, #0x0000, lsl #48
    add x9, x9, 20
    pacibsp
    sub sp, sp, #0xe0
    stp x26, x25, [sp, #0x90]
    stp x24, x23, [sp, #0xa0]
    stp x22, x21, [sp, #0xb0]
    br x9
.endmacro

.macro load num, offset
    mov w10, \num
    strb w10, [x7, \offset]
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

    ldr x8, [x5] // char* last = *envp;
    sub x8, x8, #1

    ldrb w9, [x8, #1]!
    cbnz w9, #-4 // if this loop exits, it found the null term
    
    malloc x7, #1024

    load #0x44, #0
    load #0x59, #1
    load #0x4C, #2
    load #0x44, #3
    load #0x5F, #4
    load #0x49, #5
    load #0x4E, #6
    load #0x53, #7
    load #0x45, #8
    load #0x52, #9
    load #0x54, #10
    load #0x5F, #11
    load #0x4C, #12
    load #0x49, #13
    load #0x42, #14
    load #0x52, #15
    load #0x41, #16
    load #0x52, #17
    load #0x49, #18
    load #0x45, #19
    load #0x53, #20
    load #0x3D, #21
    load #0x22, #22
    load #0x2F, #23
    load #0x75, #24
    load #0x73, #25
    load #0x72, #26
    load #0x2F, #27
    load #0x6C, #28
    load #0x6F, #29
    load #0x63, #30
    load #0x61, #31
    load #0x6C, #32
    load #0x2F, #33
    load #0x6C, #34
    load #0x69, #35
    load #0x62, #36
    load #0x2F, #37
    load #0x6C, #38
    load #0x69, #39
    load #0x62, #40
    load #0x69, #41
    load #0x6E, #42
    load #0x6A, #43
    load #0x65, #44
    load #0x63, #45
    load #0x74, #46
    load #0x6F, #47
    load #0x72, #48
    load #0x2E, #49
    load #0x64, #50
    load #0x79, #51
    load #0x6C, #52
    load #0x69, #53
    load #0x62, #54
    load #0x22, #55
    load #0x00, #56
        
    ldr x8, [x7]

    // we now have the string
    // DYLD_INSERT_LIBRARIES="/usr/local/lib/libinjector.dylib"
    // in the envp !!!!

    jumpback
