
import Foundation

func getSlide(_ task: task_t) -> UInt64 {
    var vmoffset: vm_map_offset_t = 0
    var vmsize: vm_map_size_t = 0
    var nesting_depth: UInt32 = 0
    var vbr: vm_region_submap_info_64 = .init()
    var vbrcount: mach_msg_type_number_t = 16;
    
    let krt = withUnsafeMutablePointer(to: &vbr) {
        $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<vm_region_submap_info_64>.size) {
            mach_vm_region_recurse(
                task,
                &vmoffset,
                &vmsize,
                &nesting_depth,
                $0,
                &vbrcount
            )
        }
    }
       
    assert(krt == KERN_SUCCESS)
    
    return vmoffset
}

func applyPatch(_ patchBytes: [UInt8], _ lock: Bool) {
    
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
    var threads = launchd_threads()
    threads.forEach { thread_suspend($0) }
}

public func launchd_unlock() {
    var threads = launchd_threads()
    threads.forEach { thread_resume($0) }
}


func test() {
    let theo = getSlide(mach_task_self_)
    print(theo, _dyld_get_image_vmaddr_slide(0))
    for idx in 0..<_dyld_image_count() {
        if let name = _dyld_get_image_name(idx) {
            print(String(cString: name), _dyld_get_image_vmaddr_slide(idx))
            if _dyld_get_image_vmaddr_slide(idx) == theo {
                print("found", String(cString: name))
            }
        }
    }
}

func allocateStringBuilder() -> mach_vm_address_t {
    
    let fn: mach_vm_address_t = .init(UInt(bitPattern: strip_pointer(patch_addr())))
        
    var addr: mach_vm_address_t = 0;
    
    let krt1 = mach_vm_allocate(task, &addr, UInt64(vm_page_size), VM_FLAGS_ANYWHERE);
    
    guard krt1 == KERN_SUCCESS else {
        print("[-] couldn't allocate base memory:", mach_error_string(krt1) ?? "")
        return 0
    }
    let krt2 = mach_vm_protect(task, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_WRITE);
    
    guard krt2 == KERN_SUCCESS else {
        print("[-] couldn't set memory to rw*:", mach_error_string(krt1) ?? "")
        return 0
    }
    
    mach_vm_write(task, addr, .init(bitPattern: Int(fn)), mach_msg_type_number_t(vm_page_size))
        
    let krt3 = mach_vm_protect(task, addr, UInt64(vm_page_size), 0, VM_PROT_READ | VM_PROT_EXECUTE);
    
    guard krt3 == KERN_SUCCESS else {
        print("[-] couldn't set memory to r*x:", mach_error_string(krt1) ?? "")
        return 0
    }
    
    return addr;
}
