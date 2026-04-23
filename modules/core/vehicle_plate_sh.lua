SKVehiclePlate = {}

local DIGITS  = '0123456789'
local LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

---@param charset string
---@param count integer
---@return string
local function randomChars(charset, count)
    local result = {}
    for i = 1, count do
        local idx = math.random(1, #charset)
        result[i] = charset:sub(idx, idx)
    end
    return table.concat(result)
end

--- Generate a unique plate in the format 00AAA000 (2 digits, 3 letters, 3 digits).
---@return string
function SKVehiclePlate.generate()
    return randomChars(DIGITS, 2) .. randomChars(LETTERS, 3) .. randomChars(DIGITS, 3)
end