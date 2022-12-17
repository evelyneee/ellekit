
#include "pac.h"
#include <ptrauth.h>
#include <mach/arm/thread_status.h>

void* sign_pointer(void* ptr) {
#if __arm64e__
    return ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
#else
    return ptr;
#endif
}

void set_pc(void* ptr, arm_thread_state64_t* state) {
    __darwin_arm_thread_state64_set_pc_fptr(
        *state,
        ptr
    );
}

void set_sp(void* ptr, arm_thread_state64_t* state) {
    __darwin_arm_thread_state64_set_sp(*state, ptr);
}

void* strip_pointer(void* ptr) {
#if __arm64e__
    return ptrauth_strip(ptr, ptrauth_key_function_pointer);
#else
    return ptr;
#endif
}

// MARK: - Safe boot

#include <sys/sysctl.h>

#if TARGET_OS_OSX
int safe_boot(void) {
    size_t size = 0;
    sysctlbyname("kern.bootargs", NULL, &size, NULL, 0);
    char* bootargs = malloc(size);
    sysctlbyname("kern.bootargs", bootargs, &size, NULL, 0);
    return strstr(bootargs, "-x") != 0;
}
#else
int safe_boot(void) {
    return 0;
}
#endif

// MARK: - Mach-O

#include <stdio.h>
#include <mach-o/loader.h>
#include <stdlib.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>

char** get_segment_bundles(const char* macho_path) {
    // Read the Mach-O header
    struct dl_info info;
    
    dladdr(&get_segment_bundles, &info);
    
    struct mach_header_64 *_mh = info.dli_fbase;
    struct mach_header_64 mh = *_mh;
    
    void *fp = info.dli_fbase;
    
    // Allocate an array to hold the names of the files in the LC_SEGMENT_64 load commands
    char** filenames = malloc(sizeof(char*) * mh.ncmds);
    int filename_count = 0;
    
    printf("%d\n", mh.ncmds);
    
    // Iterate over the load commands
    for (int i = 0; i < mh.ncmds; i++) {
        // Read the load command
        struct load_command *lc = (fp + sizeof(struct load_command));
                
        // Check the type of the load command
        if ((*lc).cmd == LC_SEGMENT_64) {
            // Extract the file name from the LC_SEGMENT_64 load command
            struct segment_command_64 *_sc = (fp + sizeof(struct segment_command_64));
            struct segment_command_64 sc = *_sc;
            char* segname = strdup(sc.segname);
            printf("segment: %s\n", segname);
            CFURLRef bin_path = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFStringCreateWithCString(kCFAllocatorDefault, segname, kCFStringEncodingASCII), kCFURLPOSIXPathStyle, 0);
            if (!bin_path) continue;
            CFURLRef path = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorDefault, bin_path);
            if (!path) continue;
            CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, path);
            if (!bundle) continue;
            CFStringRef cfid = CFBundleGetIdentifier(bundle);
            const char* id = CFStringGetCStringPtr(cfid, kCFStringEncodingASCII);
            filenames[filename_count] = (char*)id;
            filename_count++;
        }
    }
    
    // Resize the array to the actual number of filenames
    filenames = realloc(filenames, sizeof(char*) * filename_count);
    
    // Close the Mach-O file
    fclose(fp);
    return filenames;
}
