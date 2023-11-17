#include <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <objc/message.h>

//#import "WLog.h"


#ifndef IPA
#include <pthread.h>

static void performBlockOnProperThread(void (^block)(void)) {
  if (pthread_main_np()) {
    block();
  } else {
    dispatch_async(dispatch_get_main_queue(), block);
  }
}

// The original objc_msgSend.
static id (*orig_objc_msgSend)(id, SEL, ...) = NULL;

// HashMap functions.
static int pointerEquality(void *a, void *b) {
  uintptr_t ia = reinterpret_cast<uintptr_t>(a);
  uintptr_t ib = reinterpret_cast<uintptr_t>(b);
  return ia == ib;
}

extern "C" void * NullGetOriginal(){
    return (void *)orig_objc_msgSend;
}
    
// arm64(e) witchcraft

struct OrigAndReturn {
  uintptr_t orig;
  uintptr_t ret;
};

struct OrigAndReturn hookmanager(id self, SEL _cmd, uint64_t arg2, uint64_t arg3, uint64_t arg4, uint64_t arg5, uint64_t arg6, uint64_t arg7, ...) asm("hookman");

typedef id (*null_callback)(id self, SEL _cmd, uint64_t arg2, uint64_t arg3, uint64_t arg4, uint64_t arg5, uint64_t arg6, uint64_t arg7, uint64_t arg8, uint64_t arg9, uint64_t arg10);

typedef struct {
    int atNumber;
    int bNumber;
    int colonNumber;
    int pointerNumber;
} NumberParsingResult;

NumberParsingResult parseTypeEncodingNumbers(const char* encoding) {
    NumberParsingResult result;
    result.atNumber = 0;
    result.bNumber = 0;
    result.colonNumber = 0;
    result.pointerNumber = 0;

    const char* currentChar = encoding;

    while (*currentChar != '\0') {
        if (*currentChar == '@') {
            result.atNumber = atoi(currentChar + 1);
        } else if (*currentChar == 'B') {
            result.bNumber = atoi(currentChar + 1);
        } else if (*currentChar == ':') {
            result.colonNumber = atoi(currentChar + 1);
        } else if (*currentChar == '^') {
            result.pointerNumber = atoi(currentChar + 1);
        }

        currentChar++;
    }

    return result;
}

typedef struct {
    struct {
        void* buffer;
        UInt32 length;
        CFAllocatorRef contentsDeallocator;
    } notInlineImmutable1;
    struct {
        void* buffer;
        CFAllocatorRef contentsDeallocator;
    } notInlineImmutable2;
    struct {
        void* buffer;
        UInt32 length;
        UInt32 capacityFields;
        UInt32 gapEtc;
        CFAllocatorRef contentsAllocator;
    } notInlineMutable;
} CFStringInternal;

#define BUFFER_SIZE 256

char* findEndOfObjCType(const char* input) {
    int length = 0;  // Length of the string

    while (input[length] != '\0' && input[length] != '}' && input[length] != '=') {
        length++;
    }

    char* output = (char*)malloc((length + 1) * sizeof(char));
    if (output == NULL) {
        printf("Error: Memory allocation failed.\n");
        return NULL;
    }

    strncpy(output, input, length);
    output[length] = '\0';  // Add null-terminating character at the end
    
    return output;
}

int findOffsetObjCType(const char* input) {
    int length = 0;  // Length of the string

    while (input[length] != '\0' && input[length] != '}') {
        length++;
    }

    return atoi(input+length+1);
}

struct OrigAndReturn hookmanager(id self, SEL _cmd, uint64_t arg2, uint64_t arg3, uint64_t arg4, uint64_t arg5, uint64_t arg6, uint64_t arg7, ...) {
    
    Class cls = object_getClass(self);
    Method method = class_getInstanceMethod(cls, _cmd);
    const char *encoding = method_getTypeEncoding(method);
    NumberParsingResult result = parseTypeEncodingNumbers(encoding);
    const char* currentChar = encoding;
    
    //printf("%s\n", encoding);
        
    if (*currentChar == 'B') {
        printf("BOOL ");
    }
    
    if (*currentChar == 'Q') {
        printf("id ");
    }
    
    if (*currentChar == 'v') {
        printf("void ");
    }
    
    if (*currentChar == '#') {
        printf("Class ");
    }
    
    printf("%s.%s(", class_getName(object_getClass(self)), sel_getName(_cmd));
        
    currentChar++;
    
    while (*currentChar != '\0') {
        if (*currentChar == '@') {
            int offset = atoi(currentChar + 1);
            if (offset != 0) {
                uint64_t result;
                switch (offset / 8) {
                    case 2:
                        result = arg2;
                        break;
                    case 3:
                        result = arg3;
                        break;
                    case 4:
                        result = arg4;
                        break;
                    case 5:
                        result = arg5;
                        break;
                    case 6:
                        result = arg6;
                        break;
                    case 7:
                        result = arg7;
                        break;
                    default:
                        // Handle the case when the number is outside the expected range
                        result = -1;  // Or any other appropriate value
                        break;
                }
                if (result != -1 && result > 0x4000) {
                    printf("arg%d: ", offset / 8 - 2);
                    printf("<0x%02llX", result);
                    if (!strcmp("__NSCFConstantString", class_getName(object_getClass((__bridge id)result)))) {
                        const char* str = (const char*)orig_objc_msgSend((__bridge id)result, sel_getUid("UTF8String"));
                        printf(", __NSCFConstantString, \"%s\">", str);
                    } else if (result > 0x4000) {
                        printf(" <%s 0x%02llX>", class_getName(object_getClass((__bridge id)result)), result);
                    }
                    printf(", ");
                }
            }
        } else if (*currentChar == 'B') {
            
            int offset = atoi(currentChar + 1);
            if (offset == 0) break;
            uint64_t result;
            
            switch (offset / 8) {
                case 2:
                    result = arg2;
                    break;
                case 3:
                    result = arg3;
                    break;
                case 4:
                    result = arg4;
                    break;
                case 5:
                    result = arg5;
                    break;
                case 6:
                    result = arg6;
                    break;
                case 7:
                    result = arg7;
                    break;
                default:
                    // Handle the case when the number is outside the expected range
                    result = -1;  // Or any other appropriate value
                    break;
            }
            if (result != -1) {
                printf("arg%d: ", offset / 8 - 2);
                if (!!result) printf("true");
                else printf("false");
            }
            printf(", ");
        } else if (*currentChar == ':') {
            result.colonNumber = atoi(currentChar + 1);
        } else if (*currentChar == '^') {
            char type = *(currentChar + 1);
            int offset = atoi(currentChar + 2);
            if (offset == 0) break;
            uint64_t result;
            
            switch (offset / 8) {
                case 2:
                    result = arg2;
                    break;
                case 3:
                    result = arg3;
                    break;
                case 4:
                    result = arg4;
                    break;
                case 5:
                    result = arg5;
                    break;
                case 6:
                    result = arg6;
                    break;
                case 7:
                    result = arg7;
                    break;
                default:
                    // Handle the case when the number is outside the expected range
                    result = -1;  // Or any other appropriate value
                    break;
            }
            if (result != -1) {
                printf("arg%d: ", offset / 8 - 2);
                printf("<*%c, 0x%02llX>", type, result);
            }
            printf(", ");
        } else if (*currentChar == '{') {
            int offset = findOffsetObjCType(currentChar+1);
            if (offset != 0) {
                uint64_t result;
                switch (offset / 8) {
                    case 2:
                        result = arg2;
                        break;
                    case 3:
                        result = arg3;
                        break;
                    case 4:
                        result = arg4;
                        break;
                    case 5:
                        result = arg5;
                        break;
                    case 6:
                        result = arg6;
                        break;
                    case 7:
                        result = arg7;
                        break;
                    default:
                        // Handle the case when the number is outside the expected range
                        result = -1;  // Or any other appropriate value
                        break;
                }
                printf("arg%d: ", offset / 8 - 2);
                if (result == 0) {
                    printf("<NULL %s>", findEndOfObjCType(currentChar+1));
                } else if (result != -1) {
                    printf("<0x%02llX %s>", result, findEndOfObjCType(currentChar+1));
                } else {
                    printf("<Internal Error: No argument>");
                }
            }
            printf(", ");
       }

        currentChar++;
    }
    printf(");\n");
        
    return (struct OrigAndReturn) {(uintptr_t)(orig_objc_msgSend), 0};
}
__attribute__((__naked__)) static void replacementObjc_msgSend() {
  __asm__ volatile (
                    "stp q6, q7, [sp, #-32]!\n"
                    "stp q4, q5, [sp, #-32]!\n"
                    "stp q2, q3, [sp, #-32]!\n"
                    "stp q0, q1, [sp, #-32]!\n"
                    "stp x10, x13, [sp, #-16]!\n"
                    "stp x8, lr, [sp, #-16]!\n"
                    "stp x6, x7, [sp, #-16]!\n"
                    "stp x4, x5, [sp, #-16]!\n"
                    "stp x2, x3, [sp, #-16]!\n"
                    "stp x0, x1, [sp, #-16]!\n"
                    "bl hookman\n"
                    "bic x9, x0, #0xFFFFFF8000000000\n"
                    "mov x10, x1\n"
                    "ldp x0, x1, [sp], #16\n"
                    "ldp x2, x3, [sp], #16\n"
                    "ldp x4, x5, [sp], #16\n"
                    "ldp x6, x7, [sp], #16\n"
                    "ldp x8, lr, [sp], #16\n"
                    "ldp x10, x13, [sp], #16\n"
                    "ldp q0, q1, [sp], #32\n"
                    "ldp q2, q3, [sp], #32\n"
                    "ldp q4, q5, [sp], #32\n"
                    "ldp q6, q7, [sp], #32\n"
                    "cbz x9, Lnocall\n"
                    
                    "br x9\n"
                    "Lnocall:\n"
                    "mov x0, x10\n"
                    "ret\n"
    );
}
#endif

extern "C" void MSHookFunction(void* t, void* d, void** orig);
extern "C" void MSHookMemory(void *target, const void *data, size_t size);

__attribute__((constructor)) static void inject() {
    NSLog(@"Inject function is starting...");

    #ifndef IPA

    NSLog(@"Hooking objc_msgSend...");
    const uint8_t patch[] = {
        0xF0, 0x47, 0xC1, 0xDA
    };
    MSHookMemory((void*)(((uintptr_t)&objc_msgSend) + 24), patch, 4);
    MSHookFunction((void*)&objc_msgSend, (void *)&replacementObjc_msgSend, (void **)&orig_objc_msgSend);
    #endif

    NSLog(@"Inject function finished");
    
    NSURL* obj = [[NSURL alloc] initFileURLWithPath:@"/"];
    NSLog(@"%@", obj);
}
