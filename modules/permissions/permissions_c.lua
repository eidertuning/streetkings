SKPermissionsClient = {
    data = nil,
    nametagSettings = {
        hideOwnNametag = false,
        showOtherNametags = true,
    },
}

local function updateNametagSettings(settings)
    if type(settings) ~= 'table' then return end
    if settings.hideOwnNametag ~= nil then
        SKPermissionsClient.nametagSettings.hideOwnNametag = settings.hideOwnNametag == true
    end
    if settings.showOtherNametags ~= nil then
        SKPermissionsClient.nametagSettings.showOtherNametags = settings.showOtherNametags ~= false
    end
end

RegisterNetEvent('sk_permissions:client:updated', function(data)
    SKPermissionsClient.data = type(data) == 'table' and data or nil
    if data and data.nametagSettings then
        updateNametagSettings(data.nametagSettings)
    end
end)

RegisterNetEvent('sk_staff:client:updated', function(staff)
    if not SKPermissionsClient.data then SKPermissionsClient.data = {} end
    SKPermissionsClient.data.staff = staff
end)

RegisterNetEvent('sk_vip:client:updated', function(vip)
    if not SKPermissionsClient.data then SKPermissionsClient.data = {} end
    SKPermissionsClient.data.vip = vip
end)

RegisterNetEvent('sk_racing:client:updated', function(racing)
    if not SKPermissionsClient.data then SKPermissionsClient.data = {} end
    SKPermissionsClient.data.racing = racing
end)

RegisterNetEvent('sk_nametag:client:settingsUpdated', updateNametagSettings)

local function permissions()
    return SKPermissionsClient.data and SKPermissionsClient.data.permissions or {}
end

local function hasPermission(permission)
    permission = tostring(permission or '')
    if permission == '' then return false end
    local perms = permissions()
    if perms[permission] or perms['owner'] or perms['admin.all'] then return true end
    local prefix = permission:match('^([^%.]+)%.')
    return prefix and perms[prefix .. '.all'] == true or false
end

exports('GetCachedPlayerPermissions', function()
    return permissions()
end)

exports('HasCachedPermission', function(permission)
    return hasPermission(permission)
end)

exports('GetCachedVip', function()
    return SKPermissionsClient.data and SKPermissionsClient.data.vip or { enabled = false, level = 0, permissions = {} }
end)

exports('HasCachedVip', function()
    local vip = SKPermissionsClient.data and SKPermissionsClient.data.vip
    return vip and vip.enabled == true or false
end)

exports('GetCachedNametagSettings', function()
    return SKPermissionsClient.nametagSettings
end)

exports('SetHideOwnNametag', function(state)
    SKPermissionsClient.nametagSettings.hideOwnNametag = state == true
    TriggerServerEvent('sk_permissions:server:setNametagSettings', {
        hideOwnNametag = SKPermissionsClient.nametagSettings.hideOwnNametag,
    })
    return true
end)

exports('SetShowOtherNametags', function(state)
    SKPermissionsClient.nametagSettings.showOtherNametags = state ~= false
    TriggerServerEvent('sk_permissions:server:setNametagSettings', {
        showOtherNametags = SKPermissionsClient.nametagSettings.showOtherNametags,
    })
    return true
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('sk_permissions:server:requestRefresh')
end)
