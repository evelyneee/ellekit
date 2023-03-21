
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation
import os.log

var selfPath: String = "/usr/lib/system/libdyld.dylib"
var sbHookPath: String = "/usr/lib/system/libdyld.dylib"
var injectorPath: String = "/usr/lib/system/libdyld.dylib"

func loadPath() {
    if let path = loadDLaddrPath() {
        selfPath = path
    } else {
        #if os(macOS)
        selfPath = "/Library/TweakInject/pspawn.dylib"
        #else
        if access("/usr/lib/ellekit/pspawn.dylib", F_OK) == 0 {
            selfPath = "/usr/lib/ellekit/pspawn.dylib"
        } else {
            selfPath = (("/var/jb/usr/lib/ellekit/pspawn.dylib" as NSString).resolvingSymlinksInPath)
        }
        #endif
    }
    sbHookPath = selfPath.components(separatedBy: "/").dropLast().joined(separator: "/").appending("/MobileSafety.dylib")
    injectorPath = selfPath.components(separatedBy: "/").dropLast().joined(separator: "/").appending("/libinjector.dylib")
}

func loadDLaddrPath() -> String? {
    var info = Dl_info()
    guard let sym = dlsym(dlopen(nil, RTLD_NOW), "launchd_entry") else { return nil }
    dladdr(sym, &info)
    guard let name = info.dli_fname else { return nil }
    let str = String(cString: name)
    guard access(str, F_OK) == 0 else { return nil }
    tprint("got dladdr path "+str)
    return str
}

struct KRWPlist: Codable {
    var physical_ttep: UInt64
    var allproc: UInt64
    var kernelslide: UInt64
}

func procGetTask(proc: UInt64) throws -> UInt64
{
    if proc == 0 { return 0 }
    let taskAddr = (proc + 0x10)
    return try PPLRW.rPtr(taskAddr)
}

func taskGetVmMap(task: UInt64) throws -> UInt64
{
    if task == 0 { return 0 }
    let vmMapAddr = (task + 0x28)
    return try PPLRW.rPtr(vmMapAddr)
}

func vmMapGetPmap(vmMap: UInt64) throws -> UInt64
{
    if vmMap == 0 { return 0 }
    let pmapAddr = vmMap + 0x48
    tprint("getting pmap", pmapAddr)
    return try PPLRW.rPtr(pmapAddr)
}

func pmapSetWxAllowed(pmap: UInt64, wx_allowed: UInt8) -> Bool
{
    if pmap == 0 { return false }
    let wxAllowedAddr = (pmap + 0xC2)
    tprint("got wx allowed address", wxAllowedAddr)
    return PPLRW.w8(wxAllowedAddr, value: wx_allowed)
}

func pmapSetCSEnforce(pmap: UInt64, cs_enforce: UInt8) -> Bool
{
    if pmap == 0 { return false }
    let csEnforceAddr = (pmap + 0xC0)
    tprint("got cs enforce address", csEnforceAddr)
    return PPLRW.w8(csEnforceAddr, value: cs_enforce)
}

func procSetWxAllowed(proc: UInt64, wx_allowed: UInt8) throws -> Bool {
    let task = try procGetTask(proc: proc)
    let vmMap = try taskGetVmMap(task: task)
    let pmap = try vmMapGetPmap(vmMap:vmMap)
    tprint(task, vmMap, pmap)
    return pmapSetWxAllowed(pmap: pmap, wx_allowed: wx_allowed)
}

func procGetPid(proc: UInt64) throws -> UInt32
{
    if proc == 0 { return 0 }
    let pidAddr = (proc + 0x68)
    return try PPLRW.readGeneric(virt: pidAddr)
}

func procGetName(proc: UInt64) throws -> String
{
    if proc == 0 { return "" }
    let namePtr = proc + 0x370
    var nameString = ""
    for k in 0...32
    {
        if let read = try? PPLRW.readGeneric(virt: namePtr+UInt64(k), type: UInt8.self) {
            nameString += String(bytes: [read], encoding: .utf8) ?? ""
        }
    }
    return nameString
}

// 0x280 is the offset i calculated
// Meridian uses 0x3a6 /shrug
func procGetCSFlags(proc: UInt64) throws -> UInt32 {
    if proc == 0 { return 0 }
    let csflags = proc + 0x290
    return try PPLRW.r32(virt: csflags)
}

func procSetCSFlags(proc: UInt64, newFlags: UInt32) throws -> Bool {
    if proc == 0 { return false }
    let csflags = proc + 0x290
    return PPLRW.w32(csflags, value: newFlags)
}

let proc_ro_offset: UInt64 = 0x20
let proc_ro_csflags_offset: UInt64 = 0x1C

#if os(iOS)

struct JBDMessage {
    static var JBD_MSG_HANDOFF_PPL: UInt64 = 10
    static var JBD_MSG_REBUILD_TRUSTCACHE: UInt64 = 20
    static var JBD_MSG_UNRESTRICT_VNODE: UInt64 = 21
    static var JBD_MSG_PROCESS_BINARY: UInt64 = 22
    static var JBD_MSG_PROC_SET_DEBUGGED: UInt64 = 23
    static var JBD_MSG_UNRESTRICT_AND_SIGCONT: UInt64 = 24
}


var sendJBDMessage: @convention (c) (xpc_object_t) -> xpc_object_t = {
    tprint("INIT: Loading sendJBDMessage")
    let handle = dlopen("/var/jb/basebin/libjailbreak.dylib", RTLD_NOW)
    if handle == nil {
        tprint("couldn't get handle... panic incoming")
        sleep(2)
        fatalError()
    }
    let fn = dlsym(handle, "sendJBDMessage")
    if fn == nil {
        tprint("couldn't get symbol... panic incoming")
        sleep(2)
        fatalError()
    }
    return unsafeBitCast(fn, to: (@convention (c) (xpc_object_t) -> xpc_object_t).self)
}()

func initPPLJBD() {
    let msg = xpc_dictionary_create(nil, nil, 0)
    xpc_dictionary_set_uint64(msg, "id", JBDMessage.JBD_MSG_HANDOFF_PPL)
    let ret = sendJBDMessage(msg)
    tprint("returned:", xpc_dictionary_get_uint64(ret, "success"))
}

var jbdProcSetDebugged: @convention (c) (pid_t) -> UInt64 = {
    tprint("INIT: Loading jbdProcSetDebugged")
    let handle = dlopen("/var/jb/basebin/libjailbreak.dylib", RTLD_NOW)
    if handle == nil {
        tprint("couldn't get handle... panic incoming")
        sleep(2)
        fatalError()
    }
    let fn = dlsym(handle, "jbdProcSetDebugged")
    if fn == nil {
        tprint("couldn't get symbol... panic incoming")
        sleep(2)
        fatalError()
    }
    return unsafeBitCast(fn, to: (@convention (c) (pid_t) -> UInt64).self)
}()

func entitleAndContJBD() {
    let msg = xpc_dictionary_create(nil, nil, 0)
    xpc_dictionary_set_uint64(msg, "id", JBDMessage.JBD_MSG_UNRESTRICT_AND_SIGCONT)
    let ret = sendJBDMessage(msg)
    tprint("returned:", xpc_dictionary_get_uint64(ret, "success"))
    tprint("Entitle and sigcont started")
}
#endif

func platformize(proc: UInt64) throws {
    let proc_ro = try PPLRW.rPtr(proc + proc_ro_offset)
    tprint("got proc_ro", proc_ro)
    let proc_ro_csflags = try PPLRW.r32(virt: proc_ro + proc_ro_csflags_offset)
    tprint("got orig csflags", proc_ro_csflags)
    let new_csflags = UInt32((Int32(proc_ro_csflags) | CS_GET_TASK_ALLOW | CS_DEBUGGED | 0x00000020) & ~(CS_RESTRICT | CS_HARD | CS_KILL))
    tprint("got new csflags", new_csflags)
    let write_csflags = PPLRW.w32(proc_ro + proc_ro_csflags_offset, value: new_csflags)
    tprint("write csflags", write_csflags)
}

func enumProcs(
    allproc: UInt64,
    slide: UInt64,
    enumerateBlock:(_ proc: UInt64, _ stop: inout Bool) throws -> Void
) throws {
    var proc: UInt64 = try PPLRW.readGeneric(virt: allproc + slide)
    while (proc != 0) {

        var stop: Bool = false
        
        print(proc)
        
        try enumerateBlock(proc, &stop)

        if(stop == true) {
            break
        }
        
        proc = try PPLRW.readGeneric(virt: proc)
    }
}

func procForPid(pidToFind: UInt32) throws -> UInt64? {
    var foundProc: UInt64? = 0
     try enumProcs(allproc: allproc, slide: slide, enumerateBlock: { (proc, stop) in
        let pid = try procGetPid(proc: proc)
        if pid == pidToFind {
            foundProc = proc
            stop = true
        }
    })
    return foundProc
}

public var Fugu15: Bool = FileManager.default.fileExists(atPath: "/var/jb/basebin/boot_info.plist")
public var allproc: UInt64 = 0
public var slide: UInt64 = 0

func loadFugu15KRW() throws {
    
    tprint("loading ppl read/write primitives")
    
    let data = try Data(contentsOf: NSURL.fileURL(withPath: "/var/jb/basebin/boot_info.plist"))
    let json = try PropertyListDecoder().decode(KRWPlist.self, from: data)
    
    tprint("got json", json.physical_ttep, json.allproc, json.kernelslide)
    
    tprint("initializing ppl read/write primitives")
    PPLRW.initialize(magicPage: 0x2000000, cpuTTEP: json.physical_ttep)

    tprint("initialized krw")
    
    pspawn.allproc = json.allproc
    pspawn.slide = json.kernelslide
}

let insideLaunchd = ProcessInfo.processInfo.processName.contains("launchd")

func pspawnMain() {
    do {
        #if os(iOS)
        if Fugu15 {
            tprint("calling jbd to have ppl initialized")
//            initPPLJBD()
//            if insideLaunchd {
//                _ = jbdProcSetDebugged(getpid())
//            }
            tprint("should have ppl initialized")
            try loadFugu15KRW()
        }
        #endif
        try loadTweaks()
    } catch {
        tprint("\(error)")
    }
    
    loadPath()
    Rebinds.shared.performHooks()
}

@_cdecl("launchd_entry")
public func entry() {
    tprint("Hello world from", ProcessInfo.processInfo.processName, "running as", getuid())
    if getpid() == 1 {
        DispatchQueue.global().async {
            pspawnMain()
        }
    } else {
        pspawnMain()
    }
}
