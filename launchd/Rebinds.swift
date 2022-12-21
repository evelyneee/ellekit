
import Foundation

class Rebinds {
    
    static var shared = Rebinds()
    
    typealias SpawnBody = @convention(c) (
        UnsafeMutablePointer<pid_t>,
        UnsafePointer<CChar>,
        UnsafePointer<posix_spawn_file_actions_t>,
        UnsafePointer<posix_spawnattr_t>,
        UnsafePointer<UnsafeMutablePointer<CChar>?>?,
        UnsafePointer<UnsafeMutablePointer<CChar>?>?
    ) -> Int32
    
    var posix_spawn = dlsym(dlopen(nil, RTLD_NOW), "posix_spawn")!
    var posix_spawnp = dlsym(dlopen(nil, RTLD_NOW), "posix_spawnp")!
    
    var posix_spawn_replacement = dlsym(dlopen(nil, RTLD_NOW), "posix_spawn_replacement")!
    var posix_spawnp_replacement = dlsym(dlopen(nil, RTLD_NOW), "posix_spawnp_replacement")!

    var posix_spawn_orig_ptr: UnsafeMutableRawPointer? = nil
    var posix_spawn_orig: SpawnBody {
        unsafeBitCast(posix_spawn_orig_ptr!, to: SpawnBody.self)
    }
    var posix_spawnp_orig_ptr: UnsafeMutableRawPointer? = nil
    var posix_spawnp_orig: SpawnBody {
        unsafeBitCast(posix_spawnp_orig_ptr!, to: SpawnBody.self)
    }
    
    func performHooks() {
        self.posix_spawn_orig_ptr = hook(self.posix_spawn, self.posix_spawn_replacement)
        self.posix_spawnp_orig_ptr = hook(self.posix_spawnp, self.posix_spawnp_replacement)
        if let orig = self.posix_spawn_orig_ptr, let porig = self.posix_spawnp_orig_ptr {
            TextLog.shared.write("orig is not nil now \(orig) \(porig)")
        }
    }
}
