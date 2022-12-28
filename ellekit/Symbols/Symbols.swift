
import Foundation

public func findSymbol(image machHeaderPointer: UnsafeRawPointer) throws {
    let machHeader = machHeaderPointer.assumingMemoryBound(to: mach_header.self).pointee

    // Read the load commands
    var command = machHeaderPointer.advanced(by: 0x20)

    // Iterate over the load commands
    for _ in 0..<machHeader.ncmds {
        let type = command.assumingMemoryBound(to: UInt32.self).pointee
        
        let size = command
            .advanced(by: MemoryLayout<UInt32>.size)
            .assumingMemoryBound(to: UInt32.self)
            .pointee
        
        command = command.advanced(by: Int(size))
        
        if type == LC_SYMTAB {
            let symtab_command_pointer = command.assumingMemoryBound(to: symtab_command.self)
            let symtab_command = symtab_command_pointer.pointee
            
            let strTab = machHeaderPointer.advanced(by: Int(symtab_command.stroff))
            print(String(cString: strTab.assumingMemoryBound(to: CChar.self)))
            
            var cur = machHeaderPointer.advanced(by: Int(symtab_command.symoff))
            for _ in 0..<symtab_command.nsyms {
                let strOff = command.assumingMemoryBound(to: UInt32.self).pointee
                
                cur = cur.advanced(by: 16)
            }
        }
    }
}
