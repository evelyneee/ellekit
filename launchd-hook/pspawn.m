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
#include <stdarg.h> // v args

#include <mach-o/dyld.h>

#include <Foundation/Foundation.h>

#include "TweakInfo.h"
#include "TweakList.h"
#include <os/log.h>

int (*orig_spawn)(pid_t *restrict pid, const char *restrict path,
                    const posix_spawn_file_actions_t *file_actions,
                    const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
                                char *const envp[restrict]);

int (*orig_spawnp)(pid_t *restrict pid, const char *restrict path,
                    const posix_spawn_file_actions_t *file_actions,
                    const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
                                char *const envp[restrict]);

pid_t (*orig_waitpid)(pid_t pid, int *stat_loc, int options);

#if TARGET_OS_OSX // ElleKit Mac paths
#define PSPAWN_ENV "DYLD_INSERT_LIBRARIES=/Library/TweakInject/pspawn.dylib"
#define INJECTOR_ENV "DYLD_INSERT_LIBRARIES=/usr/local/lib/libinjector.dylib"
#define SUBSTRATE_PATH "/Library/Frameworks/ellekit.dylib"
#elif ROOTLESS // iOS/macOS rootless
#define PSPAWN_ENV "DYLD_INSERT_LIBRARIES=/var/jb/usr/lib/pspawn.dylib"
#define INJECTOR_ENV "DYLD_INSERT_LIBRARIES=/var/jb/usr/lib/libinjector.dylib"
#define SUBSTRATE_PATH "/var/jb/usr/lib/libsubstrate.dylib"
#else
#define PSPAWN_ENV "DYLD_INSERT_LIBRARIES=/usr/lib/pspawn.dylib"
#define INJECTOR_ENV "DYLD_INSERT_LIBRARIES=/usr/lib/libinjector.dylib"
#define SUBSTRATE_PATH "/usr/lib/libsubstrate.dylib"
#endif

TweakList* tweaks;
os_log_t logger;

char **
remove_dyld_env(const char* path, char **env)
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
        if (strstr(env[i], "DYLD_INSERT_LIBRARIES=") == 0) {
            newenv[i] = env[i];
        } else {
            os_log_with_type(logger, OS_LOG_TYPE_DEFAULT, "already got env for path %s, %s", path, env[i]);
            void* strbuf = malloc(100);
            strcpy(strbuf, "DYLD_NEVER_INSERT_LIBRARIES=null");
            newenv[i] = strbuf;
        }
    }
    return newenv;
}

char **
append_to_env(const char* path, char **env, bool launchd)
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
        if (strstr(env[i], "DYLD_INSERT_LIBRARIES=") == 0) {
            newenv[i] = env[i];
        } else {
            os_log_with_type(logger, OS_LOG_TYPE_DEFAULT, "already got env for path %s, %s", path, env[i]);
            void* strbuf = malloc(100);
            strcpy(strbuf, "DYLD_NEVER_INSERT_LIBRARIES=null");
            newenv[i] = strbuf;
        }
    }

    // Appends the new string to the new array.
    if (launchd) { // userspace reboot handler or xpcproxy hook
        newenv[env_size] = PSPAWN_ENV;
    } else {
        NSArray* tweakList = [tweaks tweakListForExecutableAtPath:[NSString stringWithUTF8String:path]];
        
        if ([tweakList count] == 0) return newenv;

        NSMutableArray* tweakPaths = [[NSMutableArray alloc] init];
        [tweakList enumerateObjectsUsingBlock:^(TweakInfo* obj, NSUInteger idx, BOOL* stop) {
            NSString* name = [obj dylib];
            [tweakPaths addObject:name];
        }];
        
        NSString* paths = [tweakPaths componentsJoinedByString:@":"];
        NSString* env = [@"DYLD_INSERT_LIBRARIES=" stringByAppendingString:paths];
        
        os_log_with_type(logger, OS_LOG_TYPE_DEFAULT, "modifying env for path %s to %s", path, [env UTF8String]);
        
        void* strbuf = malloc(1024);
        strcpy(strbuf, (char*)[env UTF8String]);
        newenv[env_size] = strbuf;
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
    os_log_with_type(logger, OS_LOG_TYPE_DEFAULT, "called hook with path %s", path);

    int ret;
    char** new_envp;
        
    bool should_inject = (strstr(path, "BlastDoor") == 0) && (strstr(path, "mobile_assertion_agent") == 0) && (strstr(path, "WebKit") == 0) && (strstr(path, "Safari") == 0);
    
    if (!should_inject) {
        ret = orig_spawn(pid, path, file_actions, attrp, argv, remove_dyld_env(path, (char**)envp));
        return ret;
    } else if (strstr(path, "launchd") != 0 || strstr(path, "xpcproxy") != 0)  {
        new_envp = append_to_env(path, (char**)envp, 1);
    } else {
        new_envp = append_to_env(path, (char**)envp, 0);
    }
    
    ret = orig_spawn(pid, path, file_actions, attrp, argv, new_envp);
        
    return ret;
}

int posix_spawnp_hook(
    pid_t *restrict pid,
    const char *restrict path,
    const posix_spawn_file_actions_t *file_actions,
    const posix_spawnattr_t *restrict attrp,
    char *const argv[restrict],
    char *const envp[restrict])
{
    os_log_with_type(logger, OS_LOG_TYPE_DEFAULT, "[p] called hook with path %s", path);

    int ret;
    char** new_envp;
    
    bool should_inject = (strstr(path, "BlastDoor") == 0) && (strstr(path, "mobile_assertion_agent") == 0) && (strstr(path, "WebKit") == 0) && (strstr(path, "Safari") == 0);

    if (!should_inject) {
        ret = orig_spawnp(pid, path, file_actions, attrp, argv, envp);
        return ret;
    } else if (strstr(path, "launchd") != 0 || strstr(path, "xpcproxy") != 0)  {
        new_envp = append_to_env(path, (char**)envp, 1);
    } else {
        new_envp = append_to_env(path, (char**)envp, 0);
    }
    
    ret = orig_spawnp(pid, path, file_actions, attrp, argv, new_envp);
        
    return ret;
}

// hook sandbox to allow this:
/*
 int read_denied = sandbox_check (pid, "file-read-data",  SANDBOX_FILTER_PATH  | SANDBOX_CHECK_NO_REPORT, path);
 int write_denied = sandbox_check (pid, "file-write-data", SANDBOX_FILTER_PATH | SANDBOX_CHECK_NO_REPORT, path);
 */

int (*sandbox_check_orig)(pid_t pid, const char *op, int type, ...);

// thx substitute
int sandbox_check_hook(pid_t pid, const char *op, int type, ...) {
    /* Can't easily determine the number of arguments, so just assume there's
     * less than 5 pointers' worth. */
    va_list ap;
    va_start(ap, type);
    long blah[5];
    for (int i = 0; i < 5; i++)
        blah[i] = va_arg(ap, long);
    va_end(ap);
    if (!strcmp(op, "file-read-data") || !strcmp(op, "file-write-data")) {
        const char *name = (void *) blah[0];
        if (!strstr(name, "/Library/MobileSubstrate") || !strstr(name, "TweakInject")) {
            /* always allow looking up dylibs */
            return 0;
        }
    }
    return sandbox_check_orig(pid, op, type,
                             blah[0], blah[1], blah[2], blah[3], blah[4]);
}

extern intptr_t _dyld_get_image_slide(const struct mach_header* mh);

static int (*MSHookFunction)(void*, void*, void**);

__attribute__((constructor))
static void hook_entry(void) {
    void* ekhandle = dlopen(SUBSTRATE_PATH, RTLD_NOW);
    MSHookFunction = dlsym(ekhandle, "MSHookFunction");
    tweaks = [TweakList sharedInstance];
    
    logger = os_log_create("red.charlotte.ellekit", "pspawn");
    os_log_with_type(logger, OS_LOG_TYPE_DEFAULT, "Starting posix_spawn hook");
    
    MSHookFunction(&posix_spawn, &posix_spawn_hook, (void*)&orig_spawn);
    MSHookFunction(&posix_spawnp, &posix_spawnp_hook, (void*)&orig_spawnp);
    // MSHookFunction(dlsym(RTLD_DEFAULT, "sandbox_check"), &sandbox_check_hook, (void*)&sandbox_check_orig);
    printf("hook done\n");
}
