
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

public class paciza: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ register: Register) {
        var base = Self.base
        base |= 1 << 13
        base |= Register.xzr.value << 5
        base |= register.value
        self.value = reverse(base)
    }

    static let base = 0b1_1_0_11010110_00001_0_0_0_000_00000_00000
}

public class pacia: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ target: Register, _ key: Register) {
        var base = Self.base
        base |= 0 << 13
        base |= key.value << 5
        base |= target.value
        self.value = reverse(base)
    }

    static let base = 0b1_1_0_11010110_00001_0_0_0_000_00000_00000
}
