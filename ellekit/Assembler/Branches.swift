
func disassembleBranchImm(_ opcode: UInt64) -> Int {
    let imm = bits(UInt64(reverse(Int(opcode))), 0, 25);
    
    if (imm << 2) > 1024 * 1024 * 128 {
        print("negative branch")
        let ret = ((0xfffffffff0000000 | imm << 2) & UInt64.max) ^ UInt64.max
        return -Int(ret)
    }
    
    return Int(imm << 2)
}

func redirectBranch(_ target: UnsafeMutableRawPointer, _ isn: UInt64, _ ptr: UnsafeMutableRawPointer) -> [UInt8] {
    let pcRel = disassembleBranchImm(isn)

    let originalTarget = Int(UInt(bitPattern: target)) + (Int(pcRel) * 4)
        
    let offset = calculateOffset(ptr, UnsafeMutableRawPointer(bitPattern: originalTarget)!)
    
    var code = [UInt8]()
    if (offset / 1024 / 1024) > 128 { // 128mb tiny branch not allowed
        @InstructionBuilder
        var codeBuilt: [UInt8] {
            movz(.x16, 0)
            movk(.x16, originalTarget % 65536)
            movk(.x16, (originalTarget / 65536) % 65536, lsl: 16)
            movk(.x16, ((originalTarget / 65536) / 65536) % 65536, lsl: 32)
            movk(.x16, ((originalTarget / 65536) / 65536) / 65536, lsl: 48) // stop overflow error :)
            br(.x16)
        }
        code = codeBuilt
    } else {
        @InstructionBuilder
        var codeBuilt: [UInt8] {
            b(offset)
        }
        code = codeBuilt
    }
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
