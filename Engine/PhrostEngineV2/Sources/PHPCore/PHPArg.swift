import Foundation

public let _ZEND_SEND_MODE_SHIFT = _ZEND_TYPE_EXTRA_FLAGS_SHIFT
public let _ZEND_IS_VARIADIC_BIT = 1 << (_ZEND_TYPE_EXTRA_FLAGS_SHIFT + 2)
public let _ZEND_IS_PROMOTED_BIT = 1 << (_ZEND_TYPE_EXTRA_FLAGS_SHIFT + 3)
public let _ZEND_IS_TENTATIVE_BIT = 1 << (_ZEND_TYPE_EXTRA_FLAGS_SHIFT + 4)

private func ZEND_TYPE_INIT_CODE(_ type: CUnsignedInt, _ allowNull: Bool, _ flags: UInt32) -> zend_type {
    func getTypeMask(for code: CUnsignedInt) -> UInt32 {
        switch code {
        case CUnsignedInt(_IS_BOOL):
            return UInt32(MAY_BE_BOOL)
        case CUnsignedInt(IS_ITERABLE):
            return _ZEND_TYPE_ITERABLE_BIT
        case CUnsignedInt(IS_MIXED):
            return UInt32(MAY_BE_ANY)
        default:
            return 1 << code
        }
    }

    let typeMask = getTypeMask(for: type)
    let nullableFlag = allowNull ? _ZEND_TYPE_NULLABLE_BIT : 0
    let finalMask = typeMask | nullableFlag | flags

    // Call the mask helper to construct the final zend_type struct.
    return ZEND_TYPE_INIT_MASK(finalMask)
}


public func ZEND_TYPE_INIT_NONE(_ extraFlags: Int) -> zend_type {
    return zend_type(ptr: nil, type_mask: UInt32(extraFlags))
}

// Correct _ZEND_ARG_INFO_FLAGS
public func _ZEND_ARG_INFO_FLAGS(passByRef: Int, isVariadic: Bool, isTentative: Bool) -> Int {
    let variadicFlag = isVariadic ? _ZEND_IS_VARIADIC_BIT : 0
    let tentativeFlag = isTentative ? _ZEND_IS_TENTATIVE_BIT : 0
    return (passByRef << _ZEND_SEND_MODE_SHIFT) | variadicFlag | tentativeFlag
}

// A C function that takes a C string and returns a C string
public func ZEND_ARG_TYPE_MASK(passByRef: Bool, name: String, typeMask: UInt32, defaultValue: String?) -> zend_internal_arg_info {
    #if os(Windows)
    let cName = _strdup(name)
    #else
    let cName = strdup(name)
    #endif

    // let cDefaultValue: UnsafePointer<CChar>? = defaultValue.flatMap { strdup($0) }
    #if os(Windows)
    let cDefaultValue: UnsafePointer<CChar>? = defaultValue.flatMap { _strdup($0).map { UnsafePointer($0) } }
    #else
    let cDefaultValue: UnsafePointer<CChar>? = defaultValue.flatMap { strdup($0).map { UnsafePointer($0) } }
    #endif

    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: passByRef, is_variadic: false, is_tentative: false)
    let type = ZEND_TYPE_INIT_MASK(typeMask | flags)
    return zend_internal_arg_info(name: cName, type: type, default_value: cDefaultValue)
}

public func ZEND_BEGIN_ARG_INFO() -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: false, is_variadic: false, is_tentative: false)
    let type = ZEND_TYPE_INIT_NONE(Int(flags))
    return zend_internal_arg_info(name: nil, type: type, default_value: nil)
}

public func ZEND_END_ARG_INFO() -> Void {
    return
}



public func ZEND_RAW_FENTRY(
    _ fname: UnsafePointer<CChar>?,
    _ handler: zif_handler?,
    _ arg_info: UnsafePointer<_zend_internal_arg_info>?,
    _ flags: UInt32
) -> zend_function_entry {
    var num_args: UInt32 = 0
    
    if let arg_info = arg_info {
        var count = 0
        var currentArgInfo = arg_info
        while currentArgInfo.pointee.name != nil {  // Assuming name being nil marks the end
            count += 1
            currentArgInfo = currentArgInfo.advanced(by: 1)
        }
        num_args = count > 0 ? UInt32(count - 1) : 0
    }

    return zend_function_entry(
        fname: fname,
        handler: handler,
        arg_info: arg_info,
        num_args: num_args,
        flags: flags,
        frameless_function_infos: nil,
        doc_comment: nil
    )
}

public func PHP_FE(
    _ name: UnsafePointer<CChar>?,
    _ handler: zif_handler?,
    _ arg_info: UnsafePointer<_zend_internal_arg_info>?,
    _ num_args: UInt32  // <-- Add this crucial parameter
) -> zend_function_entry {
    // This function now behaves like the original C macro,
    // creating the struct directly instead of calling another function.
    return zend_function_entry(
        fname: name,
        handler: handler,
        arg_info: arg_info,
        num_args: num_args,
        flags: 0,        
        frameless_function_infos: zend_function_entry.init().frameless_function_infos, 
        doc_comment: nil
    )
}

public func PHP_FE_END() -> zend_function_entry {
    return zend_function_entry(fname: nil, handler: nil, arg_info: nil, num_args: 0, flags: 0, frameless_function_infos: nil, doc_comment: nil)
}


public func C_ARG_INFO(from swiftArray: [zend_internal_arg_info]) -> UnsafeMutablePointer<zend_internal_arg_info> {
    let pointer = UnsafeMutablePointer<zend_internal_arg_info>.allocate(capacity: swiftArray.count + 1)
    
    pointer.initialize(from: swiftArray, count: swiftArray.count)
    
    (pointer + swiftArray.count).initialize(to: zend_internal_arg_info())
    
    return pointer
}
