
import Foundation

extension String {
    var removingLastComponent: String {
        (self as NSString).deletingLastPathComponent
    }
}

@_cdecl("posix_spawn_replacement")
func posix_spawn_replacement(
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
func posix_spawnp_replacement(
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

func spawn_replacement(
    _ p: Bool,
    _ pid: UnsafeMutablePointer<pid_t>,
    _ path: UnsafePointer<CChar>,
    _ file_actions: UnsafePointer<posix_spawn_file_actions_t?>,
    _ spawnattr: UnsafePointer<posix_spawnattr_t?>,
    _ argv: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    _ envp: UnsafePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
        
    let path = String(cString: path)
    
    TextLog.shared.write("executing \(path)")
    if #available(iOS 14.0, *) {
        logger.notice("executing \(path)")
    }
            
    var envp = envp?.array ?? []
        
    TextLog.shared.write("\(path) \(envp.joined(separator: "\n")) \(argv?.array.joined(separator: "\n") ?? "")")
    
    if #available(iOS 14.0, *) {
        logger.notice("env is \(envp.joined())")
    }
        
    let launchd = path.contains("xpcproxy") || path.contains("launchd")
    let shouldInject = !path.contains("BlastDoor") && !path.contains("mobile_assertion_agent") && !path.contains("WebKit") && !path.contains("Safari")
    
    if launchd {
        TextLog.shared.write("launchd \(path)")
        envp.append("DYLD_INSERT_LIBRARIES="+selfPath)
    } else if shouldInject {
        TextLog.shared.write("injecting tweaks \(path)")
        var parsedPath: String? = nil
        if path.contains(".app/Contents/MacOS/") {
            // remove the binary, then MacOS, then Contents
            parsedPath = path.components(separatedBy: "/").dropLast(3).joined(separator: "/")
        } else if path.contains(".app") {
            // Remove the binary
            parsedPath = path.components(separatedBy: "/").dropLast().joined(separator: "/")
        }
        
        if let parsedPath, let bundleID = Bundle(path: parsedPath)?.bundleIdentifier?.lowercased() {
            let tweaks = tweaks
                .filter { $0.bundles.contains(bundleID) || $0.bundles.contains("com.apple.uikit") }
                .map(\.path)
            if !tweaks.isEmpty {
                let env = "DYLD_INSERT_LIBRARIES="+tweaks.joined(separator: ":")
                if #available(iOS 14.0, *) {
                    logger.notice("adding env \(env)")
                }
                envp.append(env)
            }
        }
    } else {
        TextLog.shared.write("no tweaks \(path)")
    }
    
    TextLog.shared.write("----------\n new env is \n\(envp.joined(separator: "\n"))\n----------")
    
    if #available(iOS 14.0, *) {
        logger.notice("new env is \(envp.joined())")
    }
    
    var envp_c: [UnsafeMutablePointer<CChar>?] = envp.compactMap { ($0 as NSString).utf8String }.map { strdup($0) }
    
    envp_c.append(nil)
    
    TextLog.shared.write("calling back orig now")
    return envp_c.withUnsafeBufferPointer { buf in
        if Rebinds.shared.usedFishhook {
            print("calling fishhook orig")
            if p {
                let ret = posix_spawnp(pid, path, file_actions, spawnattr, argv, buf.baseAddress)
                TextLog.shared.write("orig returned \(ret)")
                return ret
            } else {
                let ret = posix_spawn(pid, path, file_actions, spawnattr, argv, buf.baseAddress)
                TextLog.shared.write("orig returned \(ret)")
                return ret
            }
        } else {
            if p {
                let ret = Rebinds.shared.posix_spawnp_orig(pid, path, file_actions, spawnattr, argv, buf.baseAddress)
                TextLog.shared.write("orig returned \(ret)")
                return ret
            } else {
                let ret = Rebinds.shared.posix_spawn_orig(pid, path, file_actions, spawnattr, argv, buf.baseAddress)
                TextLog.shared.write("orig returned \(ret)")
                return ret
            }
        }
    }
}
