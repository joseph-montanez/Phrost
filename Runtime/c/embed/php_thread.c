#include "php_thread.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#ifndef PATH_MAX
#define PATH_MAX MAX_PATH
#endif
#else
#include <unistd.h>
#endif

static ThreadBridge* g_bridge = NULL;
static char g_php_base_path[PATH_MAX];

// --- Helper: PHP Output Wrapper ---
static size_t phrost_ub_write(const char* str, size_t str_length) {
    printf("[PHP] %.*s\n", (int)str_length, str);
    fflush(stdout);
    return str_length;
}

// --- Helper: INI Defaults ---
static void set_ini_defaults(HashTable* configuration_hash) {
    zval ini_value;
    ZVAL_NEW_STR(&ini_value, zend_string_init(ZEND_STRL("-1"), 1));
    zend_hash_str_update(configuration_hash, ZEND_STRL("memory_limit"), &ini_value);
    ZVAL_NEW_STR(&ini_value, zend_string_init(ZEND_STRL("1"), 1));
    zend_hash_str_update(configuration_hash, ZEND_STRL("display_errors"), &ini_value);
    ZVAL_NEW_STR(&ini_value, zend_string_init(ZEND_STRL("E_ALL"), 1));
    zend_hash_str_update(configuration_hash, ZEND_STRL("error_reporting"), &ini_value);
}

// --- Helper: Buffer Resize ---
static void ensure_buffer_capacity(CommandBuffer* buf, size_t needed_size) {
    if (needed_size > buf->capacity) {
        size_t new_cap = (needed_size + 4096) * 2;
        char* new_ptr = (char*)realloc(buf->data, new_cap);
        if (new_ptr) {
            buf->data = new_ptr;
            buf->capacity = new_cap;
            memset(buf->data + buf->length, 0, new_cap - buf->capacity);
        }
        else {
            printf("[PHP Bridge] CRITICAL: Failed to realloc buffer!\n");
        }
    }
}

// ---------------------------------------------------------
// CORE LOGIC: Init PHP
// ---------------------------------------------------------
static bool internal_php_init() {
    printf("[PHP Bridge] Initializing PHP Engine...\n");

    php_embed_module.ini_defaults = set_ini_defaults;
    php_embed_module.ub_write = phrost_ub_write;

    if (php_embed_init(0, NULL) == FAILURE) {
        printf("[PHP Bridge] Failed to init embed SAP.\n");
        return false;
    }

    // Runtime INI
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("log_errors"), 1),
        zend_string_init(ZEND_STRL("1"), 1), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);

    char include_path[PATH_MAX];
    snprintf(include_path, PATH_MAX, ".:%sgame", g_php_base_path);
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("include_path"), 1),
        zend_string_init(include_path, strlen(include_path), 0), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);

    // Load Script
    zend_file_handle file_handle;
    char script_path[PATH_MAX];
    strcpy(script_path, g_php_base_path);
    strcat(script_path, "game/bundle.php");

    zend_stream_init_filename(&file_handle, script_path);

    if (php_stream_open_for_zend_ex(&file_handle, USE_PATH | REPORT_ERRORS | STREAM_OPEN_FOR_INCLUDE) != SUCCESS) {
        printf("[PHP Bridge] Failed to open script: %s\n", script_path);
        return false;
    }

    bool success = true;
    zend_first_try{
        if (!php_execute_script(&file_handle)) {
            success = false;
        }
    } zend_catch{
        success = false;
    } zend_end_try();

    zend_destroy_file_handle(&file_handle);
    return success;
}

// ---------------------------------------------------------
// CORE LOGIC: Run One Frame
// ---------------------------------------------------------
// This function does NOT handle locks. The caller must ensure safety.
static void internal_php_run_frame(ThreadBridge* bridge) {
    zval z_func_name, z_retval;
    zval z_params[3];

    ZVAL_STRING(&z_func_name, "Phrost_Update");
    ZVAL_LONG(&z_params[0], bridge->swift_frame);
    ZVAL_DOUBLE(&z_params[1], bridge->swift_delta);

    if (bridge->swift_event_len > 0) {
        ZVAL_STRINGL(&z_params[2], bridge->swift_event_data, bridge->swift_event_len);
    }
    else {
        ZVAL_EMPTY_STRING(&z_params[2]);
    }

    // Prepare Back Buffer
    CommandBuffer* back = &bridge->back_buffer;
    back->length = 0;

    // Call PHP
    if (call_user_function(EG(function_table), NULL, &z_func_name, &z_retval, 3, z_params) == SUCCESS) {
        if (Z_TYPE(z_retval) == IS_STRING) {
            size_t len = Z_STRLEN(z_retval);
            if (len > 0) {
                ensure_buffer_capacity(back, len + 1);
                memcpy(back->data, Z_STRVAL(z_retval), len);
                back->length = (int32_t)len;
            }
        }
        zval_ptr_dtor(&z_retval);
    }
    else {
        if (EG(exception)) {
            zend_clear_exception();
            printf("[PHP Bridge] Exception in Phrost_Update\n");
        }
    }

    // Clean params
    zval_ptr_dtor(&z_params[2]); // The string
    zval_ptr_dtor(&z_func_name);

    // Swap Buffers (Double Buffering)
    CommandBuffer temp = bridge->front_buffer;
    bridge->front_buffer = bridge->back_buffer;
    bridge->back_buffer = temp;
}


// ---------------------------------------------------------
// MODE A: Worker Thread Loop
// ---------------------------------------------------------
static void* php_thread_main(void* arg) {
    ThreadBridge* bridge = (ThreadBridge*)arg;
    g_bridge = bridge;

    if (!internal_php_init()) {
        // Signal failure
        pthread_mutex_lock(&bridge->mutex);
        bridge->engine_running = false;
        pthread_cond_signal(&bridge->php_to_swift_cond);
        pthread_mutex_unlock(&bridge->mutex);
        return NULL;
    }

    while (true) {
        pthread_mutex_lock(&bridge->mutex);
        while (!bridge->swift_has_data && bridge->engine_running) {
            pthread_cond_wait(&bridge->swift_to_php_cond, &bridge->mutex);
        }

        if (!bridge->engine_running) {
            pthread_mutex_unlock(&bridge->mutex);
            break;
        }

        // NOTE: We keep the lock held? 
        // Ideally, we copy data to local vars and unlock to allow parallelism,
        // BUT since we are doing a strict Frame Sync (Swift waits for PHP),
        // we can just process it. To be safe regarding ZTS, let's unlock.
        // (Assuming internal_php_run_frame reads from bridge fields that Swift promises not to touch now)

        pthread_mutex_unlock(&bridge->mutex);

        // --- RUN PHP ---
        internal_php_run_frame(bridge);

        pthread_mutex_lock(&bridge->mutex);
        bridge->swift_has_data = false; // Consumed
        bridge->php_has_data = true;    // Produced
        pthread_cond_signal(&bridge->php_to_swift_cond);
        pthread_mutex_unlock(&bridge->mutex);
    }

    php_embed_shutdown();
    return NULL;
}

// ---------------------------------------------------------
// PUBLIC API
// ---------------------------------------------------------

int php_thread_start(ThreadBridge* bridge, const char* base_path, bool use_threading) {
    bridge->use_threading = use_threading;
    strcpy(g_php_base_path, base_path);

    // Init synchronization primitives regardless (locks are cheap)
    if (pthread_mutex_init(&bridge->mutex, NULL) != 0) return -1;
    if (pthread_cond_init(&bridge->swift_to_php_cond, NULL) != 0) return -1;
    if (pthread_cond_init(&bridge->php_to_swift_cond, NULL) != 0) return -1;

    // Buffers
    size_t cap = 1024 * 64;
    bridge->back_buffer.data = calloc(1, cap);
    bridge->back_buffer.capacity = cap;
    bridge->front_buffer.data = calloc(1, cap);
    bridge->front_buffer.capacity = cap;

    bridge->engine_running = true;
    bridge->swift_has_data = false;

    if (use_threading) {
        // Start Worker
        if (pthread_create(&bridge->thread_id, NULL, php_thread_main, (void*)bridge) != 0) {
            return -1;
        }
    }
    else {
        // Main Thread Init
        if (!internal_php_init()) {
            return -1;
        }
    }
    return 0;
}

void php_thread_stop(ThreadBridge* bridge) {
    bridge->engine_running = false;

    if (bridge->use_threading) {
        // Signal thread to die
        pthread_mutex_lock(&bridge->mutex);
        pthread_cond_signal(&bridge->swift_to_php_cond);
        pthread_mutex_unlock(&bridge->mutex);

        pthread_join(bridge->thread_id, NULL);
    }
    else {
        // Main thread shutdown
        php_embed_shutdown();
    }

    // Cleanup
    pthread_mutex_destroy(&bridge->mutex);
    pthread_cond_destroy(&bridge->swift_to_php_cond);
    pthread_cond_destroy(&bridge->php_to_swift_cond);

    free(bridge->back_buffer.data);
    free(bridge->front_buffer.data);
}

const char* swift_callback_to_php_bridge(int32_t frame, double delta,
    const char* eventData, int32_t eventLen,
    int32_t* outLen, ThreadBridge* bridge)
{
    // Populate Inputs
    bridge->swift_frame = frame;
    bridge->swift_delta = delta;
    bridge->swift_event_data = eventData;
    bridge->swift_event_len = eventLen;

    if (bridge->use_threading) {
        // --- THREADED MODE ---
        pthread_mutex_lock(&bridge->mutex);
        bridge->swift_has_data = true;
        bridge->php_has_data = false;

        // Wake Worker
        pthread_cond_signal(&bridge->swift_to_php_cond);

        // Wait for Worker
        while (!bridge->php_has_data && bridge->engine_running) {
            pthread_cond_wait(&bridge->php_to_swift_cond, &bridge->mutex);
        }
        pthread_mutex_unlock(&bridge->mutex);
    }
    else {
        // --- DIRECT MODE (No Locks) ---
        internal_php_run_frame(bridge);
    }

    if (!bridge->engine_running) {
        *outLen = 0;
        return NULL;
    }

    // Return Front Buffer
    *outLen = bridge->front_buffer.length;
    return bridge->front_buffer.data;
}