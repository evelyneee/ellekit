func disassembleBranchImm(_ opcode: UInt64) -> Int {
    var imm = (opcode & 0x3FFFFFF) << 2
    if (opcode & 0x2000000) == 1 {
        // Sign extend
        imm |= 0xFC000000
    }
    return Int(imm)
}

func redirectBranch(_ target: UnsafeMutableRawPointer, _ isn: UInt64, _ ptr: UnsafeMutableRawPointer) -> [UInt8] {
    let pcRel = disassembleBranchImm(reverse(isn))

    let originalTarget = UInt64(UInt(bitPattern: target)) + UInt64(pcRel)

    let code = assembleJump(originalTarget, pc: UInt64(UInt(bitPattern: target)), link: false)

    return code
}

// PAC: strip before calling this function
func calculateOffset(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) -> Int {
    let sign = target > replacement ? -1 : 1
    let offsetAbs = abs((Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target)))) / 4
    return offsetAbs * sign
}

public class b: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ addr: Int) {
        var base = Self.base
        base |= (addr & 0x3ffffff)
        self.value = reverse(base)
    }

    static let base = 0b0_00101_00000000000000000000000000
}

public class bl: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ addr: Int) {
        var base = Self.base
        base |= addr
        self.value = reverse(base)
    }

    static let base = 0b1_00101_00000000000000000000000000
}

public class blr: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ register: Register) {
        var base = Self.base
        base |= (register.value << 5)
        self.value = reverse(base)
    }

    static let base = 0b1101011_0_0_01_11111_0000_0_0_00000_00000
}

public class br: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ register: Register) {
        var base = Self.base
        base |= register.value << 5
        self.value = reverse(base)
    }

    static let base = 0b1101011_0_0_00_11111_0000_0_0_00000_00000
}

func assembleJump(_ target: UInt64, pc: UInt64, size: Int = 5, link: Bool, big: Bool = false) -> [UInt8] {
    let offset = Int(target - pc)
    if (size >= 5 && abs(offset / 1024 / 1024) > 128) || big {
        let target_addr = Int(UInt64(offset) + pc)
        let codeBuild = [
            movk(.x16, target_addr % 65536).bytes(),
            movk(.x16, (target_addr / 65536) % 65536, lsl: 16).bytes(),
            movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32).bytes(),
            movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48).bytes(),
            link ? blr(.x16).bytes() : br(.x16).bytes()
        ]
        return codeBuild.joined().literal()
    } else {
        let codeBuild = [
            link ? bl(offset).bytes() : b(offset).bytes()
        ]
        return codeBuild.joined().literal()
    }
}
