//
//  PPLRW.swift
//  elle
//
//  Created by charlotte on 2023-02-11.
//

import Foundation

let PTE_NON_GLOBAL      = UInt64(1 << 11)
let PTE_VALID           = UInt64(1 << 10) // Access flag
let PTE_OUTER_SHAREABLE = UInt64(2 << 8)
let PTE_INNER_SHAREABLE = UInt64(3 << 8)

let PTE_LEVEL3_ENTRY    = PTE_VALID | 0x3

let KRW_URW_PERM        = UInt64(0x60000000000040)

let PTE_RESERVED  = UInt64(0x3)
let PTE_REUSEABLE = UInt64(0x1)
let PTE_UNUSED    = UInt64(0x0)

fileprivate func doTLBFlush() {
    usleep(70)
    usleep(70)
    dmb_sy()
}

public enum PPLMemoryAccessError: Error {
    case failedToTranslate(address: UInt64, table: String, entry: UInt64)
}

public class PPLWindow {
    private let pteAddress: UnsafeMutablePointer<UInt64>
    private let address: UnsafeMutableRawPointer
    
    public private(set) var used = false
    
    private let lock = NSLock()
    
    internal init(pteAddress: UnsafeMutablePointer<UInt64>, address: UInt64) {
        self.pteAddress = pteAddress
        self.address    = UnsafeMutableRawPointer(bitPattern: UInt(address))!
    }
    
    public func performWithMapping<T>(to pa: UInt64, _ block: (_: UnsafeMutableRawPointer) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        
        let newEntry = pa | KRW_URW_PERM | PTE_NON_GLOBAL | PTE_OUTER_SHAREABLE | PTE_LEVEL3_ENTRY
        
        // Only update (and flush) if the new entry is different
        if pteAddress.pointee != newEntry {
            pteAddress.pointee = newEntry
            if used {
                // Flush if we used this window before
                doTLBFlush()
            }
        }
        
        used = true
        
        return try block(address)
    }
    
    deinit {
        if used {
            pteAddress.pointee = PTE_REUSEABLE
        } else {
            pteAddress.pointee = PTE_UNUSED
        }
    }
}

public class PPLRW {
    public private(set) static var magicPageUInt64: UInt64!
    public private(set) static var magicPage: UnsafeMutableBufferPointer<UInt64>!
    public private(set) static var cpuTTEP: UInt64!
    public private(set) static var hasKRW: Bool = false
    static let lock = NSLock()
    
    public static func initialize(magicPage: UInt64, cpuTTEP: UInt64) {
        
        guard !hasKRW else { return }
        
        self.hasKRW = true
        
        self.magicPageUInt64 = magicPage
        self.cpuTTEP = cpuTTEP
        
        let ptr = UnsafeMutablePointer<UInt64>(bitPattern: UInt(magicPage))!
        self.magicPage = UnsafeMutableBufferPointer(start: ptr, count: 2048)
        
        clearWindows()
        
        tprint("initialized krw")
    }
    
    public static func read(phys: UInt64, count: Int) -> Data {
        guard count > 0 else {
            return Data()
        }
                
        var pa    = phys
        var count = count
        var res   = Data()
        while count > 0 {
            let page    = pa & ~0x3FFF
            let pageOff = Int(pa & 0x3FFF)
            let readCount = min(count, 0x4000 - pageOff)
            
            res += getWindow().performWithMapping(to: page) { ptr in
                Data(bytes: ptr.advanced(by: pageOff), count: readCount)
            }
            
            pa    += UInt64(readCount)
            count -= readCount
        }
                
        return res
    }
    
    public static func readGeneric<T>(phys: UInt64, type: T.Type = T.self) -> T {
        read(phys: phys, count: MemoryLayout<T>.size).withUnsafeBytes { ptr in
            ptr.baseAddress!.assumingMemoryBound(to: T.self).pointee
        }
    }
    
    public static func r64(phys: UInt64) -> UInt64 {
        readGeneric(phys: phys)
    }
    
    public static func r32(phys: UInt64) -> UInt32 {
        readGeneric(phys: phys)
    }
    
    public static func r16(phys: UInt64) -> UInt16 {
        readGeneric(phys: phys)
    }
    
    public static func r8(phys: UInt64) -> UInt8 {
        readGeneric(phys: phys)
    }
    
    public static func read(virt: UInt64, count: Int) throws -> Data {
        guard count > 0 else {
            return Data()
        }
        
        var va    = virt
        var count = count
        var res   = Data()
        while count > 0 {
            let page    = va & ~0x3FFF
            let pageOff = Int(va & 0x3FFF)
            let readCount = min(count, 0x4000 - Int(pageOff))
            
            let pa = try walkPageTable(table: cpuTTEP, virt: page)
            res += getWindow().performWithMapping(to: pa) { ptr in
                Data(bytes: ptr.advanced(by: pageOff), count: readCount)
            }
            
            va    += UInt64(readCount)
            count -= readCount
        }
        
        return res
    }
    
    public static func readGeneric<T>(virt: UInt64, type: T.Type = T.self) throws -> T {
        try read(virt: virt, count: MemoryLayout<T>.size).withUnsafeBytes { ptr in
            ptr.baseAddress!.assumingMemoryBound(to: T.self).pointee
        }
    }
    
    public static func r64(virt: UInt64) throws -> UInt64 {
        try readGeneric(virt: virt)
    }
    
    public static func r32(virt: UInt64) throws -> UInt32 {
        try readGeneric(virt: virt)
    }
    
    public static func r16(virt: UInt64) throws -> UInt16 {
        try readGeneric(virt: virt)
    }
    
    public static func r8(virt: UInt64) throws -> UInt8 {
        try readGeneric(virt: virt)
    }
    
    public static func write(phys: UInt64, data: Data) {
        print("writing now")
        var pa   = phys
        var data = data
        while data.count > 0 {
            let page    = pa & ~0x3FFF
            let pageOff = Int(pa & 0x3FFF)
            let writeCount = min(data.count, 0x4000 - Int(pageOff))
            
            getWindow().performWithMapping(to: page) { ptr in
                data.copyBytes(to: ptr.advanced(by: pageOff).assumingMemoryBound(to: UInt8.self), count: writeCount)
            }
            
            pa += UInt64(writeCount)
            
            if (data.count - writeCount) > 0 {
                data = data.advanced(by: writeCount)
            } else {
                data = Data()
            }
        }
        print("writing succeeded")
    }
    
    public static func write(virt: UInt64, data: Data) throws {
        var va   = virt
        var data = data
        while data.count > 0 {
            let page    = va & ~0x3FFF
            let pageOff = Int(va & 0x3FFF)
            let writeCount = min(data.count, 0x4000 - pageOff)
            
            let pa = try walkPageTable(table: cpuTTEP, virt: page)
            getWindow().performWithMapping(to: pa) { ptr in
                data.copyBytes(to: ptr.advanced(by: pageOff).assumingMemoryBound(to: UInt8.self), count: writeCount)
            }
            
            va += UInt64(writeCount)
            
            if (data.count - writeCount) > 0 {
                data = data.advanced(by: writeCount)
            } else {
                data = Data()
            }
        }
    }
    
    /**
     * Get a copy window
     */
    public static func getWindow() -> PPLWindow {
        lock.lock()
        
        NSLog("getting windows")
        
        for i in 1..<2048 {
            if magicPage[i] == PTE_UNUSED {
                magicPage[i] = PTE_RESERVED
                
                lock.unlock()
                
                let mapped = magicPageUInt64 + (UInt64(i) << 14)
                return PPLWindow(pteAddress: magicPage.baseAddress!.advanced(by: i), address: mapped)
            }
        }
        
        NSLog("got windows")
        
        clearWindows()
        
        lock.unlock()
        
        return getWindow()
    }
    
    private static func clearWindows() {
        for i in 1..<2048 {
            if magicPage[i] == PTE_REUSEABLE {
                magicPage[i] = PTE_UNUSED
            }
        }
        
        tprint("clearing windows")
        
        doTLBFlush()
    }
    
    private static func _walkPageTable(table: UInt64, virt: UInt64) throws -> UInt64 {
        let table1Off = (virt >> 36) & 0x7
        let table1Entry = r64(phys: table + (8 * table1Off))
        print(table1Entry)
        guard (table1Entry & 0x3) == 3 else {
            throw PPLMemoryAccessError.failedToTranslate(address: virt, table: "table1", entry: table1Entry)
        }
        
        let table2 = table1Entry & 0xFFFFFFFFC000
        let table2Off = (virt >> 25) & 0x7FF
        let table2Entry = r64(phys: table2 + (8 * table2Off))
        print(table2Entry)
        switch table2Entry & 0x3 {
        case 1:
            // Easy, this is a block
            return (table2Entry & 0xFFFFFE000000) | (virt & 0x1FFFFFF)
            
        case 3:
            // Another table
            let table3 = table2Entry & 0xFFFFFFFFC000
            let table3Off = (virt >> 14) & 0x7FF
            let table3Entry = r64(phys: table3 + (8 * table3Off))
            guard (table3Entry & 0x3) == 3 else {
                throw PPLMemoryAccessError.failedToTranslate(address: virt, table: "table3", entry: table3Entry)
            }
            
            return (table3Entry & 0xFFFFFFFFC000) | (virt & 0x3FFF)
        default:
            throw PPLMemoryAccessError.failedToTranslate(address: virt, table: "table2", entry: table2Entry)
        }
    }

    public static func walkPageTable(table: UInt64, virt: UInt64) throws -> UInt64 {
        let res = try _walkPageTable(table: table, virt: virt)
        if res == 0 {
            throw PPLMemoryAccessError.failedToTranslate(address: virt, table: "Unknown", entry: 0)
        }
        
        return res
    }
    
    private init() { fatalError("Cannot create instances of PPLRW!") }
    
    public static func w64(_ addr: UInt64, value: UInt64) -> Bool {
        let data = Data(fromObject: value)
                
        do {
            try PPLRW.write(virt: addr, data: data)
            return true
        } catch {
            return false
        }
    }
    
    public static func w32(_ addr: UInt64, value: UInt32) -> Bool {
        let data = Data(fromObject: value)
        
        do {
            try PPLRW.write(virt: addr, data: data)
            return true
        } catch {
            return false
        }
    }
    
    public static func w16(_ addr: UInt64, value: UInt16) -> Bool {
        let data = Data(fromObject: value)
        
        do {
            try PPLRW.write(virt: addr, data: data)
            return true
        } catch {
            return false
        }
    }
    
    public static func w8(_ addr: UInt64, value: UInt8) -> Bool {
        let data = Data(fromObject: value)
        
        do {
            try PPLRW.write(virt: addr, data: data)
            return true
        } catch {
            tprint("got error write", error)
            return false
        }
    }
    
    public static func rPtr(_ ptr: UInt64) throws -> UInt64 {
        let ptr = try PPLRW.r64(virt: ptr)
        if ((ptr >> 55) & 1) != 0 {
            return ptr | 0xFFFFFF8000000000
        }
        return ptr
    }
}

extension Data {
    init<Type: Any>(fromObject: Type) {
        var value = fromObject
        let valueSize = MemoryLayout.size(ofValue: value)
        
        self = withUnsafePointer(to: &value) { ptr in
            Data(bytes: UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self), count: valueSize)
        }
    }
}

