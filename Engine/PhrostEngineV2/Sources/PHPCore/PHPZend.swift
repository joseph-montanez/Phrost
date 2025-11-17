import Foundation

public func EG<T>(_ keyPath: KeyPath<zend_executor_globals, T>) -> T {
    #if ZTS_SWIFT
    let tsrm_ls = tsrm_get_ls_cache()
    guard let tsrm_ls_base = tsrm_ls?.assumingMemoryBound(to: UInt8.self) else {
        fatalError("Failed to get thread-safe resource manager cache.")
    }
    let executor_globals_offset = get_executor_globals_offset()
    let tsrm_ls_cache = tsrm_ls_base.advanced(by: Int(executor_globals_offset)).withMemoryRebound(to: zend_executor_globals.self, capacity: 1) {
        $0
    }
    // Return the value at the keyPath
    return tsrm_ls_cache.pointee[keyPath: keyPath]
    #else
    let executor_globals_ptr = get_executor_globals()!
    return executor_globals_ptr.pointee[keyPath: keyPath]
    #endif
}


public func CG<T>(_ keyPath: KeyPath<zend_compiler_globals, T>) -> T {
    #if ZTS_SWIFT
    let tsrm_ls = tsrm_get_ls_cache()
    guard let tsrm_ls_base = tsrm_ls?.assumingMemoryBound(to: UInt8.self) else {
        fatalError("Failed to get thread-safe resource manager cache.")
    }
    let compiler_globals_offset = get_compiler_globals_offset()
    let tsrm_ls_cache = tsrm_ls_base.advanced(by: Int(compiler_globals_offset)).withMemoryRebound(to: zend_compiler_globals.self, capacity: 1) {
        $0
    }
    // Return the value at the keyPath
    return tsrm_ls_cache.pointee[keyPath: keyPath]
    #else
    let compiler_globals_ptr = get_compiler_globals()!
    return compiler_globals_ptr.pointee[keyPath: keyPath]
    #endif
}



public func ZEND_STRL(_ str: String, _ body: (UnsafePointer<CChar>, Int) -> Void) {
    str.withCString { cString in
        let length = strlen(cString)
        body(cString, Int(length))
    }
}

public func ZSTR_VAL(_ zstr: UnsafeMutablePointer<zend_string>) -> UnsafePointer<CChar> {
    return withUnsafePointer(to: &zstr.pointee.val) { $0 }
}

public func ZSTR_LEN(_ zstr: UnsafeMutablePointer<zend_string>) -> Int {
    return Int(zstr.pointee.len)
}

public func ZSTR_H(_ zstr: UnsafeMutablePointer<zend_string>) -> UInt32 {
    return UInt32(zstr.pointee.h)
}

public func ZSTR_HASH(_ zstr: UnsafeMutablePointer<zend_string>) -> UInt32 {
    return UInt32(zend_string_hash_val(zstr))
}

public func Z_COLLECTABLE(_ zval: zval) -> Bool {
    return (UInt8(Z_TYPE_FLAGS(zval)) & UInt8(IS_TYPE_COLLECTABLE)) != 0
}

public func Z_COLLECTABLE_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_COLLECTABLE(zval_p.pointee)
}

public func Z_COPYABLE(_ zval: zval) -> Bool {
    return Z_TYPE(zval) == IS_ARRAY
}

public func Z_COPYABLE_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_COPYABLE(zval_p.pointee)
}

public func Z_IMMUTABLE(_ zval: zval) -> Bool {
    return Z_TYPE_INFO(zval) == IS_ARRAY
}
public func Z_IMMUTABLE_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_IMMUTABLE(zval_p.pointee)
}
public func Z_OPT_IMMUTABLE(_ zval: zval) -> Bool {
    return Z_IMMUTABLE(zval)
}
public func Z_OPT_IMMUTABLE_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_IMMUTABLE_P(zval_p)
}

public func Z_OPT_TYPE(_ zval: zval) -> UInt32 {
    return Z_TYPE_INFO(zval) & UInt32(Z_TYPE_MASK)
}

public func Z_OPT_TYPE_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_OPT_TYPE(zval_p.pointee)
}

public func Z_OPT_CONSTANT(_ zval: zval) -> Bool {
    return Z_OPT_TYPE(zval) == IS_CONSTANT_AST
}
public func Z_OPT_CONSTANT_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_OPT_CONSTANT(zval_p.pointee)
}

public func Z_OPT_REFCOUNTED(_ zval: zval) -> Bool {
    return Z_TYPE_INFO_REFCOUNTED(Z_TYPE_INFO(zval))
}
public func Z_OPT_REFCOUNTED_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_OPT_REFCOUNTED(zval_p.pointee)
}

public func Z_OPT_COPYABLE(_ zval: zval) -> Bool {
    return Z_OPT_TYPE(zval) == IS_ARRAY
}
public func Z_OPT_COPYABLE_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_OPT_COPYABLE(zval_p.pointee)
}

public func Z_OPT_ISREF(_ zval: zval) -> Bool {
    return Z_OPT_TYPE(zval) == IS_REFERENCE
}
public func Z_OPT_ISREF_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_OPT_ISREF(zval_p.pointee)
}

public func Z_ISREF(_ zval: zval) -> Bool {
    return Z_TYPE(zval) == IS_REFERENCE
}
public func Z_ISREF_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_ISREF(zval_p.pointee)
}

public func Z_ISUNDEF(_ zval: zval) -> Bool {
    return Z_TYPE(zval) == IS_UNDEF
}
public func Z_ISUNDEF_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_ISUNDEF(zval_p.pointee)
}

public func Z_ISNULL(_ zval: zval) -> Bool {
    return Z_TYPE(zval) == IS_NULL
}
public func Z_ISNULL_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_ISNULL(zval_p.pointee)
}

public func Z_ISERROR(_ zval: zval) -> Bool {
    return Z_TYPE(zval) == _IS_ERROR
}
public func Z_ISERROR_P(_ zval_p: UnsafeMutablePointer<zval>) -> Bool {
    return Z_ISERROR(zval_p.pointee)
}

public func Z_LVAL(_ zval: zval) -> Int {
    return Int(zval.value.lval)
}

public func Z_LVAL_P(_ zval_p: UnsafeMutablePointer<zval>) -> Int {
    return Z_LVAL(zval_p.pointee)
}

public func Z_DVAL(_ zval: zval) -> Double {
    return zval.value.dval
}
public func Z_DVAL_P(_ zval_p: UnsafeMutablePointer<zval>) -> Double {
    return Z_DVAL(zval_p.pointee)
}

public func Z_STR(_ zval: zval) -> UnsafeMutablePointer<zend_string> {
    return zval.value.str
}

public func Z_STR_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_string> {
    return Z_STR(zval_p.pointee)
}

public func Z_STRVAL(_ zval: zval) -> UnsafePointer<CChar> {
    return ZSTR_VAL(Z_STR(zval))
}
public func Z_STRVAL_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafePointer<CChar> {
    return Z_STRVAL(zval_p.pointee)
}

public func Z_STRLEN(_ zval: zval) -> Int {
    return ZSTR_LEN(Z_STR(zval))
}
public func Z_STRLEN_P(_ zval_p: UnsafeMutablePointer<zval>) -> Int {
    return Z_STRLEN(zval_p.pointee)
}

public func Z_STRHASH(_ zval: zval) -> UInt32 {
    return ZSTR_HASH(Z_STR(zval))
}
public func Z_STRHASH_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_STRHASH(zval_p.pointee)
}

public func Z_ARR(_ zval: zval) -> UnsafeMutablePointer<zend_array> {
    return zval.value.arr
}
public func Z_ARR_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_array> {
    return Z_ARR(zval_p.pointee)
}

@inline(__always)
public func Z_ARRVAL(_ zval: zval) -> UnsafeMutablePointer<zend_array> {
    return Z_ARR(zval)
}

@inline(__always)
public func Z_ARRVAL_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_array> {
    return Z_ARRVAL(zval_p.pointee)
}

@inline(__always)
public func PHPArrayValueGet(_ zval_p: UnsafeMutablePointer<zval>?) -> UnsafeMutablePointer<zend_array>? {
    guard let zval_p = zval_p, Z_TYPE_P(zval_p) == IS_ARRAY else {
        return nil
    }
    return Z_ARRVAL_P(zval_p)
}

public func Z_OBJ(_ zval: zval) -> UnsafeMutablePointer<zend_object> {
    return zval.value.obj
}
public func Z_OBJ_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_object> {
    return Z_OBJ(zval_p.pointee)
}

public func Z_OBJ_HT(_ zval: zval) -> UnsafeMutablePointer<zend_object_handlers> {
    return UnsafeMutablePointer(mutating: Z_OBJ(zval).pointee.handlers)
}
public func Z_OBJ_HT_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_object_handlers> {
    return Z_OBJ_HT(zval_p.pointee)
}

public func Z_OBJ_HANDLE(_ zval: zval) -> UInt32 {
    return Z_OBJ(zval).pointee.handle
}
public func Z_OBJ_HANDLE_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_OBJ_HANDLE(zval_p.pointee)
}

public func Z_OBJCE(_ zval: zval) -> UnsafeMutablePointer<zend_class_entry> {
    return Z_OBJ(zval).pointee.ce
}
public func Z_OBJCE_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_class_entry> {
    return Z_OBJCE(zval_p.pointee)
}

public func Z_RES(_ zval: zval) -> UnsafeMutablePointer<zend_resource> {
    return zval.value.res
}
public func Z_RES_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_resource> {
    return Z_RES(zval_p.pointee)
}

public func Z_RES_HANDLE(_ zval: zval) -> UInt32 {
    return UInt32(Z_RES(zval).pointee.handle)
}
public func Z_RES_HANDLE_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_RES_HANDLE(zval_p.pointee)
}

public func Z_RES_TYPE(_ zval: zval) -> UInt32 {
    return UInt32(Z_RES(zval).pointee.type)
}
public func Z_RES_TYPE_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_RES_TYPE(zval_p.pointee)
}

public func Z_REF(_ zval: zval) -> UnsafeMutablePointer<zend_reference> {
    return zval.value.ref
}
public func Z_REF_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_reference> {
    return Z_REF(zval_p.pointee)
}

public func Z_REF_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ ref: UnsafeMutablePointer<zend_reference>) {
    zval_p.pointee.value.ref = ref
}

public func Z_REFVAL(_ zval: zval) -> UnsafeMutablePointer<zval> {
    return withUnsafeMutablePointer(to: &Z_REF(zval).pointee.val) { $0 }
}

public func Z_REFVAL_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zval> {
    return Z_REFVAL(zval_p.pointee)
}

public func Z_INDIRECT(_ zval: zval) -> UnsafeMutablePointer<zval> {
    return zval.value.zv
}

public func Z_INDIRECT_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zval> {
    return Z_INDIRECT(zval_p.pointee)
}

public func Z_INDIRECT_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ zv: UnsafeMutablePointer<zval>) {
    zval_p.pointee.value.zv = zv
}

public func Z_CE(_ zval: zval) -> UnsafeMutablePointer<zend_class_entry> {
    return zval.value.ce
}
public func Z_CE_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_class_entry> {
    return Z_CE(zval_p.pointee)
}

public func Z_FUNC(_ zval: zval) -> UnsafeMutablePointer<zend_function> {
    return zval.value.func
}
public func Z_FUNC_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_function> {
    return Z_FUNC(zval_p.pointee)
}

public func Z_PTR(_ zval: zval) -> UnsafeMutableRawPointer {
    return zval.value.ptr
}

public func Z_PTR_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutableRawPointer {
    return Z_PTR(zval_p.pointee)
}

public func Z_PTR_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ ptr: UnsafeMutableRawPointer) {
    zval_p.pointee.value.ptr = ptr
}

public func Z_TYPE(_ zval: zval) -> Int32 {
    var mutableZval = zval
    return Int32(zval_get_type(&mutableZval))
}

public func Z_TYPE_P(_ zval_p: UnsafeMutablePointer<zval>) -> Int32 {
    return Z_TYPE(zval_p.pointee)
}

public func Z_TYPE_FLAGS(_ zval: zval) -> UInt8 {
    return zval.u1.v.type_flags
}
public func Z_TYPE_FLAGS_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt8 {
    return Z_TYPE_FLAGS(zval_p.pointee)
}

public func Z_TYPE_INFO(_ zval: zval) -> UInt32 {
    return zval.u1.type_info
}
public func Z_TYPE_INFO_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_TYPE_INFO(zval_p.pointee)
}

public func Z_NEXT(_ zval: zval) -> UInt32 {
    return zval.u2.next
}
public func Z_NEXT_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_NEXT(zval_p.pointee)
}

public func Z_CACHE_SLOT(_ zval: zval) -> UInt32 {
    return zval.u2.cache_slot
}
public func Z_CACHE_SLOT_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_CACHE_SLOT(zval_p.pointee)
}

public func Z_LINENO(_ zval: zval) -> UInt32 {
    return zval.u2.lineno
}
public func Z_LINENO_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_LINENO(zval_p.pointee)
}

public func Z_OPLINE_NUM(_ zval: zval) -> UInt32 {
    return zval.u2.opline_num
}
public func Z_OPLINE_NUM_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_OPLINE_NUM(zval_p.pointee)
}

public func Z_FE_POS(_ zval: zval) -> UInt32 {
    return zval.u2.fe_pos
}
public func Z_FE_POS_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_FE_POS(zval_p.pointee)
}

public func Z_FE_ITER(_ zval: zval) -> UInt32 {
    return zval.u2.fe_iter_idx
}
public func Z_FE_ITER_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_FE_ITER(zval_p.pointee)
}

public func Z_PROPERTY_GUARD(_ zval: zval) -> UInt32 {
    return unsafeBitCast(zval.u2, to: UInt32.self)
}

public func Z_PROPERTY_GUARD_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_PROPERTY_GUARD(zval_p.pointee)
}

public func Z_CONSTANT_FLAGS(_ zval: zval) -> UInt32 {
    return zval.u2.constant_flags
}
public func Z_CONSTANT_FLAGS_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_CONSTANT_FLAGS(zval_p.pointee)
}

public func Z_EXTRA(_ zval: zval) -> UInt32 {
    return zval.u2.extra
}
public func Z_EXTRA_P(_ zval_p: UnsafeMutablePointer<zval>) -> UInt32 {
    return Z_EXTRA(zval_p.pointee)
}

public func Z_COUNTED(_ zval: zval) -> UnsafeMutablePointer<zend_refcounted> {
    return zval.value.counted
}
public func Z_COUNTED_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_refcounted> {
    return Z_COUNTED(zval_p.pointee)
}

public func Z_TYPE_INFO_REFCOUNTED(_ t: UInt32) -> Bool {
    return (t & UInt32(Z_TYPE_FLAGS_MASK)) != 0
}

// Z_STR_P set version
public func Z_STR_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ s: UnsafeMutablePointer<zend_string>) {
    zval_p.pointee.value.str = s
}

// Z_DVAL_P set version
public func Z_DVAL_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ d: Double) {
    zval_p.pointee.value.dval = d
}

// Z_ARR_P set version
public func Z_ARR_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ arr: UnsafeMutablePointer<zend_array>) {
    zval_p.pointee.value.arr = arr
}

// Z_OBJ_P set version
public func Z_OBJ_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ o: UnsafeMutablePointer<zend_object>) {
    zval_p.pointee.value.obj = o
}

// Z_RES_P set version
public func Z_RES_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ res: UnsafeMutablePointer<zend_resource>) {
    zval_p.pointee.value.res = res
}

// public func Z_AST(_ zval: zval) -> UnsafeMutablePointer<zend_ast> {
//     return UnsafeMutableRawPointer(zval.value.ast).assumingMemoryBound(to: zend_ast.self)
// }

public func Z_AST(_ zval: zval) -> UnsafeMutablePointer<zend_ast> {
    return withUnsafeMutablePointer(to: &zval.value.ast.pointee) { astRefPtr in
        let astPtr = UnsafeMutableRawPointer(astRefPtr).advanced(by: MemoryLayout<zend_refcounted_h>.size)
        return astPtr.assumingMemoryBound(to: zend_ast.self)
    }
}

public func Z_AST_P(_ zval_p: UnsafeMutablePointer<zval>) -> UnsafeMutablePointer<zend_ast> {
    return Z_AST(zval_p.pointee)
}

public func Z_AST_P_SET(_ zval_p: UnsafeMutablePointer<zval>, _ ast: UnsafeMutablePointer<zend_ast>) {
    let astRefPtr = withUnsafeMutablePointer(to: &zval_p.pointee.value.ast.pointee) { astRefPtr in
        UnsafeMutableRawPointer(astRefPtr).advanced(by: MemoryLayout<zend_refcounted_h>.size)
    }
    astRefPtr.storeBytes(of: ast, as: UnsafeMutablePointer<zend_ast>.self)
}