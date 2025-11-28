import struct
import sys
from typing import Any, Dict, List, Optional, Tuple

from Events import Events
from PackFormats import (
    AudioPackFormats,
    CameraPackFormats,
    InputPackFormats,
    PhysicsPackFormats,
    PluginPackFormats,
    ScriptPackFormats,
    SpritePackFormats,
    TextPackFormats,
    WindowPackFormats,
)


# --- PackFormat Class ---
class PackFormat:
    # This map holds the pre-computed (format, size) tuples
    _EVENT_FORMAT_MAP: Dict[int, Tuple[str, int]] = {
        Events.SPRITE_ADD.value: SpritePackFormats.PACK_SPRITE_ADD,
        Events.SPRITE_REMOVE.value: SpritePackFormats.PACK_SPRITE_REMOVE,
        Events.SPRITE_MOVE.value: SpritePackFormats.PACK_SPRITE_MOVE,
        Events.SPRITE_SCALE.value: SpritePackFormats.PACK_SPRITE_SCALE,
        Events.SPRITE_RESIZE.value: SpritePackFormats.PACK_SPRITE_RESIZE,
        Events.SPRITE_ROTATE.value: SpritePackFormats.PACK_SPRITE_ROTATE,
        Events.SPRITE_COLOR.value: SpritePackFormats.PACK_SPRITE_COLOR,
        Events.SPRITE_SPEED.value: SpritePackFormats.PACK_SPRITE_SPEED,
        Events.SPRITE_TEXTURE_LOAD.value: SpritePackFormats.PACK_SPRITE_TEXTURE_LOAD,
        Events.SPRITE_TEXTURE_SET.value: SpritePackFormats.PACK_SPRITE_TEXTURE_SET,
        Events.SPRITE_SET_SOURCE_RECT.value: SpritePackFormats.PACK_SPRITE_SET_SOURCE_RECT,
        Events.GEOM_ADD_POINT.value: SpritePackFormats.PACK_GEOM_ADD_POINT,
        Events.GEOM_ADD_LINE.value: SpritePackFormats.PACK_GEOM_ADD_LINE,
        Events.GEOM_ADD_RECT.value: SpritePackFormats.PACK_GEOM_ADD_RECT,
        Events.GEOM_ADD_FILL_RECT.value: SpritePackFormats.PACK_GEOM_ADD_FILL_RECT,
        Events.GEOM_ADD_PACKED.value: SpritePackFormats.PACK_GEOM_ADD_PACKED,
        Events.GEOM_REMOVE.value: SpritePackFormats.PACK_GEOM_REMOVE,
        Events.GEOM_SET_COLOR.value: SpritePackFormats.PACK_GEOM_SET_COLOR,
        Events.INPUT_KEYUP.value: InputPackFormats.PACK_INPUT_KEYUP,
        Events.INPUT_KEYDOWN.value: InputPackFormats.PACK_INPUT_KEYDOWN,
        Events.INPUT_MOUSEUP.value: InputPackFormats.PACK_INPUT_MOUSEUP,
        Events.INPUT_MOUSEDOWN.value: InputPackFormats.PACK_INPUT_MOUSEDOWN,
        Events.INPUT_MOUSEMOTION.value: InputPackFormats.PACK_INPUT_MOUSEMOTION,
        Events.WINDOW_TITLE.value: WindowPackFormats.PACK_WINDOW_TITLE,
        Events.WINDOW_RESIZE.value: WindowPackFormats.PACK_WINDOW_RESIZE,
        Events.WINDOW_FLAGS.value: WindowPackFormats.PACK_WINDOW_FLAGS,
        Events.TEXT_ADD.value: TextPackFormats.PACK_TEXT_ADD,
        Events.TEXT_SET_STRING.value: TextPackFormats.PACK_TEXT_SET_STRING,
        Events.AUDIO_LOAD.value: AudioPackFormats.PACK_AUDIO_LOAD,
        Events.AUDIO_LOADED.value: AudioPackFormats.PACK_AUDIO_LOADED,
        Events.AUDIO_PLAY.value: AudioPackFormats.PACK_AUDIO_PLAY,
        Events.AUDIO_STOP_ALL.value: AudioPackFormats.PACK_AUDIO_STOP_ALL,
        Events.AUDIO_SET_MASTER_VOLUME.value: AudioPackFormats.PACK_AUDIO_SET_MASTER_VOLUME,
        Events.AUDIO_PAUSE.value: AudioPackFormats.PACK_AUDIO_PAUSE,
        Events.AUDIO_STOP.value: AudioPackFormats.PACK_AUDIO_STOP,
        Events.AUDIO_UNLOAD.value: AudioPackFormats.PACK_AUDIO_UNLOAD,
        Events.AUDIO_SET_VOLUME.value: AudioPackFormats.PACK_AUDIO_SET_VOLUME,
        Events.PHYSICS_ADD_BODY.value: PhysicsPackFormats.PACK_PHYSICS_ADD_BODY,
        Events.PHYSICS_REMOVE_BODY.value: PhysicsPackFormats.PACK_PHYSICS_REMOVE_BODY,
        Events.PHYSICS_APPLY_FORCE.value: PhysicsPackFormats.PACK_PHYSICS_APPLY_FORCE,
        Events.PHYSICS_APPLY_IMPULSE.value: PhysicsPackFormats.PACK_PHYSICS_APPLY_IMPULSE,
        Events.PHYSICS_SET_VELOCITY.value: PhysicsPackFormats.PACK_PHYSICS_SET_VELOCITY,
        Events.PHYSICS_SET_POSITION.value: PhysicsPackFormats.PACK_PHYSICS_SET_POSITION,
        Events.PHYSICS_SET_ROTATION.value: PhysicsPackFormats.PACK_PHYSICS_SET_ROTATION,
        Events.PHYSICS_COLLISION_BEGIN.value: PhysicsPackFormats.UNPACK_PHYSICS_COLLISION,
        Events.PHYSICS_COLLISION_SEPARATE.value: PhysicsPackFormats.UNPACK_PHYSICS_COLLISION,
        Events.PHYSICS_SYNC_TRANSFORM.value: PhysicsPackFormats.UNPACK_PHYSICS_SYNC_TRANSFORM,
        Events.PHYSICS_SET_DEBUG_MODE.value: PhysicsPackFormats.PACK_PHYSICS_SET_DEBUG_MODE,
        Events.PLUGIN.value: PluginPackFormats.PACK_PLUGIN,
        Events.PLUGIN_LOAD.value: PluginPackFormats.PACK_PLUGIN_LOAD,
        Events.PLUGIN_UNLOAD.value: PluginPackFormats.PACK_PLUGIN_UNLOAD,
        Events.PLUGIN_SET.value: PluginPackFormats.PACK_PLUGIN_SET,
        Events.PLUGIN_EVENT_STACKING.value: PluginPackFormats.PACK_PLUGIN_EVENT_STACKING,
        Events.PLUGIN_SUBSCRIBE_EVENT.value: PluginPackFormats.PACK_PLUGIN_SUBSCRIBE_EVENT,
        Events.PLUGIN_UNSUBSCRIBE_EVENT.value: PluginPackFormats.PACK_PLUGIN_UNSUBSCRIBE_EVENT,
        Events.CAMERA_SET_POSITION.value: CameraPackFormats.PACK_CAMERA_SET_POSITION,
        Events.CAMERA_MOVE.value: CameraPackFormats.PACK_CAMERA_MOVE,
        Events.CAMERA_SET_ZOOM.value: CameraPackFormats.PACK_CAMERA_SET_ZOOM,
        Events.CAMERA_SET_ROTATION.value: CameraPackFormats.PACK_CAMERA_SET_ROTATION,
        Events.CAMERA_FOLLOW_ENTITY.value: CameraPackFormats.PACK_CAMERA_FOLLOW_ENTITY,
        Events.CAMERA_STOP_FOLLOWING.value: CameraPackFormats.PACK_CAMERA_STOP_FOLLOWING,
        Events.SCRIPT_SUBSCRIBE.value: ScriptPackFormats.PACK_SCRIPT_SUBSCRIBE,
        Events.SCRIPT_UNSUBSCRIBE.value: ScriptPackFormats.PACK_SCRIPT_UNSUBSCRIBE,
    }

    # This map holds the pre-computed keys for each event
    _EVENT_KEY_MAP: Dict[int, List[str]] = {
        0: [
            "id1",
            "id2",
            "positionX",
            "positionY",
            "positionZ",
            "scaleX",
            "scaleY",
            "scaleZ",
            "sizeW",
            "sizeH",
            "rotationX",
            "rotationY",
            "rotationZ",
            "r",
            "g",
            "b",
            "a",
            "speedX",
            "speedY",
        ],
        1: ["id1", "id2"],
        2: ["id1", "id2", "positionX", "positionY", "positionZ"],
        3: ["id1", "id2", "scaleX", "scaleY", "scaleZ"],
        4: ["id1", "id2", "sizeW", "sizeH"],
        5: ["id1", "id2", "rotationX", "rotationY", "rotationZ"],
        6: ["id1", "id2", "r", "g", "b", "a"],
        7: ["id1", "id2", "speedX", "speedY"],
        8: ["id1", "id2", "filenameLength"],
        9: ["id1", "id2", "textureId"],
        10: ["id1", "id2", "x", "y", "w", "h"],
        50: ["id1", "id2", "z", "r", "g", "b", "a", "isScreenSpace", "x", "y"],
        51: [
            "id1",
            "id2",
            "z",
            "r",
            "g",
            "b",
            "a",
            "isScreenSpace",
            "x1",
            "y1",
            "x2",
            "y2",
        ],
        52: [
            "id1",
            "id2",
            "z",
            "r",
            "g",
            "b",
            "a",
            "isScreenSpace",
            "x",
            "y",
            "w",
            "h",
        ],
        53: [
            "id1",
            "id2",
            "z",
            "r",
            "g",
            "b",
            "a",
            "isScreenSpace",
            "x",
            "y",
            "w",
            "h",
        ],
        54: [
            "id1",
            "id2",
            "z",
            "r",
            "g",
            "b",
            "a",
            "isScreenSpace",
            "primitiveType",
            "count",
        ],
        55: ["id1", "id2"],
        56: ["id1", "id2", "r", "g", "b", "a"],
        100: ["scancode", "keycode", "mod", "isRepeat"],
        101: ["scancode", "keycode", "mod", "isRepeat"],
        102: ["x", "y", "button", "clicks"],
        103: ["x", "y", "button", "clicks"],
        104: ["x", "y", "xrel", "yrel"],
        200: ["title"],
        201: ["w", "h"],
        202: ["flags"],
        300: [
            "id1",
            "id2",
            "positionX",
            "positionY",
            "positionZ",
            "r",
            "g",
            "b",
            "a",
            "fontSize",
            "fontPathLength",
            "textLength",
        ],
        301: ["id1", "id2", "textLength"],
        400: ["pathLength"],
        401: ["audioId"],
        402: ["audioId"],
        403: [],
        404: ["volume"],
        405: ["audioId"],
        406: ["audioId"],
        407: ["audioId"],
        408: ["audioId", "volume"],
        500: [
            "id1",
            "id2",
            "positionX",
            "positionY",
            "bodyType",
            "shapeType",
            "lockRotation",
            "mass",
            "friction",
            "elasticity",
            "width",
            "height",
        ],
        501: ["id1", "id2"],
        502: ["id1", "id2", "forceX", "forceY"],
        503: ["id1", "id2", "impulseX", "impulseY"],
        504: ["id1", "id2", "velocityX", "velocityY"],
        505: ["id1", "id2", "positionX", "positionY"],
        506: ["id1", "id2", "angleInRadians"],
        550: ["id1_A", "id2_A", "id1_B", "id2_B"],
        551: ["id1_A", "id2_A", "id1_B", "id2_B"],
        552: [
            "id1",
            "id2",
            "positionX",
            "positionY",
            "angle",
            "velocityX",
            "velocityY",
            "angularVelocity",
            "isSleeping",
        ],
        1000: ["eventId"],
        1001: ["channelNo", "pathLength"],
        1002: ["pluginId"],
        1003: ["pluginId"],
        1004: ["eventId"],
        1005: ["pluginId", "channelNo"],
        1006: ["pluginId", "channelNo"],
        2000: ["positionX", "positionY"],
        2001: ["deltaX", "deltaY"],
        2002: ["zoom"],
        2003: ["angleInRadians"],
        2004: ["id1", "id2"],
        2005: [],
        3000: ["channelNo"],
        3001: ["channelNo"],
    }

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
                print(
                    f"PackFormat.unpack Loop {i}/{event_count}: Not enough data for header. Offset={offset}",
                    file=sys.stderr,
                )
                break

            try:
                header_data = struct.unpack_from("<IQ", events_blob, offset)
                offset += header_size
                event_type, timestamp = header_data
                event = {"type": event_type, "timestamp": timestamp}
            except struct.error:
                print(
                    f"PackFormat.unpack Loop {i}/{event_count}: Failed to unpack header. Offset={offset}",
                    file=sys.stderr,
                )
                break

            try:
                event_enum_val = Events(event_type)
            except ValueError:
                event_enum_val = None

            # --- Manual Unpacking for Variable-Length Events ---
            try:
                if event_type == Events.SPRITE_TEXTURE_LOAD.value:
                    fmt, size = PackFormat.get_info(event_type)  # ("<qqI4x", 24)
                    if offset + size > blob_length:
                        raise EOFError("TEXTURE_LOAD fixed part")

                    unpacked = struct.unpack_from(fmt, events_blob, offset)
                    offset += size
                    event["id1"], event["id2"], filename_length = unpacked

                    if offset + filename_length > blob_length:
                        raise EOFError("TEXTURE_LOAD variable part")
                    event["filename"] = events_blob[
                        offset : offset + filename_length
                    ].decode("utf-8")
                    offset += filename_length
                    events.append(event)

                elif event_type == Events.PLUGIN_LOAD.value:
                    fmt, size = PackFormat.get_info(event_type)  # ("<I", 4)
                    if offset + size > blob_length:
                        raise EOFError("PLUGIN_LOAD fixed part")

                    path_length = struct.unpack_from(fmt, events_blob, offset)[0]
                    offset += size
                    event["pathLength"] = path_length

                    if offset + path_length > blob_length:
                        raise EOFError("PLUGIN_LOAD variable part")
                    event["path"] = events_blob[offset : offset + path_length].decode(
                        "utf-8"
                    )
                    offset += path_length
                    events.append(event)

                elif event_type == Events.AUDIO_LOAD.value:
                    fmt, size = PackFormat.get_info(event_type)  # ("<I", 4)
                    if offset + size > blob_length:
                        raise EOFError("AUDIO_LOAD fixed part")

                    path_length = struct.unpack_from(fmt, events_blob, offset)[0]
                    offset += size
                    event["pathLength"] = path_length

                    if offset + path_length > blob_length:
                        raise EOFError("AUDIO_LOAD variable part")
                    event["path"] = events_blob[offset : offset + path_length].decode(
                        "utf-8"
                    )
                    offset += path_length
                    events.append(event)

                elif event_type == Events.TEXT_ADD.value:
                    fmt, size = PackFormat.get_info(
                        event_type
                    )  # ("<qqdddBBBB4xfII4x", 64)
                    if offset + size > blob_length:
                        raise EOFError("TEXT_ADD fixed part")

                    unpacked = struct.unpack_from(fmt, events_blob, offset)
                    offset += size

                    keys = [
                        "id1",
                        "id2",
                        "positionX",
                        "positionY",
                        "positionZ",
                        "r",
                        "g",
                        "b",
                        "a",
                        "fontSize",
                        "fontPathLength",
                        "textLength",
                    ]
                    event.update(zip(keys, unpacked))

                    font_path_len = event["fontPathLength"]
                    text_len = event["textLength"]

                    if offset + font_path_len > blob_length:
                        raise EOFError("TEXT_ADD font path")
                    event["fontPath"] = events_blob[
                        offset : offset + font_path_len
                    ].decode("utf-8")
                    offset += font_path_len

                    if offset + text_len > blob_length:
                        raise EOFError("TEXT_ADD text")
                    event["text"] = events_blob[offset : offset + text_len].decode(
                        "utf-8"
                    )
                    offset += text_len
                    events.append(event)

                elif event_type == Events.TEXT_SET_STRING.value:
                    fmt, size = PackFormat.get_info(event_type)  # ("<qqI4x", 24)
                    if offset + size > blob_length:
                        raise EOFError("TEXT_SET_STRING fixed part")

                    unpacked = struct.unpack_from(fmt, events_blob, offset)
                    offset += size

                    keys = ["id1", "id2", "textLength"]
                    event.update(zip(keys, unpacked))

                    text_len = event["textLength"]
                    if offset + text_len > blob_length:
                        raise EOFError("TEXT_SET_STRING text")
                    event["text"] = events_blob[offset : offset + text_len].decode(
                        "utf-8"
                    )
                    offset += text_len
                    events.append(event)

                elif event_enum_val is not None:
                    # --- Generic Fixed-Size Event Handler ---
                    payload_info = PackFormat.get_info(event_type)
                    if payload_info is None:
                        raise ValueError(
                            f"Could not get info for known event type {event_type}"
                        )

                    payload_format, payload_size = payload_info

                    if offset + payload_size > blob_length:
                        raise EOFError(
                            f"{event_enum_val.name} payload (size {payload_size})"
                        )

                    if payload_size > 0:
                        unpacked = struct.unpack_from(
                            payload_format, events_blob, offset
                        )

                        # --- MODIFIED BLOCK ---
                        # Use the pre-computed key map instead of generic v{i} keys
                        keys = PackFormat._EVENT_KEY_MAP.get(event_type)

                        if keys is not None:
                            if len(keys) == len(unpacked):
                                payload_data = dict(zip(keys, unpacked))
                            else:
                                # Error: struct definition and key map are out of sync
                                print(
                                    f"PackFormat.unpack: Key/Value mismatch for {event_enum_val.name}. Keys: {len(keys)}, Vals: {len(unpacked)}",
                                    file=sys.stderr,
                                )
                                payload_data = {
                                    f"v{i}": val for i, val in enumerate(unpacked)
                                }
                        else:
                            # Fallback for events missing from key map (shouldn't happen)
                            payload_data = {
                                f"v{i}": val for i, val in enumerate(unpacked)
                            }

                        event.update(payload_data)
                        # --- END MODIFIED BLOCK ---

                        events.append(event)
                    else:
                        events.append(event)  # No payload

                    offset += payload_size

                else:
                    print(
                        f"PackFormat.unpack: Unknown event type {event_type}. Cannot continue parsing.",
                        file=sys.stderr,
                    )
                    break

            except EOFError as e:
                print(
                    f"PackFormat.unpack: Not enough data for {e}. Stopping parse.",
                    file=sys.stderr,
                )
                break
            except struct.error as e:
                print(
                    f"PackFormat.unpack: Struct error for {event_enum_val.name if event_enum_val else event_type}: {e}",
                    file=sys.stderr,
                )
                break
            except Exception as e:
                print(
                    f"PackFormat.unpack: General error on {event_enum_val.name if event_enum_val else event_type}: {e}",
                    file=sys.stderr,
                )
                break

        return events
        # --- End PackFormat Class ---
