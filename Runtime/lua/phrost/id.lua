local M = {}

-- Seed the random number generator
math.randomseed(os.time())

function M.generate()
    -- Lua 5.4 supports 64-bit integers natively.
    -- We generate random bytes and unpack them into integers.
    local bytes = ""
    for i = 1, 16 do
        bytes = bytes .. string.char(math.random(0, 255))
    end
    -- unpack as two 64-bit unsigned integers (<I8 is Little Endian unsigned 64-bit)
    local p1, p2 = string.unpack("<I8I8", bytes)
    return p1, p2
end

function M.to_hex(id1, id2)
    local bytes = string.pack("<I8I8", id1, id2)
    local hex = ""
    for i = 1, #bytes do
        hex = hex .. string.format("%02x", string.byte(bytes, i))
    end
    return hex
end

return M
