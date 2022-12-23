import Foundation
import Darwin

#if SWIFT_PACKAGE
import ellekitc
#endif

#if arch(x86_64)
let ARM_THREAD_STATE64_COUNT = 0
#else
let ARM_THREAD_STATE64_COUNT = MemoryLayout<arm_thread_state64_t>.size/MemoryLayout<UInt32>.size
#endif

var closeExceptionPort = false

public final class ExceptionHandler {

    let port: mach_port_t
    let targetTask: mach_port_t
    let thread = DispatchQueue(label: "ellekit_exc_port", attributes: .concurrent)

    public init?(_ pid: pid_t) {
        
        var port: mach_port_t = 0
        
        let ret = task_for_pid(mach_task_self_, pid, &port)
        
        guard ret == KERN_SUCCESS else {
            return nil
        }
        
        print("got task", port)
        
        self.targetTask = port
        
        var targetPort = mach_port_t()

        mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &targetPort)
        mach_port_insert_right(mach_task_self_, targetPort, targetPort, mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND))

        task_set_exception_ports(
            port,
            exception_mask_t(EXC_MASK_SOFTWARE | EXC_MASK_BREAKPOINT),
            targetPort,
            EXCEPTION_DEFAULT,
            ARM_THREAD_STATE64
        )

        self.port = targetPort

        startPortLoop()
    }

    public func startPortLoop() {
        print("[+] ellekit: starting exception handler")
        self.thread.async { [weak self] in
            Self.portLoop(self)
        }
    }

    static func portLoop(_ `self`: ExceptionHandler?) {

        guard let `self` else {
            print("[-] ellekit: exception handler deallocated.")
            return
        }

        let msg_header = UnsafeMutablePointer<mach_msg_header_t>.allocate(capacity: Int(vm_page_size))

        defer { msg_header.deallocate() }

        let krt1 = mach_msg(
            msg_header,
            MACH_RCV_MSG | MACH_RCV_LARGE | Int32(MACH_MSG_TIMEOUT_NONE),
            0,
            mach_msg_size_t(vm_page_size),
            self.port,
            0,
            0
        )
        
        guard krt1 == KERN_SUCCESS else {
            print("[-] couldn't receive from port:", mach_error_string(krt1) ?? "")
            return
        }

        let req = UnsafeMutableRawPointer(msg_header)
            .withMemoryRebound(to: __Request__exception_raise_t.self, capacity: Int(vm_page_size)) { $0.pointee }
        
        print("got exception")
        
        var reply = __Reply__exception_raise_t()
        reply.Head.msgh_bits = req.Head.msgh_bits & UInt32(MACH_MSGH_BITS_REMOTE_MASK)
        reply.Head.msgh_size = mach_msg_size_t(MemoryLayout.size(ofValue: reply))
        reply.Head.msgh_remote_port = req.Head.msgh_remote_port
        reply.Head.msgh_local_port = mach_port_t(MACH_PORT_NULL)
        reply.Head.msgh_id = req.Head.msgh_id + 0x64

        reply.NDR = req.NDR
        reply.RetCode = KERN_SUCCESS

        let krt = mach_msg(
            &reply.Head,
            1,
            reply.Head.msgh_size,
            0,
            mach_port_name_t(MACH_PORT_NULL),
            MACH_MSG_TIMEOUT_NONE,
            mach_port_name_t(MACH_PORT_NULL)
        )

        if krt != KERN_SUCCESS {
            print("[-] error sending reply to exception: ", mach_error_string(krt) ?? "")
        }
        
        print("stopping")
                
        var pid: Int32 = 0
        
        pid_for_task(req.task.name, &pid)
                
        mach_port_deallocate(mach_task_self_, self.port)
        mach_port_destroy(mach_task_self_, self.port)
        
        kill(pid, 9)
    }
}
