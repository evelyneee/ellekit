
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import ObjectiveC
import MachO

@_cdecl("MSGetImageByName")
public func MSGetImageByName(_ name: UnsafeRawPointer) -> UnsafeRawPointer? {
    if let image = try? ellekit.openImage(image: String(cString: name.assumingMemoryBound(to: CChar.self))) {
        return .init(image)
    }
    return nil
}

@_cdecl("MSFindSymbol")
public func MSFindSymbol(_ image: UnsafeRawPointer?, _ name: UnsafeRawPointer?) -> UnsafeRawPointer? {
    guard let name else { return nil }
    
    if let image {
        #if os(macOS)
        if let symbol = try? ellekit.findSymbol(image: image, symbol: String(cString: name.assumingMemoryBound(to: CChar.self))) {
            return .init(symbol)
        }
        #else
        if let symbol = try? ellekit.findSymbol(image: image, symbol: String(cString: name.assumingMemoryBound(to: CChar.self))) {
            return .init(symbol)
        } else if let symbol = try? ellekit.findPrivateSymbol(image: image, symbol: String(cString: name.assumingMemoryBound(to: CChar.self))) {
            return .init(symbol)
        }
        #endif
    } else {
        for img in 0..<_dyld_image_count() {
            if let hdr = _dyld_get_image_header(img) {
                if #available(macOS 11.0, iOS 14.0, *) {
                    if _dyld_shared_cache_contains_path(_dyld_get_image_name(img)), let symbol = try? ellekit.findPrivateSymbol(image: hdr, symbol: String(cString: name.assumingMemoryBound(to: CChar.self))) {
                        return .init(symbol)
                    }
                }
                if let symbol = try? ellekit.findSymbol(image: hdr, symbol: String(cString: name.assumingMemoryBound(to: CChar.self))) {
                    return .init(symbol)
                }
            }
        }
    }
    return nil
}

@_cdecl("MSHookFunction")
public func MSHookFunction(_ symbol: UnsafeMutableRawPointer, _ replace: UnsafeMutableRawPointer, _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) {
    if let result {
        let orig: UnsafeMutableRawPointer? = hook(symbol, replace)
        if let orig {
            result.pointee = orig
        }
    } else { // no orig needed
        let _: Void = hook(symbol, replace)
    }
}

@_cdecl("MSHookClassPair")
public func MSHookClassPair(_ targetClass: AnyClass, _ hookClass: AnyClass, _ baseClass: AnyClass) {
    hookClassPair(targetClass, hookClass, baseClass)
}

@_cdecl("MSHookMessageEx")
public func MSHookMessageEx(_ cls: AnyClass, _ sel: Selector, _ imp: IMP, _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) {
    messageHook(cls, sel, imp, result)
}

@_cdecl("MSHookMemory")
public func MSHookMemory(_ target: UnsafeMutableRawPointer, _ code: UnsafePointer<UInt8>!, _ size: mach_vm_size_t) {
    rawHook(address: target, code: code, size: size)
}

@_cdecl("MSHookIvar")
public func MSHookIvar(_ class: AnyClass, _ name: String) -> UnsafeMutableRawPointer? {
    let ptr: UnsafeMutablePointer<Any>? = hookIvar(`class`, name)
    if let ptr {
        return .init(ptr)
    } else {
        return nil
    }
}
