<?php

/**
 * Adapter to generate a complete `phrost.py` file from structs.json.
 *
 * This adapter pre-compiles all format strings, struct sizes, and
 * member keys at generation-time, so the resulting Python code
 * is static, performant, and readable.
 */
class PythonAdapter extends BaseAdapter
{
    /**
     * Maps C-style types from structs.json to Python's struct codes.
     */
    private const TYPE_MAP = [
        "i64" => "q",
        "u64" => "Q",
        "i32" => "i",
        "u32" => "I",
        "i16" => "h",
        "u16" => "H",
        "i8" => "b",
        "u8" => "B",
        "f32" => "f",
        "f64" => "d",
        "char" => "s", // 's' is for bytes
    ];

    /**
     * Maps C-style types to their byte size.
     */
    private const C_TYPE_SIZE_MAP = [
        "i64" => 8,
        "u64" => 8,
        "i32" => 4,
        "u32" => 4,
        "i16" => 2,
        "u16" => 2,
        "i8" => 1,
        "u8" => 1,
        "f32" => 4,
        "f64" => 8,
        "char" => 1,
    ];

    /**
     * Main generation method.
     */
    protected function doGeneration(): void
    {
        $outputFile = __DIR__ . "/../out/python/phrost.py";

        $output =
            "\"\"\"\n" .
            $this->getFileHeader("PythonAdapter.php") .
            "\"\"\"\n\n";
        $output .= "import enum\n";
        $output .= "import random\n"; // --- NEW --- Added random for Id_Generate
        $output .= "import struct\n";
        $output .= "import sys\n";
        $output .=
            "from typing import Any, Callable, Dict, List, Optional, Tuple, Union\n\n"; // --- MODIFIED --- Added Any, Callable, random

        // --- 1. Generate Events Enum ---
        $output .= "# --- Events Enum ---\n";
        $output .= "class Events(enum.IntEnum):\n";
        $lastCategory = null;
        foreach ($this->allEnums as $id => $name) {
            $category = getCategory($id);
            if ($lastCategory !== null && $category !== $lastCategory) {
                $output .= "\n";
            }
            $output .= "    {$name} = {$id}\n";
            $lastCategory = $category;
        }
        $output .= "# --- End Events Enum ---\n\n";

        // --- 2. Generate Pack Format Classes (with pre-computed formats) ---
        $output .= "# --- Pack Format Classes ---\n";
        foreach ($this->groupedStructs as $category => $categoryStructs) {
            $className = ucfirst($category) . "PackFormats";
            $output .= "class {$className}:\n";
            $processedConsts = [];
            foreach ($categoryStructs as $struct) {
                $enumName = $struct["enumName"];
                $constName = $this->getConstName($enumName, $category);
                if (in_array($constName, $processedConsts)) {
                    continue;
                }
                $processedConsts[] = $constName;

                $pyStructFormat = $this->generatePythonStructFormat($struct);
                $structSize = $this->calculateStructSize($struct);

                $output .= $this->generatePythonDocComment($struct);
                $output .= "    # Format: {$pyStructFormat}\n";
                $output .= "    # Size: {$structSize} bytes\n";
                $output .= "    {$constName}: Tuple[str, int] = (\"{$pyStructFormat}\", {$structSize})\n\n";
            }
            $output = rtrim($output) . "\n\n";
        }
        $output = rtrim($output) . "# --- End Pack Format Classes ---\n\n";

        // --- 3. Generate PackFormat Class ---
        $output .= "# --- PackFormat Class ---\n";
        $output .= "class PackFormat:\n";
        $output .=
            "    # This map holds the pre-computed (format, size) tuples\n";
        $output .= "    _EVENT_FORMAT_MAP: Dict[int, Tuple[str, int]] = {\n";
        foreach ($this->allEnums as $id => $enumName) {
            $category = getCategory($id);
            $className = ucfirst($category) . "PackFormats";
            $constName = $this->getConstName($enumName, $category);
            $output .= "        Events.{$enumName}.value: {$className}.{$constName},\n";
        }
        $output .= "    }\n\n";

        $output .=
            "    # This map holds the pre-computed keys for each event\n";
        $output .= $this->generateKeyMap_PYTHON(); //

        $output .= $this->getPackFormatStaticMethods_PYTHON();
        $output .= "# --- End PackFormat Class ---\n\n";

        $output .= "# --- CommandPacker Class ---\n";
        $output .= $this->getCommandPackerClass_PYTHON();
        $output .= "# --- End CommandPacker Class ---\n\n";

        $output .= $this->getHelperFunctions_PYTHON(); // --- NEW ---

        file_put_contents($outputFile, $output);
        echo "Successfully generated {$outputFile}\n";
    }

    /**
     * Gets the constant name (e.g., PACK_SPRITE_ADD or UNPACK_PHYSICS_COLLISION)
     */
    private function getConstName(string $enumName, string $category): string
    {
        $constName = "PACK_{$enumName}";
        if (
            $category === "physics" &&
            in_array($enumName, [
                "PHYSICS_COLLISION_BEGIN",
                "PHYSICS_COLLISION_SEPARATE",
                "PHYSICS_SYNC_TRANSFORM",
            ])
        ) {
            if (
                $enumName === "PHYSICS_COLLISION_BEGIN" ||
                $enumName === "PHYSICS_COLLISION_SEPARATE"
            ) {
                $constName = "UNPACK_PHYSICS_COLLISION";
            } else {
                $constName = "UNPACK_PHYSICS_SYNC_TRANSFORM";
            }
        }
        return $constName;
    }

    /**
     * Generates a Python comment block for a pack format constant.
     */
    private function generatePythonDocComment(array $struct): string
    {
        $comment = "    \"\"\"\n";
        $comment .= "    Maps to Swift: `{$struct["name"]}`\n";
        if ($struct["isDynamic"]) {
            //
            $comment .= "    (Header struct)\n";
        }
        foreach ($struct["members"] as $member) {
            //
            $comment .= "    - {$member["name"]}: {$member["type"]} ({$member["comment"]})\n"; //
        }
        $comment .= "    \"\"\"\n";
        return $comment;
    }

    /**
     * Generates the final, pre-computed Python struct format string.
     */
    private function generatePythonStructFormat(array $struct): string
    {
        if (empty($struct["members"])) {
            return "";
        }

        $pyFormat = "<"; // Start with Little-Endian
        foreach ($struct["members"] as $member) {
            $type = $member["type"];
            $name = $member["name"];

            if (isset($member["count"]) && $type === "u8") {
                $pyFormat .= $member["count"] . "x"; // 'x' is padding
                continue; // Move to next member
            }

            // Handle fixed-size arrays first
            if (str_starts_with($type, "char[")) {
                //
                preg_match("/\[(\d+)\]/", $type, $matches);
                $pyFormat .= $matches[1] . "s";
            } elseif (str_starts_with($type, "u8[")) {
                //
                preg_match("/\[(\d+)\]/", $type, $matches);
                $pyFormat .= $matches[1] . "x"; // u8 array is padding
            }
            // Handle special padding names
            elseif (str_starts_with($name, "_padding")) {
                //
                if ($type === "u32") {
                    $pyFormat .= "4x";
                } elseif ($type === "u16") {
                    $pyFormat .= "2x";
                } elseif ($type === "u8") {
                    $pyFormat .= "x";
                } else {
                    $pyFormat .= self::TYPE_MAP[$type] ?? "?";
                }
            }
            // Handle simple types
            else {
                $pyFormat .= self::TYPE_MAP[$type] ?? "?";
            }
        }

        return $pyFormat;
    }

    /**
     * Calculates the total byte size of a struct's fixed-size members.
     */
    private function calculateStructSize(array $struct): int
    {
        if (empty($struct["members"])) {
            return 0;
        }

        $totalSize = 0;
        foreach ($struct["members"] as $member) {
            $type = $member["type"];

            if (isset($member["count"]) && $type === "u8") {
                $totalSize +=
                    (int) $member["count"] * self::C_TYPE_SIZE_MAP["u8"];
                continue;
            }

            // Handle fixed-size arrays
            if (str_starts_with($type, "char[")) {
                //
                preg_match("/\[(\d+)\]/", $type, $matches);
                $totalSize += (int) $matches[1] * self::C_TYPE_SIZE_MAP["char"];
            } elseif (str_starts_with($type, "u8[")) {
                //
                preg_match("/\[(\d+)\]/", $type, $matches);
                $totalSize += (int) $matches[1] * self::C_TYPE_SIZE_MAP["u8"];
            }
            // Handle simple types
            else {
                $totalSize += self::C_TYPE_SIZE_MAP[$type] ?? 0;
            }
        }
        return $totalSize;
    }

    /**
     * Generates a Python map of [eventId => [key1, key2, ...]]
     * This map is used by unpack() to correctly label payload data.
     */
    private function generateKeyMap_PYTHON(): string
    {
        $keyMapOutput = "    _EVENT_KEY_MAP: Dict[int, List[str]] = {\n";

        // Use allStructs which maps eventId to struct definition
        foreach ($this->allStructs as $struct) {
            //
            $eventId = $struct["eventId"]; //
            $members = $struct["members"]; //
            $keys = [];

            // This filter logic MUST match generatePythonStructFormat
            foreach ($members as $member) {
                $name = $member["name"]; //
                $type = $member["type"]; //

                if (str_starts_with($name, "_padding")) {
                    //
                    continue; // Skip padding members
                }
                if (str_starts_with($type, "u8[")) {
                    //
                    continue; // Skip padding arrays
                }

                // This member's value will be returned by struct.unpack_from
                $keys[] = "'{$name}'";
            }

            if (empty($keys)) {
                $keyMapOutput .= "        {$eventId}: [],\n";
            } else {
                $keyMapOutput .=
                    "        {$eventId}: [" . implode(", ", $keys) . "],\n";
            }
        }
        $keyMapOutput .= "    }\n\n";
        return $keyMapOutput;
    }
    // --- END NEW METHOD ---

    /**
     * Returns the implementation of the PackFormat class as a Python code string.
     */
    private function getPackFormatStaticMethods_PYTHON(): string
    {
        // --- MODIFIED ---
        // Updated the "Generic Fixed-Size Event Handler" logic
        return <<<'PYTHON'

            @staticmethod
            def get_info(event_type_value: int) -> Optional[Tuple[str, int]]:
                """
                Gets the pre-computed (format_string, size) tuple for a given event ID.
                """
                return PackFormat._EVENT_FORMAT_MAP.get(event_type_value)

            @staticmethod
            def unpack(events_blob: bytes) -> List[Dict[str, Any]]:
                """
                Unpacks a binary blob of events (Assumes <I for count/type).
                """
                events = []
                blob_length = len(events_blob)
                if blob_length < 4:
                    return []

                try:
                    # PHP 'V' = unsigned 32-bit LE -> Python '<I'
                    event_count = struct.unpack_from("<I", events_blob, 0)[0]
                    offset = 4
                except struct.error:
                    print("PackFormat.unpack: Failed to unpack event count.", file=sys.stderr)
                    return []

                for i in range(event_count):
                    # Header: <I (type) + <Q (timestamp) = 4 + 8 = 12 bytes
                    header_size = 12
                    if offset + header_size > blob_length:
                        print(f"PackFormat.unpack Loop {i}/{event_count}: Not enough data for header. Offset={offset}", file=sys.stderr)
                        break

                    try:
                        header_data = struct.unpack_from("<IQ", events_blob, offset)
                        offset += header_size
                        event_type, timestamp = header_data
                        event = {"type": event_type, "timestamp": timestamp}
                    except struct.error:
                        print(f"PackFormat.unpack Loop {i}/{event_count}: Failed to unpack header. Offset={offset}", file=sys.stderr)
                        break

                    try:
                        event_enum_val = Events(event_type)
                    except ValueError:
                        event_enum_val = None

                    # --- Manual Unpacking for Variable-Length Events ---
                    try:
                        if event_type == Events.SPRITE_TEXTURE_LOAD.value:
                            fmt, size = PackFormat.get_info(event_type) # ("<qqI4x", 24)
                            if offset + size > blob_length: raise EOFError("TEXTURE_LOAD fixed part")

                            unpacked = struct.unpack_from(fmt, events_blob, offset)
                            offset += size
                            event["id1"], event["id2"], filename_length = unpacked

                            if offset + filename_length > blob_length: raise EOFError("TEXTURE_LOAD variable part")
                            event["filename"] = events_blob[offset:offset+filename_length].decode('utf-8')
                            offset += filename_length
                            events.append(event)

                        elif event_type == Events.PLUGIN_LOAD.value:
                            fmt, size = PackFormat.get_info(event_type) # ("<I", 4)
                            if offset + size > blob_length: raise EOFError("PLUGIN_LOAD fixed part")

                            path_length = struct.unpack_from(fmt, events_blob, offset)[0]
                            offset += size
                            event["pathLength"] = path_length

                            if offset + path_length > blob_length: raise EOFError("PLUGIN_LOAD variable part")
                            event["path"] = events_blob[offset:offset+path_length].decode('utf-8')
                            offset += path_length
                            events.append(event)

                        elif event_type == Events.AUDIO_LOAD.value:
                            fmt, size = PackFormat.get_info(event_type) # ("<I", 4)
                            if offset + size > blob_length: raise EOFError("AUDIO_LOAD fixed part")

                            path_length = struct.unpack_from(fmt, events_blob, offset)[0]
                            offset += size
                            event["pathLength"] = path_length

                            if offset + path_length > blob_length: raise EOFError("AUDIO_LOAD variable part")
                            event["path"] = events_blob[offset:offset+path_length].decode('utf-8')
                            offset += path_length
                            events.append(event)

                        elif event_type == Events.TEXT_ADD.value:
                            fmt, size = PackFormat.get_info(event_type) # ("<qqdddBBBB4xfII4x", 64)
                            if offset + size > blob_length: raise EOFError("TEXT_ADD fixed part")

                            unpacked = struct.unpack_from(fmt, events_blob, offset)
                            offset += size

                            keys = ["id1", "id2", "positionX", "positionY", "positionZ", "r", "g", "b", "a", "fontSize", "fontPathLength", "textLength"]
                            event.update(zip(keys, unpacked))

                            font_path_len = event["fontPathLength"]
                            text_len = event["textLength"]

                            if offset + font_path_len > blob_length: raise EOFError("TEXT_ADD font path")
                            event["fontPath"] = events_blob[offset:offset+font_path_len].decode('utf-8')
                            offset += font_path_len

                            if offset + text_len > blob_length: raise EOFError("TEXT_ADD text")
                            event["text"] = events_blob[offset:offset+text_len].decode('utf-8')
                            offset += text_len
                            events.append(event)

                        elif event_type == Events.TEXT_SET_STRING.value:
                            fmt, size = PackFormat.get_info(event_type) # ("<qqI4x", 24)
                            if offset + size > blob_length: raise EOFError("TEXT_SET_STRING fixed part")

                            unpacked = struct.unpack_from(fmt, events_blob, offset)
                            offset += size

                            keys = ["id1", "id2", "textLength"]
                            event.update(zip(keys, unpacked))

                            text_len = event["textLength"]
                            if offset + text_len > blob_length: raise EOFError("TEXT_SET_STRING text")
                            event["text"] = events_blob[offset:offset+text_len].decode('utf-8')
                            offset += text_len
                            events.append(event)

                        elif event_enum_val is not None:
                            # --- Generic Fixed-Size Event Handler ---
                            payload_info = PackFormat.get_info(event_type)
                            if payload_info is None:
                                raise ValueError(f"Could not get info for known event type {event_type}")

                            payload_format, payload_size = payload_info

                            if offset + payload_size > blob_length:
                                raise EOFError(f"{event_enum_val.name} payload (size {payload_size})")

                            if payload_size > 0:
                                unpacked = struct.unpack_from(payload_format, events_blob, offset)

                                # --- MODIFIED BLOCK ---
                                # Use the pre-computed key map instead of generic v{i} keys
                                keys = PackFormat._EVENT_KEY_MAP.get(event_type)

                                if keys is not None:
                                    if len(keys) == len(unpacked):
                                        payload_data = dict(zip(keys, unpacked))
                                    else:
                                        # Error: struct definition and key map are out of sync
                                        print(f"PackFormat.unpack: Key/Value mismatch for {event_enum_val.name}. Keys: {len(keys)}, Vals: {len(unpacked)}", file=sys.stderr)
                                        payload_data = {f"v{i}": val for i, val in enumerate(unpacked)}
                                else:
                                    # Fallback for events missing from key map (shouldn't happen)
                                    payload_data = {f"v{i}": val for i, val in enumerate(unpacked)}

                                event.update(payload_data)
                                # --- END MODIFIED BLOCK ---

                                events.append(event)
                            else:
                                events.append(event) # No payload

                            offset += payload_size

                        else:
                            print(f"PackFormat.unpack: Unknown event type {event_type}. Cannot continue parsing.", file=sys.stderr)
                            break

                    except EOFError as e:
                         print(f"PackFormat.unpack: Not enough data for {e}. Stopping parse.", file=sys.stderr)
                         break
                    except struct.error as e:
                        print(f"PackFormat.unpack: Struct error for {event_enum_val.name if event_enum_val else event_type}: {e}", file=sys.stderr)
                        break
                    except Exception as e:
                        print(f"PackFormat.unpack: General error on {event_enum_val.name if event_enum_val else event_type}: {e}", file=sys.stderr)
                        break

                return events
        PYTHON;
    }

    /**
     * Returns the implementation of the CommandPacker class as a Python code string.
     */
    private function getCommandPackerClass_PYTHON(): string
    {
        // This is unmodified, but needs to be here.
        return <<<'PYTHON'
        class CommandPacker:

            def __init__(self, chunk_size: int = 0, chunk_callback: Optional[Callable] = None):
                self._event_stream = bytearray()
                self._command_count = 0
                self._event_buffer: List[Dict[str, Any]] = []
                self._chunk_size = chunk_size
                self._chunk_callback = chunk_callback

            def add(self, event_type: Events, data: list):
                """
                Adds a new event to the packer.

                :param event_type: The Events enum member.
                :param data: A list of arguments for the event, matching the
                             struct definition. For dynamic events, the final
                             arguments must be pre-encoded bytes.
                """
                if self._chunk_size > 0:
                    self._event_buffer.append({"type": event_type, "data": data})
                    if len(self._event_buffer) >= self._chunk_size:
                        self._pack_buffered_events()
                else:
                    self._pack_event(event_type, data)

            def _pack_event(self, event_type: Events, data: list):
                type_value = event_type.value
                try:
                    # Pack header: <I (type) <Q (timestamp) = 12 bytes
                    self._event_stream.extend(struct.pack("<IQ", type_value, 0))
                except struct.error as e:
                    print(f"CommandPacker ({event_type.name}): Failed to pack header: {e}", file=sys.stderr)
                    return

                try:
                    # --- Manual Packing for Variable-Length Events ---
                    # These events have a (format, size) for their *header*
                    # and expect raw bytes as their final argument(s).

                    if event_type == Events.SPRITE_TEXTURE_LOAD:
                        # data = [id0(q), id1(q), filenameLength(I), filename_bytes(b"")]
                        if len(data) != 4: raise ValueError(f"TEXTURE_LOAD: Expected 4 args, got {len(data)}")
                        fmt, _ = PackFormat.get_info(type_value) # ("<qqI4x", 24)
                        self._event_stream.extend(struct.pack(fmt, data[0], data[1], data[2]))
                        self._event_stream.extend(data[3]) # data[3] is already bytes

                    elif event_type == Events.PLUGIN_LOAD:
                        # data = [pathLength(I), path_bytes(b"")]
                        if len(data) != 2: raise ValueError(f"PLUGIN_LOAD: Expected 2 args, got {len(data)}")
                        fmt, _ = PackFormat.get_info(type_value) # ("<I", 4)
                        self._event_stream.extend(struct.pack(fmt, data[0]))
                        self._event_stream.extend(data[1]) # data[1] is already bytes

                    elif event_type == Events.AUDIO_LOAD:
                        # data = [pathLength(I), path_bytes(b"")]
                        if len(data) != 2: raise ValueError(f"AUDIO_LOAD: Expected 2 args, got {len(data)}")
                        fmt, _ = PackFormat.get_info(type_value) # ("<I", 4)
                        self._event_stream.extend(struct.pack(fmt, data[0]))
                        self._event_stream.extend(data[1]) # data[1] is already bytes

                    elif event_type == Events.TEXT_ADD:
                        # data = [id0(q), id1(q), ..., fontPath_bytes(b""), text_bytes(b"")]
                        if len(data) != 14: raise ValueError(f"TEXT_ADD: Expected 14 args, got {len(data)}")
                        fmt, _ = PackFormat.get_info(type_value) # ("<qqdddBBBB4xfII4x", 64)
                        self._event_stream.extend(struct.pack(
                            fmt,
                            data[0], data[1], data[2], data[3], data[4],  # id, pos
                            data[5], data[6], data[7], data[8],  # rgba
                            data[9], data[10], data[11]  # fontSize, fontPathLen, textLen
                        ))
                        self._event_stream.extend(data[12]) # fontPath_bytes
                        self._event_stream.extend(data[13]) # text_bytes

                    elif event_type == Events.TEXT_SET_STRING:
                        # data = [id0(q), id1(q), textLength(I), text_bytes(b"")]
                        if len(data) != 4: raise ValueError(f"TEXT_SET_STRING: Expected 4 args, got {len(data)}")
                        fmt, _ = PackFormat.get_info(type_value) # ("<qqI4x", 24)
                        self._event_stream.extend(struct.pack(fmt, data[0], data[1], data[2]))
                        self._event_stream.extend(data[3]) # text_bytes

                    else:
                        # --- Fixed-Size Event Packing Logic ---
                        payload_info = PackFormat.get_info(type_value)
                        if payload_info is None:
                            raise ValueError(f"Could not get payload info for {event_type.name}")

                        fmt, size = payload_info

                        if not fmt and data:
                            raise ValueError(f"Format is empty but data was provided for {event_type.name}")

                        if fmt:
                            # fmt is the pre-compiled struct string (e.g., "<qqd")
                            self._event_stream.extend(struct.pack(fmt, *data))

                    self._command_count += 1

                except (struct.error, ValueError, TypeError) as e:
                    print(f"CommandPacker ({event_type.name}): Error during pack! {e}", file=sys.stderr)
                    print(f"  Data: {data}", file=sys.stderr)

            def _pack_buffered_events(self):
                if not self._event_buffer:
                    return
                for event in self._event_buffer:
                    self._pack_event(event["type"], event["data"])

                if self._chunk_callback:
                    self._chunk_callback(len(self._event_buffer), self._command_count)

                self._event_buffer = []

            def flush(self):
                if self._event_buffer:
                    self._pack_buffered_events()

            def finalize(self) -> bytes:
                self.flush()
                if self._command_count == 0:
                    return b""
                # Prepend count (<I) and return the full byte stream
                return struct.pack("<I", self._command_count) + self._event_stream

            def get_buffer_count(self) -> int:
                return len(self._event_buffer)

            def get_total_event_count(self) -> int:
                return self._command_count + len(self._event_buffer)
        PYTHON;
    }

    // --- NEW METHOD ---
    /**
     * Returns helper functions, like Id_Generate, as a Python code string.
     */
    private function getHelperFunctions_PYTHON(): string
    {
        return <<<'PYTHON'
        def Id_Generate() -> Tuple[int, int]:
            """Generates a unique ID tuple."""
            return (random.randint(0, 2**63 - 1), random.randint(0, 2**63 - 1))
        PYTHON;
    }
}
