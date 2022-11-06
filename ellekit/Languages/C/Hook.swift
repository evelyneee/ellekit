
import Foundation
import ElleKitC

func patchFunction(_ function: UnsafeMutableRawPointer, @InstructionBuilder _ instructions: () -> [UInt8]) {
    
    let code = instructions()
        
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
    
    code.withUnsafeBufferPointer { buf in
        let result = rawHook(address: function.makeReadable(), code: buf.baseAddress, size: size)
        #if DEBUG
        print(result)
        #else
        _ = result
        #endif
    }
}

func hook(_ stockTarget: UnsafeMutableRawPointer, _ stockReplacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    
    let target = stockTarget.makeReadable()
    let replacement = stockReplacement.makeReadable()
    
    let targetSize = findFunctionSize(target) ?? 6
        
    print("[*] Size of target:", targetSize as Any)
    
    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4
    
    hooks[target] = replacement

    var code = [UInt8]()
    
    /*
     if abs(branchOffset / 1024 / 1024) > 128 {
         guard targetSize >= 5 else { fatalError("[-] ellekit: this hook is impossible (big branch, but function does not have enough space)")}
         print("[*] Big branch")

         let target_addr = Int(UInt(bitPattern: replacement))

         @InstructionBuilder
         var codeBuilder: [UInt8] {
             movk(.x16, target_addr % 65536)
             movk(.x16, (target_addr / 65536) % 65536, lsl: 16)
             movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32)
             movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48) // stop overflow error :)
             br(.x16)
         }

         code = codeBuilder
     } else
     */
    
    if abs(branchOffset / 1024 / 1024) > 128 {
        if exceptionHandler == nil {
            exceptionHandler = .init()
        }
        code = [0x20, 0x00, 0x20, 0xD4]
    } else {
        print("[*] Small branch")
        @InstructionBuilder
        var codeBuilder: [UInt8] {
            b(branchOffset)
        }
        code = codeBuilder
    }
                
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
    
    let orig = getOriginal(target, targetSize, usedBigBranch: false) // abs(branchOffset / 1024 / 1024) > 128 && targetSize >= 5
    
    code.withUnsafeBufferPointer { buf in
        let result = rawHook(address: target, code: buf.baseAddress, size: size)
        assert(result == 0, "[-] Hook failure for \(target) to \(replacement)")
    }
    
    return orig.0?.makeCallable()
}

func hook(_ originalTarget: UnsafeMutableRawPointer, _ originalReplacement: UnsafeMutableRawPointer) {
        
    let target = originalTarget.makeReadable()
    let replacement = originalReplacement.makeReadable()
    
    let targetSize = findFunctionSize(target) ?? 6
    print("[*] Size of target:", targetSize as Any)
            
    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4
    
    var code = [UInt8]()
    
    if abs(branchOffset / 1024 / 1024) > 128 {
        if exceptionHandler == nil {
            exceptionHandler = .init()
        }
        code = [0x20, 0x00, 0x20, 0xD4]
    } else {
        print("[*] Small branch")
        @InstructionBuilder
        var codeBuilder: [UInt8] {
            b(branchOffset)
        }
        code = codeBuilder
    }
    
    hooks[target] = replacement
            
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
        
    code.withUnsafeBufferPointer { buf in
        let result = rawHook(address: target, code: buf.baseAddress, size: size)
        assert(result == 0, "[-] Hook failure for \(target) to \(replacement)")
    }
}

func rawHook(address: UnsafeMutableRawPointer, code: UnsafePointer<UInt8>?, size: mach_vm_size_t) -> Int {
    let newPermissions = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY;
    mach_vm_protect(mach_task_self_, mach_vm_address_t(UInt(bitPattern: address)), mach_vm_size_t(size), 0, newPermissions);
    
    memcpy(address, code, Int(size));
    
    let originalPerms = VM_PROT_READ | VM_PROT_EXECUTE;
    let err2 = mach_vm_protect(mach_task_self_,
                               mach_vm_address_t(UInt(bitPattern: address)),
                               mach_vm_size_t(size),
                               0,
                               originalPerms)
    
    guard err2 == 0 else { return 1 }
    
    return 0;
}
