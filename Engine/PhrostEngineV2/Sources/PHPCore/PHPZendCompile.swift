var ZEND_CALL_FRAME_SLOT: Int {
    let zendExecuteDataSize = MemoryLayout<zend_execute_data>.size
    let zvalSize = MemoryLayout<zval>.size

    return (zendExecuteDataSize + zvalSize - 1) / zvalSize
}

func ZEND_CALL_VAR(_ call: UnsafeMutablePointer<zend_execute_data>?, _ n: CInt) -> UnsafeMutablePointer<zval>? {
    guard let call = call else { return nil }

    return UnsafeMutableRawPointer(call)
        .advanced(by: Int(n))
        .bindMemory(to: zval.self, capacity: 1)
}

func ZEND_CALL_VAR_NUM(_ call: UnsafeMutablePointer<zend_execute_data>?, _ n: CInt) -> UnsafeMutablePointer<zval>? {
    guard let call = call else { return nil }

    return UnsafeMutableRawPointer(call)
        .assumingMemoryBound(to: zval.self)
        .advanced(by: ZEND_CALL_FRAME_SLOT + Int(n))
}

func ZEND_CALL_ARG(_ call: UnsafeMutablePointer<zend_execute_data>?, _ n: CInt) -> UnsafeMutablePointer<zval>? {
    return ZEND_CALL_VAR_NUM(call, n - 1)
}

func EX_NUM_ARGS(_ execute_data: UnsafeMutablePointer<zend_execute_data>?) -> CInt {
    guard let dataPtr = execute_data else {
        return 0
    }
    
    return CInt(dataPtr.pointee.This.u2.num_args)
}