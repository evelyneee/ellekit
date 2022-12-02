//
//  disasm.swift
//  ellekit
//
//  Created by charlotte on 2022-12-02.
//

import Foundation

func combine(_ isns: [UInt8]) -> UInt32 {
    let instruction: UInt64 = (UInt64(isns[3]) | UInt64(isns[2]) << 8 | UInt64(isns[1]) << 16 | UInt64(isns[0]) << 24)
    return UInt32(instruction)
}

func rebind_isns(_ instructions: [[UInt8]], formerPC: UInt64, newPC: UInt64) -> [[UInt8]] {
    return instructions
        .enumerated()
        .compactMap { (idx, byteArray) -> [UInt8]? in
            let instruction = combine(byteArray)
            
            if instruction == 0x7F2303D5 {
                return byteArray
            }
            
            if reverse(instruction) & 0x9F000000 == 0x10000000 { // adr
                return adr(isn: instruction, formerPC: formerPC, newPC: newPC)?.bytes()
            }
            
            if reverse(instruction) & 0x9F000000 == 0x90000000 { // adrp
                return adrp(isn: instruction, formerPC: formerPC, newPC: newPC)?.bytes()
            }
            
            if checkBranch(byteArray) {
                let imm = branch_destination(instruction: instruction, pc: formerPC) - newPC
                if reverse(instruction) & 0x80000000 == 0x80000000 { // bl
                    if abs(Int(imm) / 1024 / 1024) > 128 { // big branch lol
                        let target_addr = Int(imm + newPC)
                        let codeBuild: [Instruction] = [
                            movk(.x16, target_addr % 65536),
                            movk(.x16, (target_addr / 65536) % 65536, lsl: 16),
                            movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32),
                            movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48),
                            blr(.x16)
                        ]
                        return Array(codeBuild.map { $0.bytes() }.joined())
                    }
                    return bl(Int(imm)).bytes()
                } else { // b
                    if abs(Int(imm) / 1024 / 1024) > 128 { // big branch lol
                        let target_addr = Int(imm + newPC)
                        let codeBuild: [Instruction] = [
                            movk(.x16, target_addr % 65536),
                            movk(.x16, (target_addr / 65536) % 65536, lsl: 16),
                            movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32),
                            movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48),
                            br(.x16)
                        ]
                        return Array(codeBuild.map { $0.bytes() }.joined())
                    }
                    return b(Int(imm)).bytes()
                }
            }
            return byteArray
        }
}

func branch_destination(instruction: UInt32, pc: UInt64) -> UInt64 {
    
    var imm = (instruction & 0x3FFFFFF) << 2;
    if (instruction & 0x2000000) == 1 {
        // Sign extend
        imm |= 0xFC000000
    }
    
    return pc + UInt64(imm);
}
/**
 * Emulate an adrp instruction at the given pc value
 * Returns adrp destination
 */
func adrp_destination(_ instruction: UInt32, _ pc: UInt64) -> UInt64? {
    // Check that this is an adrp instruction
    if ((instruction & 0x9F000000) != 0x90000000) {
        return nil;
    }
    
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

private func aarch64_emulate_add_imm(_ instruction: UInt32, _ dst: inout UInt32, _ src: inout UInt32, _ imm: inout UInt32) -> Bool {
    // Check that this is an add instruction with immediate
    if ((instruction & 0xFF000000) != 0x91000000) {
        return false;
    }
    
    let imm12 = (instruction & 0x3FFC00) >> 10;
    
    let shift = (instruction & 0xC00000) >> 22;
    
    switch (shift) {
        case 0:
            imm = imm12;
            break;
            
        case 1:
            imm = imm12 << 12;
            break;
            
        default:
            return false;
    }
    
    dst = instruction & 0x1F;
    src = (instruction >> 5) & 0x1F;
    
    return true;
}

/**
 * Emulate an adrp and add instruction at the given pc value
 * Returns destination
 */
private func get_adrp_add_dest(_ instruction: UInt32, _ addInstruction: UInt32, _ pc: UInt64) -> UInt64? {
    let adrp_target = adrp_destination(instruction, pc);
    guard let adrp_target else {
        return nil;
    }
    
    var addDst: UInt32 = 0
    var addSrc: UInt32 = 0
    var addImm: UInt32 = 0
    guard aarch64_emulate_add_imm(addInstruction, &addDst, &addSrc, &addImm) == true else {
        return nil;
    }
    
    if ((instruction & 0x1F) != addSrc) {
        return nil;
    }
    
    // Emulate
    return adrp_target + UInt64(addImm);
}

/**
 * Emulate an adrp and ldr instruction at the given pc value
 * Returns destination
 */
func get_adrp_ldr_dest(_ instruction: UInt32, _ ldrInstruction: UInt32, _ pc: UInt64) -> UInt64 {
    let adrp_target = adrp_destination(instruction, pc);
    guard let adrp_target else {
        return 0;
    }
    
    if ((instruction & 0x1F) != ((ldrInstruction >> 5) & 0x1F)) {
        return 0;
    }
    
    if ((ldrInstruction & 0xFFC00000) != 0xF9400000) {
        return 0;
    }
    
    let imm12 = ((ldrInstruction >> 10) & 0xFFF) << 3
    
    // Emulate
    return adrp_target + UInt64(imm12);
}
