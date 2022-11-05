
import Foundation

extension UnsafeMutableRawPointer {
    func makeCallable() -> Self {
        sign(self)
    }
    
    func makeReadable() -> Self {
        strip(self)
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
