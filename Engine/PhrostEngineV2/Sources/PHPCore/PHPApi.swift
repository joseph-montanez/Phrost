@preconcurrency @_exported import CSwiftPHP

public func ZEND_NS_NAME(ns: String, name: String) -> String {
    return "\(ns)\\\(name)"
}

public func ZEND_FN(name: String) -> String {
    return "zif_\(name)"
}

public func ZEND_MN(name: String) -> String {
    return "zim_\(name)"
}

public typealias PhpInternalFunctionHandler = (UnsafeMutableRawPointer?, UnsafeMutablePointer<zval>?) -> Void
public typealias InternalFunctionParameters = (execute_data: UnsafeMutableRawPointer?, return_value: UnsafeMutablePointer<zval>?)

public typealias ZifHandler = @convention(c) (
    _ execute_data: UnsafeMutablePointer<zend_execute_data>?,
    _ return_value: UnsafeMutablePointer<zval>?
) -> Void

public func ZEND_RAW_FENTRY(
    zend_name: String,
    handler: ZifHandler?,
    arg_info: [zend_internal_arg_info]?,
    flags: UInt32,
    frameless_function_infos: UnsafeMutableRawPointer? = nil,
    doc_comment: String? = nil
) -> zend_function_entry {
    
    // The C macros subtract 1 for the ZEND_END_ARG_INFO marker.
    let num_args = UInt32((arg_info?.count ?? 1) - 1)
    
    // The C struct needs pointers that live on. strdup allocates persistent memory.
    let fname_ptr = strdup(zend_name)
    let doc_comment_ptr = doc_comment.flatMap { strdup($0) }
    
    // If arg_info was provided, get a persistent pointer to it.
    let arg_info_ptr = arg_info.flatMap { info -> UnsafePointer<zend_internal_arg_info>? in
        let ptr = UnsafeMutablePointer<zend_internal_arg_info>.allocate(capacity: info.count)
        ptr.initialize(from: info, count: info.count)
        return UnsafePointer(ptr)
    }

    return zend_function_entry(
        fname: fname_ptr,
        handler: handler,
        arg_info: arg_info_ptr,
        num_args: num_args,
        flags: flags,
        frameless_function_infos: zend_function_entry.init().frameless_function_infos, // Use default for prototype/reserved
        doc_comment: doc_comment_ptr
    )
}

public func ZEND_NAMED_FUNCTION(name: String, handler: @escaping PhpInternalFunctionHandler) -> PhpInternalFunctionHandler {
    print("Registering PHP function: \(name)")
    return handler
}

public func ZEND_FUNCTION(name: String, handler: @escaping PhpInternalFunctionHandler) -> PhpInternalFunctionHandler {
    return ZEND_NAMED_FUNCTION(name: "zif_\(name)", handler: handler)
}

public func ZEND_METHOD(classname: String, name: String, handler: @escaping PhpInternalFunctionHandler) -> PhpInternalFunctionHandler {
    return ZEND_NAMED_FUNCTION(name: "zim_\(classname)_\(name)", handler: handler)
}

public func ZEND_FENTRY(
    zend_name: String,
    handler: ZifHandler?,
    arg_info: [zend_internal_arg_info]?,
    flags: UInt32
) -> zend_function_entry {

    let num_args = UInt32((arg_info?.count ?? 1) - 1)
    
    let fname_ptr = strdup(zend_name)
    
    let arg_info_ptr = arg_info.flatMap { info -> UnsafePointer<zend_internal_arg_info>? in
        let ptr = UnsafeMutablePointer<zend_internal_arg_info>.allocate(capacity: info.count)
        ptr.initialize(from: info, count: info.count)
        return UnsafePointer(ptr)
    }

    return zend_function_entry(
        fname: fname_ptr,
        handler: handler,
        arg_info: arg_info_ptr,
        num_args: num_args,
        flags: flags,
        // The two NULLs in the C macro correspond to these fields.
        frameless_function_infos: zend_function_entry.init().frameless_function_infos, 
        doc_comment: nil
    )
}


public func ZEND_FE(name: String, handler: ZifHandler?, arg_info: [zend_internal_arg_info]?) -> zend_function_entry {
    // Reliably calculate num_args using .count
    let num_args = UInt32((arg_info?.count ?? 1) - 1)
    
    // Allocate persistent memory for the arg_info array and get a pointer to it.
    let arg_info_ptr = arg_info.flatMap { info -> UnsafePointer<zend_internal_arg_info>? in
        let ptr: UnsafeMutablePointer<zend_internal_arg_info> = UnsafeMutablePointer<zend_internal_arg_info>.allocate(capacity: info.count)
        ptr.initialize(from: info, count: info.count)
        return UnsafePointer(ptr)
    }

    return zend_function_entry(
        fname: strdup(name),
        handler: handler,
        arg_info: arg_info_ptr,
        num_args: num_args,
        flags: 0,
        frameless_function_infos: zend_function_entry.init().frameless_function_infos, 
        doc_comment: nil
    )
}

public func ZEND_FE_END() -> zend_function_entry {
    return zend_function_entry(fname: nil, handler: nil, arg_info: nil, num_args: 0, flags: 0, frameless_function_infos: nil, doc_comment: nil)
}

public func ZEND_FALIAS(name: String, alias: ZifHandler?, arg_info: [zend_internal_arg_info]?) -> zend_function_entry {
    return ZEND_RAW_FENTRY(zend_name: name, handler: alias, arg_info: arg_info, flags: 0)
}

public func ZEND_ME(classname: String, name: String, handler: ZifHandler?, arg_info: [zend_internal_arg_info]?, flags: UInt32) -> zend_function_entry {
    return ZEND_RAW_FENTRY(zend_name: name, handler: handler, arg_info: arg_info, flags: flags)
}

public func ZEND_ABSTRACT_ME(classname: String, name: String, arg_info: [zend_internal_arg_info]?) -> zend_function_entry {
    let flags = UInt32(ZEND_ACC_PUBLIC | ZEND_ACC_ABSTRACT)
    return ZEND_RAW_FENTRY(zend_name: name, handler: nil, arg_info: arg_info, flags: flags)
}

public func ZEND_DEP_FE(name: String, handler: ZifHandler?, arg_info: [zend_internal_arg_info]?) -> zend_function_entry {
    return ZEND_RAW_FENTRY(zend_name: name, handler: handler, arg_info: arg_info, flags: UInt32(ZEND_ACC_DEPRECATED))
}

public func ZEND_NS_FENTRY(
    ns: String,
    zend_name: String,
    handler: ZifHandler?,
    arg_info: [zend_internal_arg_info]?,
    flags: UInt32
) -> zend_function_entry {
    let namespacedName = ZEND_NS_NAME(ns: ns, name: zend_name)
    return ZEND_RAW_FENTRY(
        zend_name: namespacedName,
        handler: handler,
        arg_info: arg_info,
        flags: flags
    )
}

public func ZEND_NS_RAW_FENTRY(
    ns: String,
    zend_name: String,
    handler: ZifHandler?,
    arg_info: [zend_internal_arg_info]?,
    flags: UInt32
) -> zend_function_entry {
    let namespacedName = ZEND_NS_NAME(ns: ns, name: zend_name)
    return ZEND_RAW_FENTRY(
        zend_name: namespacedName,
        handler: handler,
        arg_info: arg_info,
        flags: flags
    )
}

public func ZEND_ARG_INFO(pass_by_ref: Bool, name: String) -> [String: Any] {
    let passByRefFlag = pass_by_ref ? 1 : 0
    return ["name": name, "pass_by_ref": passByRefFlag]
}

public func _ZEND_ARG_INFO_FLAGS(pass_by_ref: Bool, is_variadic: Bool, is_tentative: Bool) -> UInt32 {
    let sendMode = (pass_by_ref ? 1 : 0) << _ZEND_SEND_MODE_SHIFT
    
    let variadicBit = is_variadic ? _ZEND_IS_VARIADIC_BIT : 0
    
    let tentativeBit = is_tentative ? _ZEND_IS_TENTATIVE_BIT : 0
    
    return UInt32(sendMode | variadicBit | tentativeBit)
}

// MARK: - ArgInfo Structures for a Single Argument

public func ZEND_ARG_INFO(pass_by_ref: Bool, name: String) -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: pass_by_ref, is_variadic: false, is_tentative: false)
    let type = ZEND_TYPE_INIT_NONE(Int(flags))
    return zend_internal_arg_info(name: strdup(name), type: type, default_value: nil)
}

public func ZEND_ARG_INFO_WITH_DEFAULT_VALUE(pass_by_ref: Bool, name: String, default_value: String) -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: pass_by_ref, is_variadic: false, is_tentative: false)
    let type = ZEND_TYPE_INIT_NONE(Int(flags))
    return zend_internal_arg_info(name: strdup(name), type: type, default_value: strdup(default_value))
}

public func ZEND_ARG_TYPE_INFO(pass_by_ref: Bool, name: String, type_hint: UInt32, allow_null: Bool) -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: pass_by_ref, is_variadic: false, is_tentative: false)
    let type = ZEND_TYPE_INIT_CODE(type_hint, allow_null: allow_null, flags)
    return zend_internal_arg_info(name: strdup(name), type: type, default_value: nil)
}

public func ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(pass_by_ref: Bool, name: String, type_hint: UInt32, allow_null: Bool, default_value: String) -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: pass_by_ref, is_variadic: false, is_tentative: false)
    let type = ZEND_TYPE_INIT_CODE(type_hint, allow_null: allow_null, flags)
    return zend_internal_arg_info(name: strdup(name), type: type, default_value: strdup(default_value))
}

public func ZEND_ARG_OBJ_INFO(pass_by_ref: Bool, name: String, class_name: String, allow_null: Bool) -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: pass_by_ref, is_variadic: false, is_tentative: false)
    let type = ZEND_TYPE_INIT_CLASS_CONST(class_name, allow_null: allow_null, flags)
    return zend_internal_arg_info(name: strdup(name), type: type, default_value: nil)
}

public func ZEND_ARG_VARIADIC_TYPE_INFO(pass_by_ref: Bool, name: String, type_hint: UInt32, allow_null: Bool) -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: pass_by_ref, is_variadic: true, is_tentative: false)
    let type = ZEND_TYPE_INIT_CODE(type_hint, allow_null: allow_null, flags)
    return zend_internal_arg_info(name: strdup(name), type: type, default_value: nil)
}

public func ZEND_ARG_ARRAY_INFO(pass_by_ref: Bool, name: String, allow_null: Bool) -> zend_internal_arg_info {
    return ZEND_ARG_TYPE_INFO(pass_by_ref: pass_by_ref, name: name, type_hint: UInt32(IS_ARRAY), allow_null: allow_null)
}

public func ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX2(
    returnReference: Bool,
    requiredNumArgs: Int,
    type: CUnsignedInt,
    allowNull: Bool,
    isTentativeReturnType: Bool
) -> [zend_internal_arg_info] {
    let namePtr = UnsafePointer<CChar>(bitPattern: requiredNumArgs)

    let flags = _ZEND_ARG_INFO_FLAGS(
        passByRef: returnReference ? 1 : 0,
        isVariadic: false,
        isTentative: isTentativeReturnType
    )
    let typeInfo = ZEND_TYPE_INIT_CODE(type, allow_null: allowNull, UInt32(flags))

    let argInfo = zend_internal_arg_info(
        name: namePtr,
        type: typeInfo,
        default_value: nil
    )

    return [argInfo]
}

// Other BEGIN_ARG macros are just wrappers around the EX2 version.
public func ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(name: String, return_reference: Bool, required_num_args: Int32, type: UInt32, allow_null: Bool) -> zend_internal_arg_info {
    return ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX2(name: name, return_reference: return_reference, required_num_args: required_num_args, type: type, allow_null: allow_null, is_tentative_return_type: false)
}

public func ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO(name: String, type: UInt32, allow_null: Bool) -> zend_internal_arg_info {
    return ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX2(name: name, return_reference: false, required_num_args: -1, type: type, allow_null: allow_null, is_tentative_return_type: false)
}

// MARK: - Argument List Initializers (BEGIN_ARG...)

public func ZEND_BEGIN_ARG_INFO_EX(name: String, return_reference: Bool, required_num_args: Int32) -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: return_reference, is_variadic: false, is_tentative: false)
    let type = ZEND_TYPE_INIT_NONE(flags)
    
    // In C, required_num_args is cast to a pointer and stored in the name field.
    let name_ptr = UnsafeRawPointer(bitPattern: Int(required_num_args))?.assumingMemoryBound(to: CChar.self)

    let firstElement = zend_internal_arg_info(name: name_ptr, type: type, default_value: nil)
    return firstElement
}

public func ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX2(name: String, return_reference: Bool, required_num_args: Int32, type: UInt32, allow_null: Bool, is_tentative_return_type: Bool) -> zend_internal_arg_info {
    let flags = _ZEND_ARG_INFO_FLAGS(pass_by_ref: return_reference, is_variadic: false, is_tentative: is_tentative_return_type)
    let returnType = ZEND_TYPE_INIT_CODE(type, allow_null: allow_null, flags)

    let name_ptr = UnsafeRawPointer(bitPattern: Int(required_num_args))?.assumingMemoryBound(to: CChar.self)
    
    let firstElement = zend_internal_arg_info(name: name_ptr, type: returnType, default_value: nil)
    return firstElement
}



public enum ParameterParseError: Error {
    case invalidArgumentCount
    case wrongArg
    case parameterParseFailure
}

public struct ParseState {
    var flags: CInt
    var minNumArgs: UInt32
    var maxNumArgs: UInt32
    var numArgs: UInt32
    var i: UInt32
    
    var realArg: UnsafeMutablePointer<zval>?
    var arg: UnsafeMutablePointer<zval>?
    
    var expectedType: zend_expected_type
    var error: UnsafePointer<CChar>?
    var dummy: Bool
    var optional: Bool
    var errorCode: CInt
}

public func ZEND_PARSE_PARAMETERS_START_EX(flags: CInt, min: UInt32, max: UInt32, execute_data: UnsafeMutablePointer<zend_execute_data>?) -> ParseState? {
    guard let execData = execute_data else {
        // Handle the case where execute_data is null
        return ParseState(
            flags: flags,
            minNumArgs: min,
            maxNumArgs: max,
            numArgs: 0, // No args
            i: 0,
            realArg: nil,
            arg: nil,
            expectedType: Z_EXPECTED_LONG,
            error: nil,
            dummy: false,
            optional: false,
            errorCode: ZPP_ERROR_OK
        )
    }

    let numArgs = EX_NUM_ARGS(execData)

    // Perform the argument count check
    if numArgs < min || numArgs > max {
        if (flags & (1 << 1)) == 0 {
            zend_wrong_parameters_count_error(min, max)
        }
        return nil // Failure
    }

    return ParseState(
        flags: flags,
        minNumArgs: min,
        maxNumArgs: max,
        numArgs: UInt32(numArgs),
        i: 0,
        realArg: ZEND_CALL_ARG(execData, 0),
        arg: nil,
        expectedType: Z_EXPECTED_LONG,
        error: nil,
        dummy: false,
        optional: false,
        errorCode: ZPP_ERROR_OK
    )
}

public func ZEND_PARSE_PARAMETERS_START(min: UInt32, max: UInt32, execute_data: UnsafeMutablePointer<zend_execute_data>?) -> ParseState? {
    return ZEND_PARSE_PARAMETERS_START_EX(flags: 0, min: min, max: max, execute_data: execute_data)
}


public func Z_PARAM_PROLOGUE(state: inout ParseState, deref: Bool, separate: Bool) {
    state.i += 1
    assert(state.i <= state.minNumArgs || state.optional == true)
    assert(state.i > state.minNumArgs || state.optional == false)

    if state.optional && state.i > state.numArgs {
        return
    }

    state.realArg = state.realArg?.advanced(by: 1)
    state.arg = state.realArg

    if deref, let argPtr = state.arg, Z_ISREF_P(argPtr) {
        state.arg = Z_REFVAL_P(argPtr)
    }

    if separate, let argPtr = state.arg {
        SEPARATE_ZVAL_NOREF(argPtr)
    }
}

public func Z_PARAM_OPTIONAL(state: inout ParseState) {
    state.optional = true
}

@preconcurrency @_exported import CSwiftPHP

public func Z_PARAM_STR_OR_LONG_EX(
    state: inout ParseState,
    destStr: UnsafeMutablePointer<UnsafeMutablePointer<zend_string>?>?,
    destLong: UnsafeMutablePointer<zend_long>?,
    isNull: UnsafeMutablePointer<Bool>? = nil,
    allowNull: Bool
) -> Bool {
    Z_PARAM_PROLOGUE(state: &state, deref: false, separate: false)
    if state.arg == nil { return true }
    if !zend_parse_arg_str_or_long(state.arg, destStr, destLong, isNull, allowNull, state.i) {
        state.expectedType = allowNull ? Z_EXPECTED_STRING_OR_LONG_OR_NULL : Z_EXPECTED_STRING_OR_LONG
        state.errorCode = ZPP_ERROR_WRONG_ARG
        return false
    }
    return true
}

public func Z_PARAM_STR_OR_LONG(
    state: inout ParseState,
    destStr: UnsafeMutablePointer<UnsafeMutablePointer<zend_string>?>?,
    destLong: UnsafeMutablePointer<zend_long>?
) throws {
    if !Z_PARAM_STR_OR_LONG_EX(state: &state, destStr: destStr, destLong: destLong, isNull: nil, allowNull: false) {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_STR_OR_LONG_OR_NULL(
    state: inout ParseState,
    destStr: UnsafeMutablePointer<UnsafeMutablePointer<zend_string>?>?,
    destLong: UnsafeMutablePointer<zend_long>?,
    isNull: UnsafeMutablePointer<Bool>?
) throws {
    if !Z_PARAM_STR_OR_LONG_EX(state: &state, destStr: destStr, destLong: destLong, isNull: isNull, allowNull: true) {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_STRING_EX(
    state: inout ParseState,
    dest: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>,
    destLen: UnsafeMutablePointer<Int>,
    checkNull: Bool,
    deref: Bool
) -> Bool {
    Z_PARAM_PROLOGUE(state: &state, deref: deref, separate: false)

    if state.arg == nil {
        return true
    }

    if !zend_parse_arg_string(state.arg, dest, destLen, checkNull, state.i) {
        state.expectedType = checkNull ? Z_EXPECTED_STRING_OR_NULL : Z_EXPECTED_STRING
        state.errorCode = ZPP_ERROR_WRONG_ARG
        return false
    }

    return true
}

public func Z_PARAM_STRING(state: inout ParseState, dest: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, destLen: UnsafeMutablePointer<Int>) throws {
    if !Z_PARAM_STRING_EX(state: &state, dest: dest, destLen: destLen, checkNull: false, deref: false) {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_STRING_OR_NULL(state: inout ParseState, dest: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, destLen: UnsafeMutablePointer<Int>) throws {
    if !Z_PARAM_STRING_EX(state: &state, dest: dest, destLen: destLen, checkNull: true, deref: false) {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_DOUBLE_EX(
    state: inout ParseState,
    dest: UnsafeMutablePointer<CDouble>?,
    isNull: UnsafeMutablePointer<Bool>? = nil,
    checkNull: Bool,
    deref: Bool
) -> Bool {
    Z_PARAM_PROLOGUE(state: &state, deref: deref, separate: false)

    if state.arg == nil {
        return true
    }

    if !zend_parse_arg_double(state.arg, dest, isNull, checkNull, state.i) {
        state.expectedType = checkNull ? Z_EXPECTED_DOUBLE_OR_NULL : Z_EXPECTED_DOUBLE
        state.errorCode = ZPP_ERROR_WRONG_ARG
        return false
    }

    return true
}

public func Z_PARAM_DOUBLE(
    state: inout ParseState,
    dest: UnsafeMutablePointer<CDouble>?
) throws {
    if !Z_PARAM_DOUBLE_EX(state: &state, dest: dest, isNull: nil, checkNull: false, deref: false) {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_DOUBLE_OR_NULL(
    state: inout ParseState,
    dest: UnsafeMutablePointer<CDouble>?,
    isNull: UnsafeMutablePointer<Bool>?
) throws {
    if !Z_PARAM_DOUBLE_EX(state: &state, dest: dest, isNull: isNull, checkNull: true, deref: false) {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_LONG_EX(
    state: inout ParseState,
    dest: UnsafeMutablePointer<zend_long>?,
    isNull: UnsafeMutablePointer<Bool>? = nil,
    checkNull: Bool,
    deref: Bool
) -> Bool {
    Z_PARAM_PROLOGUE(state: &state, deref: deref, separate: false)
    if state.arg == nil { return true }
    if !zend_parse_arg_long(state.arg, dest, isNull, checkNull, state.i) {
        state.expectedType = checkNull ? Z_EXPECTED_LONG_OR_NULL : Z_EXPECTED_LONG
        state.errorCode = ZPP_ERROR_WRONG_ARG
        return false
    }
    return true
}

public func Z_PARAM_LONG(
    state: inout ParseState,
    dest: UnsafeMutablePointer<zend_long>?
) throws {
    if !Z_PARAM_LONG_EX(state: &state, dest: dest, isNull: nil, checkNull: false, deref: false) {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_LONG_OR_NULL(
    state: inout ParseState,
    dest: UnsafeMutablePointer<zend_long>?,
    isNull: UnsafeMutablePointer<Bool>?
) throws {
    if !Z_PARAM_LONG_EX(state: &state, dest: dest, isNull: isNull, checkNull: true, deref: false) {
        throw ParameterParseError.wrongArg
    }
}

// MARK: - Array and Object Parsing

public func Z_PARAM_ARRAY_EX(
    state: inout ParseState,
    dest: UnsafeMutablePointer<UnsafeMutablePointer<zval>?>,
    checkNull: Bool,
    allowObjects: Bool, // The key difference between the C macros
    deref: Bool,
    separate: Bool
) -> Bool {
    Z_PARAM_PROLOGUE(state: &state, deref: deref, separate: separate)

    // If we're parsing an optional argument that wasn't provided, we're done.
    if state.i > state.numArgs {
        return true
    }

    if !zend_parse_arg_array(state.arg, dest, checkNull, allowObjects) {
        state.expectedType = checkNull ? Z_EXPECTED_ARRAY_OR_NULL : Z_EXPECTED_ARRAY
        state.errorCode = ZPP_ERROR_WRONG_ARG
        return false
    }

    return true
}


public func Z_PARAM_ARRAY(
    state: inout ParseState,
    dest: UnsafeMutablePointer<UnsafeMutablePointer<zval>?>
) throws {
    // Corresponds to Z_PARAM_ARRAY_EX(dest, 0, 0) -> Z_PARAM_ARRAY_EX2(dest, 0, 0, 0)
    let success = Z_PARAM_ARRAY_EX(
        state: &state,
        dest: dest,
        checkNull: false,
        allowObjects: false,
        deref: false,
        separate: false
    )

    if !success {
        throw ParameterParseError.wrongArg
    }
}

/**
 * Corresponds to: `#define Z_PARAM_ARRAY_OR_NULL(dest)`
 * Parses an **optional** PHP array (can be `null`).
 */
public func Z_PARAM_ARRAY_OR_NULL(
    state: inout ParseState,
    dest: UnsafeMutablePointer<UnsafeMutablePointer<zval>?>
) throws {
    // Corresponds to Z_PARAM_ARRAY_EX(dest, 1, 0) -> Z_PARAM_ARRAY_EX2(dest, 1, 0, 0)
    let success = Z_PARAM_ARRAY_EX(
        state: &state,
        dest: dest,
        checkNull: true,
        allowObjects: false,
        deref: false,
        separate: false
    )
    
    if !success {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_ARRAY_OR_OBJECT(
    state: inout ParseState,
    dest: UnsafeMutablePointer<UnsafeMutablePointer<zval>?>
) throws {
    // Corresponds to Z_PARAM_ARRAY_OR_OBJECT_EX(dest, 0, 0) -> Z_PARAM_ARRAY_OR_OBJECT_EX2(dest, 0, 0, 0)
    let success = Z_PARAM_ARRAY_EX(
        state: &state,
        dest: dest,
        checkNull: false,
        allowObjects: true,
        deref: false,
        separate: false
    )

    if !success {
        throw ParameterParseError.wrongArg
    }
}

// MARK: - Iterable Parsing

public func Z_PARAM_ITERABLE_EX(
    state: inout ParseState,
    dest: UnsafeMutablePointer<UnsafeMutablePointer<zval>?>,
    checkNull: Bool
) -> Bool {
    // The macro uses Z_PARAM_PROLOGUE(0, 0), so deref and separate are false.
    Z_PARAM_PROLOGUE(state: &state, deref: false, separate: false)

    if state.i > state.numArgs {
        return true
    }

    if !zend_parse_arg_iterable(state.arg, dest, checkNull) {
        state.expectedType = checkNull ? Z_EXPECTED_ITERABLE_OR_NULL : Z_EXPECTED_ITERABLE
        state.errorCode = ZPP_ERROR_WRONG_ARG
        return false
    }
    
    return true
}

public func Z_PARAM_ITERABLE(
    state: inout ParseState,
    dest: UnsafeMutablePointer<UnsafeMutablePointer<zval>?>
) throws {
    if !Z_PARAM_ITERABLE_EX(state: &state, dest: dest, checkNull: false) {
        throw ParameterParseError.wrongArg
    }
}

public func Z_PARAM_ITERABLE_OR_NULL(
    state: inout ParseState,
    dest: UnsafeMutablePointer<UnsafeMutablePointer<zval>?>
) throws {
    if !Z_PARAM_ITERABLE_EX(state: &state, dest: dest, checkNull: true) {
        throw ParameterParseError.wrongArg
    }
}

public func ZEND_PARSE_PARAMETERS_END(state: ParseState) throws {
    assert(state.i == state.maxNumArgs || state.maxNumArgs == UInt32.max)

    if state.errorCode != ZPP_ERROR_OK {
        if !(state.flags & ZEND_PARSE_PARAMS_QUIET != 0) {
            let mutableError = UnsafeMutablePointer(mutating: state.error)
            zend_wrong_parameter_error(state.errorCode, state.i, mutableError, state.expectedType, state.arg)
        }
        throw ParameterParseError.parameterParseFailure
    }
}

public func ZVAL_STRINGL_FAST(_ z: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?, _ l: Int) {
    guard let z = z, let s = s else { return }
    
    ZVAL_STR(z, zend_string_init_fast(s, l))
}

public func ZVAL_STRING_FAST(_ z: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?) {
    guard let z = z, let s = s else { return }
    
    ZVAL_STRINGL_FAST(z, s, strlen(s))
}

public func ZVAL_CHAR(_ z: UnsafeMutablePointer<zval>?, _ c: UInt8) {
    guard let z = z, let charStr = ZSTR_CHAR(c) else {
        return
    }
    
    ZVAL_INTERNED_STR(z, charStr)
}

public func ZVAL_COPY_DEREF(_ z: UnsafeMutablePointer<zval>?, _ v: UnsafeMutablePointer<zval>?) {
    guard let z = z, let v = v else { return }

    var sourcePtr = v

    if Z_OPT_REFCOUNTED_P(sourcePtr) {
        if Z_OPT_ISREF_P(sourcePtr) {
            sourcePtr = Z_REFVAL_P(sourcePtr)

            if Z_OPT_REFCOUNTED_P(sourcePtr) {
                _ = Z_ADDREF_P(sourcePtr)
            }
        } else {
            _ = Z_ADDREF_P(sourcePtr)
        }
    }
    
    ZVAL_COPY_VALUE(z, sourcePtr)
}

public func ZVAL_ZVAL(
    _ z: UnsafeMutablePointer<zval>?,
    _ zv: UnsafeMutablePointer<zval>?,
    _ copy: Bool,
    _ dtor: Bool
) {
    guard let z = z, let zv = zv else { return }

    if !Z_ISREF_P(zv) {
        if copy && !dtor {
            ZVAL_COPY(z, zv)
        } else {
            ZVAL_COPY_VALUE(z, zv)
        }
    } else {
        let innerValue = Z_REFVAL_P(zv)
        
        ZVAL_COPY(z, innerValue)
        
        if dtor || !copy {
            zval_ptr_dtor(zv)
        }
    }
}


public func RETVAL_BOOL(_ returnValue: UnsafeMutablePointer<zval>?, _ b: Bool) {
    guard let returnValue = returnValue else { return }
    ZVAL_BOOL(returnValue, b)
}

public func RETVAL_NULL(_ returnValue: UnsafeMutablePointer<zval>?) {
    guard let returnValue = returnValue else { return }
    ZVAL_NULL(returnValue)
}

public func RETVAL_LONG(_ returnValue: UnsafeMutablePointer<zval>?, _ l: Int64) {
    guard let returnValue = returnValue else { return }
    ZVAL_LONG(returnValue, l)
}

public func RETVAL_DOUBLE(_ returnValue: UnsafeMutablePointer<zval>?, _ d: Double) {
    guard let returnValue = returnValue else { return }
    ZVAL_DOUBLE(returnValue, d)
}

public func RETVAL_STR(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafeMutablePointer<zend_string>?) {
    guard let returnValue = returnValue, let s = s else { return }
    ZVAL_STR(returnValue, s)
}

public func RETVAL_INTERNED_STR(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafeMutablePointer<zend_string>?) {
    guard let returnValue = returnValue, let s = s else { return }
    ZVAL_INTERNED_STR(returnValue, s)
}

public func RETVAL_NEW_STR(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafeMutablePointer<zend_string>?) {
    guard let returnValue = returnValue, let s = s else { return }
    ZVAL_NEW_STR(returnValue, s)
}

public func RETVAL_STR_COPY(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafeMutablePointer<zend_string>?) {
    guard let returnValue = returnValue, let s = s else { return }
    ZVAL_STR_COPY(returnValue, s)
}

public func RETVAL_STRING(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?) {
    guard let returnValue = returnValue, let s = s else { return }
    ZVAL_STRING(returnValue, s)
}

public func RETVAL_STRINGL(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?, _ l: Int) {
    guard let returnValue = returnValue, let s = s else { return }
    ZVAL_STRINGL(returnValue, s, l)
}

public func RETVAL_STRING_FAST(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?) {
    ZVAL_STRING_FAST(returnValue, s)
}

public func RETVAL_STRINGL_FAST(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?, _ l: Int) {
    ZVAL_STRINGL_FAST(returnValue, s, l)
}

public func ZVAL_EMPTY_STRING(_ z: UnsafeMutablePointer<zval>?) {
    guard let z = z else { return }
    ZVAL_INTERNED_STR(z, ZSTR_EMPTY_ALLOC())
}

public func RETVAL_EMPTY_STRING(_ returnValue: UnsafeMutablePointer<zval>?) {
    ZVAL_EMPTY_STRING(returnValue)
}

public func RETVAL_CHAR(_ returnValue: UnsafeMutablePointer<zval>?, _ c: UInt8) {
    ZVAL_CHAR(returnValue, c)
}

public func RETVAL_RES(_ returnValue: UnsafeMutablePointer<zval>?, _ r: UnsafeMutablePointer<zend_resource>?) {
    guard let returnValue = returnValue, let r = r else { return }
    ZVAL_RES(returnValue, r)
}

public func RETVAL_ARR(_ returnValue: UnsafeMutablePointer<zval>?, _ r: UnsafeMutablePointer<zend_array>?) {
    guard let returnValue = returnValue, let r = r else { return }
    ZVAL_ARR(returnValue, r)
}

public func RETVAL_EMPTY_ARRAY(_ returnValue: UnsafeMutablePointer<zval>?) {
    ZVAL_EMPTY_ARRAY(returnValue)
}

public func RETVAL_OBJ(_ returnValue: UnsafeMutablePointer<zval>?, _ r: UnsafeMutablePointer<zend_object>?) {
    guard let returnValue = returnValue, let r = r else { return }
    ZVAL_OBJ(returnValue, r)
}

public func RETVAL_OBJ_COPY(_ returnValue: UnsafeMutablePointer<zval>?, _ r: UnsafeMutablePointer<zend_object>?) {
    guard let returnValue = returnValue, let r = r else { return }
    ZVAL_OBJ_COPY(returnValue, r)
}

public func RETVAL_COPY(_ returnValue: UnsafeMutablePointer<zval>?, _ zv: UnsafeMutablePointer<zval>?) {
    ZVAL_COPY(returnValue, zv)
}

public func RETVAL_COPY_VALUE(_ returnValue: UnsafeMutablePointer<zval>?, _ zv: UnsafeMutablePointer<zval>?) {
    ZVAL_COPY_VALUE(returnValue, zv)
}

public func RETVAL_COPY_DEREF(_ returnValue: UnsafeMutablePointer<zval>?, _ zv: UnsafeMutablePointer<zval>?) {
    ZVAL_COPY_DEREF(returnValue, zv)
}

public func RETVAL_ZVAL(_ returnValue: UnsafeMutablePointer<zval>?, _ zv: UnsafeMutablePointer<zval>?, _ copy: Bool, _ dtor: Bool) {
    ZVAL_ZVAL(returnValue, zv, copy, dtor)
}

public func RETVAL_FALSE(_ returnValue: UnsafeMutablePointer<zval>?) {
    guard let returnValue = returnValue else { return }
    ZVAL_FALSE(returnValue)
}

public func RETVAL_TRUE(_ returnValue: UnsafeMutablePointer<zval>?) {
    guard let returnValue = returnValue else { return }
    ZVAL_TRUE(returnValue)
}

// MARK: - RETURN Functions

public func RETURN_BOOL(_ returnValue: UnsafeMutablePointer<zval>?, _ b: Bool) {
    RETVAL_BOOL(returnValue, b)
}

public func RETURN_NULL(_ returnValue: UnsafeMutablePointer<zval>?) {
    RETVAL_NULL(returnValue)
}

public func RETURN_LONG(_ returnValue: UnsafeMutablePointer<zval>?, _ l: Int64) {
    RETVAL_LONG(returnValue, l)
}

public func RETURN_DOUBLE(_ returnValue: UnsafeMutablePointer<zval>?, _ d: Double) {
    RETVAL_DOUBLE(returnValue, d)
}

public func RETURN_STR(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafeMutablePointer<zend_string>?) {
    RETVAL_STR(returnValue, s)
}

public func RETURN_INTERNED_STR(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafeMutablePointer<zend_string>?) {
    RETVAL_INTERNED_STR(returnValue, s)
}

public func RETURN_NEW_STR(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafeMutablePointer<zend_string>?) {
    RETVAL_NEW_STR(returnValue, s)
}

public func RETURN_STR_COPY(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafeMutablePointer<zend_string>?) {
    RETVAL_STR_COPY(returnValue, s)
}

public func RETURN_STRING(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?) {
    RETVAL_STRING(returnValue, s)
}

public func RETURN_STRINGL(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?, _ l: Int) {
    RETVAL_STRINGL(returnValue, s, l)
}

public func RETURN_STRING_FAST(_ returnValue: UnsafeMutablePointer<zval>?, _ s: UnsafePointer<CChar>?) {
    RETVAL_STRING_FAST(returnValue, s)
}

public func RETURN_STRINGL_FAST(_ s: UnsafePointer<CChar>?, _ l: Int, _ returnValue: UnsafeMutablePointer<zval>?) {
    RETVAL_STRINGL_FAST(returnValue, s, l)
}

public func RETURN_EMPTY_STRING(_ returnValue: UnsafeMutablePointer<zval>?) {
    RETVAL_EMPTY_STRING(returnValue)
}

public func RETURN_CHAR(_ returnValue: UnsafeMutablePointer<zval>?, _ c: UInt8) {
    RETVAL_CHAR(returnValue, c)
}

public func RETURN_RES(_ returnValue: UnsafeMutablePointer<zval>?, _ r: UnsafeMutablePointer<zend_resource>?) {
    RETVAL_RES(returnValue, r)
}

public func RETURN_ARR(_ returnValue: UnsafeMutablePointer<zval>?, _ r: UnsafeMutablePointer<zend_array>?) {
    RETVAL_ARR(returnValue, r)
}

public func RETURN_EMPTY_ARRAY(_ returnValue: UnsafeMutablePointer<zval>?) {
    RETVAL_EMPTY_ARRAY(returnValue)
}

public func RETURN_OBJ(_ returnValue: UnsafeMutablePointer<zval>?, _ r: UnsafeMutablePointer<zend_object>?) {
    RETVAL_OBJ(returnValue, r)
}

public func RETURN_OBJ_COPY(_ returnValue: UnsafeMutablePointer<zval>?, _ r: UnsafeMutablePointer<zend_object>?) {
    RETVAL_OBJ_COPY(returnValue, r)
}

public func RETURN_COPY(_ returnValue: UnsafeMutablePointer<zval>?, _ zv: UnsafeMutablePointer<zval>?) {
    RETVAL_COPY(returnValue, zv)
}

public func RETURN_COPY_VALUE(_ returnValue: UnsafeMutablePointer<zval>?, _ zv: UnsafeMutablePointer<zval>?) {
    RETVAL_COPY_VALUE(returnValue, zv)
}

public func RETURN_COPY_DEREF(_ zv: UnsafeMutablePointer<zval>?, _ returnValue: UnsafeMutablePointer<zval>?) {
    RETVAL_COPY_DEREF(returnValue, zv)
}

public func RETURN_ZVAL(_ zv: UnsafeMutablePointer<zval>?, _ copy: Bool, _ dtor: Bool, _ returnValue: UnsafeMutablePointer<zval>?) {
    RETVAL_ZVAL(returnValue, zv, copy, dtor)
}

public func RETURN_FALSE(_ returnValue: UnsafeMutablePointer<zval>?) {
    RETVAL_FALSE(returnValue)
}

public func RETURN_TRUE(_ returnValue: UnsafeMutablePointer<zval>?) {
    RETVAL_TRUE(returnValue)
}

public func RETURN_THROWS(_ returnValue: UnsafeMutablePointer<zval>?) {
    assert(EG(\.exception) != nil, "RETURN_THROWS was called but no exception was set.")
}



/*
#define INIT_CLASS_ENTRY(class_container, class_name, functions) \
	INIT_CLASS_ENTRY_EX(class_container, class_name, strlen(class_name), functions)

#define INIT_CLASS_ENTRY_EX(class_container, class_name, class_name_len, functions) \
	{															\
		memset(&class_container, 0, sizeof(zend_class_entry)); \
		class_container.name = zend_string_init_interned(class_name, class_name_len, 1); \
		class_container.default_object_handlers = &std_object_handlers;	\
		class_container.info.internal.builtin_functions = functions;	\
	}
*/


public func INIT_CLASS_ENTRY_EX(
    _ class_container: inout zend_class_entry,
    _ class_name: UnsafePointer<CChar>,
    _ class_name_len: Int,
    _ functions: UnsafePointer<zend_function_entry>?
) {
    var mutableStdObjectHandlers: zend_object_handlers = std_object_handlers

    class_container = zend_class_entry()

    class_container.name = zend_string_init_interned(class_name, class_name_len, true)

    class_container.default_object_handlers = withUnsafePointer(to: &mutableStdObjectHandlers) { $0 }

    class_container.info.internal.builtin_functions = functions
}


public func INIT_CLASS_ENTRY(
    _ class_container: inout zend_class_entry,
    _ class_name: String,
    _ functions: UnsafePointer<zend_function_entry>?
) {
    class_name.withCString { cString in
        INIT_CLASS_ENTRY_EX(
            &class_container,
            cString,
            class_name.utf8.count,
            functions
        )
    }
}

public func INIT_NS_CLASS_ENTRY(
    _ class_container: inout zend_class_entry,
    _ ns: String,
    _ class_name: String,
    _ functions: UnsafePointer<zend_function_entry>?
) {
    let namespacedClassName = "\(ns)\\\(class_name)"
    
    INIT_CLASS_ENTRY(
        &class_container,
        namespacedClassName,
        functions
    )
}

@MainActor
public func INIT_CLASS_ENTRY_INIT_METHODS(
    _ class_container: inout zend_class_entry,
    _ functions: UnsafePointer<zend_function_entry>?
) {
    var mutableStdObjectHandlers: zend_object_handlers = std_object_handlers
    
    class_container.default_object_handlers = withUnsafePointer(to: &mutableStdObjectHandlers) { $0 }

    class_container.constructor = nil
    class_container.destructor = nil
    class_container.clone = nil
    class_container.serialize = nil
    class_container.unserialize = nil
    class_container.create_object = nil
    class_container.get_static_method = nil
    class_container.__call = nil
    class_container.__callstatic = nil
    class_container.__tostring = nil
    class_container.__get = nil
    class_container.__set = nil
    class_container.__unset = nil
    class_container.__isset = nil
    class_container.__debugInfo = nil
    class_container.__serialize = nil
    class_container.__unserialize = nil
    class_container.parent = nil
    class_container.num_interfaces = 0
    class_container.trait_names = nil
    class_container.num_traits = 0
    class_container.trait_aliases = nil
    class_container.trait_precedences = nil
    class_container.interfaces = nil
    class_container.get_iterator = nil
    class_container.iterator_funcs_ptr = nil
    class_container.arrayaccess_funcs_ptr = nil
    class_container.info.internal.module = nil
    class_container.info.internal.builtin_functions = functions
}