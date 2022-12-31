
var selfPath: String = "/usr/lib/system/libdyld.dylib"
var safeModePath: String = "/usr/lib/system/libdyld.dylib"

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
    safeModePath = selfPath.components(separatedBy: "/").dropLast().joined(separator: "/").appending("/MobileSafety.dylib")
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

import Foundation
import os.log

@_cdecl("launchd_entry")
public func entry() {
    loadPath()
    do {
        try loadTweaks()
    } catch {
        tprint("\(error)")
    }
    Rebinds.shared.performHooks()
//    #if os(iOS)
//    if ProcessInfo.processInfo.processName.contains("launchd") {
//        spawnSafeMode()
//    }
//    #endif
    
}
