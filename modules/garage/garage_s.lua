local TOW_TO_GARAGE_PRICE = 200
local DEFAULT_GARAGE_TINT = 'gray'

---@param entry table
---@return table
local function buildGarageVehicleDto(entry)
    local vehicleData = SKProgression.ensureVehicleData(entry.data)
    local currentLevelXp = SKProgression.VEHICLE_LEVEL_THRESHOLDS[vehicleData.level] or 0
    local nextLevelXp = SKProgression.getXpForNextLevel(
        vehicleData.level,
        SKProgression.VEHICLE_LEVEL_THRESHOLDS,
        SKProgression.VEHICLE_MAX_LEVEL
    )

    return {
        id = entry.id,
        modelName = entry.modelName,
        displayName = entry.displayName,
        sortIndex = entry.sortIndex,
        plate = entry.plate,
        data = vehicleData,
        progression = {
            level = vehicleData.level,
            xp = vehicleData.xp,
            currentLevelXp = currentLevelXp,
            nextLevelXp = nextLevelXp,
            maxLevel = SKProgression.VEHICLE_MAX_LEVEL,
        },
    }
end

---@param unlockSchedule table[]
---@return table<string, integer>
local function buildUnlockLevels(unlockSchedule)
    local unlockLevels = {}

    for _, unlock in ipairs(unlockSchedule) do
        unlockLevels[unlock.key] = unlock.level
    end

    return unlockLevels
end

---@param vehicleData table
---@param mod table
---@return string
local function getCurrentOptionName(vehicleData, mod)
    local currentIndex = vehicleData.mods[tostring(mod.modType)]
    if type(currentIndex) ~= 'number' or currentIndex < 0 then
        return 'Stock'
    end

    for _, option in ipairs(mod.options) do
        if option.index == currentIndex then
            return option.name
        end
    end

    return 'Custom'
end

---@param vehicleData table
---@param unlockLevels table<string, integer>
---@param performanceOnly boolean
---@return table[], integer, integer
local function buildPartGroups(vehicleData, unlockLevels, performanceOnly)
    local groups = {}
    local unlockedCount = 0
    local totalCount = 0

    for _, mod in ipairs(vehicleData.availableMods) do
        if not SKShopShared.isExcludedModType(mod.modType) and SKShopShared.isPerformanceModType(mod.modType) == performanceOnly then
            local unlockedOptions = {}
            local nextUnlock = nil

            for _, option in ipairs(mod.options) do
                totalCount = totalCount + 1

                if vehicleData.unlocks[option.key] then
                    unlockedCount = unlockedCount + 1
                    unlockedOptions[#unlockedOptions + 1] = option.name
                else
                    local unlockLevel = unlockLevels[option.key]
                    local optionName = option.name
                    if SKProgression.isWheelModType(mod.modType) then
                        local packIndex = SKProgression.getWheelPackIndex(option.index + 1, #mod.options)
                        optionName = SKProgression.getWheelPackName(packIndex)
                    end

                    if unlockLevel and (not nextUnlock or unlockLevel < nextUnlock.level) then
                        nextUnlock = {
                            level = unlockLevel,
                            optionName = optionName,
                        }
                    end
                end
            end

            groups[#groups + 1] = {
                modType = mod.modType,
                modName = mod.name,
                currentOptionName = getCurrentOptionName(vehicleData, mod),
                unlockedCount = #unlockedOptions,
                totalCount = #mod.options,
                unlockedOptions = unlockedOptions,
                nextUnlock = nextUnlock,
            }
        end
    end

    return groups, unlockedCount, totalCount
end

---@param vehicleData table
---@param performanceOnly boolean
---@return table[]
local function buildFutureUnlocks(vehicleData, performanceOnly)
    local futureUnlocks = {}

    for _, unlock in ipairs(vehicleData.unlockSchedule) do
        if unlock.level > vehicleData.level and not SKShopShared.isExcludedModType(unlock.modType) and SKShopShared.isPerformanceModType(unlock.modType) == performanceOnly then
            local groupKey = unlock.packIndex and unlock.modName or (unlock.modName .. ':' .. unlock.optionName)
            local group = futureUnlocks[groupKey]
            if not group then
                group = {
                    level = unlock.level,
                    modName = unlock.modName,
                    optionName = unlock.optionName,
                    count = 0,
                }
                futureUnlocks[groupKey] = group
            end

            group.count = group.count + 1
            if group.count > 1 then
                group.optionName = tostring(group.count) .. ' wheel styles'
            end
        end
    end

    local list = {}
    for _, unlock in pairs(futureUnlocks) do
        list[#list + 1] = {
            level = unlock.level,
            modName = unlock.modName,
            optionName = unlock.optionName,
        }
    end

    table.sort(list, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        if a.modName ~= b.modName then
            return a.modName < b.modName
        end
        return a.optionName < b.optionName
    end)

    while #list > 10 do
        table.remove(list)
    end

    return list
end

---@param bestActivityScores table<string, integer>
---@return table[]
local function buildEventResults(bestActivityScores)
    local eventResults = {}

    for eventId, score in pairs(bestActivityScores) do
        local event = SKEvents[eventId]
        if event then
            eventResults[#eventResults + 1] = {
                id = eventId,
                name = event.name,
                score = score,
                goalTime = event.goalTime,
                passed = event.goalTime and score <= (event.goalTime * 1000) or nil,
            }
        end
    end

    table.sort(eventResults, function(a, b)
        return a.name < b.name
    end)

    return eventResults
end

---@param source integer
---@param document SKSaveDocument
---@return string
local function resolveActiveVehicleId(source, document)
    local activeVehicleId = document.garage.activeVehicleId
    if activeVehicleId ~= '' and document.garage.vehicles[activeVehicleId] then
        return activeVehicleId
    end

    local resolvedId = ''
    local resolvedEntry = nil
    for vehicleId, entry in pairs(document.garage.vehicles) do
        if not resolvedEntry
            or entry.sortIndex < resolvedEntry.sortIndex
            or (entry.sortIndex == resolvedEntry.sortIndex and entry.displayName < resolvedEntry.displayName)
        then
            resolvedId = vehicleId
            resolvedEntry = entry
        end
    end

    if resolvedId ~= '' and document.garage.activeVehicleId ~= resolvedId then
        document.garage.activeVehicleId = resolvedId
        SKSaves.write(source, 'garage.activeVehicleId', resolvedId)
    end

    return resolvedId
end

---@param entry table
---@param activeVehicleId string
---@return table
local function buildPhoneVehicleDto(entry, activeVehicleId)
    local dto = buildGarageVehicleDto(entry)
    local unlockLevels = buildUnlockLevels(dto.data.unlockSchedule)
    local visualCategories, visualUnlockedCount, visualTotalCount = buildPartGroups(dto.data, unlockLevels, false)
    local performanceCategories, performanceUnlockedCount, performanceTotalCount = buildPartGroups(dto.data, unlockLevels, true)

    return {
        id = dto.id,
        modelName = dto.modelName,
        displayName = dto.displayName,
        sortIndex = dto.sortIndex,
        isActive = dto.id == activeVehicleId,
        progression = dto.progression,
        visualParts = {
            categories = visualCategories,
            unlockedCount = visualUnlockedCount,
            totalCount = visualTotalCount,
        },
        performanceParts = {
            categories = performanceCategories,
            unlockedCount = performanceUnlockedCount,
            totalCount = performanceTotalCount,
        },
        futureVisualUnlocks = buildFutureUnlocks(dto.data, false),
        futurePerformanceUnlocks = buildFutureUnlocks(dto.data, true),
        eventResults = buildEventResults(dto.data.bestActivityScores),
    }
end

lib.callback.register('streetkings:garage:getEnterData', function(source)
    local document = SKSaves.getDocument(source)
    if not document then
        return { ok = false, error = 'no_active_document' }
    end
    local world    = document.world.state
    local vehicles = {}
    local activeVehicleId = resolveActiveVehicleId(source, document)
    local playerLevel = document.progression.level
    local playerXp = document.progression.playerXp
    local playerCurrentLevelXp = SKProgression.PLAYER_LEVEL_THRESHOLDS[playerLevel] or 0
    local playerNextLevelXp = SKProgression.getXpForNextLevel(
        playerLevel,
        SKProgression.PLAYER_LEVEL_THRESHOLDS,
        SKProgression.PLAYER_MAX_LEVEL
    )

    for vehicleId, entry in pairs(document.garage.vehicles) do
        vehicles[vehicleId] = buildGarageVehicleDto(entry)
    end

    return {
        vehicles = vehicles,
        activeVehicleId = activeVehicleId,
        balance = document.economy.cash,
        lastGarageId = world.lastGarageId,
        garageTint = world.garageTint or DEFAULT_GARAGE_TINT,
        playerLevel = playerLevel,
        playerXp = playerXp,
        playerCurrentLevelXp = playerCurrentLevelXp,
        playerNextLevelXp = playerNextLevelXp,
        playerMaxLevel = SKProgression.PLAYER_MAX_LEVEL,
    }
end)

lib.callback.register('streetkings:garage:getPhoneOverview', function(source)
    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active garage document')
    local vehicles = {}
    local activeVehicleId = document.garage.activeVehicleId

    for _, entry in pairs(document.garage.vehicles) do
        vehicles[#vehicles + 1] = buildPhoneVehicleDto(entry, activeVehicleId)
    end

    table.sort(vehicles, function(a, b)
        if a.id == activeVehicleId then
            return true
        end
        if b.id == activeVehicleId then
            return false
        end
        if a.sortIndex ~= b.sortIndex then
            return a.sortIndex < b.sortIndex
        end
        return a.displayName < b.displayName
    end)

    return {
        vehicles = vehicles,
        activeVehicleId = activeVehicleId,
    }
end)

lib.callback.register('streetkings:garage:setActiveVehicle', function(source, vehicleId)
    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active garage document')
    if not document.garage.vehicles[vehicleId] then
        return { ok = false, reason = 'not_found' }
    end
    document.garage.activeVehicleId = vehicleId
    SKSaves.write(source, 'garage.activeVehicleId', vehicleId)
    return { ok = true }
end)

lib.callback.register('streetkings:garage:requestTowToLastGarage', function(source, fallbackGarageId)
    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active garage document')
    local garageId = document.world.state.lastGarageId
    local cash     = document.economy.cash

    if type(garageId) ~= 'string' or garageId == '' then
        garageId = fallbackGarageId
    end

    if cash < TOW_TO_GARAGE_PRICE then
        return {
            ok = false,
            reason = 'insufficient_funds',
            balance = cash,
            price = TOW_TO_GARAGE_PRICE,
        }
    end

    document.economy.cash = cash - TOW_TO_GARAGE_PRICE
    SKSaves.write(source, 'economy.cash', document.economy.cash)
    SKStats.increment(source, 'totalCashSpent', TOW_TO_GARAGE_PRICE)

    return {
        ok = true,
        garageId = garageId,
        balance = document.economy.cash,
        price = TOW_TO_GARAGE_PRICE,
    }
end)

lib.callback.register('streetkings:garage:recordVisit', function(source, garageId)
    local document  = assert(SKSaves.getDocument(source), 'streetkings: missing active garage document')
    local world     = document.world.state
    local list      = world.discoveredGarages or {}
    local found     = false
    for _, id in ipairs(list) do
        if id == garageId then found = true; break end
    end
    if not found then
        list[#list + 1] = garageId
    end
    world.discoveredGarages = list
    world.lastGarageId      = garageId
    SKSaves.write(source, 'world.state', world)
    return { ok = true }
end)

lib.callback.register('streetkings:garage:setTint', function(source, tintKey)
    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active garage document')
    local world = document.world.state

    world.garageTint = tintKey
    SKSaves.write(source, 'world.state', world)

    return { ok = true, garageTint = tintKey }
end)

lib.callback.register('streetkings:garage:loadDiscovered', function(source)
    local world = SKSaves.read(source, 'world.state')
    return world.discoveredGarages or {}
end)

exports('GetActiveVehicle', function(source)
    local doc = SKSaves.getDocument(source)
    if not doc or not doc.garage then return nil end
    local activeId = doc.garage.activeVehicleId
    if not activeId then return nil end
    return doc.garage.vehicles and doc.garage.vehicles[activeId] or nil
end)
exports('GetOwnedVehicles', function(source)
    local doc = SKSaves.getDocument(source)
    if not doc or not doc.garage then return {} end
    return doc.garage.vehicles or {}
end)