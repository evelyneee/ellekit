
import Foundation
import Darwin

func executeAssemblyBytes<T>(returnType: T.Type, _ code: [UInt8]) -> T {
    code.withUnsafeBufferPointer { buf in
        let size = MemoryLayout.size(ofValue: code) * code.count
        let result = executeRawByteArray(buf.baseAddress!, size)
        return unsafeBitCast(result, to: T.self)
    }
}

func executeAssemblyBytes(_ code: [UInt8]) {
    code.withUnsafeBufferPointer { buf in
        let size = MemoryLayout.size(ofValue: code) * code.count
        _ = executeRawByteArray(buf.baseAddress!, size)
    }
}

func execWithRelativePtr(@InstructionBuilder _ instructions: (mach_vm_address_t) -> [UInt8]) {
    
    var addr: mach_vm_address_t = 0;
    mach_vm_allocate(mach_task_self_, &addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE);
    mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE);
        
    let code = instructions(addr)
    let codesize = MemoryLayout.size(ofValue: code) * (code.count)
    
    memcpy(UnsafeMutableRawPointer(bitPattern: UInt(addr)), code, codesize);
    mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
    //now cast the address to a function pointer and call it
    let fn = unsafeBitCast(addr, to: (@convention (c) () -> Void).self)
        
    fn();
    return
}

func executeRawByteArray(_ code: UnsafePointer<UInt8>, _ codesize: Int) -> AnyObject? {
    var addr: mach_vm_address_t = 0;
    mach_vm_allocate(mach_task_self_, &addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE);
    mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE);
    memcpy(UnsafeMutableRawPointer(bitPattern: UInt(addr)), code, codesize);
    mach_vm_protect(mach_task_self_, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
    //now cast the address to a function pointer and call it
    let fn = unsafeBitCast(addr, to: (@convention (c) () -> AnyObject?).self)
    return fn();
}

func byteArray<T: FixedWidthInteger>(from value: T) -> [UInt8] {
    Array(withUnsafeBytes(of: value.bigEndian, Array.init).dropFirst(4))
}

@discardableResult
func asm<T>(@InstructionBuilder _ instructions: () -> [UInt8]) -> T {
    return executeAssemblyBytes(returnType: T.self, instructions())
}

func asm(@InstructionBuilder _ instructions: () -> [UInt8]) {
    executeAssemblyBytes(instructions())
}

func dumpInstructions(_ array: [Instruction]) {
    array.forEach {
        print(
            type(of: $0),
            $0.bytes().map { "0x" + String(format:"%02X", $0) }.joined(separator: ", "),
            $0.bytes().map { String(format:"%02X", $0) }.joined()
        )
    }
}

@resultBuilder
struct InstructionBuilder {
    static func buildEither(first component: Instruction) -> Instruction {
        component
    }
    
    static func buildEither(second component: Instruction) -> Instruction {
        component
    }
    
    static func buildBlock(_ components: Instruction...) -> [UInt8] {
        #if DEBUG
        dumpInstructions(components)
        #endif
        return Array(
            components.map { $0.bytes() }.joined()
        )
    }
}
