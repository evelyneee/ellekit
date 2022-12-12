//
//  hook.swift
//  loader
//
//  Created by charlotte on 2022-12-12.
//

import Foundation

var orig_spawn_pointer: UnsafeMutableRawPointer? = nil

typealias MSHookFunctionBody = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer) -> Void

@_cdecl("spawn_hook_entry")
public func entry() {
    DispatchQueue.global().async {
        sleep(2); // the launchd hook needs to patch back posix_spawn i guess
        let spawn_orig = dlsym(dlopen("/usr/lib/system/libdyld.dylib", RTLD_NOW), "posix_spawn")!
        let spawn_new = dlsym(dlopen(nil, RTLD_NOW), "replacement_posix_spawn")!
        guard let ptr = dlsym(dlopen("/usr/local/lib/libsubstrate.dylib", RTLD_LAZY), "MSHookFunction") else {
            return
        }
        let MSHookFunction = unsafeBitCast(ptr, to: MSHookFunctionBody.self)
        MSHookFunction(spawn_orig, spawn_new, &orig_spawn_pointer)
    }
}

typealias SpawnBody = @convention(c) (
    UnsafeMutablePointer<pid_t>,
    UnsafePointer<CChar>,
    UnsafePointer<posix_spawn_file_actions_t>,
    UnsafePointer<posix_spawnattr_t>,
    UnsafePointer<UnsafeMutablePointer<CChar>>,
    UnsafePointer<UnsafeMutablePointer<CChar>>
) -> Int32

@_cdecl("replacement_posix_spawn")
public func replacement_posix_spawn(
    _ pid: UnsafeMutablePointer<pid_t>!,
    _ path: UnsafePointer<CChar>!,
    _ actions: UnsafePointer<posix_spawn_file_actions_t>,
    _ attr: UnsafePointer<posix_spawnattr_t>,
    _ argv: UnsafePointer<UnsafeMutablePointer<CChar>>,
    _ envp: UnsafePointer<UnsafeMutablePointer<CChar>>
) -> Int32 {
    if let orig_spawn_pointer {
        return unsafeBitCast(orig_spawn_pointer, to: SpawnBody.self)(pid, path, actions, attr, argv, envp)
    } else {
        return 1;
    }
}
