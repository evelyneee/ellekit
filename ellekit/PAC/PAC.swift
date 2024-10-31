
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

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
