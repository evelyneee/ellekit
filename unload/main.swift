import Foundation

func launchd_threads() -> [thread_act_t] {
    let act_list: UnsafeMutablePointer<thread_act_array_t?> = .allocate(capacity: 100)
    var count: UInt32 = 0
    task_threads(task, act_list, &count)
    let threadArray = act_list.pointee?.withMemoryRebound(to: thread_act_t.self, capacity: MemoryLayout<thread_act_t>.size * Int(count), { ptr in
        Array(UnsafeMutableBufferPointer(start: ptr, count: Int(count)))
    })
    return threadArray ?? []
}

public func launchd_lock() {
    let threads = launchd_threads()
    threads.forEach { thread_suspend($0) }
}

public func launchd_unlock() {
    let threads = launchd_threads()
    threads.forEach { thread_resume($0) }
}

guard getuid() == 0 else {
    print("ellekit: [loader] can't get launchd's task port without root permissions")
    exit(1)
}

var task: mach_port_t = 0

let pid_krt = task_for_pid(mach_task_self_, 1, &task)

guard pid_krt == KERN_SUCCESS else {
    print("[-] loader: no task for pid access ?")
    exit(1)
}

print("[+]", "got task", task)

let posix_spawn_address_u = UInt(bitPattern: dlsym(dlopen(nil, RTLD_NOW), "posix_spawn")) & 0x7FFFFFFFF
let spawn_ptr = UnsafeMutableRawPointer(bitPattern: posix_spawn_address_u)!
let posix_spawn_address: mach_vm_address_t = UInt64(posix_spawn_address_u)

var unpatched = spawn_ptr.withMemoryRebound(to: UInt8.self, capacity: 20, { ptr in
    Array(UnsafeMutableBufferPointer(start: ptr, count: 20))
})

print(unpatched)

// launchd_lock()

assert(mach_vm_protect(task, posix_spawn_address, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS)

let write = unpatched.withUnsafeBufferPointer { buf in
    mach_vm_write(task, posix_spawn_address, .init(bitPattern: buf.baseAddress!), .init(buf.count * MemoryLayout<UInt8>.size))
}

assert(write == KERN_SUCCESS)

assert(mach_vm_protect(task, posix_spawn_address, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS)

// launchd_unlock()

dispatchMain()
