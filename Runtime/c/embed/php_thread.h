#ifndef PHP_THREAD_H
#define PHP_THREAD_H

#include <stdbool.h>
#include "pthread_shim.h"
#include "event_packer.h"

#ifdef _WIN32
#include <winsock2.h> 
#include <windows.h>
#endif

#include <main/php.h>
#include <zend.h>
#include <main/php_ini.h>
#include <ext/standard/info.h>
#include <sapi/embed/php_embed.h>
#include <zend_exceptions.h>

typedef struct {
    char* data;
    size_t capacity;
    int32_t length;
} CommandBuffer;

typedef struct {
    // Config
    bool use_threading; // NEW: Toggle threading vs main thread

    // Threading Primitives
    pthread_t       thread_id;
    pthread_mutex_t mutex;
    pthread_cond_t  swift_to_php_cond;
    pthread_cond_t  php_to_swift_cond;

    // Data Inputs (Swift -> PHP)
    const char* swift_event_data;
    int32_t     swift_event_len;
    int32_t     swift_frame;
    double      swift_delta;
    bool        swift_has_data;

    // Outputs (PHP -> Swift)
    CommandBuffer back_buffer;
    CommandBuffer front_buffer;

    bool        php_has_data;
    bool        engine_running;
} ThreadBridge;

/**
 * @brief Initializes PHP.
 * @param use_threading If true, spawns a worker thread. If false, runs on main thread.
 */
int php_thread_start(ThreadBridge* bridge, const char* base_path, bool use_threading);

void php_thread_stop(ThreadBridge* bridge);

const char* swift_callback_to_php_bridge(int32_t frame, double delta,
    const char* eventData, int32_t eventLen,
    int32_t* outLen, ThreadBridge* bridge);

#endif // PHP_THREAD_H