#include "event_packer.h"
#include <string.h>

static bool channel_write(uint8_t* out_buffer, size_t out_buffer_capacity, size_t* offset, const void* data, size_t size) {
    if (*offset + size > out_buffer_capacity) return false;
    memcpy(out_buffer + *offset, data, size);
    *offset += size;
    return true;
}

// --- Event Unpacker ---
void unpacker_init(EventUnpacker* unpacker, const char* data, int32_t length) {
    unpacker->buffer = (const uint8_t*)data;
    unpacker->length = (size_t)length;
    unpacker->offset = 0;
}
bool unpacker_read_fixed(EventUnpacker* unpacker, void* dest, size_t size) {
    if (unpacker->offset + size > unpacker->length) return false;
    memcpy(dest, unpacker->buffer + unpacker->offset, size);
    unpacker->offset += size;
    return true;
}
bool unpacker_skip(EventUnpacker* unpacker, size_t size) {
    if (unpacker->offset + size > unpacker->length) return false;
    unpacker->offset += size;
    return true;
}

// --- Command Packer ---
void packer_init(CommandPacker* packer, uint8_t* buffer, size_t capacity) {
    packer->buffer = buffer;
    packer->capacity = capacity;
    packer->size = 0;
    packer->command_count = 0;
    packer_reset(packer);
}

void packer_reset(CommandPacker* packer) {
    packer->size = 0;
    packer->command_count = 0;
    // Write 8 bytes (Count + Padding)
    if (packer->capacity >= 8) {
        memset(packer->buffer, 0, 8);
        packer->size = 8;
    }
}

static bool packer_write(CommandPacker* packer, const void* data, size_t size) {
    if (packer->size + size > packer->capacity) return false;
    memcpy(packer->buffer + packer->size, data, size);
    packer->size += size;
    return true;
}

// Helper to align stream to 8 bytes
static bool packer_align(CommandPacker* packer) {
    size_t padding = (8 - (packer->size % 8)) % 8;
    if (padding > 0) {
        uint8_t pad[8] = {0};
        return packer_write(packer, pad, padding);
    }
    return true;
}

bool packer_pack_event(CommandPacker* packer, PhrostEventID event_id, const void* payload, size_t payload_size) {
    // 16-byte header (ID(4) + TS(8) + PAD(4))
    uint32_t id_le = (uint32_t)event_id;
    uint64_t timestamp_le = 0;
    uint32_t pad = 0;

    if (!packer_write(packer, &id_le, sizeof(id_le))) return false;
    if (!packer_write(packer, &timestamp_le, sizeof(timestamp_le))) return false;
    if (!packer_write(packer, &pad, sizeof(pad))) return false; // Padding

    if (payload_size > 0) {
        if (!packer_write(packer, payload, payload_size)) return false;
    }

    // Special case: pad AUDIO_LOAD fixed part if needed
    if (event_id == EVENT_AUDIO_LOAD || event_id == EVENT_PLUGIN_LOAD) {
        // These fixed payloads are 4 bytes, but we want 8 on wire for alignment
        if (!packer_write(packer, &pad, sizeof(pad))) return false;
    }

    packer_align(packer); // Align end of event
    packer->command_count++;
    return true;
}

bool packer_pack_variable(CommandPacker* packer, PhrostEventID event_id,
                          const void* header, size_t header_size,
                          const void* var_data, size_t var_data_size) {
    uint32_t id_le = (uint32_t)event_id;
    uint64_t timestamp_le = 0;
    uint32_t pad = 0;

    if (!packer_write(packer, &id_le, sizeof(id_le))) return false;
    if (!packer_write(packer, &timestamp_le, sizeof(timestamp_le))) return false;
    if (!packer_write(packer, &pad, sizeof(pad))) return false;

    if (!packer_write(packer, header, header_size)) return false;

    // Pad fixed part for Audio/Plugin load
    if (event_id == EVENT_AUDIO_LOAD || event_id == EVENT_PLUGIN_LOAD) {
        if (!packer_write(packer, &pad, sizeof(pad))) return false;
    }

    // Pad the string part
    size_t strPad = (8 - (var_data_size % 8)) % 8;

    if (var_data_size > 0) {
        if (!packer_write(packer, var_data, var_data_size)) return false;
    }
    if (strPad > 0) {
        uint8_t zero[8] = {0};
        if (!packer_write(packer, zero, strPad)) return false;
    }

    packer_align(packer);
    packer->command_count++;
    return true;
}

void packer_finalize(CommandPacker* packer) {
    if (packer->capacity >= 4) {
        memcpy(packer->buffer, &packer->command_count, sizeof(uint32_t));
    }
}

size_t channel_packer_finalize(uint8_t* out_buffer, size_t out_buffer_capacity,
                               ChannelInput* channels, size_t channel_count) {
    size_t offset = 0;
    uint32_t count_le = (uint32_t)channel_count;
    uint32_t pad = 0;

    // 1. Count (4) + Pad (4)
    if (!channel_write(out_buffer, out_buffer_capacity, &offset, &count_le, sizeof(count_le))) return 0;
    if (!channel_write(out_buffer, out_buffer_capacity, &offset, &pad, sizeof(pad))) return 0;

    // 2. Index Table
    for (size_t i = 0; i < channel_count; ++i) {
        uint32_t id_le = channels[i].channel_id;
        uint32_t size_le = (uint32_t)channels[i].packer->size;
        if (!channel_write(out_buffer, out_buffer_capacity, &offset, &id_le, sizeof(id_le))) return 0;
        if (!channel_write(out_buffer, out_buffer_capacity, &offset, &size_le, sizeof(size_le))) return 0;
    }

    // 3. Data Blobs
    for (size_t i = 0; i < channel_count; ++i) {
        if (!channel_write(out_buffer, out_buffer_capacity, &offset, channels[i].packer->buffer, channels[i].packer->size)) return 0;
    }
    return offset;
}

// ... (get_event_payload_size remains the same) ...
size_t get_event_payload_size(PhrostEventID event_id) {
    // (Use your existing switch statement here)
    // Make sure case EVENT_PLUGIN_LOAD returns sizeof(PackedPluginLoadHeaderEvent);
    // Make sure case EVENT_AUDIO_LOAD returns sizeof(PackedAudioLoadEvent);
     switch (event_id) {
        // --- Fixed-Size Events ---
        case EVENT_SPRITE_ADD: return sizeof(PackedSpriteAddEvent);
        case EVENT_SPRITE_REMOVE: return sizeof(PackedSpriteRemoveEvent);
        case EVENT_SPRITE_MOVE: return sizeof(PackedSpriteMoveEvent);
        case EVENT_SPRITE_SCALE: return sizeof(PackedSpriteScaleEvent);
        case EVENT_SPRITE_RESIZE: return sizeof(PackedSpriteResizeEvent);
        case EVENT_SPRITE_ROTATE: return sizeof(PackedSpriteRotateEvent);
        case EVENT_SPRITE_COLOR: return sizeof(PackedSpriteColorEvent);
        case EVENT_SPRITE_SPEED: return sizeof(PackedSpriteSpeedEvent);
        case EVENT_SPRITE_TEXTURE_SET: return sizeof(PackedSpriteTextureSetEvent);
        case EVENT_SPRITE_SET_SOURCE_RECT: return sizeof(PackedSpriteSetSourceRectEvent);

        case EVENT_GEOM_ADD_POINT: return sizeof(PackedGeomAddPointEvent);
        case EVENT_GEOM_ADD_LINE: return sizeof(PackedGeomAddLineEvent);
        case EVENT_GEOM_ADD_RECT: return sizeof(PackedGeomAddRectEvent);
        case EVENT_GEOM_ADD_FILL_RECT: return sizeof(PackedGeomAddRectEvent);
        case EVENT_GEOM_REMOVE: return sizeof(PackedGeomRemoveEvent);
        case EVENT_GEOM_SET_COLOR: return sizeof(PackedGeomSetColorEvent);

        case EVENT_INPUT_KEYUP: return sizeof(PackedKeyEvent);
        case EVENT_INPUT_KEYDOWN: return sizeof(PackedKeyEvent);
        case EVENT_INPUT_MOUSEUP: return sizeof(PackedMouseButtonEvent);
        case EVENT_INPUT_MOUSEDOWN: return sizeof(PackedMouseButtonEvent);
        case EVENT_INPUT_MOUSEMOTION: return sizeof(PackedMouseMotionEvent);

        case EVENT_WINDOW_RESIZE: return sizeof(PackedWindowResizeEvent);
        case EVENT_WINDOW_FLAGS: return sizeof(PackedWindowFlagsEvent);
        case EVENT_WINDOW_TITLE: return sizeof(PackedWindowTitleEvent);

        case EVENT_AUDIO_LOADED: return sizeof(PackedAudioLoadedEvent);
        case EVENT_AUDIO_PLAY: return sizeof(PackedAudioPlayEvent);
        case EVENT_AUDIO_SET_MASTER_VOLUME: return sizeof(PackedAudioSetMasterVolumeEvent);
        case EVENT_AUDIO_PAUSE: return sizeof(PackedAudioPauseEvent);
        case EVENT_AUDIO_STOP: return sizeof(PackedAudioStopEvent);
        case EVENT_AUDIO_UNLOAD: return sizeof(PackedAudioUnloadEvent);
        case EVENT_AUDIO_SET_VOLUME: return sizeof(PackedAudioSetVolumeEvent);

        case EVENT_PHYSICS_ADD_BODY: return sizeof(PackedPhysicsAddBodyEvent);
        case EVENT_PHYSICS_REMOVE_BODY: return sizeof(PackedPhysicsRemoveBodyEvent);
        case EVENT_PHYSICS_APPLY_FORCE: return sizeof(PackedPhysicsApplyForceEvent);
        case EVENT_PHYSICS_APPLY_IMPULSE: return sizeof(PackedPhysicsApplyImpulseEvent);
        case EVENT_PHYSICS_SET_VELOCITY: return sizeof(PackedPhysicsSetVelocityEvent);
        case EVENT_PHYSICS_SET_POSITION: return sizeof(PackedPhysicsSetPositionEvent);
        case EVENT_PHYSICS_SET_ROTATION: return sizeof(PackedPhysicsSetRotationEvent);
        case EVENT_PHYSICS_COLLISION_BEGIN: return sizeof(PackedPhysicsCollisionEvent);
        case EVENT_PHYSICS_COLLISION_SEPARATE: return sizeof(PackedPhysicsCollisionEvent);
        case EVENT_PHYSICS_SYNC_TRANSFORM: return sizeof(PackedPhysicsSyncTransformEvent);

        case EVENT_PLUGIN: return sizeof(PackedPluginOnEvent);
        case EVENT_PLUGIN_UNLOAD: return sizeof(PackedPluginUnloadEvent);
        case EVENT_PLUGIN_SET: return sizeof(PackedPluginSetEvent);
        case EVENT_PLUGIN_EVENT_STACKING: return sizeof(PackedPluginEventStackingEvent);
        case EVENT_PLUGIN_SUBSCRIBE_EVENT: return sizeof(PackedPluginSubscribeEvent);
        case EVENT_PLUGIN_UNSUBSCRIBE_EVENT: return sizeof(PackedPluginUnsubscribeEvent);

        case EVENT_CAMERA_SET_POSITION: return sizeof(PackedCameraSetPositionEvent);
        case EVENT_CAMERA_MOVE: return sizeof(PackedCameraMoveEvent);
        case EVENT_CAMERA_SET_ZOOM: return sizeof(PackedCameraSetZoomEvent);
        case EVENT_CAMERA_SET_ROTATION: return sizeof(PackedCameraSetRotationEvent);
        case EVENT_CAMERA_FOLLOW_ENTITY: return sizeof(PackedCameraFollowEntityEvent);

        case EVENT_SCRIPT_SUBSCRIBE: return sizeof(PackedScriptSubscribeEvent);
        case EVENT_SCRIPT_UNSUBSCRIBE: return sizeof(PackedScriptUnsubscribeEvent);

        // --- Variable-Size Events (Return size of *header*) ---
        case EVENT_SPRITE_TEXTURE_LOAD: return sizeof(PackedTextureLoadHeaderEvent);
        case EVENT_TEXT_ADD: return sizeof(PackedTextAddEvent);
        case EVENT_TEXT_SET_STRING: return sizeof(PackedTextSetStringEvent);
        case EVENT_AUDIO_LOAD: return sizeof(PackedAudioLoadEvent);
        case EVENT_PLUGIN_LOAD: return sizeof(PackedPluginLoadHeaderEvent);
        case EVENT_GEOM_ADD_PACKED: return sizeof(PackedGeomAddPackedHeaderEvent);

        case EVENT_AUDIO_STOP_ALL: return 0;
        case EVENT_CAMERA_STOP_FOLLOWING: return 0;

        default: return 0;
    }
}
