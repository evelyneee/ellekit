
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

@_cdecl("posix_spawn_replacement")
public func posix_spawn_replacement(
    _ pid: UnsafeMutablePointer<pid_t>,
    _ path: UnsafePointer<CChar>,
    _ file_actions: UnsafePointer<posix_spawn_file_actions_t?>?,
    _ spawnattr: UnsafePointer<posix_spawnattr_t?>?,
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
    _ file_actions: UnsafePointer<posix_spawn_file_actions_t?>?,
    _ spawnattr: UnsafePointer<posix_spawnattr_t?>?,
    _ argv: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    _ envp: UnsafePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let ret = spawn_replacement(true, pid, path, file_actions, spawnattr, argv, envp)
    return ret
}
