local socket = require("socket")
local ChannelPacker = require("phrost_packer")

local Client = {}
Client.__index = Client

function Client.new()
    local self = setmetatable({}, Client)
    self.sock = nil
    self.packer = ChannelPacker.new()
    return self
end

function Client:connect(host, port)
    host = host or "127.0.0.1"
    port = port or 8080 -- You must configure Swift to listen here

    -- For Unix Domain Sockets (Linux/Mac only):
    -- self.sock = require("socket.unix")()
    -- self.sock:connect("/tmp/PhrostEngine.socket")

    -- For TCP (Windows/Generic):
    print("Connecting to " .. host .. ":" .. port)
    self.sock = assert(socket.connect(host, port))
    self.sock:setoption("tcp-nodelay", true)
    self.sock:settimeout(nil) -- Blocking
    print("Connected!")
end

function Client:read_all(length)
    local buffer = ""
    local remaining = length

    while remaining > 0 do
        -- receive(bytes)
        local chunk, err, partial = self.sock:receive(remaining)

        if not chunk then
            if partial and #partial > 0 then
                buffer = buffer .. partial
                remaining = remaining - #partial
            else
                return nil, err
            end
        else
            buffer = buffer .. chunk
            remaining = remaining - #chunk
        end
    end
    return buffer
end

function Client:read_frame()
    -- 1. Read Length Header (4 bytes)
    local header, err = self:read_all(4)
    if not header then return nil, err end

    local total_len = string.unpack("<I4", header)

    -- 2. Read Payload
    if total_len < 8 then return nil, "Payload too small" end

    local payload, err = self:read_all(total_len)
    if not payload then return nil, err end

    -- 3. Unpack DT (8 bytes double)
    local dt = string.unpack("<d", string.sub(payload, 1, 8))
    local events_blob = string.sub(payload, 9)

    return dt, events_blob
end

function Client:write_frame(command_blob)
    local len = #command_blob
    -- Pack length prefix
    local header = string.pack("<I4", len)
    self.sock:send(header .. command_blob)
end

function Client:run(update_callback)
    if not self.sock then error("Not connected") end

    local elapsed_frames = 0

    while true do
        local dt, events_blob = self:read_frame()
        if not dt then
            print("Pipe broken/Disconnected")
            break
        end

        -- Call user logic
        -- User fills the 'self.packer' during this callback
        update_callback(elapsed_frames, dt, events_blob, self.packer)

        -- Finalize packer to get blob
        local cmd_blob = self.packer:finalize()

        -- Send back
        self:write_frame(cmd_blob)

        elapsed_frames = elapsed_frames + 1
    end
end

return Client
