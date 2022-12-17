import Foundation

func allocateFunction(_ patchBytes: [UInt8]) -> UnsafeMutableRawPointer {
    var page_address: mach_vm_address_t = 0
    assert(mach_vm_allocate(task, &page_address, UInt64(vm_page_size), VM_FLAGS_ANYWHERE) == KERN_SUCCESS)
    assert(mach_vm_protect(task, page_address, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS)

    let write = patchBytes.withUnsafeBufferPointer { buf in
        mach_vm_write(task, page_address, .init(bitPattern: buf.baseAddress!), .init(buf.count * MemoryLayout<UInt8>.size))
    }

    assert(write == KERN_SUCCESS)

    assert(mach_vm_protect(task, page_address, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS)
    return UnsafeMutableRawPointer(bitPattern: UInt(page_address))!
}

func allocateStack() -> UnsafeMutableRawPointer {
    var page_address: mach_vm_address_t = 0
    assert(mach_vm_allocate(task, &page_address, 65536, VM_FLAGS_ANYWHERE) == KERN_SUCCESS)
    assert(mach_vm_protect(task, page_address, 65536, 0, VM_PROT_READ | VM_PROT_WRITE) == KERN_SUCCESS)
    return UnsafeMutableRawPointer(bitPattern: UInt(page_address) + (65536 / 2))!
}

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
