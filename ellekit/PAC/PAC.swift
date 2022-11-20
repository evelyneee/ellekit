
import Foundation

#if SWIFT_PACKAGE
import ellekitc
#endif

extension UnsafeMutableRawPointer {
    
    @inline(never)
    public func makeCallable() -> Self {
        sign_pointer(self)
    }
    
    @inline(never)
    public func makeReadable() -> Self {
        strip_pointer(self)
    }
    
    public func opaquePointer() -> OpaquePointer {
        OpaquePointer(self)
    }
}

extension OpaquePointer {
    func unsafePointer() -> UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(self)
    }
}
