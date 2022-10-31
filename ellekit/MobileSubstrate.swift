//
//  MobileSubstrate.swift
//  Assembler
//
//  Created by evelyn on 2022-10-29.
//

import ObjectiveC

@_cdecl("MSGetImageByName")
public func MSGetImageByName(_ name: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    dlopen(name, RTLD_NOW)
}

@_cdecl("MSFindSymbol")
public func MSFindSymbol(_ image: UnsafeMutableRawPointer, _ name: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    dlsym(image, name)
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

@_cdecl("MSHookMessageEx")
public func MSHookMessageEx(_ cls: AnyClass, _ sel: Selector, _ imp: IMP, _ result: UnsafeMutableRawPointer) {
    print(cls, sel, imp)
    messageHook(cls, sel, imp, result)
}

@_cdecl("MSHookMemory")
public func MSHookMemory(_ target: UnsafeMutableRawPointer, _ code: UnsafePointer<UInt8>!, _ size: mach_vm_size_t) {
    hook(target, code, size)
}
