
import Foundation

// target:replacement
public var hooks: [UnsafeMutableRawPointer: UnsafeMutableRawPointer] = [:]

#if os(macOS)
public var slide: Int = _dyld_get_image_vmaddr_slide(0)
#endif

var exceptionHandler: ExceptionHandler?
