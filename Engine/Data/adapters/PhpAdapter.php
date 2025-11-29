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
        // DYNAMIC LOGIC: Build the list of dynamic events based on JSON 'isDynamic' field
        $dynamicEnumEntries = [];
        foreach ($this->allStructs as $struct) {
            if (isset($struct["isDynamic"]) && $struct["isDynamic"] === true) {
                $dynamicEnumEntries[] = "Events::{$struct["enumName"]}->value";
            }
        }
        $dynamicEnumEntries = array_unique($dynamicEnumEntries);
        sort($dynamicEnumEntries);
        $dynamicEventsPhpArray = implode(
            ",\n                        ",
            $dynamicEnumEntries,
        );

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

        $output .= $this->getPackFormatStaticMethods($dynamicEventsPhpArray);
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
            $code = "?";

            if (isset($member["count"]) && $type === "u8") {
                $code = "x" . $member["count"];
            } elseif ($type === "i64") {
                $code = "q";
            } elseif ($type === "u64") {
                $code = "Q";
            } elseif ($type === "i32") {
                $code = "l";
            } elseif ($type === "u32") {
                $code = "V";
            } elseif ($type === "i16") {
                $code = "s";
            } elseif ($type === "u16") {
                $code = "S";
            } elseif ($type === "i8") {
                $code = "c";
            } elseif ($type === "u8") {
                $code = "C";
            } elseif ($type === "f32") {
                $code = "g";
            } elseif ($type === "f64") {
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

        // Logic to guess variable parts for PackFormat string generation
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
            } elseif ($struct["name"] === "PackedUIBeginWindowHeaderEvent") {
                $variableParts[] = "a*title";
            } elseif ($struct["name"] === "PackedUITextHeaderEvent") {
                $variableParts[] = "a*text";
            } elseif ($struct["name"] === "PackedUIButtonHeaderEvent") {
                $variableParts[] = "a*label";
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

    // UPDATED: Now accepts the dynamic events list string
    private function getPackFormatStaticMethods(
        string $dynamicEventsPhpArray,
    ): string {
        return <<<PHP

            /**
             * Gets descriptive format and calculates size based on summing format codes.
             * For variable formats ('*'), size is only for the fixed part. Includes padding codes (x).
             */
            public static function getInfo(int \$eventTypeValue): ?array
            {
                if (isset(self::\$cache[\$eventTypeValue])) {
                    return self::\$cache[\$eventTypeValue];
                }

                \$descriptiveFormat = self::EVENT_FORMAT_MAP[\$eventTypeValue] ?? null;
                if (\$descriptiveFormat === null) {
                    return null;
                }

                static \$sizeMap = [
                    "a" => 1, "A" => 1, "Z" => 1, "h" => 0.5, "H" => 0.5, "c" => 1,
                    "C" => 1, "s" => 2, "S" => 2, "n" => 2, "v" => 2, "l" => 4,
                    "L" => 4, "N" => 4, "V" => 4, "i" => 4, "I" => 4, "f" => 4,
                    "g" => 4, "G" => 4, "q" => 8, "Q" => 8, "J" => 8, "P" => 8,
                    "d" => 8, "e" => 8, "E" => 8, "x" => 1, "X" => -1, "@" => 0,
                ];

                \$totalSize = 0;
                foreach (explode("/", \$descriptiveFormat) as \$part) {
                    if (preg_match("/^([a-zA-Z])(\*|\d*)/", \$part, \$matches)) {
                        \$code = \$matches[1];
                        \$repeater = \$matches[2];

                        if (\$repeater === "*") {
                            // Variable length part detected.
                            static \$dynamicEvents = [
                        $dynamicEventsPhpArray
                            ];

                            if (in_array(\$eventTypeValue, \$dynamicEvents)) {
                                break;
                            } else {
                                error_log(
                                    "PackFormat::getInfo: Unexpected '*' in format '{\$descriptiveFormat}' for event {\$eventTypeValue}. Size calculation might be wrong."
                                );
                                break;
                            }
                        }

                        \$count = \$repeater === "" || !ctype_digit(\$repeater)
                                            ? 1
                                            : (int) \$repeater;
                        \$size = \$sizeMap[\$code] ?? 0;
                        if (\$size === 0 && \$code !== "@") {
                            error_log(
                                "PackFormat::getInfo: Unknown format code '{\$code}' in format '{\$descriptiveFormat}' for event {\$eventTypeValue}."
                            );
                        }

                        if (\$code === "h" || \$code === "H") {
                            \$totalSize += ceil(\$count * \$size);
                        } else {
                            \$totalSize += \$count * \$size;
                        }
                    } else {
                        if (!empty(trim(\$part))) {
                            error_log(
                                "PackFormat::getInfo: Could not parse format part '{\$part}' in format '{\$descriptiveFormat}' for event {\$eventTypeValue}."
                            );
                        }
                    }
                }

                \$result = ["format" => \$descriptiveFormat, "size" => (int) \$totalSize];
                self::\$cache[\$eventTypeValue] = \$result;
                return \$result;
            }

            /**
             * Unpacks a binary blob of events (Assumes V for count/type).
             * NOTE: Primarily for PHP-side use/testing; Swift handles its own unpacking.
             */
            public static function unpack(string \$eventsBlob): array
            {
                \$events = [];
                \$blobLength = strlen(\$eventsBlob);
                if (\$blobLength < 4) {
                    return [];
                }

                \$countUnpack = unpack("Vcount", \$eventsBlob);
                if (\$countUnpack === false) {
                    error_log("PackFormat::unpack: Failed to unpack event count.");
                    return [];
                }
                \$eventCount = \$countUnpack["count"];
                \$offset = 4;

                for (\$i = 0; \$i < \$eventCount; \$i++) {
                    \$headerSize = 4 + 8; // type (V) + timestamp (Q) = 12 bytes
                    if (\$offset + \$headerSize > \$blobLength) {
                        error_log("PackFormat::unpack Loop {\$i}/{\$eventCount}: Not enough data for header. Offset={\$offset}");
                        break;
                    }

                    \$headerData = unpack("Vtype/Qtimestamp", substr(\$eventsBlob, \$offset, \$headerSize));
                    if (\$headerData === false) {
                        error_log("PackFormat::unpack Loop {\$i}/{\$eventCount}: Failed to unpack header. Offset={\$offset}");
                        break;
                    }
                    \$offset += \$headerSize;
                    \$eventType = \$headerData["type"];
                    \$eventEnumValue = Events::tryFrom(\$eventType);

                    if (\$eventType === Events::SPRITE_TEXTURE_LOAD->value) {
                        \$fixedPartSize = 24; // q(8) + q(8) + V(4) + x4(4)
                        if (\$offset + \$fixedPartSize > \$blobLength) { error_log("PackFormat::unpack (TEXTURE_LOAD): Not enough data for fixed part."); break; }
                        \$fixedPartData = unpack("qid1/qid2/VfilenameLength/x4padding", substr(\$eventsBlob, \$offset, \$fixedPartSize));
                        if (\$fixedPartData === false) { error_log("PackFormat::unpack (TEXTURE_LOAD): Failed to unpack fixed part."); break; }
                        \$offset += \$fixedPartSize;
                        \$filenameLength = \$fixedPartData["filenameLength"];
                        if (\$offset + \$filenameLength > \$blobLength) { error_log("PackFormat::unpack (TEXTURE_LOAD): Not enough data for variable part."); break; }
                        \$stringPartData = (\$filenameLength > 0) ? unpack("a{\$filenameLength}filename", substr(\$eventsBlob, \$offset, \$filenameLength)) : ["filename" => ""];
                        \$offset += \$filenameLength;
                        \$events[] = \$headerData + \$fixedPartData + \$stringPartData;

                    } elseif (\$eventType === Events::PLUGIN_LOAD->value) {
                        \$fixedPartSize = 4; // V(4)
                        if (\$offset + \$fixedPartSize > \$blobLength) { error_log("PackFormat::unpack (PLUGIN_LOAD): Not enough data for fixed part."); break; }
                        \$fixedPartData = unpack("VpathLength", substr(\$eventsBlob, \$offset, \$fixedPartSize));
                        if (\$fixedPartData === false) { error_log("PackFormat::unpack (PLUGIN_LOAD): Failed to unpack fixed part."); break; }
                        \$offset += \$fixedPartSize;
                        \$pathLength = \$fixedPartData["pathLength"];
                        if (\$offset + \$pathLength > \$blobLength) { error_log("PackFormat::unpack (PLUGIN_LOAD): Not enough data for variable part."); break; }
                        \$stringPartData = (\$pathLength > 0) ? unpack("a{\$pathLength}path", substr(\$eventsBlob, \$offset, \$pathLength)) : ["path" => ""];
                        \$offset += \$pathLength;
                        \$events[] = \$headerData + \$fixedPartData + \$stringPartData;

                    } elseif (\$eventType === Events::AUDIO_LOAD->value) {
                         \$fixedPartSize = 4; // V(4)
                        if (\$offset + \$fixedPartSize > \$blobLength) { error_log("PackFormat::unpack (AUDIO_LOAD): Not enough data for fixed part."); break; }
                        \$fixedPartData = unpack("VpathLength", substr(\$eventsBlob, \$offset, \$fixedPartSize));
                        if (\$fixedPartData === false) { error_log("PackFormat::unpack (AUDIO_LOAD): Failed to unpack fixed part."); break; }
                        \$offset += \$fixedPartSize;
                        \$pathLength = \$fixedPartData["pathLength"];
                        if (\$offset + \$pathLength > \$blobLength) { error_log("PackFormat::unpack (AUDIO_LOAD): Not enough data for variable part."); break; }
                        \$stringPartData = (\$pathLength > 0) ? unpack("a{\$pathLength}path", substr(\$eventsBlob, \$offset, \$pathLength)) : ["path" => ""];
                        \$offset += \$pathLength;
                        \$events[] = \$headerData + \$fixedPartData + \$stringPartData;

                    } elseif (\$eventType === Events::TEXT_ADD->value) {
                        // Manually check format: qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4/gfontSize/VfontPathLength/VtextLength/x4
                        \$fixedPartSize = 8+8+8+8+8+1+1+1+1+4+4+4+4+4; // 64 bytes
                        if (\$offset + \$fixedPartSize > \$blobLength) { error_log("PackFormat::unpack (TEXT_ADD): Not enough data for fixed part."); break; }
                        \$fixedPartData = unpack(
                            "qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4padding1/gfontSize/VfontPathLength/VtextLength/x4padding2",
                            substr(\$eventsBlob, \$offset, \$fixedPartSize)
                        );
                        if (\$fixedPartData === false) { error_log("PackFormat::unpack (TEXT_ADD): Failed to unpack fixed part."); break; }
                        \$offset += \$fixedPartSize;
                        \$fontPathLength = \$fixedPartData["fontPathLength"];
                        \$textLength = \$fixedPartData["textLength"];

                        if (\$offset + \$fontPathLength > \$blobLength) { error_log("PackFormat::unpack (TEXT_ADD): Not enough data for font path."); break; }
                        \$fontPathData = (\$fontPathLength > 0) ? unpack("a{\$fontPathLength}fontPath", substr(\$eventsBlob, \$offset, \$fontPathLength)) : ["fontPath" => ""];
                        \$offset += \$fontPathLength;

                        if (\$offset + \$textLength > \$blobLength) { error_log("PackFormat::unpack (TEXT_ADD): Not enough data for text."); break; }
                        \$textData = (\$textLength > 0) ? unpack("a{\$textLength}text", substr(\$eventsBlob, \$offset, \$textLength)) : ["text" => ""];
                        \$offset += \$textLength;
                        \$events[] = \$headerData + \$fixedPartData + \$fontPathData + \$textData;

                    } elseif (\$eventType === Events::TEXT_SET_STRING->value) {
                        \$fixedPartSize = 24; // q(8) + q(8) + V(4) + x4(4)
                        if (\$offset + \$fixedPartSize > \$blobLength) { error_log("PackFormat::unpack (TEXT_SET_STRING): Not enough data for fixed part."); break; }
                        \$fixedPartData = unpack("qid1/qid2/VtextLength/x4padding", substr(\$eventsBlob, \$offset, \$fixedPartSize));
                        if (\$fixedPartData === false) { error_log("PackFormat::unpack (TEXT_SET_STRING): Failed to unpack fixed part."); break; }
                        \$offset += \$fixedPartSize;
                        \$textLength = \$fixedPartData["textLength"];

                        if (\$offset + \$textLength > \$blobLength) { error_log("PackFormat::unpack (TEXT_SET_STRING): Not enough data for text."); break; }
                        \$textData = (\$textLength > 0) ? unpack("a{\$textLength}text", substr(\$eventsBlob, \$offset, \$textLength)) : ["text" => ""];
                        \$offset += \$textLength;
                        \$events[] = \$headerData + \$fixedPartData + \$textData;

                    } elseif (\$eventType === Events::UI_BEGIN_WINDOW->value) {
                        // Header: ggggVV (24 bytes)
                        \$fixedPartSize = 24;
                        if (\$offset + \$fixedPartSize > \$blobLength) { error_log("PackFormat::unpack (UI_BEGIN_WINDOW): Not enough data for fixed part."); break; }
                        \$fixedPartData = unpack("gx/gy/gw/gh/Vflags/VtitleLength", substr(\$eventsBlob, \$offset, \$fixedPartSize));
                        if (\$fixedPartData === false) { error_log("PackFormat::unpack (UI_BEGIN_WINDOW): Failed to unpack fixed part."); break; }
                        \$offset += \$fixedPartSize;
                        \$titleLength = \$fixedPartData["titleLength"];

                        if (\$offset + \$titleLength > \$blobLength) { error_log("PackFormat::unpack (UI_BEGIN_WINDOW): Not enough data for title."); break; }
                        \$titleData = (\$titleLength > 0) ? unpack("a{\$titleLength}title", substr(\$eventsBlob, \$offset, \$titleLength)) : ["title" => ""];
                        \$offset += \$titleLength;
                        \$events[] = \$headerData + \$fixedPartData + \$titleData;

                    } elseif (\$eventType === Events::UI_TEXT->value) {
                        // Header: Vx4 (8 bytes)
                        \$fixedPartSize = 8;
                        if (\$offset + \$fixedPartSize > \$blobLength) { error_log("PackFormat::unpack (UI_TEXT): Not enough data for fixed part."); break; }
                        \$fixedPartData = unpack("VtextLength/x4padding", substr(\$eventsBlob, \$offset, \$fixedPartSize));
                        \$offset += \$fixedPartSize;
                        \$textLength = \$fixedPartData["textLength"];

                        if (\$offset + \$textLength > \$blobLength) { error_log("PackFormat::unpack (UI_TEXT): Not enough data for text."); break; }
                        \$textData = (\$textLength > 0) ? unpack("a{\$textLength}text", substr(\$eventsBlob, \$offset, \$textLength)) : ["text" => ""];
                        \$offset += \$textLength;
                        \$events[] = \$headerData + \$fixedPartData + \$textData;

                    } elseif (\$eventType === Events::UI_BUTTON->value) {
                        // Header: VggV (16 bytes)
                        \$fixedPartSize = 16;
                        if (\$offset + \$fixedPartSize > \$blobLength) { error_log("PackFormat::unpack (UI_BUTTON): Not enough data for fixed part."); break; }
                        \$fixedPartData = unpack("Vid/gw/gh/VlabelLength", substr(\$eventsBlob, \$offset, \$fixedPartSize));
                        \$offset += \$fixedPartSize;
                        \$labelLength = \$fixedPartData["labelLength"];

                        if (\$offset + \$labelLength > \$blobLength) { error_log("PackFormat::unpack (UI_BUTTON): Not enough data for label."); break; }
                        \$labelData = (\$labelLength > 0) ? unpack("a{\$labelLength}label", substr(\$eventsBlob, \$offset, \$labelLength)) : ["label" => ""];
                        \$offset += \$labelLength;
                        \$events[] = \$headerData + \$fixedPartData + \$labelData;

                    } elseif (\$eventEnumValue !== null) {
                        // Handle other known fixed-size events
                        \$payloadInfo = self::getInfo(\$eventType);
                        if (\$payloadInfo === null) {
                            error_log("PackFormat::unpack: Could not get info for known event type {\$eventType}.");
                            break;
                        }

                        \$payloadSize = \$payloadInfo["size"];
                        \$payloadFormat = \$payloadInfo["format"];

                        if (\$offset + \$payloadSize > \$blobLength) {
                            error_log("PackFormat::unpack ({\$eventEnumValue->name}): Not enough data for payload (size {\$payloadSize}).");
                            break;
                        }

                        if (\$payloadSize > 0) {
                            \$payloadData = unpack(\$payloadFormat, substr(\$eventsBlob, \$offset, \$payloadSize));
                            if (\$payloadData === false) {
                                error_log("PackFormat::unpack ({\$eventEnumValue->name}): Failed to unpack payload.");
                                break;
                            }
                            \$payloadData = array_filter(\$payloadData, "is_string", ARRAY_FILTER_USE_KEY);
                            \$events[] = \$headerData + \$payloadData;
                        } else {
                            \$events[] = \$headerData; // Event with no payload
                        }
                        \$offset += \$payloadSize;
                    } else {
                        error_log("PackFormat::unpack: Unknown event type {\$eventType}. Cannot continue parsing.");
                        error_log(bin2hex(\$eventsBlob));
                        break;
                    }
                }
                return \$events;
            }
        PHP;
    }

    private function getCommandPackerClass(): string
    {
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
                $this->eventStream .= pack("VQ", $typeValue, 0);

                if ($type === Events::SPRITE_TEXTURE_LOAD) {
                    if (count($data) !== 4) { error_log("CommandPacker: Data count mismatch for SPRITE_TEXTURE_LOAD"); return; }
                    $this->eventStream .= pack("qqVx4", $data[0], $data[1], $data[2]);
                    $this->eventStream .= $data[3];
                } elseif ($type === Events::PLUGIN_LOAD) {
                    if (count($data) !== 2) { error_log("CommandPacker: Data count mismatch for PLUGIN_LOAD"); return; }
                    $this->eventStream .= pack("V", $data[0]);
                    $this->eventStream .= $data[1];
                } elseif ($type === Events::AUDIO_LOAD) {
                    if (count($data) !== 2) { error_log("CommandPacker: Data count mismatch for AUDIO_LOAD"); return; }
                    $this->eventStream .= pack("V", $data[0]);
                    $this->eventStream .= $data[1];
                } elseif ($type === Events::TEXT_ADD) {
                    // qqeeeCCCCx4gVVx4 + str + str
                    $packedFixed = pack("qqeeeCCCCx4gVVx4",
                        $data[0], $data[1], $data[2], $data[3], $data[4],
                        $data[5], $data[6], $data[7], $data[8],
                        $data[9], $data[10], $data[11]
                    );
                    $this->eventStream .= $packedFixed;
                    $this->eventStream .= $data[12];
                    $this->eventStream .= $data[13];
                } elseif ($type === Events::TEXT_SET_STRING) {
                    $this->eventStream .= pack("qqVx4", $data[0], $data[1], $data[2]);
                    $this->eventStream .= $data[3];
                } elseif ($type === Events::UI_BEGIN_WINDOW) {
                    // NEW: Dynamic UI Window
                    // Format: ggggVV + title
                    $this->eventStream .= pack("ggggVV", $data[0], $data[1], $data[2], $data[3], $data[4], $data[5]);
                    $this->eventStream .= $data[6];
                } elseif ($type === Events::UI_TEXT) {
                    // NEW: Dynamic UI Text
                    // Format: Vx4 + text
                    $this->eventStream .= pack("Vx4", $data[0]);
                    $this->eventStream .= $data[1];
                } elseif ($type === Events::UI_BUTTON) {
                    // NEW: Dynamic UI Button
                    // Format: VggV + label
                    $this->eventStream .= pack("VggV", $data[0], $data[1], $data[2], $data[3]);
                    $this->eventStream .= $data[4];
                } else {
                    // --- FIXED SIZE HANDLING ---
                    $payloadInfo = PackFormat::getInfo($typeValue);
                    if ($payloadInfo) {
                        $pureFormat = self::getPureFormat($payloadInfo["format"]);
                        if (!empty($pureFormat)) {
                             $this->eventStream .= pack($pureFormat, ...array_values($data));
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
                        if ($count === '*') { break; }
                        $pure .= $code . $count;
                    }
                }
                return self::$pureFormatCache[$descriptiveFormat] = $pure;
            }
        }
        PHP;
    }
}
