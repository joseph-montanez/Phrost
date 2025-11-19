from typing import Tuple


# --- Pack Format Classes ---
class SpritePackFormats:
    """
    Maps to Swift: `PackedSpriteAddEvent`
    - id1: i64 (Primary identifier (e.g., entity ID).)
    - id2: i64 (Secondary identifier (e.g., component ID).)
    - positionX: f64 (Initial X position.)
    - positionY: f64 (Initial Y position.)
    - positionZ: f64 (Initial Z position (depth).)
    - scaleX: f64 (Initial X scale.)
    - scaleY: f64 (Initial Y scale.)
    - scaleZ: f64 (Initial Z scale.)
    - sizeW: f64 (Initial width.)
    - sizeH: f64 (Initial height.)
    - rotationX: f64 (Initial X rotation (in radians).)
    - rotationY: f64 (Initial Y rotation (in radians).)
    - rotationZ: f64 (Initial Z rotation (in radians).)
    - r: u8 (Red color component (0-255).)
    - g: u8 (Green color component (0-255).)
    - b: u8 (Blue color component (0-255).)
    - a: u8 (Alpha color component (0-255).)
    - _padding: u32 (Ensures 8-byte alignment for speeds.)
    - speedX: f64 (Initial X speed.)
    - speedY: f64 (Initial Y speed.)
    """

    # Format: <qqdddddddddddBBBB4xdd
    # Size: 128 bytes
    PACK_SPRITE_ADD: Tuple[str, int] = ("<qqdddddddddddBBBB4xdd", 128)

    """
    Maps to Swift: `PackedSpriteRemoveEvent`
    - id1: i64 (Primary ID of sprite to remove.)
    - id2: i64 (Secondary ID of sprite to remove.)
    """
    # Format: <qq
    # Size: 16 bytes
    PACK_SPRITE_REMOVE: Tuple[str, int] = ("<qq", 16)

    """
    Maps to Swift: `PackedSpriteMoveEvent`
    - id1: i64 (Primary ID of the sprite.)
    - id2: i64 (Secondary ID of the sprite.)
    - positionX: f64 (New X position.)
    - positionY: f64 (New Y position.)
    - positionZ: f64 (New Z position (depth).)
    """
    # Format: <qqddd
    # Size: 40 bytes
    PACK_SPRITE_MOVE: Tuple[str, int] = ("<qqddd", 40)

    """
    Maps to Swift: `PackedSpriteScaleEvent`
    - id1: i64 (Primary ID of the sprite.)
    - id2: i64 (Secondary ID of the sprite.)
    - scaleX: f64 (New X scale.)
    - scaleY: f64 (New Y scale.)
    - scaleZ: f64 (New Z scale.)
    """
    # Format: <qqddd
    # Size: 40 bytes
    PACK_SPRITE_SCALE: Tuple[str, int] = ("<qqddd", 40)

    """
    Maps to Swift: `PackedSpriteResizeEvent`
    - id1: i64 (Primary ID of the sprite.)
    - id2: i64 (Secondary ID of the sprite.)
    - sizeW: f64 (New width.)
    - sizeH: f64 (New height.)
    """
    # Format: <qqdd
    # Size: 32 bytes
    PACK_SPRITE_RESIZE: Tuple[str, int] = ("<qqdd", 32)

    """
    Maps to Swift: `PackedSpriteRotateEvent`
    - id1: i64 (Primary ID of the sprite.)
    - id2: i64 (Secondary ID of the sprite.)
    - rotationX: f64 (New X rotation (in radians).)
    - rotationY: f64 (New Y rotation (in radians).)
    - rotationZ: f64 (New Z rotation (in radians).)
    """
    # Format: <qqddd
    # Size: 40 bytes
    PACK_SPRITE_ROTATE: Tuple[str, int] = ("<qqddd", 40)

    """
    Maps to Swift: `PackedSpriteColorEvent`
    - id1: i64 (Primary ID of the sprite.)
    - id2: i64 (Secondary ID of the sprite.)
    - r: u8 (New red component (0-255).)
    - g: u8 (New green component (0-255).)
    - b: u8 (New blue component (0-255).)
    - a: u8 (New alpha component (0-255).)
    - _padding: u32 (Padding for alignment.)
    """
    # Format: <qqBBBB4x
    # Size: 24 bytes
    PACK_SPRITE_COLOR: Tuple[str, int] = ("<qqBBBB4x", 24)

    """
    Maps to Swift: `PackedSpriteSpeedEvent`
    - id1: i64 (Primary ID of the sprite.)
    - id2: i64 (Secondary ID of the sprite.)
    - speedX: f64 (New X speed.)
    - speedY: f64 (New Y speed.)
    """
    # Format: <qqdd
    # Size: 32 bytes
    PACK_SPRITE_SPEED: Tuple[str, int] = ("<qqdd", 32)

    """
    Maps to Swift: `PackedTextureLoadHeaderEvent`
    (Header struct)
    - id1: i64 (ID of the sprite this texture is for.)
    - id2: i64 (Secondary ID.)
    - filenameLength: u32 (Length of the texture filename that follows this header.)
    - _padding: u32 (Padding for alignment.)
    """
    # Format: <qqI4x
    # Size: 24 bytes
    PACK_SPRITE_TEXTURE_LOAD: Tuple[str, int] = ("<qqI4x", 24)

    """
    Maps to Swift: `PackedSpriteTextureSetEvent`
    - id1: i64 (Primary ID of the sprite.)
    - id2: i64 (Secondary ID of the sprite.)
    - textureId: u64 (The ID of the loaded texture to set.)
    """
    # Format: <qqQ
    # Size: 24 bytes
    PACK_SPRITE_TEXTURE_SET: Tuple[str, int] = ("<qqQ", 24)

    """
    Maps to Swift: `PackedSpriteSetSourceRectEvent`
    - id1: i64 (Primary ID of the sprite.)
    - id2: i64 (Secondary ID of the sprite.)
    - x: f32 (Source rect X coordinate.)
    - y: f32 (Source rect Y coordinate.)
    - w: f32 (Source rect Width.)
    - h: f32 (Source rect Height.)
    """
    # Format: <qqffff
    # Size: 32 bytes
    PACK_SPRITE_SET_SOURCE_RECT: Tuple[str, int] = ("<qqffff", 32)

    """
    Maps to Swift: `PackedGeomAddPointEvent`
    - id1: i64 (Primary identifier.)
    - id2: i64 (Secondary identifier.)
    - z: f64 (Z position (depth).)
    - r: u8 (Red color component (0-255).)
    - g: u8 (Green color component (0-255).)
    - b: u8 (Blue color component (0-255).)
    - a: u8 (Alpha color component (0-255).)
    - isScreenSpace: u8 (If the geometry is unaffected by the camera.)
    - _padding: u8 (Padding for alignment.)
    - x: f32 (X coordinate.)
    - y: f32 (Y coordinate.)
    """
    # Format: <qqdBBBBB3xff
    # Size: 40 bytes
    PACK_GEOM_ADD_POINT: Tuple[str, int] = ("<qqdBBBBB3xff", 40)

    """
    Maps to Swift: `PackedGeomAddLineEvent`
    - id1: i64 (Primary identifier.)
    - id2: i64 (Secondary identifier.)
    - z: f64 (Z position (depth).)
    - r: u8 (Red color component (0-255).)
    - g: u8 (Green color component (0-255).)
    - b: u8 (Blue color component (0-255).)
    - a: u8 (Alpha color component (0-255).)
    - isScreenSpace: u8 (If the geometry is unaffected by the camera.)
    - _padding: u8 (Padding for alignment.)
    - x1: f32 (Start X coordinate.)
    - y1: f32 (Start Y coordinate.)
    - x2: f32 (End X coordinate.)
    - y2: f32 (End Y coordinate.)
    """
    # Format: <qqdBBBBB3xffff
    # Size: 48 bytes
    PACK_GEOM_ADD_LINE: Tuple[str, int] = ("<qqdBBBBB3xffff", 48)

    """
    Maps to Swift: `PackedGeomAddRectEvent`
    - id1: i64 (Primary identifier.)
    - id2: i64 (Secondary identifier.)
    - z: f64 (Z position (depth).)
    - r: u8 (Red color component (0-255).)
    - g: u8 (Green color component (0-255).)
    - b: u8 (Blue color component (0-255).)
    - a: u8 (Alpha color component (0-255).)
    - isScreenSpace: u8 (If the geometry is unaffected by the camera.)
    - _padding: u8 (Padding for alignment.)
    - x: f32 (Top-left X coordinate.)
    - y: f32 (Top-left Y coordinate.)
    - w: f32 (Width.)
    - h: f32 (Height.)
    """
    # Format: <qqdBBBBB3xffff
    # Size: 48 bytes
    PACK_GEOM_ADD_RECT: Tuple[str, int] = ("<qqdBBBBB3xffff", 48)

    """
    Maps to Swift: `PackedGeomAddRectEvent`
    - id1: i64 (Primary identifier.)
    - id2: i64 (Secondary identifier.)
    - z: f64 (Z position (depth).)
    - r: u8 (Red color component (0-255).)
    - g: u8 (Green color component (0-255).)
    - b: u8 (Blue color component (0-255).)
    - a: u8 (Alpha color component (0-255).)
    - isScreenSpace: u8 (If the geometry is unaffected by the camera.)
    - _padding: u8 (Padding for alignment.)
    - x: f32 (Top-left X coordinate.)
    - y: f32 (Top-left Y coordinate.)
    - w: f32 (Width.)
    - h: f32 (Height.)
    """
    # Format: <qqdBBBBB3xffff
    # Size: 48 bytes
    PACK_GEOM_ADD_FILL_RECT: Tuple[str, int] = ("<qqdBBBBB3xffff", 48)

    """
    Maps to Swift: `PackedGeomAddPackedHeaderEvent`
    (Header struct)
    - id1: i64 (Primary identifier.)
    - id2: i64 (Secondary identifier.)
    - z: f64 (Z position (depth).)
    - r: u8 (Red color component (0-255).)
    - g: u8 (Green color component (0-255).)
    - b: u8 (Blue color component (0-255).)
    - a: u8 (Alpha color component (0-255).)
    - isScreenSpace: u8 (If the geometry is unaffected by the camera.)
    - _padding: u16 (Padding for alignment.)
    - primitiveType: u32 (Raw value from PrimitiveType enum (point, line, rect).)
    - count: u32 (Number of primitives that follow this header.)
    """
    # Format: <qqdBBBBB2xII
    # Size: 39 bytes
    PACK_GEOM_ADD_PACKED: Tuple[str, int] = ("<qqdBBBBB2xII", 39)

    """
    Maps to Swift: `PackedGeomRemoveEvent`
    - id1: i64 (Primary ID of geometry to remove.)
    - id2: i64 (Secondary ID of geometry to remove.)
    """
    # Format: <qq
    # Size: 16 bytes
    PACK_GEOM_REMOVE: Tuple[str, int] = ("<qq", 16)

    """
    Maps to Swift: `PackedGeomSetColorEvent`
    - id1: i64 (Primary ID of the geometry entity.)
    - id2: i64 (Secondary ID of the geometry entity.)
    - r: u8 (New red component (0-255).)
    - g: u8 (New green component (0-255).)
    - b: u8 (New blue component (0-255).)
    - a: u8 (New alpha component (0-255).)
    - _padding: u32 (Padding for alignment.)
    """
    # Format: <qqBBBB4x
    # Size: 24 bytes
    PACK_GEOM_SET_COLOR: Tuple[str, int] = ("<qqBBBB4x", 24)


class InputPackFormats:
    """
    Maps to Swift: `PackedKeyEvent`
    - scancode: i32 (Physical key scancode.)
    - keycode: u32 (Keycode (e.g., Keycode.A).)
    - mod: u16 (Key modifiers (Shift, Ctrl, etc.).)
    - isRepeat: u8 (1 if this is a key repeat, 0 otherwise.)
    - _padding: u8 (Padding for alignment.)
    """

    # Format: <iIHBx
    # Size: 12 bytes
    PACK_INPUT_KEYUP: Tuple[str, int] = ("<iIHBx", 12)

    """
    Maps to Swift: `PackedKeyEvent`
    - scancode: i32 (Physical key scancode.)
    - keycode: u32 (Keycode (e.g., Keycode.A).)
    - mod: u16 (Key modifiers (Shift, Ctrl, etc.).)
    - isRepeat: u8 (1 if this is a key repeat, 0 otherwise.)
    - _padding: u8 (Padding for alignment.)
    """
    # Format: <iIHBx
    # Size: 12 bytes
    PACK_INPUT_KEYDOWN: Tuple[str, int] = ("<iIHBx", 12)

    """
    Maps to Swift: `PackedMouseButtonEvent`
    - x: f32 (X coordinate of the mouse.)
    - y: f32 (Y coordinate of the mouse.)
    - button: u8 (Mouse button index.)
    - clicks: u8 (Number of clicks (1 for single, 2 for double).)
    - _padding: u16 (Padding for alignment.)
    """
    # Format: <ffBB2x
    # Size: 12 bytes
    PACK_INPUT_MOUSEUP: Tuple[str, int] = ("<ffBB2x", 12)

    """
    Maps to Swift: `PackedMouseButtonEvent`
    - x: f32 (X coordinate of the mouse.)
    - y: f32 (Y coordinate of the mouse.)
    - button: u8 (Mouse button index.)
    - clicks: u8 (Number of clicks (1 for single, 2 for double).)
    - _padding: u16 (Padding for alignment.)
    """
    # Format: <ffBB2x
    # Size: 12 bytes
    PACK_INPUT_MOUSEDOWN: Tuple[str, int] = ("<ffBB2x", 12)

    """
    Maps to Swift: `PackedMouseMotionEvent`
    - x: f32 (Absolute X coordinate.)
    - y: f32 (Absolute Y coordinate.)
    - xrel: f32 (Relative X motion.)
    - yrel: f32 (Relative Y motion.)
    """
    # Format: <ffff
    # Size: 16 bytes
    PACK_INPUT_MOUSEMOTION: Tuple[str, int] = ("<ffff", 16)


class WindowPackFormats:
    """
    Maps to Swift: `PackedWindowTitleEvent`
    - title: char[256] (A fixed-size 256-byte NUL-padded string for the title.)
    """

    # Format: <256s
    # Size: 256 bytes
    PACK_WINDOW_TITLE: Tuple[str, int] = ("<256s", 256)

    """
    Maps to Swift: `PackedWindowResizeEvent`
    - w: i32 (New window width.)
    - h: i32 (New window height.)
    """
    # Format: <ii
    # Size: 8 bytes
    PACK_WINDOW_RESIZE: Tuple[str, int] = ("<ii", 8)

    """
    Maps to Swift: `PackedWindowFlagsEvent`
    - flags: u64 (Bitmask of window flags.)
    """
    # Format: <Q
    # Size: 8 bytes
    PACK_WINDOW_FLAGS: Tuple[str, int] = ("<Q", 8)


class TextPackFormats:
    """
    Maps to Swift: `PackedTextAddEvent`
    (Header struct)
    - id1: i64 (Primary identifier.)
    - id2: i64 (Secondary identifier.)
    - positionX: f64 (Initial X position.)
    - positionY: f64 (Initial Y position.)
    - positionZ: f64 (Initial Z position (depth).)
    - r: u8 (Red color component (0-255).)
    - g: u8 (Green color component (0-255).)
    - b: u8 (Blue color component (0-255).)
    - a: u8 (Alpha color component (0-255).)
    - _padding1: u32 (Padding for alignment.)
    - fontSize: f32 (Font size.)
    - fontPathLength: u32 (Length of the font path string that follows.)
    - textLength: u32 (Length of the initial text string that follows.)
    - _padding2: u32 (Padding.)
    """

    # Format: <qqdddBBBB4xfII4x
    # Size: 64 bytes
    PACK_TEXT_ADD: Tuple[str, int] = ("<qqdddBBBB4xfII4x", 64)

    """
    Maps to Swift: `PackedTextSetStringEvent`
    (Header struct)
    - id1: i64 (Primary ID of the text entity.)
    - id2: i64 (Secondary ID of the text entity.)
    - textLength: u32 (Length of the new text string that follows this header.)
    - _padding: u32 (Padding for alignment.)
    """
    # Format: <qqI4x
    # Size: 24 bytes
    PACK_TEXT_SET_STRING: Tuple[str, int] = ("<qqI4x", 24)


class AudioPackFormats:
    """
    Maps to Swift: `PackedAudioLoadEvent`
    (Header struct)
    - pathLength: u32 (Length of the audio file path that follows.)
    """

    # Format: <I
    # Size: 4 bytes
    PACK_AUDIO_LOAD: Tuple[str, int] = ("<I", 4)

    """
    Maps to Swift: `PackedAudioLoadedEvent`
    - audioId: u64 (The ID assigned to the loaded audio.)
    """
    # Format: <Q
    # Size: 8 bytes
    PACK_AUDIO_LOADED: Tuple[str, int] = ("<Q", 8)

    """
    Maps to Swift: `PackedAudioPlayEvent`
    - audioId: u64 (The ID of the audio to play.)
    """
    # Format: <Q
    # Size: 8 bytes
    PACK_AUDIO_PLAY: Tuple[str, int] = ("<Q", 8)

    """
    Maps to Swift: `PackedAudioStopAllEvent`
    - _unused: u8 (Padding to ensure non-zero struct size (MSVC compatibility).)
    """
    # Format: <B
    # Size: 1 bytes
    PACK_AUDIO_STOP_ALL: Tuple[str, int] = ("<B", 1)

    """
    Maps to Swift: `PackedAudioSetMasterVolumeEvent`
    - volume: f32 (Volume level (e.g., 0.0 to 1.0).)
    """
    # Format: <f
    # Size: 4 bytes
    PACK_AUDIO_SET_MASTER_VOLUME: Tuple[str, int] = ("<f", 4)

    """
    Maps to Swift: `PackedAudioPauseEvent`
    - audioId: u64 (The ID of the audio to pause.)
    """
    # Format: <Q
    # Size: 8 bytes
    PACK_AUDIO_PAUSE: Tuple[str, int] = ("<Q", 8)

    """
    Maps to Swift: `PackedAudioStopEvent`
    - audioId: u64 (The ID of the audio to stop.)
    """
    # Format: <Q
    # Size: 8 bytes
    PACK_AUDIO_STOP: Tuple[str, int] = ("<Q", 8)

    """
    Maps to Swift: `PackedAudioUnloadEvent`
    - audioId: u64 (The ID of the audio to unload.)
    """
    # Format: <Q
    # Size: 8 bytes
    PACK_AUDIO_UNLOAD: Tuple[str, int] = ("<Q", 8)

    """
    Maps to Swift: `PackedAudioSetVolumeEvent`
    - audioId: u64 (The ID of the audio to modify.)
    - volume: f32 (Volume level (0.0 to 1.0).)
    - _padding: u32 (Padding for alignment.)
    """
    # Format: <Qf4x
    # Size: 16 bytes
    PACK_AUDIO_SET_VOLUME: Tuple[str, int] = ("<Qf4x", 16)


class PhysicsPackFormats:
    """
    Maps to Swift: `PackedPhysicsAddBodyEvent`
    - id1: i64 (Primary identifier.)
    - id2: i64 (Secondary identifier.)
    - positionX: f64 (Initial X position.)
    - positionY: f64 (Initial Y position.)
    - bodyType: u8 (Body type (static, kinematic, dynamic).)
    - shapeType: u8 (Shape type (box, circle).)
    - lockRotation: u8 (Rotation lock (0 = unlocked, 1 = locked). Prevent bodies from falling over.)
    - _padding: u8 (Padding for 8-byte alignment.)
    - mass: f64 (Mass of the body.)
    - friction: f64 (Friction coefficient.)
    - elasticity: f64 (Elasticity (bounciness).)
    - width: f64 (Width of the shape (or radius).)
    - height: f64 (Height of the shape (unused if circle).)
    """

    # Format: <qqddBBB5xddddd
    # Size: 80 bytes
    PACK_PHYSICS_ADD_BODY: Tuple[str, int] = ("<qqddBBB5xddddd", 80)

    """
    Maps to Swift: `PackedPhysicsRemoveBodyEvent`
    - id1: i64 (Primary ID of body to remove.)
    - id2: i64 (Secondary ID of body to remove.)
    """
    # Format: <qq
    # Size: 16 bytes
    PACK_PHYSICS_REMOVE_BODY: Tuple[str, int] = ("<qq", 16)

    """
    Maps to Swift: `PackedPhysicsApplyForceEvent`
    - id1: i64 (Primary ID of the body.)
    - id2: i64 (Secondary ID of the body.)
    - forceX: f64 (Force vector X component.)
    - forceY: f64 (Force vector Y component.)
    """
    # Format: <qqdd
    # Size: 32 bytes
    PACK_PHYSICS_APPLY_FORCE: Tuple[str, int] = ("<qqdd", 32)

    """
    Maps to Swift: `PackedPhysicsApplyImpulseEvent`
    - id1: i64 (Primary ID of the body.)
    - id2: i64 (Secondary ID of the body.)
    - impulseX: f64 (Impulse vector X component.)
    - impulseY: f64 (Impulse vector Y component.)
    """
    # Format: <qqdd
    # Size: 32 bytes
    PACK_PHYSICS_APPLY_IMPULSE: Tuple[str, int] = ("<qqdd", 32)

    """
    Maps to Swift: `PackedPhysicsSetVelocityEvent`
    - id1: i64 (Primary ID of the body.)
    - id2: i64 (Secondary ID of the body.)
    - velocityX: f64 (New X velocity.)
    - velocityY: f64 (New Y velocity.)
    """
    # Format: <qqdd
    # Size: 32 bytes
    PACK_PHYSICS_SET_VELOCITY: Tuple[str, int] = ("<qqdd", 32)

    """
    Maps to Swift: `PackedPhysicsSetPositionEvent`
    - id1: i64 (Primary ID of the body.)
    - id2: i64 (Secondary ID of the body.)
    - positionX: f64 (New X position.)
    - positionY: f64 (New Y position.)
    """
    # Format: <qqdd
    # Size: 32 bytes
    PACK_PHYSICS_SET_POSITION: Tuple[str, int] = ("<qqdd", 32)

    """
    Maps to Swift: `PackedPhysicsSetRotationEvent`
    - id1: i64 (Primary ID of the body.)
    - id2: i64 (Secondary ID of the body.)
    - angleInRadians: f64 (New angle in radians.)
    """
    # Format: <qqd
    # Size: 24 bytes
    PACK_PHYSICS_SET_ROTATION: Tuple[str, int] = ("<qqd", 24)

    """
    Maps to Swift: `PackedPhysicsCollisionEvent`
    - id1_A: i64 (Primary ID of the first body.)
    - id2_A: i64 (Secondary ID of the first body.)
    - id1_B: i64 (Primary ID of the second body.)
    - id2_B: i64 (Secondary ID of the second body.)
    """
    # Format: <qqqq
    # Size: 32 bytes
    UNPACK_PHYSICS_COLLISION: Tuple[str, int] = ("<qqqq", 32)

    """
    Maps to Swift: `PackedPhysicsSyncTransformEvent`
    - id1: i64 (Primary ID of the body.)
    - id2: i64 (Secondary ID of the body.)
    - positionX: f64 (Current X position.)
    - positionY: f64 (Current Y position.)
    - angle: f64 (Current rotation (in radians).)
    - velocityX: f64 (Current X velocity.)
    - velocityY: f64 (Current Y velocity.)
    - angularVelocity: f64 (Current angular velocity (spin speed) in radians/sec.)
    - isSleeping: u8 (1 if the body is sleeping, 0 if active.)
    - _padding: u8 (Aligns struct to 64-bit boundary.)
    """
    # Format: <qqddddddB7x
    # Size: 72 bytes
    UNPACK_PHYSICS_SYNC_TRANSFORM: Tuple[str, int] = ("<qqddddddB7x", 72)


class PluginPackFormats:
    """
    Maps to Swift: `PackedPluginOnEvent`
    - eventId: u8 (A custom event ID for the plugin.)
    """

    # Format: <B
    # Size: 1 bytes
    PACK_PLUGIN: Tuple[str, int] = ("<B", 1)

    """
    Maps to Swift: `PackedPluginLoadHeaderEvent`
    (Header struct)
    - channelNo: u32 (Initial Channel number to receive events from. Look at channel subscription event to listen to more than one channel.)
    - pathLength: u32 (Length of the plugin file path that follows.)
    """
    # Format: <II
    # Size: 8 bytes
    PACK_PLUGIN_LOAD: Tuple[str, int] = ("<II", 8)

    """
    Maps to Swift: `PackedPluginUnloadEvent`
    - pluginId: u8 (ID of the plugin to unload.)
    """
    # Format: <B
    # Size: 1 bytes
    PACK_PLUGIN_UNLOAD: Tuple[str, int] = ("<B", 1)

    """
    Maps to Swift: `PackedPluginSetEvent`
    - pluginId: u8 (ID of the plugin to set as active.)
    """
    # Format: <B
    # Size: 1 bytes
    PACK_PLUGIN_SET: Tuple[str, int] = ("<B", 1)

    """
    Maps to Swift: `PackedPluginEventStackingEvent`
    - eventId: u8 (1 to enable stacking, 0 to disable.)
    - _padding: u8 (Padding for alignment.)
    """
    # Format: <Bx
    # Size: 2 bytes
    PACK_PLUGIN_EVENT_STACKING: Tuple[str, int] = ("<Bx", 2)

    """
    Maps to Swift: `PackedPluginSubscribeEvent`
    - pluginId: u8 (ID of the plugin.)
    - _padding: u8 (Padding for alignment.)
    - channelNo: u32 (Channel number to receive events from.)
    """
    # Format: <B3xI
    # Size: 8 bytes
    PACK_PLUGIN_SUBSCRIBE_EVENT: Tuple[str, int] = ("<B3xI", 8)

    """
    Maps to Swift: `PackedPluginUnsubscribeEvent`
    - pluginId: u8 (ID of the plugin.)
    - _padding: u8 (Padding for alignment.)
    - channelNo: u32 (Channel number to stop receiving events from.)
    """
    # Format: <B3xI
    # Size: 8 bytes
    PACK_PLUGIN_UNSUBSCRIBE_EVENT: Tuple[str, int] = ("<B3xI", 8)


class CameraPackFormats:
    """
    Maps to Swift: `PackedCameraSetPositionEvent`
    - positionX: f64 (New X position for the camera's top-left corner.)
    - positionY: f64 (New Y position for the camera's top-left corner.)
    """

    # Format: <dd
    # Size: 16 bytes
    PACK_CAMERA_SET_POSITION: Tuple[str, int] = ("<dd", 16)

    """
    Maps to Swift: `PackedCameraMoveEvent`
    - deltaX: f64 (Amount to move the camera on the X axis.)
    - deltaY: f64 (Amount to move the camera on the Y axis.)
    """
    # Format: <dd
    # Size: 16 bytes
    PACK_CAMERA_MOVE: Tuple[str, int] = ("<dd", 16)

    """
    Maps to Swift: `PackedCameraSetZoomEvent`
    - zoom: f64 (New zoom level. 1.0 is default, 2.0 is zoomed in.)
    """
    # Format: <d
    # Size: 8 bytes
    PACK_CAMERA_SET_ZOOM: Tuple[str, int] = ("<d", 8)

    """
    Maps to Swift: `PackedCameraSetRotationEvent`
    - angleInRadians: f64 (New camera rotation in radians.)
    """
    # Format: <d
    # Size: 8 bytes
    PACK_CAMERA_SET_ROTATION: Tuple[str, int] = ("<d", 8)

    """
    Maps to Swift: `PackedCameraFollowEntityEvent`
    - id1: i64 (Primary ID of the entity to follow.)
    - id2: i64 (Secondary ID of the entity to follow.)
    """
    # Format: <qq
    # Size: 16 bytes
    PACK_CAMERA_FOLLOW_ENTITY: Tuple[str, int] = ("<qq", 16)

    """
    Maps to Swift: `PackedCameraStopFollowingEvent`
    - _unused: u8 (Padding to ensure non-zero struct size (MSVC compatibility).)
    """
    # Format: <B
    # Size: 1 bytes
    PACK_CAMERA_STOP_FOLLOWING: Tuple[str, int] = ("<B", 1)


class ScriptPackFormats:
    """
    Maps to Swift: `PackedScriptSubscribeEvent`
    - channelNo: u32 (Channel number to start receiving events from.)
    - _padding: u32 (Padding for alignment.)
    """

    # Format: <I4x
    # Size: 8 bytes
    PACK_SCRIPT_SUBSCRIBE: Tuple[str, int] = ("<I4x", 8)

    """
    Maps to Swift: `PackedScriptUnsubscribeEvent`
    - channelNo: u32 (Channel number to stop receiving events from.)
    - _padding: u32 (Padding for alignment.)
    """
    # Format: <I4x
    # Size: 8 bytes
    PACK_SCRIPT_UNSUBSCRIBE: Tuple[str, int] = (
        "<I4x",
        8,
    )  # --- End Pack Format Classes ---
