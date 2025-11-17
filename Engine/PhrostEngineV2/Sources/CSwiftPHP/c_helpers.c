
// #include "main/php.h"
// #include "Zend/zend.h"
#include "c_helpers.h"

#include "Zend/zend_exceptions.h"
// TODO: embed versus module
//#include "sapi/embed/php_embed.h"

zend_string* swift_zend_string_init(const char *str, size_t len, bool persistent) {
    return zend_string_init(str, len, persistent);
}

const zend_object_handlers* swift_zend_get_std_object_handlers(void) { return &std_object_handlers; }

// sapi_module_struct* get_php_embed_module(void) {
//     return &php_embed_module;
// }

zend_result swift_zend_parse_parameters_2(uint32_t num_args, const char *type_spec, void *arg1, void *arg2) {
    // Directly call zend_parse_parameters with the correct arguments
    return zend_parse_parameters(num_args, type_spec, &arg1, &arg2);
}

zend_result swift_zend_parse_parameters_3(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3);
}

zend_result swift_zend_parse_parameters_4(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4);
}

zend_result swift_zend_parse_parameters_5(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4, arg5);
}

zend_result swift_zend_parse_parameters_6(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4, arg5, arg6);
}

zend_result swift_zend_parse_parameters_7(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
}

zend_result swift_zend_parse_parameters_8(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8);
}

zend_result swift_zend_parse_parameters_9(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8, void *arg9) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9);
}

zend_result swift_zend_parse_parameters_10(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8, void *arg9, void *arg10) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10);
}

zend_result swift_zend_parse_parameters_11(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8, void *arg9, void *arg10, void *arg11) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11);
}

zend_result swift_zend_parse_parameters_12(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8, void *arg9, void *arg10, void *arg11, void *arg12) {
    return zend_parse_parameters(num_args, type_spec, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12);
}

// TODO: embed versus module
// void set_php_embed_ini_defaults(void (*ini_defaults)(HashTable *)) {
//     php_embed_module.ini_defaults = ini_defaults;
// }

// void call_php_with_try(void (*swift_callback)()) {
//     zend_try {
//         // Inside the try, call the Swift callback function
//         swift_callback();
//     } zend_catch {
//         php_printf("Caught an exception or error\n");
//     } zend_end_try();
// }


// zend_result safe_zend_call_function(zend_fcall_info *fci, zend_fcall_info_cache *fci_cache) {
//     zend_result result;

//     // Try calling the PHP function
//     zend_try {
//         result = zend_call_function(fci, fci_cache);
//     } zend_catch {
//         // Handle the bailout here, set an error result
//         result = FAILURE;

//         // Handle non-exception error
//         php_printf("Error: Script execution failed without throwing an exception\n");
//     } zend_end_try();

//     return result;
// }

// bool safe_php_execute_script(zend_file_handle *primary_file) {
//     bool retval = false;

//     zend_try {
//         php_printf("Reloading from C: %s\n", primary_file->filename->val);
//         // Execute the script
//         retval = php_execute_script(primary_file);
//     } zend_catch {
//         if (EG(exception)) {
//             // Fetch exception information
//             zval *message = zend_read_property(
//                 zend_exception_get_default(), EG(exception), "message", strlen("message"), 0, NULL);

//             if (message && Z_TYPE_P(message) == IS_STRING) {
//                 php_printf("Exception during script execution: %s\n", Z_STRVAL_P(message));
//             } else {
//                 php_printf("Exception during script execution: Unknown error\n");
//             }

//             // Clear exception to prevent it from propagating
//             zend_clear_exception();
//         } else {
//             // Handle non-exception error
//             php_printf("Error: Script execution failed without throwing an exception\n");
//         }
//             zend_clear_exception();

//     } zend_end_try();

//     return retval;
// }

zend_module_entry* create_module_entry(
    const char* name,
    const char* version,
    const zend_function_entry* functions,
    int (*module_startup_func)(INIT_FUNC_ARGS),
    int (*module_shutdown_func)(SHUTDOWN_FUNC_ARGS),
    int (*request_startup_func)(INIT_FUNC_ARGS),
    int (*request_shutdown_func)(SHUTDOWN_FUNC_ARGS),
    void (*info_func)(ZEND_MODULE_INFO_FUNC_ARGS),
    size_t globals_size,
    #if defined(ZTS) && ZTS
    ts_rsrc_id* globals_id_ptr,
    #endif
    void (*globals_ctor)(void* global_ctor_arg),
    void (*globals_dtor)(void* global_dtor_arg),
    const char* build_id
) {
    zend_module_entry* entry = (zend_module_entry*)malloc(sizeof(zend_module_entry));
    if (entry == NULL) {
        return NULL;
    }

    entry->size = sizeof(zend_module_entry);
    entry->zend_api = ZEND_MODULE_API_NO;
    #if defined(ZEND_DEBUG) && ZEND_DEBUG
        entry->zend_debug = 1;
    #else
        entry->zend_debug = 0;
    #endif
    entry->zts = USING_ZTS;
    entry->ini_entry = NULL;
    entry->deps = NULL;
    entry->name = name;
    entry->functions = functions;
    entry->module_startup_func = module_startup_func;
    entry->module_shutdown_func = module_shutdown_func;
    entry->request_startup_func = request_startup_func;
    entry->request_shutdown_func = request_shutdown_func;
    entry->info_func = info_func;
    entry->version = version;
    entry->globals_size = globals_size;
#if defined(ZTS) && ZTS
    entry->globals_id_ptr = globals_id_ptr;
#endif
#if !defined(ZTS) || !ZTS
    entry->globals_ptr = NULL;
#endif
    entry->globals_ctor = globals_ctor;
    entry->globals_dtor = globals_dtor;
    entry->post_deactivate_func = NULL;
    entry->module_started = 0;
    entry->type = 0;
    entry->handle = NULL;
    entry->module_number = 0;
    entry->build_id = build_id;

    return entry;
}


#if !defined(ZTS) || !ZTS
zend_executor_globals* get_executor_globals(void) { return &executor_globals; }
zend_compiler_globals* get_compiler_globals(void) { return &compiler_globals; }
#endif

#if defined(ZTS) && ZTS
size_t get_executor_globals_offset(void) { return executor_globals_offset; }
size_t get_compiler_globals_offset(void) { return compiler_globals_offset; }
#endif
