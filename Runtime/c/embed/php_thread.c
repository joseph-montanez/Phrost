#include "php_thread.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h> // For malloc/free/realloc
#include <limits.h> // For PATH_MAX

#ifdef _WIN32
#ifndef PATH_MAX
#define PATH_MAX MAX_PATH
#endif
#endif

// Store the bridge and base path globally for this thread
static ThreadBridge* g_bridge = NULL;
static char g_php_base_path[PATH_MAX];

/**
 * @brief NEW: This function will receive all output (echo, errors) from PHP.
 */
static size_t phrost_ub_write(const char* str, size_t str_length) {
    // We print it to the C stdout, prefixed with [PHP]
    printf("[PHP] %.*s\n", (int)str_length, str);
    fflush(stdout); // Ensure it prints immediately
    return str_length;
}


/**
 * @brief Sets PHP INI defaults.
 */
static void set_ini_defaults(HashTable* configuration_hash)
{
    zval ini_value;
    // Setting memory_limit
    ZVAL_NEW_STR(&ini_value, zend_string_init(ZEND_STRL("-1"), 1));
    zend_hash_str_update(configuration_hash, ZEND_STRL("memory_limit"), &ini_value);

    // Setting display_errors
    ZVAL_NEW_STR(&ini_value, zend_string_init(ZEND_STRL("1"), 1));
    zend_hash_str_update(configuration_hash, ZEND_STRL("display_errors"), &ini_value);

    // Setting error_reporting
    ZVAL_NEW_STR(&ini_value, zend_string_init(ZEND_STRL("E_ALL"), 1));
    zend_hash_str_update(configuration_hash, ZEND_STRL("error_reporting"), &ini_value);
}

/**
 * @brief The main entry point for the new PHP thread.
 */
static void* php_thread_main(void* arg) {
    ThreadBridge* bridge = (ThreadBridge*)arg;
    g_bridge = bridge; // Set global for this thread

    printf("[PHP Thread] Initializing PHP embed...\n");

    // --- 1. Initialize PHP ---
    php_embed_module.ini_defaults = set_ini_defaults;
    php_embed_module.ub_write = phrost_ub_write;
    php_embed_init(0, NULL);

    // --- Force INI settings *after* init ---

    // 1. Set 'log_errors = 1'
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("log_errors"), 1), zend_string_init(ZEND_STRL("1"), 1), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);

    // 2. Set 'error_log' to a file in our base path
    char error_log_path[PATH_MAX];
    snprintf(error_log_path, PATH_MAX, "%sphp_errors.log", g_php_base_path);
    printf("[PHP Thread] Setting error_log to: %s\n", error_log_path);
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("error_log"), 1), zend_string_init(error_log_path, strlen(error_log_path), 0), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);

    // 3. Set 'include_path' to the game directory
    char include_path[PATH_MAX];
    snprintf(include_path, PATH_MAX, ".:%sgame", g_php_base_path);
    printf("[PHP Thread] Setting include_path to: %s\n", include_path);
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("include_path"), 1), zend_string_init(include_path, strlen(include_path), 0), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);


    // --- 2. Load the main PHP script ---
    zend_file_handle file_handle;
    char script_path[PATH_MAX];
    strcpy(script_path, g_php_base_path);
    strcat(script_path, "game/bundle.php");

    zend_stream_init_filename(&file_handle, script_path);

    if (php_stream_open_for_zend_ex(&file_handle, USE_PATH | REPORT_ERRORS | STREAM_OPEN_FOR_INCLUDE) != SUCCESS) {
        printf("[PHP Thread] CRITICAL: Failed to *open* main PHP script: %s. Check path.\n", script_path);
        php_embed_shutdown();

        // Signal the main thread that we failed
        pthread_mutex_lock(&bridge->mutex);
        bridge->engine_running = false; // Tell main thread to exit
        pthread_cond_signal(&bridge->php_to_swift_cond); // Wake up main thread if it's waiting
        pthread_mutex_unlock(&bridge->mutex);
        return NULL;
    }

    printf("[PHP Thread] Executing script: %s\n", script_path);

    bool script_executed_ok = true;
    zend_first_try{
        // Run the script
        if (!php_execute_script(&file_handle)) {
            script_executed_ok = false;
            printf("[PHP Thread] php_execute_script returned false.\n");
        }
 else {
            // Check for Uncaught Exceptions
            if (EG(exception)) {
                zval property;
                zend_class_entry* exception_ce = EG(exception)->ce;
                zval* msg_zval = zend_read_property(exception_ce, EG(exception), "message", strlen("message"), 1, &property);

                if (msg_zval && Z_TYPE_P(msg_zval) == IS_STRING) {
                        printf("[PHP Thread] CRITICAL: Uncaught Exception: %s\n", Z_STRVAL_P(msg_zval));
                }
                zend_clear_exception();
                script_executed_ok = false;
            }
        }
    } zend_catch{
        script_executed_ok = false;
        printf("[PHP Thread] CRITICAL: PHP Fatal Error (Bailout).\n");
    } zend_end_try();

    if (!script_executed_ok) {
        printf("[PHP Thread] Script failed to run. Shutting down.\n");
        pthread_mutex_lock(&bridge->mutex);
        bridge->engine_running = false;
        pthread_cond_signal(&bridge->php_to_swift_cond);
        pthread_mutex_unlock(&bridge->mutex);
        php_embed_shutdown();
        return NULL;
    }

    zend_destroy_file_handle(&file_handle);
    printf("[PHP Thread] PHP script loaded. Entering logic loop.\n");

    // --- 3. The PHP Logic Loop ---
    zend_fcall_info fci;
    zend_fcall_info_cache fci_cache;
    zval z_func_name, z_retval;

    zval z_params[3];
    zval* z_elapsed = &z_params[0];
    zval* z_delta = &z_params[1];
    zval* z_event_data = &z_params[2];

    ZVAL_STRING(&z_func_name, "Phrost_Update");

    while (true) {
        // --- Wait for data from Swift/Main thread ---
        pthread_mutex_lock(&bridge->mutex);
        while (!bridge->swift_has_data && bridge->engine_running) {
            pthread_cond_wait(&bridge->swift_to_php_cond, &bridge->mutex);
        }

        if (!bridge->engine_running) {
            pthread_mutex_unlock(&bridge->mutex);
            break;
        }

        //-- Setup parameters of Phrost_Update($elapsed, $dt, $eventsBlob)
        ZVAL_LONG(z_elapsed, bridge->swift_frame);
        ZVAL_DOUBLE(z_delta, bridge->swift_delta);
        if (bridge->swift_event_len > 0) {
            ZVAL_STRINGL(z_event_data, bridge->swift_event_data, bridge->swift_event_len);
        }
        else {
            ZVAL_EMPTY_STRING(z_event_data);
        }

        //-- Mark events buffer from Swift consumed
        bridge->swift_has_data = false;
        pthread_mutex_unlock(&bridge->mutex);

        //-- Call PHP Function
        zend_fcall_info_init(&z_func_name, 0, &fci, &fci_cache, NULL, NULL);
        fci.param_count = 3;
        fci.params = z_params;
        fci.retval = &z_retval;

        if (zend_call_function(&fci, &fci_cache) == SUCCESS) {
            pthread_mutex_lock(&bridge->mutex);

            if (Z_TYPE(z_retval) == IS_STRING) {
                const char* php_str = Z_STRVAL(z_retval);
                size_t php_len = Z_STRLEN(z_retval);

                // --- FIXED: Use Persistent Buffer (Realloc) ---

                // 1. Check Capacity: Grow if needed
                // We add +1 byte for a null terminator safety sentinel
                if (php_len + 1 > bridge->php_buffer_cap) {
                    // Growth Strategy: New length + padding * 2
                    size_t new_cap = (php_len + 4096) * 2;
                    char* new_ptr = (char*)realloc(bridge->php_command_data, new_cap);

                    if (new_ptr) {
                        bridge->php_command_data = new_ptr;
                        bridge->php_buffer_cap = new_cap;
                    }
                    else {
                        printf("[PHP Thread] CRITICAL ERROR: Failed to realloc command buffer to %zu bytes!\n", new_cap);
                        // In event of allocation failure, return empty so we don't crash
                        php_len = 0;
                    }
                }

                // 2. Copy Data into the Persistent Buffer
                // Only copy if we have a valid buffer and length > 0
                if (bridge->php_command_data && php_len > 0) {
                    memcpy(bridge->php_command_data, php_str, php_len);
                    // Null-terminate specifically for C/Swift safety, 
                    // even if the binary data contains nulls earlier.
                    bridge->php_command_data[php_len] = '\0';
                    bridge->php_command_len = (int32_t)php_len;
                }
                else {
                    bridge->php_command_len = 0;
                }

            }
            else {
                // PHP returned null/void/false
                // We treat this as "No Commands", but we MUST set the len to 0
                bridge->php_command_len = 0;
            }

            bridge->php_has_data = true; // ALWAYS signal data ready
            pthread_mutex_unlock(&bridge->mutex);

            zval_ptr_dtor(&z_retval); // Free PHP's return zval
        }
        else {
            // --- Execution Failed ---
            if (EG(exception)) {
                zval property;
                zend_class_entry* exception_ce = EG(exception)->ce;
                zval* msg_zval = zend_read_property(exception_ce, EG(exception), "message", strlen("message"), 1, &property);
                if (msg_zval && Z_TYPE_P(msg_zval) == IS_STRING) {
                    printf("[PHP Thread] RUNTIME ERROR in Phrost_Update: %s\n", Z_STRVAL_P(msg_zval));
                }
                zend_clear_exception();
            }

            // Always signal Swift to unblock it
            pthread_mutex_lock(&bridge->mutex);
            bridge->php_command_len = 0;
            bridge->php_has_data = true;
            pthread_mutex_unlock(&bridge->mutex);
        }

        // Free parameters
        zval_ptr_dtor(z_event_data);

        // Signal Swift that commands are ready
        pthread_cond_signal(&bridge->php_to_swift_cond);
    }

    // --- 7. Shutdown ---
    zval_ptr_dtor(&z_func_name);
    php_embed_shutdown();
    printf("[PHP Thread] PHP shutdown complete. Exiting.\n");
    return NULL;
}


/**
 * @brief The C callback called *by Swift* (on the Swift/Main thread).
 */
const char* swift_callback_to_php_bridge(int32_t frame, double delta,
    const char* eventData, int32_t eventLen,
    int32_t* outLen, ThreadBridge* bridge) {

    pthread_mutex_lock(&bridge->mutex);

    // 1. Give Swift's data to the PHP thread
    bridge->swift_event_data = eventData;
    bridge->swift_event_len = eventLen;
    bridge->swift_has_data = true;
    bridge->swift_frame = frame;
    bridge->swift_delta = delta;

    // 2. Signal the PHP thread and wait for it to finish
    pthread_cond_signal(&bridge->swift_to_php_cond);

    while (!bridge->php_has_data && bridge->engine_running) {
        pthread_cond_wait(&bridge->php_to_swift_cond, &bridge->mutex);
    }

    if (!bridge->engine_running) {
        pthread_mutex_unlock(&bridge->mutex);
        *outLen = 0;
        return NULL;
    }

    // 3. Return the Persistent Pointer
    // We do NOT free this. The ThreadBridge owns this memory.
    // Swift acts as a "Borrower" of this memory.
    const char* return_buffer = bridge->php_command_data;
    *outLen = bridge->php_command_len;

    bridge->php_has_data = false;
    pthread_mutex_unlock(&bridge->mutex);

    return return_buffer;
}


int php_thread_start(ThreadBridge* bridge, const char* base_path) {
    if (pthread_mutex_init(&bridge->mutex, NULL) != 0) return -1;
    if (pthread_cond_init(&bridge->swift_to_php_cond, NULL) != 0) return -1;
    if (pthread_cond_init(&bridge->php_to_swift_cond, NULL) != 0) return -1;

    bridge->swift_event_data = NULL;
    bridge->swift_event_len = 0;
    bridge->swift_has_data = false;

    // --- Initialize Persistent Buffer ---
    // Allocate 16KB initially to reduce early reallocations
    bridge->php_buffer_cap = 1024 * 16;
    bridge->php_command_data = (char*)malloc(bridge->php_buffer_cap);

    if (!bridge->php_command_data) {
        printf("CRITICAL: Failed to allocate initial PHP buffer.\n");
        return -1;
    }
    // Zero it out for safety
    memset(bridge->php_command_data, 0, bridge->php_buffer_cap);

    bridge->php_command_len = 0;
    bridge->php_has_data = false;
    bridge->engine_running = true;

    strcpy(g_php_base_path, base_path);

    pthread_t thread_id;
    if (pthread_create(&thread_id, NULL, php_thread_main, (void*)bridge) != 0) {
        return -1;
    }
    pthread_detach(thread_id);

    return 0;
}

void php_thread_stop(ThreadBridge* bridge) {
    printf("[Main Thread] Signaling PHP thread to stop...\n");
    pthread_mutex_lock(&bridge->mutex);
    bridge->engine_running = false;

    // Wake up both cond vars
    pthread_cond_signal(&bridge->swift_to_php_cond);
    pthread_cond_signal(&bridge->php_to_swift_cond);

    pthread_mutex_unlock(&bridge->mutex);

    // Give the thread a moment to shut down
    usleep(200000); // 200ms

    // --- Cleanup Persistent Buffer ---
    // We lock to ensure the PHP thread is definitely done using it
    pthread_mutex_lock(&bridge->mutex);
    if (bridge->php_command_data) {
        free(bridge->php_command_data);
        bridge->php_command_data = NULL;
    }
    pthread_mutex_unlock(&bridge->mutex);

    pthread_mutex_destroy(&bridge->mutex);
    pthread_cond_destroy(&bridge->swift_to_php_cond);
    pthread_cond_destroy(&bridge->php_to_swift_cond);
}