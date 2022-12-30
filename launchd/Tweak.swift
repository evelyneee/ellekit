//
//  Tweak.swift
//  launchd
//
//  Created by charlotte on 2022-12-20.
//

import Foundation

struct Filter: Codable {
    var Filter: CoreFilter
    struct CoreFilter: Codable {
        var Bundles: [String]
    }
    var UnloadAfter: Bool?
}

class Tweak {
    internal init(tweak: String) throws {
        self.path = tweak+".dylib"
        let filterData = try Data(contentsOf: NSURL.fileURL(withPath: tweak+".plist"))
        let filterRoot = try PropertyListDecoder().decode(Filter.self, from: filterData)
        let filter = filterRoot
            .Filter
            .Bundles
            .map { $0.lowercased() }
        self.bundles = filter
        TextLog.shared.write("\(self.path) : \(self.bundles)")
    }
    
    var path: String
    var bundles: [String]
}

func getTweaksPath() -> String {
    #if os(macOS)
    return "/Library/TweakInject/"
    #else
    if access("/usr/lib/TweakInject/", F_OK) == 0 {
        return "/usr/lib/TweakInject/"
    } else {
        return (("/var/jb/usr/lib/TweakInject/" as NSString).resolvingSymlinksInPath)+"/"
    }
    #endif
}

var tweaks: [Tweak] = []

func loadTweaks() throws {
    let path = getTweaksPath()
    let loaded = try FileManager.default.contentsOfDirectory(atPath: path)
        .filter { $0.suffix(6) == ".dylib" || $0.suffix(6) == ".plist" }
        .compactMap {
            path+$0.components(separatedBy: ".").dropLast().joined(separator: ".") // remove extension
        }
        .removeDuplicates()
        .sorted { $0 < $1 }
    tweaks = loaded.compactMap { try? Tweak.init(tweak: $0) }
}

extension Array where Element: Hashable {
    func removeDuplicates() -> Self {
        Array(Set(self))
    }
}
