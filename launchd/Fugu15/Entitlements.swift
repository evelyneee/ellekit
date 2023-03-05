
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

struct Proc {
    
    var address: UInt64
    
    init(_ address: UInt64) {
        self.address = address
        if ((address >> 55) & 1) != 0 {
            self.address = address | 0xFFFFFF8000000000
        }
    }
    
    init?(forPID: pid_t) {
        var foundProc: UInt64? = 0
        try? enumProcs(allproc: allproc, slide: slide, enumerateBlock: { (proc, stop) in
            let pid = try procGetPid(proc: proc)
            if pid == forPID {
                foundProc = proc
                stop = true
            }
        })
        if let foundProc {
            self.address = foundProc
        } else {
            return nil
        }
    }
    
    var task: UInt64 {
        get throws {
            let taskAddr = (self.address + 0x10)
            return try PPLRW.rPtr(taskAddr)
        }
    }
    
    var vm_map: UInt64 {
        get throws {
            let vmMapAddr = (try self.task + 0x28)
            return try PPLRW.rPtr(vmMapAddr)
        }
    }
    
    var pmap: UInt64 {
        get throws {
            let taskAddr = (try self.vm_map + 0x48)
            return try PPLRW.rPtr(taskAddr)
        }
    }
    
    var wx_allowed: Bool {
        get throws {
            try PPLRW.r8(virt: (try self.pmap) + 0xC2) == 1
        }
    }
    
    var pid: pid_t {
        get throws {
            let pidAddr = (self.address + 0x68)
            return try PPLRW.readGeneric(virt: pidAddr)
        }
    }
    
    var name: String {
        get throws {
            let namePtr = self.address + 0x370
            var nameString = ""
            for k in 0...32
            {
                if let read = try? PPLRW.readGeneric(virt: namePtr+UInt64(k), type: UInt8.self) {
                    nameString += String(bytes: [read], encoding: .utf8) ?? ""
                }
            }
            return nameString
        }
    }
    
    private let proc_ro_offset: UInt64 = 0x20
    
    var proc_ro: UInt64 {
        get throws {
            try PPLRW.rPtr(self.address + proc_ro_offset)
        }
    }
    
    private let proc_ro_csflags_offset: UInt64 = 0x1C
    
    var csflags: UInt64 {
        get throws {
            try PPLRW.rPtr(try self.proc_ro + proc_ro_csflags_offset)
        }
    }
    
    func debug() throws {
        _ = PPLRW.w8((try self.pmap) + 0xC2, value: 1) // self.pmap.wx_allowed = 1
        _ = PPLRW.w8((try self.pmap) + 0xC0, value: 0) // self.pmap.cs_enforce = 0
    }
    
    func platformize() throws {
        
        try self.debug()
        let proc_ro_csflags = try self.csflags
        
        tprint("got orig csflags", proc_ro_csflags)
        
        let new_csflags = UInt32((Int32(proc_ro_csflags) | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW | CS_DEBUGGED) & ~(CS_HARD | CS_KILL | CS_RESTRICT | CS_ENFORCEMENT | CS_REQUIRE_LV))
        
        let write_csflags = try PPLRW.w32(self.proc_ro + proc_ro_csflags_offset, value: new_csflags)
        
        tprint("write csflags", write_csflags)
    }
    
    var p_ucred: ucred {
        get throws {
            try ucred(proc: self)
        }
    }
}

struct ucred {
    
    private let ucred_offset: UInt64 = 0x20
    
    init(proc: Proc) throws {
        self.proc = proc
        self.ucred = try PPLRW.rPtr(try proc.proc_ro + ucred_offset)
    }
    
    var proc: Proc
    var ucred: UInt64
    
    private let cr_label_offset: UInt64 = 0x78
    
    var cr_label: UInt64 {
        get throws {
            try PPLRW.rPtr(self.ucred + self.cr_label_offset)
        }
    }
        
    private let entitlements_offset: UInt64 = 0x1F

    var entitlements: UInt64 {
        get throws {
            try PPLRW.rPtr(try self.cr_label + self.entitlements_offset)
        }
    }
}

struct OSEntitlements {
    
    let proc: Proc
    let ucred: ucred
    let address: UInt64
    
    init(ucred: ucred) throws {
        self.proc = ucred.proc
        self.ucred = ucred
        self.address = try ucred.cr_label
    }
}
