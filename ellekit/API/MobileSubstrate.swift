
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import ObjectiveC
import MachO

@_cdecl("MSGetImageByName")
public func MSGetImageByName(_ name: UnsafeRawPointer) -> UnsafeRawPointer? {
    if let image = try? ellekit.openImage(image: String(cString: name.assumingMemoryBound(to: CChar.self))) {
        return .init(image)
    }
    return nil
}

@_cdecl("MSCloseImage")
public func MSCloseImage(_ image: UnsafeRawPointer) {
    // no-op
}

@_cdecl("MSFindSymbol")
public func MSFindSymbol(_ image: UnsafeRawPointer?, _ name: UnsafeRawPointer?) -> UnsafeRawPointer? {
    guard let name else { return nil }
    
    if let image {
        
        let swiftName = String(cString: name.assumingMemoryBound(to: CChar.self))
        if swiftName.first == "_", let symbol = dlsym(UnsafeMutableRawPointer(mutating: image), String(swiftName.dropFirst())) {
            return .init(symbol)
        }
        
        #if os(macOS)
        if let symbol = try? ellekit.findSymbol(image: image, symbol: swiftName) {
            return .init(symbol)
        }
        #else
        if let symbol = try? ellekit.findSymbol(image: image, symbol: swiftName) {
            return .init(symbol)
        }
        if #available(iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            var info = Dl_info()
            dladdr(image, &info)
            if info.dli_fname != nil && _dyld_shared_cache_contains_path(info.dli_fname) {
                if let symbol = try? ellekit.findPrivateSymbol(image: image, symbol: swiftName) {
                    return .init(symbol)
                }
            }
        } else {
            if let symbol = try? ellekit.findPrivateSymbol(image: image, symbol: swiftName) {
                return .init(symbol)
            }
        }
        #endif
    } else {
        for img in 0..<_dyld_image_count() {
            if let hdr = _dyld_get_image_header(img) {
                let swiftName = String(cString: name.assumingMemoryBound(to: CChar.self))
                if swiftName.first == "_", let symbol = dlsym(UnsafeMutableRawPointer(mutating: UnsafeRawPointer(hdr)), String(swiftName.dropFirst())) {
                    return .init(symbol)
                }
                if #available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *) {
                    if _dyld_shared_cache_contains_path(_dyld_get_image_name(img)), let symbol = try? ellekit.findPrivateSymbol(image: hdr, symbol: swiftName) {
                        return .init(symbol)
                    }
                }
                if let symbol = try? ellekit.findSymbol(image: hdr, symbol: swiftName) {
                    return .init(symbol)
                }
            }
        }
    }
    return nil
}

@_cdecl("MSHookFunction")
public func MSHookFunction(_ symbol: UnsafeMutableRawPointer, _ replace: UnsafeMutableRawPointer, _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) {
    let orig: UnsafeMutableRawPointer? = hook(symbol, replace)
    if let result, let orig {
        result.pointee = orig
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
