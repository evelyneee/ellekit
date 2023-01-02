// my playground!

import Foundation
import ellekit

ellekit.loadSharedCache("")

exit(0)

func calculateTime(block : (() -> Void)) {
        let start = DispatchTime.now()
        block()
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        print("Time: \(timeInterval) seconds")
    }

let mapping = try ellekit.openImage(image: "/usr/lib/system/libdyld.dylib")!

print("opened")

let symbol = try ellekit.findSymbol(image: mapping, symbol: "_dlopen")

print("FOUND SYMBOL \(symbol)")

let imageData = try Data(contentsOf: URL(fileURLWithPath: "/Applications/Accord.app/Contents/MacOS/Accord"))

let ptr = imageData.withUnsafeBytes { ptr in
    print(ptr.baseAddress?.assumingMemoryBound(to: mach_header.self).pointee)
    print(try? ellekit.headerBundleIDs(image: ptr.baseAddress!))
}

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
