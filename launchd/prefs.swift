
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

import Foundation

class Preferences {
    
    var suite: UserDefaults
    
    init?() {
        if let suite = UserDefaults(suiteName: "ellekit") {
            self.suite = suite
        } else {
            return nil
        }
    }
    
    var enabled: Bool {
        get {
            suite.bool(forKey: "Enabled")
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
}
