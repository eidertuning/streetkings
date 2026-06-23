SKProgression = SKProgression or {}

---@param vehicle integer
---@return table[]
function SKProgression.collectVehicleAvailability(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return {}
    end

    SetVehicleModKit(vehicle, 0)

    local availableMods = {}
    for modType = 0, 49 do
        local count = SKShopShared.getVehicleModOptionCount(vehicle, modType)
        if count > 0 then
            local options = {}

            for modIndex = 0, count - 1 do
                local name = SKProgression.MOD_TYPE_NAMES[modType]
                if not SKShopShared.isToggleModType(modType) then
                    local labelKey = GetModTextLabel(vehicle, modType, modIndex)
                    name = GetLabelText(labelKey)
                end
                if not name or name == 'NULL' or name == '' then
                    name = (SKProgression.MOD_TYPE_NAMES[modType] or 'Mod') .. ' ' .. (modIndex + 1)
                end

                options[#options + 1] = {
                    index = modIndex,
                    name = name,
                    key = SKProgression.getModOptionKey(modType, modIndex),
                }
            end

            availableMods[#availableMods + 1] = {
                modType = modType,
                name = SKProgression.MOD_TYPE_NAMES[modType] or ('Mod ' .. modType),
                options = options,
            }
        end
    end

    availableMods[#availableMods + 1] = {
        modType = SKShopShared.NEON_UNLOCK_MOD_TYPE,
        name = SKProgression.MOD_TYPE_NAMES[SKShopShared.NEON_UNLOCK_MOD_TYPE],
        options = {
            {
                index = SKShopShared.NEON_UNLOCK_MOD_INDEX,
                name = 'Neon Kit',
                key = SKProgression.getModOptionKey(SKShopShared.NEON_UNLOCK_MOD_TYPE, SKShopShared.NEON_UNLOCK_MOD_INDEX),
            },
        },
    }
    availableMods[#availableMods + 1] = {
        modType = SKShopShared.NITROUS_UNLOCK_MOD_TYPE,
        name = SKProgression.MOD_TYPE_NAMES[SKShopShared.NITROUS_UNLOCK_MOD_TYPE],
        options = {
            {
                index = SKShopShared.NITROUS_UNLOCKS.street.index,
                name = 'Street Nitrous',
                unlockLevel = SKShopShared.NITROUS_UNLOCKS.street.level,
            },
            {
                index = SKShopShared.NITROUS_UNLOCKS.sport.index,
                name = 'Sport Nitrous',
                unlockLevel = SKShopShared.NITROUS_UNLOCKS.sport.level,
            },
            {
                index = SKShopShared.NITROUS_UNLOCKS.race.index,
                name = 'Race Nitrous',
                unlockLevel = SKShopShared.NITROUS_UNLOCKS.race.level,
            },
        },
    }

    return availableMods
end

---@param payload { unlocks: table[], newLevel: integer }
local function showVehicleUnlocks(payload)
    if not payload or not payload.unlocks or #payload.unlocks == 0 then
        return
    end

    local groups = {}

    for _, unlock in ipairs(payload.unlocks) do
        local group = groups[unlock.modName]
        if not group then
            group = {
                count = 0,
                optionName = unlock.optionName,
            }
            groups[unlock.modName] = group
        end

        group.count = group.count + 1
    end

    local titles = {}
    for modName, group in pairs(groups) do
        titles[#titles + 1] = group.count > 1
            and (modName .. ' (' .. tostring(group.count) .. ' options)')
            or (modName .. ': ' .. group.optionName)
    end

    table.sort(titles, function(a, b)
        return a < b
    end)

    local summary = {}
    for index, title in ipairs(titles) do
        if index > 4 then
            summary[#summary + 1] = '+' .. tostring(#titles - 4) .. ' more'
            break
        end

        summary[#summary + 1] = title
    end

    SKNotify({
        type = 'success',
        title = 'Vehicle Lv. ' .. payload.newLevel .. ' Unlocks: ' .. table.concat(summary, ', '),
        duration = 5000,
    })
end

exports('GetVehicleAvailability', SKProgression.collectVehicleAvailability)

RegisterNetEvent('streetkings:progression:vehicleUnlocks', function(payload)
    showVehicleUnlocks(payload)
end)

RegisterNetEvent('streetkings:progression:playerLevelUp', function(payload)
    if not payload or not payload.levelUps or #payload.levelUps == 0 then
        return
    end

    local lastLevel = payload.levelUps[#payload.levelUps]
    SKNotify({
        type = 'success',
        title = 'Player Level Up: Lv. ' .. tostring(lastLevel),
        duration = 3500,
    })
end)