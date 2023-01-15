
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation
import os.log

// target:replacement
public var hooks: [UnsafeMutableRawPointer: UnsafeMutableRawPointer] = [:]

public var exceptionHandler: ExceptionHandler?

public var enforceThreadSafety: Bool = true

@_cdecl("EKEnableThreadSafety")
public func EKEnableThreadSafety(_ on: Int) {
    enforceThreadSafety = on == 1
}
