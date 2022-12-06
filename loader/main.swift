//
//  main.swift
//  loader
//
//  Created by charlotte on 2022-12-04.
//

import Foundation

var task: mach_port_t = 0

let pid_krt = task_for_pid(mach_task_self_, 1, &task)

print("got task", task, pid_krt, String(cString: mach_error_string(pid_krt)))

let act_list: UnsafeMutablePointer<thread_act_array_t?> = .allocate(capacity: 100)
var count: UInt32 = 0
let task_krt = task_threads(task, act_list, &count)

let threadArray = act_list.pointee?.withMemoryRebound(to: thread_act_t.self, capacity: MemoryLayout<thread_act_t>.size * Int(count), { ptr in
    Array(UnsafeMutableBufferPointer(start: ptr, count: Int(count)))
})

let ARM_THREAD_STATE64_COUNT = MemoryLayout<arm_thread_state64_t>.size/MemoryLayout<UInt32>.size

var states = threadArray?.map { thread in
    var state = __darwin_arm_thread_state64()
    var stateCnt = mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT)
    
    thread_suspend(thread)
    
    let krt2 = withUnsafeMutablePointer(to: &state) {
        $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size) {
            thread_get_state(thread, ARM_THREAD_STATE64, $0, &stateCnt)
        }
    }
    
    return (thread, state)
}

sleep(2);

inject_to_task(task, "/usr/local/lib/libinjector.dylib")

states?.forEach { thread, state in
    var state = state
    var stateCnt = mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT)
    _ = withUnsafeMutablePointer(to: &state) {
        $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<__darwin_arm_thread_state64>.size) {
            thread_set_state(thread, ARM_THREAD_STATE64, $0, stateCnt)
        }
    }
    thread_resume(thread)
}

exit(0);

#if false

print("got threads", threadArray, task_krt, String(cString: mach_error_string(task_krt)))

let ARM_THREAD_STATE64_COUNT = MemoryLayout<arm_thread_state64_t>.size/MemoryLayout<UInt32>.size

let sym = dlsym(dlopen(nil, RTLD_NOLOAD), "os_log_simple_now")!

//var addr: mach_vm_address_t = 0;
//assert(mach_vm_allocate(task, &addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE) == KERN_SUCCESS)
//assert(mach_vm_protect(task, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE) == KERN_SUCCESS)
//var str = ("/usr/local/lib/libtesttweak.dylib" as NSString).utf8String
//assert(mach_vm_write(task, addr, UInt(bitPattern: str), mach_msg_type_number_t(vm_page_size)) == KERN_SUCCESS)

let slide = launchd_slide(task)

var addr: mach_vm_address_t = 0;
assert(mach_vm_allocate(task, &addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE) == KERN_SUCCESS)
assert(mach_vm_protect(task, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE) == KERN_SUCCESS)
var str = ("/usr/local/lib/libinjector.dylib" as NSString).utf8String
assert(mach_vm_write(task, addr, UInt(bitPattern: str), mach_msg_type_number_t(vm_page_size)) == KERN_SUCCESS)

print("allocated everything fine!!!!")

print(UInt64(UInt(bitPattern: sign_data(UnsafeMutableRawPointer(bitPattern: UInt(addr))!)!)))

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

#endif
