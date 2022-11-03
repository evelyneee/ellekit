//
//  Exception.swift
//  ellekit
//
//  Created by charlotte on 2022-11-03.
//

import Foundation
import Darwin

let ARM_THREAD_STATE64_COUNT = MemoryLayout<arm_thread_state64_t>.size/MemoryLayout<UInt32>.size

public func registerEXCPort() {
    
    var exceptionPort = mach_port_t()
        
    mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &exceptionPort)
    mach_port_insert_right(mach_task_self_, exceptionPort, exceptionPort, mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND))
    
    task_set_exception_ports(mach_task_self_, exception_mask_t(EXC_MASK_BREAKPOINT), exceptionPort, EXCEPTION_DEFAULT, ARM_THREAD_STATE64)
                
    DispatchQueue(label: "exceptionHandler", qos: .userInteractive).async {
        while true {
            let head = UnsafeMutablePointer<mach_msg_header_t>.allocate(capacity: 0x4000)
            
            defer { head.deallocate() }
            
            var ret = mach_msg(head,
                               MACH_RCV_MSG | MACH_RCV_LARGE | Int32(MACH_MSG_TIMEOUT_NONE),
                               0,
                               0x4000,
                               exceptionPort,
                               0, 0)
            guard ret == KERN_SUCCESS else {
                print("[-] error receiving from port:", mach_error_string(ret) ?? "")
                continue
            }
            
            let req = head.withMemoryRebound(to: exception_raise_request.self,
                                             capacity: 0x4000) { $0.pointee }
            
            let thread_port = req.thread.name
            let task_port = req.task.name
                        
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
                mach_port_deallocate(mach_task_self_, thread_port)
                mach_port_deallocate(mach_task_self_, task_port)
                
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
            
            let formerPtr = UnsafeMutableRawPointer(bitPattern: UInt(state.__pc))!
                        
            print(state)
            
            if let newPtr = hooks[formerPtr] {
                print("[+] changed pc to", newPtr)
                state.__pc = UInt64(UInt(bitPattern: newPtr))
            }
                                
            ret = withUnsafeMutablePointer(to: &state, {
                $0.withMemoryRebound(to: UInt32.self, capacity: MemoryLayout<arm_thread_state64>.size, {
                    thread_set_state(thread_port, ARM_THREAD_STATE64, $0, mach_msg_type_number_t(ARM_THREAD_STATE64_COUNT))
                })
            })
            
            thread_resume(thread_port)
                        
            guard ret == KERN_SUCCESS else {
                print("[-] error getting thread state:", mach_error_string(ret) ?? "")
                continue
            }
        }
    }
}
