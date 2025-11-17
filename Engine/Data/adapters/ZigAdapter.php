<?php

class ZigAdapter extends BaseAdapter
{
    protected function doGeneration(): void
    {
        $outputFile = __DIR__ . "/../out/zig/phrost.zig";

        $output = $this->getFileHeader("ZigAdapter.php");
        $output .= "const std = @import(\"std\");\n\n";

        // --- 1. Generate Events Enum ---
        $output .= "pub const Events = enum(u32) {\n";
        $lastCategory = null;
        foreach ($this->allEnums as $id => $enumName) {
            $category = getCategory($id);
            if ($lastCategory !== null && $category !== $lastCategory) {
                $output .= "\n";
            }
            $output .= "    " . $this->snakeToCamel($enumName) . " = {$id},\n";
            $lastCategory = $category;
        }
        $output .= "};\n\n";

        // --- 2. Generate Structs ---
        foreach ($this->uniqueStructs as $structName => $struct) {
            $output .= "pub const {$structName} = extern struct {\n";
            foreach ($struct["members"] as $member) {
                $output .=
                    "    " .
                    $member["name"] .
                    ": " .
                    $this->mapJsonTypeToZig($member) . // <-- MODIFIED
                    ", // " .
                    $member["comment"] .
                    "\n";
            }
            $output .= "};\n\n";
        }

        // --- 3. Generate Payload List and Map ---
        $output .= "pub const KVPair = struct { []const u8, u32 };\n\n";
        $output .= "pub const event_payload_list = [_]KVPair{\n";
        $lastCategory = null;
        foreach ($this->allEnums as $id => $enumName) {
            $struct = $this->findStructForEventId($id);
            if ($struct === null) {
                continue;
            }

            $category = getCategory($id);
            if ($lastCategory !== null && $category !== $lastCategory) {
                $output .= "\n    // " . ucfirst($category) . " Events\n";
            }
            $lastCategory = $category;

            $camelCaseName = $this->snakeToCamel($enumName);
            if (empty($struct["members"])) {
                $output .= "    .{ \"{$camelCaseName}\", 0 }, // No payload\n";
            } else {
                $output .= "    .{ \"{$camelCaseName}\", @sizeOf({$struct["name"]}) },\n";
            }
        }
        $output .= "};\n\n";
        $output .=
            "pub const event_payload_sizes = std.StaticStringMap(u32).initComptime(event_payload_list);\n\n";

        // --- 4. Append Static Helper Code ---
        $output .= $this->getStaticZigCode();

        file_put_contents($outputFile, $output);
        echo "Successfully generated {$outputFile}\n";
    }

    private function findStructForEventId(int $id): ?array
    {
        foreach ($this->allStructs as $s) {
            if ($s["eventId"] === $id) {
                return $s;
            }
        }
        return null;
    }

    /**
     * Maps JSON member definition to a Zig type.
     *
     * @param array $member The member definition from structs.json
     * @return string The corresponding Zig type
     */
    private function mapJsonTypeToZig(array $member): string
    {
        $jsonType = $member["type"];

        // Handle "count" property
        if (isset($member["count"]) && $jsonType === "u8") {
            return "[" . $member["count"] . "]u8";
        }

        // Handle old array syntax as a fallback
        if (preg_match("/^u8\[(\d+)\]$/", $jsonType, $matches)) {
            return "[" . $matches[1] . "]u8";
        }
        if ($jsonType === "char[256]") {
            return "@Vector(256, u8)";
        }

        switch ($jsonType) {
            case "i64":
                return "i64";
            case "u64":
                return "u64";
            case "i32":
                return "i32";
            case "u32":
                return "u32";
            case "i16":
                return "i16";
            case "u16":
                return "u16";
            case "i8":
                return "i8";
            case "u8":
                return "u8";
            case "f32":
                return "f32";
            case "f64":
                return "f64";
            default:
                return "anytype"; // Should not happen
        }
    }

    private function getStaticZigCode(): string
    {
        // This is the static helper code from your original phrost.zig
        // NOTE: The closing ZIG; MUST NOT be indented.
        return <<<'ZIG'
        pub const Keycode = struct {
            pub const A: u32 = 97;
            pub const D: u32 = 100;
        };

        pub const CommandPacker = struct {
            writer: std.ArrayList(u8).Writer,
            command_count: u32 = 0,

            pub fn pack(self: *CommandPacker, event_type: Events, payload: anytype) !void {
                try self.writer.writeInt(u32, @intFromEnum(event_type), .little);
                try self.writer.writeInt(u64, 0, .little); // 8-byte timestamp
                try self.writer.writeAll(std.mem.asBytes(&payload));
                self.command_count += 1;
            }

            pub fn packTextureLoad(self: *CommandPacker, id1: i64, id2: i64, path: []const u8) !void {
                try self.writer.writeInt(u32, @intFromEnum(Events.spriteTextureLoad), .little);
                try self.writer.writeInt(u64, 0, .little);
                const header = PackedTextureLoadHeaderEvent{
                    .id1 = id1,
                    .id2 = id2,
                    .filenameLength = @intCast(path.len),
                    ._padding = 0,
                };
                try self.writer.writeAll(std.mem.asBytes(&header));
                try self.writer.writeAll(path);
                self.command_count += 1;
            }

            pub fn packPluginLoad(self: *CommandPacker, path: []const u8) !void {
                try self.writer.writeInt(u32, @intFromEnum(Events.pluginLoad), .little);
                try self.writer.writeInt(u64, 0, .little);
                const header = PackedPluginLoadHeaderEvent{
                    .pathLength = @intCast(path.len),
                };
                try self.writer.writeAll(std.mem.asBytes(&header));
                try self.writer.writeAll(path);
                self.command_count += 1;
            }

            pub fn packAudioLoad(self: *CommandPacker, path: []const u8) !void {
                try self.writer.writeInt(u32, @intFromEnum(Events.audioLoad), .little);
                try self.writer.writeInt(u64, 0, .little);
                const header = PackedAudioLoadEvent{
                    .pathLength = @intCast(path.len),
                };
                try self.writer.writeAll(std.mem.asBytes(&header));
                try self.writer.writeAll(path);
                self.command_count += 1;
            }

            pub fn packTextSetString(self: *CommandPacker, id1: i64, id2: i64, text: []const u8) !void {
                try self.writer.writeInt(u32, @intFromEnum(Events.textSetString), .little);
                try self.writer.writeInt(u64, 0, .little);

                const header = PackedTextSetStringEvent{
                    .id1 = id1,
                    .id2 = id2,
                    .textLength = @intCast(text.len),
                    ._padding = 0,
                };
                try self.writer.writeAll(std.mem.asBytes(&header));
                try self.writer.writeAll(text);
                self.command_count += 1;
            }

            pub fn packTextAdd(
                self: *CommandPacker,
                id1: i64, id2: i64,
                pos: [3]f64,
                color: [4]u8,
                font_size: f32,
                font_path: []const u8,
                text: []const u8,
            ) !void {
                try self.writer.writeInt(u32, @intFromEnum(Events.textAdd), .little);
                try self.writer.writeInt(u64, 0, .little);

                const header = PackedTextAddEvent{
                    .id1 = id1,
                    .id2 = id2,
                    .positionX = pos[0],
                    .positionY = pos[1],
                    .positionZ = pos[2],
                    .r = color[0],
                    .g = color[1],
                    .b = color[2],
                    .a = color[3],
                    ._padding1 = 0,
                    .fontSize = font_size,
                    .fontPathLength = @intCast(font_path.len),
                    .textLength = @intCast(text.len),
                    ._padding2 = 0,
                };
                try self.writer.writeAll(std.mem.asBytes(&header));
                try self.writer.writeAll(font_path);
                try self.writer.writeAll(text);
                self.command_count += 1;
            }
        };

        pub const EventUnpacker = struct {
            stream: std.io.FixedBufferStream([]const u8),

            pub fn init(blob: []const u8) EventUnpacker {
                return .{
                    .stream = std.io.fixedBufferStream(blob),
                };
            }

            pub fn read(self: *EventUnpacker, comptime T: type) !T {
                return self.stream.reader().readInt(T, .little);
            }

            pub fn readPayload(self: *EventUnpacker, comptime T: type) !T {
                const bytes_array = try self.stream.reader().readBytesNoEof(@sizeOf(T));
                return std.mem.bytesAsValue(T, &bytes_array).*;
            }

            pub fn readVariable(self: *EventUnpacker, len: u32) ![]const u8 {
                return self.stream.reader().readBytesNoEof(len);
            }

            pub fn skip(self: *EventUnpacker, N: u32) !void {
                try self.stream.reader().skipBytes(@intCast(N), .{});
            }
        };

        pub fn hexdump_util(writer: anytype, slice: []const u8) anyerror!void {
            const ROW_SIZE = 16;
            var i: usize = 0;

            while (i < slice.len) : (i += ROW_SIZE) {
                const row_end = @min(i + ROW_SIZE, slice.len);
                const row = slice[i..row_end];

                try writer.print("{x:0>8} ", .{@as(u32, @intCast(i))});

                var j: usize = 0;
                while (j < ROW_SIZE) : (j += 1) {
                    if (j < row.len) {
                        try writer.print("{x:0>2} ", .{row[j]});
                    } else {
                        try writer.writeAll("   ");
                    }
                }

                try writer.writeAll(" |");
                for (row) |byte| {
                    if (byte >= 0x20 and byte <= 0x7E) {
                        try writer.writeByte(byte);
                    } else {
                        try writer.writeByte('.');
                    }
                }
                try writer.writeAll("|\n");
            }
        }
        ZIG;
    }
}
