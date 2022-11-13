
import Foundation
import os.log
import AppKit

#warning("TODO: C rewrite")

#if os(iOS)
let path = "/Library/MobileSubstrate/DynamicLibraries"
#elseif os(macOS)
let path = (("~/.tweaks/" as NSString).expandingTildeInPath as String)
#endif

let logger = Logger(subsystem: "red.charlotte.ellekit", category: "injector")

// big wip don't complain!
@_cdecl("injector_entry")
public func entry() {
    logger.notice("[ellekit] injector: out here")
    do {
        try FileManager.default.contentsOfDirectory(atPath: path)
            .filter { $0.suffix(6) == ".dylib" || $0.suffix(6) == ".plist" }
            .compactMap {
                path+"/"+$0.components(separatedBy: ".").dropLast().joined(separator: ".") // remove extension
            }
            .removeDuplicates()
            .sorted { $0 < $1 }
            .forEach(openTweak(_:))
        
    } catch {
        print("got error", error)
    }
}

class Filter: Codable {
    var Filter: CoreFilter
    class CoreFilter: Codable {
        var Bundles: [String]
    }
}

func openTweak(_ tweak: String) throws {
    
    let filterData = try Data(contentsOf: NSURL.fileURL(withPath: tweak+".plist"))
    let filter = try PropertyListDecoder().decode(Filter.self, from: filterData)
        .Filter
        .Bundles
        .map { $0.lowercased() }
        
    if let bundleID = Bundle.main.bundleIdentifier {
        if filter.contains(bundleID.lowercased()) {
            logger.notice("[ellekit] injector: \(tweak+".dylib")")
            let handle = dlopen(tweak + ".dylib", RTLD_NOW)
            if handle == nil {
                logger.notice("[ellekit] injector: Failed to open tweak: \(String(cString: dlerror()))")
            }
            return
        }
    }
}

extension Array where Element: Hashable {
    func removeDuplicates() -> Self {
        Array(Set(self))
    }
}
