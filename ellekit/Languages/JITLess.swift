
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

@_cdecl("EKLaunchExceptionHandler")
public func launchExceptionHandler() {
    if exceptionHandler == nil {
         exceptionHandler = .init()
    }
}

@_cdecl("EKAddHookToRegistry")
public func addHookToRegistry(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) {
    hooks[target] = replacement;
}

@_silgen_name("EKJITLessHook")
public func hardwareHook(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer, _ orig: UnsafeMutablePointer<UnsafeMutableRawPointer?>?)
