
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

func combine(_ isns: [UInt8]) -> UInt32 {
    let instruction: UInt64 = (UInt64(isns[3]) | UInt64(isns[2]) << 8 | UInt64(isns[1]) << 16 | UInt64(isns[0]) << 24)
    return UInt32(instruction)
}

typealias Instructions = [[UInt8]]

extension FlattenSequence {
    func literal() -> [Self.Element] {
        Array(self)
    }
}

func signExtend(_ immediate: UInt32, _ offset: UInt8) -> Int32 {
    var result = Int32(bitPattern: immediate)
    let signBit = (immediate >> offset) & 0x1
    for i in (offset + 1) ..< 32 {
        result |= Int32(bitPattern: signBit << i)
    }
    return result
}

extension Instructions {
    func rebind(formerPC: UInt64, newPC: UInt64) -> [[UInt8]] {
        self
            .enumerated()
            .compactMap { (index, byteArray) -> [UInt8]? in
                let instruction = combine(byteArray)
                
                if instruction == 0x7F2303D5 {
                    return byteArray
                }
                
                let reversed = instruction.reverse()
                            
                // MARK: - adr(p)
                
                if reversed & 0x9F000000 == 0x10000000 { // adr
                    print("rebinded adr")
                    let target = adr.destination(reversed, formerPC)
                    
                    let register = reversed.bits(0...4)
                                        
                    return assembleReference(target: target, register: Int(register)) // this is easier than adrp, since we have unlimited size
                }

                if reversed & 0x9F000000 == 0x90000000 { // adrp
                    print("rebinded adrp")
                    guard let target = adrp.destination(reversed, formerPC) else {
                        return nil
                    }
                    
                    let register = reversed.bits(0...4)
                                        
                    return assembleReference(target: target, register: Int(register)) // this is easier than adrp, since we have unlimited size
                }
                
                // MARK: - b.cond
                
                if reversed >> 25 == b.condBase >> 25 {
                    print("rebinded b.cond")
                    let cond = reversed & 0xf
                    let offset: Int32 = (signExtend(((reversed >> 5) & 0x7ffff), 17) * 4 + Int32(4*index))

                    let jump = assembleJump(UInt64(Int64(formerPC) + Int64(offset)), pc: newPC, link: false, big: true)
                    return b(8 / 4, cond: .init(Int(cond))).bytes() +
                    b(Int((Double(jump.count + 4) / 4))).bytes() +
                        jump
                }
                
                // MARK: - 64-bit CBZ/CBNZ
                
                if reversed >> 24 == (cbz.base | (1 << 31)) >> 24 {
                    print("rebinded cbz")
                    let register = reversed & 0x1f
                    let offset: Int32 = (signExtend(((reversed >> 5) & 0x7ffff), 17) * 4 + Int32(4*index))
                                        
                    let jump = assembleJump(UInt64(Int64(formerPC) + Int64(offset)), pc: newPC, link: false, big: true)
                    return cbz(.x(Int(register)), 8 / 4).bytes() +
                    b(Int((Double(jump.count + 4) / 4))).bytes() +
                        jump
                }
                
                if reversed >> 24 == (cbnz.base | (1 << 31)) >> 24 {
                    print("rebinded cbnz")
                    let register = reversed & 0x1f
                    let offset: Int32 = (signExtend(((reversed >> 5) & 0x7ffff), 17) * 4 + Int32(4*index))
                                        
                    let jump = assembleJump(UInt64(Int64(formerPC) + Int64(offset)), pc: newPC, link: false, big: true)
                    return cbnz(.x(Int(register)), 8 / 4).bytes() +
                    b(Int((Double(jump.count + 4) / 4))).bytes() +
                        jump
                }
                
                // MARK: - 32-bit CBZ/CBNZ
                
                if reversed >> 24 == (cbz.base) >> 24 {
                    print("rebinded 32-bit cbz")
                    let register = reversed & 0x1f
                    let offset: Int32 = (signExtend(((reversed >> 5) & 0x7ffff), 17) * 4 + Int32(4*index))
                                        
                    let jump = assembleJump(UInt64(Int64(formerPC) + Int64(offset)), pc: newPC, link: false, big: true)
                    return cbz(.w(Int(register)), 8 / 4).bytes() +
                    b(Int((Double(jump.count + 4) / 4))).bytes() +
                        jump
                }
                
                if reversed >> 24 == (cbnz.base) >> 24 {
                    print("rebinded 32-bit cbnz")
                    let register = reversed & 0x1f
                    let offset: Int32 = (signExtend(((reversed >> 5) & 0x7ffff), 17) * 4 + Int32(4*index))
                                        
                    let jump = assembleJump(UInt64(Int64(formerPC) + Int64(offset)), pc: newPC, link: false, big: true)
                    return cbnz(.w(Int(register)), 8 / 4).bytes() +
                    b(Int((Double(jump.count + 4) / 4))).bytes() +
                        jump
                }
                
                // MARK: - Plain branches
                
                if checkBranchLink(byteArray) {
                    print("Rebinding branch")
                    var imm = UInt64(Int32((reversed & 0x3FFFFFF) << 2))
                    if (reversed & 0x2000000) != 0 {
                        // Sign extend
                        imm |= 0xFFFFFFFFFC000000
                    }

                    imm += UInt64(4*index)
                    
                    print("it's jumping now to : ", String(format: "0x%02llX", formerPC &+ imm))

                    if instruction.reverse() & 0x80000000 == 0x80000000 { // bl
                        return assembleJump(formerPC &+ imm, pc: newPC, link: true, big: true, jmpReg: .x17)
                    } else { // b
                        return assembleJump(formerPC &+ imm, pc: newPC, link: false, big: true, jmpReg: .x17)
                    }
                }

                return byteArray
            }
    }
}
