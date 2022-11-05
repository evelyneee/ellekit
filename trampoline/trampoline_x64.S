#if defined(__x86_64__)
.intel_syntax noprefix

.extern execl, setenv, puts
.global _main

.text

_main:

    push    rax
    movabs  r8, offset .helloworld
    mov     rdi, r8
    call    _puts
    
    movabs  r8,  offset .dyld_insert_libraries
    mov     rdi, r8
    movabs  r8,  offset .dylib_path
    mov     rsi, r8
    mov     rdx, 1
    call    _setenv
    
    test    rax, rax
    jne     exec_and_check
    
    movabs  r8,  offset .env_set_success
    mov     rdi, r8
    call    _puts
        
exec_and_check:

    movabs  r8,  offset .bin_path
    mov     rdi, r8
    mov     rsi, r8
    xor     rax, rax
    call    _execl
    
    test    rax, rax
    je      print_success
    
    movabs  r8,  offset .failed_to_call
    mov     rdi, r8
    call    _puts
        
print_success:

    movabs  r8,  offset .success
    mov     rdi, r8
    call    _puts
    
    xor     rax, rax
    pop     rcx
    ret

.align 4

.data

.helloworld:
    .asciz  "[Trampoline] Hello world!"

.dyld_insert_libraries:
    .asciz  "DYLD_INSERT_LIBRARIES"

.dylib_path:
    .asciz  "/Applications/Messages.app/Contents/MacOS/hook.dylib"

.env_set_success:
    .asciz  "[Trampoline] Env setting success"

.bin_path:
    .asciz  "/Applications/Messages.app/Contents/MacOS/Messages_original"

.failed_to_call:
    .asciz  "[Trampoline] Failed to call, resign CrossOver_original"

.success:
    .asciz  "[Trampoline] Called binary, goodbye"

#endif
