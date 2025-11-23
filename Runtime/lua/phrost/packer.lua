local Enums = require("phrost_enums")
local Events = Enums.Events
local FormatData = require("phrost_formats")

local CommandPacker = {}
CommandPacker.__index = CommandPacker

function CommandPacker.new()
    local self = setmetatable({}, CommandPacker)
    self.event_stream = ""
    self.command_count = 0
    return self
end

-- Helper: Pad string to 8-byte boundary (Critical for Phrost protocol)
local function pack_string_aligned(str)
    local len = #str
    local padding = (8 - (len % 8)) % 8
    return str .. string.rep("\0", padding)
end

function CommandPacker:pad_boundary()
    local len = #self.event_stream
    local padding = (8 - (len % 8)) % 8
    if padding > 0 then
        self.event_stream = self.event_stream .. string.rep("\0", padding)
    end
end

function CommandPacker:add(event_type, data)
    -- 1. Pack the Generic Header: Type (I4) + Pad (I8 space?) -> PHP was VQx4
    -- Standard header in PHP: pack("VQx4", type, 0) -> I4, I8, x4 (16 bytes)
    self.event_stream = self.event_stream .. string.pack("<I4I8", event_type, 0) .. string.rep("\0", 4)

    -- 2. Check if we have a Fixed Format defined
    local fmt = FormatData.Formats[event_type]

    if fmt and fmt ~= "" then
        -- Pack the numeric/struct data
        -- Note: table.unpack(data) works if 'data' is a sequential array matching the format
        self.event_stream = self.event_stream .. string.pack(fmt, table.unpack(data))
    end

    -- 3. Handle Dynamic String Payloads (Logic ported from PHP manually)
    if event_type == Events.SPRITE_TEXTURE_LOAD then
        -- Data: [1]id1, [2]id2, [3]filename
        -- The fixed part (fmt) handled id1, id2, and filename-length
        -- Now append string
        self.event_stream = self.event_stream .. pack_string_aligned(data[3])

    elseif event_type == Events.PLUGIN_LOAD then
        -- Data: [1]channel, [2]path
        self.event_stream = self.event_stream .. pack_string_aligned(data[2])

    elseif event_type == Events.AUDIO_LOAD then
        -- Data: [1]len, [2]path
        self.event_stream = self.event_stream .. pack_string_aligned(data[2])

    elseif event_type == Events.TEXT_ADD then
        -- Data: ... [14]fontPath, [15]text
        self.event_stream = self.event_stream .. pack_string_aligned(data[14])
        self.event_stream = self.event_stream .. pack_string_aligned(data[15])

    elseif event_type == Events.TEXT_SET_STRING then
        -- Data: ... [4]text
        self.event_stream = self.event_stream .. pack_string_aligned(data[4])

    elseif event_type == Events.WINDOW_TITLE then
        -- Special case: Fixed 256 byte string
        local title = data[1]
        self.event_stream = self.event_stream .. string.pack("c256", title)
    end

    -- 4. Global Alignment
    self:pad_boundary()
    self.command_count = self.command_count + 1
end

function CommandPacker:finalize()
    if self.command_count == 0 then return "" end
    -- Header: Count (4 bytes) + Padding (4 bytes)
    return string.pack("<I4", self.command_count) .. string.rep("\0", 4) .. self.event_stream
end

-- --- Channel Packer Wrapper (Same as before) ---

local ChannelPacker = {}
ChannelPacker.__index = ChannelPacker

function ChannelPacker.new()
    local self = setmetatable({}, ChannelPacker)
    self.packers = {}
    return self
end

function ChannelPacker:add(channel_id, event_type, data)
    if not self.packers[channel_id] then
        self.packers[channel_id] = CommandPacker.new()
    end
    self.packers[channel_id]:add(event_type, data)
end

function ChannelPacker:finalize()
    local count = 0
    local index_table = ""
    local data_blobs = ""

    local keys = {}
    for k in pairs(self.packers) do table.insert(keys, k) end
    table.sort(keys)

    for _, channel_id in ipairs(keys) do
        local blob = self.packers[channel_id]:finalize()
        local size = #blob
        if size > 0 then
            count = count + 1
            index_table = index_table .. string.pack("<I4I4", channel_id, size)
            data_blobs = data_blobs .. blob
        end
    end

    if count == 0 then return "" end
    local header = string.pack("<I4", count) .. string.rep("\0", 4)
    local result = header .. index_table .. data_blobs
    self.packers = {}
    return result
end

return ChannelPacker
