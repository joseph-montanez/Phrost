import Foundation


public let MAY_BE_BOOL: UInt32 = UInt32(MAY_BE_FALSE | MAY_BE_TRUE)
public let MAY_BE_ANY: UInt32 = UInt32(MAY_BE_NULL | MAY_BE_FALSE | MAY_BE_TRUE | MAY_BE_LONG | MAY_BE_DOUBLE | MAY_BE_STRING | MAY_BE_ARRAY | MAY_BE_OBJECT | MAY_BE_RESOURCE)

public let IS_STRING_EX: Int32 = (IS_STRING) | (IS_TYPE_REFCOUNTED << Z_TYPE_FLAGS_SHIFT)
public let IS_ARRAY_EX: Int32 = (IS_ARRAY) | (IS_TYPE_REFCOUNTED << Z_TYPE_FLAGS_SHIFT) | (IS_TYPE_COLLECTABLE << Z_TYPE_FLAGS_SHIFT)
public let IS_OBJECT_EX: Int32 = (IS_OBJECT) | (IS_TYPE_REFCOUNTED << Z_TYPE_FLAGS_SHIFT) | (IS_TYPE_COLLECTABLE << Z_TYPE_FLAGS_SHIFT)
public let IS_RESOURCE_EX: Int32 = (IS_RESOURCE) | (IS_TYPE_REFCOUNTED << Z_TYPE_FLAGS_SHIFT)
public let IS_REFERENCE_EX: Int32 = (IS_REFERENCE) | (IS_TYPE_REFCOUNTED << Z_TYPE_FLAGS_SHIFT)
public let IS_CONSTANT_AST_EX: Int32 = (IS_CONSTANT_AST) | (IS_TYPE_REFCOUNTED << Z_TYPE_FLAGS_SHIFT)

// Assuming GC_FLAGS_SHIFT and GC_NOT_COLLECTABLE are defined constants:
public let GC_FLAGS_SHIFT: Int32 = 8 // Example value, adjust according to actual definition
public let GC_NOT_COLLECTABLE: Int32 = 1 // Example value, adjust according to actual definition

// Define the GC_NULL constant
public let GC_NULL: Int32 = IS_NULL | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT)

// Define the GC_STRING constant
public let GC_STRING: Int32 = IS_STRING | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT)

// Define the GC_ARRAY constant
public let GC_ARRAY: Int32 = IS_ARRAY

// Define the GC_OBJECT constant
public let GC_OBJECT: Int32 = IS_OBJECT

// Define the GC_RESOURCE constant
public let GC_RESOURCE: Int32 = IS_RESOURCE | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT)

// Define the GC_REFERENCE constant
public let GC_REFERENCE: Int32 = IS_REFERENCE | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT)

// Define the GC_CONSTANT_AST constant
public let GC_CONSTANT_AST: Int32 = IS_CONSTANT_AST | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT)

public func Z_TYPE_INFO_P_SET(_ z: UnsafeMutablePointer<zval>, _ type: Int32) {
    z.pointee.u1.type_info = UInt32(type)
}

public func Z_LVAL_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ l: Int64) {
    zval_p.pointee.value.lval = l
}

// ZVAL_UNDEF macro
public func ZVAL_UNDEF(_ z: UnsafeMutablePointer<zval>) {
    Z_TYPE_INFO_P_SET(z, IS_UNDEF)
}

// ZVAL_NULL macro
public func ZVAL_NULL(_ z: UnsafeMutablePointer<zval>) {
    Z_TYPE_INFO_P_SET(z, IS_NULL)
}

// ZVAL_FALSE macro
public func ZVAL_FALSE(_ z: UnsafeMutablePointer<zval>) {
    Z_TYPE_INFO_P_SET(z, IS_FALSE)
}

// ZVAL_TRUE macro
public func ZVAL_TRUE(_ z: UnsafeMutablePointer<zval>) {
    Z_TYPE_INFO_P_SET(z, IS_TRUE)
}

// ZVAL_BOOL macro
public func ZVAL_BOOL(_ z: UnsafeMutablePointer<zval>, _ b: Bool) {
    Z_TYPE_INFO_P_SET(z, b ? IS_TRUE : IS_FALSE)
}

// ZVAL_LONG macro
public func ZVAL_LONG(_ z: UnsafeMutablePointer<zval>, _ l: Int64) {
    Z_LVAL_P_SET(z, l)
    Z_TYPE_INFO_P_SET(z, IS_LONG)
}

// ZVAL_DOUBLE macro
public func ZVAL_DOUBLE(_ z: UnsafeMutablePointer<zval>, _ d: Double) {
    Z_DVAL_P_SET(z, d)
    Z_TYPE_INFO_P_SET(z, IS_DOUBLE)
}

// ZVAL_STR macro
public func ZVAL_STR(_ z: UnsafeMutablePointer<zval>, _ s: UnsafeMutablePointer<zend_string>) {
    Z_STR_P_SET(z, s)
    Z_TYPE_INFO_P_SET(z, ZSTR_IS_INTERNED(s) ? IS_INTERNED_STRING_EX : IS_STRING_EX)
}

// ZVAL_INTERNED_STR macro
public func ZVAL_INTERNED_STR(_ z: UnsafeMutablePointer<zval>, _ s: UnsafeMutablePointer<zend_string>) {
    Z_STR_P_SET(z, s)
    Z_TYPE_INFO_P_SET(z, IS_INTERNED_STRING_EX)
}

// ZVAL_NEW_STR macro
public func ZVAL_NEW_STR(_ z: UnsafeMutablePointer<zval>, _ s: UnsafeMutablePointer<zend_string>) {
    Z_STR_P_SET(z, s)
    Z_TYPE_INFO_P_SET(z, IS_STRING_EX)
}

// ZVAL_STR_COPY macro
public func ZVAL_STR_COPY(_ z: UnsafeMutablePointer<zval>, _ s: UnsafeMutablePointer<zend_string>) {
    Z_STR_P_SET(z, s)
    if ZSTR_IS_INTERNED(s) {
        Z_TYPE_INFO_P_SET(z, IS_INTERNED_STRING_EX)
    } else {
        _ = GC_ADDREF(UnsafeMutablePointer<zend_refcounted>(OpaquePointer(s)))
        Z_TYPE_INFO_P_SET(z, IS_STRING_EX)
    }
}

// ZVAL_ARR macro
public func ZVAL_ARR(_ z: UnsafeMutablePointer<zval>, _ a: UnsafeMutablePointer<zend_array>) {
    Z_ARR_P_SET(z, a)
    Z_TYPE_INFO_P_SET(z, IS_ARRAY_EX)
}

// ZVAL_NEW_PERSISTENT_ARR macro
public func ZVAL_NEW_PERSISTENT_ARR(_ z: UnsafeMutablePointer<zval>) {
    let arr = UnsafeMutablePointer<zend_array>.allocate(capacity: 1)
    Z_ARR_P_SET(z, arr)
    Z_TYPE_INFO_P_SET(z, IS_ARRAY_EX)
}

// ZVAL_OBJ macro
public func ZVAL_OBJ(_ z: UnsafeMutablePointer<zval>, _ o: UnsafeMutablePointer<zend_object>) {
    Z_OBJ_P_SET(z, o)
    Z_TYPE_INFO_P_SET(z, IS_OBJECT_EX)
}

// ZVAL_OBJ_COPY macro
public func ZVAL_OBJ_COPY(_ z: UnsafeMutablePointer<zval>, _ o: UnsafeMutablePointer<zend_object>) {
    _ = GC_ADDREF(UnsafeMutablePointer<zend_refcounted>(OpaquePointer(o)))
    Z_OBJ_P_SET(z, o)
    Z_TYPE_INFO_P_SET(z, IS_OBJECT_EX)
}

// ZVAL_RES macro
public func ZVAL_RES(_ z: UnsafeMutablePointer<zval>, _ r: UnsafeMutablePointer<zend_resource>) {
    Z_RES_P_SET(z, r)
    Z_TYPE_INFO_P_SET(z, IS_RESOURCE_EX)
}

// ZVAL_NEW_RES macro
public func ZVAL_NEW_RES(_ z: UnsafeMutablePointer<zval>, _ h: zend_long, _ p: UnsafeMutableRawPointer, _ t: Int32) {
    let res = UnsafeMutablePointer<zend_resource>.allocate(capacity: 1) // Allocate for zend_resource
    GC_SET_REFCOUNT(UnsafeMutablePointer(OpaquePointer(res)), 1) // Set reference count on the zend_refcounted portion
    GC_TYPE_INFO_SET(UnsafeMutablePointer(OpaquePointer(res)), UInt32(GC_RESOURCE)) // Set the type info
    
    res.pointee.handle = h // Set the handle in zend_resource
    res.pointee.type = t    // Set the type in zend_resource
    res.pointee.ptr = p     // Set the pointer in zend_resource
    
    Z_RES_P_SET(z, res) // Set the resource in the zval
    Z_TYPE_INFO_P_SET(z, IS_RESOURCE_EX) // Set the type info in the zval
}

// ZVAL_REF macro
public func ZVAL_REF(_ z: UnsafeMutablePointer<zval>, _ r: UnsafeMutablePointer<zend_reference>) {
    Z_REF_P_SET(z, r)
    Z_TYPE_INFO_P_SET(z, IS_REFERENCE_EX)
}

// ZVAL_NEW_EMPTY_REF macro
public func ZVAL_NEW_EMPTY_REF(_ z: UnsafeMutablePointer<zval>) {
    let ref = UnsafeMutablePointer<zend_reference>.allocate(capacity: 1) // Allocate zend_reference
    GC_SET_REFCOUNT(UnsafeMutablePointer(OpaquePointer(ref)), 1) // Set reference count for zend_reference
    GC_TYPE_INFO_SET(UnsafeMutablePointer(OpaquePointer(ref)), UInt32(GC_REFERENCE)) // Set type info as GC_REFERENCE
    ref.pointee.sources.ptr = nil // Initialize sources pointer to nil
    Z_REF_P_SET(z, ref) // Set reference in zval
    Z_TYPE_INFO_P_SET(z, IS_REFERENCE_EX) // Set type info in zval
}

// ZVAL_AST macro
public func ZVAL_AST(_ z: UnsafeMutablePointer<zval>, _ ast: UnsafeMutablePointer<zend_ast>) {
    Z_AST_P_SET(z, ast)
    Z_TYPE_INFO_P_SET(z, IS_CONSTANT_AST_EX)
}

public func ZVAL_INDIRECT(_ z: UnsafeMutablePointer<zval>, _ v: UnsafeMutablePointer<zval>) {
    Z_INDIRECT_P_SET(z, v)
    Z_TYPE_INFO_P_SET(z, IS_INDIRECT)
}

public func ZVAL_PTR(_ z: UnsafeMutablePointer<zval>, _ p: UnsafeMutableRawPointer) {
    Z_PTR_P_SET(z, p)
    Z_TYPE_INFO_P_SET(z, IS_PTR)
}

public func ZVAL_ERROR(_ z: UnsafeMutablePointer<zval>) {
    Z_TYPE_INFO_P_SET(z, _IS_ERROR)
}

public func Z_ADDREF_P(_ pz: UnsafeMutablePointer<zval>?) -> UInt32 {
    guard let pz = pz else {
        return 0
    }
    
    return zval_addref_p(pz)
}

public func ZVAL_COPY_VALUE_EX(
    _ z: UnsafeMutablePointer<zval>,
    _ v: UnsafePointer<zval>,
    _ gc: UnsafeMutablePointer<zend_refcounted>?,
    _ t: UInt32
) {
    #if arch(x86_64) || arch(arm64) || arch(powerpc64) || arch(powerpc64le) || arch(s390x) || arch(riscv64)
    z.pointee.value.counted = gc
    z.pointee.u1.type_info = t
    #else
    let w2 = v.pointee.value.ww.w2
    z.pointee.value.counted = gc
    z.pointee.value.ww.w2 = w2
    z.pointee.u1.type_info = t
    #endif
}

public func ZVAL_COPY_VALUE(_ z: UnsafeMutablePointer<zval>?, _ v: UnsafePointer<zval>?) {
    guard let z = z, let v = v else { return }
    
    let gc = v.pointee.value.counted
    
    let typeInfo = v.pointee.u1.type_info
    
    ZVAL_COPY_VALUE_EX(z, v, gc, typeInfo)
}

public func ZVAL_COPY(_ z: UnsafeMutablePointer<zval>?, _ v: UnsafePointer<zval>?) {
    guard let z = z, let v = v else { return }

    let gc = v.pointee.value.counted
    let typeInfo = v.pointee.u1.type_info
    
    ZVAL_COPY_VALUE_EX(z, v, gc, typeInfo)

    if Z_TYPE_INFO_REFCOUNTED(typeInfo) {
        guard let gc = gc else { return }
        _ = GC_ADDREF(gc)
    }
}

public func ZVAL_DUP(_ z: UnsafeMutablePointer<zval>?, _ v: UnsafePointer<zval>?) {
    guard let z = z, let v = v else { return }

    let gc = v.pointee.value.counted
    let typeInfo = v.pointee.u1.type_info

    if (typeInfo & UInt32(Z_TYPE_MASK)) == IS_ARRAY {
        guard let gc = gc else { return }
        let arrayPtr = UnsafeMutableRawPointer(gc).assumingMemoryBound(to: zend_array.self)
        ZVAL_ARR(z, zend_array_dup(arrayPtr))
    } else {
        // It's not an array: perform a standard shallow copy.
        ZVAL_COPY_VALUE_EX(z, v, gc, typeInfo)
        if Z_TYPE_INFO_REFCOUNTED(typeInfo) {
            guard let gc = gc else { return }
            _ = GC_ADDREF(gc)
        }
    }
}

public func SEPARATE_ARRAY(_ zv: UnsafeMutablePointer<zval>?) {
    guard let zv = zv else { return }

    let originalArray = Z_ARR_P(zv)
    
    let refcountedArray = UnsafeMutableRawPointer(originalArray)
                              .assumingMemoryBound(to: zend_refcounted.self)

    if GC_REFCOUNT(refcountedArray) > 1 {
        guard let newArray = zend_array_dup(originalArray) else { return }
        ZVAL_ARR(zv, newArray)
        GC_TRY_DELREF(UnsafeMutableRawPointer(originalArray).assumingMemoryBound(to: zend_refcounted_h.self))
    }
}

public func SEPARATE_ZVAL_NOREF(_ zv: UnsafeMutablePointer<zval>?) {
    guard let zv = zv else { return }

    assert(Z_TYPE_P(zv) != IS_REFERENCE, "zval should not be a reference.")

    if Z_TYPE_P(zv) == IS_ARRAY {
        SEPARATE_ARRAY(zv)
    }
}

// GC_REFCOUNT
public func GC_REFCOUNT(_ p: UnsafeMutablePointer<zend_refcounted>) -> UInt32 {
    return p.pointee.gc.refcount
}

// GC_SET_REFCOUNT
public func GC_SET_REFCOUNT(_ p: UnsafeMutablePointer<zend_refcounted>, _ rc: UInt32) {
    p.pointee.gc.refcount = rc
}

// GC_ADDREF
public func GC_ADDREF(_ p: UnsafeMutablePointer<zend_refcounted>) -> UInt32 {
    return withUnsafeMutablePointer(to: &p.pointee.gc) { gcPtr in
        return zend_gc_addref(gcPtr)
    }
}

// GC_DELREF
public func GC_DELREF(_ p: UnsafeMutablePointer<zend_refcounted>) -> UInt32 {
    return withUnsafeMutablePointer(to: &p.pointee.gc) { gcPtr in
        return zend_gc_delref(gcPtr)
    }
}

// GC_ADDREF_EX
public func GC_ADDREF_EX(_ p: UnsafeMutablePointer<zend_refcounted>, _ rc: UInt32) -> UInt32 {
    return withUnsafeMutablePointer(to: &p.pointee.gc) { gcPtr in
        return zend_gc_addref_ex(gcPtr, rc)
    }
}

// GC_DELREF_EX
public func GC_DELREF_EX(_ p: UnsafeMutablePointer<zend_refcounted>, _ rc: UInt32) -> UInt32 {
    return withUnsafeMutablePointer(to: &p.pointee.gc) { gcPtr in
        return zend_gc_delref_ex(gcPtr, rc)
    }
}

// GC_TRY_ADDREF
public func GC_TRY_ADDREF(_ p: UnsafeMutablePointer<zend_refcounted_h>) -> Void {
    zend_gc_try_addref(p)
}

// GC_TRY_DELREF
public func GC_TRY_DELREF(_ p: UnsafeMutablePointer<zend_refcounted_h>) -> Void {  
    zend_gc_try_delref(p)
}

public func GC_TYPE_INFO(_ p: UnsafeMutablePointer<zend_refcounted>) -> UInt32 {
    return p.pointee.gc.u.type_info
}

public func GC_TYPE_INFO_SET(_ p: UnsafeMutablePointer<zend_refcounted>, _ typeInfo: UInt32) {
    p.pointee.gc.u.type_info = typeInfo
}

public func GC_TYPE(_ p: UnsafeMutablePointer<zend_refcounted>) -> UInt32 {
    return UInt32(zval_gc_type(GC_TYPE_INFO(p)))
}

public func GC_FLAGS(_ p: UnsafeMutablePointer<zend_refcounted>) -> UInt32 {
    return zval_gc_flags(GC_TYPE_INFO(p))
}

public func GC_INFO(_ p: UnsafeMutablePointer<zend_refcounted>) -> UInt32 {
    return zval_gc_info(GC_TYPE_INFO(p))
}

public func ZEND_TYPE_INIT_NONE(_ extra_flags: UInt32) -> zend_type {
    return zend_type(ptr: nil, type_mask: extra_flags)
}

public func ZEND_TYPE_INIT_MASK(_ type_mask: UInt32) -> zend_type {
    return zend_type(ptr: nil, type_mask: type_mask)
}

public func ZEND_TYPE_INIT_CODE(_ code: UInt32, allow_null: Bool, _ extra_flags: UInt32) -> zend_type {
    var type_mask: UInt32
    switch Int32(code) {
    case _IS_BOOL:
        type_mask = MAY_BE_BOOL
    case IS_ITERABLE:
        type_mask = _ZEND_TYPE_ITERABLE_BIT
    case IS_MIXED:
        type_mask = MAY_BE_ANY
    default:
        type_mask = (1 << code)
    }
    
    let nullable_bit = allow_null ? _ZEND_TYPE_NULLABLE_BIT : 0
    return ZEND_TYPE_INIT_MASK(type_mask | nullable_bit | extra_flags)
}

public func ZEND_TYPE_INIT_PTR(_ ptr: UnsafeMutableRawPointer?, _ type_kind: UInt32, allow_null: Bool, _ extra_flags: UInt32) -> zend_type {
    let nullable_bit = allow_null ? _ZEND_TYPE_NULLABLE_BIT : 0
    let type_mask = type_kind | nullable_bit | extra_flags
    return zend_type(ptr: ptr, type_mask: type_mask)
}

public func ZEND_TYPE_INIT_PTR_MASK(_ ptr: UnsafeMutableRawPointer?, _ type_mask: UInt32) -> zend_type {
    return zend_type(ptr: ptr, type_mask: type_mask)
}

public func ZEND_TYPE_INIT_UNION(_ ptr: UnsafeMutableRawPointer?, _ extra_flags: UInt32) -> zend_type {
    let type_mask = (_ZEND_TYPE_LIST_BIT | _ZEND_TYPE_UNION_BIT) | extra_flags
    return zend_type(ptr: ptr, type_mask: type_mask)
}

public func ZEND_TYPE_INIT_INTERSECTION(_ ptr: UnsafeMutableRawPointer?, _ extra_flags: UInt32) -> zend_type {
    let type_mask = (_ZEND_TYPE_LIST_BIT | _ZEND_TYPE_INTERSECTION_BIT) | extra_flags
    return zend_type(ptr: ptr, type_mask: type_mask)
}

public func ZEND_TYPE_INIT_CLASS(_ class_name: String, allow_null: Bool, _ extra_flags: UInt32) -> zend_type {
    #if os(Windows)
    let name_ptr = UnsafeMutableRawPointer(_strdup(class_name))
    #else
    let name_ptr = UnsafeMutableRawPointer(strdup(class_name))
    #endif
    return ZEND_TYPE_INIT_PTR(name_ptr, _ZEND_TYPE_NAME_BIT, allow_null: allow_null, extra_flags)
}

public func ZEND_TYPE_INIT_CLASS_MASK(_ class_name: String, _ type_mask: UInt32) -> zend_type {
    #if os(Windows)
    let name_ptr = UnsafeMutableRawPointer(_strdup(class_name))
    #else
    let name_ptr = UnsafeMutableRawPointer(strdup(class_name))
    #endif
    return ZEND_TYPE_INIT_PTR_MASK(name_ptr, _ZEND_TYPE_NAME_BIT | type_mask)
}

public func ZEND_TYPE_INIT_CLASS_CONST(_ class_name: String, allow_null: Bool, _ extra_flags: UInt32) -> zend_type {
    #if os(Windows)
    let name_ptr = UnsafeMutableRawPointer(_strdup(class_name))
    #else
    let name_ptr = UnsafeMutableRawPointer(strdup(class_name))
    #endif
    return ZEND_TYPE_INIT_PTR(name_ptr, _ZEND_TYPE_LITERAL_NAME_BIT, allow_null: allow_null, extra_flags)
}

public func ZEND_TYPE_INIT_CLASS_CONST_MASK(_ class_name: String, _ type_mask: UInt32) -> zend_type {
    #if os(Windows)
    let name_ptr = UnsafeMutableRawPointer(_strdup(class_name))
    #else
    let name_ptr = UnsafeMutableRawPointer(strdup(class_name))
    #endif
    return ZEND_TYPE_INIT_PTR_MASK(name_ptr, _ZEND_TYPE_LITERAL_NAME_BIT | type_mask)
}

public func RETVAL_STR(_ s: UnsafeMutablePointer<zend_string>, _ return_value: UnsafeMutablePointer<zval>) {
    ZVAL_STR(return_value, s)
}


public func Z_LVAL(_ z: zval) -> zend_long { z.value.lval }
public func Z_LVAL_P(_ zp: UnsafePointer<zval>) -> zend_long { Z_LVAL(zp.pointee) }
public func Z_DVAL_P(_ zp: UnsafePointer<zval>) -> CDouble { Z_DVAL(zp.pointee) }
public func Z_STR(_ z: zval) -> UnsafeMutablePointer<zend_string>? { z.value.str }
public func Z_STR_P(_ zp: UnsafePointer<zval>) -> UnsafeMutablePointer<zend_string>? { Z_STR(zp.pointee) }
// public func Z_STRVAL(_ z: zval) -> UnsafePointer<CChar>! { ZSTR_VAL(Z_STR(z)) }
// public func Z_STRVAL_P(_ zp: UnsafePointer<zval>) -> UnsafePointer<CChar>! { Z_STRVAL(zp.pointee) }
// public func Z_STRLEN_P(_ zp: UnsafePointer<zval>) -> size_t { Z_STRLEN(zp.pointee) }
public func Z_STRHASH(_ z: zval) -> zend_ulong { zend_ulong(ZSTR_HASH(Z_STR(z))) }
public func Z_STRHASH_P(_ zp: UnsafePointer<zval>) -> zend_ulong { Z_STRHASH(zp.pointee) }
