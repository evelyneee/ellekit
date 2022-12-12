
import Foundation

func applyPatch(_ patchBytes: [UInt8], lock: Bool) {
    
    var patchBytes = patchBytes
    
    if lock {
        launchd_lock()
    }
    
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

    if lock {
        launchd_unlock()
    }
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
