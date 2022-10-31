//
//  Hook.swift
//  Assembler
//
//  Created by evelyn on 2022-10-27.
//

import Foundation

func patchFunction(_ function: UnsafeMutableRawPointer, @InstructionBuilder _ instructions: () -> [UInt8]) {
    
    let code = instructions()
        
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
    
    code.withUnsafeBufferPointer { buf in
        let result = hook(function, buf.baseAddress, size)
        print(result)
    }
}

func hook(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    
    let targetSize = findFunctionSize(target)
    print("[*] Size of target:", targetSize as Any)
    
    let replacement = (Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target))) / 4
    
    @InstructionBuilder
    var codeBuilder: [UInt8] {
        b(replacement)
    }
    
    let code = codeBuilder
        
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
    
    let orig = getOriginal(target, targetSize)
    
    code.withUnsafeBufferPointer { buf in
        let result = hook(target, buf.baseAddress, size)
        assert(result == 0, "[-] Hook failure for \(target) to \(replacement)")
    }
    
    return orig.0
}

func getOriginal(_ target: UnsafeMutableRawPointer, _ size: Int? = nil, _ addr: mach_vm_address_t? = nil, _ totalSize: Int? = nil) -> (UnsafeMutableRawPointer?, Int) {
    
    var unpatched = target.withMemoryRebound(to: UInt8.self, capacity: 4, { ptr in
        Array(UnsafeMutableBufferPointer(start: ptr, count: 4))
    })
    
    let target_addr = Int(UInt(bitPattern: target))
        
    if size == 1 {
        
        print("[*] Small function")
        
        let isn = (UInt64(unpatched[3]) | UInt64(unpatched[2]) << 8 | UInt64(unpatched[1]) << 16 | UInt64(unpatched[0]) << 24)
        
        let codesize = MemoryLayout<[UInt8]>.size

        let ptr: UnsafeMutableRawPointer?
        if let addr, let totalSize {
            ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr))?.advanced(by: totalSize)
        } else {
            var addr: mach_vm_address_t = 0;
            mach_vm_allocate(mach_task_self_, &addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE);
            mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE);
            ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr))
        }
        guard let ptr else { return (nil, 0) }
        
        let addr: mach_vm_address_t = addr ?? 0;
        
        var code: [UInt8] = []
        if checkBranch(isn) {
            print("Redirecting branch")
            code = redirectBranch(target, isn, ptr)
        } else {
            @InstructionBuilder
            var codeBuilt: [UInt8] {
                bytes(unpatched[0], unpatched[1], unpatched[2], unpatched[3]) // First instruction of the function that got hooked
            }
            code = codeBuilt
        }
        
        if let totalSize, let ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr))?.advanced(by: totalSize) {
            memcpy(ptr, code, codesize * code.count);
            print("Orig written to:", ptr, "for function", totalSize)
        } else {
            memcpy(ptr, code, codesize * code.count);
            mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
            print("Orig written to:", ptr)
        }

        return (ptr, codesize * code.count)
    }
    
    var addr: mach_vm_address_t = 0;
    mach_vm_allocate(mach_task_self_, &addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE);
    mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE);
    let ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr))
    
    let isn = (UInt64(unpatched[3]) | UInt64(unpatched[2]) << 8 | UInt64(unpatched[1]) << 16 | UInt64(unpatched[0]) << 24)
    
    if let ptr, checkBranch(isn) {
        print("Redirecting branch")
        unpatched = redirectBranch(target, isn, ptr)
    }
    
    @InstructionBuilder
    var code: [UInt8] {
        movk(.x16, target_addr % 65536)
        movk(.x16, (target_addr / 65536) % 65536, lsl: 16)
        movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32)
        movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48) // stop overflow error :)
        add(.x16, .x16, 4) // Jump first instruction (the branch to the replacement)
        bytes(unpatched[0], unpatched[1], unpatched[2], unpatched[3]) // First instruction of the function that got hooked
        br(.x16)
    }
        
    let codesize = MemoryLayout.size(ofValue: code) * (code.count)
    
    memcpy(UnsafeMutableRawPointer(bitPattern: UInt(addr)), code, codesize);
    mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
    if let ptr {
        print("Orig written to:", ptr)
    }
    return (ptr, codesize)
}

func calculateOffset(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) -> Int {
    let sign = target > replacement ? -1 : 1
    let offsetAbs = abs((Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target)))) / 4
    return offsetAbs * sign
}

func hook(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) {
    
    let replacement = calculateOffset(target, replacement)
        
    print(replacement)
    
    @InstructionBuilder
    var codeBuilder: [UInt8] {
        b(replacement)
    }
    
    let code = codeBuilder
        
    let size = mach_vm_size_t(MemoryLayout.size(ofValue: code) * code.count) / 8
    
    print("SIZE:", size)
    
    code.withUnsafeBufferPointer { buf in
        let result = hook(target, buf.baseAddress, size)
        #if DEBUG
        print(result)
        #else
        _ = result
        #endif
    }
}

func messageHook(_ cls: AnyClass, _ sel: Selector, _ imp: IMP, _ result: UnsafeMutableRawPointer) {
    let meth1 = class_getInstanceMethod(cls, sel)
    method_setImplementation(meth1!, imp)
}
