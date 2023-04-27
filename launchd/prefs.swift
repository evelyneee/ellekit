
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

class Preferences {
    
    var suite: UserDefaults
    static var shared: Preferences? = .init()
    
    init?() {
        if let suite = UserDefaults(suiteName: "ellekit") {
            self.suite = suite
        } else {
            return nil
        }
    }
    
    var enabled: Bool? {
        get {
            suite.value(forKey: "Enabled") as? Bool
        }
        set(newValue) {
            suite.set(newValue, forKey: "Enabled")
        }
    }
    
    var useKRW: Bool {
        get {
            suite.bool(forKey: "UseKRW")
        }
        set(newValue) {
            suite.set(newValue, forKey: "UseKRW")
        }
    }
    
    var blacklist: [String]? {
        get {
            suite.array(forKey: "Blacklist") as? [String]
        }
        set(newValue) {
            suite.set(newValue, forKey: "Blacklist")
        }
    }
    
    var fastMode: Bool {
        get {
            suite.bool(forKey: "FastMode")
        }
        set(newValue) {
            suite.set(newValue, forKey: "FastMode")
        }
    }
}
