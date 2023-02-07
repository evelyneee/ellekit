
import Foundation


extension UnsafeRawPointer {
    public func hexDump(_ size: Int) {
        var unpatched = self.withMemoryRebound(to: UInt8.self, capacity: size, { ptr in
            Array(UnsafeBufferPointer(start: ptr, count: size))
        })
        
        print(unpatched.map { String(format: "%02X", $0) }.joined())
    }
}
