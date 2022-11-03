
import Foundation

func patchFunction(_ function: UnsafeMutableRawPointer, @InstructionBuilder _ instructions: () -> [UInt8]) {
    
    let code = instructions()
        
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
    
    code.withUnsafeBufferPointer { buf in
        let result = hook(function.makeReadable(), buf.baseAddress, size)
        #if DEBUG
        print(result)
        #else
        _ = result
        #endif
    }
}

func hook(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    
    let target = target.makeReadable()
    let replacement = replacement.makeReadable()
    
    let targetSize = findFunctionSize(target) ?? 6
    print("[*] Size of target:", targetSize as Any)
    
    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4
            
    var code: [UInt8] = [0x20, 0x00, 0x20, 0xD4]
    
    print("[*] Using brk #1 method")
    
    hooks[target] = replacement

//    if abs(branchOffset / 1024 / 1024) > 128 {
//        guard targetSize >= 5 else { fatalError("[-] ellekit: this hook is impossible (big branch, but function does not have enough space)")}
//        print("[*] Big branch")
//
//        let target_addr = Int(UInt(bitPattern: replacement))
//
//        @InstructionBuilder
//        var codeBuilder: [UInt8] {
//            movk(.x16, target_addr % 65536)
//            movk(.x16, (target_addr / 65536) % 65536, lsl: 16)
//            movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32)
//            movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48) // stop overflow error :)
//            br(.x16)
//        }
//
//        code = codeBuilder
//    } else {
//        print("[*] Small branch")
//        @InstructionBuilder
//        var codeBuilder: [UInt8] {
//            b(branchOffset)
//        }
//        code = codeBuilder
//    }
            
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
    
    let orig = getOriginal(target, targetSize, usedBigBranch: abs(branchOffset / 1024 / 1024) > 128)
    
    code.withUnsafeBufferPointer { buf in
        let result = hook(target, buf.baseAddress, size)
        assert(result == 0, "[-] Hook failure for \(target) to \(replacement)")
    }
    
    return orig.0?.makeCallable()
}

func hook(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) {
    
    let target = target.makeReadable()
    let replacement = replacement.makeReadable()
    
    let targetSize = findFunctionSize(target) ?? 6
    print("[*] Size of target:", targetSize as Any)
    
    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4
            
    var code: [UInt8] = [0x20, 0x00, 0x20, 0xD4]
    
    print("[*] Using brk #1 method")
//    if abs(branchOffset / 1024 / 1024) > 128 {
//        guard targetSize >= 5 else { fatalError("[-] ellekit: this hook is impossible (big branch, but function does not have enough space)")}
//        print("[*] Big branch")
//
//        let target_addr = Int(UInt(bitPattern: replacement))
//
//        @InstructionBuilder
//        var codeBuilder: [UInt8] {
//            movk(.x16, target_addr % 65536)
//            movk(.x16, (target_addr / 65536) % 65536, lsl: 16)
//            movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32)
//            movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48) // stop overflow error :)
//            br(.x16)
//        }
//
//        code = codeBuilder
//    } else {
//        print("[*] Small branch")
//        @InstructionBuilder
//        var codeBuilder: [UInt8] {
//            b(branchOffset)
//        }
//        code = codeBuilder
//    }
    
    hooks[target] = replacement
            
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
        
    code.withUnsafeBufferPointer { buf in
        let result = hook(target, buf.baseAddress, size)
        assert(result == 0, "[-] Hook failure for \(target) to \(replacement)")
    }
}
