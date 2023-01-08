
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

@available(macOS 10.15.4, *)
private func loadBaseHeader() throws -> UnsafeMutableRawPointer? {
    
    let path = "/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e"
    
    let fd = open(path, O_RDONLY)
        
    var header_ptr: UnsafeMutableRawPointer = malloc(0x4000)
    
    pread(fd, header_ptr, MemoryLayout<dyld_cache_header>.size, 0)
    
    print(header_ptr.assumingMemoryBound(to: dyld_cache_header.self).pointee)
        
    return nil
}

@available(macOS 10.15.4, *)
public func loadSharedCache(_ path: String) throws {
    try loadBaseHeader()
}
