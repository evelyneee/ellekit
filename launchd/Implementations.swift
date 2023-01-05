
import Foundation

extension String {
    var removingLastComponent: String {
        (self as NSString).deletingLastPathComponent
    }
}

@_cdecl("posix_spawn_replacement")
public func posix_spawn_replacement(
    _ pid: UnsafeMutablePointer<pid_t>,
    _ path: UnsafePointer<CChar>,
    _ file_actions: UnsafePointer<posix_spawn_file_actions_t?>,
    _ spawnattr: UnsafePointer<posix_spawnattr_t?>,
    _ argv: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    _ envp: UnsafePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let ret = spawn_replacement(false, pid, path, file_actions, spawnattr, argv, envp)
    return ret
}

@_cdecl("posix_spawnp_replacement")
public func posix_spawnp_replacement(
    _ pid: UnsafeMutablePointer<pid_t>,
    _ path: UnsafePointer<CChar>,
    _ file_actions: UnsafePointer<posix_spawn_file_actions_t?>,
    _ spawnattr: UnsafePointer<posix_spawnattr_t?>,
    _ argv: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    _ envp: UnsafePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let ret = spawn_replacement(true, pid, path, file_actions, spawnattr, argv, envp)
    return ret
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

func spawn_replacement(
    _ p: Bool,
    _ pid: UnsafeMutablePointer<pid_t>,
    _ path: UnsafePointer<CChar>,
    _ file_actions: UnsafePointer<posix_spawn_file_actions_t?>,
    _ spawnattr: UnsafePointer<posix_spawnattr_t?>?,
    _ argv: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    _ envp: UnsafePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
        
    let path = String(cString: path)
    
    tprint("executing \(path)")
    
    var envp = envp?.array ?? []
    
    let firstEnvIndex = envp.firstIndex(where: { $0.hasPrefix("DYLD_INSERT_LIBRARIES=") })
        
    tprint("\(path) \(envp.joined(separator: "\n")) \(argv?.array.joined(separator: "\n") ?? "")")
        
    let launchd = path.contains("xpcproxy") || path.contains("launchd")
    
    let blacklisted = [
        "BlastDoor",
        "mobile_assertion_agent",
        "WebKit",
        "Safari"
    ]
    .map { path.contains($0) }
    .contains(true)
    
    
    // check if we're spawning springboard
    // usually launchd spawns springboard directly, without going through xpcproxy
    // since we cache tweaks, a respring will forcefully refresh it
    // we also spawn safe mode after
    let springboard = path == "/System/Library/CoreServices/SpringBoard.app/SpringBoard"
    
    var safeMode = false
    
    if springboard {
        tprint("Testing safe mode")
        safeMode = checkVolumeUp()
        tprint("Safe mode status:", safeMode)
    }
    
    func addDYLDEnv(_ envKey: String) {
        if let firstEnvIndex {
            let previousEnvKey = envp[firstEnvIndex].dropFirst("DYLD_INSERT_LIBRARIES=".count) // gives us the path
            envp[firstEnvIndex] = "DYLD_INSERT_LIBRARIES="+envKey + ":" + previousEnvKey
        }
        envp.append("DYLD_INSERT_LIBRARIES="+envKey)
    }
    
    if springboard {
        tprint("Spawning SpringBoard (time to refresh tweaks)")
        try? loadTweaks()
    }
    
    if launchd {
        
        tprint("launchd \(path)")
        addDYLDEnv(selfPath)
        
    } else if safeMode && springboard {

        tprint("Safe Mode \(path)")
        addDYLDEnv(safeModePath)
        
    } else if !blacklisted {
        
        tprint("injecting tweaks \(path)")
        
        if let bundleID = findBundleID(path: path) {
            
            tprint("found bundle \(path) \(bundleID)")
            #warning("TODO: Stop hardcoding these frameworks")
            
            let tweaks = tweaks
                .compactMap {
                    if $0.bundles.contains(bundleID) ||
                        $0.bundles.contains("com.apple.uikit") ||
                        $0.bundles.contains("com.apple.foundation") ||
                        $0.bundles.contains("com.apple.security") {
                        return $0.path
                    }
                    return nil
                }
            
            tprint("got tweaks \(bundleID) \(tweaks)")
            
            if !tweaks.isEmpty {
                let env = tweaks.joined(separator: ":")
                tprint("adding env \(env)")
                addDYLDEnv(env)
            }
            
        } else {
            let executableName = (path as NSString).lastPathComponent
            tprint("using exec name \(path) \(executableName)")
            let tweaks = tweaks
                .filter { $0.executables.contains(executableName.lowercased()) }
                .map(\.path)
            tprint("got tweaks \(executableName) \(tweaks)")
            if !tweaks.isEmpty {
                let env = tweaks.joined(separator: ":")
                tprint("adding env \(env)")
                addDYLDEnv(env)
            }
        }
        
    } else {
        tprint("no tweaks \(path)")
    }
    
    tprint("----------\n new env is \n\(envp.joined(separator: "\n"))\n----------")
    
    var envp_c: [UnsafeMutablePointer<CChar>?] = envp.compactMap { ($0 as NSString).utf8String }.map { strdup($0) }
    
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
    
    return ret
}
