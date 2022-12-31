//
//  envp.swift
//  launchd
//
//  Created by charlotte on 2022-12-21.
//

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
            if (strstr(self[i], "DYLD_INSERT_LIBRARIES=") == nil), let key = self[i] {
                newenv.append(String(cString: key))
            } else {
                newenv.append("DYLD_NEVER_INSERT_LIBRARIES=null")
            }
        }
        
        return newenv
    }
}
