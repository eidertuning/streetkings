---@param source integer
---@return boolean
local function playerHasDebugTools(source)
    return IsPlayerAceAllowed(source, 'command') == 1
end

lib.callback.register('phone:settings:isAdmin', function(source)
    return playerHasDebugTools(source)
end)

lib.callback.register('phone:settings:hasPermission', function(source)
    return playerHasDebugTools(source)
end)

lib.callback.register('phone:settings:deleteSave', function(source)
    if not playerHasDebugTools(source) then
        return { ok = false }
    end

    local saveId = SKSaves.getActiveSaveId(source)
    if not saveId then
        return { ok = false }
    end

    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    MySQL.update.await(
        'DELETE FROM player_saves WHERE owner_identifier = ? AND id = ?',
        { license, saveId }
    )
    SKSaves.clearActive(source)

    return { ok = true }
end)

lib.callback.register('phone:settings:getLevelBounds', function(source)
    if not playerHasDebugTools(source) then
        return { ok = false }
    end

    return {
        ok = true,
        vehicleMaxLevel = SKProgression.VEHICLE_MAX_LEVEL,
        playerMaxLevel = SKProgression.PLAYER_MAX_LEVEL,
    }
end)

lib.callback.register('phone:settings:setVehicleLevel', function(source, level)
    if not playerHasDebugTools(source) then
        return { ok = false }
    end

    return { ok = SKProgression.setVehicleLevel(source, level) }
end)

lib.callback.register('phone:settings:setPlayerLevel', function(source, level)
    if not playerHasDebugTools(source) then
        return { ok = false }
    end

    return { ok = SKProgression.setPlayerLevel(source, level) }
end)

lib.callback.register('phone:settings:grantCosmeticCurrency', function(source)
    if not playerHasDebugTools(source) then
        return { ok = false }
    end

    local awardedAmount, balance = SKAvatar.addCosmeticCurrency(source, 1000)
    return {
        ok = true,
        amount = awardedAmount,
        balance = balance,
    }
end)