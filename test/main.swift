
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

// my playground!
// this file goes in layers depending on what i'm working on.
// the layers end with an exit call

import Foundation
import ellekit

func calculateTime(block : (() -> Void)) {
        let start = DispatchTime.now()
        block()
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        print("Time: \(timeInterval) seconds")
    }

print("--------- Finding posix_spawnp symbol through image iteration ---------")
calculateTime {
    for image in 0..<_dyld_image_count() {
        if let sym = try? ellekit.findSymbol(image: _dyld_get_image_header(image), symbol: "_posix_spawnp") {
            print("posix_spawnp: \(sym)")
            break
        }
    }
}

print("--------- Finding objc_direct symbol ---------")
// CF tests
let image = try ellekit.openImage(image: "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation")!
calculateTime {
    print(
        try! ellekit.findPrivateSymbol(
            image: image,
            symbol: "-[CFPrefsDaemon handleSourceMessage:replyHandler:]",
            overrideCachePath: "/Users/charlotte/Downloads/iPhone15,3_16.2_20C65_Restore/dyld_shared_cache_arm64e.symbols"
        )! // private sym
    )
}
let symbol = try ellekit.findSymbol(
    image: image,
    symbol: "-[CFPrefsDaemon handleSourceMessage:replyHandler:]"
)! // private sym
print("Symbol found:", symbol)

print("--------- Finding Capt's symbol ---------")
for image in 0..<_dyld_image_count() {
    [
        "_CFAttributedStringGetAttribute",
        "_CFUUIDCreate",
        "_CGFontCopyVariations",
        "_CGImageCreateWithPNGDataProvider",
        "_FPFileMetadataCopyTagData",
        "_BKSDisplayBrightnessSetAutoBrightnessEnabled",
        "_BKSDisplayBrightnessGetCurrent",
        "_UISUserInterfaceStyleModeValuelsAutomatic",
        "_MGGetBoolAnswer"
    ].forEach {
        if let sym = try? ellekit.findSymbol(image: _dyld_get_image_header(image), symbol: $0) {
            print("\($0): \(sym)")
            let _:Void = hook(UnsafeMutableRawPointer(mutating: sym), dlsym(dlopen(nil, RTLD_NOW), "MSHookFunction"))
        }
    }
}

print("--------- Finding posix_spawn and memcpy symbols ---------")
// libkernel tests
let libkernel = try ellekit.openImage(image: "/usr/lib/system/libsystem_kernel.dylib")!
let _posix_spawn_sym = try ellekit.findSymbol(image: libkernel, symbol: "_posix_spawn")!
let _memcpy_sym = try ellekit.findSymbol(image: libkernel, symbol: "_memcpy")!
print("Symbols found: \(_posix_spawn_sym) \(_memcpy_sym)")

// normal dylib test
print("--------- Hooking a findSymbol result ---------")
dlopen("/usr/local/lib/libsubstrate.dylib", RTLD_NOW)
let libsubstrate = try ellekit.openImage(image: "/usr/local/lib/libsubstrate.dylib")!
let _MSHookFunction_sym = try ellekit.findSymbol(image: libsubstrate, symbol: "_MSHookFunction")!
let _:Void = ellekit.hook(.init(mutating: _MSHookFunction_sym), .init(mutating: _memcpy_sym))

print("--------- Finding _main in myself ---------")
// selftest
let self_bin = try ellekit.openImage(image: ProcessInfo.processInfo.processName)!
let _main_self_sym = try ellekit.findSymbol(image: self_bin, symbol: "_main")!
print("_main:", _main_self_sym)

print("--------- Finding bundles for thin Mach-O ---------")
// MobileSMS
let msms = try ellekit.getLinkedBundleIDs(file: "/Users/charlotte/Library/Developer/Xcode/DerivedData/ellekit-dhqjqjjllmssnfdtbktrsblfipvk/Build/Products/Debug-iphoneos/MobileSMS")

print("Found bundles for MobileSMS:", msms.prefix(2))

print("--------- Finding bundles for thick Mach-O ---------")
let substrate = try ellekit.getLinkedBundleIDs(file: "/usr/local/lib/libsubstrate.dylib")

print("Found bundles for libsubstrate:", substrate)

#if false

print(try ellekit.getLinkedBundleIDs(file: "/Users/charlotte/Library/Developer/Xcode/DerivedData/ellekit-dhqjqjjllmssnfdtbktrsblfipvk/Build/Products/Debug-iphoneos/MobileSMS"))

print(try ellekit.getLinkedBundleIDs(file: "/usr/local/lib/libsubstrate.dylib"))

exit(1)


typealias AnyClosureType = @convention(swift) () -> Any
typealias ThinAnyClosureType = @convention(c) () -> Any

func mangle(_ name: String) -> String {
    return "\(name.utf8.count)\(name)"
}

private func mangleFunction(name: String,
                               owner: Any.Type,
                               args: String = "ypXpSgzt") {
    let module = _typeName(owner).components(separatedBy: ".")[0]
    let symbol = "$s\(mangle(module))\(mangle(name))5value3outyx_\(args)lF"
    print(symbol)
}

func mangledName(for type: Any) -> String? {
    var info = Dl_info()
    if dladdr(unsafeBitCast(type, to: UnsafeMutableRawPointer.self), &info) != 0,
        let metaTypeSymbol = info.dli_sname {
        print(String(cString: metaTypeSymbol))
    }
    return nil
}

func peekFunc<A, R>(_ f: @escaping (A) -> R) -> (fp: Int, ctx: Int) {
  typealias IntInt = (Int, Int)
  let (_, lo) = unsafeBitCast(f, to: IntInt.self)
  let offset = MemoryLayout<Int>.size == 8 ? 16 : 12
  let ptr = UnsafePointer<Int>(bitPattern: lo + offset)!
  return (ptr.pointee, ptr.successor().pointee)
}

var info = Dl_info()

dladdr(UnsafeRawPointer(bitPattern: peekFunc(String.hasPrefix).fp), &info)

print(info.dli_saddr)

exit(0)

let cache = try ellekit.loadSharedCache("")

func calculateTime(block : (() -> Void)) {
        let start = DispatchTime.now()
        block()
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        print("Time: \(timeInterval) seconds")
    }

let mapping = try ellekit.openImage(image: "/usr/local/lib/libsubstrate.dylib")!

print("opened")

let symbol = try ellekit.findSymbol(image: mapping, symbol: "_dlopen")

print("FOUND SYMBOL \(symbol)")

let imageData = try Data(contentsOf: URL(fileURLWithPath: "/Applications/Accord.app/Contents/MacOS/Accord"))

let ptr = imageData.withUnsafeBytes { ptr in
    print(ptr.baseAddress?.assumingMemoryBound(to: mach_header_64.self).pointee)
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

#endif
