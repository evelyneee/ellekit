
import Foundation

print("malloc:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "malloc"))!)
print("posix_spawn:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "posix_spawn"))!)
print("setenv:", strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "setenv"))!)
print("my uid:", getuid())

run_cmd("/usr/bin/env")

@_silgen_name("posix_spawn_patch_routine")

func posix_spawn_patch_routine(
    _:UnsafeMutablePointer<pid_t>?,
    _:UnsafePointer<CChar>?,
    _:UnsafePointer<posix_spawn_file_actions_t?>?,
    _:UnsafePointer<posix_spawnattr_t>?,
    _:UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    _:UnsafePointer<UnsafeMutablePointer<CChar>?>?
)

var pid: pid_t = 0

var task: mach_port_t = 0

let pid_krt = task_for_pid(mach_task_self_, 1, &task)

print("got task", task, "with status", String(cString: mach_error_string(pid_krt)))

let slide: Int = Int(getSlide(task))
            
let posix_spawn_address: mach_vm_address_t = .init(UInt(bitPattern: strip_pointer(dlsym(dlopen(nil, RTLD_NOW), "posix_spawn"))))

func remoteHexDump(_ task: task_t, _ addr: mach_vm_address_t) {
    var offset: vm_offset_t = 0
    var outSize: mach_msg_type_number_t = 0

    if mach_vm_read(task, addr, mach_vm_size_t(vm_page_size), &offset, &outSize) == KERN_SUCCESS {
        hexdump(.init(bitPattern: offset), 1000)
    } else {
        print("fail")
    }
}

let patch_addy = allocateStringBuilder()

@InstructionBuilder
var patch: [UInt8] {
    movk(.x16, patch_addy % 65536)
    movk(.x16, (patch_addy / 65536) % 65536, lsl: 16)
    movk(.x16, ((patch_addy / 65536) / 65536) % 65536, lsl: 32)
    movk(.x16, ((patch_addy / 65536) / 65536) / 65536, lsl: 48)
    br(.x16)
}

var patchBytes = patch

//launchd_lock()

assert(
    mach_vm_protect(
        task,
        posix_spawn_address,
        mach_vm_size_t(patchBytes.count * MemoryLayout<UInt8>.size),
        0,
        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY
    ) == KERN_SUCCESS
)


let write = patchBytes.withUnsafeMutableBufferPointer { buf in
    mach_vm_write(task, posix_spawn_address, .init(bitPattern: buf.baseAddress!), .init(buf.count * MemoryLayout<UInt8>.size))
}

assert(write == KERN_SUCCESS)

assert(
    mach_vm_protect(
        task,
        posix_spawn_address,
        mach_vm_size_t(patchBytes.count * MemoryLayout<UInt8>.size),
        0,
        VM_PROT_READ | VM_PROT_EXECUTE
    ) == KERN_SUCCESS
)

// launchd_unlock()

var offset2: vm_offset_t = 0
var outSize2: mach_msg_type_number_t = 0

// void posix_spawn_patch(pid_t *restrict pid, const char *restrict path,
// const posix_spawn_file_actions_t *file_actions,
// const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
//             char * envp[restrict])

unsetenv("DYLD_INSERT_LIBRARIES")
run_cmd("/usr/bin/env")

/*
threadArray?.forEach { thread in
    
//    let krt_sus = thread_suspend(thread)
//
//    print("susd thread", thread, krt_sus, String(cString: mach_error_string(krt_sus)))
//
//    if krt_sus != KERN_SUCCESS { return }
    
    // thread_suspend(thread)
    
    var state = __darwin_arm_thread_state64()
    var stateCnt = mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT)

    let krt2 = withUnsafeMutablePointer(to: &state) {
        $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size) {
            thread_get_state(thread, ARM_THREAD_STATE64, $0, &stateCnt)
        }
    }
        
    guard let ptr = state.__opaque_pc, let stripped = strip_pc(ptr) else { return }

    var orig = state
    
    var info = Dl_info()
    
    dladdr(state.__opaque_pc, &info)
    
    print(String(cString: info.dli_fname))

    state.__x.0 = UInt64(UInt(bitPattern: sign_data(UnsafeMutableRawPointer(bitPattern: UInt(addr))!)!))
    state.__x.1 = UInt64(RTLD_NOW)
    state.__opaque_pc = sign_pc(strip_pointer(dlsym_ptr()))
    state.__x.16 = UInt64(UInt(bitPattern: sign_pc(strip_pointer(dlsym_ptr()))))
    state.__opaque_sp? += 64
    state.__opaque_lr = nil
    
//    let krt3 = withUnsafeMutablePointer(to: &state) {
//        $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size) {
//            thread_set_state(thread, ARM_THREAD_STATE64, $0, stateCnt)
//        }
//    }
    
//    thread_resume(thread)
    
//    print(krt3)
    
    _ = launchd_routine
    
    sleep(1)
    
    print(state.__opaque_pc, UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: strip_pointer(state.__opaque_pc)) - UInt(slide)))
    
    let otherPointer = dlsym(dlopen(nil, RTLD_NOW), "launchd_routine")!.assumingMemoryBound(to: UInt8.self)
    
    var patch = [0x20, 0x00, 0x20, 0xD4]
    
    var buf = malloc(0x4000)
        
    var outSize: mach_vm_size_t = 0
                
    print(
        mach_vm_read_overwrite(
            task,
            .init(UInt(bitPattern: strip_pointer(orig.__opaque_pc))),
            mach_vm_size_t(vm_page_size),
            .init(UInt(bitPattern: buf)),
            &outSize
        )
    )
    
    var buf2 = malloc(0x4000)
        
    var outSize2: mach_vm_size_t = 0
                
    print(
        mach_vm_read_overwrite(
            mach_task_self_,
            .init(UInt(bitPattern: strip_pointer(dlsym_ptr()))),
            mach_vm_size_t(vm_page_size),
            .init(UInt(bitPattern: buf2)),
            &outSize2
        )
    )
    
    hexdump_ugh2(buf, 100)
    hexdump_ugh2(buf2, 100)
    
    print(outSize)
    
//    thread_suspend(thread)
    
//    let krt4 = withUnsafeMutablePointer(to: &orig) {
//        $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size) {
//            thread_set_state(thread, ARM_THREAD_STATE64, $0, stateCnt)
//        }
//    }
    
//    print(krt4)
    
//    thread_resume(thread)
    
    //hexdump_ugh2(buf, 500)
    
//    print(
//        thread_resume(thread)
//    )
}
*/
