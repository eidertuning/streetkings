local ACTIVE_SESSIONS = {}
local DEFAULT_DISTANCE = 28.0
local DEFAULT_VOLUME = 0.42

local function cleanText(value, maxLength)
    value = tostring(value or ''):gsub('[\r\n\t]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, maxLength or 96)
end

local function cleanUrl(value)
    value = cleanText(value, 500)
    if value == '' or not value:match('^https?://') then
        return ''
    end
    return value
end

local function vectorPayload(coords)
    if type(coords) ~= 'table' then return nil end
    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z }
end

local function sessionIdFor(src)
    return ('sk_sotyfly_%d'):format(src)
end

local function publicSession(session)
    return {
        id = session.id,
        owner = session.owner,
        title = session.title,
        url = session.url,
        coords = session.coords,
        netId = session.netId,
        startedAt = session.startedAt,
        paused = session.paused == true,
        distance = session.distance,
        volume = session.volume,
    }
end

RegisterNetEvent('streetkings:sotyfly:requestSessions', function()
    local src = source
    local payload = {}
    for id, session in pairs(ACTIVE_SESSIONS) do
        payload[id] = publicSession(session)
    end
    TriggerClientEvent('streetkings:sotyfly:sessions', src, payload)
end)

RegisterNetEvent('streetkings:sotyfly:playUrl', function(data)
    local src = source
    data = type(data) == 'table' and data or {}
    local url = cleanUrl(data.url)
    if url == '' then
        TriggerClientEvent('streetkings:sotyfly:error', src, 'invalid_url')
        return
    end

    local coords = vectorPayload(data.coords)
    if not coords then
        local ped = GetPlayerPed(src)
        local pos = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
        coords = { x = pos.x, y = pos.y, z = pos.z }
    end

    local id = sessionIdFor(src)
    local session = {
        id = id,
        owner = src,
        title = cleanText(data.title, 120),
        url = url,
        coords = coords,
        netId = tonumber(data.netId) or 0,
        startedAt = os.time(),
        paused = false,
        distance = math.max(5.0, math.min(tonumber(data.distance) or DEFAULT_DISTANCE, 90.0)),
        volume = math.max(0.0, math.min(tonumber(data.volume) or DEFAULT_VOLUME, 1.0)),
    }
    if session.title == '' then session.title = 'Sotyfly link' end

    ACTIVE_SESSIONS[id] = session
    TriggerClientEvent('streetkings:sotyfly:play', -1, publicSession(session))
end)

RegisterNetEvent('streetkings:sotyfly:updatePosition', function(coords, netId)
    local src = source
    local id = sessionIdFor(src)
    local session = ACTIVE_SESSIONS[id]
    if not session then return end

    local nextCoords = vectorPayload(coords)
    if not nextCoords then return end

    session.coords = nextCoords
    session.netId = tonumber(netId) or session.netId or 0
    TriggerClientEvent('streetkings:sotyfly:position', -1, id, session.coords, session.netId)
end)

RegisterNetEvent('streetkings:sotyfly:pause', function()
    local src = source
    local id = sessionIdFor(src)
    local session = ACTIVE_SESSIONS[id]
    if not session then return end
    session.paused = true
    TriggerClientEvent('streetkings:sotyfly:pause', -1, id)
end)

RegisterNetEvent('streetkings:sotyfly:resume', function()
    local src = source
    local id = sessionIdFor(src)
    local session = ACTIVE_SESSIONS[id]
    if not session then return end
    session.paused = false
    TriggerClientEvent('streetkings:sotyfly:resume', -1, id)
end)

RegisterNetEvent('streetkings:sotyfly:stop', function()
    local src = source
    local id = sessionIdFor(src)
    if not ACTIVE_SESSIONS[id] then return end
    ACTIVE_SESSIONS[id] = nil
    TriggerClientEvent('streetkings:sotyfly:stop', -1, id)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = sessionIdFor(src)
    if not ACTIVE_SESSIONS[id] then return end
    ACTIVE_SESSIONS[id] = nil
    TriggerClientEvent('streetkings:sotyfly:stop', -1, id)
end)
