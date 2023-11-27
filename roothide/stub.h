#ifndef ROOTHIDE_H
#define ROOTHIDE_H

#pragma message("roothide disabled, using stub functions...")

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wnullability-completeness"

#include <string.h>

#ifdef __cplusplus
#include <string>
#endif

#ifdef __OBJC__
#import <Foundation/NSString.h>
#endif

//stub functions

#ifdef __cplusplus
extern "C" {
#endif

static const char* rootfs_alloc(const char* path) { return path ? strdup(path) : path; }
static const char* jbroot_alloc(const char* path) { return path ? strdup(path) : path; }
static const char* jbrootat_alloc(int fd, const char* path) { return path ? strdup(path) : path; }

static unsigned long long jbrand() { return 0; }
static const char* jbroot(const char* path) { return path; }
static const char* rootfs(const char* path) { return path; }

#ifdef __OBJC__
static NSString* _Nonnull __attribute__((overloadable)) jbroot(NSString* _Nonnull path) { return path; }
static NSString* _Nonnull __attribute__((overloadable)) rootfs(NSString* _Nonnull path) { return path; }
#endif

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
static std::string jbroot(std::string path) { return path; }
static std::string rootfs(std::string path) { return path; }
#endif

#pragma GCC diagnostic pop

#endif /* ROOTHIDE_H */
