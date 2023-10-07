
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

public struct Trampoline {
    var base: UnsafeMutableRawPointer
    var target: UnsafeMutableRawPointer
    var trampolineCode: [UInt8] = []
    
    public var trampoline: UnsafeMutableRawPointer = UnsafeMutableRawPointer(bitPattern: -2)!
    public var orig: UnsafeMutableRawPointer? = nil
    
    // PAC: strip before initializing
    #warning("Trampolines ARE enabled")
    public init?(base: UnsafeMutableRawPointer, target: UnsafeMutableRawPointer) {
        
        return nil;
        stopAllThreads()
        
        defer { resumeAllThreads() }
        
        self.base = base
        self.target = target
        guard let location = self.findLocation() else {
            return nil;
        }
        self.trampoline = location
        
        self.orig = findOrig()
        
        guard let code = self.buildTrampoline() else {
            return nil;
        }
        self.trampolineCode = code
        self.writeTrampoline() // this is fine coz other threads are blocked.. no race condition possible i think
        self.buildHook()
    }
    
    public func findOrig() -> UnsafeMutableRawPointer? {
        
        let size = findFunctionSize(self.base)
        
        let (orig, _) = getOriginal(
            self.base,
            size,
            desiredRebindSize: 1*4,
            shouldBranchAfter: size != 4
        )
        
        return orig
    }
    
    // layout: jump to orig, jump to target, normal function...
    // patch is only 32 bytes
    public func buildTrampoline() -> [UInt8]? {
        let safeReg = findSafeRegister(self.base, isns: 8)
        let (orig, _) = getOriginal(
            self.trampoline,
            9,
            desiredRebindSize: 8 * 4,
            shouldBranchAfter: true,
            jmpReg: Register.x(safeReg)
        )
        
        guard let orig else {
            print("[-] trampoline: couldn't get orig for victim function")
            return nil
        }
        
        hooks[self.trampoline] = orig
        
        let origJump: [UInt8] = [0x50, 0x00, 0x00, 0x58] + // ldr x16, #8
        br(.x16).bytes() +
        split(from: UInt64(UInt(bitPattern: orig)))
        
        let targetJump = [0x50, 0x00, 0x00, 0x58] + // ldr x16, #8
        br(.x16).bytes() +
        split(from: UInt64(UInt(bitPattern: target)))
        
        let code: [UInt8] = origJump + targetJump
                
        return code
    }
    
    public func writeTrampoline() {
        patchFunction(self.trampoline, {
            return self.trampolineCode
        })
    }
    
    public func buildHook() {
        let _: UnsafeMutableRawPointer? = hook(self.base, self.trampoline.advanced(by: 16)) // hook base to tramp + 16 which jumps to the replacement... ellekit /should/ use simple branching for the tiny hook
    }
}
