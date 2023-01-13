
import Foundation

#if SWIFT_PACKAGE
import ellekitc
#endif

public func sharedCachePath() -> String {
    #if os(macOS)
    if #available(macOS 13.0, *) {
        #if arch(arm64)
        return "/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64e"
        #elseif arch(x86_64)
        return "/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld/dyld_shared_cache_x86_64"
        #endif
    } else {
        #if arch(arm64)
        return "/System/Library/dyld/dyld_shared_cache_arm64e"
        #elseif arch(x86_64)
        return "/System/Library/dyld/dyld_shared_cache_x86_64"
        #endif
    }
    #else
    if #available(iOS 16.0, *) {
        if FileManager.default.fileExists(atPath: "/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64e") {
            return "/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64e"
        } else {
            return "/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64"
        }
    } else {
        if FileManager.default.fileExists(atPath: "/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64e") {
            return "/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64e"
        } else {
            return "/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64"
        }
    }
    #endif
}

private func sharedCacheSymbolsPath() -> String {
    if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
        return sharedCachePath()+".symbols"
    } else {
        return sharedCachePath()
    }
}


public func findPrivateSymbol(image machHeaderPointer: UnsafeRawPointer, symbol symbolName: String) throws -> UnsafeRawPointer? {
    guard let handle = FileHandle(forReadingAtPath: sharedCacheSymbolsPath()) else {
        print("[-] ellekit: failed to open shared cache")
        return nil
    }
                    
    let entry = handle
        .readData(ofLength: MemoryLayout<dyld_cache_header>.size)
        .withUnsafeBytes { $0.baseAddress! }
        .assumingMemoryBound(to: dyld_cache_header.self)
        .pointee
                    
    handle.seek(toFileOffset: entry.localSymbolsOffset)
        
    let symInfo = handle
        .readData(ofLength: MemoryLayout<dyld_cache_local_symbols_info>.size)
        .withUnsafeBytes { $0.baseAddress! }
        .assumingMemoryBound(to: dyld_cache_local_symbols_info.self)
        .pointee
    
    handle.seek(toFileOffset: entry.localSymbolsOffset + UInt64(symInfo.stringsOffset))
    
    let strTab = handle
        .readData(ofLength: Int(symInfo.stringsSize))
        .withUnsafeBytes { $0.baseAddress! }
                    
    handle.seek(toFileOffset: entry.localSymbolsOffset + UInt64(symInfo.nlistOffset))
    
    var sym = handle
        .readData(ofLength: Int(entry.localSymbolsSize))
        .withUnsafeBytes { $0.baseAddress! }
    
    for _ in 0..<(symInfo.nlistCount) { // idk why but the last symbols are always invalid
                        
        let symbol = sym.assumingMemoryBound(to: nlist_64.self).pointee
                    
        // Access the properties of the symbol structure
        let strIndex = symbol.n_un.n_strx
        
        if strIndex == 0 {
            sym = sym.advanced(by: MemoryLayout<nlist_64>.size)
            continue;
        }

        // Get the symbol's name from the string table
        let name = strTab.advanced(by: Int(strIndex)).assumingMemoryBound(to: CChar.self)
                    
        guard symbol.n_type != 115 && symbol.n_type != 17 else {
            sym = sym.advanced(by: MemoryLayout<nlist_64>.size)
            continue
        }
                        
        let nName = String(cString: name)
                      
        if nName == symbolName {
            
            guard symbol.n_value != 0 else {
                return nil
            }
            
            return UnsafeRawPointer(bitPattern: UInt(bitPattern: machHeaderPointer.advanced(by: Int(symbol.n_value))))
        }
        
        sym = sym.advanced(by: MemoryLayout<nlist_64>.size)
    }
    
    throw SymbolErr.noSymbol
}

