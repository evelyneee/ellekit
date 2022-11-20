
import Foundation

public func hook(
    _ target: UnsafeMutableRawPointer,
    _ replacement: UnsafeMutableRawPointer,
    in image: String
) -> UnsafeMutableRawPointer? {
    if let slide = slide(for: image) {
        let target = target.advanced(by: slide)
        return hook(target, replacement)
    }
    return hook(target, replacement)
}

public func slide(`for` target: String) -> Int? {
    for idx in 0..<_dyld_image_count() {
        if let name = _dyld_get_image_name(idx) {
            let name = String(cString: name)
            if name.contains(target) {
                return _dyld_get_image_vmaddr_slide(idx)
            }
        }
    }
    return nil
}
