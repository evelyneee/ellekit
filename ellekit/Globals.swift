
import Foundation
import os.log

// target:replacement
public var hooks: [UnsafeMutableRawPointer: UnsafeMutableRawPointer] = [:]

public var exceptionHandler: ExceptionHandler?

@available(iOS 14.0, macOS 11.0, *)
public let logger = Logger(subsystem: "red.charlotte.ellekit", category: "hooking")

public var enforceThreadSafety: Bool = false

@_cdecl("EKEnableThreadSafety")
public func EKEnableThreadSafety(_ on: Int) {
    enforceThreadSafety = on == 1
}

