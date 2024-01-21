
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation
import ObjectiveC
import UIKit
import os.log

var orig: UnsafeMutableRawPointer? = nil // for SpringBoard applicationDidFinishLaunching
var orig2: UnsafeMutableRawPointer? = nil // for _UIStatusBar layoutSubviews

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

func showSafeModeAlert() {
    let title = "Safe Mode"
    let message = "You've entered Safe Mode. Tweaks will not be injected until you exit Safe Mode.\n\nYou can select Dismiss to safely remove any broken tweaks.\n\nTap the status bar to show this alert again."
    DispatchQueue.main.async(execute: {
        guard let alertWindow = UIApplication.shared.keyWindow else { return }
        
        alertWindow.rootViewController = alertWindow.rootViewController?.top
    
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let exitAction = UIAlertAction(title: "Exit Safe Mode", style: .default, handler: { action in
            try? FileManager.default.removeItem(atPath: "/var/mobile/.eksafemode")
            exit(0)
        })

        let dismissAction = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
        
        alert.addAction(exitAction)
        alert.addAction(dismissAction)
    
        alertWindow.makeKeyAndVisible()
    
        alertWindow.rootViewController?.present(alert, animated: true, completion: nil)
    })
}

@objc class SpringBoard: NSObject {
    @objc func applicationDidFinishLaunching(_ application: UIApplication) {
        let block = unsafeBitCast(orig, to: (@convention (c) (NSObject, Selector, UIApplication) -> Void).self)
        block(self, #selector(UIApplicationDelegate.applicationDidFinishLaunching(_:)), application)
        
        showSafeModeAlert()
    }
}

@objc class SBStatusBarManager: NSObject {
    @objc func handleStatusBarTapWithEvent(_ event: UIEvent) {
        showSafeModeAlert()
    }
}

@objc class _UIStatusBar: UIView {
    @objc func layoutSubviews2() {
        let block = unsafeBitCast(orig2, to: (@convention (c) (NSObject, Selector) -> Void).self)
        block(self, #selector(UIView.layoutSubviews))

        self.backgroundColor = UIColor.systemRed
    }
}

func performHooks() {
    guard let springboard_class = NSClassFromString("SpringBoard") else { return }
    let replacement = class_getMethodImplementation(
        SpringBoard.self,
        #selector(SpringBoard.applicationDidFinishLaunching(_:))
    )!
    messageHook(
        springboard_class, #selector(UIApplicationDelegate.applicationDidFinishLaunching(_:)),
        replacement, &orig
    )

    guard let statusbar_class = NSClassFromString("SBStatusBarManager") else { return }
    let replacement2 = class_getMethodImplementation(
        SBStatusBarManager.self,
        #selector(SBStatusBarManager.handleStatusBarTapWithEvent(_:))
    )!
    messageHook(
        statusbar_class, NSSelectorFromString("handleStatusBarTapWithEvent:"),
        replacement2, nil
    )

    guard let statusbar_class2 = NSClassFromString("_UIStatusBar") else { return }
    let replacement3 = class_getMethodImplementation(
        _UIStatusBar.self,
        #selector(_UIStatusBar.layoutSubviews2)
    )!
    messageHook(
        statusbar_class2, #selector(UIView.layoutSubviews),
        replacement3, &orig2
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
    FileManager.default.createFile(atPath: "/var/mobile/.eksafemode", contents: Data())
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
                
    if FileManager.default.fileExists(atPath: "/var/mobile/.eksafemode") {
        performHooks()
    } else if checkVolumeUp() {
        tprint("Volume up!!!")
        FileManager.default.createFile(atPath: "/var/mobile/.eksafemode", contents: Data())
        exit(0)
    }
        
    trap(signals: allSignals, action: handleSBCrash)
}
