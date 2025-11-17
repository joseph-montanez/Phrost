const std = @import("std");
const ph = @import("phrost.zig");

// --- Sprite ---
pub const Sprite = struct {
    id1: i64,
    id2: i64,
    pos: [2]f64,
    speed: [2]f64,
    color: [4]u8, // <-- NEW: Store color for serialization

    // Updated to use dynamic window size and add ejection logic from PHP
    pub fn update(comptime WorldType: type, world: *WorldType, self: *Sprite, dt: f64, packer_render: *ph.CommandPacker) !void {
        // Apply physics
        self.pos[0] += self.speed[0] * dt;
        self.pos[1] += self.speed[1] * dt;
        var speed_changed = false;

        // Define constants from world state
        const boundary_left: f64 = 12.0;
        // Need to cast world ints to f64 for math
        const boundary_right: f64 = @as(f64, @floatFromInt(world.windowWidth)) - 12.0;
        const boundary_top: f64 = 16.0;
        const boundary_bottom: f64 = @as(f64, @floatFromInt(world.windowHeight)) - 16.0;

        const hotspot_offset_x: f64 = 16.0;
        const hotspot_offset_y: f64 = 16.0;

        const hotspot_x = self.pos[0] + hotspot_offset_x;
        const hotspot_y = self.pos[1] + hotspot_offset_y;
        // 3. Boundary collision logic with ejection
        // Check X axis
        if (hotspot_x > boundary_right) {
            self.speed[0] *= -1.0;
            self.pos[0] = boundary_right - hotspot_offset_x; // Eject
            speed_changed = true;
        } else if (hotspot_x < boundary_left) {
            self.speed[0] *= -1.0;
            self.pos[0] = boundary_left - hotspot_offset_x; // Eject
            speed_changed = true;
        }

        // Check Y axis
        if (hotspot_y > boundary_bottom) {
            self.speed[1] *= -1.0;
            self.pos[1] = boundary_bottom - hotspot_offset_y; // Eject
            speed_changed = true;
        } else if (hotspot_y < boundary_top) {
            self.speed[1] *= -1.0;
            self.pos[1] = boundary_top - hotspot_offset_y; // Eject
            speed_changed = true;
        }

        // 4. Pack move event with final (potentially corrected) position
        // This is always sent, as physics has changed the position
        try packer_render.pack(ph.Events.spriteMove, ph.PackedSpriteMoveEvent{
            .id1 = self.id1,
            .id2 = self.id2,
            .positionX = self.pos[0],
            .positionY = self.pos[1],
            .positionZ = 0,
        });
        // 5. Pack speed event *only if it changed*
        if (speed_changed) {
            try packer_render.pack(ph.Events.spriteSpeed, ph.PackedSpriteSpeedEvent{
                .id1 = self.id1,
                .id2 = self.id2,
                .speedX = self.speed[0],

                .speedY = self.speed[1],
            });
        }
    }
};
