#include "php_thread.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h> // For malloc/free
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
static size_t phrost_ub_write(const char *str, size_t str_length) {
    // We print it to the C stdout, prefixed with [PHP]
    // The '%.*s' is a safe way to print a non-null-terminated string
    printf("[PHP] %.*s\n", (int)str_length, str);
    fflush(stdout); // Ensure it prints immediately
    return str_length;
}


/**
 * @brief Sets PHP INI defaults. From your C++ example.
 */
static void set_ini_defaults(HashTable *configuration_hash)
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

    // --- NEW: Force INI settings *after* init ---
    // This is more reliable for dynamic paths.

    // 1. Set 'log_errors = 1'
    // FIX: Added persistent flag '1'
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("log_errors"), 1), zend_string_init(ZEND_STRL("1"), 1), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);

    // 2. Set 'error_log' to a file in our base path
    char error_log_path[PATH_MAX];
    snprintf(error_log_path, PATH_MAX, "%sphp_errors.log", g_php_base_path);
    printf("[PHP Thread] Setting error_log to: %s\n", error_log_path);
    // FIX: Added persistent flag '1' to key, '0' (non-persistent) to value
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("error_log"), 1), zend_string_init(error_log_path, strlen(error_log_path), 0), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);

    // 3. Set 'include_path' to the game directory
    char include_path[PATH_MAX];
    snprintf(include_path, PATH_MAX, ".:%sgame", g_php_base_path);
    printf("[PHP Thread] Setting include_path to: %s\n", include_path);
    // FIX: Added persistent flag '1' to key, '0' (non-persistent) to value
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("include_path"), 1), zend_string_init(include_path, strlen(include_path), 0), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);
    // --- END FIX ---


    // --- 2. Load the main PHP script ---
    zend_file_handle file_handle;
    char script_path[PATH_MAX];
    strcpy(script_path, g_php_base_path);
    // IMPORTANT: Change this to your actual PHP script entry point
    strcat(script_path, "game/bundle.php");

    zend_stream_init_filename(&file_handle, script_path);

    // This is the missing step:
    if (php_stream_open_for_zend_ex(&file_handle, USE_PATH|REPORT_ERRORS|STREAM_OPEN_FOR_INCLUDE) != SUCCESS) {
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
    zend_first_try {
        // Run the script
        // php_execute_script returns 1 (true) if the script ran.
        // We don't check != SUCCESS (0) because that logic was wrong.
        if (!php_execute_script(&file_handle)) {
            script_executed_ok = false;
            printf("[PHP Thread] php_execute_script returned false.\n");
        } else {
            // Script ran, but did it throw an Uncaught Exception?
            // This handles: throw new Exception("...");
            if (EG(exception)) {
                zval property;
                zend_class_entry *exception_ce = EG(exception)->ce;

                // Read "message"
                zval* msg_zval = zend_read_property(exception_ce, EG(exception), "message", strlen("message"), 1, &property);

                if (msg_zval && Z_TYPE_P(msg_zval) == IS_STRING) {
                        printf("[PHP Thread] CRITICAL: Uncaught Exception: %s\n", Z_STRVAL_P(msg_zval));
                }

                // Clear it so the engine doesn't think it's still in a broken state
                zend_clear_exception();

                // Mark as failed so we shut down
                script_executed_ok = false;
            }
        }
    } zend_catch {
        // This handles Fatal Errors (Bailouts)
        // This handles: require('missing_file.php') or syntax errors
        script_executed_ok = false;
        printf("[PHP Thread] CRITICAL: PHP Fatal Error (Bailout).\n");
    } zend_end_try();

    if (!script_executed_ok) {
        printf("[PHP Thread] Script failed to run. Shutting down.\n");

        // Signal Main thread to stop
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
            // Engine shut down, exit loop
            pthread_mutex_unlock(&bridge->mutex);
            break;
        }

        //-- Setup parameters of Phrost_Update($elapsed, $dt, $eventsBlob)
        ZVAL_LONG(z_elapsed, bridge->swift_frame);
        ZVAL_DOUBLE(z_delta, bridge->swift_delta);
        if (bridge->swift_event_len > 0) {
            ZVAL_STRINGL(z_event_data, bridge->swift_event_data, bridge->swift_event_len);
        } else {
            ZVAL_EMPTY_STRING(z_event_data);
        }


        //-- Mark events buffer from Swift consumed
        bridge->swift_has_data = false;
        pthread_mutex_unlock(&bridge->mutex);


        zend_fcall_info_init(&z_func_name, 0, &fci, &fci_cache, NULL, NULL);
        fci.param_count = 3;
        fci.params = z_params;
        fci.retval = &z_retval;

        if (zend_call_function(&fci, &fci_cache) == SUCCESS) {
            if (Z_TYPE(z_retval) == IS_STRING) {
                // --- 5. We got command data back from PHP ---
                const char* php_str = Z_STRVAL(z_retval);
                size_t php_len = Z_STRLEN(z_retval);

                pthread_mutex_lock(&bridge->mutex);
                // We must copy the data, as the zval will be destroyed
                bridge->php_command_data = (char*)malloc(php_len);
                if (bridge->php_command_data) {
                    memcpy(bridge->php_command_data, php_str, php_len);
                    bridge->php_command_len = (int32_t)php_len;
                } else {
                    printf("[PHP Thread] Error: Failed to malloc for command buffer!\n");
                    bridge->php_command_len = 0;
                }
                bridge->php_has_data = true;
                pthread_mutex_unlock(&bridge->mutex);
            }
            zval_ptr_dtor(&z_retval); // Free the zval returned by PHP
        } else {
            if (EG(exception)) {
                zval property;
                zend_class_entry *exception_ce = EG(exception)->ce;
                zval* msg_zval = zend_read_property(exception_ce, EG(exception), "message", strlen("message"), 1, &property);
                zend_string* msg_str = zval_get_string(msg_zval);

                printf("[PHP Thread] RUNTIME ERROR in Phrost_Update: %s\n", ZSTR_VAL(msg_str));

                zend_string_release(msg_str);
                zend_clear_exception();
            } else {
                printf("[PHP Thread] Error: zend_call_function failed for Phrost_Update.\n");
            }

            // Send empty response
            pthread_mutex_lock(&bridge->mutex);
            bridge->php_command_data = NULL;
            bridge->php_command_len = 0;
            bridge->php_has_data = true;
            pthread_mutex_unlock(&bridge->mutex);
        }

        // Free the zval we created for the event data
        zval_ptr_dtor(z_event_data);

        // --- 6. Signal Swift/Main thread that commands are ready ---
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
        // PHP thread failed or we are shutting down
        pthread_mutex_unlock(&bridge->mutex);
        *outLen = 0;
        return NULL;
    }

    // 3. We were woken up! Get the command data from PHP.
    const char* return_buffer = bridge->php_command_data;
    *outLen = bridge->php_command_len;

    bridge->php_has_data = false;
    pthread_mutex_unlock(&bridge->mutex);

    // 4. Return the buffer (which was malloc'd on the PHP thread)
    // The Swift engine is responsible for calling phrost_free_data (which is free())
    return return_buffer;
}


int php_thread_start(ThreadBridge* bridge, const char* base_path) {
    // Initialize the bridge
    if (pthread_mutex_init(&bridge->mutex, NULL) != 0) return -1;
    if (pthread_cond_init(&bridge->swift_to_php_cond, NULL) != 0) return -1;
    if (pthread_cond_init(&bridge->php_to_swift_cond, NULL) != 0) return -1;

    bridge->swift_event_data = NULL;
    bridge->swift_event_len = 0;
    bridge->swift_has_data = false;
    bridge->php_command_data = NULL;
    bridge->php_command_len = 0;
    bridge->php_has_data = false;
    bridge->engine_running = true;

    // Store the base path for the PHP thread to use
    strcpy(g_php_base_path, base_path);

    // Launch the PHP thread
    pthread_t thread_id;
    if (pthread_create(&thread_id, NULL, php_thread_main, (void*)bridge) != 0) {
        return -1;
    }

    // Detach the thread so we don't have to join it manually
    // We will signal it to stop
    pthread_detach(thread_id);

    return 0;
}

void php_thread_stop(ThreadBridge* bridge) {
    printf("[Main Thread] Signaling PHP thread to stop...\n");
    pthread_mutex_lock(&bridge->mutex);
    bridge->engine_running = false;

    // Wake up both cond vars in case PHP thread is sleeping
    pthread_cond_signal(&bridge->swift_to_php_cond);
    pthread_cond_signal(&bridge->php_to_swift_cond);

    pthread_mutex_unlock(&bridge->mutex);

    // Give the thread a moment to shut down
    // In a real app, you might use a more robust join
    usleep(100000); // 100ms

    pthread_mutex_destroy(&bridge->mutex);
    pthread_cond_destroy(&bridge->swift_to_php_cond);
    pthread_cond_destroy(&bridge->php_to_swift_cond);
}
