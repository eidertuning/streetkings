local BUILTIN_APP_IDS = {
    Event = true,
    event = true,
    Mission = true,
    mission = true,
    Messages = true,
    messages = true,
    Map = true,
    map = true,
    Vehicles = true,
    vehicles = true,
    Stats = true,
    stats = true,
    RealEstate = true,
    realestate = true,
    Store = true,
    store = true,
    Towing = true,
    towing = true,
    Settings = true,
    settings = true,
    Leaderboards = true,
    leaderboards = true,
    External = true,
    external = true,
}

local externalApps = {}

local function cloneApp(app)
    local copy = {}
    for key, value in pairs(app) do
        copy[key] = value
    end
    return copy
end

local function normalizeApp(def, owner)
    if type(def) ~= 'table' then return nil, 'invalid_app' end

    local id = tostring(def.id or ''):lower()
    if id == '' or #id > 32 or not id:match('^[a-z0-9_]+$') then
        return nil, 'invalid_id'
    end
    if BUILTIN_APP_IDS[id] or BUILTIN_APP_IDS[def.id] then
        return nil, 'reserved_id'
    end

    local label = tostring(def.label or ''):sub(1, 48)
    local ui = tostring(def.ui or ''):gsub('^/+', '')
    if label == '' then return nil, 'missing_label' end
    if ui == '' then return nil, 'missing_ui' end

    return {
        id = id,
        label = label,
        icon = tostring(def.icon or 'fa-star'):sub(1, 64),
        glyph = tostring(def.glyph or ''):sub(1, 4),
        color = tostring(def.color or '#ff006a'):sub(1, 96),
        category = tostring(def.category or 'default'):sub(1, 24),
        ui = ui,
        description = tostring(def.description or ''):sub(1, 240),
        version = tostring(def.version or ''):sub(1, 32),
        developer = tostring(def.developer or owner or ''):sub(1, 64),
        resource = owner,
    }
end

local function syncApp(app)
    SendNUIMessage({
        type = 'phone:externalApps:set',
        app = cloneApp(app),
    })
end

local function removeApp(appId)
    SendNUIMessage({
        type = 'phone:externalApps:remove',
        appId = appId,
    })
end

local function registerTabletApp(def)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local app, reason = normalizeApp(def, owner)
    if not app then return false, reason end

    local existing = externalApps[app.id]
    if existing and existing.resource ~= owner then
        return false, 'already_registered'
    end

    externalApps[app.id] = app
    syncApp(app)
    return true
end

local function unregisterTabletApp(appId)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    appId = tostring(appId or ''):lower()
    local app = externalApps[appId]
    if not app then return false, 'not_found' end
    if app.resource ~= owner then return false, 'not_owner' end

    externalApps[appId] = nil
    removeApp(appId)
    return true
end

local function sendTabletAppMessage(appId, eventName, data)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    appId = tostring(appId or ''):lower()
    local app = externalApps[appId]
    if not app then return false, 'not_found' end
    if app.resource ~= owner then return false, 'not_owner' end

    SendNUIMessage({
        type = 'phone:externalApp:message',
        appId = appId,
        event = tostring(eventName or ''),
        data = data or {},
    })
    return true
end

local function openTabletApp(appId, appData)
    appId = tostring(appId or ''):lower()
    if not externalApps[appId] then return false, 'not_found' end
    SKPhone.open({
        appId = appId,
        appData = appData or {},
    })
    return true
end

RegisterNetEvent('streetkings:phone:externalApps:set', function(app)
    if type(app) ~= 'table' or type(app.id) ~= 'string' then return end
    externalApps[app.id] = app
    syncApp(app)
end)

RegisterNetEvent('streetkings:phone:externalApps:remove', function(appId)
    appId = tostring(appId or ''):lower()
    externalApps[appId] = nil
    removeApp(appId)
end)

RegisterNetEvent('streetkings:phone:externalApps:sync', function(apps)
    externalApps = {}
    local payload = {}
    if type(apps) == 'table' then
        for _, app in ipairs(apps) do
            if type(app) == 'table' and type(app.id) == 'string' then
                externalApps[app.id] = app
                payload[#payload + 1] = cloneApp(app)
            end
        end
    end
    SendNUIMessage({
        type = 'phone:externalApps:sync',
        apps = payload,
    })
end)

RegisterNetEvent('streetkings:phone:externalApp:message', function(appId, eventName, data)
    appId = tostring(appId or ''):lower()
    if not externalApps[appId] then return end
    SendNUIMessage({
        type = 'phone:externalApp:message',
        appId = appId,
        event = tostring(eventName or ''),
        data = data or {},
    })
end)

RegisterNetEvent('streetkings:phone:externalApp:open', function(appId, appData)
    openTabletApp(appId, appData)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerServerEvent('streetkings:phone:externalApps:requestSync')
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    local removed = {}
    for appId, app in pairs(externalApps) do
        if app.resource == resourceName then
            removed[#removed + 1] = appId
        end
    end
    for _, appId in ipairs(removed) do
        externalApps[appId] = nil
        removeApp(appId)
    end
end)

exports('RegisterTabletApp', registerTabletApp)
exports('registerTabletApp', registerTabletApp)
exports('registerApp', registerTabletApp)
exports('UnregisterTabletApp', unregisterTabletApp)
exports('unregisterTabletApp', unregisterTabletApp)
exports('unregisterApp', unregisterTabletApp)
exports('SendTabletAppMessage', sendTabletAppMessage)
exports('sendTabletAppMessage', sendTabletAppMessage)
exports('sendAppMessage', sendTabletAppMessage)
exports('OpenTabletApp', openTabletApp)
exports('openTabletApp', openTabletApp)
