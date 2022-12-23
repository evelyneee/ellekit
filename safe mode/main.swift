
import Foundation
import Darwin

@_silgen_name("proc_pidpath")
func proc_pidpath(
    _ pid: pid_t,
    _ string: UnsafeMutablePointer<UInt8>?,
    _ size: UInt32
) -> Int

@_silgen_name("proc_listpids")
func proc_listpids(
    _ type: Int32, _ typeinfo: UInt32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int
) -> Int

func findPID(_ name: String) -> pid_t? {
    let numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, nil, 0)
    var pids = [pid_t](repeating: 0, count: numberOfProcesses)
    _ = pids.withUnsafeMutableBufferPointer { buf in
        proc_listpids(PROC_ALL_PIDS, 0, buf.baseAddress, MemoryLayout<pid_t>.size * buf.count)
    }
    for i in 0..<numberOfProcesses {
        let pathBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))
        defer {
            pathBuffer.deallocate()
        }
        let pathLength = proc_pidpath(pids[i], pathBuffer, UInt32(MAXPATHLEN))
        if pathLength > 0 {
            let path = String(cString: pathBuffer)
            if path.contains(name) {
                return pids[i]
            }
        }
    }
    return nil
}

guard let target = findPID("launchd") else {
    fatalError("Couldn't get SB PID")
}

print(target)

let handler = ExceptionHandler(target)!

dispatchMain()
