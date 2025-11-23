local Enums = require("phrost_enums")
local Events = Enums.Events

local M = {}

-- Map Event ID to Lua 5.4 Pack Format string
M.Formats = {
    -- --- SPRITES ---
    -- PHP: qid1/qid2/epositionX.../Cr.../x4...
    [Events.SPRITE_ADD] = "<i8 i8 d d d d d d d d d d d B B B B x4 d d",

    [Events.SPRITE_REMOVE] = "<i8 i8",

    [Events.SPRITE_MOVE]   = "<i8 i8 d d d",
    [Events.SPRITE_SCALE]  = "<i8 i8 d d d",
    [Events.SPRITE_RESIZE] = "<i8 i8 d d",
    [Events.SPRITE_ROTATE] = "<i8 i8 d d d",

    -- PHP: .../x4_padding
    [Events.SPRITE_COLOR]  = "<i8 i8 B B B B x4",

    [Events.SPRITE_SPEED]  = "<i8 i8 d d",

    -- Note: Strings (filename) are handled manually by the packer logic,
    -- this format only covers the fixed header before the string.
    [Events.SPRITE_TEXTURE_LOAD] = "<i8 i8 I4 x4",

    [Events.SPRITE_TEXTURE_SET] = "<i8 i8 I8",

    -- PHP: gx/gy/gw/gh (Floats)
    [Events.SPRITE_SET_SOURCE_RECT] = "<i8 i8 f f f f",

    -- --- GEOMETRY ---
    -- PHP: .../CisScreenSpace/x3_padding/gx/gy
    [Events.GEOM_ADD_POINT]     = "<i8 i8 d B B B B B x3 f f",
    [Events.GEOM_ADD_LINE]      = "<i8 i8 d B B B B B x3 f f f f",
    [Events.GEOM_ADD_RECT]      = "<i8 i8 d B B B B B x3 f f f f",
    [Events.GEOM_ADD_FILL_RECT] = "<i8 i8 d B B B B B x3 f f f f",

    -- PHP: .../x2_padding/VprimitiveType/Vcount
    [Events.GEOM_ADD_PACKED]    = "<i8 i8 d B B B B B x2 I4 I4",

    [Events.GEOM_REMOVE]        = "<i8 i8",
    [Events.GEOM_SET_COLOR]     = "<i8 i8 B B B B x4",

    -- --- INPUT ---
    -- PHP: l(signed 32) V(unsigned 32) S(unsigned 16) C(byte) x
    [Events.INPUT_KEYUP]    = "<i4 I4 I2 B x",
    [Events.INPUT_KEYDOWN]  = "<i4 I4 I2 B x",

    -- PHP: gx/gy/C/C/x2
    [Events.INPUT_MOUSEUP]   = "<f f B B x2",
    [Events.INPUT_MOUSEDOWN] = "<f f B B x2",
    [Events.INPUT_MOUSEMOTION]= "<f f f f",

    -- --- WINDOW ---
    -- String handled manually
    [Events.WINDOW_TITLE]  = "", -- Special case: just a 256-byte string
    [Events.WINDOW_RESIZE] = "<i4 i4",
    [Events.WINDOW_FLAGS]  = "<I8",

    -- --- TEXT ---
    -- Complex Header + Padding
    -- PHP: q.../C.../x4/g/V/V/x4
    [Events.TEXT_ADD]        = "<i8 i8 d d d B B B B x4 f I4 I4 x4",
    [Events.TEXT_SET_STRING] = "<i8 i8 I4 x4",

    -- --- AUDIO ---
    [Events.AUDIO_LOAD]   = "<I4", -- Followed by aligned string
    [Events.AUDIO_LOADED] = "<I8",
    [Events.AUDIO_PLAY]   = "<I8",
    [Events.AUDIO_STOP_ALL] = "<B", -- C_unused
    [Events.AUDIO_SET_MASTER_VOLUME] = "<f",
    [Events.AUDIO_PAUSE]  = "<I8",
    [Events.AUDIO_STOP]   = "<I8",
    [Events.AUDIO_UNLOAD] = "<I8",
    [Events.AUDIO_SET_VOLUME] = "<I8 f x4",

    -- --- PHYSICS ---
    -- PHP: .../C/C/C/x5/e/e...
    [Events.PHYSICS_ADD_BODY] = "<i8 i8 d d B B B x5 d d d d d",
    [Events.PHYSICS_REMOVE_BODY] = "<i8 i8",
    [Events.PHYSICS_APPLY_FORCE] = "<i8 i8 d d",
    [Events.PHYSICS_APPLY_IMPULSE] = "<i8 i8 d d",
    [Events.PHYSICS_SET_VELOCITY] = "<i8 i8 d d",
    [Events.PHYSICS_SET_POSITION] = "<i8 i8 d d",
    [Events.PHYSICS_SET_ROTATION] = "<i8 i8 d",

    -- Unpack / Sync
    [Events.PHYSICS_COLLISION_BEGIN]    = "<i8 i8 i8 i8",
    [Events.PHYSICS_COLLISION_SEPARATE] = "<i8 i8 i8 i8",
    -- PHP: .../CisSleeping/x7
    [Events.PHYSICS_SYNC_TRANSFORM]     = "<i8 i8 d d d d d d B x7",

    -- --- PLUGINS ---
    [Events.PLUGIN]                   = "<B",
    [Events.PLUGIN_LOAD]              = "<I4 I4", -- ChannelNo, PathLen
    [Events.PLUGIN_UNLOAD]            = "<B",
    [Events.PLUGIN_SET]               = "<B",
    [Events.PLUGIN_EVENT_STACKING]    = "<B x",
    [Events.PLUGIN_SUBSCRIBE_EVENT]   = "<B x3 I4",
    [Events.PLUGIN_UNSUBSCRIBE_EVENT] = "<B x3 I4",

    -- --- CAMERA ---
    [Events.CAMERA_SET_POSITION]   = "<d d",
    [Events.CAMERA_MOVE]           = "<d d",
    [Events.CAMERA_SET_ZOOM]       = "<d",
    [Events.CAMERA_SET_ROTATION]   = "<d",
    [Events.CAMERA_FOLLOW_ENTITY]  = "<i8 i8",
    [Events.CAMERA_STOP_FOLLOWING] = "<B",

    -- --- SCRIPT ---
    [Events.SCRIPT_SUBSCRIBE]   = "<I4 x4",
    [Events.SCRIPT_UNSUBSCRIBE] = "<I4 x4",
}

return M
