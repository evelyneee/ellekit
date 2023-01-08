
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

@_silgen_name("IOHIDEventSystemClientCreate")
func IOHIDEventSystemClientCreate(_:CFAllocator?) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventSystemCreate")
func IOHIDEventSystemCreate(_:CFAllocator?) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventCreateKeyboardEvent")
func IOHIDEventCreateKeyboardEvent(
    _:CFAllocator?,
    _:UInt64,
    _:UInt32,
    _:UInt32,
    _:Bool,
    _:UInt32
) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventGetIntegerValue")
func IOHIDEventGetIntegerValue(_:UnsafeMutableRawPointer!, _:UInt32) -> CFIndex

@_silgen_name("IOHIDEventSystemClientSetMatching")
func IOHIDEventSystemClientSetMatching(_ client: UnsafeMutableRawPointer, _ dict: CFDictionary) -> Void

@_silgen_name("_IOHIDEventSystemClientCopyEventForService")
func _IOHIDEventSystemClientCopyEventForService(
    _ client: UnsafeMutableRawPointer,
    _:UnsafeRawPointer?,
    _:UInt32?,
    _:UnsafeMutableRawPointer,
    _:UInt32
) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventSystemClientCopyServices")
func IOHIDEventSystemClientCopyServices(_ client: UnsafeMutableRawPointer) -> CFArray?

@_silgen_name("IOHIDEventSystemOpen")
func IOHIDEventSystemOpen(
    _:UnsafeMutableRawPointer!,
    _:UInt32,
    _:UInt32,
    _:UInt32,
    _:UInt32
)

@_silgen_name("IOHIDEventSystemCopyMatchingServices")
func IOHIDEventSystemCopyMatchingServices(
    _ client: UnsafeMutableRawPointer,
    _ dict: CFDictionary,
    _:UInt32,_:UInt32,_:UInt32
) -> CFArray?

@_silgen_name("IOHIDEventSystemCopyEvent")
func IOHIDEventSystemCopyEvent(
    _:UnsafeMutableRawPointer!,
    _:UInt32,
    _:UnsafeMutableRawPointer!,
    _:UInt32
) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventSystemCopyServices")
func IOHIDEventSystemCopyServices(_ client: UnsafeMutableRawPointer, _ dict: CFDictionary) -> CFArray?

var sharedClient: UnsafeMutableRawPointer? = nil

func alternativeButtonCheck() -> Bool {
    
    guard let client = IOHIDEventSystemCreate(nil) else {
        tprint("couldn't get client")
        return false
    }
        
    sleep(1)
    
    IOHIDEventSystemOpen(nil, 0, 0, 0, 0)
    
    #warning("TODO: remove sleep call")
        
    let keyboardEvent = IOHIDEventCreateKeyboardEvent(
        kCFAllocatorDefault,
        mach_absolute_time(),
        0x0c, 0xe9,
        false, 0
    );
    
    if let keyboardEvent {
        let v9 = IOHIDEventSystemCopyEvent(client, 3, keyboardEvent, 0);
        if let v9 {
            return IOHIDEventGetIntegerValue(v9, 0x30002) != 0;
        } else {
            tprint("couldn't get system event")
      }
    } else {
        tprint("couldn't get kb event")
    }
    tprint("couldn't use alternative....... wtf")
    return false
  }
/*

// reverse engineered from substrate......
func checkVolumeUp() -> Bool {
    if sharedClient == nil {
        sharedClient = IOHIDEventSystemCreate(kCFAllocatorDefault);
        sleep(1)
        if let sharedClient {
            var valuePtr = 11;
            let value_page = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &valuePtr);
            valuePtr = 1;
            let value = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &valuePtr);
            let dict = ["PrimaryUsagePage" as CFString:value_page,"PrimaryUsage" as CFString:value]
            IOHIDEventSystemClientSetMatching(sharedClient, dict as CFDictionary);
        }
    }
    if let sharedClient {
        let services = IOHIDEventSystemClientCopyServices(sharedClient);
        if let services {
            tprint("got services \(services as Array)")
            guard CFArrayGetCount(services) >= 1 else {
                tprint("no services outputted")
                return false
            }
            
            let ValueAtIndex = CFArrayGetValueAtIndex(services, 0);
            
            let KeyboardEvent = IOHIDEventCreateKeyboardEvent(
                kCFAllocatorDefault,
                mach_absolute_time(),
                0x0c, 0xe9, // volume up
                false, 0x0
            )
            if let KeyboardEvent
            {
                let v9 = _IOHIDEventSystemClientCopyEventForService(
                    sharedClient,
                    ValueAtIndex,
                    3, // keyboard event
                    KeyboardEvent,
                    0
                );
                tprint("successfully got event")
                let clicked = IOHIDEventGetIntegerValue(
                    v9,
                    0x30002 // keyboard down event
                ) != 0;
                tprint("successfully got event state \(clicked)")
                return clicked
            }
        } else {
            tprint("couldn't get services")
        }
    }
    tprint("trying alternative")
    return alternativeButtonCheck()
}

*/

func checkVolumeUp() -> Bool {
    // Create and open an event system.
    guard let system = IOHIDEventSystemCreate(nil) else {
        tprint("failed to get system")
        return false
    }
    
    tprint("got system")

    // Set the PrimaryUsagePage and PrimaryUsage for the Ambient Light Sensor Service
    let page = 11 as CFNumber
    let usage = 1 as CFNumber
    
    let dict = [
        "PrimaryUsagePage" as CFString : page,
        "PrimaryUsage" as CFString : usage
    ] as CFDictionary
  
    // Get all services matching the above criteria
    let services = IOHIDEventSystemCopyServices(system, dict)
  
    guard let services, CFArrayGetCount(services) >= 1 else {
        tprint("failed to get services")
        return false
    }
    
    tprint("got services")
    
    // Get the service
    let service = CFArrayGetValueAtIndex(services, 0);

    IOHIDEventSystemOpen(system, 0, 0, 0, 0);
    
    tprint("opened system")
    
    let KeyboardEvent = IOHIDEventCreateKeyboardEvent(
        kCFAllocatorDefault,
        mach_absolute_time(),
        0x0c, 0xe9, // volume up
        false, 0x0
    )
    if let KeyboardEvent {
        let v9 = _IOHIDEventSystemClientCopyEventForService(
            system,
            service,
            3, // keyboard event
            KeyboardEvent,
            0
        );
        tprint("got system event")
        let clicked = IOHIDEventGetIntegerValue(
            v9,
            0x30002 // keyboard down event
        ) != 0;
        tprint("successfully got event state \(clicked)")
        return clicked
    }
    
    return false
}
