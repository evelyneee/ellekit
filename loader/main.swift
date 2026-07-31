
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

guard safe_boot() == 0 else {
    print("[-] not injecting, this is macOS safe mode")
    exit(1)
}

guard getuid() == 0 else {
    print("[-] can't get launchd's task port without root permissions")
    exit(1)
}

var task: mach_port_t = 0

let pid_krt = task_for_pid(mach_task_self_, 1, &task)

guard pid_krt == KERN_SUCCESS else {
    print("[-] loader: no task for pid access ?")
    exit(1)
}

print("[+]", "got task", task)

var tweak_str_addr: mach_vm_address_t = 0
assert(mach_vm_allocate(task, &tweak_str_addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE) == KERN_SUCCESS)
assert(mach_vm_protect(task, tweak_str_addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS)

class retain {
    
    static func getPath() -> String {
        #if os(macOS)
        return "/Library/TweakInject/pspawn.dylib"
        #else
        if access("/usr/lib/ellekit/pspawn.dylib", F_OK) == 0 {
            return "/usr/lib/ellekit/pspawn.dylib"
        } else {
            return (("/var/jb/usr/lib/ellekit/pspawn.dylib" as NSString).resolvingSymlinksInPath)
        }
        #endif
    }
    
    static var str_c = (getPath() as NSString).utf8String
}

guard access(retain.str_c, F_OK) == 0 else {
    print("[-] the path \(retain.getPath()) doesn't exit, so we can't load it")
    fatalError()
}

print("[i] using path", retain.getPath())

assert(mach_vm_write(task, tweak_str_addr, UInt(bitPattern: retain.str_c), mach_msg_type_number_t(vm_page_size)) == KERN_SUCCESS)

let posix_spawn_address: mach_vm_address_t = .init(UInt(bitPattern: strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "posix_spawn"))))

var dlopen_fn = Int(UInt(bitPattern: strip_pointer(dlsym(dlopen("/usr/lib/system/libdyld.dylib", RTLD_NOW), "dlopen"))!))

let pthread_handle = dlopen("/usr/lib/system/libsystem_pthread.dylib", RTLD_NOW)
let pthread_exit_ptr = strip_pointer(dlsym(pthread_handle, "pthread_exit"))!
var pthread_exit_addr = Int(UInt(bitPattern: pthread_exit_ptr))

@InstructionBuilder
var thread_target_routine: [UInt8] {
    bytes([
        0xFF, 0x43, 0x00, 0xD1,
        0xFD, 0x7B, 0x00, 0xA9,
        0xFD, 0x03, 0x00, 0x91
    ])
    movk(.x0, tweak_str_addr % 65536)
    movk(.x0, (tweak_str_addr / 65536) % 65536, lsl: 16)
    movk(.x0, ((tweak_str_addr / 65536) / 65536) % 65536, lsl: 32)
    movk(.x0, ((tweak_str_addr / 65536) / 65536) / 65536, lsl: 48)
    movz(.x1, Int(RTLD_NOW))
    movk(.x14, dlopen_fn % 65536)
    movk(.x14, (dlopen_fn / 65536) % 65536, lsl: 16)
    movk(.x14, ((dlopen_fn / 65536) / 65536) % 65536, lsl: 32)
    movk(.x14, ((dlopen_fn / 65536) / 65536) / 65536, lsl: 48)
    blr(.x14)
    bytes([
         0xFD, 0x7B, 0x40, 0xA9,
         0xFF, 0x43, 0x00, 0x91
     ])
    ret()
}

var thread_target_routine_bytes = thread_target_routine

var pthread_target = allocateFunction(thread_target_routine_bytes) // our dlopen routine

let pthread_create_ptr = strip_pointer(dlsym(pthread_handle, "pthread_create_from_mach_thread"))!
var pthread_create_addr = Int(UInt(bitPattern: pthread_create_ptr))

@InstructionBuilder
var thread_start_routine: [UInt8] {
    // we start with the thread in x2
    bytes([
        0xFF, 0x43, 0x00, 0xD1, // sub sp, sp, #16
        0xE0, 0x23, 0x00, 0x91 // add x0, sp, #8
    ])
    movz(.x1, 0)
    #if _ptrauth(_arm64e)
    paciza(.x2)
    #endif
    movz(.x3, 0)
    movk(.x14, pthread_create_addr % 65536)
    movk(.x14, (pthread_create_addr / 65536) % 65536, lsl: 16)
    movk(.x14, ((pthread_create_addr / 65536) / 65536) % 65536, lsl: 32)
    movk(.x14, ((pthread_create_addr / 65536) / 65536) / 65536, lsl: 48)
    blr(.x14)
    b(0)
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
var count = mach_msg_type_number_t(MemoryLayout<__darwin_arm_thread_state64>.size / MemoryLayout<UInt32>.size)

#if _ptrauth(_arm64e)
guard custom_thread_create(task, &thread) == KERN_SUCCESS else {
    print("[-] loader: failed to spawn thread")
    exit(1)
}

if thread == 0 {
    print("[-] loader: thread is a NULL mach_port")
    exit(1)
}

print("[+] loader: started thread:", thread)

let convert = withUnsafeMutablePointer(to: &state, {
    $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size, { statePtr in
        thread_convert_thread_state(
            thread,
            THREAD_CONVERT_THREAD_STATE_FROM_SELF,
            ARM_THREAD_STATE64,
            statePtr,
            mach_msg_type_number_t(MemoryLayout<__darwin_arm_thread_state64>.size / MemoryLayout<UInt32>.size),
            statePtr,
            &count
        )
    })
})

guard convert == KERN_SUCCESS else {
    print("[-] loader: failed to convert thread state")
    exit(1)
}

print("[+] loader: converted thread state")

let create = withUnsafeMutablePointer(to: &state, {
    $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size, { statePtr in
        thread_set_state(thread, ARM_THREAD_STATE64, statePtr, count)
    })
})

guard create == KERN_SUCCESS else {
    print("[-] loader: failed to set thread state")
    exit(1)
}

print("[+] loader: set thread state")
#else
print("[*] using thread_create_running method")
guard withUnsafeMutablePointer(to: &state, {
    $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size, { statePtr in
        custom_thread_create_running(task, ARM_THREAD_STATE64, statePtr, count, &thread)
    })
}) == KERN_SUCCESS else {
    print("[-] loader: failed to spawn thread")
    exit(1)
}

if thread == 0 {
    print("[-] loader: thread is a NULL mach_port")
    exit(1)
}

print("[+] loader: started thread:", thread)

#endif

DispatchQueue.global().async {
    thread_resume(thread)
    print("[+] loader: resumed thread state. waiting for launchd...")
    sleep(3)
    print("[+] loader: closed thread")
    thread_suspend(thread)
    custom_thread_terminate(thread)
    print("[i] run `launchctl reboot userspace` to load your tweaks")
    exit(0)
}

dispatchMain()
