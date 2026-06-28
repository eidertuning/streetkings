local function copyArray(values)
    local out = {}
    for i = 1, #values do
        out[i] = values[i]
    end
    return out
end

exports('GetAllVehicleData', function()
    return SKVehicles or {}
end)

exports('GetVehicleData', function(model)
    if type(model) ~= 'string' then return nil end
    return SKVehicles and SKVehicles[model:lower()] or nil
end)

exports('GetOnlinePlayers', function()
    local players = {}
    for _, source in ipairs(GetPlayers()) do
        local src = tonumber(source)
        if src then
            players[#players + 1] = src
        end
    end
    return players
end)

exports('GetPlayersWithActiveSaves', function()
    local players = {}
    for _, source in ipairs(GetPlayers()) do
        local src = tonumber(source)
        if src and SKSaves and SKSaves.hasActiveSave and SKSaves.hasActiveSave(src) then
            players[#players + 1] = src
        end
    end
    return players
end)

exports('GetValidGameStates', function()
    if type(GameState) ~= 'table' then return {} end
    local values = {}
    for _, state in pairs(GameState) do
        values[#values + 1] = state
    end
    table.sort(values)
    return copyArray(values)
end)
