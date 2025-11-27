<?php

namespace Phrost;

class PackFormat
{
    /** @var array<int, array{format: string, size: int}> */
    private static array $cache = [];

    // ... (EVENT_FORMAT_MAP remains unchanged) ...
    /** @var array<int, string> */
    private const EVENT_FORMAT_MAP = [
        Events::SPRITE_ADD->value => SpritePackFormats::PACK_SPRITE_ADD,
        Events::SPRITE_REMOVE->value => SpritePackFormats::PACK_SPRITE_REMOVE,
        // ... include all your existing map entries here ...
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
        Events::PHYSICS_SET_DEBUG_MODE->value =>
            PhysicsPackFormats::PACK_PHYSICS_SET_DEBUG_MODE,
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

    // ... (getInfo implementation remains unchanged) ...
    public static function getInfo(int $eventTypeValue): ?array
    {
        if (isset(self::$cache[$eventTypeValue])) {
            return self::$cache[$eventTypeValue];
        }
        $descriptiveFormat = self::EVENT_FORMAT_MAP[$eventTypeValue] ?? null;
        if ($descriptiveFormat === null) {
            return null;
        }

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
            if (preg_match("/^([a-zA-Z])(\*|\d*)/", $part, $matches)) {
                $code = $matches[1];
                $repeater = $matches[2];
                if ($repeater === "*") {
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
                        break;
                    }
                }
                $count =
                    $repeater === "" || !ctype_digit($repeater)
                        ? 1
                        : (int) $repeater;
                $size = $sizeMap[$code] ?? 0;
                $totalSize += $count * $size;
            }
        }
        $result = ["format" => $descriptiveFormat, "size" => (int) $totalSize];
        self::$cache[$eventTypeValue] = $result;
        return $result;
    }

    /**
     * Unpacks a binary blob (DEBUG ONLY).
     * Supports the new aligned format (skip padding).
     */
    public static function unpack(string $eventsBlob): array
    {
        $events = [];
        $blobLength = strlen($eventsBlob);
        if ($blobLength < 8) {
            return [];
        } // Need at least count(4) + padding(4)

        // UNPACK COUNT + SKIP PADDING
        $countUnpack = unpack("Vcount", $eventsBlob);
        if ($countUnpack === false) {
            return [];
        }

        $eventCount = $countUnpack["count"];
        $offset = 8; // 4 bytes count + 4 bytes padding

        for ($i = 0; $i < $eventCount; $i++) {
            // ALIGNMENT FIX: Header is now 16 bytes (4+8+4)
            $headerSize = 16;
            if ($offset + $headerSize > $blobLength) {
                break;
            }

            $headerData = unpack(
                "Vtype/Qtimestamp",
                substr($eventsBlob, $offset, $headerSize),
            );
            $offset += $headerSize;

            $eventType = $headerData["type"];
            $eventEnumValue = Events::tryFrom($eventType);

            // --- Variable Event Handling ---
            if ($eventType === Events::SPRITE_TEXTURE_LOAD->value) {
                $fixedPartSize = 24;
                if ($offset + $fixedPartSize > $blobLength) {
                    break;
                }
                $fixedPartData = unpack(
                    "qid1/qid2/VfilenameLength/x4padding",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                $offset += $fixedPartSize;

                $filenameLength = $fixedPartData["filenameLength"];
                // Calculate Padding
                $strPadding = (8 - ($filenameLength % 8)) % 8;

                if ($offset + $filenameLength + $strPadding > $blobLength) {
                    break;
                }

                $stringPartData =
                    $filenameLength > 0
                        ? unpack(
                            "a{$filenameLength}filename",
                            substr($eventsBlob, $offset, $filenameLength),
                        )
                        : ["filename" => ""];

                $offset += $filenameLength + $strPadding;
                $events[] = $headerData + $fixedPartData + $stringPartData;
            } elseif (
                $eventType === Events::PLUGIN_LOAD->value ||
                $eventType === Events::AUDIO_LOAD->value
            ) {
                // Fixed: V (4) + x4 (4) = 8 bytes
                $fixedPartSize = 8;
                if ($offset + $fixedPartSize > $blobLength) {
                    break;
                }
                $fixedPartData = unpack(
                    "VpathLength",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                $offset += $fixedPartSize;

                $pathLength = $fixedPartData["pathLength"];
                $strPadding = (8 - ($pathLength % 8)) % 8;

                if ($offset + $pathLength + $strPadding > $blobLength) {
                    break;
                }

                $stringPartData =
                    $pathLength > 0
                        ? unpack(
                            "a{$pathLength}path",
                            substr($eventsBlob, $offset, $pathLength),
                        )
                        : ["path" => ""];

                $offset += $pathLength + $strPadding;
                $events[] = $headerData + $fixedPartData + $stringPartData;
            } elseif ($eventType === Events::TEXT_ADD->value) {
                $fixedPartSize = 64;
                if ($offset + $fixedPartSize > $blobLength) {
                    break;
                }
                $fixedPartData = unpack(
                    "qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4padding1/gfontSize/VfontPathLength/VtextLength/x4padding2",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                $offset += $fixedPartSize;

                $fontPathLength = $fixedPartData["fontPathLength"];
                $textLength = $fixedPartData["textLength"];

                $fpPadding = (8 - ($fontPathLength % 8)) % 8;
                if ($offset + $fontPathLength + $fpPadding > $blobLength) {
                    break;
                }
                $fontPathData =
                    $fontPathLength > 0
                        ? unpack(
                            "a{$fontPathLength}fontPath",
                            substr($eventsBlob, $offset, $fontPathLength),
                        )
                        : ["fontPath" => ""];
                $offset += $fontPathLength + $fpPadding;

                $txtPadding = (8 - ($textLength % 8)) % 8;
                if ($offset + $textLength + $txtPadding > $blobLength) {
                    break;
                }
                $textData =
                    $textLength > 0
                        ? unpack(
                            "a{$textLength}text",
                            substr($eventsBlob, $offset, $textLength),
                        )
                        : ["text" => ""];
                $offset += $textLength + $txtPadding;

                $events[] =
                    $headerData + $fixedPartData + $fontPathData + $textData;
            } elseif ($eventType === Events::TEXT_SET_STRING->value) {
                $fixedPartSize = 24;
                if ($offset + $fixedPartSize > $blobLength) {
                    break;
                }
                $fixedPartData = unpack(
                    "qid1/qid2/VtextLength/x4padding",
                    substr($eventsBlob, $offset, $fixedPartSize),
                );
                $offset += $fixedPartSize;

                $textLength = $fixedPartData["textLength"];
                $strPadding = (8 - ($textLength % 8)) % 8;
                if ($offset + $textLength + $strPadding > $blobLength) {
                    break;
                }
                $textData =
                    $textLength > 0
                        ? unpack(
                            "a{$textLength}text",
                            substr($eventsBlob, $offset, $textLength),
                        )
                        : ["text" => ""];
                $offset += $textLength + $strPadding;

                $events[] = $headerData + $fixedPartData + $textData;
            } elseif ($eventEnumValue !== null) {
                // --- Fixed Size Handling ---
                $payloadInfo = self::getInfo($eventType);
                $payloadSize = $payloadInfo["size"];

                if ($offset + $payloadSize > $blobLength) {
                    break;
                }

                if ($payloadSize > 0) {
                    $payloadData = unpack(
                        $payloadInfo["format"],
                        substr($eventsBlob, $offset, $payloadSize),
                    );
                    $payloadData = array_filter(
                        $payloadData,
                        "is_string",
                        ARRAY_FILTER_USE_KEY,
                    );
                    $events[] = $headerData + $payloadData;
                } else {
                    $events[] = $headerData;
                }
                $offset += $payloadSize;
            }

            // ALIGNMENT FIX: Skip trailing padding for the whole event
            $padding = (8 - ($offset % 8)) % 8;
            $offset += $padding;
        }
        return $events;
    }
}
