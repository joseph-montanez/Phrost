import PHPCore
import Foundation

// @_silgen_name("swift_shutdown_concurrency")
// func swift_shutdown_concurrency()

// @_silgen_name("swift_task_asyncMainDrainQueue")
// internal func swift_task_asyncMainDrainQueue()

// @_silgen_name("swift_shutdown")
// internal func swift_shutdown()

// Global pointers to hold data that will persist
@MainActor var phrost_functions_ptr: UnsafeMutablePointer<zend_function_entry>? = nil
@MainActor var phrost_ini_entries_ptr: UnsafeMutablePointer<zend_ini_entry>? = nil
@MainActor var phrost_deps_ptr: UnsafeMutablePointer<zend_module_dep>? = nil
@MainActor var phrostModule_ptr: UnsafeMutablePointer<zend_module_entry>? = nil 
#if ZTS_SWIFT
@MainActor var phrost_globals_id: ts_rsrc_id = 0
#endif

struct phrostGlobals {
    var someGlobalVariable: Int = 0
}


@_cdecl("zm_startup_phrost")
func zm_startup_phrost(type: Int32, module_number: Int32) -> Int32 {
    print("[phrost] zm_startup_phrost called - type=\(type), module_number=\(module_number)")
    defer {
        print("[phrost] zm_startup_phrost completed")
    }
    return SUCCESS.rawValue
}

@_cdecl("zm_shutdown_phrost")
func zm_shutdown_phrost(type: Int32, module_number: Int32) -> Int32 {
    print("[phrost] zm_shutdown_phrost called - type=\(type), module_number=\(module_number)")
    // perform any shutdown work here
    // swift_shutdown_concurrency()
    // swift_task_asyncMainDrainQueue()
    // swift_shutdown()
    defer {
        print("[phrost] zm_shutdown_phrost completed")
    }
    return Int32(SUCCESS.rawValue)
}

@_cdecl("zm_activate_phrost")
func zm_activate_phrost(type: Int32, module_number: Int32) -> Int32 {
    print("[phrost] zm_activate_phrost called - type=\(type), module_number=\(module_number)")
    print("[phrost] zm_activate_phrost completed")
    return Int32(SUCCESS.rawValue)
}

@_cdecl("zm_deactivate_phrost")
func zm_deactivate_phrost(type: Int32, module_number: Int32) -> Int32 {
    print("[phrost] zm_deactivate_phrost called - type=\(type), module_number=\(module_number)")
    print("[phrost] zm_deactivate_phrost completed")
    return Int32(SUCCESS.rawValue)
}

@_cdecl("zm_info_phrost")
func zm_info_phrost(zend_module: UnsafeMutableRawPointer?) {
    print("[phrost] zm_info_phrost called")
    print("Phrost Module Version: 2.0.0")
    print("[phrost] zm_info_phrost completed")
}

@_cdecl("zm_globals_ctor_phrost")
func zm_globals_ctor_phrost(pointer: UnsafeMutableRawPointer?) {
    print("[phrost] zm_globals_ctor_phrost called")
    if let p = pointer {
        let globals = p.bindMemory(to: phrostGlobals.self, capacity: 1)
        // initialize if needed
        globals.pointee.someGlobalVariable = globals.pointee.someGlobalVariable // noop to avoid warnings
        print("[phrost] zm_globals_ctor_phrost initialized globals.someGlobalVariable=\(globals.pointee.someGlobalVariable)")
    } else {
        print("[phrost] zm_globals_ctor_phrost received nil pointer")
    }
}

@_cdecl("zm_globals_dtor_phrost")
func zm_globals_dtor_phrost(pointer: UnsafeMutableRawPointer?) {
    print("[phrost] zm_globals_dtor_phrost called")
    if let p = pointer {
        // If any cleanup is necessary, do it here. For now, just log.
        print("[phrost] zm_globals_dtor_phrost pointer non-nil - cleanup (none)\n")
    } else {
        print("[phrost] zm_globals_dtor_phrost received nil pointer")
    }
    exit(0)
}


@_cdecl("get_module")
@MainActor
public func get_module() -> UnsafeMutablePointer<zend_module_entry> {
    // Allocate memory for phrost_functions
    var builder = FunctionListBuilder()
    sdl3_add_entries(builder: &builder)
    // spritekit_add_entries(builder: &builder)
    phrost_functions_ptr = builder.build()
    
    let version = strdup("2.0.0")
    let module_name = strdup("phrost")

    let build_id = strdup(ZEND_MODULE_BUILD_ID)
    
    phrost_ini_entries_ptr = UnsafeMutablePointer<zend_ini_entry>.allocate(capacity: 1)
    phrost_ini_entries_ptr?.initialize(to: zend_ini_entry())
    
    phrost_deps_ptr = UnsafeMutablePointer<zend_module_dep>.allocate(capacity: 1)
    phrost_deps_ptr?.initialize(to: zend_module_dep())

#if ZTS_SWIFT
    phrostModule_ptr = create_module_entry(
        module_name,
        version,
        phrost_functions_ptr,
        zm_startup_phrost,
        zm_shutdown_phrost,
        zm_activate_phrost,
        zm_deactivate_phrost,
        zm_info_phrost,
        MemoryLayout<phrostGlobals>.size,
        &phrost_globals_id,
        zm_globals_ctor_phrost,
        zm_globals_dtor_phrost,
        build_id
    )
#else
    phrostModule_ptr = create_module_entry(
        module_name,
        version,
        phrost_functions_ptr,
        zm_startup_phrost,
        zm_shutdown_phrost,
        zm_activate_phrost,
        zm_deactivate_phrost,
        zm_info_phrost,
        MemoryLayout<phrostGlobals>.size,
        zm_globals_ctor_phrost,
        zm_globals_dtor_phrost,
        build_id
    )
#endif
    
    return phrostModule_ptr!
}

