
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

// my playground!
// this file goes in layers depending on what i'm working on.
// the layers end with an exit call

import Foundation
import ellekit
import AppKit
import Darwin

#if false
@_cdecl("rep1")
public func rep1() {
    print("called rep 1")
}

let repcl1: @convention(c) () -> Void = rep1

let repptr1 = unsafeBitCast(repcl1, to: UnsafeMutableRawPointer.self)

let nspopptr = dlsym(dlopen(nil, RTLD_NOW), "NSPopAutoreleasePool")!

let tramp = Trampoline(
    base: UnsafeMutableRawPointer(bitPattern: (UInt(bitPattern: nspopptr) & 0x0000007fffffffff))!,
    target: UnsafeMutableRawPointer(bitPattern: (UInt(bitPattern: repptr1) & 0x0000007fffffffff))!
)

print(NSRecursiveLock.init())

unsafeBitCast(nspopptr.makeCallable(), to: (@convention (c) () -> Void).self)()
//unsafeBitCast(tramp!.orig?.makeCallable(), to: (@convention (c) () -> Void).self)()
#endif


#if false

let atoiptr = dlsym(dlopen(nil, RTLD_NOW), "atoi")!

print(atoiptr)

var orig: UnsafeMutableRawPointer? = nil

hardwareHook(atoiptr, repptr1, &orig)

print("start")
print("ORIG:", unsafeBitCast(orig, to: (@convention (c) (UnsafePointer<CChar>) -> Int32).self)("4"))
print("REPLACEMENT:", unsafeBitCast(atoiptr, to: (@convention (c) (UnsafePointer<CChar>) -> Int32).self)("4"))

@_cdecl("rep2")
public func rep2(_ x1: UnsafePointer<CChar>) -> Int32 {
    print("called rep 2", String(cString: x1))
    return 41
}

let repcl2: @convention(c) (UnsafePointer<CChar>) -> Int32 = rep1

let repptr2 = unsafeBitCast(repcl1, to: UnsafeMutableRawPointer.self)

let atollptr = dlsym(dlopen(nil, RTLD_NOW), "puts")!

print(atollptr)

var orig2: UnsafeMutableRawPointer? = nil

hardwareHook(atollptr, repptr2, &orig2)

print("start")

if let orig2 {
    print("ORIG:", unsafeBitCast(orig2, to: (@convention (c) (UnsafePointer<CChar>) -> Void).self)("4"))
}
print("REPLACEMENT:", unsafeBitCast(atollptr, to: (@convention (c) (UnsafePointer<CChar>) -> Void).self)("4"))
#endif

@_cdecl("weirdfuncrep1")
public func weirdfuncrep1() {
    print("called weird func rep 1")
}

let weirdfuncrepcl1: @convention(c) () -> Void = weirdfuncrep1

let weirdfuncrepptr1 = unsafeBitCast(weirdfuncrepcl1, to: UnsafeMutableRawPointer.self)

let test_weirdfuncptr = dlsym(dlopen(nil, RTLD_NOW), "test_weirdfunc")!

print(test_weirdfuncptr)

let orig_weirdfunc = hook(test_weirdfuncptr, weirdfuncrepptr1)!

print("start")
print("ORIG:", unsafeBitCast(orig_weirdfunc, to: (@convention (c) (UnsafePointer<CChar>) -> Int32).self)("4"))
print("REPLACEMENT:", unsafeBitCast(test_weirdfuncptr, to: (@convention (c) (UnsafePointer<CChar>) -> Int32).self)("4"))

var orig1_: UnsafeMutableRawPointer! = nil

@_cdecl("rep1")
public func rep1(_ x1: UnsafePointer<CChar>) -> Int32 {
    print("called rep 1")
    let ret = unsafeBitCast(orig1_, to: (@convention (c) (UnsafePointer<CChar>) -> Int32).self)(x1)
    return ret
}

let repcl1: @convention(c) (UnsafePointer<CChar>) -> Int32 = rep1

let repptr1 = unsafeBitCast(repcl1, to: UnsafeMutableRawPointer.self)

var orig2_: UnsafeMutableRawPointer! = nil

@_cdecl("rep2")
public func rep2(_ x1: UnsafePointer<CChar>) -> Int32 {
    print("called rep 2")
    let ret = unsafeBitCast(orig2_, to: (@convention (c) (UnsafePointer<CChar>) -> Int32).self)(x1)
    return ret
}

let repcl2: @convention(c) (UnsafePointer<CChar>) -> Int32 = rep2

let repptr2 = unsafeBitCast(repcl2, to: UnsafeMutableRawPointer.self)

var socketorig: UnsafeMutableRawPointer! = nil

@_cdecl("socketrep")
public func socketrep(_ x0: Int32, _ x1: Int32, _ x2: Int32) -> Int32 {
    print("called socket")
    let ret = unsafeBitCast(socketorig, to: (@convention (c) (Int32, Int32, Int32) -> Int32).self)(x0, x1, x2)
    return ret
}

let socketrepcl: @convention (c) (Int32, Int32, Int32) -> Int32 = socketrep

let socketrepptr = unsafeBitCast(socketrepcl, to: UnsafeMutableRawPointer.self)

var writeorig: UnsafeMutableRawPointer! = nil

@_cdecl("writerep")
public func writerep(_ x0: Int32, _ x1: UnsafeRawPointer, _ x2: Int32) -> Int32 {
    print("called write")
    let ret = unsafeBitCast(writeorig, to: (@convention (c) (Int32, UnsafeRawPointer, Int32) -> Int32).self)(x0, x1, x2)
    return ret
}

let writerepcl: @convention (c) (Int32, UnsafeRawPointer, Int32) -> Int32 = writerep

let writerepptr = unsafeBitCast(writerepcl, to: UnsafeMutableRawPointer.self)

var unlinkorig: UnsafeMutableRawPointer! = nil

@_cdecl("unlinkrep")
public func unlinkrep(_ x0: UnsafePointer<CChar>) -> Int32 {
    print("called unlink", String(cString: x0))
    let ret = unsafeBitCast(unlinkorig, to: (@convention(c) (UnsafePointer<CChar>) -> Int32).self)(x0)
    return ret
}

let unlinkrepcl: @convention(c) (UnsafePointer<CChar>) -> Int32 = unlinkrep

let unlinkrepptr = unsafeBitCast(unlinkrepcl, to: UnsafeMutableRawPointer.self)

for image in 0..<_dyld_image_count() {
//    if let sym = MSFindSymbol(_dyld_get_image_header(image), "_atoi") {
//        print("_atoi: \(sym)")
//
//        var hook1 = LHFunctionHook(function: UnsafeMutableRawPointer(mutating: sym), replacement: repptr1, oldptr: &orig1_, options: nil)
//
//        let ret1 = LHHookFunctions(&hook1, 1)
//
//        var hook = LHFunctionHook(function: UnsafeMutableRawPointer(mutating: sym), replacement: repptr2, oldptr: &orig2_, options: nil)
//
//        let ret = LHHookFunctions(&hook, 1)
//
//        print("orig1", ret1, ret)
//
//        // let orig2: UnsafeMutableRawPointer = hook(UnsafeMutableRawPointer(mutating: sym), repptr2)!
//
//        print(unsafeBitCast(sym, to: (@convention (c) (UnsafePointer<CChar>) -> Int32).self)("4"))
//    }
    
    if let sym = MSFindSymbol(_dyld_get_image_header(image), "_socket") {
        print("_socket: \(sym)")
                
        let ret1 = socket(32, 1, 2)
        
        socketorig = hook(UnsafeMutableRawPointer(mutating: sym), socketrepptr)!
        
        let ret = socket(32, 1, 2)
                
        print(ret1, ret)
    }
    
    #if false
    if let sym = MSFindSymbol(_dyld_get_image_header(image), "_read") {
        print("_read: \(sym)")
                        
        writeorig = hook(UnsafeMutableRawPointer(mutating: sym), writerepptr)!
                
        let ret = read(STDIN_FILENO, malloc(4), 5)
                
        print(ret)
    }
    #endif
    
    if let sym = MSFindSymbol(_dyld_get_image_header(image), "_unlink") {
        print("_unlink: \(sym)")
                        
        UnsafeRawPointer(bitPattern: (UInt(bitPattern: writeorig) & 0x0000007fffffffff))?.hexDump(0x400)
        
        unlinkorig = hook(UnsafeMutableRawPointer(mutating: sym), unlinkrepptr)!
        
        let ret = unlink("/var/jb/")
                
        print(ret)
    }
}
#if false

func demangle(symbol: UnsafePointer<Int8>) -> String? {
    if let demangledNamePtr = _stdlib_demangleImpl(
        symbol, mangledNameLength: UInt(strlen(symbol)),
        outputBuffer: nil, outputBufferSize: nil, flags: 0) {
        let demangledName = String(cString: demangledNamePtr)
        free(demangledNamePtr)
        return demangledName
    }
    return nil
}

// Taken from stdlib, not public Swift3+
@_silgen_name("swift_demangle")
private
func _stdlib_demangleImpl(
_ mangledName: UnsafePointer<CChar>?,
mangledNameLength: UInt,
outputBuffer: UnsafeMutablePointer<UInt8>?,
outputBufferSize: UnsafeMutablePointer<UInt>?,
flags: UInt32
) -> UnsafeMutablePointer<CChar>?

//withUnsafeFunctionPointer(String.lowercased) {
//    $0.hexDump(128)
//    var info = Dl_info()
//    dladdr($0, &info)
//    print(String(cString: info.dli_sname))
//    print(
//        demangle(symbol: info.dli_sname)
//    )
//}

extension FixedWidthInteger {
    func reverse() -> Self {
        ((self>>24)&0xff) | ((self<<8)&0xff0000) | ((self>>8)&0xff00) | ((self<<24)&0xff000000)
    }
}
#endif

// CF tests
let image2 = try ellekit.openImage(image: "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation")!
calculateTime {
    print(
        try! ellekit.findPrivateSymbol(
            image: image2,
            symbol: "-[CFPrefsDaemon handleSourceMessage:replyHandler:]",
            overrideCachePath: "/Users/charlotte/Downloads/iPhone7-10.0-14A93012r/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64"
        )! // private sym
    )
}

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

#if false
print("--------- Finding DhinakG's symbol -----------")

dlopen("/System/Library/PrivateFrameworks/DeviceIdentity.framework/Versions/A/DeviceIdentity", RTLD_NOW)
let devID = try ellekit.openImage(image: "/System/Library/PrivateFrameworks/DeviceIdentity.framework/Versions/A/DeviceIdentity")!
calculateTime {
    print(try? ellekit.findPrivateSymbol(
        image: devID,
        symbol: "_isSupportedDeviceIdentityClient",
        overrideCachePath: "/Users/charlotte/Downloads/iPhone12,3,iPhone12,5_16.4.1_20E252_Restore/dyld_shared_cache_arm64e.symbols"
    )!) // private sym
}
#endif

print("--------- Finding objc_direct symbol ---------")
// CF tests
let image = try ellekit.openImage(image: "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation")!
calculateTime {
    print(
        try! ellekit.findPrivateSymbol(
            image: image,
            symbol: "-[CFPrefsDaemon handleSourceMessage:replyHandler:]",
            overrideCachePath: "/Users/charlotte/Downloads/iPhone12,3,iPhone12,5_16.4.1_20E252_Restore/dyld_shared_cache_arm64e.symbols"
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

print("--------- Finding non-existent symbols ---------")

let null = MSFindSymbol(try ellekit.openImage(image: "/usr/lib/system/libsystem_kernel.dylib")!, "AAAAAAA")

print(null)

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
let msms = try ellekit.getLinkedBundleIDs(file: "/Users/charlotte/Downloads/prng_seedctl")

print("Found bundles for MobileSMS:", msms.prefix(2))

print("--------- Finding bundles for thick Mach-O ---------")
let dirPath = "/usr/sbin/"
for path in try FileManager.default.contentsOfDirectory(atPath: dirPath) {
    
    _ = try? ellekit.getLinkedBundleIDs(file: dirPath+path)

}

print(try? ellekit.getLinkedBundleIDs(file: "/usr/local/lib/libsubstrate.dylib"))

#if false
let atoiptr = dlsym(dlopen(nil, RTLD_NOW), "atoll")!

@_cdecl("rep")
public func rep() -> Int {
    2
}

let repcl: @convention(c) () -> Int = rep

let repptr = unsafeBitCast(repcl, to: UnsafeMutableRawPointer.self)

DispatchQueue.global().async {
    while true {
        let two = atoll("3")
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

#endif

print("--------- Begin NSPop test ---------")

let nspopptr = dlsym(dlopen(nil, RTLD_NOW), "NSPopAutoreleasePool")!

@_cdecl("nspoprep")
public func nspoprep() -> Int {
    2
}

let nspoprepcl: @convention(c) () -> Int = nspoprep

let nspoprepptr = unsafeBitCast(nspoprepcl, to: UnsafeMutableRawPointer.self)

let test2: UnsafeMutableRawPointer = hook(nspopptr, nspoprepptr)!

print("hooked")

func test3() {
    let h = unsafeBitCast(nspopptr, to: (@convention (c) () -> Int32).self)()

    print(h)
}
print("testing")

test3()

// unsafeBitCast(test2, to: (@convention (c) () -> Void).self)()

//typealias freebody = @convention(c) (UnsafeMutableRawPointer?) -> Void
//
//var free_orig: (freebody)?
//
//@_cdecl("free_c_orig")
//public func free_c_orig(_ ptr: UnsafeMutableRawPointer?) {
//    print("freeing", ptr as Any)
//    free_orig?(ptr)
//}
//
//let orig: UnsafeMutableRawPointer? = hook(dlsym(dlopen(nil, RTLD_NOW), "free"), dlsym(dlopen(nil, RTLD_NOW), "free_c_orig"))
//
//free_orig = unsafeBitCast(orig, to: freebody?.self)

print("test bp")
