
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

extension String {
    var removingLastComponent: String {
        (self as NSString).deletingLastPathComponent
    }
}

func count(of cStringArray: UnsafePointer<UnsafePointer<CChar>?>?) -> Int {
    guard let cStringArray = cStringArray else { return 0 }
    var count = 0
    var currentPointer = cStringArray
    while currentPointer.pointee != nil {
        count += 1
        currentPointer = currentPointer.successor()
    }
    return count
}

func findBundleID(path: String) -> String? {
    let parsedPath: String
    if path.contains(".app/Contents/MacOS/") {
        // this is in every app path
        // remove the binary path component, then MacOS, then Contents
        parsedPath = path.components(separatedBy: "/").dropLast(3).joined(separator: "/")
    } else if path.contains(".app") {
        // Remove the binary path component
        parsedPath = path.components(separatedBy: "/").dropLast().joined(separator: "/")
    } else {
        parsedPath = path
    }
         
    if let bundleID = Bundle(path: parsedPath)?.bundleIdentifier?.lowercased() {
        return bundleID
    }
    
    return nil
}

let iOS16XPCBlacklist = [
    "com.apple.logd",
    "com.apple.notifyd",
    "com.apple.mobile.usermanagerd",
]

@inline(never)
func spawn_replacement(
    _ p: Bool,
    _ pid: UnsafeMutablePointer<pid_t>,
    _ path: UnsafePointer<CChar>,
    _ file_actions: UnsafePointer<posix_spawn_file_actions_t?>?,
    _ spawnattr: UnsafePointer<posix_spawnattr_t?>?,
    _ argv: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    _ envp: UnsafePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
            
    let path = String(cString: path)
    
    tprint("executing \(path)")
    
    var envp = envp?.array ?? []
    
    let firstEnvIndex = envp.firstIndex(where: { $0.hasPrefix("DYLD_INSERT_LIBRARIES=") })
        
    tprint("\(path) \(envp.joined(separator: "\n")) \(argv?.array.joined(separator: "\n") ?? "")")
        
    let launchd = path.contains("launchd")
    let xpcproxy = path.contains("xpcproxy")

    var binaryBlacklist = [
        "BlastDoor",
        "mobile_assertion_agent",
        "watchdog",
        "webkit",
        "jailbreakd",
        "loader",
        "GSSCred",
    ]
    
    var xpcBlacklist = [] as [String]
    
    if #available(iOS 16.0, *) {
        xpcBlacklist.insert(contentsOf: iOS16XPCBlacklist, at: 0)
    }
    
    var blacklisted = binaryBlacklist
        .map { path.lowercased().contains($0.lowercased()) }
        .contains(true)
    
    if !blacklisted && xpcproxy {
        let argv_array = argv?.array ?? []
        if let xpcIdentifier = argv_array.indices.contains(1) ? argv_array[1] : nil {
            blacklisted = xpcBlacklist
                .map { $0.lowercased() }
                .contains(xpcIdentifier.lowercased())
        }
    }

    // check if we're spawning springboard
    // usually launchd spawns springboard directly, without going through xpcproxy
    // since we cache tweaks, a respring will forcefully refresh it
    // we also *not anymore* spawn safe mode after
    let springboard = path == "/System/Library/CoreServices/SpringBoard.app/SpringBoard"
    let safeMode = FileManager.default.fileExists(atPath: "/var/mobile/.eksafemode")
    
    func addDYLDEnv(_ envKey: String) {
        
        guard !envKey.isEmpty else {
            return
        }
        
        if let firstEnvIndex, envKey != envp[firstEnvIndex] {
            let previousEnvKey = envp[firstEnvIndex].dropFirst("DYLD_INSERT_LIBRARIES=".count) // gives us the path
            envp[firstEnvIndex] = "DYLD_INSERT_LIBRARIES="+envKey + ":" + previousEnvKey
        } else {
            envp.append("DYLD_INSERT_LIBRARIES="+envKey)
        }
    }
    
    if springboard {
        tprint("Spawning SpringBoard (time to refresh tweaks)")
        try? loadTweaks()
    }
    
    if launchd {
        // Inject pspawn.dylib in launchd and xpcproxy
        tprint("launchd \(path)")
        addDYLDEnv(selfPath)
    } else if xpcproxy {
        if !blacklisted {
            addDYLDEnv(selfPath)
        }
    }
    else if safeMode {
                
        // We always inject the SpringBoard MobileSafety.dylib, I believe it is safe
        // If it isn't SpringBoard, skip ahead
        if springboard {
            tprint("Injecting sb hook \(sbHookPath)")
            addDYLDEnv(sbHookPath)
        }
        
    } else if !blacklisted {
        
        #if !os(macOS)
        tprint("injecting tweaks \(path)")
        
        addDYLDEnv(injectorPath)
        
        let POSIX_SPAWNATTR_OFF_MEMLIMIT_ACTIVE = 0x48
        let POSIX_SPAWNATTR_OFF_MEMLIMIT_INACTIVE = 0x4C
        
        #warning("Offset is wrong for 16.x")
        
//        if let attrStruct = spawnattr?.pointee {
//            let memlimit_active = attrStruct.advanced(by: Int(POSIX_SPAWNATTR_OFF_MEMLIMIT_ACTIVE)).load(as: Int32.self)
//            if memlimit_active != -1 {
//                attrStruct.advanced(by: Int(POSIX_SPAWNATTR_OFF_MEMLIMIT_ACTIVE)).storeBytes(of: memlimit_active * 3, as: Int32.self)
//            }
//            let memlimit_inactive = attrStruct.advanced(by: Int(POSIX_SPAWNATTR_OFF_MEMLIMIT_INACTIVE)).load(as: Int32.self)
//            if memlimit_inactive != -1 {
//                attrStruct.advanced(by: Int(POSIX_SPAWNATTR_OFF_MEMLIMIT_INACTIVE)).storeBytes(of: memlimit_inactive * 3, as: Int32.self)
//            }
//        }
        #else
        
        tprint("removed jetsam")
        
        if let bundleID = findBundleID(path: path) {
            
            tprint("found bundle \(path) \(bundleID)")
                              
            var dylibs = [String]()
            
            var injectedBundles = ["com.apple.uikit", "com.apple.foundation", "com.apple.security", "com.apple.appkit"]
            
//            // my macho parser isn't that good yet...
//            if rootless, let bundleIDs = try? getLinkedBundleIDs(file: path) {
//                injectedBundles.insert(contentsOf: bundleIDs.map { $0.lowercased() }, at: 0)
//            }
            
//            injectedBundles.insert(contentsOf: ["com.apple.uikit", "com.apple.foundation", "com.apple.security"], at: 0)

            
            tprint("loaded bundles", injectedBundles)
                        
            if !safeMode {
                dylibs = tweaks
                    .compactMap {
                         if $0.bundles.contains(bundleID) || $0.bundles.contains(where: { injectedBundles.contains($0) }) {
                             return $0.path
                         }
                        return nil
                    }
            }
            
            tprint("got tweaks \(bundleID) \(tweaks)")
            
            if springboard {
                tprint("Injecting sb hook \(sbHookPath)")
                dylibs.insert(sbHookPath, at: 0)
            }
            
            if !tweaks.isEmpty {
                let env = dylibs.joined(separator: ":")
                tprint("adding env \(env)")
                addDYLDEnv(env)
            }
            
        } else {
            let executableName = (path as NSString).lastPathComponent
            tprint("using exec name \(path) \(executableName)")
            
            var injectedBundles = ["com.apple.uikit", "com.apple.foundation", "com.apple.security", "com.apple.appkit"]
           
//            // my macho parser isn't that good yet...
//            if rootless, let bundleIDs = try? getLinkedBundleIDs(file: path) {
//                injectedBundles.insert(contentsOf: bundleIDs.map { $0.lowercased() }, at: 0)
//            }
            
            let tweaks = tweaks
                .compactMap {
                    if $0.executables.contains(executableName.lowercased()) {
                        return $0.path
                    }
                    if $0.bundles.contains(where: { injectedBundles.contains($0) }) {
                         return $0.path
                    }
                    return nil
                }
            
            tprint("got tweaks \(executableName) \(tweaks)")
            
            if !tweaks.isEmpty {
                let env = tweaks.joined(separator: ":")
                tprint("adding env \(env)")
                addDYLDEnv(env)
            }
        }
        #endif
    } else {
        tprint("no tweaks \(path)")
    }
    
    #if os(macOS)
    let file_extension = sandbox_extension_issue_file(
        APP_SANDBOX_READ_WRITE,
        ("/Library/TweakInject" as NSString).resolvingSymlinksInPath,
        0
    )
    #else
    let file_extension = sandbox_extension_issue_file(
        APP_SANDBOX_READ,
        ("/var/jb" as NSString).resolvingSymlinksInPath,
        0
    )
    #endif
        
    if let exten = file_extension {
        tprint("got extension", String(cString: exten))
        envp.append("SANDBOX_EXTENSION="+String(cString: exten))
    }
    
    tprint("----------\n new env is \n\(envp.joined(separator: "\n"))\n----------")
    
    var envp_c: [UnsafeMutablePointer<CChar>?] = envp
        .compactMap { ($0 as NSString).utf8String }
        .map { strdup($0) }
    
    envp_c.append(nil)
            
    #if false // unused now. use volume up
    if springboard {
        if let handler = PIDExceptionHandler(),
            let spawnattr = spawnattr {
            PIDExceptionHandler.current = handler

            tprint(handler, "created handler")
            
            posix_spawnattr_setexceptionports_np(
                UnsafeMutablePointer(mutating: spawnattr),
                exception_mask_t(EXC_MASK_BREAKPOINT),
                handler.port,
                EXCEPTION_DEFAULT,
                ARM_THREAD_STATE64
            )
            
            tprint("set handler to spawn_attr")
        }
    }
    #endif
    
    let ret = envp_c.withUnsafeBufferPointer { buf in
        if Rebinds.shared.usedFishhook {
            tprint("calling fishhook orig")
            if p {
                let ret = posix_spawnp(pid, path, file_actions, spawnattr, argv, buf.baseAddress)
                tprint("origp returned \(ret)")
                return ret
            } else {
                let ret = posix_spawn(pid, path, file_actions, spawnattr, argv, buf.baseAddress)
                tprint("orig returned \(ret)")
                return ret
            }
        } else {
            if p {
                let ret = Rebinds.shared.posix_spawnp_orig(pid, path, file_actions, spawnattr, argv, buf.baseAddress)
                tprint("origp returned \(ret)")
                return ret
            } else {
                let ret = Rebinds.shared.posix_spawn_orig(pid, path, file_actions, spawnattr, argv, buf.baseAddress)
                tprint("orig returned \(ret)")
                return ret
            }
        }
    }
    
    #if os(iOS)
    if springboard && ret != 0 {
        FileManager.default.createFile(atPath: "/var/mobile/.eksafemode", contents: Data())
    }
    #endif
        
    return ret
}
