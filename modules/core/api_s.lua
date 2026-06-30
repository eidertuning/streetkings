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

local function permissionApi()
    return SKPermissions
end

exports('GetStreetKingsRoleData', function(source)
    local api = permissionApi()
    return api and api.GetPlayerRoleData and api.GetPlayerRoleData(source) or nil
end)

exports('HasAdminPermission', function(source, permission)
    local api = permissionApi()
    if not api or not api.HasPermission then return false end
    return api.HasPermission(source, permission or 'admin.menu')
end)

exports('IsVip', function(source)
    local api = permissionApi()
    return api and api.HasVip and api.HasVip(source) or false
end)

exports('IsStaffMember', function(source)
    local api = permissionApi()
    return api and api.IsStaff and api.IsStaff(source) or false
end)

exports('CanAccessVipShop', function(source)
    local api = permissionApi()
    return api and api.CanUseVipShop and api.CanUseVipShop(source) or false
end)

exports('CanAccessVipVehicleShop', function(source)
    local api = permissionApi()
    return api and api.CanUseVipVehicleShop and api.CanUseVipVehicleShop(source) or false
end)

exports('CanUseVipWorkshop', function(source)
    local api = permissionApi()
    return api and api.CanUseVipWorkshop and api.CanUseVipWorkshop(source) or false
end)

exports('CanUseVipTuning', function(source)
    local api = permissionApi()
    return api and api.CanUseVipTuning and api.CanUseVipTuning(source) or false
end)

exports('CanUseVipRepairDiscount', function(source)
    local api = permissionApi()
    return api and api.CanUseVipRepairDiscount and api.CanUseVipRepairDiscount(source) or false
end)

exports('CanUseVipCosmetics', function(source)
    local api = permissionApi()
    return api and api.CanUseVipCosmetics and api.CanUseVipCosmetics(source) or false
end)
