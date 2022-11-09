
import Foundation

#if SWIFT_PACKAGE
import ellekitc
#endif

// PAC: strip before calling this function and sign the result afterwards
func getOriginal(_ target: UnsafeMutableRawPointer, _ size: Int? = nil, _ addr: mach_vm_address_t? = nil, _ totalSize: Int? = nil, usedBigBranch: Bool = false) -> (UnsafeMutableRawPointer?, Int) {
        
    var unpatched = target.withMemoryRebound(to: UInt8.self, capacity: usedBigBranch ? 20 : 4, { ptr in
        Array(UnsafeMutableBufferPointer(start: ptr, count: usedBigBranch ? 20 : 4))
    })
        
    let target_addr = Int(UInt(bitPattern: target))
        
    if size == 1 {
        
        print("[*] ellekit: Small function")
        
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
            print("[*] ellekit: Redirecting branch")
            code = redirectBranch(target, isn, ptr)
        } else {
            @InstructionBuilder
            var codeBuilt: [UInt8] {
                bytes(unpatched) // First instruction of the function that got hooked
            }
            code = codeBuilt
        }
        
        if let totalSize, let ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr))?.advanced(by: totalSize) {
            memcpy(ptr, code, codesize * code.count);
            #if DEBUG
            print("[+] ellekit: Orig written to:", ptr, "for function", totalSize)
            #endif
        } else {
            memcpy(ptr, code, codesize * code.count);
            mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
            #if DEBUG
            print("[+] ellekit: Orig written to:", ptr)
            #endif
        }

        return (ptr, codesize * code.count)
    }
    
    let ptr: UnsafeMutableRawPointer?
    
    var address: mach_vm_address_t = addr ?? 0;
    
    if let addr, let totalSize {
        print("[*] ellekit: Reusing page")
        ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr))?.advanced(by: totalSize)
    } else {
        mach_vm_allocate(mach_task_self_, &address, UInt64(vm_page_size), VM_FLAGS_ANYWHERE);
        mach_vm_protect(mach_task_self_, address, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE);
        ptr = UnsafeMutableRawPointer(bitPattern: UInt(address))
    }
    guard let ptr else { return (nil, 0) }
    let addr = address
        
    let isn = (UInt64(unpatched[3]) | UInt64(unpatched[2]) << 8 | UInt64(unpatched[1]) << 16 | UInt64(unpatched[0]) << 24)
    
    if checkBranch(UInt64(reverse(Int(isn)))) {
        print("[*] ellekit: Redirecting branch")
        unpatched = redirectBranch(target, isn, ptr)
    }
    
    var code = [UInt8]()
    @InstructionBuilder
    var codeBuilder: [UInt8] {
        movk(.x16, target_addr % 65536)
        movk(.x16, (target_addr / 65536) % 65536, lsl: 16)
        movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32)
        movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48) // stop overflow error :)
        add(.x16, .x16, usedBigBranch ? 16 : 4) // Jump first instruction (the branch to the replacement)
        bytes(unpatched) // First instruction of the function that got hooked
        br(.x16)
    }
    code = codeBuilder
            
    let codesize = MemoryLayout<[UInt8]>.size * code.count + (usedBigBranch ? 16 : 0)

    if let totalSize {
        memcpy(ptr, code, codesize);
        print("[+] ellekit: Orig written to:", ptr, "for function", totalSize)
    } else {
        memcpy(ptr, code, codesize);
        mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
        print("[+] ellekit: Orig written to:", ptr)
    }
    return (ptr, codesize)
}
