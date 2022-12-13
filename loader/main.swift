
import Foundation
#if os(macOS)
import AppKit
#endif

print("malloc:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "malloc"))!)
print("posix_spawn:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "posix_spawn"))!)
print("setenv:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "setenv"))!)
print("_NSGetEnviron:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "_NSGetEnviron"))!)
print("my uid:", getuid())

guard getuid() == 0 else {
    print("ellekit: [loader] can't get launchd's task port without root permissions");
    fatalError()
}

var task: mach_port_t = 0

let pid_krt = task_for_pid(mach_task_self_, getpid(), &task)

print("got task", task, "with status", String(cString: mach_error_string(pid_krt)))

assert(pid_krt == KERN_SUCCESS)

var tweak_str_addr: mach_vm_address_t = 0;
assert(mach_vm_allocate(task, &tweak_str_addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE) == KERN_SUCCESS)
assert(mach_vm_protect(task, tweak_str_addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS)

class retain {
    static var str_c = ("/usr/local/lib/libinjector.dylib" as NSString).utf8String
}

assert(mach_vm_write(task, tweak_str_addr, UInt(bitPattern: retain.str_c), mach_msg_type_number_t(vm_page_size)) == KERN_SUCCESS)

let posix_spawn_address: mach_vm_address_t = .init(UInt(bitPattern: strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "posix_spawn"))))

var dlopen_fn = Int(UInt(bitPattern: strip_pointer(dlsym(dlopen("/usr/lib/system/libdyld.dylib", RTLD_NOW), "dlopen"))!))

@InstructionBuilder
var thread_target_routine: [UInt8] {
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
    b(0)
    ret()
}

var thread_target_routine_bytes = thread_target_routine

var pthread_target = allocateFunction(thread_target_routine_bytes) // our dlopen routine

var pthread_create_fn = Int(UInt(bitPattern: strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "pthread_create_from_mach_thread"))!))

@InstructionBuilder
var thread_start_routine: [UInt8] {
    // we start with the thread in x2
    bytes([
        0x7F, 0x23, 0x03, 0xD5, // pacibsp
        0xE0, 0x23, 0x00, 0x91 // x0=sp+8
    ])
    movz(.x1, 0)
    movz(.x3, 0)
    movk(.x16, pthread_create_fn % 65536)
    movk(.x16, (pthread_create_fn / 65536) % 65536, lsl: 16)
    movk(.x16, ((pthread_create_fn / 65536) / 65536) % 65536, lsl: 32)
    movk(.x16, ((pthread_create_fn / 65536) / 65536) / 65536, lsl: 48)
    bytes(0x1f, 0x0a, 0x3f, 0xd6)
    b(0) // spin after running
}

var thread_start_routine_bytes = thread_start_routine

var state = __darwin_arm_thread_state64()

var pthread_starter = sign_pointer(allocateFunction(thread_start_routine_bytes))
let sp_ptr = allocateStack()

bzero(&state, MemoryLayout.size(ofValue: state))

state.__x.2 = UInt64(UInt(bitPattern: pthread_target))
set_pc(pthread_starter, &state)
set_sp(sp_ptr, &state)

var thread: thread_t = 0

print(state)

DispatchQueue.global().async {
    let krt = withUnsafeMutablePointer(to: &state, {
        $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size, {
            thread_create_running(
                task,
                ARM_THREAD_STATE64,
                $0,
                mach_msg_type_number_t(MemoryLayout<__darwin_arm_thread_state64>.size / MemoryLayout<UInt32>.size),
                &thread
            )
        })
    })

    print(krt)
}

dispatchMain()
