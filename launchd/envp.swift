//
//  envp.swift
//  launchd
//
//  Created by charlotte on 2022-12-21.
//

import Foundation

typealias EnvPointer = UnsafePointer<UnsafeMutablePointer<CChar>?>

struct TextLog: TextOutputStream {

    static var shared = TextLog()
    
    var enableLogging = true
    
    func write(_ string: String) {
        guard enableLogging else { return print(string) }
        #if os(iOS)
        let log = NSURL.fileURL(withPath: "/private/var/mobile/log.txt")
        #else
        let log = NSURL.fileURL(withPath: "/Users/charlotte/log.txt")
        #endif
        if let handle = try? FileHandle(forWritingTo: log) {
            handle.seekToEndOfFile()
            handle.write((string+"\n").data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? string.data(using: .utf8)?.write(to: log)
        }
    }
}

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
