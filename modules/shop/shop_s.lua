lib.callback.register('streetkings:shop:getBalance', function(source)
    return SKSaves.read(source, 'economy.cash')
end)

lib.callback.register('streetkings:shop:loadDiscovered', function(source)
    local world = SKSaves.read(source, 'world.state')
    return world.discoveredShops or {}
end)

lib.callback.register('streetkings:shop:discover', function(source, shopId)
    local world    = SKSaves.read(source, 'world.state')
    local list     = world.discoveredShops or {}
    for _, id in ipairs(list) do
        if id == shopId then return { ok = true } end
    end
    list[#list + 1] = shopId
    world.discoveredShops = list
    SKSaves.write(source, 'world.state', world)
    return { ok = true }
end)

lib.callback.register('streetkings:shop:getVehicleColors', function(source)
    local document  = SKSaves.getDocument(source)
    local vehicleId = document.garage.activeVehicleId
    local entry     = document.garage.vehicles[vehicleId]
    return entry.data.colors or {}
end)

lib.callback.register('streetkings:shop:getVehicleMods', function(source)
    local document  = SKSaves.getDocument(source)
    local vehicleId = document.garage.activeVehicleId
    local entry     = document.garage.vehicles[vehicleId]
    return entry.data.mods or {}
end)

lib.callback.register('streetkings:shop:getVehicleProgression', function(source)
    local _, entry = SKProgression.getActiveVehicleEntry(source)
    if not entry then
        return nil
    end

    local unlockLevels = {}
    for _, unlock in ipairs(entry.data.unlockSchedule) do
        unlockLevels[unlock.key] = unlock.level
    end

    return {
        level = entry.data.level,
        xp = entry.data.xp,
        unlocks = entry.data.unlocks,
        unlockLevels = unlockLevels,
    }
end)

---@param source integer
---@return table, string, table
local function getActiveVehicleEntry(source)
    local document = SKSaves.getDocument(source)
    local vehicleId = document.garage.activeVehicleId
    local entry = document.garage.vehicles[vehicleId]
    return document, vehicleId, entry
end

---@param entry table
---@param unlockKey string
---@return integer|nil
local function getUnlockLevel(entry, unlockKey)
    for _, unlock in ipairs(entry.data.unlockSchedule) do
        if unlock.key == unlockKey then
            return unlock.level
        end
    end
end

---@param entry table
---@param modType integer
---@param modIndex integer
---@return boolean
local function hasModOption(entry, modType, modIndex)
    if modIndex == -1 then
        return true
    end

    for _, mod in ipairs(entry.data.availableMods) do
        if mod.modType == modType then
            for _, option in ipairs(mod.options) do
                if option.index == modIndex then
                    return true
                end
            end
            return false
        end
    end

    return false
end

local VALID_COLOR_SLOTS = { primary = true, secondary = true }

lib.callback.register('streetkings:shop:purchaseColor', function(source, slot, r, g, b)
    if not VALID_COLOR_SLOTS[slot] then
        return { ok = false, reason = 'invalid_slot' }
    end

    if type(r) ~= 'number' or type(g) ~= 'number' or type(b) ~= 'number' then
        return { ok = false, reason = 'invalid_color' }
    end

    local document, vehicleId, entry = getActiveVehicleEntry(source)
    local cash = document.economy.cash
    if cash < SKShopShared.COLOR_PRICE then
        return { ok = false, reason = 'insufficient_funds' }
    end

    if not entry.data.colors then entry.data.colors = {} end

    document.economy.cash = cash - SKShopShared.COLOR_PRICE
    entry.data.colors[slot] = {
        r = math.min(255, math.max(0, math.floor(r))),
        g = math.min(255, math.max(0, math.floor(g))),
        b = math.min(255, math.max(0, math.floor(b))),
    }

    SKSaves.write(source, 'economy.cash', document.economy.cash)
    SKSaves.write(source, 'garage.vehicles.' .. vehicleId .. '.data', entry.data)
    SKStats.increment(source, 'totalCashSpent', SKShopShared.COLOR_PRICE)

    return { ok = true, balance = document.economy.cash }
end)

lib.callback.register('streetkings:shop:purchaseMod', function(source, shopTypeKey, modType, modIndex)
    if not SKShopShared.isShopModType(shopTypeKey, modType) then
        return { ok = false, reason = 'invalid_mod' }
    end

    local price = SKShopShared.getModPrice(shopTypeKey, modType, modIndex)
    if not price then
        return { ok = false, reason = 'invalid_mod' }
    end

    local document, vehicleId, entry = getActiveVehicleEntry(source)
    local cash = document.economy.cash
    if cash < price then
        return { ok = false, reason = 'insufficient_funds' }
    end

    if not hasModOption(entry, modType, modIndex) then
        return { ok = false, reason = 'invalid_mod' }
    end

    local unlockKey = SKProgression.getModOptionKey(modType, modIndex)
    if not entry.data.mods then entry.data.mods = {} end

    if modIndex >= 0 and not entry.data.unlocks[unlockKey] then
        return { ok = false, reason = 'locked', unlockLevel = getUnlockLevel(entry, unlockKey) }
    end

    document.economy.cash = cash - price
    entry.data.mods[tostring(modType)] = modIndex

    SKSaves.write(source, 'economy.cash', document.economy.cash)
    SKSaves.write(source, 'garage.vehicles.' .. vehicleId .. '.data', entry.data)
    SKStats.increment(source, 'totalCashSpent', price)

    return { ok = true, balance = document.economy.cash, price = price }
end)