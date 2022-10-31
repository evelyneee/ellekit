
import Foundation

enum FunctionSize {
    case found(Int) // 1 to 5
    case indeterminate // 6 or bigger
}

func checkBranch(_ opcode: UInt64) -> Bool {
            
    let opcode = UInt64(reverse(Int(opcode)))
    let bits = bits(opcode, 25, 28)
        
    if (bits >> 1) == 5 {
        return true
    }
        
    return false
}

func bits(_ target: UInt64, _ start: UInt64, _ end: UInt64) -> UInt64 {
    let amount: UInt64 = (end - start) + 1;
    let mask: UInt64 = ((1 << amount) - 1) << start;

    return (target & mask) >> start
}

func sign_extend(_ number: Int, _ numbits: Int) -> Int {
    if (number & (1 << (numbits - 1))) == 1 {
        return number | ~((1 << numbits) - 1);
    }
    return number;
}

func checkBranch(_ isn: [UInt8]) -> Bool {
    let isn: UInt64 = (UInt64(isn[3]) | UInt64(isn[2]) << 8 | UInt64(isn[1]) << 16 | UInt64(isn[0]) << 24)
    if isn == 0x7F2303D5 {
        return false
    }
    return checkBranch(isn)
}

func findFunctionSize(_ target: UnsafeMutableRawPointer) -> Int? {
    let instructions: [UInt8] = target.withMemoryRebound(to: UInt8.self, capacity: 4 * 5, { ptr in
        Array(UnsafeMutableBufferPointer(start: ptr, count: 4 * 5))
    })
    let isns: [[UInt8]] = (0..<(instructions.count / 4)).map { offset in
        let base = offset*4
        return [
            instructions[base+0],
            instructions[base+1],
            instructions[base+2],
            instructions[base+3]
        ]
    }
    for (idx, isn) in isns.enumerated() {
        print(isn.map { String(format: "%02X", $0) }.joined() )
        if checkBranch(isn) {
            return (idx + 1)
        }
    }
    return nil
}
