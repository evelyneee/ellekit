
import Foundation
import os.log

// target:replacement
public var hooks: [UnsafeMutableRawPointer: UnsafeMutableRawPointer] = [:]

public var exceptionHandler: ExceptionHandler?

@available(macOS 11.0, *)
public let logger = Logger(subsystem: "red.charlotte.ellekit", category: "hooking")
