
import Foundation

extension UnsafeMutableRawPointer {
    func makeCallable() -> Self {
        #if __arm64e__
        let signed = ptrauth_sign_unauthenticated(ptrauth_strip(self, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0)
        print("[+] ellekit: signing pointer", signed)
        return signed
        #else
        self
        #endif
    }
    
    func makeReadable() -> Self {
        #if __arm64e__
        print("[+] ellekit: stripping pointer", self)
        ptrauth_strip(self, ptrauth_key_function_pointer)
        #else
        self
        #endif
    }
}
