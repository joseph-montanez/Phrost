const std = @import("std");
const ph = @import("phrost.zig");

/// Processes the incoming event blob from Swift.
/// Returns `true` if sprites should be added this frame.
pub fn processIncomingEvents(
    comptime WorldType: type,
    world: *WorldType,
    eventsBlob: ?*const anyopaque,
    eventsLength: i32,
) bool {
    var add_sprites = false;
    if (eventsBlob) |blob_ptr| {
        const blob_len: usize = @intCast(eventsLength);
        const blob_slice = @as([*]const u8, @ptrCast(blob_ptr))[0..blob_len];

        // --- FIXED: Use EventUnpacker directly, not ChannelUnpacker ---
        // The Swift engine sends a flat [count][events...] blob, not a channel-packed blob.
        var unpacker = ph.EventUnpacker.init(blob_slice);

        // Process events using the *exact same* robust loop as before,
        // but now it's operating on the *entire* blob.
        // Read event_count for logging/syncing, but DO NOT use it to control the loop.
        const event_count = blk: {
            if (unpacker.read(u32)) |count| {
                break :blk count;
            } else |_| {
                // std.debug.print("Phrost_Update: Received blob length {d} but couldn't read event count ({any}).\n", .{ eventsLength, err });
                break :blk 0;
            }
        };
        // std.debug.print("Phrost_Update: Received blob length {d}. Event count: {d}\n", .{ eventsLength, event_count });
        // **FINAL ROBUST LOOP STRUCTURE**
        const MIN_EVENT_HEADER_SIZE = 12;
        while (true) {
            // Safe Position Check: Check if there is enough room for the minimum header (12 bytes).
            const current_pos = unpacker.stream.getPos() catch {
                // If getPos() fails (stream error), we terminate the loop safely.
                break;
            };

            // --- MODIFIED: Check against the unpacker's stream length ---
            if (current_pos + MIN_EVENT_HEADER_SIZE > unpacker.stream.getWritten().len) {
                // Not enough room for even the header.
                // We stop.
                break;
            }

            // Read Header
            const event_type_raw = unpacker.read(u32) catch break;
            _ = unpacker.read(u64) catch break; // Discard timestamp

            const event_type = std.meta.intToEnum(ph.Events, event_type_raw) catch {
                // This is the garbage event, which we now log and stop at.
                std.debug.print("Unknown event: {d} at offset {d}. Stopping processing.\n", .{ event_type_raw, current_pos });
                // --- DIAGNOSTIC BLOCK: Hexdump the *channel* blob ---
                const dump_start: usize = 0;
                const dump_end: usize = @min(unpacker.stream.getWritten().len, 400);

                std.debug.print("Phrost_Update: Input Channel Blob. Event count: {d}\n", .{event_count});
                std.debug.print("--- RAW BLOB DUMP (0 to {d}) ---\n", .{dump_end});

                // Use the thread-safe locking mechanism provided in std.debug/std.Progress
                const writer = std.debug.lockStderrWriter(&.{});
                defer std.debug.unlockStderrWriter();
                ph.hexdump_util(writer, unpacker.stream.getWritten()[dump_start..dump_end]) catch {};

                std.debug.print("--------------------------------\n", .{});
                // --------------------------------------------------------
                break;
            };

            // Determine Payload Size and Check Bounds for Payload
            const payload_size = ph.event_payload_sizes.get(@tagName(event_type)) orelse {
                std.debug.print("Unknown payload size for event: {any}. Stopping processing.\n", .{event_type});
                break;
            };

            const pos_after_header = unpacker.stream.getPos() catch break;

            // --- MODIFIED: Check against the unpacker's stream length ---
            if (pos_after_header + payload_size > unpacker.stream.getWritten().len) {
                // Not enough room for the full payload.
                // End gracefully.
                std.debug.print("Warning: Insufficient remaining space for payload size {d}. Ending read loop.\n", .{payload_size});
                break;
            }

            // Process Payload
            switch (event_type) {
                .inputMousemotion => {
                    const event = unpacker.readPayload(ph.PackedMouseMotionEvent) catch break;
                    world.mouseX = event.x;
                    world.mouseY = event.y;
                },
                .inputMousedown => {
                    _ = unpacker.readPayload(ph.PackedMouseButtonEvent) catch break;
                    add_sprites = true;
                },
                .inputKeydown => {
                    const event = unpacker.readPayload(ph.PackedKeyEvent) catch break;
                    if (event.keycode == ph.Keycode.A) add_sprites = true;
                },
                .spriteTextureSet => {
                    _ = unpacker.readPayload(ph.PackedSpriteTextureSetEvent) catch break;
                },

                // Handle window resize event to update world state
                .windowResize => {
                    const event = unpacker.readPayload(ph.PackedWindowResizeEvent) catch break;
                    world.windowWidth = event.w;
                    world.windowHeight = event.h;
                },
                .windowTitle => {
                    unpacker.skip(payload_size) catch break;
                    // This should be the intended struct size
                },

                // Handle variable payload events by manually skipping the correct size
                // (Note: Since ph.event_payload_sizes.get() was used, we now just use skip)

                .textSetString => {
                    // 1. Read the fixed-size header to get the string length
                    const header = unpacker.readPayload(ph.PackedTextSetStringEvent) catch break;
                    // 2. Skip the variable length string data
                    // Note: textLength is u32, so cast to u32 is safe for skip
                    unpacker.skip(header.textLength) catch break;
                },

                // --- Also apply this logic to textAdd (another variable length event) ---
                .textAdd => {
                    // Read the fixed-size header to get the string length

                    const header =
                        unpacker.readPayload(ph.PackedTextAddEvent) catch break;
                    // Skip the font path (variable length)
                    unpacker.skip(header.fontPathLength) catch break;
                    // Skip the text content (variable length)
                    unpacker.skip(header.textLength) catch break;
                },

                else => |_| {
                    // Skip any other known, fixed-size event type.
                    unpacker.skip(payload_size) catch break;
                },
            }
        } // End of while loop
    }
    return add_sprites;
}
