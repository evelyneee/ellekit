
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

#if __x86_64__
.intel_syntax noprefix
#endif

.text

.extern _shared_region_check
.global _shared_region_check

#if __arm64__
_shared_region_check:
    mov x16, #294
    svc #0x80
    ret
#else
_shared_region_check:
    mov rax, 294
    syscall
    ret
#endif
