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
    if SKLogs then
        SKLogs.Module('settings', 'delete_active_save', {
            source = source,
            title = 'Save eliminado desde ajustes',
            publicMessage = 'Un administrador elimino un save.',
            details = ('saveId=%s\nlicense=%s'):format(saveId, license),
        }, 'admin')
    end

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

    local ok = SKProgression.setVehicleLevel(source, level)
    if ok and SKLogs then
        SKLogs.Module('settings', 'set_vehicle_level', {
            source = source,
            title = 'Nivel de vehiculo ajustado',
            publicMessage = 'Un administrador cambio el nivel de un vehiculo.',
            details = ('level=%s'):format(level),
        }, 'admin')
    end
    return { ok = ok }
end)

lib.callback.register('phone:settings:setPlayerLevel', function(source, level)
    if not playerHasDebugTools(source) then
        return { ok = false }
    end

    local ok = SKProgression.setPlayerLevel(source, level)
    if ok and SKLogs then
        SKLogs.Module('settings', 'set_player_level', {
            source = source,
            title = 'Nivel de jugador ajustado',
            publicMessage = 'Un administrador cambio el nivel de un jugador.',
            details = ('level=%s'):format(level),
        }, 'admin')
    end
    return { ok = ok }
end)

lib.callback.register('phone:settings:grantCosmeticCurrency', function(source)
    if not playerHasDebugTools(source) then
        return { ok = false }
    end

    local awardedAmount, balance = SKAvatar.addCosmeticCurrency(source, 1000)
    if SKLogs then
        SKLogs.Module('settings', 'grant_cosmetic_currency', {
            source = source,
            title = 'Moneda cosmetica otorgada',
            publicMessage = 'Un administrador otorgo moneda cosmetica.',
            details = ('amount=%s\nbalance=%s'):format(awardedAmount, balance),
        }, 'admin')
    end
    return {
        ok = true,
        amount = awardedAmount,
        balance = balance,
    }
end)
