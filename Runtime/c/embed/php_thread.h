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
    bool use_threading;

    // Threading Primitives
    pthread_t       thread_id;
    pthread_mutex_t mutex;
    pthread_cond_t  swift_to_php_cond; // Signal: "Input Ready"
    pthread_cond_t  php_to_swift_cond; // Signal: "Output Ready"

    // --- PIPELINE BUFFERS ---

    // 1. Input Buffers (Double Buffered)
    CommandBuffer input_accum; // Swift writes here (Accumulator)
    CommandBuffer input_proc;  // PHP reads here (Processor)

    int32_t       input_frame; // Latest frame info from Swift
    double        input_delta;

    int32_t       proc_frame;  // Snapshot of frame info for PHP
    double        proc_delta;

    bool          input_ready; // True when Accumulator has data

    // 2. Output Buffers (Double Buffered)
    CommandBuffer back_buffer;
    CommandBuffer front_buffer;
    bool          output_ready;

    // 3. State Flags
    bool        engine_running;
    bool        first_frame_ready;

} ThreadBridge;

int php_thread_start(ThreadBridge* bridge, const char* base_path, bool use_threading);
void php_thread_stop(ThreadBridge* bridge);

const char* swift_callback_to_php_bridge(int32_t frame, double delta,
    const char* eventData, int32_t eventLen,
    int32_t* outLen, ThreadBridge* bridge);

#endif // PHP_THREAD_H
