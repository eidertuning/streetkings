SKProgression = SKProgression or {}

local function requireProgressionInt(key, minimum)
    local value = SKProgressionConfig[key]
    assert(type(value) == 'number' and value % 1 == 0 and value >= minimum, ('streetkings: invalid SKProgressionConfig.%s'):format(key))
    return value
end

SKProgression.PLAYER_MAX_LEVEL = requireProgressionInt('PLAYER_MAX_LEVEL', 1)
SKProgression.VEHICLE_MAX_LEVEL = requireProgressionInt('VEHICLE_MAX_LEVEL', 1)
SKProgression.SINGLE_OPTION_UNLOCK_LEVEL = requireProgressionInt('SINGLE_OPTION_UNLOCK_LEVEL', 1)
SKProgression.WHEEL_PACK_COUNT = requireProgressionInt('WHEEL_PACK_COUNT', 1)
local PLAYER_XP_CURVE_BASE = requireProgressionInt('PLAYER_XP_CURVE_BASE', 0)
local PLAYER_XP_CURVE_LINEAR = requireProgressionInt('PLAYER_XP_CURVE_LINEAR', 0)
local PLAYER_XP_CURVE_QUADRATIC = requireProgressionInt('PLAYER_XP_CURVE_QUADRATIC', 0)
local VEHICLE_XP_CURVE_BASE = requireProgressionInt('VEHICLE_XP_CURVE_BASE', 0)
local VEHICLE_XP_CURVE_LINEAR = requireProgressionInt('VEHICLE_XP_CURVE_LINEAR', 0)
local VEHICLE_XP_CURVE_QUADRATIC = requireProgressionInt('VEHICLE_XP_CURVE_QUADRATIC', 0)

SKProgression.MOD_TYPE_NAMES = {
    [0] = 'Spoilers',
    [1] = 'Front Bumper',
    [2] = 'Rear Bumper',
    [3] = 'Side Skirt',
    [4] = 'Exhaust',
    [5] = 'Frame',
    [6] = 'Grille',
    [7] = 'Hood',
    [8] = 'Fender',
    [9] = 'Right Fender',
    [10] = 'Roof',
    [11] = 'Engine',
    [12] = 'Brakes',
    [13] = 'Transmission',
    [15] = 'Suspension',
    [18] = 'Turbo',
    [22] = 'Xenon Lights',
    [23] = 'Wheels',
    [24] = 'Rear Wheels',
    [25] = 'Plate Holder',
    [26] = 'Vanity Plate',
    [27] = 'Trim Design',
    [28] = 'Ornaments',
    [29] = 'Dashboard',
    [30] = 'Dial Design',
    [31] = 'Door Speaker',
    [32] = 'Seats',
    [33] = 'Steering Wheel',
    [34] = 'Shift Lever',
    [35] = 'Plaques',
    [36] = 'ICE',
    [37] = 'Boot Speaker',
    [38] = 'Hydraulics',
    [39] = 'Engine Block',
    [40] = 'Air Filter',
    [41] = 'Strut Bar',
    [42] = 'Arch Cover',
    [43] = 'Aerial',
    [44] = 'Trim',
    [45] = 'Tank',
    [46] = 'Windows',
    [47] = 'Mirrors',
    [48] = 'Livery',
    [50] = 'Neons',
    [51] = 'Nitrous',
}

---@param maxLevel integer
---@param xpForCurrentLevel fun(n: integer): integer
---@return integer[]
local function buildThresholds(maxLevel, xpForCurrentLevel)
    local thresholds = { [1] = 0 }
    local totalXp = 0

    for level = 2, maxLevel do
        local n = level - 2
        totalXp = totalXp + xpForCurrentLevel(n)
        thresholds[level] = totalXp
    end

    return thresholds
end

SKProgression.PLAYER_LEVEL_THRESHOLDS = buildThresholds(SKProgression.PLAYER_MAX_LEVEL, function(n)
    return PLAYER_XP_CURVE_BASE + (PLAYER_XP_CURVE_LINEAR * n) + (PLAYER_XP_CURVE_QUADRATIC * n * n)
end)

SKProgression.VEHICLE_LEVEL_THRESHOLDS = buildThresholds(SKProgression.VEHICLE_MAX_LEVEL, function(n)
    return VEHICLE_XP_CURVE_BASE + (VEHICLE_XP_CURVE_LINEAR * n) + (VEHICLE_XP_CURVE_QUADRATIC * n * n)
end)

---@param xp integer
---@param thresholds integer[]
---@param maxLevel integer
---@return integer
function SKProgression.resolveLevelFromXp(xp, thresholds, maxLevel)
    for level = maxLevel, 1, -1 do
        if xp >= thresholds[level] then
            return level
        end
    end

    return 1
end

---@param xp integer
---@return integer
function SKProgression.getPlayerLevelFromXp(xp)
    return SKProgression.resolveLevelFromXp(xp, SKProgression.PLAYER_LEVEL_THRESHOLDS, SKProgression.PLAYER_MAX_LEVEL)
end

---@param xp integer
---@return integer
function SKProgression.getVehicleLevelFromXp(xp)
    return SKProgression.resolveLevelFromXp(xp, SKProgression.VEHICLE_LEVEL_THRESHOLDS, SKProgression.VEHICLE_MAX_LEVEL)
end

---@param level integer
---@param thresholds integer[]
---@param maxLevel integer
---@return integer|nil
function SKProgression.getXpForNextLevel(level, thresholds, maxLevel)
    if level >= maxLevel then
        return nil
    end

    return thresholds[level + 1]
end

---@param modType integer
---@param modIndex integer
---@return string
function SKProgression.getModOptionKey(modType, modIndex)
    return tostring(modType) .. ':' .. tostring(modIndex)
end

---@param unlockIndex integer
---@param unlockCount integer
---@return integer
function SKProgression.getVehicleUnlockLevel(unlockIndex, unlockCount)
    if unlockCount <= 0 then
        return SKProgression.VEHICLE_MAX_LEVEL
    end
    if unlockCount == 1 then
        return SKProgression.SINGLE_OPTION_UNLOCK_LEVEL
    end

    local clampedIndex = math.max(1, math.min(unlockIndex, unlockCount))
    local span = SKProgression.VEHICLE_MAX_LEVEL - 2
    return 2 + math.floor(((clampedIndex - 1) * span) / (unlockCount - 1))
end

---@param modType integer
---@return boolean
function SKProgression.isWheelModType(modType)
    return modType == 23 or modType == 24
end

---@param unlockIndex integer
---@param unlockCount integer
---@return integer
function SKProgression.getWheelPackIndex(unlockIndex, unlockCount)
    if unlockCount <= 1 then
        return 1
    end

    local clampedIndex = math.max(1, math.min(unlockIndex, unlockCount))
    local packIndex = math.floor(((clampedIndex - 1) * SKProgression.WHEEL_PACK_COUNT) / unlockCount) + 1
    return math.max(1, math.min(packIndex, SKProgression.WHEEL_PACK_COUNT))
end

---@param packIndex integer
---@return integer
function SKProgression.getWheelPackUnlockLevel(packIndex)
    local clampedPack = math.max(1, math.min(packIndex, SKProgression.WHEEL_PACK_COUNT))
    return SKProgression.getVehicleUnlockLevel(clampedPack, SKProgression.WHEEL_PACK_COUNT)
end

---@param packIndex integer
---@return string
function SKProgression.getWheelPackName(packIndex)
    local names = {
        [1] = 'Street Wheels',
        [2] = 'Sport Wheels',
        [3] = 'Track Wheels',
        [4] = 'Elite Wheels',
    }
    return names[packIndex] or ('Wheels Pack ' .. tostring(packIndex))
end
