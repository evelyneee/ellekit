
import Foundation

enum SymbolErr: Error {
    case noSymbol
    case badAddress
}

public func findSymbol(image machHeaderPointer: UnsafeRawPointer, symbol symbolName: String) throws -> UnsafeRawPointer? {
    let machHeader = machHeaderPointer.assumingMemoryBound(to: mach_header.self).pointee
    
    // Read the load commands
    var command = machHeaderPointer.advanced(by: 0x20)

    // Iterate over the load commands
    for _ in 0..<machHeader.ncmds {
        let load_command = command.assumingMemoryBound(to: load_command.self).pointee
                
        if load_command.cmd == LC_SYMTAB {
            let symtab_command_pointer = command.assumingMemoryBound(to: symtab_command.self)
            let symtab_command = symtab_command_pointer.pointee
                        
            let strTab = machHeaderPointer.advanced(by: Int(symtab_command.stroff))
            
            var sym = UnsafeMutableRawPointer(mutating: symtab_command_pointer).advanced(by: Int(symtab_command.symoff))
                        
            for _ in 0..<(symtab_command.nsyms - 100) { // idk why but the last symbols are always invalid
                                
                let symbol = sym.assumingMemoryBound(to: nlist_64.self).pointee
                                
                // Access the properties of the symbol structure
                let strIndex = symbol.n_un.n_strx

                // Get the symbol's name from the string table
                let name = strTab.advanced(by: Int(strIndex)).assumingMemoryBound(to: CChar.self)
                            
                print(String(cString: name))
                
                if String(cString: name) == symbolName && symbol.n_value != 0 {
                    
                    return UnsafeRawPointer(bitPattern: UInt(bitPattern: machHeaderPointer.advanced(by: Int(symbol.n_value))))
                }
                
                sym = sym.advanced(by: MemoryLayout<nlist_64>.stride)
            }
        } else {
            command = command.advanced(by: Int(load_command.cmdsize))
        }
    }
    
    throw SymbolErr.noSymbol
}
