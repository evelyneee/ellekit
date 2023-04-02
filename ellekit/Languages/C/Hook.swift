
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

public func hook(_ stockTarget: UnsafeMutableRawPointer, _ stockReplacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {

    var target = stockTarget.makeReadable()
    let replacement = stockReplacement.makeReadable()
    
    if let newTarget = hooks[target] {
        target = newTarget
    }

    let targetSize = findFunctionSize(target) ?? 6

    print("[*] ellekit: Size of target:", targetSize as Any)

    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4

    hooks[target] = replacement

    var code = [UInt8]()

    // fast big branch option
    if targetSize > 5 && abs(branchOffset / 1024 / 1024) > 128 {
         print("[*] Big branch")

         let target_addr = UInt64(UInt(bitPattern: replacement))

         code = assembleJump(target_addr, pc: 0, link: false, big: true)
     } else if abs(branchOffset / 1024 / 1024) > 128 { // tiny function beyond 4gb hook... using exception handler
        if exceptionHandler == nil {
             exceptionHandler = .init()
        }
        code = [0x20, 0x00, 0x20, 0xD4] // brk #1
    } else { // fastest and simplest branch
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
        usedBigBranch: abs(branchOffset / 1024 / 1024) > 128 && targetSize > 5,
        shouldBranchAfter: targetSize != 5
    )

    let ret = code.withUnsafeBufferPointer { buf in
        let result = rawHook(address: target, code: buf.baseAddress, size: size)
        #if DEBUG
        assert(result == 0, "[-] ellekit: Hook failure for \(target) to \(replacement)")
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

public func hook(_ originalTarget: UnsafeMutableRawPointer, _ originalReplacement: UnsafeMutableRawPointer) {

    let target = originalTarget.makeReadable()
    let replacement = originalReplacement.makeReadable()

    let targetSize = findFunctionSize(target) ?? 6
    print("[*] ellekit: Size of target:", targetSize as Any)

    let branchOffset = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4

    var code = [UInt8]()

    if targetSize > 5 && abs(branchOffset / 1024 / 1024) > 128 {
        print("[*] Big branch")

        let target_addr = UInt64(UInt(bitPattern: replacement))

        code = assembleJump(target_addr, pc: 0, link: false, big: true)
    } else if abs(branchOffset / 1024 / 1024) > 128 {
        if exceptionHandler == nil {
            exceptionHandler = .init()
        }
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

@discardableResult @_optimize(speed)
func rawHook(address: UnsafeMutableRawPointer, code: UnsafePointer<UInt8>?, size: mach_vm_size_t) -> Int {
    let enforceThreadSafety = enforceThreadSafety
    if enforceThreadSafety {
        stopAllThreads()
    }
    
    let goodSize = Int(size)
    let machAddr = mach_vm_address_t(UInt(bitPattern: address))
        
    let krt1 = custom_mach_vm_protect(
        mach_task_self_,
        machAddr,
        0x4000,
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
        0x4000,
        0,
        VM_PROT_READ | VM_PROT_EXECUTE
    )

    // flush page cache so we don't hit cached unpatched functions
    sys_icache_invalidate(address, Int(vm_page_size))

    guard err2 == KERN_SUCCESS else {
        return Int(err2)
    }
    if enforceThreadSafety {
        resumeAllThreads()
    }

    return 0
}
