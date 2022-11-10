
import Foundation
import os.log

#if os(iOS)
let path = "/Library/MobileSubstrate/DynamicLibraries"
#elseif os(macOS)
let path = (("~/.tweaks/" as NSString).expandingTildeInPath as String)
#endif

// big wip don't complain!
@_cdecl("injector_entry")
func entry() {
    do {
        try FileManager.default.contentsOfDirectory(atPath: path)
            .compactMap {
                $0.components(separatedBy: ".").dropLast().joined(separator: ".") // remove extension
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
    let filter = try PropertyListDecoder().decode(Filter.self, from: filterData).Filter.Bundles
    
    if let bundleID = Bundle.main.bundleIdentifier {
        if filter.contains(bundleID) {
            let handle = dlopen(tweak + ".dylib", RTLD_NOW)
            if handle == nil {
                print("Failed to open tweak:", String(cString: dlerror()))
            }
            return
        }
    } else {
        let handle = dlopen(tweak + ".dylib", RTLD_NOW)
        if handle == nil {
            print("Failed to open tweak:", String(cString: dlerror()))
        }
        return
    }
}

extension Array where Element: Hashable {
    func removeDuplicates() -> Self {
        Array(Set(self))
    }
}
