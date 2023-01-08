
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

public func getLinkedPaths(file path: String) throws -> [String] {
        
    guard var handle = FileHandle(forReadingAtPath: path) else { return [] }
        
    var headerData = handle.readData(ofLength: MemoryLayout<mach_header>.size)
    
    guard var machHeaderPointer = headerData.withUnsafeBytes({ $0.baseAddress }) else { return [] }
    
    if machHeaderPointer.assumingMemoryBound(to: mach_header.self).pointee.magic == FAT_CIGAM {
        // we have a fat binary
        // get our current cpu subtype
        let nslices = machHeaderPointer
            .advanced(by: 0x4)
            .assumingMemoryBound(to: UInt32.self)
            .pointee.bigEndian
        
        for i in 0..<nslices {
            
            handle.seek(toFileOffset: UInt64(8 + (Int(i) * 20)))
                        
            let sliceData = handle.readData(ofLength: MemoryLayout<fat_arch>.size)
            
            guard var slice = sliceData.withUnsafeBytes({ $0.baseAddress })?.assumingMemoryBound(to: fat_arch.self).pointee else { return [] }
                        
            #if arch(arm64)
            if slice.cputype.bigEndian == CPU_TYPE_ARM64 { // hope that there's no arm64 and arm64e subtype
                handle.seek(toFileOffset: UInt64(slice.offset.bigEndian))
                
                var headerData = handle.readData(ofLength: MemoryLayout<mach_header>.size)
                
                if let newHeader = headerData.withUnsafeBytes({ $0.baseAddress })?.assumingMemoryBound(to: mach_header.self).pointee {
                    let readSize = Int(newHeader.sizeofcmds)
                    
                    handle.seek(toFileOffset: UInt64(slice.offset.bigEndian) + 0x20)
                    
                    let cmdData = handle.readData(ofLength: readSize)
                    
                    headerData.append(cmdData)
                }
                
                machHeaderPointer = headerData.withUnsafeBytes({ $0.baseAddress! })
                break
            }
            #else
            if slice.cputype.bigEndian == CPU_TYPE_X86_64 {
                handle.seek(toFileOffset: UInt64(slice.offset.bigEndian))
                
                var headerData = handle.readData(ofLength: MemoryLayout<mach_header>.size)
                
                if let newHeader = headerData.withUnsafeBytes({ $0.baseAddress })?.assumingMemoryBound(to: mach_header.self).pointee {
                    let readSize = Int(newHeader.sizeofcmds)
                    
                    handle.seek(toFileOffset: UInt64(slice.offset.bigEndian) + 0x20)
                    
                    let cmdData = handle.readData(ofLength: readSize)
                    
                    headerData.append(cmdData)
                }
                
                machHeaderPointer = headerData.withUnsafeBytes({ $0.baseAddress! })
                break
            }
            #endif
        }
    }
    
    let machHeader = machHeaderPointer.assumingMemoryBound(to: mach_header.self).pointee
        
    // Read the load commands
    var command = machHeaderPointer.advanced(by: MemoryLayout<mach_header>.size)
    
    var allPaths = [String]()
        
    // Iterate over the load commands
    for _ in 0..<machHeader.ncmds {
        let load_command = command.assumingMemoryBound(to: load_command.self).pointee
                
        if load_command.cmd == LC_LOAD_DYLIB {
            let dylib_command_pointer = command
            let dylib_command = dylib_command_pointer.assumingMemoryBound(to: dylib_command.self).pointee
            
            let cString = dylib_command_pointer
                .advanced(by: Int(dylib_command.dylib.name.offset))
                .assumingMemoryBound(to: CChar.self)
            
            let path = String(cString: cString)
            
            allPaths.append(path)
        }
        
        command = command.advanced(by: Int(load_command.cmdsize))
    }
        
    return allPaths
}

public func getLinkedBundleIDs(file path: String) throws -> [String] {

    let allPaths = try getLinkedPaths(file: path)
        
    let allBundleIDs = allPaths
        .compactMap {
            if $0.contains(".framework") {
                return Bundle(path: ($0 as NSString).deletingLastPathComponent)?.bundleIdentifier
            }
            return nil
        }
        
    return allBundleIDs
}
