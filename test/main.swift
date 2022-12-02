
import Foundation
import ellekit_mac

let atoiptr = dlsym(dlopen(nil, RTLD_NOW), "atoi")!

@_cdecl("rep")
public func rep() -> Int {
    2
}

let repcl: @convention(c) () -> Int = rep

let repptr = unsafeBitCast(repcl, to: UnsafeMutableRawPointer.self)

let test: UnsafeMutableRawPointer? = hook(atoiptr, repptr)!

print(
    atoi("3"),
    unsafeBitCast(test, to: (@convention (c) (UnsafePointer<CChar>) -> Int).self)("4")
)
