
import Foundation

#if SWIFT_PACKAGE
import ellekitc
#endif

public func patchFunction(_ function: UnsafeMutableRawPointer, @InstructionBuilder _ instructions: () -> [UInt8]) {
    
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

public func hook(_ stockTarget: UnsafeMutableRawPointer, _ stockReplacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    
    let target = stockTarget.makeReadable()
    let replacement = stockReplacement.makeReadable()
    
    let targetSize = findFunctionSize(target) ?? 6
        
    print("[*] ellekit: Size of target:", targetSize as Any)
    
    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4
    
    hooks[target] = replacement

    var code = [UInt8]()
    
    #warning("TODO: Write some PC-relative instruction redirection code")
    /// Big branch code, unused atm because there are issues
     if targetSize >= 5 && abs(branchOffset / 1024 / 1024) > 128 {
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
     } else if abs(branchOffset / 1024 / 1024) > 128 {
        if exceptionHandler == nil {
            exceptionHandler = .init()
        }
        code = [0x20, 0x00, 0x20, 0xD4]
    } else {
        print("[*] ellekit: Small branch")
        @InstructionBuilder
        var codeBuilder: [UInt8] {
            b(branchOffset)
        }
        code = codeBuilder
    }
                
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
    
    let orig = getOriginal(
        target,
        targetSize,
        usedBigBranch: abs(branchOffset / 1024 / 1024) > 128 && targetSize >= 5
    )
    
    code.withUnsafeBufferPointer { buf in
        let result = rawHook(address: target, code: buf.baseAddress, size: size)
        #if DEBUG
        assert(result == 0, "[-] ellekit: Hook failure for \(target) to \(replacement)")
        #else
        if result != 0 {
            if #available(macOS 11.0, *) {
                logger.error("ellekit: Hook failure for \(target) to \(replacement)")
            }
        }
        #endif
    }
    
    return orig.0?.makeCallable()
}

public func hook(_ originalTarget: UnsafeMutableRawPointer, _ originalReplacement: UnsafeMutableRawPointer) {
        
    let target = originalTarget.makeReadable()
    let replacement = originalReplacement.makeReadable()
    
    let targetSize = findFunctionSize(target) ?? 6
    print("[*] ellekit: Size of target:", targetSize as Any)
            
    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4
    
    var code = [UInt8]()
    
    if targetSize >= 5 && abs(branchOffset / 1024 / 1024) > 128 {
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
    } else if abs(branchOffset / 1024 / 1024) > 128 {
        if exceptionHandler == nil {
            exceptionHandler = .init()
        }
        code = [0x20, 0x00, 0x20, 0xD4] // process crash!
    } else {
        print("[*] ellekit: Small branch")
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
        #if DEBUG
        assert(result == 0, "[-] ellekit: Hook failure for \(target) to \(replacement)")
        #else
        if result != 0 {
            if #available(macOS 11.0, *) {
                logger.error("ellekit: Hook failure for \(target) to \(replacement)")
            }
        }
        #endif
    }
}

@discardableResult
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
    
    // flush page cache so we don't hit cached unpatched functions
    sys_icache_invalidate(address, Int(size))
    
    guard err2 == 0 else { return Int(err2) }
    
    return 0;
}
