
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

#if SWIFT_PACKAGE
import ellekitc
#endif

public func isDebugged() -> Bool {
    var flags = Int32()
    csops(getpid(), UInt32(CS_OPS_STATUS), &flags, 0)
    
    let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "swh_is_debugged")
    
    if let sym, sym.assumingMemoryBound(to: Int32.self).pointee == 1 {
        return true
    }
    
    return flags & CS_DEBUGGED != 0
}
