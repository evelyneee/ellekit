
import Foundation

enum SymbolErr: Error {
    case noSymbol
    case noAddress
}

public func findSymbol(image machHeaderPointer: UnsafeRawPointer, symbol symbolName: String) throws -> UnsafeRawPointer? {
    
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

    // Iterate over the load commands
    for _ in 0..<machHeader.ncmds {
        let load_command = command.assumingMemoryBound(to: load_command.self).pointee
                
        if load_command.cmd == LC_SYMTAB {
            let symtab_command_pointer = command.assumingMemoryBound(to: symtab_command.self)
            let symtab_command = symtab_command_pointer.pointee
                        
            let strTab = machHeaderPointer.advanced(by: Int(symtab_command.stroff))
            
            var sym = UnsafeMutableRawPointer(mutating: symtab_command_pointer).advanced(by: Int(symtab_command.symoff))
                        
            for _ in 0..<(symtab_command.nsyms) { // idk why but the last symbols are always invalid
                                
                let symbol = sym.assumingMemoryBound(to: nlist_64.self).pointee
                                
                // Access the properties of the symbol structure
                let strIndex = symbol.n_un.n_strx

                // Get the symbol's name from the string table
                let name = strTab.advanced(by: Int(strIndex)).assumingMemoryBound(to: CChar.self)
                            
                guard symbol.n_type != 115 && symbol.n_type != 17 else {
                    continue
                }
                                
                let nName = String(cString: name)
                
                print(nName)
                
                if nName == symbolName {
                    
                    guard symbol.n_value != 0 else {
                        throw SymbolErr.noAddress
                    }
                    
                    return UnsafeRawPointer(bitPattern: UInt(bitPattern: machHeaderPointer.advanced(by: Int(symbol.n_value))))
                }
                
                sym = sym.advanced(by: MemoryLayout<nlist_64>.stride)
            }
            
            command = command.advanced(by: Int(load_command.cmdsize))
        } else {
            command = command.advanced(by: Int(load_command.cmdsize))
        }
    }
    
    throw SymbolErr.noSymbol
}
