#include <stdio.h>
#include <stdlib.h> // For malloc, free
#include <string.h> // For memcpy
#include "phrost.h"
#include "events.h"
#include "event_packer.h"
#include "php_thread.h"

// --- Platform-specific includes ---
#ifdef __APPLE__
#include <mach-o/dyld.h>
#include <limits.h>
#elif defined(_WIN32)
#include <windows.h>
#ifndef PATH_MAX
#define PATH_MAX MAX_PATH
#endif
#else
#include <limits.h>
#include <unistd.h>
#endif

static ThreadBridge g_thread_bridge;
static char g_base_path[PATH_MAX];

/**
 * @brief Debug walker
 */
void debug_walk_php_packet(const char* data, size_t totalLen) {
    EventUnpacker unpacker;
    unpacker_init(&unpacker, data, (int32_t)totalLen);

    // 1. Read Channel Count (4 bytes)
    uint32_t channelCount = 0;
    if (!unpacker_read_fixed(&unpacker, &channelCount, sizeof(uint32_t))) return;

    // SKIP PADDING: 4 bytes (Matches PHP "Vx4")
    unpacker_skip(&unpacker, 4);

    printf("[C Walk Debug] Packet contains %u channels.\n", channelCount);

    struct ChannelIndex { uint32_t id; uint32_t size; };
    struct ChannelIndex* indices = malloc(channelCount * sizeof(struct ChannelIndex));

    for (uint32_t i = 0; i < channelCount; i++) {
        unpacker_read_fixed(&unpacker, &indices[i].id, sizeof(uint32_t));
        unpacker_read_fixed(&unpacker, &indices[i].size, sizeof(uint32_t));
    }

    for (uint32_t i = 0; i < channelCount; i++) {
        printf("  > Channel %u (Total Size: %u bytes)\n", indices[i].id, indices[i].size);

        const char* channelDataPtr = (const char*)(unpacker.buffer + unpacker.offset);
        unpacker_skip(&unpacker, indices[i].size);

        EventUnpacker chUnpacker;
        unpacker_init(&chUnpacker, channelDataPtr, indices[i].size);

        // 2. Read Command Count (4 bytes)
        uint32_t commandCount = 0;
        if (!unpacker_read_fixed(&chUnpacker, &commandCount, sizeof(uint32_t))) continue;

        printf("  > %u Events\n", commandCount);

        // SKIP PADDING: 4 bytes (Matches PHP "Vx4")
        unpacker_skip(&chUnpacker, 4);

        while (chUnpacker.offset < chUnpacker.length) {
            uint32_t eventID;
            uint64_t timestamp;

            if (!unpacker_read_fixed(&chUnpacker, &eventID, sizeof(uint32_t))) break;
            if (!unpacker_read_fixed(&chUnpacker, &timestamp, sizeof(uint64_t))) break;

            // SKIP PADDING: 4 bytes (Matches PHP "VQx4")
            unpacker_skip(&chUnpacker, 4);

            size_t payloadSize = get_event_payload_size((PhrostEventID)eventID);

            // --- GENERIC EVENT PRINT ---
            printf("    - Event %u: Timestamp=%llu PayloadBase=%zu\n", eventID, timestamp, payloadSize);

            if (payloadSize > 0) {
                uint8_t headerBuffer[256];
                if (!unpacker_read_fixed(&chUnpacker, headerBuffer, payloadSize)) break;

                size_t extraSkip = 0;

                // --- Handle Variable Strings + Padding ---
                if (eventID == EVENT_TEXT_ADD) {
                    PackedTextAddEvent* e = (PackedTextAddEvent*)headerBuffer;
                    size_t fpPad = (8 - (e->fontPathLength % 8)) % 8;
                    size_t txtPad = (8 - (e->textLength % 8)) % 8;

                    // Peek at strings (Pointer arithmetic)
                    const char* fontPtr = (const char*)(chUnpacker.buffer + chUnpacker.offset);
                    const char* txtPtr = (const char*)(chUnpacker.buffer + chUnpacker.offset + e->fontPathLength + fpPad);

                    printf("      | TextAdd: Font='%.*s' Text='%.*s'\n",
                        e->fontPathLength, fontPtr,
                        e->textLength, txtPtr);

                    extraSkip = e->fontPathLength + fpPad + e->textLength + txtPad;
                }
                else if (eventID == EVENT_TEXT_SET_STRING) {
                    PackedTextSetStringEvent* e = (PackedTextSetStringEvent*)headerBuffer;
                    size_t txtPad = (8 - (e->textLength % 8)) % 8;

                    const char* txtPtr = (const char*)(chUnpacker.buffer + chUnpacker.offset);
                    printf("      | TextSet: '%.*s'\n", e->textLength, txtPtr);

                    extraSkip = e->textLength + txtPad;
                }
                else if (eventID == EVENT_SPRITE_TEXTURE_LOAD) {
                    PackedTextureLoadHeaderEvent* e = (PackedTextureLoadHeaderEvent*)headerBuffer;
                    size_t strPad = (8 - (e->filenameLength % 8)) % 8;

                    const char* strPtr = (const char*)(chUnpacker.buffer + chUnpacker.offset);
                    printf("      | TexLoad: '%.*s' (Len: %u)\n", e->filenameLength, strPtr, e->filenameLength);

                    extraSkip = e->filenameLength + strPad;
                }
                else if (eventID == EVENT_AUDIO_LOAD) {
                    // Audio Header is 4 bytes (length). PHP adds 4 bytes padding.
                    // We MUST skip that extra 4 bytes BEFORE reading string.
                    unpacker_skip(&chUnpacker, 4);

                    PackedAudioLoadEvent* e = (PackedAudioLoadEvent*)headerBuffer;
                    size_t strPad = (8 - (e->pathLength % 8)) % 8;

                    const char* strPtr = (const char*)(chUnpacker.buffer + chUnpacker.offset);
                    printf("      | AudioLoad: '%.*s' (Len: %u)\n", e->pathLength, strPtr, e->pathLength);

                    extraSkip = e->pathLength + strPad;
                }
                else if (eventID == EVENT_PLUGIN_LOAD) {
                    // Plugin Header is 8 bytes. PHP writes 8 bytes.
                    // No padding to skip *before* the string.

                    PackedPluginLoadHeaderEvent* e = (PackedPluginLoadHeaderEvent*)headerBuffer;
                    size_t strPad = (8 - (e->pathLength % 8)) % 8;

                    const char* strPtr = (const char*)(chUnpacker.buffer + chUnpacker.offset);
                    printf("      | PluginLoad: '%.*s' (Len: %u)\n", e->pathLength, strPtr, e->pathLength);

                    extraSkip = e->pathLength + strPad;
                }

                if (extraSkip > 0) {
                    unpacker_skip(&chUnpacker, extraSkip);
                }
            }

            // ALIGNMENT: Skip trailing padding for the whole event
            size_t currentOffset = chUnpacker.offset;
            size_t pad = (8 - (currentOffset % 8)) % 8;
            unpacker_skip(&chUnpacker, pad);
        }
    }
    free(indices);
}

/**
 * @brief C Wrapper for Swift Callback
 */
const char* my_game_update(int32_t frame, double delta, const char* eventData, int32_t eventLen, int32_t* outLen) {
    // Call the Pipelined Bridge
    const char* outData = swift_callback_to_php_bridge(frame, delta, eventData, eventLen, outLen, &g_thread_bridge);

    // Debug: Uncomment to see packet flow
    // if (*outLen > 0) debug_walk_php_packet(outData, *outLen);

    return outData;
}

void setup_base_path() {
#ifdef _WIN32
    if (GetModuleFileNameA(NULL, g_base_path, PATH_MAX) == 0) {
        strcpy(g_base_path, ".\\");
        return;
    }
    char* last_slash = strrchr(g_base_path, '\\');
    if (last_slash != NULL) *(last_slash + 1) = '\0';
    else strcpy(g_base_path, ".\\");
#elif defined(__APPLE__)
    char exe_path_buf[PATH_MAX];
    uint32_t size = sizeof(exe_path_buf);
    if (_NSGetExecutablePath(exe_path_buf, &size) != 0) {
        strcpy(g_base_path, "./");
        return;
    }
    char* last_slash = strrchr(exe_path_buf, '/');
    if (last_slash != NULL) {
        *(last_slash + 1) = '\0';
        strcpy(g_base_path, exe_path_buf);
    } else {
        strcpy(g_base_path, "./");
    }
#endif
    printf("Base path set to: %s\n", g_base_path);
}

int main() {
    printf("Initializing C Host...\n");
    setup_base_path();

    // --- 1. Start the PHP Logic Thread (PIPELINED) ---
    bool use_threading = false; // Enable Pipelining

    if (php_thread_start(&g_thread_bridge, g_base_path, use_threading) != 0) {
        printf("CRITICAL: Failed to start PHP engine.\n");
        return -1;
    }
    printf("[Main Thread] PHP thread started.\n");

    // --- 2. Create the Swift Engine Instance ---
    PhrostEngineRef engine = phrost_create_instance("Phrost Engine (Pipelined)", 800, 600);

    if (!engine) {
        printf("[Main Thread] Failed to create Swift engine\n");
        php_thread_stop(&g_thread_bridge);
        return 1;
    }

    // --- 3. Run the Swift Engine ---
    printf("[Main Thread] Starting engine run loop...\n");
    phrost_run_loop(engine, my_game_update);
    printf("[Main Thread] Engine run loop finished.\n");

    // --- 4. Cleanup ---
    php_thread_stop(&g_thread_bridge);
    phrost_destroy_instance(engine);
    printf("[Main Thread] Engine shutdown.\n");

    return 0;
}
