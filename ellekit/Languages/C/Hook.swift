
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

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

@_cdecl("EKHookFunction")
public func hook(_ stockTarget: UnsafeMutableRawPointer, _ stockReplacement: UnsafeMutableRawPointer, _ internalSkipChecks: Bool = false) -> UnsafeMutableRawPointer? {
    
    /*
    guard isDebugged() else {
        var orig: UnsafeMutableRawPointer? = nil
        hardwareHook(stockTarget, stockReplacement, &orig)
        return orig
    }
     */
    
    var target = stockTarget.makeReadable()
    let replacement = stockReplacement.makeReadable()
    
    if let newReplacement = hooks[target], !internalSkipChecks {
        return hook(newReplacement.makeReadable(), replacement)
    }
    
//    var info = Dl_info()
//    dladdr(target, &info)
//    var info2 = Dl_info()
//    dladdr(target, &info2)
//    if let name = info.dli_sname, let frame = info.dli_fname {
//        NSLog("[hookinfo] \(String(describing: target))/\(String(cString: name)) in \(String(cString: frame)) -> \(String(describing: replacement))/\(info.dli_sname == nil ? "" : String(cString: info.dli_sname))")
//    }
    
    print("finding size", target)
    
    let targetSize = findFunctionSize(target) ?? 6
    let safeReg = findSafeRegister(target)

    print("[*] ellekit: Size of target:", targetSize as Any)

    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4

    hooks[target] = replacement

    var code = [UInt8]()

    var branchAfter: Bool = false
    var patchSize: Int = -1
    
    if targetSize >= 3 && abs(branchOffset / 1024 / 1024 / 1024) < 4 && branchOffset > 0 {
         print("[*] adrp branch")

        let target_addr = UInt64(UInt(bitPattern: target))
        let replacement_addr = UInt64(UInt(bitPattern: replacement))
        
        code = assembleJump(replacement_addr, pc: target_addr, link: false, page: true, jmpReg: Register.x(safeReg))
        
        if targetSize != 3 {
            branchAfter = true
        }
        
        patchSize = 3
        
     } else if targetSize >= 4 && abs(branchOffset / 1024 / 1024) > 128 {
         print("[*] Big branch")
         
        let target_addr = UInt64(UInt(bitPattern: replacement))
        
        code = [0x50, 0x00, 0x00, 0x58] + // ldr x16, #8
                br(.x16).bytes() +
                split(from: target_addr)
         
         if targetSize != 4 {
             branchAfter = true
         }
         
         patchSize = 4
         
     } else if !internalSkipChecks, let tramp = Trampoline(
        base: target,
        target: replacement
     ) {
         print("[+] ellekit: using trampoline method")
         
         return tramp.orig
     } else if abs(branchOffset / 1024 / 1024) > 128 { // tiny function beyond 4gb hook... using exception handler
         if exceptionHandler == nil {
              exceptionHandler = .init()
         }
         print("[*] ellekit: using exception handler method")
         code = [0x20, 0x00, 0x20, 0xD4] // brk #1
         
         patchSize = 1
    } else { // fastest and simplest branch
        print("[*] ellekit: Small branch")
        @InstructionBuilder
        var codeBuilder: [UInt8] {
            b(branchOffset)
        }
        code = codeBuilder
        
        patchSize = 1
    }

    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8

    let orig = getOriginal(
        target,
        targetSize,
        desiredRebindSize: patchSize * 4,
        shouldBranchAfter: branchAfter,
        jmpReg: Register.x(safeReg)
    )
    
    let ret = code.withUnsafeBufferPointer { buf in
        let result = rawHook(address: target, code: buf.baseAddress, size: size)
        #if DEBUG
        assert(result == 0, "ellekit: Hook failure for \(String(describing: target)) to \(String(describing: target))")
        #else
        if result != 0 {
            print("ellekit: Hook failure for \(String(describing: target)) to \(String(describing: target))")
        }
        #endif
        return result
    }
    
    if ret != 0 {
        return nil
    }

    return orig.0?.makeCallable()
}

func split(from uint64: UInt64) -> [UInt8] {
    var result = [UInt8]()
    
    for i in 0..<8 {
        let byte = UInt8((uint64 >> (i * 8)) & 0xFF)
        result.append(byte)
    }
    
    return result
}

#if false
public func hook(_ originalTarget: UnsafeMutableRawPointer, _ originalReplacement: UnsafeMutableRawPointer) {

    let target = originalTarget.makeReadable()
    let replacement = originalReplacement.makeReadable()

    let targetSize = findFunctionSize(target) ?? 6
    print("[*] ellekit: Size of target:", targetSize as Any)

    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4

    var code = [UInt8]()

    if targetSize > 4 && abs(branchOffset / 1024 / 1024) > 128 {
        print("[*] Big branch")

        let target_addr = UInt64(UInt(bitPattern: replacement))

//        code = assembleJump(target_addr, pc: 0, link: false, page: true)
        
        code = [0x50, 0x00, 0x00, 0x58] + // ldr x16, #8
                br(.x16).bytes() +
                split(from: target_addr)
    } else if abs(branchOffset / 1024 / 1024) > 128 {
        if Trampoline(
           base: target,
           target: replacement
        ) != nil {
            print("[+] ellekit: using trampoline method")
            
            return;
        }
        if exceptionHandler == nil {
            exceptionHandler = .init()
        }
        print("[*] ellekit: using exception handler method")
        code = [0x20, 0x00, 0x20, 0xD4] // process crash! (brk #1)
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
        assert(result == 0, "[-] ellekit: Hook failure for \(target) to \(replacement) with error \(result), \(String(cString: mach_error_string(Int32(result))))")
        #else
        if result != 0 {
            print("ellekit: Hook failure for \(String(describing: target)) to \(String(describing: target))")
        }
        #endif
    }
}
#endif

@discardableResult @_optimize(speed)
func rawHook(address: UnsafeMutableRawPointer, code: UnsafePointer<UInt8>?, size: mach_vm_size_t) -> Int {
    
    //NSLog("[hookinfo] patching \(String(describing: address)) with \(code == nil ? "nothing!" : Array(UnsafeBufferPointer(start: code, count: Int(size))).map {String(format: "%02X", $0)}.joined())")
    let enforceThreadSafety = enforceThreadSafety
    if enforceThreadSafety {
        stopAllThreads()
    }
    defer {
        if enforceThreadSafety {
            resumeAllThreads()
        }
    }
    
    let goodSize = Int(size)
    let machAddr = mach_vm_address_t(UInt(bitPattern: address))
            
    let krt1 = custom_mach_vm_protect(
        mach_task_self_,
        machAddr,
        size,
        0,
        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY
    )
        
    guard krt1 == KERN_SUCCESS else {
        return Int(krt1)
    }

    manual_memcpy(address, code, goodSize)
        
    let err2 = custom_mach_vm_protect(
        mach_task_self_,
        machAddr,
        size,
        0,
        VM_PROT_READ | VM_PROT_EXECUTE
    )

    // flush page cache so we don't hit cached unpatched functions
    sys_icache_invalidate(address, Int(vm_page_size))

    guard err2 == KERN_SUCCESS else {
        return Int(err2)
    }

    return 0
}
