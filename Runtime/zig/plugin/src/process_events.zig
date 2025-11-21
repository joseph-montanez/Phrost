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

        var unpacker = ph.EventUnpacker.init(blob_slice);

        // 1. Read Command Count
        // PHP packs this as "Vx4" (UInt32 + 4 bytes padding) to ensure alignment starts at 8.
        const event_count = blk: {
            if (unpacker.read(u32)) |count| {
                // Skip 4 bytes padding
                unpacker.skip(4) catch break :blk 0;
                break :blk count;
            } else |_| {
                break :blk 0;
            }
        };

        const EVENT_HEADER_SIZE = 16; // 4(Type) + 8(Time) + 4(Pad)

        // Loop based on buffer availability, but conceptually we are processing `event_count` commands.
        while (true) {
            const current_pos = unpacker.stream.getPos() catch break;

            // Safety Check: Is there enough data for a header?
            if (current_pos + EVENT_HEADER_SIZE > unpacker.stream.getWritten().len) {
                break;
            }

            // 2. Read Event Header
            const event_type_raw = unpacker.read(u32) catch break;
            _ = unpacker.read(u64) catch break; // Discard timestamp
            _ = unpacker.skip(4) catch break; // Discard header padding

            const event_type = std.meta.intToEnum(ph.Events, event_type_raw) catch {
                std.debug.print("Unknown event type: {d} at offset {d}. Stopping.\n", .{ event_type_raw, current_pos });
                break;
            };

            const payload_size = ph.event_payload_sizes.get(@tagName(event_type)) orelse {
                std.debug.print("Unknown payload size for event: {any}. Stopping.\n", .{event_type});
                break;
            };

            // Safety Check: Is there enough data for the fixed payload?
            const pos_after_header = unpacker.stream.getPos() catch break;
            if (pos_after_header + payload_size > unpacker.stream.getWritten().len) {
                break;
            }

            // 3. Process Payload
            switch (event_type) {
                // --- VARIABLE LENGTH EVENTS (Strings) ---
                // These have a fixed header, then string data + string padding.

                .spriteTextureLoad => {
                    const header = unpacker.readPayload(ph.PackedTextureLoadHeaderEvent) catch break;
                    // Read filename string + padding
                    unpacker.skipStringAligned(header.filenameLength) catch break;
                },

                .textAdd => {
                    const header = unpacker.readPayload(ph.PackedTextAddEvent) catch break;
                    // Read font path + padding
                    unpacker.skipStringAligned(header.fontPathLength) catch break;
                    // Read text + padding
                    unpacker.skipStringAligned(header.textLength) catch break;
                },

                .textSetString => {
                    const header = unpacker.readPayload(ph.PackedTextSetStringEvent) catch break;
                    // Read text + padding
                    unpacker.skipStringAligned(header.textLength) catch break;
                },

                .pluginLoad => {
                    const header = unpacker.readPayload(ph.PackedPluginLoadHeaderEvent) catch break;
                    // Read path + padding
                    unpacker.skipStringAligned(header.pathLength) catch break;
                },

                .audioLoad => {
                    // Note: PackedAudioLoadEvent is just u32 length.
                    // PHP packs it as "Vx4" (8 bytes). But the STRUCT is 4 bytes.
                    // The `EventUnpacker.alignTo(8)` at the end of loop handles the `x4`.
                    // However, Swift logic specifically skips 4 bytes inside the case.
                    // Let's trust the Structs.swift definition (size 4) and let the
                    // final alignment handle the gap.
                    const header = unpacker.readPayload(ph.PackedAudioLoadEvent) catch break;
                    // BUT: Swift explicitly does `offset += 4` *before* reading string.
                    // This means the padding is INSIDE the payload area effectively.
                    // To match Swift:
                    unpacker.skip(4) catch break;

                    unpacker.skipStringAligned(header.pathLength) catch break;
                },

                .windowTitle => {
                    // Fixed size buffer in struct, just read normally
                    unpacker.skip(payload_size) catch break;
                },

                // --- INPUT ---
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

                // --- WINDOW ---
                .windowResize => {
                    const event = unpacker.readPayload(ph.PackedWindowResizeEvent) catch break;
                    world.windowWidth = event.w;
                    world.windowHeight = event.h;
                },

                else => |_| {
                    // Standard fixed-size event.
                    unpacker.skip(payload_size) catch break;
                },
            }

            // 4. ALIGNMENT
            // Ensure the stream is aligned to 8 bytes before the next event header starts.
            // This matches PHP's `padToBoundary()` and Swift's `alignOffset`.
            unpacker.alignTo(8) catch break;
        }
    }
    return add_sprites;
}
