
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

#include "injector.h"

#include <CoreFoundation/CoreFoundation.h>
#include <objc/runtime.h>
#include <dirent.h>
#include <dlfcn.h>
#include <os/log.h>

static int compare(const void *a, const void *b) {
    return strcmp(*(const char **)a, *(const char **)b);
}

#if TARGET_OS_OSX
#define TWEAKS_DIRECTORY "/Library/TweakInject/"
#else
#define TWEAKS_DIRECTORY "/var/jb/usr/lib/TweakInject/"
#endif

CFStringRef copyAndLowercaseCFString(CFStringRef input) {
    CFMutableStringRef mutableCopy = CFStringCreateMutableCopy(NULL, 0, input);
    CFStringLowercase(mutableCopy, NULL);
    return CFStringCreateCopy(NULL, mutableCopy);
}

#warning "Add bundle checks, needs choicy code"
static bool tweak_needinject(const char* orig_path) {
    
    CFStringRef plistPath;
    CFURLRef url;
    CFDataRef data;
    CFPropertyListRef plist;
    
    char* path = malloc(strlen(orig_path)+7);
    strcpy(path, orig_path);
    strcat(path, ".plist");
    
    os_log(os_log_create("red.charlotte.injector", "ellekit"), "now loading: %s", path);
    
    plistPath = CFStringCreateWithCString(kCFAllocatorDefault, path, kCFStringEncodingUTF8);
            
    if (!!access(path, F_OK)) {
        free(path);
        CFRelease(plistPath);
        return false;
    }
    
    free(path);
    
    url = CFURLCreateWithFileSystemPath(kCFAllocatorSystemDefault, plistPath, kCFURLPOSIXPathStyle, false);
        
    if (url && CFURLCreateDataAndPropertiesFromResource(kCFAllocatorSystemDefault, url, &data, NULL, NULL, NULL)) {
        plist = CFPropertyListCreateWithData(kCFAllocatorSystemDefault, data, kCFPropertyListImmutable, NULL, NULL);
        CFRelease(data);
    } else {
        CFRelease(plistPath);
        return false;
    }
    CFRelease(url);
    CFRelease(plistPath);
                            
    CFDictionaryRef filter = CFDictionaryGetValue(plist, CFSTR("Filter"));
    CFArrayRef bundles = CFDictionaryGetValue(filter, CFSTR("Bundles"));
    
    if (bundles) {
        for (CFIndex i = 0; i < CFArrayGetCount(bundles); i++) {
            CFStringRef id = CFArrayGetValueAtIndex(bundles, i);
            
            if (CFBundleGetBundleWithIdentifier(id) || CFBundleGetBundleWithIdentifier(copyAndLowercaseCFString(id))) {
                goto success;
            }
        }
    }
    
    CFArrayRef classes = CFDictionaryGetValue(filter, CFSTR("Classes"));
    
    if (classes) {
        for (CFIndex i = 0; i < CFArrayGetCount(classes); i++) {
            CFStringRef id = CFArrayGetValueAtIndex(classes, i);
                                            
            char* str = malloc(CFStringGetLength(id)+1);
            
            CFStringGetCString(id, str, CFStringGetLength(id)+1, kCFStringEncodingASCII);
                        
            if (objc_getClass(str)) {
                free(str);
                goto success;
            }
            
            free(str);
        }
    }
    
    CFRelease(plist);
    return false;
    
success:
    CFRelease(plist);
    return true;
}

static void tweaks_iterate() {
    DIR *dir;
    struct dirent *ent;
    char **files;
    int i, n;

    dir = opendir(TWEAKS_DIRECTORY);
    if (dir == NULL) {
        perror("opendir");
        exit(EXIT_FAILURE);
    }

    n = 0;
    while ((ent = readdir(dir)) != NULL) {
        if (ent->d_type == DT_REG) {
            n++;
        }
    }

    rewinddir(dir);
    
    if (n == 0) {
        return;
    }

    files = malloc(n * sizeof(char *));
    if (files == NULL) {
        perror("malloc");
        exit(EXIT_FAILURE);
    }

    i = 0;
    while ((ent = readdir(dir)) != NULL) {
        if (ent->d_type == DT_REG) {
            files[i] = strdup(ent->d_name);
            i++;
        }
    }

    qsort(files, n, sizeof(char *), compare);

    for (i = 0; i < n; ++i) {
        if (!!strstr(files[i], ".dylib")) {
            
            char *full_path = (char *) malloc(strlen(TWEAKS_DIRECTORY) + strlen(files[i]) + 1);
            
            strcat(full_path, TWEAKS_DIRECTORY);
            strcat(full_path, files[i]);
            
            char* plist = strdup(full_path);
            *(plist + strlen(plist) - 6) = '\0';
            
            bool ret = tweak_needinject(plist);
            if (ret) {
                dlopen(full_path, RTLD_NOW);
            }
            free(full_path);
        }
        free(files[i]);
    }
    
    free(files);

    closedir(dir);
}

__attribute__((constructor))
static void injection_init() {
    const char* extension = getenv("SANDBOX_EXTENSION");
    if (extension) {
        sandbox_extension_consume(extension);
    }
    tweaks_iterate();
}
