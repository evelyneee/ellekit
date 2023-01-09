
// WARNING:
// This code is taken from Accord
// It is therefore licensed under the BSD 4 clause license
// Copyright 2022, Evelyn Belanger

import Foundation
import os.log

private let ENABLE_LINE_LOGGING: Bool = true
private let ENABLE_FILE_EXTENSION_LOGGING: Bool = false

@available(iOS 14.0, tvOS 14.0, watchOS 8.0, macOS 11.0, *)
fileprivate let logger = Logger(subsystem: "red.charlotte.ellekit", category: "all")

public func dprint(
    _ items: Any..., // first variadic parameter
    file: String = #fileID, // file name which is not meant to be specified
    _ items2: Any..., // second variadic parameter
    line: Int = #line, // line number
    separator: String = " "
) {
    let file = ENABLE_FILE_EXTENSION_LOGGING ?
        file.components(separatedBy: "/").last ?? "ElleKit" :
        file.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? "ElleKit"
    let line = ENABLE_LINE_LOGGING ? ":\(String(line))" : ""
    log(items: items, file: file, line: line, separator: separator)
}

private struct TextLog: TextOutputStream {

    static var shared = TextLog()
    
    private var enableLogging: Bool {
        FileManager.default.fileExists(atPath: "/private/var/mobile/.ekenablelogging")
    }
    
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

public func tprint(
    _ items: Any..., // first variadic parameter
    file: String = #fileID, // file name which is not meant to be specified
    _ items2: Any..., // second variadic parameter
    line: Int = #line, // line number
    separator: String = " "
) {
    let file = ENABLE_FILE_EXTENSION_LOGGING ?
        file.components(separatedBy: "/").last ?? "ElleKit" :
        file.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? "ElleKit"
    let line = ENABLE_LINE_LOGGING ? ":\(String(line))" : ""
    var out = String()
    for item in items {
        if type(of: item) is AnyClass {
            out.append(String(reflecting: item))
        } else if let data = item as? Data {
            out.append(String(data: data, encoding: .utf8) ?? String(describing: item))
        } else {
            out.append(String(describing: item))
        }
        out.append(separator)
    }
    TextLog.shared.write("[\(file)\(line)] \(out)")
}

// this is meant to override the print function globally in scope
// the normal signature of the print function is print(_ items: Any...)
// if we wanna override it, we can't use a single variadic parameter because
// there is an error about ambiguous usage
// tldr: very cursed code, do not touch
public func print(
    _ items: Any..., // first variadic parameter
    file: String = #fileID, // file name which is not meant to be specified
    _ items2: Any..., // second variadic parameter
    line: Int = #line, // line number
    separator: String = " "
) {
    let file = ENABLE_FILE_EXTENSION_LOGGING ?
        file.components(separatedBy: "/").last ?? "ElleKit" :
        file.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? "ElleKit"
    let line = ENABLE_LINE_LOGGING ? ":\(String(line))" : ""
    log(items: items, file: file, line: line, separator: separator)
}

// this function exists to override the print function
// when there is only one item to print
// since the other function uses two variadic parameters it doesn't work
// when there is one element
public func print(
    _ item: Any,
    file: String = #fileID,
    line: Int = #line
) {
    let file = ENABLE_FILE_EXTENSION_LOGGING ?
        file.components(separatedBy: "/").last ?? "ElleKit" :
        file.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? "ElleKit"
    let line = ENABLE_LINE_LOGGING ? ":\(String(line))" : ""
    log(items: [item], file: file, line: line)
}

private func log<T>(items: [T], file: String, line: String? = nil, separator: String = " ") {
    var out = String()
    for item in items {
        if type(of: item) is AnyClass {
            out.append(String(reflecting: item))
        } else if let data = item as? Data {
            out.append(String(data: data, encoding: .utf8) ?? String(describing: item))
        } else {
            out.append(String(describing: item))
        }
        out.append(separator)
    }
    if #available(iOS 14.0, tvOS 14.0, watchOS 8.0, macOS 11.0, *) {
        logger.log("[\(file)\(line ?? "")] \(out)")
    }
}
