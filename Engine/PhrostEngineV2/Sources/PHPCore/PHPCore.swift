@preconcurrency @_exported import CSwiftPHP

// @_exported import CSwiftPHP

@inlinable
public func PHP_FE(
    _ name: String,
    _ handler: ZifHandler?,
    _ arg_info: [zend_internal_arg_info]?
) -> zend_function_entry {
    ZEND_FE(name: name, handler: handler, arg_info: arg_info)
}

@inlinable
public func PHP_ME(
    _ className: String,
    _ methodName: String,
    _ handler: ZifHandler?,
    _ arg_info: [zend_internal_arg_info]?,
    _ flags: Int32
) -> zend_function_entry {
    ZEND_ME(
        classname: className, name: methodName, handler: handler, arg_info: arg_info,
        flags: UInt32(flags))
}

public struct PhpFunctionContext {
    public var funcName: UnsafeMutablePointer<zend_string>
    public var retval: zval = zval()
    public var fci: zend_fcall_info = zend_fcall_info()
    public var fciCache: zend_fcall_info_cache = zend_fcall_info_cache()

    public init(functionName: String) {
        self.funcName = zend_string_init_fast("", 0)
        self.fci.function_name.u1.type_info = 0
        self.fci.size = MemoryLayout<zend_fcall_info>.size
        self.fci.object = nil
        self.fci.retval = nil
        self.fci.param_count = 0
        self.fci.params = nil

        self.fciCache.function_handler = nil
        self.fciCache.calling_scope = nil
        self.fciCache.called_scope = nil
        self.fciCache.object = nil

        functionName.withCString { functionNameCS in
            let length = strlen(functionNameCS)
            if let funcName = zend_string_init_fast(functionNameCS, length) {
                self.funcName = funcName
                ZVAL_STR(&self.fci.function_name, self.funcName)
            }
        }
    }

    public mutating func cleanup() {
        zend_string_release(self.funcName)
    }

    public mutating func reset() {
        // Release funcName if allocated
        zend_string_release(self.funcName)
        self.funcName = zend_string_init_fast("", 0)

        // Release retval if it's been set or used
        if Z_TYPE(self.retval) != IS_UNDEF {
            zval_ptr_dtor(&self.retval)
            ZVAL_UNDEF(&self.retval)
        }

        // Clear zend_fcall_info
        self.fci.size = MemoryLayout<zend_fcall_info>.size
        self.fci.function_name.u1.type_info = 0
        self.fci.object = nil
        self.fci.retval = nil
        self.fci.param_count = 0
        self.fci.params = nil

        // Clear zend_fcall_info_cache
        self.fciCache.function_handler = nil
        self.fciCache.calling_scope = nil
        self.fciCache.called_scope = nil
        self.fciCache.object = nil
    }
}

#if ZTS_SWIFT
    // ZTS (Thread Safe) version of the function
    @_silgen_name("create_module_entry")
    public func create_module_entry(
        _ name: UnsafePointer<CChar>?,
        _ version: UnsafePointer<CChar>?,
        _ functions: UnsafePointer<zend_function_entry>?,
        _ module_startup_func: @convention(c) (Int32, Int32) -> Int32,
        _ module_shutdown_func: @convention(c) (Int32, Int32) -> Int32,
        _ request_startup_func: @convention(c) (Int32, Int32) -> Int32,
        _ request_shutdown_func: @convention(c) (Int32, Int32) -> Int32,
        _ info_func: @convention(c) (UnsafeMutableRawPointer?) -> Void,
        _ globals_size: Int,
        _ globals_id_ptr: UnsafeMutablePointer<ts_rsrc_id>?,  // Included for ZTS
        _ globals_ctor: @convention(c) (UnsafeMutableRawPointer?) -> Void,
        _ globals_dtor: @convention(c) (UnsafeMutableRawPointer?) -> Void,
        _ build_id: UnsafePointer<CChar>?
    ) -> UnsafeMutablePointer<zend_module_entry>
#else
    // NTS (Non-Thread Safe) version of the function
    @_silgen_name("create_module_entry")
    public func create_module_entry(
        _ name: UnsafePointer<CChar>?,
        _ version: UnsafePointer<CChar>?,
        _ functions: UnsafePointer<zend_function_entry>?,
        _ module_startup_func: @convention(c) (Int32, Int32) -> Int32,
        _ module_shutdown_func: @convention(c) (Int32, Int32) -> Int32,
        _ request_startup_func: @convention(c) (Int32, Int32) -> Int32,
        _ request_shutdown_func: @convention(c) (Int32, Int32) -> Int32,
        _ info_func: @convention(c) (UnsafeMutableRawPointer?) -> Void,
        _ globals_size: Int,
        // globals_id_ptr is omitted for NTS
        _ globals_ctor: @convention(c) (UnsafeMutableRawPointer?) -> Void,
        _ globals_dtor: @convention(c) (UnsafeMutableRawPointer?) -> Void,
        _ build_id: UnsafePointer<CChar>?
    ) -> UnsafeMutablePointer<zend_module_entry>
#endif

public struct FunctionListBuilder {
    private var functions: [zend_function_entry] = []

    public init() {}

    // Original method for non-namespaced functions
    @discardableResult
    public mutating func add(
        name: String,
        handler: ZifHandler?,
        arg_info: [zend_internal_arg_info]?
    ) -> Self {
        // Assuming you have a ZEND_FENTRY or similar helper
        let entry = ZEND_FENTRY(zend_name: name, handler: handler, arg_info: arg_info, flags: 0)
        functions.append(entry)
        return self
    }

    // ✅ NEW: Overloaded method for namespaced functions
    @discardableResult
    public mutating func add(
        namespace: String,
        name: String,
        handler: ZifHandler?,
        arg_info: [zend_internal_arg_info]?
    ) -> Self {
        // This method calls your new helper function
        let entry = ZEND_NS_FENTRY(
            ns: namespace,
            zend_name: name,
            handler: handler,
            arg_info: arg_info,
            flags: 0
        )
        functions.append(entry)
        return self
    }

    public func build() -> UnsafeMutablePointer<zend_function_entry> {
        var finalList = self.functions
        finalList.append(ZEND_FE_END())

        let pointer = UnsafeMutablePointer<zend_function_entry>.allocate(capacity: finalList.count)
        pointer.initialize(from: finalList, count: finalList.count)

        return pointer
    }
}

/// Represents a key in a PHP array, which can be either an integer or a string.
public enum PHPArrayKey {
    case int(UInt)  // zend_ulong is aliased to UInt
    case string(UnsafeMutablePointer<zend_string>)
}

/// A protocol for any Swift struct that represents the memory layout of a custom PHP object.
public protocol ZendObjectContainer {
    /// The standard zend_object required by the Zend Engine.
    var std: zend_object { get set }

    /// The memory offset of the `std` property within the struct.
    static var stdOffset: Int { get }
}

/// A helper to create a Swift String from a zend_string pointer.
extension String {
    public init?(zendString: UnsafeMutablePointer<zend_string>?) {
        guard let zstr = zendString else { return nil }
        let rawPtr = UnsafeRawPointer(ZSTR_VAL(zstr))
        let buffer = UnsafeRawBufferPointer(start: rawPtr, count: Int(ZSTR_LEN(zstr)))
        self.init(decoding: buffer, as: UTF8.self)
    }
}

/// Fetches the beginning of the custom Swift object struct from a pointer
/// to its standard `zend_object` member.
@inline(__always)
public func fetchObject<T: ZendObjectContainer>(
    _ obj: UnsafeMutablePointer<zend_object>?,
    as type: T.Type
) -> UnsafeMutablePointer<T> {
    // Use the pre-calculated offset from the protocol to avoid generic key path issues.
    let offset = T.stdOffset

    let base = UnsafeMutableRawPointer(obj!).advanced(by: -offset)
    return base.assumingMemoryBound(to: T.self)
}

extension UnsafeMutablePointer where Pointee == zend_array {

    // MARK: - Value-Only Iterators

    /**
     * Iterates over each element in the array, yielding only the values that are a specific object type.
     */
    public func withEachObject<T: ZendObjectContainer>(
        ofType ce: UnsafeMutablePointer<zend_class_entry>?,
        as objectType: T.Type,
        body: (UnsafeMutablePointer<T>) -> Void
    ) {
        guard let ce = ce else { return }

        self.forEach { valuePtr in
            if Z_TYPE_P(valuePtr) == IS_OBJECT && Z_OBJCE_P(valuePtr) == ce {
                let intern = fetchObject(Z_OBJ_P(valuePtr), as: objectType)
                body(intern)
            }
        }
    }

    /**
     * Iterates over each element in the array, yielding only the values that are strings.
     */
    public func withEachString(body: (String) -> Void) {
        self.forEach { valuePtr in
            if Z_TYPE_P(valuePtr) == IS_STRING {
                if let swiftString = String(zendString: Z_STR_P(valuePtr)) {
                    body(swiftString)
                }
            }
        }
    }

    /**
     * Iterates over each element in the array, yielding only the values that are integers.
     */
    public func withEachInt(body: (Int) -> Void) {
        self.forEach { valuePtr in
            if Z_TYPE_P(valuePtr) == IS_LONG {
                body(Int(Z_LVAL_P(valuePtr)))
            }
        }
    }

    /**
     * Iterates over each element in the array, yielding only the values that are doubles (floats).
     */
    public func withEachDouble(body: (Double) -> Void) {
        self.forEach { valuePtr in
            if Z_TYPE_P(valuePtr) == IS_DOUBLE {
                body(Double(Z_DVAL_P(valuePtr)))
            }
        }
    }

    // MARK: - Generic Iterators

    /**
     * Iterates over every element in the array, yielding a pointer to the dereferenced value `zval`.
     * This is a flexible but less safe iterator that requires manual type checking.
     */
    public func forEach(body: (UnsafeMutablePointer<zval>) -> Void) {
        ZEND_HASH_FOREACH_VAL(self) { zv in
            var tmp = zval()
            ZVAL_COPY_DEREF(&tmp, zv)
            defer { zval_ptr_dtor(&tmp) }
            body(&tmp)
        }
    }

    /**
     * Iterates over each element in the array, yielding both the key and the value `zval`.
     * This is the base iterator for all key-value operations.
     */
    public func forEach(body: (PHPArrayKey, UnsafeMutablePointer<zval>) -> Void) {
        var pos = HashPosition()
        zend_hash_internal_pointer_reset_ex(self, &pos)

        while true {
            do {
                guard let valPtr = zend_hash_get_current_data_ex(self, &pos) else { break }

                var tmpVal = zval()
                ZVAL_COPY_DEREF(&tmpVal, valPtr)
                defer { zval_ptr_dtor(&tmpVal) }

                if Z_TYPE(tmpVal) == IS_UNDEF {
                    if zend_hash_move_forward_ex(self, &pos) == FAILURE { return }
                    continue
                }

                var keyStr: UnsafeMutablePointer<zend_string>? = nil
                var index: zend_ulong = 0
                let keyType = zend_hash_get_current_key_ex(self, &keyStr, &index, &pos)

                let key: PHPArrayKey
                if keyType == HASH_KEY_IS_STRING, let nonNilKeyStr = keyStr {
                    key = .string(nonNilKeyStr)
                } else {
                    key = .int(UInt(index))
                }

                body(key, &tmpVal)

            }

            if zend_hash_move_forward_ex(self, &pos) == FAILURE { break }
        }
    }

    // MARK: - Specialized Key-Value Iterators

    /**
     * Iterates over the array, yielding the key and any value that is a String.
     */
    public func withEachString(body: (PHPArrayKey, String) -> Void) {
        self.forEach { key, valuePtr in
            if Z_TYPE_P(valuePtr) == IS_STRING {
                if let swiftString = String(zendString: Z_STR_P(valuePtr)) {
                    body(key, swiftString)
                }
            }
        }
    }

    /**
     * Iterates over the array, yielding the key and any value that is an Int.
     */
    public func withEachInt(body: (PHPArrayKey, Int) -> Void) {
        self.forEach { key, valuePtr in
            if Z_TYPE_P(valuePtr) == IS_LONG {
                body(key, Int(Z_LVAL_P(valuePtr)))
            }
        }
    }

    /**
     * Iterates over the array, yielding the key and any value that is a Double.
     */
    public func withEachDouble(body: (PHPArrayKey, Double) -> Void) {
        self.forEach { key, valuePtr in
            if Z_TYPE_P(valuePtr) == IS_DOUBLE {
                body(key, Double(Z_DVAL_P(valuePtr)))
            }
        }
    }

    /**
     * Iterates over the array, yielding the key and any value that is a specific object type.
     */
    public func withEachObject<T: ZendObjectContainer>(
        ofType ce: UnsafeMutablePointer<zend_class_entry>?,
        as objectType: T.Type,
        body: (PHPArrayKey, UnsafeMutablePointer<T>) -> Void
    ) {
        guard let ce = ce else { return }
        self.forEach { key, valuePtr in
            if Z_TYPE_P(valuePtr) == IS_OBJECT && Z_OBJCE_P(valuePtr) == ce {
                let intern = fetchObject(Z_OBJ_P(valuePtr), as: objectType)
                body(key, intern)
            }
        }
    }
}
