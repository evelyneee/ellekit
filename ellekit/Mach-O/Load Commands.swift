
import Foundation

public func headerBundleIDs(image machHeaderPointer: UnsafeRawPointer) throws -> [String] {
    let machHeader = machHeaderPointer.assumingMemoryBound(to: mach_header.self).pointee
    
    // Read the load commands
    var command = machHeaderPointer.advanced(by: 0x20)

    // Iterate over the load commands
    for _ in 0..<machHeader.ncmds {
        let load_command = command.assumingMemoryBound(to: load_command.self).pointee
                
        if load_command.cmd == LC_LOAD_DYLIB {
            let dylib_command_pointer = command.assumingMemoryBound(to: dylib_command.self)
            let dylib_command = dylib_command_pointer.pointee
                        
            let offset = dylib_command_pointer
                .advanced(by: Int(dylib_command.dylib.name.offset))
            
            let stringPointer = UnsafeMutableRawPointer(mutating: offset).assumingMemoryBound(to: CChar.self)
            
            print(String(cString: stringPointer))
        }
        
        command = command.advanced(by: Int(load_command.cmdsize))
    }
    
    return []
}
