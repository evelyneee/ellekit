// my playground!

import Foundation
import ellekit

let mapping = try ellekit.openImage(image: "/usr/lib/system/libdyld.dylib")
let image = try ellekit.openImage(image: "/usr/local/lib/libsubstrate.dylib")

try ellekit.findSymbol(image: image!)

print(image?.pointee)

exit(0)

EKEnableThreadSafety(1)

let atoiptr = dlsym(dlopen(nil, RTLD_NOW), "atoi")!

@_cdecl("rep")
public func rep() -> Int {
    2
}

let repcl: @convention(c) () -> Int = rep

let repptr = unsafeBitCast(repcl, to: UnsafeMutableRawPointer.self)

DispatchQueue.global().async {
    while true {
        let two = atoi("3")
        if two == 2 {
            break
        }
    }
    print("hooked fine")
}

let test: UnsafeMutableRawPointer? = hook(atoiptr, repptr)!

let origRes = unsafeBitCast(test, to: (@convention (c) (UnsafePointer<CChar>) -> Int).self)("4")

print(
    atoi("3"),
    origRes
)

let nspopptr = dlsym(dlopen(nil, RTLD_NOW), "NSPopAutoreleasePool")!

@_cdecl("nspoprep")
public func nspoprep() -> Int {
    2
}

let nspoprepcl: @convention(c) () -> Int = nspoprep

let nspoprepptr = unsafeBitCast(nspoprepcl, to: UnsafeMutableRawPointer.self)

let test2: UnsafeMutableRawPointer = hook(nspopptr, nspoprepptr)!

func test3() {
    let h = unsafeBitCast(nspopptr, to: (@convention (c) () -> Int).self)()

    print(h)
}
test3()

// unsafeBitCast(test2, to: (@convention (c) () -> Void).self)()

typealias freebody = @convention(c) (UnsafeMutableRawPointer?) -> Void

var free_orig: (freebody)?

@_cdecl("free_c_orig")
public func free_c_orig(_ ptr: UnsafeMutableRawPointer?) {
    print("freeing", ptr as Any)
    free_orig?(ptr)
}

let orig: UnsafeMutableRawPointer? = hook(dlsym(dlopen(nil, RTLD_NOW), "free"), dlsym(dlopen(nil, RTLD_NOW), "free_c_orig"))

free_orig = unsafeBitCast(orig, to: freebody?.self)
