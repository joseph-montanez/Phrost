#ifndef EVENT_PACKER_H
#define EVENT_PACKER_H

#include <stdint.h>
#include <stddef.h> // For size_t
#include <stdbool.h>
#include "events.h"

// --- Event Unpacker (Reads flat blob from Swift) ---

typedef struct {
    const uint8_t* buffer;
    size_t length;
    size_t offset;
} EventUnpacker;

/**
 * @brief Initializes a new event unpacker with the data from Swift.
 */
void unpacker_init(EventUnpacker* unpacker, const char* data, int32_t length);

/**
 * @brief Reads a fixed-size payload (like a header or event struct).
 * @return True on success, false if out of bounds.
 */
bool unpacker_read_fixed(EventUnpacker* unpacker, void* dest, size_t size);

/**
 * @brief Skips a number of bytes.
 * @return True on success, false if out of bounds.
 */
bool unpacker_skip(EventUnpacker* unpacker, size_t size);


// --- Command Packer (Builds a single channel's data) ---

// Note: 12MB buffer, same as your Zig implementation (CHANNEL_BUFFER_SIZE)
#define COMMAND_PACKER_CAPACITY (25 * 1024 * 1024)

typedef struct {
    uint8_t* buffer;
    size_t capacity;
    size_t size;
    uint32_t command_count;
} CommandPacker;

/**
 * @brief Initializes a packer with a given buffer.
 */
void packer_init(CommandPacker* packer, uint8_t* buffer, size_t capacity);

/**
 * @brief Resets the packer to be reused, writing a 4-byte 0 count.
 */
void packer_reset(CommandPacker* packer);

/**
 * @brief Packs a fixed-size event (header + payload struct).
 * @return True on success, false if buffer is full.
 */
bool packer_pack_event(CommandPacker* packer, PhrostEventID event_id, const void* payload, size_t payload_size);

/**
 * @brief Packs a variable-data event (e.g., texture load).
 * @return True on success, false if buffer is full.
 */
bool packer_pack_variable(CommandPacker* packer, PhrostEventID event_id,
                          const void* header, size_t header_size,
                          const void* var_data, size_t var_data_size);

/**
 * @brief Finalizes the packer by writing the true command count at the start.
 */
void packer_finalize(CommandPacker* packer);


// --- Channel Packer (Combines multiple CommandPackers for Swift) ---

#define FINAL_BUFFER_CAPACITY (50 * 1024 * 1024)

typedef struct {
    CommandPacker* packer;
    uint32_t channel_id;
} ChannelInput;

/**
 * @brief Combines multiple channels into the final output buffer.
 * @param out_buffer The buffer to write the final blob to.
 * @param out_buffer_capacity The capacity of the output buffer.
 * @param channels An array of ChannelInput structs.
 * @param channel_count The number of channels in the array.
 * @return The total number of bytes written to out_buffer, or 0 on failure.
 */
size_t channel_packer_finalize(uint8_t* out_buffer, size_t out_buffer_capacity,
                               ChannelInput* channels, size_t channel_count);

/**
 * @brief Gets the *fixed* payload size for a given event ID.
 * This is our C version of the Zig 'event_payload_sizes' map.
 * Returns 0 for unknown events or events with NO payload.
 * Returns the size of the *fixed header* for variable-sized events.
 */
size_t get_event_payload_size(PhrostEventID event_id);

#endif // EVENT_PACKER_H
