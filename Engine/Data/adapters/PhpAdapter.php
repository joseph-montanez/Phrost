<?php

class PhpAdapter extends BaseAdapter
{
    protected function doGeneration(): void
    {
        $outputFile = __DIR__ . "/../out/php/Events.php";
        $namespace = "Phrost";

        $output = "<?php\n\n";
        $output .= $this->getFileHeader("PhpAdapter.php");
        $output .= "namespace {$namespace};\n\n";

        // --- 1. Generate Events Enum ---
        $output .= "// --- Events Enum ---\n";
        $output .= "enum Events: int\n{\n";
        $lastCategory = null;
        foreach ($this->allEnums as $id => $name) {
            $category = getCategory($id);
            if ($lastCategory !== null && $category !== $lastCategory) {
                $output .= "\n";
            }
            $output .= "    case {$name} = {$id};\n";
            $lastCategory = $category;
        }
        $output .= "}\n// --- End Events Enum ---\n\n";

        // --- 2. Generate Pack Format Classes ---
        $output .= "// --- Pack Format Classes ---\n";
        foreach ($this->groupedStructs as $category => $categoryStructs) {
            $className = ucfirst($category) . "PackFormats";
            $output .= "class {$className}\n{\n";
            $processedConsts = [];
            foreach ($categoryStructs as $struct) {
                $enumName = $struct["enumName"];
                $constName = $this->getPhpConstName($enumName, $category);
                if (in_array($constName, $processedConsts)) {
                    continue;
                }
                $processedConsts[] = $constName;

                $output .= $this->generateDocComment($struct);
                $output .=
                    "    public const {$constName} = \"" .
                    $this->generatePackFormat($struct) .
                    "\";\n\n";
            }
            $output = rtrim($output) . "\n}\n\n";
        }
        $output = rtrim($output) . "\n// --- End Pack Format Classes ---\n\n";

        // --- 3. Generate PackFormat Class ---
        $output .= "// --- PackFormat Class ---\nclass PackFormat\n{\n";
        $output .=
            "    /** @var array<int, array{format: string, size: int}> */\n";
        $output .= "    private static array \$cache = [];\n\n";
        $output .= "    /** @var array<int, string> */\n";
        $output .= "    private const EVENT_FORMAT_MAP = [\n";
        foreach ($this->allEnums as $id => $enumName) {
            $category = getCategory($id);
            $className = ucfirst($category) . "PackFormats";
            $constName = $this->getPhpConstName($enumName, $category);
            $output .= "        Events::{$enumName}->value => {$className}::{$constName},\n";
        }
        $output .= "    ];\n";
        $output .= $this->getPackFormatStaticMethods();
        $output .= "}\n// --- End PackFormat Class ---\n\n";

        // --- 4. Generate CommandPacker Class ---
        $output .= "// --- CommandPacker Class ---\n";
        $output .= $this->getCommandPackerClass();
        $output .= "// --- End CommandPacker Class ---\n";

        file_put_contents($outputFile, $output);
        echo "Successfully generated {$outputFile}\n";
    }

    private function getPhpConstName(string $enumName, string $category): string
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

    // --- Start of Pasted Functions ---

    private function generatePackFormat(array $struct): string
    {
        if (empty($struct["members"])) {
            return "";
        }

        $parts = [];
        $variableParts = [];

        foreach ($struct["members"] as $member) {
            $type = $member["type"];
            $name = $member["name"];
            $code = "?"; // Default

            // --- NEW: Handle "count" property ---
            if (isset($member["count"]) && $type === "u8") {
                $code = "x" . $member["count"];
            }
            // --- End NEW ---
            // signed 64-bit, little endian
            elseif ($type === "i64") {
                $code = "q";
            }
            // unsigned 64-bit, little endian (Using 'P' as per your original file logic, 'Q' is also LE)
            elseif ($type === "u64") {
                $code = "Q"; // Corrected to 'Q' for unsigned 64-bit LE
            }
            // signed 32-bit, little endian
            elseif ($type === "i32") {
                $code = "l";
            }
            // unsigned 32-bit, little endian
            elseif ($type === "u32") {
                $code = "V";
            }
            // signed 16-bit, little endian
            elseif ($type === "i16") {
                $code = "s";
            }
            // unsigned 16-bit, little endian
            elseif ($type === "u16") {
                $code = "S";
            }
            // signed 8-bit
            elseif ($type === "i8") {
                $code = "c";
            }
            // unsigned 8-bit
            elseif ($type === "u8") {
                $code = "C";
            }
            // float 32-bit, little endian
            elseif ($type === "f32") {
                $code = "g";
            }
            // double 64-bit, little endian
            elseif ($type === "f64") {
                $code = "e";
            } elseif (str_starts_with($type, "char[")) {
                preg_match("/\[(\d+)\]/", $type, $matches);
                $count = $matches[1];
                $code = "a{$count}";
            } elseif (str_starts_with($type, "u8[")) {
                preg_match("/\[(\d+)\]/", $type, $matches);
                $count = $matches[1];
                $code = "x{$count}";
            }

            if (str_starts_with($name, "_padding")) {
                // This block is now mostly redundant if you use "count"
                // but we keep it as a fallback for simple types.
                if ($type === "u32") {
                    $code = "x4";
                } elseif ($type === "u16") {
                    $code = "x2";
                } elseif ($type === "u8" && !isset($member["count"])) {
                    $code = "x";
                }
            }

            $parts[] = "{$code}{$name}";
        }

        if ($struct["isDynamic"]) {
            if ($struct["name"] === "PackedTextureLoadHeaderEvent") {
                $variableParts[] = "a*filename";
            } elseif ($struct["name"] === "PackedPluginLoadHeaderEvent") {
                $variableParts[] = "a*path";
            } elseif ($struct["name"] === "PackedAudioLoadEvent") {
                $variableParts[] = "a*path";
            } elseif ($struct["name"] === "PackedTextAddEvent") {
                $variableParts[] = "a*fontPath";
                $variableParts[] = "a*text";
            } elseif ($struct["name"] === "PackedTextSetStringEvent") {
                $variableParts[] = "a*text";
            }
        }

        return implode("/", array_merge($parts, $variableParts));
    }

    private function generateDocComment(array $struct): string
    {
        $comment = "    /**\n";
        $comment .= "     * Maps to Swift: `{$struct["name"]}`\n";
        if ($struct["isDynamic"]) {
            $comment .= "     * (Header struct)\n";
        }
        foreach ($struct["members"] as $member) {
            $comment .= "     * - {$member["name"]}: {$member["type"]} ({$member["comment"]})\n";
        }
        $comment .= "     */\n";
        return $comment;
    }

    private function getPackFormatStaticMethods(): string
    {
        // This is the static logic from your PackFormat class
        return <<<'PHP'

            /**
             * Gets descriptive format and calculates size based on summing format codes.
             * For variable formats ('*'), size is only for the fixed part. Includes padding codes (x).
             */
            public static function getInfo(int $eventTypeValue): ?array
            {
                if (isset(self::$cache[$eventTypeValue])) {
                    return self::$cache[$eventTypeValue];
                }

                $descriptiveFormat = self::EVENT_FORMAT_MAP[$eventTypeValue] ?? null;
                if ($descriptiveFormat === null) {
                    return null;
                }

                // --- Reverted Size Calculation Logic ---
                static $sizeMap = [
                    "a" => 1, "A" => 1, "Z" => 1, "h" => 0.5, "H" => 0.5, "c" => 1,
                    "C" => 1, "s" => 2, "S" => 2, "n" => 2, "v" => 2, "l" => 4,
                    "L" => 4, "N" => 4, "V" => 4, "i" => 4, "I" => 4, "f" => 4,
                    "g" => 4, "G" => 4, "q" => 8, "Q" => 8, "J" => 8, "P" => 8,
                    "d" => 8, "e" => 8, "E" => 8, "x" => 1, "X" => -1, "@" => 0,
                ];

                $totalSize = 0;
                foreach (explode("/", $descriptiveFormat) as $part) {
                    // Match format code (letter) and optional repeater (* or digits)
                    if (preg_match("/^([a-zA-Z])(\*|\d*)/", $part, $matches)) {
                        // Use ^ to match start
                        $code = $matches[1];
                        $repeater = $matches[2];

                        if ($repeater === "*") {
                            // It's a variable length part, stop calculating size here
                            // Check against a list of known dynamic events
                            static $dynamicEvents = [
                                Events::SPRITE_TEXTURE_LOAD->value,
                                Events::PLUGIN_LOAD->value,
                                Events::TEXT_ADD->value,
                                Events::TEXT_SET_STRING->value,
                                Events::AUDIO_LOAD->value,
                                Events::GEOM_ADD_PACKED->value
                            ];

                            if (in_array($eventTypeValue, $dynamicEvents)) {
                                break;
                            } else {
                                error_log(
                                    "PackFormat::getInfo: Unexpected '*' in format '{$descriptiveFormat}' for event {$eventTypeValue}. Size calculation might be wrong."
                                );
                                break; // Stop calculation
                            }
                        }

                        $count = $repeater === "" || !ctype_digit($repeater)
                                    ? 1
                                    : (int) $repeater;
                        $size = $sizeMap[$code] ?? 0;
                        if ($size === 0 && $code !== "@") {
                            error_log(
                                "PackFormat::getInfo: Unknown format code '{$code}' in format '{$descriptiveFormat}' for event {$eventTypeValue}."
                            );
                        }

                        if ($code === "h" || $code === "H") {
                            $totalSize += ceil($count * $size);
                        } else {
                            $totalSize += $count * $size;
                        }
                    } else {
                        if (!empty(trim($part))) {
                            error_log(
                                "PackFormat::getInfo: Could not parse format part '{$part}' in format '{$descriptiveFormat}' for event {$eventTypeValue}."
                            );
                        }
                    }
                }

                $result = ["format" => $descriptiveFormat, "size" => (int) $totalSize];
                self::$cache[$eventTypeValue] = $result;
                return $result;
            }

            /**
             * Unpacks a binary blob of events (Assumes V for count/type).
             * NOTE: Primarily for PHP-side use/testing; Swift handles its own unpacking.
             */
            public static function unpack(string $eventsBlob): array
            {
                $events = [];
                $blobLength = strlen($eventsBlob);
                if ($blobLength < 4) {
                    return [];
                }

                $countUnpack = unpack("Vcount", $eventsBlob);
                if ($countUnpack === false) {
                    error_log("PackFormat::unpack: Failed to unpack event count.");
                    return [];
                }
                $eventCount = $countUnpack["count"];
                $offset = 4;

                for ($i = 0; $i < $eventCount; $i++) {
                    $headerSize = 4 + 8; // type (V) + timestamp (Q) = 12 bytes
                    if ($offset + $headerSize > $blobLength) {
                        error_log("PackFormat::unpack Loop {$i}/{$eventCount}: Not enough data for header. Offset={$offset}");
                        break;
                    }

                    $headerData = unpack("Vtype/Qtimestamp", substr($eventsBlob, $offset, $headerSize));
                    if ($headerData === false) {
                        error_log("PackFormat::unpack Loop {$i}/{$eventCount}: Failed to unpack header. Offset={$offset}");
                        break;
                    }
                    $offset += $headerSize;
                    $eventType = $headerData["type"];
                    $eventEnumValue = Events::tryFrom($eventType);

                    if ($eventType === Events::SPRITE_TEXTURE_LOAD->value) {
                        $fixedPartSize = 24; // q(8) + q(8) + V(4) + x4(4)
                        if ($offset + $fixedPartSize > $blobLength) { error_log("PackFormat::unpack (TEXTURE_LOAD): Not enough data for fixed part."); break; }
                        $fixedPartData = unpack("qid1/qid2/VfilenameLength/x4padding", substr($eventsBlob, $offset, $fixedPartSize));
                        if ($fixedPartData === false) { error_log("PackFormat::unpack (TEXTURE_LOAD): Failed to unpack fixed part."); break; }
                        $offset += $fixedPartSize;
                        $filenameLength = $fixedPartData["filenameLength"];
                        if ($offset + $filenameLength > $blobLength) { error_log("PackFormat::unpack (TEXTURE_LOAD): Not enough data for variable part."); break; }
                        $stringPartData = ($filenameLength > 0) ? unpack("a{$filenameLength}filename", substr($eventsBlob, $offset, $filenameLength)) : ["filename" => ""];
                        $offset += $filenameLength;
                        $events[] = $headerData + $fixedPartData + $stringPartData;

                    } elseif ($eventType === Events::PLUGIN_LOAD->value) {
                        $fixedPartSize = 4; // V(4)
                        if ($offset + $fixedPartSize > $blobLength) { error_log("PackFormat::unpack (PLUGIN_LOAD): Not enough data for fixed part."); break; }
                        $fixedPartData = unpack("VpathLength", substr($eventsBlob, $offset, $fixedPartSize));
                        if ($fixedPartData === false) { error_log("PackFormat::unpack (PLUGIN_LOAD): Failed to unpack fixed part."); break; }
                        $offset += $fixedPartSize;
                        $pathLength = $fixedPartData["pathLength"];
                        if ($offset + $pathLength > $blobLength) { error_log("PackFormat::unpack (PLUGIN_LOAD): Not enough data for variable part."); break; }
                        $stringPartData = ($pathLength > 0) ? unpack("a{$pathLength}path", substr($eventsBlob, $offset, $pathLength)) : ["path" => ""];
                        $offset += $pathLength;
                        $events[] = $headerData + $fixedPartData + $stringPartData;

                    } elseif ($eventType === Events::AUDIO_LOAD->value) {
                         $fixedPartSize = 4; // V(4)
                        if ($offset + $fixedPartSize > $blobLength) { error_log("PackFormat::unpack (AUDIO_LOAD): Not enough data for fixed part."); break; }
                        $fixedPartData = unpack("VpathLength", substr($eventsBlob, $offset, $fixedPartSize));
                        if ($fixedPartData === false) { error_log("PackFormat::unpack (AUDIO_LOAD): Failed to unpack fixed part."); break; }
                        $offset += $fixedPartSize;
                        $pathLength = $fixedPartData["pathLength"];
                        if ($offset + $pathLength > $blobLength) { error_log("PackFormat::unpack (AUDIO_LOAD): Not enough data for variable part."); break; }
                        $stringPartData = ($pathLength > 0) ? unpack("a{$pathLength}path", substr($eventsBlob, $offset, $pathLength)) : ["path" => ""];
                        $offset += $pathLength;
                        $events[] = $headerData + $fixedPartData + $stringPartData;

                    } elseif ($eventType === Events::TEXT_ADD->value) {
                        // Manually check format: qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4/gfontSize/VfontPathLength/VtextLength/x4
                        $fixedPartSize = 8+8+8+8+8+1+1+1+1+4+4+4+4+4; // 64 bytes
                        if ($offset + $fixedPartSize > $blobLength) { error_log("PackFormat::unpack (TEXT_ADD): Not enough data for fixed part."); break; }
                        $fixedPartData = unpack(
                            "qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4padding1/gfontSize/VfontPathLength/VtextLength/x4padding2",
                            substr($eventsBlob, $offset, $fixedPartSize)
                        );
                        if ($fixedPartData === false) { error_log("PackFormat::unpack (TEXT_ADD): Failed to unpack fixed part."); break; }
                        $offset += $fixedPartSize;
                        $fontPathLength = $fixedPartData["fontPathLength"];
                        $textLength = $fixedPartData["textLength"];

                        if ($offset + $fontPathLength > $blobLength) { error_log("PackFormat::unpack (TEXT_ADD): Not enough data for font path."); break; }
                        $fontPathData = ($fontPathLength > 0) ? unpack("a{$fontPathLength}fontPath", substr($eventsBlob, $offset, $fontPathLength)) : ["fontPath" => ""];
                        $offset += $fontPathLength;

                        if ($offset + $textLength > $blobLength) { error_log("PackFormat::unpack (TEXT_ADD): Not enough data for text."); break; }
                        $textData = ($textLength > 0) ? unpack("a{$textLength}text", substr($eventsBlob, $offset, $textLength)) : ["text" => ""];
                        $offset += $textLength;
                        $events[] = $headerData + $fixedPartData + $fontPathData + $textData;

                    } elseif ($eventType === Events::TEXT_SET_STRING->value) {
                        $fixedPartSize = 24; // q(8) + q(8) + V(4) + x4(4)
                        if ($offset + $fixedPartSize > $blobLength) { error_log("PackFormat::unpack (TEXT_SET_STRING): Not enough data for fixed part."); break; }
                        $fixedPartData = unpack("qid1/qid2/VtextLength/x4padding", substr($eventsBlob, $offset, $fixedPartSize));
                        if ($fixedPartData === false) { error_log("PackFormat::unpack (TEXT_SET_STRING): Failed to unpack fixed part."); break; }
                        $offset += $fixedPartSize;
                        $textLength = $fixedPartData["textLength"];

                        if ($offset + $textLength > $blobLength) { error_log("PackFormat::unpack (TEXT_SET_STRING): Not enough data for text."); break; }
                        $textData = ($textLength > 0) ? unpack("a{$textLength}text", substr($eventsBlob, $offset, $textLength)) : ["text" => ""];
                        $offset += $textLength;
                        $events[] = $headerData + $fixedPartData + $textData;

                    } elseif ($eventEnumValue !== null) {
                        // Handle other known fixed-size events
                        $payloadInfo = self::getInfo($eventType);
                        if ($payloadInfo === null) {
                            error_log("PackFormat::unpack: Could not get info for known event type {$eventType}.");
                            break;
                        }

                        $payloadSize = $payloadInfo["size"];
                        $payloadFormat = $payloadInfo["format"];

                        if ($offset + $payloadSize > $blobLength) {
                            error_log("PackFormat::unpack ({$eventEnumValue->name}): Not enough data for payload (size {$payloadSize}).");
                            break;
                        }

                        if ($payloadSize > 0) {
                            $payloadData = unpack($payloadFormat, substr($eventsBlob, $offset, $payloadSize));
                            if ($payloadData === false) {
                                error_log("PackFormat::unpack ({$eventEnumValue->name}): Failed to unpack payload.");
                                break;
                            }
                            $payloadData = array_filter($payloadData, "is_string", ARRAY_FILTER_USE_KEY);
                            $events[] = $headerData + $payloadData;
                        } else {
                            $events[] = $headerData; // Event with no payload
                        }
                        $offset += $payloadSize;
                    } else {
                        error_log("PackFormat::unpack: Unknown event type {$eventType}. Cannot continue parsing.");
                        error_log(bin2hex($eventsBlob));
                        break;
                    }
                }
                return $events;
            }
        PHP;
    }

    private function getCommandPackerClass(): string
    {
        // This is the static CommandPacker class you provided
        return <<<'PHP'
        class CommandPacker
        {
            private string $eventStream = "";
            private int $commandCount = 0;
            private static array $pureFormatCache = [];
            private array $eventBuffer = [];
            private int $chunkSize = 0;
            private $chunkCallback = null;

            public function __construct(int $chunkSize = 0, $chunkCallback = null)
            {
                $this->chunkSize = $chunkSize;
                $this->chunkCallback = $chunkCallback;
            }

            public function add(Events $type, array $data): void
            {
                if ($this->chunkSize > 0) {
                    $this->eventBuffer[] = ["type" => $type, "data" => $data];
                    if (count($this->eventBuffer) >= $this->chunkSize) {
                        $this->packBufferedEvents();
                    }
                } else {
                    $this->packEvent($type, $data);
                }
            }

            private function packEvent(Events $type, array $data): void
            {
                $typeValue = $type->value;
                $this->eventStream .= pack("VQ", $typeValue, 0); // 12 bytes header (type + timestamp)

                if ($type === Events::SPRITE_TEXTURE_LOAD) {
                    if (count($data) !== 4) { error_log("CommandPacker (TEXTURE_LOAD): Incorrect data count, expected 4."); return; }
                    $packedFixedPart = pack("qqVx4", $data[0], $data[1], $data[2]);
                    $this->eventStream .= $packedFixedPart;
                    $this->eventStream .= $data[3]; // Append filename string

                } elseif ($type === Events::PLUGIN_LOAD) {
                     if (count($data) !== 2) { error_log("CommandPacker (PLUGIN_LOAD): Incorrect data count, expected 2."); return; }
                    $packedFixedPart = pack("V", $data[0]);
                    $this->eventStream .= $packedFixedPart;
                    $this->eventStream .= $data[1]; // Append path string

                } elseif ($type === Events::AUDIO_LOAD) {
                     if (count($data) !== 2) { error_log("CommandPacker (AUDIO_LOAD): Incorrect data count, expected 2."); return; }
                    $packedFixedPart = pack("V", $data[0]);
                    $this->eventStream .= $packedFixedPart;
                    $this->eventStream .= $data[1]; // Append path string

                } elseif ($type === Events::TEXT_ADD) {
                     if (count($data) !== 14) { error_log("CommandPacker (TEXT_ADD): Incorrect data count, expected 14."); return; }
                     // Corrected format: e = f64, g = f32
                    $packedFixedPart = pack("qqeeeCCCCx4gVVx4",
                        $data[0], $data[1], $data[2], $data[3], $data[4], // id1, id2, posXYZ (e)
                        $data[5], $data[6], $data[7], $data[8],             // rgba (C)
                        $data[9], $data[10], $data[11]                      // fontSize(g), fontPathLength(V), textLength(V)
                    );
                    $this->eventStream .= $packedFixedPart;
                    $this->eventStream .= $data[12]; // Append fontPath
                    $this->eventStream .= $data[13]; // Append text

                } elseif ($type === Events::TEXT_SET_STRING) {
                     if (count($data) !== 4) { error_log("CommandPacker (TEXT_SET_STRING): Incorrect data count, expected 4."); return; }
                    $packedFixedPart = pack("qqVx4", $data[0], $data[1], $data[2]);
                    $this->eventStream .= $packedFixedPart;
                    $this->eventStream .= $data[3]; // Append text string

                } else {
                    // --- Fixed-Size Event Packing Logic ---
                    $payloadInfo = PackFormat::getInfo($typeValue);
                    if ($payloadInfo === null) { error_log("CommandPacker ({$type->name}): Could not get payload info."); return; }

                    $pureFormat = self::getPureFormat($payloadInfo["format"]);
                    if (empty($pureFormat) && !empty($data)) { error_log("CommandPacker ({$type->name}): Format is empty but data was provided."); return; }

                    if (empty($pureFormat) && empty($data)) {
                         // Correctly handle no-payload events like AUDIO_STOP_ALL
                    } else {
                        $numericData = array_values($data);
                        try {
                            $packedPayload = pack($pureFormat, ...$numericData);
                            if ($packedPayload === false) {
                                error_log("CommandPacker ({$type->name}): pack() returned false. Format='{$pureFormat}'");
                            } else {
                                $this->eventStream .= $packedPayload;
                            }
                        } catch (\ValueError $e) {
                            error_log("CommandPacker ({$type->name}): ValueError during pack()! Format='{$pureFormat}', Error: {$e->getMessage()}");
                        } catch (\Exception $e) {
                            error_log("CommandPacker ({$type->name}): Exception during pack()! Format='{$pureFormat}', Error: {$e->getMessage()}");
                        }
                    }
                }
                $this->commandCount++;
            }

            private function packBufferedEvents(): void
            {
                if (empty($this->eventBuffer)) { return; }
                foreach ($this->eventBuffer as $event) {
                    $this->packEvent($event["type"], $event["data"]);
                }
                if ($this->chunkCallback !== null) {
                    ($this->chunkCallback)(count($this->eventBuffer), $this->commandCount);
                }
                $this->eventBuffer = [];
            }

            public function flush(): void
            {
                if (!empty($this->eventBuffer)) {
                    $this->packBufferedEvents();
                }
            }

            public function finalize(): string
            {
                $this->flush();
                if ($this->commandCount === 0) {
                    return "";
                }
                return pack("V", $this->commandCount) . $this->eventStream;
            }

            public function getBufferCount(): int
            {
                return count($this->eventBuffer);
            }

            public function getTotalEventCount(): int
            {
                return $this->commandCount + count($this->eventBuffer);
            }

            private static function getPureFormat(string $descriptiveFormat): string
            {
                if (isset(self::$pureFormatCache[$descriptiveFormat])) {
                    return self::$pureFormatCache[$descriptiveFormat];
                }
                $pure = "";
                foreach (explode("/", $descriptiveFormat) as $part) {
                    if (preg_match("/^([a-zA-Z])(\*|\d*)/", $part, $matches)) {
                        $code = $matches[1];
                        $count = $matches[2];
                        if ($count === '*') {
                            break; // Stop at variable part
                        }
                        $pure .= $code . $count;
                    }
                }
                return self::$pureFormatCache[$descriptiveFormat] = $pure;
            }
        }
        PHP;
    }

    // --- End of Pasted Functions ---
}
