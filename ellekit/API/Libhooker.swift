
import Foundation
import ellekitc

// Libhooker API Implementation

@_cdecl("LHHookMessageEx")
public func LHHookMessageEx(_ cls: AnyClass, _ sel: Selector, _ imp: IMP, _ oldptr: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) {
    messageHook(cls, sel, imp, oldptr)
}

@_cdecl("LHStrError")
public func LHStrError(_ err: LIBHOOKER_ERR) -> UnsafeRawPointer? {
    
    var error: String = ""
    
    switch err.rawValue {
    case 0: error = "No errors took place"
    case 1: error = "An Objective-C selector was not found. (This error is from libblackjack)"
    case 2: error = "A function was too short to hook"
    case 3: error = "A problematic instruction was found at the start. We can't preserve the original function due to this instruction getting clobbered."
    case 4: error = "An error took place while handling memory pages"
    case 5: error = "No symbol was specified for hooking"
    default: error = "Unknown error"
    }
    
    return UnsafeRawPointer((error as NSString).utf8String)
}

#warning("TODO: LHHookMemory")

@_cdecl("LHHookFunctions")
public func LHHookFunctions(_ hooks: UnsafePointer<LHFunctionHook>, _ count: Int) -> Int {
        
    let hooksArray = Array(UnsafeBufferPointer(start: hooks, count: count))
        
    var origPageAddress: mach_vm_address_t = 0;
    let krt1 = mach_vm_allocate(mach_task_self_, &origPageAddress, UInt64(vm_page_size), VM_FLAGS_ANYWHERE);
    
    guard krt1 == KERN_SUCCESS else { return Int(LIBHOOKER_ERR_VM.rawValue) }

    let krt2 = mach_vm_protect(mach_task_self_, origPageAddress, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE);
    
    guard krt2 == KERN_SUCCESS else { return Int(LIBHOOKER_ERR_VM.rawValue) }
    
    var totalSize = 0
    for targetHook in hooksArray {
        
        guard let target = targetHook.function?.makeReadable() else { return Int(LIBHOOKER_ERR_NO_SYMBOL.rawValue); }
                
        let functionSize = findFunctionSize(target)
                
        let (orig, codesize) = getOriginal(
            target, functionSize, origPageAddress, totalSize,
            usedBigBranch: false
        )
                
        totalSize = (totalSize + codesize)
        
        if let orig, targetHook.oldptr != nil {
            let setter = unsafeBitCast(targetHook.oldptr, to: UnsafeMutablePointer<UnsafeMutableRawPointer?>.self)
            setter.pointee = orig.makeCallable()
        }
        
        let _: Void = hook(targetHook.function, targetHook.replacement)
        
        if let orig = targetHook.oldptr {
            print("[+] ellekit: Performed one hook in LHHookFunctions from \(String(describing: target)) with orig at \(String(describing: orig))")
        } else {
            print("[+] ellekit: Performed one hook in LHHookFunctions from \(String(describing: target)) with no orig")
        }
    }
    
    let krt3 = mach_vm_protect(mach_task_self_, origPageAddress, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
    guard krt3 == KERN_SUCCESS else { return Int(LIBHOOKER_ERR_VM.rawValue) }
    
    return Int(LIBHOOKER_OK.rawValue);
}
