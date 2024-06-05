
import Foundation

/**
 `void* EKPrecisionHook(void* target, void* replacement);`
 Beta, WIP. Please report bugs but test extensively before using in prod.
 Hook a single instruction. It's likely that writing the replacement function will require usage of inline assembly
 Arguments:
 - target: pointer to the target instruction. Can be PAC-signed, or not.
 - replacement: pointer to the replacement function. Can be PAC-signed, or not.
 Returns:
 - Original function that calls the first instruction and jumps back to the original function
 */
@_cdecl("EKPrecisionHook") // single isn hook
public func precisionHook(_ stockTarget: UnsafeMutableRawPointer, _ stockReplacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    var target = stockTarget.makeReadable()
    let replacement = stockReplacement.makeReadable()
    
    if let newReplacement = hooks[target] {
        precisionHook(newReplacement.makeReadable(), replacement)
    }
    
    let isn = target.withMemoryRebound(to: UInt8.self, capacity: 4, { ptr in
        Array(UnsafeMutableBufferPointer(start: ptr, count: 4))
    })
        
    let ptr: UnsafeMutableRawPointer?

    var address: mach_vm_address_t = 0

    mach_vm_allocate(mach_task_self_, &address, UInt64(vm_page_size), VM_FLAGS_ANYWHERE)
    mach_vm_protect(mach_task_self_, address, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE)
    ptr = UnsafeMutableRawPointer(bitPattern: UInt(address))
    guard let ptr else { return nil }
        
    let target_addr = UInt64(UInt(bitPattern: target))

    let code: [UInt8] = isn + assembleJump(target_addr + 4, pc: 0, link: true)

    let codesize = MemoryLayout<[UInt8]>.size * code.count

    memcpy(ptr, code, codesize)
    mach_vm_protect(mach_task_self_, mach_vm_address_t(UInt(bitPattern: ptr)), UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE)
    sys_icache_invalidate(ptr, Int(vm_page_size))
    print("[+] ellekit: Orig written to:", ptr)
    
    hooks[target] = replacement
    if exceptionHandler == nil {
         exceptionHandler = .init()
    }
    rawHook(address: target, code: [0x20, 0x00, 0x20, 0xD4], size: 4) // swap svc #... with brk #1
    
    return ptr
}
