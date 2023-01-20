
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger


import Foundation

#if SWIFT_PACKAGE
import ellekitc
#endif

enum SymbolErr: Error {
    case noSymbol
    case noAddress
    case badCachePath
}

// Thanks to opa334 for the help
public func findSymbol(
    image machHeaderPointer: UnsafeRawPointer,
    symbol symbolName: String
) throws -> UnsafeRawPointer? {
    
    var machHeaderPointer = machHeaderPointer
    
    if machHeaderPointer.assumingMemoryBound(to: mach_header_64.self).pointee.magic == FAT_CIGAM {
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
    
    let machHeader = machHeaderPointer.assumingMemoryBound(to: mach_header_64.self).pointee
        
    // Read the load commands
    var command = machHeaderPointer.advanced(by: MemoryLayout<mach_header_64>.size)
    var commandIt = command;

    // First iteration: Get symtab pointer
    var symtab_cmd: symtab_command?
    
    for _ in 0..<machHeader.ncmds {
        let load_command = commandIt.assumingMemoryBound(to: load_command.self).pointee
        if load_command.cmd == LC_SYMTAB {
            symtab_cmd = commandIt.assumingMemoryBound(to: symtab_command.self).pointee
            break;
        }
        commandIt = commandIt.advanced(by: Int(load_command.cmdsize))
    }
    
    guard let symtab_cmd else { throw SymbolErr.noSymbol }
    
    var stroff: UInt64 = 0
    var symoff: UInt64 = 0
    var slide: UInt64 = 0
    
    // Second iteration: Resolve offsets by segments
    for _ in 0..<machHeader.ncmds {
        let load_command = command.assumingMemoryBound(to: load_command.self).pointee
        
        if load_command.cmd == LC_SEGMENT_64 {
            let segment_command = command.assumingMemoryBound(to: segment_command_64.self).pointee
            
            let segnameString = withUnsafePointer(to: segment_command.segname) {
                $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                    String(cString: $0)
                }
            }
                                   
            if slide == 0 && segnameString == "__TEXT" {
                slide = segment_command.vmaddr
            } else if segnameString == "__LINKEDIT" {
                                
                if (UInt64(symtab_cmd.symoff) - segment_command.fileoff) < segment_command.filesize {
                    symoff = segment_command.vmaddr + UInt64(symtab_cmd.symoff) - segment_command.fileoff
                }
                
                if (UInt64(symtab_cmd.stroff) - segment_command.fileoff) < segment_command.filesize {
                    stroff = segment_command.vmaddr + UInt64(symtab_cmd.stroff) - segment_command.fileoff
                }
                
            }
            
            if stroff != 0 && symoff != 0 && slide != 0 {
                break
            }
        }
        
        command = command.advanced(by: Int(load_command.cmdsize))
    }
            
    if slide != 0 {
        stroff = stroff - slide
        symoff = symoff - slide
    }
            
    let strTab = machHeaderPointer
        .advanced(by: Int(stroff))
                    
    // Iterate over the load commands
    for idx in 0..<(symtab_cmd.nsyms) { // idk why but the last symbols are always invalid
        
        let symbol = machHeaderPointer
            .advanced(by: Int(symoff))
            .advanced(by: Int(idx) * MemoryLayout<nlist_64>.size)
            .assumingMemoryBound(to: nlist_64.self).pointee
        
        // Access the properties of the symbol structure
        let strIndex = symbol.n_un.n_strx
                
        if strIndex >= symtab_cmd.strsize || strIndex == 0 {
            continue;
        }
        
        // Get the symbol's name from the string table
        let name = strTab.advanced(by: Int(strIndex)).assumingMemoryBound(to: CChar.self)
                    
        guard symbol.n_type != 115 && symbol.n_type != 17 else {
            continue
        }
                             
        if strcmp(name, symbolName) == 0 {
            
            guard symbol.n_value != 0 else {
                throw SymbolErr.noAddress
            }
            
            return UnsafeRawPointer(bitPattern: UInt(bitPattern: machHeaderPointer.advanced(by: Int(symbol.n_value - slide))))
        }
    }

    throw SymbolErr.noSymbol
}
