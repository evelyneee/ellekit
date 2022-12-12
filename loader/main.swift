
import Foundation
#if os(macOS)
import AppKit
#endif

print("malloc:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "malloc"))!)
print("posix_spawn:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "posix_spawn"))!)
print("setenv:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "setenv"))!)
print("_NSGetEnviron:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "_NSGetEnviron"))!)
print("my uid:", getuid())

var pid: pid_t = 0

var task: mach_port_t = 0

let pid_krt = task_for_pid(mach_task_self_, 1, &task)

print("got task", task, "with status", String(cString: mach_error_string(pid_krt)))

assert(pid_krt == KERN_SUCCESS)

var tweak_str_addr: mach_vm_address_t = 0;
assert(mach_vm_allocate(task, &tweak_str_addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE) == KERN_SUCCESS)
assert(mach_vm_protect(task, tweak_str_addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS)
var str_c = ("/usr/local/lib/libinjector.dylib" as NSString).utf8String
assert(mach_vm_write(task, tweak_str_addr, UInt(bitPattern: str_c), mach_msg_type_number_t(vm_page_size)) == KERN_SUCCESS)
            
let posix_spawn_address: mach_vm_address_t = .init(UInt(bitPattern: strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "posix_spawn"))))

var dlopen_fn = Int(UInt(bitPattern: strip_pointer(dlsym(dlopen("/usr/lib/system/libdyld.dylib", RTLD_NOW), "dlopen"))!))

@InstructionBuilder
var patch: [UInt8] {
    // start
    bytes([
        0xFF, 0x43, 0x00, 0xD1,
        0xFD, 0x7B, 0x00, 0xA9,
        0xFD, 0x03, 0x00, 0x91,
    ])
    movz(.x1, Int(getpid()))
    str(.x1, .x0)
    movk(.x0, tweak_str_addr % 65536)
    movk(.x0, (tweak_str_addr / 65536) % 65536, lsl: 16)
    movk(.x0, ((tweak_str_addr / 65536) / 65536) % 65536, lsl: 32)
    movk(.x0, ((tweak_str_addr / 65536) / 65536) / 65536, lsl: 48)
    movz(.x1, Int(RTLD_LAZY))
    movk(.x16, dlopen_fn % 65536)
    movk(.x16, (dlopen_fn / 65536) % 65536, lsl: 16)
    movk(.x16, ((dlopen_fn / 65536) / 65536) % 65536, lsl: 32)
    movk(.x16, ((dlopen_fn / 65536) / 65536) / 65536, lsl: 48)
    blr(.x16)
    movz(.x0, 1)
    // end
    bytes([
        0xFD, 0x7B, 0x40, 0xA9,
        0xFF, 0x43, 0x00, 0x91
    ])
    ret()
}

var patchBytes = patch

var unpatched = strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "posix_spawn"))!.withMemoryRebound(to: UInt8.self, capacity: patchBytes.count, { ptr in
    Array(UnsafeMutableBufferPointer(start: ptr, count: patchBytes.count))
})

applyPatch(patchBytes, lock: true) // install hook

NSWorkspace.shared.open(NSURL.fileURL(withPath: "/System/Applications/Calculator.app")) // trigger hook
sleep(2)

applyPatch(unpatched, lock: true) // unhook

mach_port_deallocate(mach_task_self_, task)
