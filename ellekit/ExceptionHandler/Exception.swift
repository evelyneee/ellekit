
import Foundation
import Darwin

let ARM_THREAD_STATE64_COUNT = MemoryLayout<arm_thread_state64_t>.size/MemoryLayout<UInt32>.size

var closeExceptionPort = false

final class ExceptionHandler {
    
    let port: mach_port_t
    let thread = DispatchQueue(label: "ellekit_exc_port", attributes: .concurrent)
    
    init() {
        var targetPort = mach_port_t()
            
        mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &targetPort)
        mach_port_insert_right(mach_task_self_, targetPort, targetPort, mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND))
        
        task_set_exception_ports(mach_task_self_, exception_mask_t(EXC_MASK_BREAKPOINT), targetPort, EXCEPTION_DEFAULT, ARM_THREAD_STATE64)
        
        self.port = targetPort
        
        startPortLoop()
    }
    
    func startPortLoop() {
        self.thread.async { [weak self] in
            Self.portLoop(self)
        }
    }
    
    static func portLoop(_ `self`: ExceptionHandler?) {
                            
        guard let `self` else {
            return print("[-] ellekit: exception handler deallocated.")
        }
        
        defer { Self.portLoop(self) }
        
        let head = UnsafeMutablePointer<mach_msg_header_t>.allocate(capacity: 0x4000)
        
        defer { head.deallocate() }
        
        var ret = mach_msg(head,
                           MACH_RCV_MSG | MACH_RCV_LARGE | Int32(MACH_MSG_TIMEOUT_NONE),
                           0,
                           0x4000,
                           self.port,
                           0, 0)
        
        guard ret == KERN_SUCCESS else {
            print("[-] error receiving from port:", mach_error_string(ret) ?? "")
            return
        }
                    
        let req = UnsafeMutableRawPointer(head).makeReadable().withMemoryRebound(to: exception_raise_request.self,
                                         capacity: 0x4000) { $0.pointee }
        
        let thread_port = req.thread.name
        
        defer {
            var reply = exception_raise_reply()
            reply.Head.msgh_bits = req.Head.msgh_bits & UInt32(MACH_MSGH_BITS_REMOTE_MASK)
            reply.Head.msgh_size = mach_msg_size_t(MemoryLayout.size(ofValue: reply))
            reply.Head.msgh_remote_port = req.Head.msgh_remote_port
            reply.Head.msgh_local_port = mach_port_t(MACH_PORT_NULL)
            reply.Head.msgh_id = req.Head.msgh_id + 0x64
            
            reply.NDR = req.NDR
            reply.RetCode = KERN_SUCCESS
            
            ret = mach_msg(&reply.Head,
                           1,
                           reply.Head.msgh_size,
                           0,
                           mach_port_name_t(MACH_PORT_NULL),
                           MACH_MSG_TIMEOUT_NONE,
                           mach_port_name_t(MACH_PORT_NULL))
            
            print("[*] Sending reply")
            
            if ret != KERN_SUCCESS {
                print("[-] error sending reply to exception: ", mach_error_string(ret) ?? "")
            }
        }
        
        var state = arm_thread_state64()
        var stateCnt = mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT)
        
        ret = withUnsafeMutablePointer(to: &state) {
            $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<arm_thread_state64>.size) {
                thread_get_state(thread_port, ARM_THREAD_STATE64, $0, &stateCnt)
            }
        }
                    
        #if _ptrauth(_arm64e)
        guard let formerPtr = state.__opaque_pc?.makeReadable() else {
            print("[-] couldn't get ptr from pc reg")
            return
        }
        #else
        guard let formerPtr = UnsafeMutableRawPointer(bitPattern: UInt(state.__pc)) else {
            print("[-] couldn't get ptr from pc reg")
            return
        }
        #endif
                                            
        if let newPtr = hooks[formerPtr] ?? hooks.first?.value {
            
            #if _ptrauth(_arm64e)
            state.__opaque_pc = sign_pc(newPtr)
            state.__x.16 = UInt64(UInt(bitPattern: sign_pc(newPtr)))
            #else
            state.__pc = UInt64(UInt(bitPattern: newPtr))
            state.__x.16 = UInt64(UInt(bitPattern: newPtr))
            #endif
            
            ret = withUnsafeMutablePointer(to: &state, {
                $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<arm_thread_state64>.size, {
                    return thread_set_state(thread_port, ARM_THREAD_STATE64, $0, mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT))
                })
            })
            
        } else {
            fatalError("[-] ellekit: called exc handler with unknown function")
        }
        
        thread_resume(thread_port)
        
        guard ret == KERN_SUCCESS else {
            print("[-] error getting thread state:", mach_error_string(ret) ?? "")
            return
        }
    }

}
