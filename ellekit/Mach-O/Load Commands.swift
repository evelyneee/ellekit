
import Foundation

public func headerLinkedPaths(image machHeaderPointer: UnsafeRawPointer) throws -> [String] {
    var machHeaderPointer = machHeaderPointer
    
    if machHeaderPointer.assumingMemoryBound(to: mach_header.self).pointee.magic == FAT_CIGAM {
        // we have a fat binary
        // get our current cpu subtype
        let nslices = machHeaderPointer
            .advanced(by: 0x4)
            .assumingMemoryBound(to: UInt32.self)
            .pointee.bigEndian
        
        for i in 0..<nslices {
            let slice = machHeaderPointer
                .advanced(by: 8 + (Int(i) * 20))
                .assumingMemoryBound(to: fat_arch.self)
                .pointee
            #if arch(arm64)
            if slice.cputype.bigEndian == CPU_TYPE_ARM64 { // hope that there's no arm64e subtype
                machHeaderPointer = machHeaderPointer.advanced(by: Int(slice.offset.bigEndian))
            }
            #else
            if slice.cputype.bigEndian == CPU_TYPE_X86_64 {
                machHeaderPointer = machHeaderPointer.advanced(by: Int(slice.offset.bigEndian))
            }
            #endif
        }
    }
    
    let machHeader = machHeaderPointer.assumingMemoryBound(to: mach_header.self).pointee
        
    // Read the load commands
    var command = machHeaderPointer.advanced(by: 0x20)
    
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

public func headerBundleIDs(image machHeaderPointer: UnsafeRawPointer) throws -> [String] {

    let allPaths = try headerLinkedPaths(image: machHeaderPointer)
    
    print(allPaths)
    
    let allBundleIDs = allPaths
        .compactMap {
            if $0.contains(".framework") {
                return Bundle(path: ($0 as NSString).deletingLastPathComponent)?.bundleIdentifier
            }
            return nil
        }
    
    print(allBundleIDs)
    
    return allBundleIDs
}
