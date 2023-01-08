
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

func getAllThreads() -> [thread_act_t] {
    let act_list: UnsafeMutablePointer<thread_act_array_t?> = .allocate(capacity: 100)
    var count: UInt32 = 0
    task_threads(mach_task_self_, act_list, &count)
    let threadArray = act_list.pointee?.withMemoryRebound(to: thread_act_t.self, capacity: MemoryLayout<thread_act_t>.size * Int(count), { ptr in
        Array(UnsafeMutableBufferPointer(start: ptr, count: Int(count)))
    })
    return threadArray ?? []
}

public func stopAllThreads() {
    var threads = getAllThreads()
    threads.removeAll(where: { $0 == mach_thread_self() })
    threads.forEach { thread_suspend($0) }
}

public func resumeAllThreads() {
    var threads = getAllThreads()
    threads.removeAll(where: { $0 == mach_thread_self() })
    threads.forEach { thread_resume($0) }
}
