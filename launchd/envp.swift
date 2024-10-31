
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

typealias EnvPointer = UnsafePointer<UnsafeMutablePointer<CChar>?>

extension EnvPointer {
    var count: Int {
        var size = 0;
        while (self[size] != nil) {
            size += 1
        }
        return size
    }
    
    var array: [String] {
        var newenv = [String]()

        // Copies the strings from the old array to the new array.
        for i in 0..<self.count {
            if let key = self[i] {
                newenv.append(String(cString: key))
            }
        }
        
        return newenv
    }
}
