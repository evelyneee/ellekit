
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

class Rebinds {
    
    static var shared = Rebinds()
    
    typealias SpawnBody = @convention(c) (
        UnsafeMutablePointer<pid_t>?,
        UnsafePointer<CChar>?,
        UnsafePointer<posix_spawn_file_actions_t?>?,
        UnsafePointer<posix_spawnattr_t?>?,
        UnsafePointer<UnsafeMutablePointer<CChar>?>?,
        UnsafePointer<UnsafeMutablePointer<CChar>?>?
    ) -> Int32
    
    var posix_spawn = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "posix_spawn")!
    var posix_spawnp = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "posix_spawnp")!
    
    var posix_spawn_replacement = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "posix_spawn_replacement")!
    var posix_spawnp_replacement = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "posix_spawnp_replacement")!
    var sandbox_check_replacement = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "hook_sandbox_check")!
    
    var posix_spawn_orig_ptr: UnsafeMutableRawPointer? = nil
    var posix_spawn_orig: SpawnBody {
        unsafeBitCast(posix_spawn_orig_ptr!, to: SpawnBody.self)
    }
    var posix_spawnp_orig_ptr: UnsafeMutableRawPointer? = nil
    var posix_spawnp_orig: SpawnBody {
        unsafeBitCast(posix_spawnp_orig_ptr!, to: SpawnBody.self)
    }
    
    var usedFishhook = false
    
    let posix_spawnp_cstring = strdup(("posix_spawnp" as NSString).utf8String)
    let posix_spawn_cstring = strdup(("posix_spawn" as NSString).utf8String)
    
    func rebind() {
                
        self.usedFishhook = true
        
        var rebindings: [rebinding] = [
            rebinding(name: posix_spawn_cstring, replacement: posix_spawn_replacement, replaced: nil),
            rebinding(name: posix_spawnp_cstring, replacement: posix_spawnp_replacement, replaced: nil),
        ]
        
        let index = (0..<_dyld_image_count())
            .filter {
                String(cString: _dyld_get_image_name($0))
                    .contains( ProcessInfo.processInfo.processName)
            }
            .first
        
        guard let index else {
            tprint("failed to get my image")
            return
        }
        
        tprint("rebindinds starting \(index) \(String(cString: _dyld_get_image_name(index)))")
                
        let ret = rebind_symbols_image(
            .init(mutating: _dyld_get_image_header(index)),
            _dyld_get_image_vmaddr_slide(index),
            &rebindings, rebindings.count
        )
        
        tprint("got ret", ret)
    }
    
    func hook() {
        if let orig = pspawn.hook(self.posix_spawn, self.posix_spawn_replacement),
           let origp = pspawn.hook(self.posix_spawnp, self.posix_spawnp_replacement) {
            self.usedFishhook = false
            self.posix_spawn_orig_ptr = orig
            self.posix_spawnp_orig_ptr = origp
            if let orig = self.posix_spawn_orig_ptr, let porig = self.posix_spawnp_orig_ptr {
                tprint("orig is not nil now \(orig) \(porig)")
            }
        } else {
            tprint("hook failed. shoot")
            rebind()
        }
    }
    
    func performHooks() {
        #if os(macOS)
        tprint("using ellekit for hooking")
        hook()
        #else // iOS, tvOS, watchOS (?)
        if Fugu15 { // Fugu will have CS_DEBUGGED set everywhere, unlike checkm8 (unsure about this in practice though)
            tprint("using ellekit for hooking")
            hook()
        } else {
            tprint("using fishhook for launchd/proxy hooks")
            rebind()
        }
        #endif
    }
}
