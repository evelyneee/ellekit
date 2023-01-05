
import Foundation

@_silgen_name("IOHIDEventSystemClientCreate")
func IOHIDEventSystemClientCreate(_:CFAllocator?) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventCreateKeyboardEvent")
func IOHIDEventCreateKeyboardEvent(_:CFAllocator?, _:UInt64, _:UInt32, _:UInt32, _:UInt32, _:UInt32) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventGetIntegerValue")
func IOHIDEventGetIntegerValue(_:UnsafeMutableRawPointer!, _:UInt32) -> CFIndex

@_silgen_name("IOHIDEventSystemClientSetMatching")
func IOHIDEventSystemClientSetMatching(_ client: UnsafeMutableRawPointer, _ dict: CFDictionary) -> Void

@_silgen_name("_IOHIDEventSystemClientCopyEventForService")
func _IOHIDEventSystemClientCopyEventForService(_ client: UnsafeMutableRawPointer, _:UnsafeRawPointer?, _:UInt32?, _:UnsafeMutableRawPointer, _:UInt32) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventSystemClientCopyServices")
func IOHIDEventSystemClientCopyServices(_ client: UnsafeMutableRawPointer) -> CFArray?

// reverse engineered from substrate......
func checkVolumeUp() -> Bool {
    let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if let client {
        var valuePtr = 11;
        let value_page = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &valuePtr);
        valuePtr = 1;
        let value = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &valuePtr);
        let dict = ["PrimaryUsagePage" as CFString:value_page,"PrimaryUsage" as CFString:value]
        IOHIDEventSystemClientSetMatching(client, dict as CFDictionary);
        let services = IOHIDEventSystemClientCopyServices(client);
        if let services, ( CFArrayGetCount(services) == 1 ) {
            let ValueAtIndex = CFArrayGetValueAtIndex(services, 0);
            mach_absolute_time();
            let KeyboardEvent = IOHIDEventCreateKeyboardEvent(
                kCFAllocatorDefault,
                mach_absolute_time(),
                0x0c, 0xe9, // volume up
                0,0
            );
            if let KeyboardEvent
            {
                let v9 = _IOHIDEventSystemClientCopyEventForService(client, ValueAtIndex, 3, KeyboardEvent, 0);
                let clicked = IOHIDEventGetIntegerValue(v9, 196610) != 0;
                tprint("got keyboard event result")
                return clicked
            } else {
                tprint("failed to get keyboard event")
            }
        } else {
            tprint("failed to get services")
        }
    } else {
        tprint("failed to init client")
    }
    return true
}
