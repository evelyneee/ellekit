
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

extension Instructions {
    func rebind(formerPC: UInt64, newPC: UInt64) -> [[UInt8]] {
        self
            .compactMap { byteArray in
                let instruction = combine(byteArray)

                if instruction == 0x7F2303D5 {
                    return byteArray
                }

                let reversed = instruction.reverse()

                if reversed & 0x9F000000 == 0x90000000 { // adr
                    return adr(isn: instruction, formerPC: formerPC, newPC: newPC)?.bytes()
                }

                if reversed & 0x9F000000 == 0x90000000 { // adrp
                    return adrp(isn: instruction, formerPC: formerPC, newPC: newPC)?.bytes()
                }

                if checkBranch(byteArray) {
                    let imm = (UInt64(disassembleBranchImm(UInt64(instruction))) + formerPC) - newPC
                    if instruction.reverse() & 0x80000000 == 0x80000000 { // bl
                        print("bl")
                        return assembleJump(imm + newPC, pc: newPC, link: true)
                    } else { // b
                        return assembleJump(imm + newPC, pc: newPC, link: false)
                    }
                }

                return byteArray
            }
    }

}
