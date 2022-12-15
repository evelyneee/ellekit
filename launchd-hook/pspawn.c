//
//  spawn.c
//  posixspawn-hook
//
//  Created by charlotte on 2022-12-14.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <spawn.h>

#include <mach-o/dyld.h>

int (*orig_spawn)(pid_t *restrict pid, const char *restrict path,
                    const posix_spawn_file_actions_t *file_actions,
                    const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
                                char *const envp[restrict]);

int (*orig_spawnp)(pid_t *restrict pid, const char *restrict path,
                    const posix_spawn_file_actions_t *file_actions,
                    const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
                                char *const envp[restrict]);

pid_t (*orig_waitpid)(pid_t pid, int *stat_loc, int options);


extern char*** _NSGetEnviron(void);

// stolen from apple libc
char **
append_to_env(char **env, bool launchd)
{
    // Determines the size of the array by counting the number of strings
    // until it reaches a null pointer.
    int env_size = 0;
    while (env[env_size] != NULL) {
        env_size++;
    }

    // Allocates a new array with enough space to hold the existing strings
    // plus the new string.
    char **newenv = (char**)malloc(sizeof(char*) * (env_size + 2));

    // Copies the strings from the old array to the new array.
    for (int i = 0; i < env_size; i++) {
        newenv[i] = env[i];
    }

    // Appends the new string to the new array.
    if (launchd) { // userspace reboot handler or xpcproxy hook
        newenv[env_size] = "DYLD_INSERT_LIBRARIES=/usr/local/lib/pspawn.dylib";
    } else {
        newenv[env_size] = "DYLD_INSERT_LIBRARIES=/usr/local/lib/libinjector.dylib";
    }
    
    // Adds a null pointer to the end of the array to mark the end of the list.
    newenv[env_size + 1] = NULL;
    
    return newenv;
}

int posix_spawn_hook(
    pid_t *restrict pid,
    const char *restrict path,
    const posix_spawn_file_actions_t *file_actions,
    const posix_spawnattr_t *restrict attrp,
    char *const argv[restrict],
    char *const envp[restrict]
) {
    puts("called hooked posix_spawn!");
        
    char** new_envp;
    
    if (strcmp(path, "/sbin/launchd") == 0 || strcmp(path, "/usr/libexec/xpcproxy") == 0)  {
        new_envp = append_to_env((char**)envp, 1);
    } else {
        new_envp = append_to_env((char**)envp, 0);
    }
    
    int ret = orig_spawn(pid, path, file_actions, attrp, argv, new_envp);
    
    return ret;
}

int posix_spawnp_hook(
    pid_t *restrict pid,
    const char *restrict path,
    const posix_spawn_file_actions_t *file_actions,
    const posix_spawnattr_t *restrict attrp,
    char *const argv[restrict],
    char *const envp[restrict]
) {
    puts("called hooked posix_spawnp!");
        
    char** new_envp;
    
    new_envp = append_to_env((char**)envp, 0);

    int ret = orig_spawnp(pid, path, file_actions, attrp, argv, new_envp);
    
    return ret;
}

//pid_t waitpid_hook(pid_t pid, int *stat_loc, int options) {
//    pid_t ret = old_waitpid(pid, stat_loc, options);
//    after_wait_generic(ret, *stat_loc);
//    return ret;
//}

extern intptr_t _dyld_get_image_slide(const struct mach_header* mh);

static int (*MSHookFunction)(void*, void*, void**);

__attribute__((constructor))
static void hook_entry(void) {
    void* ekhandle = dlopen("/usr/local/lib/libsubstrate.dylib", RTLD_NOW);
    MSHookFunction = dlsym(ekhandle, "MSHookFunction");
    MSHookFunction(&posix_spawn, &posix_spawn_hook, (void*)&orig_spawn);
    MSHookFunction(&posix_spawnp, &posix_spawnp_hook, (void*)&orig_spawnp);
    printf("hook done\n");
}
