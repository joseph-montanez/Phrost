#ifndef PHROST_ENGINE_H
#define PHROST_ENGINE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer definition (C doesn't need to know what's inside)
typedef void* PhrostEngineRef;

// Callback signature matches the @convention(c) in Swift
// Returns: pointer to command data (char*).
// IMPORTANT: The C host must ensure this pointer remains valid until the next frame or handle memory carefully.
typedef const char* (*PhrostUpdateCallback)(
    int32_t frameCount,
    double deltaSec,
    const char* eventData,
    int32_t eventLen,
    int32_t* outCommandLen
);

// --- API ---

// Creates the engine instance
PhrostEngineRef phrost_create_instance(const char* title, int32_t width, int32_t height);

// Destroys the instance
void phrost_destroy_instance(PhrostEngineRef engine);

// Blocking call that runs the game loop
void phrost_run_loop(PhrostEngineRef engine, PhrostUpdateCallback callback);

#ifdef __cplusplus
}
#endif

#endif // PHROST_ENGINE_H
