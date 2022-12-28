
import Foundation
import Darwin

var attr: UnsafeMutablePointer<posix_spawnattr_t?> = .allocate(capacity: 64)

posix_spawnattr_init(attr)

@_silgen_name("posix_spawnattr_set_ptrauth_task_port_np")
func posix_spawnattr_set_ptrauth_task_port_np(
    _:UnsafeMutablePointer<posix_spawnattr_t?>,
    _:mach_port_t
)

var port: mach_port_t = 0

let pid_krt = task_for_pid(mach_task_self_, 1, &port)

guard pid_krt == KERN_SUCCESS else {
    print("[-] loader: no task for pid access ?")
    exit(1)
}

print("[*] got task port")

posix_spawnattr_set_ptrauth_task_port_np(attr, port)

print("[*] setting ptrauth task port")

var pid: pid_t = 0

var argv = ["loader"].map { strdup(($0 as NSString).utf8String) }

posix_spawnp(&pid, "loader", nil, attr, &argv, nil)

var status: Int32 = 0

waitpid(pid, &status, WEXITED)
