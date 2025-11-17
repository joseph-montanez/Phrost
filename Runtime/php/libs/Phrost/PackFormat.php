<?php

namespace Phrost;

class PackFormat
{
    /** @var array<int, array{format: string, size: int}> */
    private static array $cache = [];

    /** @var array<int, string> */
    private const EVENT_FORMAT_MAP = [
        Events::SPRITE_ADD->value => SpritePackFormats::PACK_SPRITE_ADD,
        Events::SPRITE_REMOVE->value => SpritePackFormats::PACK_SPRITE_REMOVE,
        Events::SPRITE_MOVE->value => SpritePackFormats::PACK_SPRITE_MOVE,
        Events::SPRITE_SCALE->value => SpritePackFormats::PACK_SPRITE_SCALE,
        Events::SPRITE_RESIZE->value => SpritePackFormats::PACK_SPRITE_RESIZE,
        Events::SPRITE_ROTATE->value => SpritePackFormats::PACK_SPRITE_ROTATE,
        Events::SPRITE_COLOR->value => SpritePackFormats::PACK_SPRITE_COLOR,
        Events::SPRITE_SPEED->value => SpritePackFormats::PACK_SPRITE_SPEED,
        Events::SPRITE_TEXTURE_LOAD->value =>
            SpritePackFormats::PACK_SPRITE_TEXTURE_LOAD,
        Events::SPRITE_TEXTURE_SET->value =>
            SpritePackFormats::PACK_SPRITE_TEXTURE_SET,
        Events::SPRITE_SET_SOURCE_RECT->value =>
            SpritePackFormats::PACK_SPRITE_SET_SOURCE_RECT,
        Events::GEOM_ADD_POINT->value => SpritePackFormats::PACK_GEOM_ADD_POINT,
        Events::GEOM_ADD_LINE->value => SpritePackFormats::PACK_GEOM_ADD_LINE,
        Events::GEOM_ADD_RECT->value => SpritePackFormats::PACK_GEOM_ADD_RECT,
        Events::GEOM_ADD_FILL_RECT->value =>
            SpritePackFormats::PACK_GEOM_ADD_FILL_RECT,
        Events::GEOM_ADD_PACKED->value =>
            SpritePackFormats::PACK_GEOM_ADD_PACKED,
        Events::GEOM_REMOVE->value => SpritePackFormats::PACK_GEOM_REMOVE,
        Events::GEOM_SET_COLOR->value => SpritePackFormats::PACK_GEOM_SET_COLOR,
        Events::INPUT_KEYUP->value => InputPackFormats::PACK_INPUT_KEYUP,
        Events::INPUT_KEYDOWN->value => InputPackFormats::PACK_INPUT_KEYDOWN,
        Events::INPUT_MOUSEUP->value => InputPackFormats::PACK_INPUT_MOUSEUP,
        Events::INPUT_MOUSEDOWN->value =>
            InputPackFormats::PACK_INPUT_MOUSEDOWN,
        Events::INPUT_MOUSEMOTION->value =>
            InputPackFormats::PACK_INPUT_MOUSEMOTION,
        Events::WINDOW_TITLE->value => WindowPackFormats::PACK_WINDOW_TITLE,
        Events::WINDOW_RESIZE->value => WindowPackFormats::PACK_WINDOW_RESIZE,
        Events::WINDOW_FLAGS->value => WindowPackFormats::PACK_WINDOW_FLAGS,
        Events::TEXT_ADD->value => TextPackFormats::PACK_TEXT_ADD,
        Events::TEXT_SET_STRING->value => TextPackFormats::PACK_TEXT_SET_STRING,
        Events::AUDIO_LOAD->value => AudioPackFormats::PACK_AUDIO_LOAD,
        Events::AUDIO_LOADED->value => AudioPackFormats::PACK_AUDIO_LOADED,
        Events::AUDIO_PLAY->value => AudioPackFormats::PACK_AUDIO_PLAY,
        Events::AUDIO_STOP_ALL->value => AudioPackFormats::PACK_AUDIO_STOP_ALL,
        Events::AUDIO_SET_MASTER_VOLUME->value =>
            AudioPackFormats::PACK_AUDIO_SET_MASTER_VOLUME,
        Events::AUDIO_PAUSE->value => AudioPackFormats::PACK_AUDIO_PAUSE,
        Events::AUDIO_STOP->value => AudioPackFormats::PACK_AUDIO_STOP,
        Events::AUDIO_UNLOAD->value => AudioPackFormats::PACK_AUDIO_UNLOAD,
        Events::AUDIO_SET_VOLUME->value =>
            AudioPackFormats::PACK_AUDIO_SET_VOLUME,
        Events::PHYSICS_ADD_BODY->value =>
            PhysicsPackFormats::PACK_PHYSICS_ADD_BODY,
        Events::PHYSICS_REMOVE_BODY->value =>
            PhysicsPackFormats::PACK_PHYSICS_REMOVE_BODY,
        Events::PHYSICS_APPLY_FORCE->value =>
            PhysicsPackFormats::PACK_PHYSICS_APPLY_FORCE,
        Events::PHYSICS_APPLY_IMPULSE->value =>
            PhysicsPackFormats::PACK_PHYSICS_APPLY_IMPULSE,
        Events::PHYSICS_SET_VELOCITY->value =>
            PhysicsPackFormats::PACK_PHYSICS_SET_VELOCITY,
        Events::PHYSICS_SET_POSITION->value =>
            PhysicsPackFormats::PACK_PHYSICS_SET_POSITION,
        Events::PHYSICS_SET_ROTATION->value =>
            PhysicsPackFormats::PACK_PHYSICS_SET_ROTATION,
        Events::PHYSICS_COLLISION_BEGIN->value =>
            PhysicsPackFormats::UNPACK_PHYSICS_COLLISION,
        Events::PHYSICS_COLLISION_SEPARATE->value =>
            PhysicsPackFormats::UNPACK_PHYSICS_COLLISION,
        Events::PHYSICS_SYNC_TRANSFORM->value =>
            PhysicsPackFormats::UNPACK_PHYSICS_SYNC_TRANSFORM,
        Events::PLUGIN->value => PluginPackFormats::PACK_PLUGIN,
        Events::PLUGIN_LOAD->value => PluginPackFormats::PACK_PLUGIN_LOAD,
        Events::PLUGIN_UNLOAD->value => PluginPackFormats::PACK_PLUGIN_UNLOAD,
        Events::PLUGIN_SET->value => PluginPackFormats::PACK_PLUGIN_SET,
        Events::PLUGIN_EVENT_STACKING->value =>
            PluginPackFormats::PACK_PLUGIN_EVENT_STACKING,
        Events::PLUGIN_SUBSCRIBE_EVENT->value =>
            PluginPackFormats::PACK_PLUGIN_SUBSCRIBE_EVENT,
        Events::PLUGIN_UNSUBSCRIBE_EVENT->value =>
            PluginPackFormats::PACK_PLUGIN_UNSUBSCRIBE_EVENT,
        Events::CAMERA_SET_POSITION->value =>
            CameraPackFormats::PACK_CAMERA_SET_POSITION,
        Events::CAMERA_MOVE->value => CameraPackFormats::PACK_CAMERA_MOVE,
        Events::CAMERA_SET_ZOOM->value =>
            CameraPackFormats::PACK_CAMERA_SET_ZOOM,
        Events::CAMERA_SET_ROTATION->value =>
            CameraPackFormats::PACK_CAMERA_SET_ROTATION,
        Events::CAMERA_FOLLOW_ENTITY->value =>
            CameraPackFormats::PACK_CAMERA_FOLLOW_ENTITY,
        Events::CAMERA_STOP_FOLLOWING->value =>
            CameraPackFormats::PACK_CAMERA_STOP_FOLLOWING,
        Events::SCRIPT_SUBSCRIBE->value =>
            ScriptPackFormats::PACK_SCRIPT_SUBSCRIBE,
        Events::SCRIPT_UNSUBSCRIBE->value =>
            ScriptPackFormats::PACK_SCRIPT_UNSUBSCRIBE,
    ];

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
            "a" => 1,
            "A" => 1,
            "Z" => 1,
            "h" => 0.5,
            "H" => 0.5,
            "c" => 1,
            "C" => 1,
            "s" => 2,
            "S" => 2,
            "n" => 2,
            "v" => 2,
            "l" => 4,
            "L" => 4,
            "N" => 4,
            "V" => 4,
            "i" => 4,
            "I" => 4,
            "f" => 4,
            "g" => 4,
            "G" => 4,
            "q" => 8,
            "Q" => 8,
            "J" => 8,
            "P" => 8,
            "d" => 8,
            "e" => 8,
            "E" => 8,
            "x" => 1,
            "X" => -1,
            "@" => 0,
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
                        Events::GEOM_ADD_PACKED->value,
                    ];

                    if (in_array($eventTypeValue, $dynamicEvents)) {
                        break;
                    } else {
                        error_log(
                            "PackFormat::getInfo: Unexpected '*' in format '{$descriptiveFormat}' for event {$eventTypeValue}. Size calculation might be wrong.",
                        );
                        break; // Stop calculation
                    }
                }

                $count =
                    $repeater === "" || !ctype_digit($repeater)
                        ? 1
                        : (int) $repeater;
                $size = $sizeMap[$code] ?? 0;
                if ($size === 0 && $code !== "@") {
                    error_log(
                        "PackFormat::getInfo: Unknown format code '{$code}' in format '{$descriptiveFormat}' for event {$eventTypeValue}.",
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
                        "PackFormat::getInfo: Could not parse format part '{$part}' in format '{$descriptiveFormat}' for event {$eventTypeValue}.",
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
                error_log(
                    "PackFormat::unpack Loop {$i}/{$eventCount}: Not enough data for header. Offset={$offset}",
                );
                break;
            }

            $headerData = unpack(
                "Vtype/Qtimestamp",
                substr($eventsBlob, $offset, $headerSize),
            );
            if ($headerData === false) {
                error_log(
                    "PackFormat::unpack Loop {$i}/{$eventCount}: Failed to unpack header. Offset={$offset}",
                );
                break;
            }
            $offset += $headerSize;
            $eventType = $headerData["type"];
            $eventEnumValue = Events::tryFrom($eventType);

            if ($eventType === Events::SPRITE_TEXTURE_LOAD->value) {
                $fixedPartSize = 24; // q(8) + q(8) + V(4) + x4(4)
                if ($offset + $fixedPartSize > $blobLength) {
                    error_log(
                        "PackFormat::unpack (TEXTURE_LOAD): Not enough data for fixed part.",
                    );
                    break;
                }
                $fixedPartData = unpack(
                    "qid1/qid2/VfilenameLength/x4padding",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                if ($fixedPartData === false) {
                    error_log(
                        "PackFormat::unpack (TEXTURE_LOAD): Failed to unpack fixed part.",
                    );
                    break;
                }
                $offset += $fixedPartSize;
                $filenameLength = $fixedPartData["filenameLength"];
                if ($offset + $filenameLength > $blobLength) {
                    error_log(
                        "PackFormat::unpack (TEXTURE_LOAD): Not enough data for variable part.",
                    );
                    break;
                }
                $stringPartData =
                    $filenameLength > 0
                        ? unpack(
                            "a{$filenameLength}filename",
                            substr($eventsBlob, $offset, $filenameLength),
                        )
                        : ["filename" => ""];
                $offset += $filenameLength;
                $events[] = $headerData + $fixedPartData + $stringPartData;
            } elseif ($eventType === Events::PLUGIN_LOAD->value) {
                $fixedPartSize = 4; // V(4)
                if ($offset + $fixedPartSize > $blobLength) {
                    error_log(
                        "PackFormat::unpack (PLUGIN_LOAD): Not enough data for fixed part.",
                    );
                    break;
                }
                $fixedPartData = unpack(
                    "VpathLength",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                if ($fixedPartData === false) {
                    error_log(
                        "PackFormat::unpack (PLUGIN_LOAD): Failed to unpack fixed part.",
                    );
                    break;
                }
                $offset += $fixedPartSize;
                $pathLength = $fixedPartData["pathLength"];
                if ($offset + $pathLength > $blobLength) {
                    error_log(
                        "PackFormat::unpack (PLUGIN_LOAD): Not enough data for variable part.",
                    );
                    break;
                }
                $stringPartData =
                    $pathLength > 0
                        ? unpack(
                            "a{$pathLength}path",
                            substr($eventsBlob, $offset, $pathLength),
                        )
                        : ["path" => ""];
                $offset += $pathLength;
                $events[] = $headerData + $fixedPartData + $stringPartData;
            } elseif ($eventType === Events::AUDIO_LOAD->value) {
                $fixedPartSize = 4; // V(4)
                if ($offset + $fixedPartSize > $blobLength) {
                    error_log(
                        "PackFormat::unpack (AUDIO_LOAD): Not enough data for fixed part.",
                    );
                    break;
                }
                $fixedPartData = unpack(
                    "VpathLength",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                if ($fixedPartData === false) {
                    error_log(
                        "PackFormat::unpack (AUDIO_LOAD): Failed to unpack fixed part.",
                    );
                    break;
                }
                $offset += $fixedPartSize;
                $pathLength = $fixedPartData["pathLength"];
                if ($offset + $pathLength > $blobLength) {
                    error_log(
                        "PackFormat::unpack (AUDIO_LOAD): Not enough data for variable part.",
                    );
                    break;
                }
                $stringPartData =
                    $pathLength > 0
                        ? unpack(
                            "a{$pathLength}path",
                            substr($eventsBlob, $offset, $pathLength),
                        )
                        : ["path" => ""];
                $offset += $pathLength;
                $events[] = $headerData + $fixedPartData + $stringPartData;
            } elseif ($eventType === Events::TEXT_ADD->value) {
                // Manually check format: qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4/gfontSize/VfontPathLength/VtextLength/x4
                $fixedPartSize =
                    8 + 8 + 8 + 8 + 8 + 1 + 1 + 1 + 1 + 4 + 4 + 4 + 4 + 4; // 64 bytes
                if ($offset + $fixedPartSize > $blobLength) {
                    error_log(
                        "PackFormat::unpack (TEXT_ADD): Not enough data for fixed part.",
                    );
                    break;
                }
                $fixedPartData = unpack(
                    "qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4padding1/gfontSize/VfontPathLength/VtextLength/x4padding2",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                if ($fixedPartData === false) {
                    error_log(
                        "PackFormat::unpack (TEXT_ADD): Failed to unpack fixed part.",
                    );
                    break;
                }
                $offset += $fixedPartSize;
                $fontPathLength = $fixedPartData["fontPathLength"];
                $textLength = $fixedPartData["textLength"];

                if ($offset + $fontPathLength > $blobLength) {
                    error_log(
                        "PackFormat::unpack (TEXT_ADD): Not enough data for font path.",
                    );
                    break;
                }
                $fontPathData =
                    $fontPathLength > 0
                        ? unpack(
                            "a{$fontPathLength}fontPath",
                            substr($eventsBlob, $offset, $fontPathLength),
                        )
                        : ["fontPath" => ""];
                $offset += $fontPathLength;

                if ($offset + $textLength > $blobLength) {
                    error_log(
                        "PackFormat::unpack (TEXT_ADD): Not enough data for text.",
                    );
                    break;
                }
                $textData =
                    $textLength > 0
                        ? unpack(
                            "a{$textLength}text",
                            substr($eventsBlob, $offset, $textLength),
                        )
                        : ["text" => ""];
                $offset += $textLength;
                $events[] =
                    $headerData + $fixedPartData + $fontPathData + $textData;
            } elseif ($eventType === Events::TEXT_SET_STRING->value) {
                $fixedPartSize = 24; // q(8) + q(8) + V(4) + x4(4)
                if ($offset + $fixedPartSize > $blobLength) {
                    error_log(
                        "PackFormat::unpack (TEXT_SET_STRING): Not enough data for fixed part.",
                    );
                    break;
                }
                $fixedPartData = unpack(
                    "qid1/qid2/VtextLength/x4padding",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                if ($fixedPartData === false) {
                    error_log(
                        "PackFormat::unpack (TEXT_SET_STRING): Failed to unpack fixed part.",
                    );
                    break;
                }
                $offset += $fixedPartSize;
                $textLength = $fixedPartData["textLength"];

                if ($offset + $textLength > $blobLength) {
                    error_log(
                        "PackFormat::unpack (TEXT_SET_STRING): Not enough data for text.",
                    );
                    break;
                }
                $textData =
                    $textLength > 0
                        ? unpack(
                            "a{$textLength}text",
                            substr($eventsBlob, $offset, $textLength),
                        )
                        : ["text" => ""];
                $offset += $textLength;
                $events[] = $headerData + $fixedPartData + $textData;
            } elseif ($eventEnumValue !== null) {
                // Handle other known fixed-size events
                $payloadInfo = self::getInfo($eventType);
                if ($payloadInfo === null) {
                    error_log(
                        "PackFormat::unpack: Could not get info for known event type {$eventType}.",
                    );
                    break;
                }

                $payloadSize = $payloadInfo["size"];
                $payloadFormat = $payloadInfo["format"];

                if ($offset + $payloadSize > $blobLength) {
                    error_log(
                        "PackFormat::unpack ({$eventEnumValue->name}): Not enough data for payload (size {$payloadSize}).",
                    );
                    break;
                }

                if ($payloadSize > 0) {
                    $payloadData = unpack(
                        $payloadFormat,
                        substr($eventsBlob, $offset, $payloadSize),
                    );
                    if ($payloadData === false) {
                        error_log(
                            "PackFormat::unpack ({$eventEnumValue->name}): Failed to unpack payload.",
                        );
                        break;
                    }
                    $payloadData = array_filter(
                        $payloadData,
                        "is_string",
                        ARRAY_FILTER_USE_KEY,
                    );
                    $events[] = $headerData + $payloadData;
                } else {
                    $events[] = $headerData; // Event with no payload
                }
                $offset += $payloadSize;
            } else {
                error_log(
                    "PackFormat::unpack: Unknown event type {$eventType}. Cannot continue parsing.",
                );
                error_log(bin2hex($eventsBlob));
                break;
            }
        }
        return $events;
    }
}
