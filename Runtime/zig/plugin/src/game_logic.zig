const std = @import("std");
const ph = @import("phrost.zig");
pub const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
});

/// Calculates and updates the world's FPS and smoothed FPS.
pub fn updateFPS(
    comptime WorldType: type,
    world: *WorldType,
    dt: f64,
) void {
    if (dt > 0) {
        world.fps = 1.0 / dt;
        if (world.fps_samples.items.len == WorldType.FPS_SAMPLE_SIZE) {
            _ = world.fps_samples.orderedRemove(0);
        }
        world.fps_samples.appendBounded(dt) catch {};

        var sum: f64 = 0;
        for (world.fps_samples.items) |sample|
            sum += sample;

        if (world.fps_samples.items.len > 0) {
            const average_dt = sum / @as(f64, @floatFromInt(world.fps_samples.items.len));
            if (average_dt > 0) {
                world.smoothed_fps = 1.0 / average_dt;
            }
        }
    }
}

/// Updates the window title with current stats.
pub fn updateWindowTitle(
    comptime WorldType: type,
    world: *WorldType,
    packer_window: *ph.CommandPacker,
) void {
    var title_buf: [256]u8 = .{0} ** 256;
    const title_slice = std.fmt.bufPrint(&title_buf, "Bunny Benchmark | Sprites: {d} | FPS: {d:.0}", .{
        world.spritesCount,
        world.smoothed_fps,
    }) catch "Error";
    var title_event = ph.PackedWindowTitleEvent{ .title = @splat(@as(u8, 0)) };
    _ = c.memcpy(&title_event.title, title_slice.ptr, title_slice.len);
    // Pack to window channel
    packer_window.pack(ph.Events.windowTitle, title_event) catch {};
}

/// Runs the update logic for all existing sprites.
pub fn updateAndMoveSprites(
    comptime WorldType: type,
    comptime SpriteType: type,
    world: *WorldType,
    dt: f64,
    packer_render: *ph.CommandPacker,
) void {
    for (world.sprites.items) |*sprite| {
        // Pass render packer to update function
        SpriteType.update(WorldType, world, sprite, dt, packer_render) catch {};
    }
}

/// Spawns new sprites if the `add_sprites_flag` is set.
pub fn spawnNewSprites(
    comptime WorldType: type,
    comptime SpriteType: type,
    world: *WorldType,
    add_sprites_flag: bool,
    packer_render: *ph.CommandPacker,
) void {
    if (add_sprites_flag and world.spritesCount < WorldType.MAX_SPRITES) {
        const rand = world.prng.random();
        for (0..1000) |_| {
            if (world.spritesCount >= WorldType.MAX_SPRITES) break;
            const id1: i64 = @intCast(world.spritesCount);
            const id2: i64 = 0;
            // --- MODIFIED: Store color ---
            const r = 50 + rand.uintAtMost(u8, 240 - 50);
            const g = 80 + rand.uintAtMost(u8, 240 - 80);
            const b = 100 + rand.uintAtMost(u8, 240 - 100);
            const a = 255;

            const sprite = SpriteType{
                .id1 = id1,
                .id2 = id2,
                .pos = .{ world.mouseX, world.mouseY }, // Use f64
                .speed = .{
                    (rand.float(f64) * 500.0) - 250.0,
                    (rand.float(f64) * 500.0) - 250.0,
                },
                .color = .{ r, g, b, a }, // <-- Save color
            };
            world.sprites.appendBounded(sprite) catch break;

            // --- Pack to render channel ---
            packer_render.pack(ph.Events.spriteAdd, ph.PackedSpriteAddEvent{
                .id1 = id1,
                .id2 = id2,
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
                .r = r, // Use vars
                .g = g,

                .b = b,
                .a = a,
                ._padding = 0,
                .speedX = sprite.speed[0],
                .speedY = sprite.speed[1],
            }) catch
                break;
            // Pack to render channel
            packer_render.packTextureLoad(id1, id2, WorldType.texture_path) catch break;
            world.spritesCount += 1;
        }
    }
}
