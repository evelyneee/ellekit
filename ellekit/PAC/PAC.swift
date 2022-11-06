
import Foundation
import ellekitc

extension UnsafeMutableRawPointer {
    
    @inline(never)
    func makeCallable() -> Self {
        sign_pointer(self)
    }
    
    @inline(never)
    func makeReadable() -> Self {
        strip_pointer(self)
    }
    
    func opaquePointer() -> OpaquePointer {
        OpaquePointer(self)
    }
}

extension OpaquePointer {
    func unsafePointer() -> UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(self)
    }
}
