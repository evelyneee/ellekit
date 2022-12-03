
import Foundation

public protocol Instruction {
        
    init(encoded: Int)
    
    func bytes() -> [UInt8]
    
}

func ror(_ x: Int, _ y: Int) -> Int {
    ((x >> y) | (x << (32 - y)) & 0xFFFFFFFF)
}

extension Instruction {
    static func encodeRegisterInt(_ base: Int, _ rd: Register, _ value: Int) -> Int {
        var base = base
        base |= (rd.w ? 0 : 1) << 31
        base |= value << 5
        base |= rd.value
        let result = reverse(base)
        return result
    }
    
    static func encodeRegRegRegCond(_ base: Int, _ rd: Register, _ rm: Register, _ rn: Register, _ cond: Int) -> Int {
        var base = base
        base |= (rd.w ? 0 : 1) << 31
        base |= rn.value << 16
        base |= cond << 12
        base |= rm.value << 5
        base |= rd.value
        let result = reverse(base)
        return result
    }
}

public class ret: Instruction {
    required public init(encoded: Int) {
        fatalError()
    }
    
    public init() {}
    
    public func bytes() -> [UInt8] {
        self.ret
    }
    
    let ret: [UInt8] = [0xc0, 0x03, 0x5f, 0xd6]
}

public class movz: Instruction {
    let value: Int
    
    public init(_ rd: Register, _ value: Int) {
        self.value = Self.encodeRegisterInt(Self.base, rd, value)
    }
    
    required public init(encoded: Int) {
        self.value = encoded
    }
    
    public func bytes() -> [UInt8] {
        byteArray(from: self.value)
    }
    
    static let base = 0b0_10_100101_00_0000000000000000_00000
}

public class movk: Instruction {
    let value: Int
    
    public init(_ rd: Register, _ value: Int, lsl: Int = 0) {
        var base = Self.base
        base |= (rd.w ? 0 : 1) << 31
        base |= (lsl / 16) << 21
        base |= value << 5
        base |= rd.value
        base = reverse(base)
        self.value = base
    }
    
    required public init(encoded: Int) {
        self.value = encoded
    }
    
    public func bytes() -> [UInt8] {
        byteArray(from: self.value)
    }
    
    static let base = 0b0_11_100101_00_0000000000000000_00000
}

public class csel: Instruction {
    let value: Int
    
    public init(_ rd: Register, _ rm: Register, _ rn: Register, _ value: Cond) {
        self.value = Self.encodeRegRegRegCond(Self.base, rd, rm, rn, value.rawValue)
    }
    
    required public init(encoded: Int) {
        self.value = encoded
    }
    
    public func bytes() -> [UInt8] {
        byteArray(from: self.value)
    }
    
    static let base = 0b0_0_0_11010100_00000_0000_0_0_00000_00000
}

public class bytes: Instruction {
    public let byteValues: [UInt8]
    
    required public init(encoded: Int) {
        self.byteValues = byteArray(from: encoded)
    }
    
    public init(_ bytes: UInt8...) {
        self.byteValues = bytes
    }
    
    public init(_ bytes: [UInt8]) {
        self.byteValues = bytes
    }
    
    public func bytes() -> [UInt8] {
        self.byteValues
    }
}

public class svc: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }
    
    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }
    
    let value: Int
    
    public init(_ sv: Int) {
        self.value = 0x010000D4 | sv << 13
    }
}

public class str: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }
    
    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }
    
    let value: Int
    
    public init(_ rd: Register, _ dest: Register, _ offset: Int = 0) {
        let destOffset = Int((Double(dest.value) / 10).rounded(.down))
        var value = 0x000000F9 | dest.value << 29 | rd.value << 24 | offset << 20 | destOffset << 16
        if offset > 0 {
            value = value + 0xff
        }
        self.value = value
    }
}

public class ldr: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }
    
    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }
    
    let value: Int
    
    public init(_ rt: Register, _ rn: Register, _ offset: Int = 0) {
        let size = rt.w ? 0b10 : 0b11
        var base = Self.base
        base |= size << 30
        base |= offset << 12
        base |= rn.value << 5
        base |= rt.value
        self.value = reverse(base)
    }
    
    static let base = 0b00_111_0_00_01_0_000000000_00_00000_00000
}

public class nop: Instruction {
    
    required public init(encoded: Int) {
    }
    
    public init() {}
    
    let value = 0x1F2003D5
    
    public func bytes() -> [UInt8] {
        byteArray(from: self.value)
    }
}

class adrp: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }
    
    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }
    
    let value: Int
    
    public init(_ rt: Register, _ label: Int = 0) {
        var base = Self.base
        let immlow = label / 4096
        let immhigh = label >> 2 & 0x7ffff
        base |= immlow << 29
        base |= immhigh << 5
        base |= rt.value
        self.value = reverse(base)
    }
    
    public convenience init?(isn: UInt32, formerPC: UInt64, newPC: UInt64) {
        guard let target = Self.destination(isn, formerPC) else {
            return nil
        }
        let rt = isn.bits(0...4)
        self.init(.x(Int(rt)), Int(target - newPC))
    }
    
    static let base = 0b1_00_10000_0000000000000000000_00000
    
    static private func destination(_ instruction: UInt32, _ pc: UInt64) -> UInt64? {
        // Calculate imm from hi and lo
        var imm_hi_lo = (instruction & 0xFFFFE0) >> 3;
        imm_hi_lo |= (instruction & 0x60000000) >> 29;
        if (instruction & 0x800000) == 1 {
            // Sign extend
            imm_hi_lo |= 0xFFE00000;
        }
        
        // Build real imm
        let imm = (imm_hi_lo << 12);
        
        // Emulate
        return (pc & 0xFFFFFFFFFFFFF000) + UInt64(imm);
    }

}

class adr: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }
    
    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }
    
    let value: Int
    
    public init(_ rt: Register, _ label: Int = 0) {
        var base = Self.base
        let immlow = label & 0x3
        let immhigh = label >> 2 & 0x7ffff
        base |= immlow << 29
        base |= immhigh << 5
        base |= rt.value
        self.value = reverse(base)
    }
    
    public convenience init?(isn: UInt32, formerPC: UInt64, newPC: UInt64) {
        let target = Self.destination(isn, formerPC)
        let rt = isn.bits(0...4)
        self.init(.x(Int(rt)), Int(target - newPC))
    }
    
    static let base = 0b0_00_10000_0000000000000000000_00000
    
    static private func destination(_ instruction: UInt32, _ pc: UInt64) -> UInt64 {
        
        var imm = (instruction & 0xFFFFE0) >> 3
        imm |= (instruction & 0x60000000) >> 29
        if (instruction & 0x800000) == 1 {
            // Sign extend
            imm |= 0xFFE00000
        }
        
        return pc + UInt64(imm)
    }
}
