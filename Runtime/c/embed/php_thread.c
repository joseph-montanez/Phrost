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
    // printf("[PHP] %.*s\n", (int)str_length, str);
    // fflush(stdout);
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
        } else {
            printf("[PHP Bridge] CRITICAL: Failed to realloc buffer!\n");
        }
    }
}

// --- Helper: Packet Merging ---
static void append_input_packet(CommandBuffer* dst, const char* src, int32_t src_len) {
    if (src_len < 8) return;

    if (dst->length == 0) {
        ensure_buffer_capacity(dst, src_len);
        memcpy(dst->data, src, src_len);
        dst->length = src_len;
        return;
    }

    uint32_t* dst_count_ptr = (uint32_t*)dst->data;
    const uint32_t* src_count_ptr = (const uint32_t*)src;

    // Merge counts
    *dst_count_ptr = *dst_count_ptr + *src_count_ptr;

    // Append Body (Skip 8 byte header of src)
    size_t src_body_len = src_len - 8;
    ensure_buffer_capacity(dst, dst->length + src_body_len);
    memcpy(dst->data + dst->length, src + 8, src_body_len);
    dst->length += (int32_t)src_body_len;
}

// ---------------------------------------------------------
// CORE LOGIC: Init PHP
// ---------------------------------------------------------
static bool internal_php_init() {
    printf("[PHP Bridge] Initializing PHP Engine...\n");
    php_embed_module.ini_defaults = set_ini_defaults;
    php_embed_module.ub_write = phrost_ub_write;

    if (php_embed_init(0, NULL) == FAILURE) {
        printf("[PHP Bridge] Failed to init embed SAPI.\n");
        return false;
    }

    zend_alter_ini_entry(zend_string_init(ZEND_STRL("log_errors"), 1),
        zend_string_init(ZEND_STRL("1"), 1), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);

    char include_path[PATH_MAX];
    snprintf(include_path, PATH_MAX, ".:%sgame", g_php_base_path);
    zend_alter_ini_entry(zend_string_init(ZEND_STRL("include_path"), 1),
        zend_string_init(include_path, strlen(include_path), 0), ZEND_INI_USER, ZEND_INI_STAGE_RUNTIME);

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
static void internal_php_run_frame(ThreadBridge* bridge) {
    zval z_func_name, z_retval;
    zval z_params[3];

    ZVAL_STRING(&z_func_name, "Phrost_Update");
    ZVAL_LONG(&z_params[0], bridge->proc_frame);
    ZVAL_DOUBLE(&z_params[1], bridge->proc_delta);

    if (bridge->input_proc.length > 0) {
        ZVAL_STRINGL(&z_params[2], bridge->input_proc.data, bridge->input_proc.length);
    } else {
        ZVAL_EMPTY_STRING(&z_params[2]);
    }

    CommandBuffer* back = &bridge->back_buffer;
    back->length = 0;

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
    } else {
        if (EG(exception)) {
            zend_clear_exception();
            printf("[PHP Bridge] Exception in Phrost_Update\n");
        }
    }
    zval_ptr_dtor(&z_params[2]);
    zval_ptr_dtor(&z_func_name);
}

// ---------------------------------------------------------
// WORKER THREAD
// ---------------------------------------------------------
static void* php_thread_main(void* arg) {
    ThreadBridge* bridge = (ThreadBridge*)arg;
    g_bridge = bridge;

    if (!internal_php_init()) {
        pthread_mutex_lock(&bridge->mutex);
        bridge->engine_running = false;
        pthread_cond_signal(&bridge->php_to_swift_cond);
        pthread_mutex_unlock(&bridge->mutex);
        return NULL;
    }

    while (true) {
        pthread_mutex_lock(&bridge->mutex);

        while (!bridge->input_ready && bridge->engine_running) {
            pthread_cond_wait(&bridge->swift_to_php_cond, &bridge->mutex);
        }

        // Wait for Output Slot to be free (Backpressure)
        while (bridge->output_ready && bridge->engine_running) {
            pthread_cond_wait(&bridge->swift_to_php_cond, &bridge->mutex);
        }

        if (!bridge->engine_running) {
            pthread_mutex_unlock(&bridge->mutex);
            break;
        }

        // Swap Input
        CommandBuffer temp = bridge->input_accum;
        bridge->input_accum = bridge->input_proc;
        bridge->input_proc = temp;

        bridge->proc_frame = bridge->input_frame;
        bridge->proc_delta = bridge->input_delta;

        // RESET Accumulators
        bridge->input_delta = 0.0;
        bridge->input_ready = false;
        bridge->pending_frames = 0; // [FIX] Reset the throttle counter

        // Signal Swift that we have cleared the queue
        pthread_cond_signal(&bridge->php_to_swift_cond);

        pthread_mutex_unlock(&bridge->mutex);

        // Run PHP
        internal_php_run_frame(bridge);

        bridge->input_proc.length = 0;

        // Publish Output
        pthread_mutex_lock(&bridge->mutex);
        bridge->output_ready = true;
        pthread_cond_signal(&bridge->php_to_swift_cond); // Wake Swift
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

    if (pthread_mutex_init(&bridge->mutex, NULL) != 0) return -1;
    if (pthread_cond_init(&bridge->swift_to_php_cond, NULL) != 0) return -1;
    if (pthread_cond_init(&bridge->php_to_swift_cond, NULL) != 0) return -1;

    size_t cap = 1024 * 64;
    bridge->back_buffer.data = calloc(1, cap);
    bridge->back_buffer.capacity = cap;
    bridge->front_buffer.data = calloc(1, cap);
    bridge->front_buffer.capacity = cap;

    bridge->input_accum.data = calloc(1, cap);
    bridge->input_accum.capacity = cap;
    bridge->input_proc.data = calloc(1, cap);
    bridge->input_proc.capacity = cap;

    bridge->engine_running = true;
    bridge->input_ready = false;
    bridge->output_ready = false;
    bridge->first_frame_ready = false;
    bridge->pending_frames = 0; // Init throttle

    if (use_threading) {
        if (pthread_create(&bridge->thread_id, NULL, php_thread_main, (void*)bridge) != 0) {
            return -1;
        }
    } else {
        if (!internal_php_init()) return -1;
    }
    return 0;
}

void php_thread_stop(ThreadBridge* bridge) {
    bridge->engine_running = false;

    if (bridge->use_threading) {
        pthread_mutex_lock(&bridge->mutex);
        pthread_cond_signal(&bridge->swift_to_php_cond);
        pthread_mutex_unlock(&bridge->mutex);
        pthread_join(bridge->thread_id, NULL);
    } else {
        php_embed_shutdown();
    }

    pthread_mutex_destroy(&bridge->mutex);
    pthread_cond_destroy(&bridge->swift_to_php_cond);
    pthread_cond_destroy(&bridge->php_to_swift_cond);

    free(bridge->back_buffer.data);
    free(bridge->front_buffer.data);
    free(bridge->input_accum.data);
    free(bridge->input_proc.data);
}

const char* swift_callback_to_php_bridge(int32_t frame, double delta,
    const char* eventData, int32_t eventLen,
    int32_t* outLen, ThreadBridge* bridge)
{
    if (!bridge->use_threading) {
        // Sync Fallback
        bridge->proc_frame = frame;
        bridge->proc_delta = delta;
        ensure_buffer_capacity(&bridge->input_proc, eventLen);
        memcpy(bridge->input_proc.data, eventData, eventLen);
        bridge->input_proc.length = eventLen;
        internal_php_run_frame(bridge);
        bridge->input_proc.length = 0;
        ensure_buffer_capacity(&bridge->front_buffer, bridge->back_buffer.length);
        memcpy(bridge->front_buffer.data, bridge->back_buffer.data, bridge->back_buffer.length);
        bridge->front_buffer.length = bridge->back_buffer.length;
        *outLen = bridge->front_buffer.length;
        return bridge->front_buffer.data;
    }

    // --- THREADED PIPELINE MODE ---
    pthread_mutex_lock(&bridge->mutex);

    // [FIX] THROTTLING / BACKPRESSURE
    // If PHP is >3 frames behind, we stop accumulating and wait.
    // This prevents memory explosion and thrashing.
    while (bridge->pending_frames > 3 && bridge->engine_running) {
        pthread_cond_wait(&bridge->php_to_swift_cond, &bridge->mutex);
    }

    // 1. Accumulate Input
    bridge->input_frame = frame;
    bridge->input_delta += delta;
    bridge->pending_frames++; // Track pending work

    append_input_packet(&bridge->input_accum, eventData, eventLen);
    bridge->input_ready = true;
    pthread_cond_signal(&bridge->swift_to_php_cond);

    // 2. Output Check
    bool new_data_available = false;
    // --- FIX: DEADLOCK PREVENTION LOOP ---
    // While we are throttled, we must STILL process output.
    // If we don't, PHP freezes waiting for us to take the output,
    // and never gets around to resetting pending_frames.
    while (bridge->pending_frames > 3 && bridge->engine_running) {

        // Check for output while waiting
        if (bridge->output_ready) {
            CommandBuffer temp = bridge->front_buffer;
            bridge->front_buffer = bridge->back_buffer;
            bridge->back_buffer = temp;
            bridge->output_ready = false;

            // Unblock PHP so it can process the pending frames!
            pthread_cond_signal(&bridge->swift_to_php_cond);

            new_data_available = true;
        }

        // Wait for signal (PHP signals when output is ready OR when pending_frames is reset)
        pthread_cond_wait(&bridge->php_to_swift_cond, &bridge->mutex);
    }

    // 1. Accumulate Input (Now safe to proceed)
    bridge->input_frame = frame;
    bridge->input_delta += delta;
    bridge->pending_frames++;

    append_input_packet(&bridge->input_accum, eventData, eventLen);
    bridge->input_ready = true;
    pthread_cond_signal(&bridge->swift_to_php_cond);

    // 2. Standard Output Check (If we didn't already get it in the loop)
    if (!new_data_available && bridge->output_ready) {
        CommandBuffer temp = bridge->front_buffer;
        bridge->front_buffer = bridge->back_buffer;
        bridge->back_buffer = temp;
        bridge->output_ready = false;
        pthread_cond_signal(&bridge->swift_to_php_cond);
        new_data_available = true;
    }

    // 3. First Frame Sync
    if (!bridge->first_frame_ready) {
        while (!bridge->output_ready && bridge->engine_running) {
            pthread_cond_wait(&bridge->php_to_swift_cond, &bridge->mutex);
        }
        bridge->first_frame_ready = true;
        CommandBuffer temp = bridge->front_buffer;
        bridge->front_buffer = bridge->back_buffer;
        bridge->back_buffer = temp;
        bridge->output_ready = false;
        pthread_cond_signal(&bridge->swift_to_php_cond);
        new_data_available = true;
    }

    pthread_mutex_unlock(&bridge->mutex);

    if (!bridge->engine_running) {
        *outLen = 0;
        return NULL;
    }

    if (new_data_available) {
        *outLen = bridge->front_buffer.length;
    } else {
        *outLen = 0;
    }

    return bridge->front_buffer.data;
}
