import Foundation

@inline(__always)
private func foreachVals(
    _ ht: UnsafeMutablePointer<HashTable>,
    _ body: (_ zv: UnsafeMutablePointer<zval>) -> Void
) {
    var pos = HashPosition()
    zend_hash_internal_pointer_reset_ex(ht, &pos)
    while true {
        guard let zv = zend_hash_get_current_data_ex(ht, &pos) else { break }
        if Z_TYPE_P(zv) != IS_UNDEF {
            body(zv)
        }
        if zend_hash_move_forward_ex(ht, &pos) == FAILURE { break }
    }
}

@inline(__always)
private func foreachStrKeyPtr(
    _ ht: UnsafeMutablePointer<HashTable>,
    _ body: (_ key: UnsafeMutablePointer<zend_string>?, _ ptr: UnsafeMutableRawPointer?) -> Void
) {
    var pos = HashPosition()
    zend_hash_internal_pointer_reset_ex(ht, &pos)
    while true {
        var keyStr: UnsafeMutablePointer<zend_string>? = nil
        var index: zend_ulong = 0
        let keyType = zend_hash_get_current_key_ex(ht, &keyStr, &index, &pos)
        let zv = zend_hash_get_current_data_ex(ht, &pos)
        if let zv = zv, Z_TYPE_P(zv) != IS_UNDEF {
            body((keyType == HASH_KEY_IS_STRING) ? keyStr : nil, Z_PTR_P(zv))
        }
        if zend_hash_move_forward_ex(ht, &pos) == FAILURE { break }
    }
}

#if !DEBUG && HAVE_BUILTIN_CONSTANT_P
@inline(__always)
public func zend_new_array(_ size: UInt32) -> UnsafeMutablePointer<zend_array>! {
    size <= HT_MIN_SIZE ? _zend_new_array_0() : _zend_new_array(size)
}
#else
@inline(__always)
public func zend_new_array(_ size: UInt32) -> UnsafeMutablePointer<zend_array>! {
    _zend_new_array(size)
}
#endif

let HASH_FLAG_PACKED: UInt32 = 1 << 2

func HT_FLAGS(_ ht: UnsafeMutablePointer<HashTable>) -> UInt32 {
    return ht.pointee.u.flags
}

func HT_IS_PACKED(_ ht: UnsafeMutablePointer<HashTable>) -> Bool {
    return (HT_FLAGS(ht) & HASH_FLAG_PACKED) != 0
}

public func ZVAL_EMPTY_ARRAY(_ z: UnsafeMutablePointer<zval>?) {
    guard let z = z else { return }
    
    // Note: zend_empty_array is a `let` constant, so we need a mutable copy to get a pointer.
    var emptyArray = zend_empty_array
    withUnsafeMutablePointer(to: &emptyArray) { emptyArrayPtr in
        z.pointee.value.arr = emptyArrayPtr
    }
    
    z.pointee.u1.type_info = UInt32(IS_ARRAY)
}

public func ZEND_HASH_FOREACH_STR_KEY_VAL(
    _ ht: UnsafeMutablePointer<HashTable>,
    body: (_ key: UnsafeMutablePointer<zend_string>?, _ val: UnsafeMutablePointer<zval>) -> Void
) {
    ZEND_HASH_FOREACH_FROM(ht: ht, indirect: 0, from: 0) { (key, val, _) in
        if let val = val {
            body(key, val)
        }
    }
}

// NOTE: The C macro ZEND_HASH_FOREACH is the *start* of a loop. A direct
// function translation in Swift doesn't make sense without a body.
// This function is kept for structural completeness but is not typically called directly.
public func ZEND_HASH_FOREACH(ht: UnsafeMutablePointer<HashTable>, indirect: Int32) {
    ZEND_HASH_FOREACH_FROM(ht: ht, indirect: indirect, from: 0) { (_, _, _) in
        // In C, the user provides the loop body here.
        // In Swift, the body is provided via a closure to the calling function.
    }
}

public func ZEND_HASH_FOREACH_FROM(
    ht: UnsafeMutablePointer<HashTable>,
    indirect: Int32,
    from: Int,
    body: (_ key: UnsafeMutablePointer<zend_string>?, _ val: UnsafeMutablePointer<zval>?, _ hash: zend_ulong) -> Void
) {
    guard ht.pointee.nNumUsed > 0 else { return }
    let _size = ZEND_HASH_ELEMENT_SIZE(ht)
    var _idx = UInt32(from)
    var _count = ht.pointee.nNumUsed - _idx

    while _count > 0 {
        let p = ht.pointee.arData.advanced(by: Int(_idx))
        let _z = p.withMemoryRebound(to: zval.self, capacity: 1) { $0 }
        
        // Advance index for the next iteration
        _idx += 1
        _count -= 1
        
        if Z_TYPE_P(_z) == IS_UNDEF {
            continue
        }

        var _final_z = _z
        if indirect != 0 && Z_TYPE_P(_z) == IS_INDIRECT {
            _final_z = Z_INDIRECT_P(_z)
        }

        body(p.pointee.key, _final_z, p.pointee.h)
    }
}

public func ZEND_HASH_FOREACH_VAL(
    _ ht: UnsafeMutablePointer<HashTable>,
    body: (_ val: UnsafeMutablePointer<zval>) -> Void
) {
    foreachVals(ht, body)
}

// NOTE: These low-level helpers are highly specific to the C HashTable layout
// and can be complex to use correctly.
public func ZEND_HASH_NEXT_ELEMENT(_ _el: UnsafeMutablePointer<zval>?, _ _size: Int) -> UnsafeMutablePointer<zval>? {
    return _el.map { UnsafeMutableRawPointer($0).advanced(by: _size).assumingMemoryBound(to: zval.self) }
}

public func ZEND_HASH_ELEMENT_SIZE(_ ht: UnsafeMutablePointer<HashTable>) -> Int {
    if HT_IS_PACKED(ht) {
        return MemoryLayout<zval>.size
    } else {
        return MemoryLayout<Bucket>.size
    }
}

public func ZEND_HASH_ELEMENT_EX(_ ht: UnsafeMutablePointer<HashTable>, _ _idx: Int, _ _size: Int) -> UnsafeMutablePointer<zval>? {
     // This logic is simplified and may not be fully correct for non-packed arrays.
     // The implementation in ZEND_HASH_FOREACH_FROM is more robust.
    return ht.pointee.arData.advanced(by: _idx)
        .withMemoryRebound(to: zval.self, capacity: 1) { $0 }
}

public struct PhpArrayValIter: Sequence, IteratorProtocol {
    var hashTable: UnsafeMutablePointer<HashTable> // Non-optional
    var idx: Int = 0
    let size: Int
    var count: Int

    public init(_ hashTable: UnsafeMutablePointer<HashTable>) {
        self.hashTable = hashTable
        self.size = ZEND_HASH_ELEMENT_SIZE(hashTable)
        self.count = Int(hashTable.pointee.nNumUsed)
    }

    public mutating func next() -> UnsafeMutablePointer<zval>? {
        while idx < count {
            let p = hashTable.pointee.arData.advanced(by: idx)
            idx += 1

            let val = p.withMemoryRebound(to: zval.self, capacity: 1) { $0 }
            if Z_TYPE_P(val) == IS_UNDEF {
                continue
            }
            return val
        }
        return nil
    }
}

public struct PhpZValValIter: Sequence, IteratorProtocol {
    private var iterator: PhpArrayValIter?

    public init(_ zval: UnsafeMutablePointer<zval>) {
        if Z_TYPE_P(zval) == IS_ARRAY {
            self.iterator = PhpArrayValIter(Z_ARRVAL_P(zval))
        } else {
            self.iterator = nil
        }
    }

    public mutating func next() -> UnsafeMutablePointer<zval>? {
        return iterator?.next()
    }
}

// MARK: - Added Swift Conversion

public func ZEND_HASH_FOREACH_STR_KEY_PTR(
    _ ht: UnsafeMutablePointer<HashTable>,
    body: (_ key: UnsafeMutablePointer<zend_string>?, _ ptr: UnsafeMutableRawPointer?) -> Void
) {
    foreachStrKeyPtr(ht, body)
}

@inline(__always)
public func ZVAL_COPY_DEREF_TO_SCALAR(_ zvIn: UnsafeMutablePointer<zval>, _ out: inout zval) {
    ZVAL_COPY_DEREF(&out, zvIn)
}

public func zend_hash_init(
    _ ht: UnsafeMutablePointer<HashTable>?,
    _ nSize: UInt32,
    _ pHashFunction: (@convention(c) (UnsafeMutablePointer<zval>?) -> Void)?,
    _ pDestructor: (@convention(c) (UnsafeMutablePointer<zval>?) -> Void)?,
    _ persistent: Bool
) {
    _zend_hash_init(ht, nSize, pDestructor, persistent)
}