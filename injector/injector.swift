
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation
import os.log

#warning("TODO: C rewrite")

#if os(iOS) || os(tvOS) || os(watchOS)
let path = "/Library/MobileSubstrate/DynamicLibraries/"
#elseif os(macOS)
let path = "/Library/TweakInject/"
#endif

@_silgen_name("sandbox_extension_consume")
func sandbox_extension_consume(_ str: UnsafePointer<Int8>)

// big wip don't complain!
@_cdecl("injector_entry")
public func entry() {
    dlopen("/usr/lib/libobjc.A.dylib", RTLD_NOW)
    print("[ellekit] injector: out here")
    if let exten = ProcessInfo.processInfo.environment["SANDBOX_EXTENSION"] {
        NSLog("got extension")
        NSLog(exten)
        sandbox_extension_consume(exten)
    } else {
        NSLog("no extension")
    }
    do {
        try loadTweaks()
        tweaks
            .filter { $0.bundles.contains(Bundle.main.bundleIdentifier ?? "com.apple.security") }
            .forEach {
                NSLog("opening tweak")
                NSLog($0.path)
                dlopen($0.path, RTLD_NOW)
                if let err = dlerror() {
                    NSLog("Got dlerr")
                    NSLog(String(cString: err))
                }
            }
    } catch {
        print("got error", error)
    }
}
