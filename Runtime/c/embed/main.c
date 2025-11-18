#include <stdio.h>
#include <stdlib.h> // For malloc, free
#include <string.h> // For memcpy
#include "phrost.h"
#include "events.h"
#include "event_packer.h"
#include "php_thread.h"  // --- NEW ---

// --- NEW INCLUDES ---
#include <mach-o/dyld.h> // For _NSGetExecutablePath
#include <limits.h>     // For PATH_MAX

// --- Global Thread Bridge ---
static ThreadBridge g_thread_bridge;

// --- Global Base Path ---
static char g_base_path[PATH_MAX];

/**
 * @brief This is the C function that Swift calls *from its thread*.
 * It is now just a wrapper that passes data to/from the PHP thread.
 */
const char* my_game_update(int32_t frame, double delta, const char* eventData, int32_t eventLen, int32_t* outLen) {
    // Use the bridge function
    //
    return swift_callback_to_php_bridge(frame, delta, eventData, eventLen, outLen, &g_thread_bridge);
}

void setup_base_path() {
    char exe_path_buf[PATH_MAX];
    uint32_t size = sizeof(exe_path_buf);

    if (_NSGetExecutablePath(exe_path_buf, &size) != 0) {
        printf("Warning: Could not get executable path. Using relative path.\n");
        strcpy(g_base_path, "./");
        return;
    }

    char* last_slash = strrchr(exe_path_buf, '/');
    if (last_slash != NULL) {
        *(last_slash + 1) = '\0'; // Null-terminate after the slash
        strcpy(g_base_path, exe_path_buf);
    } else {
        strcpy(g_base_path, "./");
    }

    printf("Base path set to: %s\n", g_base_path);
}


int main() {
    printf("Initializing C Host...\n");

    setup_base_path();

    // --- 1. Start the PHP Logic Thread ---
    if (php_thread_start(&g_thread_bridge, g_base_path) != 0) {
        printf("CRITICAL: Failed to start PHP thread. Exiting.\n");
        return -1;
    }
    printf("[Main Thread] PHP thread started.\n");


    // --- 2. Create the Swift Engine Instance ---
    PhrostEngineRef engine = phrost_create_instance("Embedded Phrost (PHP Threaded)", 800, 600);

    if (!engine) {
        printf("[Main Thread] Failed to create Swift engine\n");
        php_thread_stop(&g_thread_bridge);
        return 1;
    }
    printf("[Main Thread] Swift engine created.\n");

    // --- 3. Run the Swift Engine (This blocks the main thread) ---
    // The engine will call 'my_game_update', which now bridges
    // to the running PHP thread.
    printf("[Main Thread] Starting engine run loop...\n");
    phrost_run_loop(engine, my_game_update);
    printf("[Main Thread] Engine run loop finished.\n");


    // --- 4. Cleanup ---
    php_thread_stop(&g_thread_bridge);
    phrost_destroy_instance(engine);
    printf("[Main Thread] Engine shutdown.\n");

    return 0;
}
