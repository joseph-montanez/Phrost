import Foundation

#if ZEND_DEBUG
public let STANDARD_MODULE_HEADER_EX = (
    size: MemoryLayout<zend_module_entry>.size,
    zendApiNo: ZEND_MODULE_API_NO,
    zendDebug: 1, // Or ZEND_DEBUG if it has a specific value
    usingZTS: USING_ZTS
)
#else
public let STANDARD_MODULE_HEADER_EX = (
    size: MemoryLayout<zend_module_entry>.size,
    zendApiNo: ZEND_MODULE_API_NO,
    zendDebug: 0,
    usingZTS: USING_ZTS
)
#endif

public let STANDARD_MODULE_PROPERTIES_EX: (
    globalsSize: Int,
    globalsCtor: (@Sendable (UnsafeMutableRawPointer) -> Void)?,
    globalsDtor: (@Sendable (UnsafeMutableRawPointer) -> Void)?,
    postDeactivate: (@Sendable () -> Int32)?,
    moduleStartup: String
) = (
    globalsSize: 0,
    globalsCtor: nil,
    globalsDtor: nil,
    postDeactivate: nil,
    moduleStartup: ZEND_MODULE_BUILD_ID
)



// public let NO_MODULE_GLOBALS = (
//     globalsSize: 0,
//     globalsCtor: nil,
//     globalsDtor: nil,
//     postDeactivate: nil
// )
