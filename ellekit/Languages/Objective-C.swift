
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

#warning("TODO: Unhook API")

@inlinable
public func messageHook(_ cls: AnyClass, _ sel: Selector, _ imp: IMP, _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) {

    guard let method = class_getInstanceMethod(cls, sel) ?? class_getClassMethod(cls, sel) else {
        return
    }

    let old = class_replaceMethod(cls, sel, .init(UnsafeMutableRawPointer(imp).makeCallable()), method_getTypeEncoding(method))

    if let result {
        if let old,
           let fp = unsafeBitCast(old, to: UnsafeMutableRawPointer?.self) {
            print("[+] ellekit: Successfully got orig pointer for an objc message hook")
            result.pointee = fp.makeCallable()
        } else if let superclass = class_getSuperclass(cls),
                  let ptr = class_getMethodImplementation(superclass, sel),
                  let fp = unsafeBitCast(ptr, to: UnsafeMutableRawPointer?.self) {
            print("[+] ellekit: Successfully got orig pointer from superclass for an objc message hook")
            result.pointee = fp.makeCallable()
        }
    }
}

@inlinable
func hookIvar<T>(_ class: AnyClass, _ name: String) -> UnsafeMutablePointer<T>? {
    let ivar = class_getInstanceVariable(object_getClass(`class`), name)
    if let ivar {
        let ptr = unsafeBitCast(`class`, to: UnsafeMutableRawPointer.self).advanced(by: ivar_getOffset(ivar))
        return ptr.assumingMemoryBound(to: T.self)
    }
    return nil
}

// MSHookClassPair
// thanks to faptain kink
@inlinable
public func hookClassPair(_ targetClass: AnyClass, _ hookClass: AnyClass, _ baseClass: AnyClass) {
    var method_count: UInt32 = 0
    guard let methods = class_copyMethodList(hookClass, &method_count) else {
        return
    }
    print("[*] ellekit: \(method_count) methods found in hooked class")
    for iter in 0..<Int(method_count) {
        let selector = method_getName(methods[iter])
        NSLog("[*] ellekit: hooked method is", sel_getName(selector))
        
        let method_encoding = method_getTypeEncoding(methods[iter])
        
        // If this is true we need to override the method
        // Otherwise we can just add the method to the subclass
        if let origImp = class_getInstanceMethod(baseClass, selector), let hookedImp = class_getInstanceMethod(hookClass, selector) {
            class_addMethod(baseClass, selector, method_getImplementation(methods[iter]), method_encoding)
            method_exchangeImplementations(hookedImp, origImp)
            
        } else {
            class_addMethod(targetClass, selector, method_getImplementation(methods[iter]), method_encoding)
        }
    }
    
    free(methods)
}
