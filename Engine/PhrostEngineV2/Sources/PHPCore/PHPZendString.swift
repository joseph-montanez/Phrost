import Foundation

@preconcurrency import CSwiftPHP

public func ZSTR_IS_INTERNED(_ s: UnsafeMutablePointer<zend_string>) -> Bool {
    return (GC_FLAGS(UnsafeMutablePointer(OpaquePointer(s))) & UInt32(IS_STR_INTERNED)) != 0
}

public func ZVAL_STRINGL(_ z: UnsafeMutablePointer<zval>, _ s: UnsafePointer<CChar>, _ l: Int) {
    let zendStr = zend_string_init(s, l, false)
    ZVAL_NEW_STR(z, zendStr!)
}

public func ZVAL_STRING(_ z: UnsafeMutablePointer<zval>, _ s: UnsafePointer<CChar>) {
    let len = strlen(s)
    ZVAL_STRINGL(z, s, Int(len))
}

public func RETURN_STR(_ s: UnsafeMutablePointer<zend_string>, _ return_value: UnsafeMutablePointer<zval>) {
    RETVAL_STR(s, return_value)
}

public func ZSTR_CHAR(_ c: UInt8) -> UnsafeMutablePointer<zend_string>? {
    return withUnsafePointer(to: &zend_one_char_string) { tuplePtr in
        let elementPtr = UnsafeRawPointer(tuplePtr).assumingMemoryBound(to: UnsafeMutablePointer<zend_string>?.self)
        return elementPtr.advanced(by: Int(c)).pointee
    }
}

public func ZSTR_KNOWN(_ idx: Int) -> UnsafeMutablePointer<zend_string>? {
    guard let knownStrings = zend_known_strings else { return nil }
    return knownStrings.advanced(by: idx).pointee
}

public func ZSTR_EMPTY_ALLOC() -> UnsafeMutablePointer<zend_string> {
    return zend_empty_string
}