#ifndef PHP_THREAD_H
#define PHP_THREAD_H

#include <stdbool.h>
#include <pthread.h>
#include "event_packer.h" // For ChannelInput

// --- PHP Embed Headers ---
// Note: We use C-style includes for a .c file
#include <main/php.h>
#include <zend.h>
#include <main/php_ini.h>
#include <ext/standard/info.h>
#include <sapi/embed/php_embed.h>
#include <zend_exceptions.h>
// --- End PHP Headers ---


/**
 * @brief Thread-safe data bridge between the Swift/Main thread
 * and the PHP logic thread.
 */
typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t  swift_to_php_cond; // Swift has new events for PHP
    pthread_cond_t  php_to_swift_cond; // PHP has new commands for Swift

    // Data from Swift -> PHP
    const char* swift_event_data;
    int32_t     swift_event_len;
    int32_t     swift_frame;
    double      swift_delta;
    bool        swift_has_data;

    // Data from PHP -> Swift
    char* php_command_data;
    int32_t     php_command_len;
    bool        php_has_data;

    // Control flag
    bool        engine_running;

} ThreadBridge;

/**
 * @brief Initializes the PHP thread and all thread-safe structures.
 *
 * @param bridge A pointer to the ThreadBridge struct to initialize.
 * @param base_path The absolute path to the executable's directory.
 * @return 0 on success, non-zero on failure.
 */
int php_thread_start(ThreadBridge* bridge, const char* base_path);

/**
 * @brief Signals the PHP thread to shut down and joins it.
 *
 * @param bridge A pointer to the ThreadBridge struct.
 */
void php_thread_stop(ThreadBridge* bridge);

/**
 * @brief The C callback called *by Swift* (on the Swift/Main thread).
 * This function passes event data to the PHP thread and waits for command data.
 */
const char* swift_callback_to_php_bridge(int32_t frame, double delta,
                                         const char* eventData, int32_t eventLen,
                                         int32_t* outLen, ThreadBridge* bridge);

#endif // PHP_THREAD_H
