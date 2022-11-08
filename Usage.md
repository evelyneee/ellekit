## C Function Hooking

### Hooking functions from Swift

You can hook C functions with an orig function like this: 

```swift
let atoiC: @convention(c) (UnsafePointer<CChar>?) -> Int32 = atoi
let repC: @convention(c) () -> Int32 = Replacement
let orig = hook(
    unsafeBitCast(atoiC, to: UnsafeMutableRawPointer.self),
    unsafeBitCast(repC, to: UnsafeMutableRawPointer.self)
)
```

You can hook C functions without an orig function like this: 

```swift
hook(
    target,
    replacement
)
```

You can also use the Substrate API, like this: 

```swift
let atoiC: @convention(c) (UnsafePointer<CChar>?) -> Int32 = atoi
let repC: @convention(c) () -> Int32 = Replacement
let orig = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 10)
MSHookFunction(
    unsafeBitCast(atoiC, to: UnsafeMutableRawPointer.self),
    unsafeBitCast(repC, to: UnsafeMutableRawPointer.self),
    orig
)
```

The orig variable holds a pointer to the original implementation of the target, which is now located in another page.

## Objective-C Function Hooking

section is todo
use substrate or libhooker api!
