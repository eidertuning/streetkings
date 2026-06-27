local BUILTIN_APP_IDS = {
    event = true,
    mission = true,
    messages = true,
    map = true,
    vehicles = true,
    stats = true,
    realestate = true,
    store = true,
    towing = true,
    settings = true,
    leaderboards = true,
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

local function appList()
    local list = {}
    for _, app in pairs(externalApps) do
        list[#list + 1] = cloneApp(app)
    end
    table.sort(list, function(a, b)
        return tostring(a.label or a.id) < tostring(b.label or b.id)
    end)
    return list
end

local function normalizeApp(def, owner)
    if type(def) ~= 'table' then return nil, 'invalid_app' end

    local id = tostring(def.id or ''):lower()
    if id == '' or #id > 32 or not id:match('^[a-z0-9_]+$') then
        return nil, 'invalid_id'
    end
    if BUILTIN_APP_IDS[id] then
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
        color = tostring(def.color or '#ff006a'):sub(1, 96),
        category = tostring(def.category or 'default'):sub(1, 24),
        ui = ui,
        description = tostring(def.description or ''):sub(1, 240),
        version = tostring(def.version or ''):sub(1, 32),
        developer = tostring(def.developer or owner or ''):sub(1, 64),
        resource = owner,
    }
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
    TriggerClientEvent('streetkings:phone:externalApps:set', -1, cloneApp(app))
    return true
end

local function unregisterTabletApp(appId)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    appId = tostring(appId or ''):lower()
    local app = externalApps[appId]
    if not app then return false, 'not_found' end
    if app.resource ~= owner then return false, 'not_owner' end

    externalApps[appId] = nil
    TriggerClientEvent('streetkings:phone:externalApps:remove', -1, appId)
    return true
end

local function sendTabletAppMessage(source, appId, eventName, data)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local target = tonumber(source)
    appId = tostring(appId or ''):lower()
    local app = externalApps[appId]
    if not target then return false, 'invalid_source' end
    if not app then return false, 'not_found' end
    if app.resource ~= owner then return false, 'not_owner' end

    TriggerClientEvent('streetkings:phone:externalApp:message', target, appId, tostring(eventName or ''), data or {})
    return true
end

local function openTabletApp(source, appId, appData)
    local target = tonumber(source)
    appId = tostring(appId or ''):lower()
    if not target then return false, 'invalid_source' end
    if not externalApps[appId] then return false, 'not_found' end

    TriggerClientEvent('streetkings:phone:externalApp:open', target, appId, appData or {})
    return true
end

RegisterNetEvent('streetkings:phone:externalApps:requestSync', function()
    TriggerClientEvent('streetkings:phone:externalApps:sync', source, appList())
end)

AddEventHandler('onResourceStop', function(resourceName)
    local removed = {}
    for appId, app in pairs(externalApps) do
        if app.resource == resourceName then
            removed[#removed + 1] = appId
        end
    end

    for _, appId in ipairs(removed) do
        externalApps[appId] = nil
        TriggerClientEvent('streetkings:phone:externalApps:remove', -1, appId)
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
