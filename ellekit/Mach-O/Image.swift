
import Foundation

public func openImage(image path: String) throws -> UnsafePointer<mach_header>? {
    
    let index = (0..<_dyld_image_count())
        .filter {
            String(cString: _dyld_get_image_name($0))
                .contains(path)
        }
        .first
    
    if let index {
        return _dyld_get_image_header(index)
    } else {
        if #available(iOS 14.0, tvOS 14.0, watchOS 8.0, macOS 11.0, *) {
            if _dyld_shared_cache_contains_path(path) { // special handling soon maybe
                print("[i] ellekit: image is in the shared cache")
            } else {
                dlopen(path, RTLD_NOW | RTLD_LOCAL)
            }
        } else {
            dlopen(path, RTLD_NOW | RTLD_LOCAL)
        }
        
        let index = (0..<_dyld_image_count())
            .filter {
                String(cString: _dyld_get_image_name($0))
                    .contains(path)
            }
            .first
        
        if let index {
            return _dyld_get_image_header(index)
        } else {
            return nil
        }
    }
}
