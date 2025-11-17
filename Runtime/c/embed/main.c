#include <stdio.h>
#include <stdlib.h> // For malloc, free
#include <string.h> // For memcpy
#include "phrost.h"
#include "../plugin/events.h"
#include "../plugin/event_packer.h"

// --- NEW INCLUDES ---
#include <mach-o/dyld.h> // For _NSGetExecutablePath
#include <limits.h>     // For PATH_MAX

// --- Define Channels Enum (from Zig) ---
typedef enum {
    CHANNEL_RENDERER = 0,
    CHANNEL_INPUT = 1,
    CHANNEL_PHYSICS = 2,
    CHANNEL_AUDIO = 3,
    CHANNEL_GUI = 4,
    CHANNEL_WINDOW = 5,
    CHANNEL_SCRIPT = 6,
} PhrostChannelID;

// --- Global Buffers (like in Zig) ---
static uint8_t g_command_buffer_render[COMMAND_PACKER_CAPACITY];
static uint8_t g_command_buffer_window[COMMAND_PACKER_CAPACITY];
static uint8_t g_final_buffer[FINAL_BUFFER_CAPACITY];

// --- Global Packers ---
static CommandPacker g_packer_render;
static CommandPacker g_packer_window;

// --- Global World State ---
static double g_mouse_x = 0;
static double g_mouse_y = 0;
static char g_base_path[PATH_MAX]; // --- NEW: To store the executable's directory ---

// The callback function implementation
const char* my_game_update(int32_t frame, double delta, const char* eventData, int32_t eventLen, int32_t* outLen) {

    // --- 1. Reset packers for this frame ---
    packer_reset(&g_packer_render);
    packer_reset(&g_packer_window);

    // --- 2. Process Incoming Events (from Swift) ---
    EventUnpacker unpacker;
    unpacker_init(&unpacker, eventData, eventLen);

    uint32_t event_count;
    if (!unpacker_read_fixed(&unpacker, &event_count, sizeof(event_count))) {
        event_count = 0; // No events or bad data
    }

    // --- This is your 'flag' variable idea ---
    bool continue_processing = true;

    for (uint32_t i = 0; i < event_count && continue_processing; ++i) {
        uint32_t event_id_raw;
        uint64_t timestamp;

        if (!unpacker_read_fixed(&unpacker, &event_id_raw, sizeof(event_id_raw))) {
            continue_processing = false;
            break;
        }
        if (!unpacker_read_fixed(&unpacker, &timestamp, sizeof(timestamp))) {
            continue_processing = false;
            break;
        }

        PhrostEventID event_id = (PhrostEventID)event_id_raw;

        switch (event_id) {
            case EVENT_INPUT_MOUSEMOTION: {
                PackedMouseMotionEvent event;
                if (!unpacker_read_fixed(&unpacker, &event, sizeof(event))) {
                    continue_processing = false;
                } else {
                    g_mouse_x = event.x;
                    g_mouse_y = event.y;
                }
                break;
            }

            // --- ADDED: Handlers for variable-sized events we must skip ---
            case EVENT_SPRITE_TEXTURE_LOAD: {
                PackedTextureLoadHeaderEvent header;
                if (!unpacker_read_fixed(&unpacker, &header, sizeof(header)) ||
                    !unpacker_skip(&unpacker, header.filenameLength)) {
                    continue_processing = false;
                }
                break;
            }
            case EVENT_TEXT_SET_STRING: {
                PackedTextSetStringEvent header;
                if (!unpacker_read_fixed(&unpacker, &header, sizeof(header)) ||
                    !unpacker_skip(&unpacker, header.textLength)) {
                    continue_processing = false;
                }
                break;
            }
            case EVENT_TEXT_ADD: {
                PackedTextAddEvent header;
                 if (!unpacker_read_fixed(&unpacker, &header, sizeof(header)) ||
                     !unpacker_skip(&unpacker, header.fontPathLength) ||
                     !unpacker_skip(&unpacker, header.textLength)) {
                    continue_processing = false;
                 }
                 break;
            }
            // --- (Add other variable event-types here) ---


            // --- Default handler for *all other events* ---
            default: {
                // Get the size of the event's fixed payload
                size_t payload_size = get_event_payload_size(event_id);

                if (payload_size > 0) {
                    // We don't recognize it, but we know its size.
                    // Safely skip its payload so we can read the next event.
                    if (!unpacker_skip(&unpacker, payload_size)) {
                        continue_processing = false; // Failed to skip, abort
                    }
                } else {
                    // This is a zero-payload event (like AUDIO_STOP_ALL)
                    // or a *truly* unknown event (not in our map).
                    // In either case, there's nothing to skip.
                }
                break;
            }
        }
    }


    // --- 3. Run "Game Logic" & Pack Commands (to Swift) ---
    PackedWindowTitleEvent title_event;
    snprintf(title_event.title, 256, "C Host | Frame: %d", frame);
    packer_pack_event(&g_packer_window, EVENT_WINDOW_TITLE, &title_event, sizeof(title_event));

    if (frame == 10) {
        PackedSpriteAddEvent add_event = {
            .id1 = 1, .id2 = 0,
            .positionX = g_mouse_x, .positionY = g_mouse_y, .positionZ = 0,
            .scaleX = 1.0, .scaleY = 1.0, .scaleZ = 1.0,
            .sizeW = 32.0, .sizeH = 32.0,
            .rotationX = 0, .rotationY = 0, .rotationZ = 0,
            .r = 255, .g = 100, .b = 100, .a = 255,
            ._padding = 0,
            .speedX = 50.0, .speedY = 50.0
        };
        packer_pack_event(&g_packer_render, EVENT_SPRITE_ADD, &add_event, sizeof(add_event));

        // --- UPDATED: Use absolute path ---
        char texture_path_buffer[PATH_MAX];
        strcpy(texture_path_buffer, g_base_path);
        strcat(texture_path_buffer, "assets/wabbit_alpha.png");

        const char* texture_path = texture_path_buffer; // Use the full path
        // ---

        PackedTextureLoadHeaderEvent tex_header = {
            .id1 = 1, .id2 = 0,
            .filenameLength = (uint32_t)strlen(texture_path),
            ._padding = 0
        };
        packer_pack_variable(&g_packer_render, EVENT_SPRITE_TEXTURE_LOAD,
                             &tex_header, sizeof(tex_header),
                             texture_path, strlen(texture_path));
    }


    // --- 4. Finalize Packers ---
    packer_finalize(&g_packer_render);
    packer_finalize(&g_packer_window);

    // --- 5. Combine Channels ---
    ChannelInput channels[] = {
        { &g_packer_render, CHANNEL_RENDERER },
        { &g_packer_window, CHANNEL_WINDOW }
    };

    size_t final_size = channel_packer_finalize(g_final_buffer, FINAL_BUFFER_CAPACITY, channels, 2);

    if (final_size == 0) {
        *outLen = 0;
        return NULL;
    }

    char* return_buffer = (char*)malloc(final_size);
    if (!return_buffer) {
        *outLen = 0;
        return NULL;
    }

    memcpy(return_buffer, g_final_buffer, final_size);
    *outLen = (int32_t)final_size;

    return return_buffer;
}

// --- NEW FUNCTION ---
void setup_base_path() {
    char exe_path_buf[PATH_MAX];
    uint32_t size = sizeof(exe_path_buf);

    if (_NSGetExecutablePath(exe_path_buf, &size) != 0) {
        // Failed to get path, fall back to relative
        printf("Warning: Could not get executable path. Using relative path.\n");
        strcpy(g_base_path, "./");
        return;
    }

    // Find the last '/' to get the directory
    char* last_slash = strrchr(exe_path_buf, '/');
    if (last_slash != NULL) {
        *(last_slash + 1) = '\0'; // Null-terminate after the slash
        strcpy(g_base_path, exe_path_buf);
    } else {
        // No slash found? Should be impossible, but fallback.
        strcpy(g_base_path, "./");
    }

    printf("Base path set to: %s\n", g_base_path);
}


int main() {
    printf("Initializing Swift Engine from C...\n");

    // --- NEW: Set the global base path ---
    setup_base_path();

    // --- Initialize global packers once ---
    packer_init(&g_packer_render, g_command_buffer_render, COMMAND_PACKER_CAPACITY);
    packer_init(&g_packer_window, g_command_buffer_window, COMMAND_PACKER_CAPACITY);

    // 1. Create
    PhrostEngineRef engine = phrost_create_instance("Embedded Phrost", 800, 600);

    if (!engine) {
        printf("Failed to create engine\n");
        return 1;
    }

    // 2. Run (This blocks until window closes)
    phrost_run_loop(engine, my_game_update);

    // 3. Cleanup
    phrost_destroy_instance(engine);
    printf("Engine shutdown.\n");

    return 0;
}
