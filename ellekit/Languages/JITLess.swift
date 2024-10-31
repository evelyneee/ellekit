
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

@_cdecl("EKLaunchExceptionHandler")
public func launchExceptionHandler() -> mach_port_t {
    if exceptionHandler == nil {
         exceptionHandler = .init()
    }
    
    return exceptionHandler?.port ?? 0
}

@_cdecl("EKAddHookToRegistry")
public func addHookToRegistry(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) {
    hooks[target] = replacement;
}

@_silgen_name("EKJITLessHook")
public func hardwareHook(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer, _ orig: UnsafeMutablePointer<UnsafeMutableRawPointer?>?)
