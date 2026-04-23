local CLASS_UNLOCK_LEVELS = {
    C = 1,
    B = 10,
    A = 20,
    S = 30,
}

local RANDOM_COLORS = {
    { r = 220, g = 30,  b = 30  },  -- red
    { r = 220, g = 100, b = 20  },  -- orange
    { r = 210, g = 190, b = 20  },  -- yellow
    { r = 30,  g = 180, b = 50  },  -- green
    { r = 20,  g = 120, b = 220 },  -- blue
    { r = 100, g = 30,  b = 220 },  -- purple
    { r = 210, g = 30,  b = 140 },  -- pink
    { r = 220, g = 220, b = 220 },  -- white
    { r = 25,  g = 25,  b = 25  },  -- black
    { r = 120, g = 120, b = 120 },  -- silver
    { r = 180, g = 140, b = 60  },  -- gold
    { r = 30,  g = 180, b = 180 },  -- teal
}

---@return table
local function randomColor()
    return RANDOM_COLORS[math.random(#RANDOM_COLORS)]
end

---@param class string
---@return integer
local function getClassUnlockLevel(class)
    return assert(CLASS_UNLOCK_LEVELS[class], ('streetkings: missing dealership class unlock level for %s'):format(class))
end

---@param vehicles table<string, table>
---@return table<string, boolean>
local function buildOwnedModels(vehicles)
    local ownedModels = {}
    for _, entry in pairs(vehicles) do
        ownedModels[entry.modelName] = true
    end
    return ownedModels
end

lib.callback.register('streetkings:dealership:getState', function(source)
    local document = SKSaves.getDocument(source)
    return {
        balance = document.economy.cash,
        playerLevel = document.progression.level,
        ownedModels = buildOwnedModels(document.garage.vehicles),
    }
end)

lib.callback.register('streetkings:dealership:loadDiscovered', function(source)
    local world = SKSaves.read(source, 'world.state')
    return world.discoveredDealerships or {}
end)

lib.callback.register('streetkings:dealership:discover', function(source, dealerId)
    local world = SKSaves.read(source, 'world.state')
    local list  = world.discoveredDealerships or {}
    for _, id in ipairs(list) do
        if id == dealerId then return { ok = true } end
    end
    list[#list + 1]           = dealerId
    world.discoveredDealerships = list
    SKSaves.write(source, 'world.state', world)
    return { ok = true }
end)

lib.callback.register('streetkings:dealership:purchase', function(source, model, _, price)
    local serverVehicle = nil
    for _, vehicles in pairs(SKGameVehicles) do
        for _, v in ipairs(vehicles) do
            if v.model == model then
                serverVehicle = v
                break
            end
        end
        if serverVehicle then break end
    end

    if not serverVehicle or serverVehicle.price ~= price then
        return { ok = false, reason = 'invalid_vehicle' }
    end

    local sharedVehicle = assert(SKVehicles[model], ('streetkings: missing shared vehicle metadata for %s'):format(model))

    local document = SKSaves.getDocument(source)
    local cash     = document.economy.cash
    local playerLevel = document.progression.level

    if playerLevel < getClassUnlockLevel(serverVehicle.class) then
        return { ok = false, reason = 'class_locked', requiredLevel = getClassUnlockLevel(serverVehicle.class) }
    end

    if cash < price then
        return { ok = false, reason = 'insufficient_funds' }
    end

    for _, entry in pairs(document.garage.vehicles) do
        if entry.modelName == model then
            return { ok = false, reason = 'already_owned' }
        end
    end

    local vehicleId = lib.string.random('........^-....^-....^-....^-............')
    local vehicleCount = 0
    for _ in pairs(document.garage.vehicles) do
        vehicleCount = vehicleCount + 1
    end
    local sortIndex = vehicleCount

    local vehicleData = SKProgression.newVehicleData('automobile')
    vehicleData.colors.primary   = randomColor()
    vehicleData.colors.secondary = randomColor()

    document.garage.vehicles[vehicleId] = {
        id          = vehicleId,
        modelName   = model,
        displayName = sharedVehicle.name,
        sortIndex   = sortIndex,
        plate       = SKVehiclePlate.generate(),
        data        = vehicleData,
    }

    document.economy.cash = cash - price

    SKSaves.write(source, 'garage.vehicles.' .. vehicleId, document.garage.vehicles[vehicleId])
    SKSaves.write(source, 'economy.cash', document.economy.cash)
    SKStats.increment(source, 'totalCashSpent', price)
    TriggerEvent('streetkings:messages:trigger', source, 'vehicleAcquired', {
        acquisitionSource = 'dealership',
        vehicleId = vehicleId,
        modelName = model,
        isFirstVehicle = vehicleCount == 0,
    })

    return { ok = true, balance = document.economy.cash, vehicleId = vehicleId }
end)