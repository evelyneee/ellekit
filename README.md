##  ElleKit

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
- iOS 16.1 (arm64)
- iOS 16.1 (arm64e)

### Used by
- Dopamine (jailbreak for A9-A11 on 15.0-16.6.1, A12-A14 + M1 on iOS 15.0-16.5.1 and A15-A16 + M2 on iOS 15.0-16.5)
- palera1n (jailbreak for A8-A11 on iOS 15.0+)
- meowbrek2 (jailbreak for A8-A11 on iOS 15.0-15.8.1)
- Def1nit3lyN0tAJa1lbr3akTool (jailbreak for A9-A11 on iOS 16.0-16.6.1)

### Usage

Use the Substrate API [header](https://github.com/theos/headers/blob/master/substrate.h) or the [libhooker](https://libhooker.com) API. 
You can also use the Swift functions directly

### How to load ElleKit on startup
See [here](./launchd-plist/LAUNCHDAEMON.md) for a guide on how to install a LaunchDaemon that loads ElleKit on startup.

### Building

To build a dynamic library, use Xcode 14. To build the library and the package, run `make deb`. For the macOS library, set MAC=1.
You can also use this as a Swift package.

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

ElleKit will only ever patch the functions you give it. If you hook a function within 128mb of address space, it will make a simple branch instruction and patch the function with it. 

If you hook beyond 128mb of address space, it'll set up an exception port to catch all breakpoint exceptions and handle them. Then, it'll patch the target with a `brk #1` instruction. ElleKit saves the hooks' target and replacement function and when the exception handler is called, it changes the thread state to redirect execution to the target, then resume execution. This might sound extremely inefficient but it's not too bad.

### The original function

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
