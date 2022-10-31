
import Foundation

// Libhooker API Implementation

@_cdecl("LHHookMessageEx")
public func LHHookMessageEx(_ cls: AnyClass, _ sel: Selector, _ imp: IMP, _ oldptr: UnsafeMutableRawPointer) {
    messageHook(cls, sel, imp, oldptr)
}

#warning("TODO: LHHookMemory")

@_cdecl("LHHookFunctions")
public func LHHookFunctions(_ hooks: UnsafePointer<LHFunctionHook>, _ count: Int) -> Int {
    
    let hooksArray = Array(UnsafeBufferPointer(start: hooks, count: count))
        
    var origPageAddress: mach_vm_address_t = 0;
    let krt1 = mach_vm_allocate(mach_task_self_, &origPageAddress, UInt64(vm_page_size), VM_FLAGS_ANYWHERE);
    
    guard krt1 == KERN_SUCCESS else { return Int(krt1) }

    let krt2 = mach_vm_protect(mach_task_self_, origPageAddress, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE);
    
    guard krt2 == KERN_SUCCESS else { return Int(krt2) }
    
    var totalSize = 0
    for hook in hooksArray {
        
        guard let target = hook.function else { return 2; }
                
        let functionSize = findFunctionSize(target)
        
        let (orig, codesize) = getOriginal(target, functionSize, origPageAddress, totalSize)
                
        totalSize = (totalSize + codesize)
        
        if let orig, hook.oldptr != nil {
            let setter = unsafeBitCast(hook.oldptr, to: UnsafeMutablePointer<UnsafeMutableRawPointer?>.self)
            setter.pointee = orig
        }
        
        #if os(iOS)
        let _: Void = ellekit.hook(hook.function, hook.replacement)
        #else
        let _: Void = ellekit_mac.hook(hook.function, hook.replacement)
        #endif
        
        if let orig = hook.oldptr {
            print("[+] ellekit: Performed one hook in LHHookFunctions from \(String(describing: target)) with orig at \(String(describing: orig))")
        } else {
            print("[+] ellekit: Performed one hook in LHHookFunctions from \(String(describing: target)) with no orig")
        }
    }
    
    let krt3 = mach_vm_protect(mach_task_self_, origPageAddress, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
    guard krt3 == KERN_SUCCESS else { return Int(krt3) }
    
    return 0;
}
