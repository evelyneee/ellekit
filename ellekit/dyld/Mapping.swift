
import Foundation

private func loadCacheBaseHeader() -> (UnsafeMutableRawPointer?, dyld_cache_header?) {
    var start_address: UInt64 = 0
    shared_region_check(&start_address)
    let cache_base_header_pointer = UnsafeMutableRawPointer(bitPattern: Int(start_address))

    let cache_base_header = cache_base_header_pointer?
        .assumingMemoryBound(to: dyld_cache_header.self)
        .pointee
    
    let cache_base_magic = String(cString: cache_base_header_pointer!.assumingMemoryBound(to: CChar.self))
    
    print(cache_base_magic)
    
    return (cache_base_header_pointer, cache_base_header)
}

public func loadSharedCache(_ path: String) {
    
    let (cache_base_header_pointer, cache_base_header) = loadCacheBaseHeader()
    
    guard let header = cache_base_header, let header_pointer = cache_base_header_pointer else { return }
    
    print(header_pointer.advanced(by: Int(header.localSymbolsOffset)))
    
    print(header)
    
    exit(0)
}
