const std = @import("std");
const ph = @import("phrost.zig");
const process_events = @import("process_events.zig");
const game_logic = @import("game_logic.zig");
const sp = @import("sprite.zig");

pub const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
});

// --- Global State ---
var world = struct {
    pub const FPS_SAMPLE_SIZE = 60;
    pub const MAX_SPRITES = 64000;
    // const texture_path = "/Users/josephmontanez/Documents/dev/PhrostEngineV2/assets/wabbit_alpha.png";
    pub const texture_path = "assets/wabbit_alpha.png";
    // --- MODIFIED: Buffer sizes for channels ---
    const CHANNEL_BUFFER_SIZE = 25 * 1024 * 1024;
    const FINAL_BUFFER_SIZE = 50 * 1024 * 1024;
    const SAVE_FILE_PATH = "save.dat";
    // <-- NEW

    // --- MODIFIED: Separate buffers for channels ---
    final_command_buffer: [FINAL_BUFFER_SIZE]u8 = undefined,
    command_buffer_render: [CHANNEL_BUFFER_SIZE]u8 = undefined,
    command_buffer_window: [CHANNEL_BUFFER_SIZE]u8 = undefined,

    sprite_buffer: [MAX_SPRITES]sp.Sprite = undefined,
    sprites: std.ArrayList(sp.Sprite),
    spritesCount: u64 = 0,
    mouseX: f32 = 0,
    mouseY: f32 = 0,
    fps: f64 = 0,
    smoothed_fps: f64 = 0,
    fps_sample_buffer: [FPS_SAMPLE_SIZE]f64 = undefined,
    fps_samples: std.ArrayList(f64),
    prng: std.Random.DefaultPrng,

    // --- ADDED ---
    // Track window size, matching PHP's initial state
    windowWidth: i32 = 800,
    windowHeight: i32 = 450,

    pub fn init() !void {
        world.sprites = std.ArrayList(sp.Sprite).initBuffer(world.sprite_buffer[0..]);
        world.fps_samples = std.ArrayList(f64).initBuffer(world.fps_sample_buffer[0..]);
        world.prng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
    }
}{
    .sprite_buffer = undefined,
    .sprites = undefined,
    .fps_sample_buffer = undefined,
    .fps_samples = undefined,
    .prng = undefined,
};

// --- Internal Helper Functions ---

/// Finalizes the command buffers, packs them into channels, and returns the
/// final memory blob to Swift.
fn finalizeAndReturn(
    cb_render: *std.ArrayList(u8),
    packer_render: *ph.CommandPacker,
    cb_window: *std.ArrayList(u8),
    packer_window: *ph.CommandPacker,
    out_length: *i32,
) ?*anyopaque {
    // Finalize individual channel event counts
    // Note: We write into the first 4 bytes. The next 4 bytes (indices 4-7)
    // are already 0 from our initialization, providing the required padding.
    std.mem.writeInt(u32, cb_render.items[0..4], packer_render.command_count, .little);
    std.mem.writeInt(u32, cb_window.items[0..4], packer_window.command_count, .little);

    // Prepare the final output buffer
    @memset(world.final_command_buffer[0..], 0);
    var fba_final = std.heap.FixedBufferAllocator.init(world.final_command_buffer[0..]);
    var cb_final = std.ArrayList(u8).initCapacity(
        fba_final.allocator(),
        @TypeOf(world).FINAL_BUFFER_SIZE,
    ) catch {
        std.debug.print("Phrost_Update: Failed to init cb_final\n", .{});
        out_length.* = 0;
        return null;
    };

    // Define the channel data
    const channel_inputs = &.{
        ph.ChannelPacker.ChannelInput{ .id = @intFromEnum(ph.Channels.renderer), .data = cb_render.items },
        ph.ChannelPacker.ChannelInput{ .id = @intFromEnum(ph.Channels.window), .data = cb_window.items },
    };
    // Pack the channels into the final buffer
    ph.ChannelPacker.finalize(cb_final.writer(fba_final.allocator()), channel_inputs) catch {
        std.debug.print("Phrost_Update: Failed to finalize channel packer\n", .{});
        out_length.* = 0;
        return null;
    };

    // Return the *final* blob
    const final_slice = cb_final.items;
    const swift_ptr = c.malloc(final_slice.len) orelse {
        out_length.* = 0;
        return null;
    };
    _ = c.memcpy(swift_ptr, final_slice.ptr, final_slice.len);

    out_length.* = @intCast(final_slice.len);
    return swift_ptr;
}

// --- Exported Functions ---
var is_initialized: bool = false;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

/// This function loads the saved world state and re-emits all
/// sprite creation commands to the Swift engine.
export fn Phrost_Wake(out_length: *i32) ?*anyopaque {
    // Initialize world state if this is the first call
    if (!is_initialized) {
        @TypeOf(world).init() catch {
            std.debug.print("Phrost_Wake: Failed to init Zig world\n", .{});
            out_length.* = 0;
            return null;
        };
        is_initialized = true;

        std.debug.print("--- Initializing Event Payload Sizes (from Wake) ---\n", .{});
        for (ph.event_payload_list) |kv_pair| {
            std.debug.print("Event '{s}': payload size {d}\n", .{ kv_pair[0], kv_pair[1] });
        }
        std.debug.print("----------------------------------------\n", .{});
    }

    // Prepare a command buffer to send commands back
    // Zeroing is good practice for fixed buffers being reused as ArrayList backing.
    @memset(world.command_buffer_render[0..], 0);
    var fba_render = std.heap.FixedBufferAllocator.init(world.command_buffer_render[0..]);
    const temp_allocator = fba_render.allocator();

    var cb_render = std.ArrayList(u8).initCapacity(
        temp_allocator,
        @TypeOf(world).CHANNEL_BUFFER_SIZE,
    ) catch |err| {
        std.debug.print("Phrost_Wake: Failed to init cb_render: {any}\n", .{err});
        out_length.* = 0;
        return null;
    };

    // --- FIXED: Reserve 8 bytes (Count + Padding) instead of 4 ---
    cb_render.appendSliceAssumeCapacity(&.{ 0, 0, 0, 0, 0, 0, 0, 0 });

    var packer_render = ph.CommandPacker{ .writer = cb_render.writer(temp_allocator) };

    // Try to load the save file
    // NOTE: We must provide a max size for readFileAlloc.
    // MAX_SPRITES (64000) * @sizeOf(Sprite) (~52 bytes) = ~3.3MB.
    // We'll set a 50MB limit, which is very safe.
    const MAX_SAVE_FILE_SIZE = 50 * 1024 * 1024;

    const file_bytes = std.fs.cwd().readFileAlloc(
        gpa.allocator(), // allocator
        @TypeOf(world).SAVE_FILE_PATH, // file_path
        MAX_SAVE_FILE_SIZE, // max_bytes
    ) catch |err|
        {
            if (err == error.FileNotFound) {
                std.debug.print("Phrost_Wake: No save.dat found. Starting new world.\n", .{});
            } else {
                std.debug.print("Phrost_Wake: Error reading save.dat: {any}\n", .{err});
            }
            out_length.* = 0;
            return null;
            // No commands to send, file not found or error
        };
    defer gpa.allocator().free(file_bytes);
    // Deserialize the file data
    // Ensure the file size is a clean multiple of the Sprite struct size
    if (file_bytes.len % @sizeOf(sp.Sprite) != 0) {
        std.debug.print("Phrost_Wake: save.dat has invalid size ({d} bytes). Ignoring.\n", .{file_bytes.len});
        out_length.* = 0;
        return null;
    }

    const loaded_sprites = std.mem.bytesAsSlice(sp.Sprite, file_bytes);
    std.debug.print("Phrost_Wake: Loading {d} sprites from save.dat...\n", .{loaded_sprites.len});

    // Populate world and RE-EMIT creation commands
    for (loaded_sprites) |sprite| {
        // Add to our internal world state
        world.sprites.appendBounded(sprite) catch {
            std.debug.print("Phrost_Wake: World full while loading save.dat!\n", .{});
            break; // Stop if we run out of space
        };
        world.spritesCount += 1;
        // Re-emit the spriteAdd command to Swift (to the render channel)
        packer_render.pack(ph.Events.spriteAdd, ph.PackedSpriteAddEvent{
            .id1 = sprite.id1,
            .id2 = sprite.id2,
            .positionX = sprite.pos[0],
            .positionY = sprite.pos[1],
            .positionZ = 0,
            .scaleX = 1,
            .scaleY = 1,
            .scaleZ = 1,
            .sizeW = 32,
            .sizeH = 32,
            .rotationX = 0,
            .rotationY = 0,
            .rotationZ = 0,
            .r = sprite.color[0],
            .g = sprite.color[1],
            .b = sprite.color[2],
            .a = sprite.color[3],
            ._padding = 0,
            .speedX = sprite.speed[0],
            .speedY = sprite.speed[1],
        }) catch {
            std.debug.print("Phrost_Wake: Command buffer full!\n", .{});
            break;
        };

        // Re-emit the textureLoad command to Swift (to the render channel)
        packer_render.packTextureLoad(sprite.id1, sprite.id2, @TypeOf(world).texture_path) catch {
            std.debug.print("Phrost_Wake: Command buffer full!\n", .{});
            break;
        };
    }

    std.debug.print("Phrost_Wake: Finished loading. Re-emitting {d} commands.\n", .{packer_render.command_count});

    // --- Finalize event count matches the reserved 8 bytes ---
    std.mem.writeInt(u32, cb_render.items[0..4], packer_render.command_count, .little);

    // Prepare the final output buffer
    @memset(world.final_command_buffer[0..], 0);
    var fba_final = std.heap.FixedBufferAllocator.init(world.final_command_buffer[0..]);
    var cb_final = std.ArrayList(u8).initCapacity(
        fba_final.allocator(),
        @TypeOf(world).FINAL_BUFFER_SIZE,
    ) catch {
        std.debug.print("Phrost_Wake: Failed to init cb_final\n", .{});
        out_length.* = 0;
        return null;
    };

    // Define the channel data (only render channel for wake)
    const channel_inputs = &.{
        ph.ChannelPacker.ChannelInput{ .id = @intFromEnum(ph.Channels.renderer), .data = cb_render.items },
    };
    // Pack the channels into the final buffer
    ph.ChannelPacker.finalize(cb_final.writer(fba_final.allocator()), channel_inputs) catch {
        std.debug.print("Phrost_Wake: Failed to finalize channel packer\n", .{});
        out_length.* = 0;
        return null;
    };

    // --- Return the *final* blob ---
    const final_slice = cb_final.items;
    const swift_ptr = c.malloc(final_slice.len) orelse {
        out_length.* = 0;
        return null;
    };
    _ = c.memcpy(swift_ptr, final_slice.ptr, final_slice.len);

    out_length.* = @intCast(final_slice.len);
    return swift_ptr;
}

/// This is the main game loop function, called by Swift.
export fn Phrost_Update(
    _: u64, // ticks (unused in this example)
    dt: f64,
    eventsBlob: ?*const anyopaque, // C's `const void*`
    eventsLength: i32,
    out_length: *i32,
) ?*anyopaque {
    // --- 1. One-time Initialization ---
    if (!is_initialized) {
        @TypeOf(world).init() catch {
            std.debug.print("Phrost_Update: Failed to init Zig world\n", .{});
            out_length.* = 0;
            return null;
        };
        is_initialized = true;

        std.debug.print("--- Initializing Event Payload Sizes (from Update) ---\n", .{});
        for (ph.event_payload_list) |kv_pair| {
            std.debug.print("Event '{s}': payload size {d}\n", .{ kv_pair[0], kv_pair[1] });
        }
        std.debug.print("----------------------------------------\n", .{});
    }

    // --- 2. Setup separate packers for each channel ---
    // Packer for Render Channel
    @memset(world.command_buffer_render[0..], 0);
    var fba_render = std.heap.FixedBufferAllocator.init(world.command_buffer_render[0..]);
    var cb_render = std.ArrayList(u8).initCapacity(
        fba_render.allocator(),
        @TypeOf(world).CHANNEL_BUFFER_SIZE,
    ) catch |err|
        {
            std.debug.print("Failed to init cb_render: {any}\n", .{err});
            out_length.* = 0;
            return null;
        };

    // --- FIXED: Reserve 8 bytes (Count + Padding) instead of 4 ---
    cb_render.appendSliceAssumeCapacity(&.{ 0, 0, 0, 0, 0, 0, 0, 0 });

    // Placeholder for count
    var packer_render = ph.CommandPacker{ .writer = cb_render.writer(fba_render.allocator()) };

    // --- Packer for Window Channel ---
    @memset(world.command_buffer_window[0..], 0);
    var fba_window = std.heap.FixedBufferAllocator.init(world.command_buffer_window[0..]);
    var cb_window = std.ArrayList(u8).initCapacity(
        fba_window.allocator(),
        @TypeOf(world).CHANNEL_BUFFER_SIZE, // Overkill, but safe
    ) catch |err|
        {
            std.debug.print("Failed to init cb_window: {any}\n", .{err});
            out_length.* = 0;
            return null;
        };

    // --- FIXED: Reserve 8 bytes (Count + Padding) instead of 4 ---
    cb_window.appendSliceAssumeCapacity(&.{ 0, 0, 0, 0, 0, 0, 0, 0 });

    var packer_window = ph.CommandPacker{ .writer = cb_window.writer(fba_window.allocator()) };

    // --- 3. Process Incoming Events ---
    const add_sprites_flag = process_events.processIncomingEvents(
        @TypeOf(world),
        &world,
        eventsBlob,
        eventsLength,
    );

    // --- 4. Run Game Logic ---
    game_logic.updateFPS(@TypeOf(world), &world, dt);
    game_logic.updateWindowTitle(@TypeOf(world), &world, &packer_window);
    game_logic.updateAndMoveSprites(@TypeOf(world), sp.Sprite, &world, dt, &packer_render);
    game_logic.spawnNewSprites(@TypeOf(world), sp.Sprite, &world, add_sprites_flag, &packer_render);

    // --- 5. Finalize & Return ---
    return finalizeAndReturn(
        &cb_render,
        &packer_render,
        &cb_window,
        &packer_window,
        out_length,
    );
}

/// This function is called by Swift to free the memory returned by Phrost_Wake and Phrost_Update.
export fn Phrost_Free(data_ptr: ?*anyopaque) void {
    if (data_ptr) |ptr| {
        c.free(ptr); // Use C's free to match C's malloc
    }
}

/// This function is called by Swift *only* when the plugin is being unloaded.
/// It is responsible for saving the world state to a file.
export fn Phrost_Sleep() void {
    // We do this *before* freeing the memory.
    if (is_initialized and world.sprites.items.len > 0) {
        std.debug.print("Phrost_Sleep: Saving {d} sprites to save.dat...\n", .{world.sprites.items.len});
        // Get the raw byte slice of our sprite list
        const save_data = std.mem.sliceAsBytes(world.sprites.items);
        // Write the bytes directly to the file
        std.fs.cwd().writeFile(.{
            .sub_path = @TypeOf(world).SAVE_FILE_PATH,
            .data = save_data,
        }) catch |err|
            {
                // Log an error, but don't stop the sleep/free process
                std.debug.print("Phrost_Sleep: FAILED to write save.dat: {any}\n", .{err});
            };
    } else if (is_initialized) {
        // If we are initialized but have 0 sprites, we should clear the save file
        // to prevent loading old sprites on next launch.
        std.fs.cwd().deleteFile(@TypeOf(world).SAVE_FILE_PATH) catch |err| {
            if (err != error.FileNotFound) {
                std.debug.print("Phrost_Sleep: FAILED to delete save.dat: {any}\n", .{err});
            }
        };
    }
}
