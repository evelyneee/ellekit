
import Foundation

@inlinable
public func messageHook(_ cls: AnyClass, _ sel: Selector, _ imp: IMP, _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) {
    
    guard let method = class_getInstanceMethod(cls, sel) ?? class_getClassMethod(cls, sel) else {
        if #available(macOS 11.0, *) {
            logger.error("ellekit: peacefully bailing out of message hook because the method cannot be found")
        }
        return
    }
    
    let old = class_replaceMethod(cls, sel, imp, method_getTypeEncoding(method))
    
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
    var method_count: UInt32 = 0;
    let method_list = class_copyMethodList(hookClass, &method_count);
    let methods = Array(UnsafeBufferPointer(start: method_list, count: Int(method_count)))
    print("[*] ellekit: \(method_count) methods found in hooked class");
    for iter in 0..<Int(method_count) {
        let selector = method_getName(methods[iter]);
        NSLog("[*] ellekit: hooked method is", sel_getName(selector));

        let hookedImp = method_getImplementation(methods[iter])
        
        // If this is true we need to override the method
        // Otherwise we can just add the method to the subclass
        if class_respondsToSelector(targetClass, selector),
           let target_method = class_getInstanceMethod(targetClass, selector) {
            
            let target_implementation = method_getImplementation(target_method);
            let method_encoding = method_getTypeEncoding(target_method);
            method_setImplementation(target_method, hookedImp);
            let hookedClassName: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> = .allocate(capacity: 50)
            
            class_addMethod(
                NSClassFromString(String(cString: hookedClassName.pointee!)),
                selector,
                target_implementation,
                method_encoding
            )
        } else {
            let method_encoding = method_getTypeEncoding(methods[iter]);
            class_addMethod(targetClass, selector, hookedImp, method_encoding);
        }
    }
}
