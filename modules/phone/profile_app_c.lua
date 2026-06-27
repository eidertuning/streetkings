local PROFILE_APP = {
    id = 'profile',
    label = 'Perfil',
    icon = 'fa-user',
    glyph = 'P',
    color = '#14b8a6',
    category = 'system',
    ui = 'html/apps/profile/index.html',
    description = 'Demo app for the StreetKings tablet external app SDK.',
    version = '1.0.0',
    developer = 'StreetKings',
}

local function registerProfileApp()
    exports[GetCurrentResourceName()]:RegisterTabletApp(PROFILE_APP)
end

local function cleanAlias(value)
    value = tostring(value or ''):gsub('[\r\n\t]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, 32)
end

RegisterNUICallback('skProfileGet', function(_, cb)
    local result = lib.callback.await('streetkings:profileApp:getProfile', false)
    cb(result or { ok = false, error = 'profile_unavailable' })
end)

RegisterNUICallback('skProfileSave', function(data, cb)
    local result = lib.callback.await('streetkings:profileApp:saveProfile', false, {
        alias = cleanAlias(data and data.alias),
    })
    cb(result or { ok = false, error = 'profile_save_failed' })
end)

RegisterNUICallback('skProfilePing', function(data, cb)
    cb({
        ok = true,
        echo = data or {},
        receivedAt = GetGameTimer(),
    })
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        registerProfileApp()
    end
end)

CreateThread(function()
    Wait(750)
    registerProfileApp()
end)
