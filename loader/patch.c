
#include <stdio.h>
#include <stdlib.h>
#include <spawn.h>

void* sign_pointer(void* ptr) {
#if __arm64e__
    return ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
#else
    return ptr;
#endif
}

void* sign_pc(void* ptr) {
#if __arm64e__
    return ptrauth_sign_unauthenticated(ptr, ptrauth_key_process_independent_code, 0x7481);
#else
    return ptr;
#endif
}

void* strip_pointer(void* ptr) {
#if __arm64e__
    return ptrauth_strip(ptr, ptrauth_key_function_pointer);
#else
    return ptr;
#endif
}

// 44594C445F494E534552545F4C49425241524945533D222F7573722F6C6F63616C2F6C69622F6C6962696E6A6563746F722E64796C696222

__attribute__((aligned(0x4000)))
char* buildstr(char *const argv[restrict]) { // build the string DYLD_INSERT_LIBRARIES="/usr/local/lib/libinjector.dylib"
    
    char var44 = 0x44;
    char var59 = 0x59;
    char var4C = 0x4C;
    char var5F = 0x5F;
    char var49 = 0x49;
    char var4E = 0x4E;
    char var53 = 0x53;
    char var45 = 0x45;
    char var52 = 0x52;
    char var54 = 0x54;
    char var42 = 0x42;
    char var41 = 0x41;
    char var3D = 0x3D;
    char var22 = 0x22;
    char var2F = 0x2F;
    char var75 = 0x75;
    char var73 = 0x73;
    char var72 = 0x72;
    char var6C = 0x6C;
    char var6F = 0x6F;
    char var63 = 0x63;
    char var61 = 0x61;
    char var69 = 0x69;
    char var62 = 0x62;
    char var6E = 0x6E;
    char var6A = 0x6A;
    char var65 = 0x65;
    char var74 = 0x74;
    char var2E = 0x2E;
    char var64 = 0x64;
    char var79 = 0x79;
    
    char string[] = {
        var44,
        var59,
        var4C,
        var44,
        var5F,
        var49,
        var4E,
        var53,
        var45,
        var52,
        var54,
        var5F,
        var4C,
        var49,
        var42,
        var52,
        var41,
        var52,
        var49,
        var45,
        var53,
        var3D,
        var22,
        var2F,
        var75,
        var73,
        var72,
        var2F,
        var6C,
        var6F,
        var63,
        var61,
        var6C,
        var2F,
        var6C,
        var69,
        var62,
        var2F,
        var6C,
        var69,
        var62,
        var69,
        var6E,
        var6A,
        var65,
        var63,
        var74,
        var6F,
        var72,
        var2E,
        var64,
        var79,
        var6C,
        var69,
        var62,
        var22,
        0x00
    };
    
    char* last = string;
    while (*last != 0x00) last++;
    last = string;
        
    return string;
}

static void* patch_alloc(void) {
    return malloc(1024);
}

__attribute__((optnone))
void posix_spawn_patch (
        pid_t *restrict pid,
        const char *restrict path,
        const posix_spawn_file_actions_t *file_actions,
        const posix_spawnattr_t *restrict attrp,
        char *const argv[restrict],
        char * envp[restrict]
) {
    // then we exec the first 5 instructions
    __asm__("pacibsp");
    
    void* alloc = patch_alloc();
    
    char var44 = 0x44;
    char var59 = 0x59;
    char var4C = 0x4C;
    char var5F = 0x5F;
    char var49 = 0x49;
    char var4E = 0x4E;
    char var53 = 0x53;
    char var45 = 0x45;
    char var52 = 0x52;
    char var54 = 0x54;
    char var42 = 0x42;
    char var41 = 0x41;
    char var3D = 0x3D;
    char var22 = 0x22;
    char var2F = 0x2F;
    char var75 = 0x75;
    char var73 = 0x73;
    char var72 = 0x72;
    char var6C = 0x6C;
    char var6F = 0x6F;
    char var63 = 0x63;
    char var61 = 0x61;
    char var69 = 0x69;
    char var62 = 0x62;
    char var6E = 0x6E;
    char var6A = 0x6A;
    char var65 = 0x65;
    char var74 = 0x74;
    char var2E = 0x2E;
    char var64 = 0x64;
    char var79 = 0x79;
        
    alloc = (char[]){
        var44,
        var59,
        var4C,
        var44,
        var5F,
        var49,
        var4E,
        var53,
        var45,
        var52,
        var54,
        var5F,
        var4C,
        var49,
        var42,
        var52,
        var41,
        var52,
        var49,
        var45,
        var53,
        var3D,
        var22,
        var2F,
        var75,
        var73,
        var72,
        var2F,
        var6C,
        var6F,
        var63,
        var61,
        var6C,
        var2F,
        var6C,
        var69,
        var62,
        var2F,
        var6C,
        var69,
        var62,
        var69,
        var6E,
        var6A,
        var65,
        var63,
        var74,
        var6F,
        var72,
        var2E,
        var64,
        var79,
        var6C,
        var69,
        var62,
        var22,
        0x00
    };
    
    char* last = *envp;
    while (*last != 0x00) last++;
    last = alloc;
}
__asm__("pacibsp");
__asm__("sub sp, sp, #0xe0");
__asm__("stp x26, x25, [sp, #0x90]");
__asm__("stp x24, x23, [sp, #0xa0]");
__asm__("stp x22, x21, [sp, #0xb0]");
__asm__("ret");

extern void posix_spawn_patch_routine(void);

void* patch_addr(void) {
    return (void*)posix_spawn_patch_routine;
}
