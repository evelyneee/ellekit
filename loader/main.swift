//
//  main.swift
//  loader
//
//  Created by charlotte on 2022-12-04.
//

import Foundation

var task: mach_port_t = 0

let pid_krt = task_for_pid(mach_task_self_, 1, &task)

print("got task", pid_krt, String(cString: mach_error_string(pid_krt)))

let act_list: UnsafeMutablePointer<thread_act_array_t?> = .allocate(capacity: 100)
var count: UInt32 = 0
let task_krt = task_threads(task, act_list, &count)

let threadArray = act_list.pointee?.withMemoryRebound(to: thread_act_t.self, capacity: MemoryLayout<thread_act_t>.size * Int(count), { ptr in
    Array(UnsafeMutableBufferPointer(start: ptr, count: Int(count)))
})

print("got threads", threadArray, task_krt, String(cString: mach_error_string(task_krt)))

let ARM_THREAD_STATE64_COUNT = MemoryLayout<arm_thread_state64_t>.size/MemoryLayout<UInt32>.size

let sym = dlsym(dlopen(nil, RTLD_NOW), "dlopen")!

var state = arm_thread_state64()
var stateCnt = mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT)

var thread: mach_port_t = threadArray!.first!

let krt2 = withUnsafeMutablePointer(to: &state) {
    $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<arm_thread_state64>.size) {
        thread_get_state(thread, ARM_THREAD_STATE64, $0, &stateCnt)
    }
}

var addr: mach_vm_address_t = 0;
assert(mach_vm_allocate(task, &addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE) == KERN_SUCCESS)
assert(mach_vm_protect(task, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE) == KERN_SUCCESS)
var str = ("/usr/local/lib/libinjector.dylib" as NSString).utf8String
assert(mach_vm_write(task, addr, UInt(bitPattern: str), mach_msg_type_number_t(vm_page_size)) == KERN_SUCCESS)

print("allocated everything fine!!!!")

print(UInt64(UInt(bitPattern: sign_data(UnsafeMutableRawPointer(bitPattern: UInt(addr))!)!)))

var orig = state

state.__x.0 = UInt64(UInt(bitPattern: sign_data(UnsafeMutableRawPointer(bitPattern: UInt(addr))!)!))
state.__x.1 = UInt64(RTLD_NOW)
state.__opaque_pc = sign_pc(sym)
state.__x.16 = UInt64(UInt(bitPattern: sign_pc(sym)))

let krt_sus = thread_suspend(thread)

print("susd thread", thread, krt_sus, String(cString: mach_error_string(krt_sus)))

let krt_set = withUnsafeMutablePointer(to: &state, {
    $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<arm_thread_state64>.size, {
        thread_set_state(thread, ARM_THREAD_STATE64, $0, mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT))
    })
})

// RUN CONSOLE IDIOT

print("set thread", thread, krt_set, String(cString: mach_error_string(krt_set)))

let krt_res = thread_resume(thread)

print("resumed thread", thread, krt_res, String(cString: mach_error_string(krt_res)))

sleep(2)

thread_suspend(thread)

var lastState = arm_thread_state64()
let krt5 = withUnsafeMutablePointer(to: &lastState) {
    $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<arm_thread_state64>.size) {
        thread_get_state(thread, ARM_THREAD_STATE64, $0, &stateCnt)
    }
}

if lastState.__x.0 == state.__x.0 {
    print("FAILED.")
}

print(lastState.__x.0)

let krt_set2 = withUnsafeMutablePointer(to: &orig, {
    $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<arm_thread_state64>.size, {
        thread_set_state(thread, ARM_THREAD_STATE64, $0, mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT))
    })
})

thread_resume(thread)

@discardableResult
func launchdHook(address: UnsafeMutableRawPointer, code: UnsafePointer<UInt8>?, size: mach_vm_size_t) -> Int {
    let newPermissions = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY;
    mach_vm_protect(mach_task_self_, mach_vm_address_t(UInt(bitPattern: address)), mach_vm_size_t(size), 0, newPermissions);
    
    memcpy(address, code, Int(size));
    
    let originalPerms = VM_PROT_READ | VM_PROT_EXECUTE;
    let err2 = mach_vm_protect(task,
                               mach_vm_address_t(UInt(bitPattern: address)),
                               mach_vm_size_t(size),
                               0,
                               originalPerms)
    
    // flush page cache so we don't hit cached unpatched functions
    sys_icache_invalidate(address, Int(vm_page_size))
    
    guard err2 == 0 else { return Int(err2) }
    
    return 0
}
