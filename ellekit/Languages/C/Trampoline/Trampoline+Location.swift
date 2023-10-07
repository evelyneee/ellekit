
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

extension Trampoline {
    public func findLocation() -> UnsafeMutableRawPointer? {
        for isnIdx in 0..<(128_000_000/4) {
            let isnptr = self.base.advanced(by: 256).advanced(by: isnIdx * 4).assumingMemoryBound(to: UInt32.self)
            let isn = isnptr.pointee
                                    
            if isn == 0xD503237F {
                print("[+] trampoline: found pacibsp", isnptr)

                let size = findFunctionSize(UnsafeMutableRawPointer(mutating: isnptr.advanced(by: 4)), max: 15) ?? 16

                if size > 8 {
                    print("[+] trampoline: found trampoline victim", isnptr)
                    return UnsafeMutableRawPointer(isnptr)
                }
            }
            
            /*
            if isn == 0xD65F03C0 { // found a ret
                
                print("[+] trampoline: found ret")
                
                let size = findFunctionSize(UnsafeMutableRawPointer(mutating: self.base.assumingMemoryBound(to: UInt32.self).advanced(by: isnIdx * 4 + 4)), max: 15) ?? 16
                                
                if size > 8 {
                    print("[+] trampoline: found trampoline victim", isnptr.advanced(by: 4))
                    return UnsafeMutableRawPointer(isnptr)
                }
            }
             */
        }
        return nil
    }

}
