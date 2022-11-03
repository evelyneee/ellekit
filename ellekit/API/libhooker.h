
struct LHFunctionHook {
    void* function;
    void *replacement;
    void *oldptr;
    struct LHFunctionHookOptions *options;
};

enum LHOptions {
    LHOptionsNone,
    LHOptionsSetJumpReg
};

struct LHFunctionHookOptions {
    enum LHOptions options;
    int jmp_reg;
};

enum LIBHOOKER_ERR {
    LIBHOOKER_OK = 0,
    LIBHOOKER_ERR_SELECTOR_NOT_FOUND = 1,
    LIBHOOKER_ERR_SHORT_FUNC = 2,
    LIBHOOKER_ERR_BAD_INSN_AT_START = 3,
    LIBHOOKER_ERR_VM = 4,
    LIBHOOKER_ERR_NO_SYMBOL = 5
};

struct LHMemoryPatch {
    void *destination;
    const void *data;
    size_t size;
    void *options;
};
