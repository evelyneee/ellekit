
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

#if __x86_64__
.intel_syntax noprefix
#endif

.text

.extern _shared_region_check
.global _shared_region_check, _dmb_sy, _test_weirdfunc

#if __arm64__

_shared_region_check:
    mov x16, #294
    svc #0x80
    ret
_dmb_sy:
    dmb sy
    ret
.align 4
.skip 16384
_test_weirdfunc:
    mov x3, #1
    cbnz x3, _dmb_sy
    cbz x3, _dmb_sy
    cbnz w3, _dmb_sy
    ret
.skip 16384

#else
_shared_region_check:
    mov rax, 294
    syscall
    ret
#endif
