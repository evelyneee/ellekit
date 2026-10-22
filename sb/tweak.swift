
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

func showSafeModeAlert()
{
    let title = "Safe Mode"
    let message = "You've entered safe mode. SpringBoard tweaks will not get injected until you respring your device. You can select Dismiss to safely remove your broken tweaks."
    DispatchQueue.main.async(execute: {
        NSLog("MobileSafety: async executed")
        guard let alertWindow = UIApplication.shared.keyWindow else { return }
        
        alertWindow.rootViewController = alertWindow.rootViewController?.top
    
        let alert2 = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let defaultAction2 = UIAlertAction(title: "Dismiss", style: .default, handler: { action in
            try? FileManager.default.removeItem(atPath: jbroot("/var/mobile/.eksafemode"))
        })
        
        alert2.addAction(defaultAction2)
        

        let respringAction2 = UIAlertAction(title: "Exit Safe Mode", style: .destructive, handler: { action in
            try? FileManager.default.removeItem(atPath: jbroot("/var/mobile/.eksafemode"))
            exit(0)
        })
        
        alert2.addAction(respringAction2)
    
        alertWindow.makeKeyAndVisible()
    
        alertWindow.rootViewController?.present(alert2, animated: true, completion: nil)
    })
}

func showBrokenPackageAlert()
{
    let title = "Error"
    let message = "Ellekit files are corrupted for unknown reasons. Please try reinstalling the ellekit package."
    DispatchQueue.main.async(execute: {
        NSLog("MobileSafety: async executed")
        guard let alertWindow = UIApplication.shared.keyWindow else { return }
        
        alertWindow.rootViewController = alertWindow.rootViewController?.top
    
        let alert2 = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let defaultAction2 = UIAlertAction(title: "Dismiss", style: .destructive, handler: { action in
            try? FileManager.default.removeItem(atPath: jbroot("/var/mobile/.eksafemode"))
        })
        
        alert2.addAction(defaultAction2)
    
        alertWindow.makeKeyAndVisible()
    
        alertWindow.rootViewController?.present(alert2, animated: true, completion: nil)
    })
}

@objc class SpringBoard2: NSObject {
    
    @objc func applicationDidFinishLaunching(_ application: UIApplication) {
        
        NSLog("MobileSafety: applicationDidFinishLaunching")
        
        let block = unsafeBitCast(orig, to: (@convention (c) (NSObject, Selector, UIApplication) -> Void).self)
        
        block(self, #selector(UIApplicationDelegate.applicationDidFinishLaunching(_:)), application)
        
        
        var isSymbolicLink = false
        if let attributes = try? FileManager.default.attributesOfItem(atPath: jbroot("/Library/MobileSubstrate/DynamicLibraries")) {
            if let fileType = attributes[FileAttributeKey.type] as? FileAttributeType,
               fileType == .typeSymbolicLink {
                isSymbolicLink = true
            }
        }

        if !isSymbolicLink {
            showBrokenPackageAlert();
            return
        }
        
        showSafeModeAlert()
    }
}

func performHooks() {
    NSLog("MobileSafety: performHooks")
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

@_cdecl("tweak_entry")
public func tweak_entry() {
    
    NSLog("MobileSafety: Hello world, SpringBoard!")
                
    if FileManager.default.fileExists(atPath: jbroot("/var/mobile/.eksafemode")) {
        performHooks()
    } else if checkVolumeUp() {
        tprint("Volume up!!!")
        NSLog("MobileSafety: Volume up!!!")
        FileManager.default.createFile(atPath: jbroot("/var/mobile/.eksafemode"), contents: Data())
        exit(0)
    }
        
}
