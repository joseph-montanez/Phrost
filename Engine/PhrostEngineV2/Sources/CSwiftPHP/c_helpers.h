#ifndef C_HELPERS_H
#define C_HELPERS_H

#ifdef _WIN32
#ifdef __clang__
#ifndef _AddressOfReturnAddress
#define _AddressOfReturnAddress() __builtin_return_address(0)
#endif
#endif
#endif

#include "main/php.h"
//#include "sapi/embed/php_embed.h"
#include "Zend/zend.h"

#ifdef PHP_WIN32
#include <config.w32.h>
#else
#include <php_config.h>
#endif

#if defined(_WIN32) && !defined(ZEND_DEBUG)
    #undef HAVE_BUILTIN_CONSTANT_P
#endif


zend_string* swift_zend_string_init(const char *str, size_t len, bool persistent);
const zend_object_handlers* swift_zend_get_std_object_handlers(void);

zend_result swift_zend_parse_parameters_2(uint32_t num_args, const char *type_spec, void *arg1, void *arg2);
zend_result swift_zend_parse_parameters_3(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3);
zend_result swift_zend_parse_parameters_4(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4);
zend_result swift_zend_parse_parameters_5(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5);
zend_result swift_zend_parse_parameters_6(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6);
zend_result swift_zend_parse_parameters_7(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7);
zend_result swift_zend_parse_parameters_8(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8);
zend_result swift_zend_parse_parameters_9(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8, void *arg9);
zend_result swift_zend_parse_parameters_10(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8, void *arg9, void *arg10);
zend_result swift_zend_parse_parameters_11(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8, void *arg9, void *arg10, void *arg11);
zend_result swift_zend_parse_parameters_12(uint32_t num_args, const char *type_spec, void *arg1, void *arg2, void *arg3, void *arg4, void *arg5, void *arg6, void *arg7, void *arg8, void *arg9, void *arg10, void *arg11, void *arg12);
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
);

// sapi_module_struct* get_php_embed_module(void);
// void set_php_embed_ini_defaults(void (*ini_defaults)(HashTable *));
// void call_php_with_try(void (*swift_callback)());
// zend_result safe_zend_call_function(zend_fcall_info *fci, zend_fcall_info_cache *fci_cache);
// bool safe_php_execute_script(zend_file_handle *primary_file);

#if !defined(ZTS) || !ZTS
zend_executor_globals* get_executor_globals();
zend_compiler_globals* get_compiler_globals();
#endif

#if defined(ZTS) && ZTS
extern size_t compiler_globals_offset;
extern size_t executor_globals_offset;
size_t get_compiler_globals_offset();
size_t get_executor_globals_offset();
#endif

#endif
