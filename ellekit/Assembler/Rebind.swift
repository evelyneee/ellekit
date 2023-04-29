
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

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
        result |= Int32(signBit << i)
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
                                
                if reversed & 0x9F000000 == 0x10000000 { // adr
                    return adr(isn: reversed, formerPC: formerPC, newPC: newPC)?.bytes()
                }

                if reversed & 0x9F000000 == 0x90000000 { // adrp
                    guard let target = adrp.destination(reversed, formerPC) else {
                        return nil
                    }
                    
                    let register = reversed.bits(0...4)
                    
                    return assembleReference(target: target, register: Int(register)) // this is easier than adrp, since we have unlimited size
                }
                
                if reversed >> 25 == b.condBase >> 25 {

                    let cond = reversed & 0xf
                    let offset = Int((signExtend(((reversed >> 5) & 0x7ffff), 17))) * 4 + 4*index
                    
                    let jump = assembleJump(formerPC + UInt64(offset), pc: newPC, link: false, big: true)
                    return b(8 / 4, cond: .init(Int(cond))).bytes() +
                    b((jump.count / 4) / 4).bytes() +
                        jump
                }
                
                if checkBranch(byteArray) {
                    print("Rebinding branch")
                    let imm = (UInt64(disassembleBranchImm(UInt64(instruction))) + formerPC) - newPC
                    if instruction.reverse() & 0x80000000 == 0x80000000 { // bl
                        return assembleJump(imm + newPC, pc: newPC, link: true)
                    } else { // b
                        return assembleJump(imm + newPC, pc: newPC, link: false)
                    }
                }

                return byteArray
            }
    }
}
