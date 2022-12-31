import Foundation
import os.log

// target:replacement
public var hooks: [UnsafeMutableRawPointer: UnsafeMutableRawPointer] = [:]

public var exceptionHandler: ExceptionHandler?

public var enforceThreadSafety: Bool = false

@_cdecl("EKEnableThreadSafety")
public func EKEnableThreadSafety(_ on: Int) {
    enforceThreadSafety = on == 1
}
