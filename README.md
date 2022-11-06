##  ElleKit: Elegant Low Level Elements

### What this is

- A C function hooker that patches memory pages directly
- An Objective-C function hooker
- An arm64 assembler
- A JIT inline assembly implementation for Swift
- A Substrate and libhooker API reimplementation

### Requirements

- A arm64 device running the XNU kernel

### Tested configurations

- macOS Ventura (arm64)
- macOS Ventura (arm64e)

### Usage

Use the Substrate API [header](https://github.com/theos/headers/blob/master/substrate.h) or the [libhooker](https://libhooker.com) API. 
You can also use the Swift functions directly

### Building

Use Xcode 14. Just run `xcodebuild`

### Status

- Can hook most C functions on arm64 and arm64e
    - Works on functions with 1 instruction beyond 128mb of address space
    - Allows making faster hooks for functions within 128mb of address space
    - Can hook functions without symbols if you provide a pointer to the function
- Can hook Objective-C messages with the original implementation being kept
- Can hook Objective-C class pairs (MSHookClassPair)
- Assembles these instructions: 
    - `add`, `sub`
    - `b`, `bl`, `br`, `blr` 
    - `movz`, `movk`
    - `svc`
    - `csel` with all parameters
    - `ldr` and `str`
    - `ret`, `nop`
- Implements the Substrate API
- Implements the libhooker API

### The C hooking technique

ElleKit will only ever patch the functions you give it. If you hook a function within 128mb of address space, it will make a simple branch instruction and patch the function with it. If you hook beyond 128mb of address space, it'll set up an exception port to catch all breakpoint exceptions and handle them. ElleKit saves the hooks' target and replacement function and when the exception handler is called, it changes the thread state to redirect execution to the target. 

### The original function technique

ElleKit writes the original function implementation to a new memory page and then provides a pointer to it. If you use `LHHookFunctions`, it will use one page for the orig functions, which will be faster than allocating a new one for each hook. Orig functions are assembled like so: 

```arm64
// Insert address to target function
movk x16, target_addr % 65536)
movk x16, (target_addr / 65536) % 65536 lsl: 16
movk x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32
movk x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48

// Jump first instruction (the branch to the replacement, aka what we patched)
add x16, x16, 4 

// Execute the skipped instruction
[4 first unpatched bytes of the target function]

// Call the target function
br x16
```
