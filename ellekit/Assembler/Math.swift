import Foundation

private func encodeImm(_ base: Int, _ rd: Register, _ rn: Register, _ imm: Int, _ lsl: Int) -> Int {
    var base = base
    base |= (rd.w ? 0 : 1) << 31
    base |= (lsl/12) << 22
    base |= imm << 10
    base |= rn.value << 5
    base |= rd.value
    let result = reverse(base)
    return result
}

public class sub: Instruction {
    let value: Int
    required public init(encoded: Int) {
        self.value = encoded
    }

    public init(_ rd: Register, _ rn: Register, _ imm: Int) {
        self.value = encodeImm(Self.base, rd, rn, imm, 16)
    }

    public func bytes() -> [UInt8] {
        byteArray(from: self.value)
    }

    static let base = 0b0_1_1_100010_0_000000000000_00000_00000
}

public class add: Instruction {
    let value: Int
    required public init(encoded: Int) {
        self.value = encoded
    }

    public init(_ rd: Register, _ rn: Register, _ imm: Int) {
        self.value = encodeImm(Self.base, rd, rn, imm, 0)
    }

    public func bytes() -> [UInt8] {
        byteArray(from: self.value)
    }

    static let base = 0b0_0_0_100010_0_000000000000_00000_00000
}
