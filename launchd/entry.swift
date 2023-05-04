
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation
import os.log

var selfPath: String = "/usr/lib/system/libdyld.dylib"
var sbHookPath: String = "/usr/lib/system/libdyld.dylib"
var injectorPath: String = "/usr/lib/system/libdyld.dylib"

func loadPath() {
    if let path = loadDLaddrPath() {
        selfPath = path
    } else {
        #if os(macOS)
        selfPath = "/Library/TweakInject/pspawn.dylib"
        #else
        if access("/usr/lib/ellekit/pspawn.dylib", F_OK) == 0 {
            selfPath = "/usr/lib/ellekit/pspawn.dylib"
        } else {
            selfPath = (("/var/jb/usr/lib/ellekit/pspawn.dylib" as NSString).resolvingSymlinksInPath)
        }
        #endif
    }
    sbHookPath = selfPath.components(separatedBy: "/").dropLast().joined(separator: "/").appending("/MobileSafety.dylib")
    injectorPath = selfPath.components(separatedBy: "/").dropLast().joined(separator: "/").appending("/libinjector.dylib")
}

func loadDLaddrPath() -> String? {
    var info = Dl_info()
    guard let sym = dlsym(dlopen(nil, RTLD_NOW), "launchd_entry") else { return nil }
    dladdr(sym, &info)
    guard let name = info.dli_fname else { return nil }
    let str = String(cString: name)
    guard access(str, F_OK) == 0 else { return nil }
    tprint("got dladdr path "+str)
    return str
}

let insideLaunchd = ProcessInfo.processInfo.processName.contains("launchd")

@_cdecl("launchd_entry")
public func entry() {
    tprint("Hello world from", ProcessInfo.processInfo.processName, "running as", getuid())
        
    loadPath()
    
    do {
        try loadTweaks()
    } catch {
        tprint("\(error)")
    }
    
    Rebinds.shared.performHooks()
}
