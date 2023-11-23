
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation
import ObjectiveC
import UIKit
import os.log

var orig: UnsafeMutableRawPointer? = nil

// Thanks to Amy While (@elihwyma) for this piece of code
extension UIViewController {
    var top: UIViewController? {
        if let controller = self as? UINavigationController {
            return controller.topViewController?.top
        }
        if let controller = self as? UISplitViewController {
            return controller.viewControllers.last?.top
        }
        if let controller = self as? UITabBarController {
            return controller.selectedViewController?.top
        }
        if let controller = presentedViewController {
            return controller.top
        }
        return self
    }
}

@objc class SpringBoard2: NSObject {
    
    @objc func applicationDidFinishLaunching(_ application: UIApplication) {
        
        let block = unsafeBitCast(orig, to: (@convention (c) (NSObject, Selector, UIApplication) -> Void).self)
        
        block(self, #selector(UIApplicationDelegate.applicationDidFinishLaunching(_:)), application)
        
        let title = "Safe Mode"
        let message = "You've entered safe mode. SpringBoard tweaks will not get injected until you respring your device. You can also safely remove your broken tweaks."
        DispatchQueue.main.async(execute: {
            guard let alertWindow = UIApplication.shared.keyWindow else { return }
            
            alertWindow.rootViewController = alertWindow.rootViewController?.top
        
            let alert2 = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let defaultAction2 = UIAlertAction(title: "OK", style: .default, handler: { action in
                try? FileManager.default.removeItem(atPath: jbroot("/var/mobile/.eksafemode"))
            })
            
            alert2.addAction(defaultAction2)
        
            alertWindow.makeKeyAndVisible()
        
            alertWindow.rootViewController?.present(alert2, animated: true, completion: nil)
        })
        
    }
}

func performHooks() {
    guard let sb = NSClassFromString("SpringBoard") else { return }
    let replacement = class_getMethodImplementation(
        SpringBoard2.self,
        #selector(SpringBoard2.applicationDidFinishLaunching(_:))
    )!
    messageHook(
        sb, #selector(UIApplicationDelegate.applicationDidFinishLaunching(_:)),
        replacement, &orig
    )
}

func trap(signals: [Int32], action: (@convention(c) (Int32) -> Void)?) {
    var signalAction = sigaction()
    signalAction.__sigaction_u.__sa_handler = action

    signals.forEach { sig in
        signal(sig, action)
    }
}

func handleSBCrash(currentSig: Int32) {
    FileManager.default.createFile(atPath: jbroot("/var/mobile/.eksafemode"), contents: Data())
    allSignals.forEach {
        signal($0, SIG_DFL)
    }
    raise(currentSig)
}

let allSignals = [
    SIGQUIT,
    SIGILL,
    SIGTRAP,
    SIGABRT,
    SIGEMT,
    SIGFPE,
    SIGBUS,
    SIGSEGV,
    SIGSYS
]

@_cdecl("tweak_entry")
public func tweak_entry() {
        
    NSLog("Hello world, SpringBoard!")
                
    if FileManager.default.fileExists(atPath: jbroot("/var/mobile/.eksafemode")) {
        performHooks()
    } else if checkVolumeUp() {
        tprint("Volume up!!!")
        FileManager.default.createFile(atPath: jbroot("/var/mobile/.eksafemode"), contents: Data())
        exit(0)
    }
        
    trap(signals: allSignals, action: handleSBCrash)
}
