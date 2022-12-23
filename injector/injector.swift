import Foundation
import os.log

#warning("TODO: C rewrite")

#if os(iOS) || os(tvOS) || os(watchOS)
let path = "/Library/MobileSubstrate/DynamicLibraries/"
#elseif os(macOS)
let path = "/Library/TweakInject/"
#endif

let logger = Logger(subsystem: "red.charlotte.ellekit", category: "injector")

// big wip don't complain!
@_cdecl("injector_entry")
public func entry() {
    logger.notice("[ellekit] injector: out here")
    print("hi stdout c:")
    do {
        try FileManager.default.contentsOfDirectory(atPath: path)
            .filter { $0.suffix(6) == ".dylib" || $0.suffix(6) == ".plist" }
            .compactMap {
                path+$0.components(separatedBy: ".").dropLast().joined(separator: ".") // remove extension
            }
            .removeDuplicates()
            .sorted { $0 < $1 }
            .forEach(openTweak(_:))
    } catch {
        print("got error", error)
    }
}

struct Filter: Codable {
    var Filter: CoreFilter
    struct CoreFilter: Codable {
        var Bundles: [String]
    }
    var UnloadAfter: Bool?
}

func openTweak(_ tweak: String) throws {

    let filterData = try Data(contentsOf: NSURL.fileURL(withPath: tweak+".plist"))
    let filterRoot = try PropertyListDecoder().decode(Filter.self, from: filterData)
    let filter = filterRoot
        .Filter
        .Bundles
        .map { $0.lowercased() }

    if let bundleID = Bundle.main.bundleIdentifier {
        if filter.contains(bundleID.lowercased()) {
            logger.notice("[ellekit] injector: loaded \(tweak+".dylib")")
            let handle = dlopen(tweak + ".dylib", RTLD_NOW)
            if handle == nil {
                logger.notice("[ellekit] injector: Failed to open tweak: \(String(cString: dlerror()))")
            }
            if filterRoot.UnloadAfter == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                    dlclose(handle)
                    dlclose(handle)
                    logger.notice("[ellekit] injector: closed \(tweak+".dylib")")
                })
            }
            return
        }
    }

    if filter.contains("*") {
        logger.notice("[ellekit] injector: loading with wildcard filter: \(tweak+".dylib")")
        let handle = dlopen(tweak + ".dylib", RTLD_NOW)
        if handle == nil {
            logger.notice("[ellekit] injector: Failed to open tweak: \(String(cString: dlerror()))")
        }
        if filterRoot.UnloadAfter == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                dlclose(handle)
                dlclose(handle)
                logger.notice("[ellekit] injector: closed \(tweak+".dylib")")
            })
        }
        return
    }
}

extension Array where Element: Hashable {
    func removeDuplicates() -> Self {
        Array(Set(self))
    }
}
