
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

#if SWIFT_PACKAGE
import ellekitc
#endif

enum LinkPathError: Error {
    case badMachO
    case badPath
}

/*
 int loadSignature(NSString* filePath)
 {
     uint32_t offset = 0, size = 0;
     
     getCSBlobOffsetAndSize(filePath, &offset, &size);
     
     int binaryFd = open(filePath.UTF8String, O_RDONLY);
     
     struct fsignatures fsig;
     fsig.fs_file_start = 0;
     fsig.fs_blob_start = (void*)(uint64_t)offset;
     fsig.fs_blob_size = size;
     
     int ret = fcntl(binaryFd, F_ADDFILESIGS, fsig);
     close(binaryFd);
     return ret;
 }
 */

public func getLinkedPaths(file path: String) throws -> [String] {
        
    guard let handle = fopen(path, "r") else {
        throw LinkPathError.badPath
    }
    
    defer { handle.close() }
    
    var machHeaderPointer = handle
        .readData(ofLength: MemoryLayout<mach_header_64>.size)
    
    var baseOffset: UInt32 = 0
    
    defer { machHeaderPointer.deallocate() }
    
    if machHeaderPointer.assumingMemoryBound(to: mach_header_64.self).pointee.magic == FAT_CIGAM {
        // we have a fat binary
        // get our current cpu subtype
        let nslices = handle
            .seek(toFileOffset: 0x4)
            .readData(ofLength: MemoryLayout<UInt32>.size)
            .assumingMemoryBound(to: UInt32.self)
            .pointee.bigEndian
                        
        for i in 0..<nslices {
            let slice_ptr = handle
                .seek(toFileOffset: UInt64(8 + (Int(i) * 20)))
                .readData(ofLength: MemoryLayout<fat_arch>.size)
                .assumingMemoryBound(to: fat_arch.self)
            
            let slice = slice_ptr.pointee
            
            defer { slice_ptr.deallocate() }
                                        
            machHeaderPointer = handle.seek(toFileOffset: UInt64(slice.offset.bigEndian)).readData(ofLength: MemoryLayout<mach_header_64>.size)
            baseOffset = slice.offset.bigEndian
        }
    }
    
    let machHeader = machHeaderPointer.assumingMemoryBound(to: mach_header_64.self).pointee
                
    guard machHeader.ncmds < 0x4000 && machHeader.magic == MH_MAGIC_64 else { throw LinkPathError.badMachO }
            
    var allPaths = [String]()
    var commandOffset: UInt32 = 0
    
    // Iterate over the load commands
    for _ in 0..<machHeader.ncmds {
        let load_command = handle
            .seek(toFileOffset: UInt64(baseOffset + 0x20 + commandOffset))
            .readData(ofLength: MemoryLayout<load_command>.size)
            .assumingMemoryBound(to: load_command.self)
                
        defer { load_command.deallocate() }
        
        if load_command.pointee.cmd == LC_LOAD_DYLIB {
            let dylib_command = handle
                .seek(toFileOffset: UInt64(baseOffset + 0x20 + commandOffset))
                .readData(ofLength: MemoryLayout<dylib_command>.size)
                .assumingMemoryBound(to: dylib_command.self)
            
            defer { dylib_command.deallocate() }
            
            let cString = handle
                .seek(toFileOffset: UInt64(baseOffset + 0x20 + commandOffset + dylib_command.pointee.dylib.name.offset))
                .readData(ofLength: 1024)
                .assumingMemoryBound(to: UInt8.self)
            
            defer { cString.deallocate() }
            
            let path = String(cString: cString)
            
            allPaths.append(path)
        }
                        
        commandOffset += UInt32(load_command.pointee.cmdsize)
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
