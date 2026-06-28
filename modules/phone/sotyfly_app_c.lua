local SOTYFLY_APP = {
    id = 'sotyfly',
    label = 'Sotyfly',
    icon = 'fa-music',
    glyph = 'Sf',
    color = 'linear-gradient(135deg, #1ed760, #0f8f44)',
    category = 'media',
    ui = 'html/apps/sotyfly/index.html',
    description = 'Tablet music player with synced drive audio.',
    version = '1.0.0',
    developer = 'Five Horizon',
}

local LINKS_KVP = 'sk_sotyfly_links'
local PLAYLISTS_KVP = 'sk_sotyfly_playlists'
local DEFAULT_DISTANCE = 28.0
local DEFAULT_VOLUME = 0.42
local activeSessions = {}
local ownSessionId = nil

local function registerSotyflyApp()
    exports[GetCurrentResourceName()]:RegisterTabletApp(SOTYFLY_APP)
end

local function decodeKvp(key, fallback)
    local raw = GetResourceKvpString(key)
    if not raw or raw == '' then return fallback end
    local ok, value = pcall(json.decode, raw)
    if not ok or type(value) ~= 'table' then return fallback end
    return value
end

local function saveKvp(key, value)
    SetResourceKvp(key, json.encode(value or {}))
end

local function cleanText(value, maxLength)
    value = tostring(value or ''):gsub('[\r\n\t]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, maxLength or 80)
end

local function normalizeUrl(value)
    value = cleanText(value, 300)
    if value == '' then return '' end
    if not value:match('^https?://') then return '' end
    return value
end

local function buildLinkTitle(url, title)
    title = cleanText(title, 96)
    if title ~= '' then return title end
    local host = url:match('^https?://([^/%?]+)')
    return host and ('Link ' .. host) or 'Link guardado'
end

local function getLinks()
    local links = decodeKvp(LINKS_KVP, {})
    local clean = {}
    for _, link in ipairs(links) do
        if type(link) == 'table' and type(link.url) == 'string' and link.url ~= '' then
            clean[#clean + 1] = {
                id = tostring(link.id or ('link_' .. #clean + 1)),
                title = cleanText(link.title, 96),
                url = link.url,
                provider = tostring(link.provider or 'link'):sub(1, 24),
                addedAt = tonumber(link.addedAt) or 0,
                type = 'link',
            }
        end
    end
    return clean
end

local function getPlaylists()
    local playlists = decodeKvp(PLAYLISTS_KVP, {
        { id = 'favorites', name = 'Favoritos', items = {} },
        { id = 'drives', name = 'Drive links', items = {} },
    })
    if #playlists == 0 then
        playlists = {
            { id = 'favorites', name = 'Favoritos', items = {} },
            { id = 'drives', name = 'Drive links', items = {} },
        }
    end
    return playlists
end

local function xsoundReady()
    return GetResourceState('xsound') == 'started'
end

local function soundName(sessionId)
    return tostring(sessionId or ''):gsub('[^%w_%-]', '_')
end

local function coordsPayload()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local entity = vehicle ~= 0 and vehicle or ped
    local coords = GetEntityCoords(entity)
    local netId = 0
    if vehicle ~= 0 and NetworkGetEntityIsNetworked(vehicle) then
        netId = VehToNet(vehicle)
    end
    return { x = coords.x, y = coords.y, z = coords.z }, netId
end

local function destroySession(sessionId)
    if xsoundReady() then
        pcall(function()
            exports['xsound']:Destroy(soundName(sessionId))
        end)
    end
    activeSessions[sessionId] = nil
    if ownSessionId == sessionId then ownSessionId = nil end
end

local function updateSessionPosition(sessionId, coords, netId)
    local session = activeSessions[sessionId]
    if not session then return end
    session.coords = coords or session.coords
    session.netId = tonumber(netId) or session.netId or 0

    if session.netId and session.netId ~= 0 and NetworkDoesNetworkIdExist(session.netId) then
        local entity = NetToEnt(session.netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            local pos = GetEntityCoords(entity)
            session.coords = { x = pos.x, y = pos.y, z = pos.z }
        end
    end

    if xsoundReady() and session.coords then
        pcall(function()
            exports['xsound']:Position(soundName(sessionId), vector3(session.coords.x, session.coords.y, session.coords.z))
        end)
    end
end

local function startSession(session)
    if type(session) ~= 'table' or type(session.id) ~= 'string' then return end
    activeSessions[session.id] = session
    if session.owner == GetPlayerServerId(PlayerId()) then
        ownSessionId = session.id
    end
    if not xsoundReady() then return end

    local coords = session.coords or coordsPayload()
    pcall(function()
        exports['xsound']:Destroy(soundName(session.id))
    end)
    pcall(function()
        exports['xsound']:PlayUrlPos(
            soundName(session.id),
            session.url,
            tonumber(session.volume) or DEFAULT_VOLUME,
            vector3(coords.x, coords.y, coords.z),
            false
        )
        exports['xsound']:Distance(soundName(session.id), tonumber(session.distance) or DEFAULT_DISTANCE)
    end)

    CreateThread(function()
        Wait(650)
        local elapsed = math.max(0, os.time() - (tonumber(session.startedAt) or os.time()))
        pcall(function()
            exports['xsound']:setTimeStamp(soundName(session.id), elapsed)
            if session.paused then exports['xsound']:Pause(soundName(session.id)) end
        end)
    end)
end

local function getOwnPlaybackState()
    local base = SKSoundtrack.GetPlayerState()
    local session = ownSessionId and activeSessions[ownSessionId] or nil
    local currentMs = 0
    local durationMs = 0
    local playing = false
    if session and xsoundReady() then
        pcall(function()
            currentMs = math.floor((exports['xsound']:getTimeStamp(soundName(session.id)) or 0) * 1000)
            durationMs = math.floor((exports['xsound']:getMaxDuration(soundName(session.id)) or 0) * 1000)
            playing = exports['xsound']:isPlaying(soundName(session.id)) == true
        end)
    end

    return {
        key = session and session.id or nil,
        title = session and session.title or nil,
        currentMs = currentMs,
        durationMs = durationMs,
        playing = playing,
        enabled = base.enabled,
        blocked = base.blocked,
        musicDisabled = base.musicDisabled,
        xsoundReady = xsoundReady(),
        externalPlayer = true,
        distance = session and session.distance or DEFAULT_DISTANCE,
    }
end

RegisterNUICallback('sotyfly:getData', function(data, cb)
    local query = cleanText(data and data.query, 80)
    TriggerServerEvent('streetkings:sotyfly:requestSessions')
    cb({
        ok = true,
        player = getOwnPlaybackState(),
        tracks = {},
        links = getLinks(),
        playlists = getPlaylists(),
        sessions = activeSessions,
    })
end)

RegisterNUICallback('sotyfly:playItem', function(data, cb)
    data = type(data) == 'table' and data or {}
    local url = normalizeUrl(data.url)
    local title = cleanText(data.title, 120)

    if url == '' and data.id then
        for _, link in ipairs(getLinks()) do
            if link.id == data.id then
                url = link.url
                title = title ~= '' and title or link.title
                break
            end
        end
    end

    if url == '' then
        cb({ ok = false, reason = 'invalid_url', player = getOwnPlaybackState() })
        return
    end

    if not xsoundReady() then
        cb({ ok = false, reason = 'xsound_missing', player = getOwnPlaybackState() })
        return
    end

    local coords, netId = coordsPayload()
    TriggerServerEvent('streetkings:sotyfly:playUrl', {
        url = url,
        title = title ~= '' and title or buildLinkTitle(url, ''),
        coords = coords,
        netId = netId,
        distance = DEFAULT_DISTANCE,
        volume = DEFAULT_VOLUME,
    })
    cb({ ok = true, player = getOwnPlaybackState() })
end)

RegisterNUICallback('sotyfly:skip', function(_, cb)
    TriggerServerEvent('streetkings:sotyfly:stop')
    cb({ ok = true, player = getOwnPlaybackState() })
end)

RegisterNUICallback('sotyfly:pause', function(_, cb)
    TriggerServerEvent('streetkings:sotyfly:pause')
    cb({ ok = true, player = getOwnPlaybackState() })
end)

RegisterNUICallback('sotyfly:resume', function(_, cb)
    TriggerServerEvent('streetkings:sotyfly:resume')
    cb({ ok = true, player = getOwnPlaybackState() })
end)

RegisterNUICallback('sotyfly:setEnabled', function(data, cb)
    local enabled = data and data.enabled == true
    if SKSettings and SKSettings.setGeneralValue then
        SKSettings.setGeneralValue('soundtrackEnabled', enabled)
    end
    exports[GetCurrentResourceName()]:SetSoundtrackEnabled(enabled)
    cb({ ok = true, player = getOwnPlaybackState() })
end)

RegisterNUICallback('sotyfly:addLink', function(data, cb)
    local url = normalizeUrl(data and data.url)
    if url == '' then
        cb({ ok = false, reason = 'invalid_url' })
        return
    end
    local links = getLinks()
    for _, link in ipairs(links) do
        if link.url == url then
            cb({ ok = true, duplicate = true, links = links })
            return
        end
    end
    links[#links + 1] = {
        id = ('link_%d_%d'):format(GetGameTimer(), #links + 1),
        title = buildLinkTitle(url, data and data.title),
        url = url,
        provider = 'link',
        addedAt = GetCloudTimeAsInt and GetCloudTimeAsInt() or GetGameTimer(),
        type = 'link',
    }
    saveKvp(LINKS_KVP, links)
    cb({ ok = true, links = links })
end)

RegisterNUICallback('sotyfly:removeLink', function(data, cb)
    local id = tostring(data and data.id or '')
    local links = getLinks()
    for i = #links, 1, -1 do
        if links[i].id == id then table.remove(links, i) end
    end
    saveKvp(LINKS_KVP, links)
    cb({ ok = true, links = links })
end)

RegisterNUICallback('sotyfly:savePlaylists', function(data, cb)
    local incoming = type(data and data.playlists) == 'table' and data.playlists or {}
    local playlists = {}
    for _, playlist in ipairs(incoming) do
        if type(playlist) == 'table' then
            playlists[#playlists + 1] = {
                id = cleanText(playlist.id, 48),
                name = cleanText(playlist.name, 48),
                items = type(playlist.items) == 'table' and playlist.items or {},
            }
        end
    end
    saveKvp(PLAYLISTS_KVP, playlists)
    cb({ ok = true, playlists = playlists })
end)

RegisterNUICallback('sotyfly:setVisible', function(data, cb)
    SKSoundtrack.SetSotyflyVisible(data and data.visible == true)
    cb({ ok = true })
end)

local function playUrlFromExport(url, title, options)
    url = normalizeUrl(url)
    if url == '' then return false, 'invalid_url' end
    if not xsoundReady() then return false, 'xsound_missing' end

    options = type(options) == 'table' and options or {}
    local coords, netId = coordsPayload()
    TriggerServerEvent('streetkings:sotyfly:playUrl', {
        url = url,
        title = cleanText(title, 120) ~= '' and cleanText(title, 120) or buildLinkTitle(url, ''),
        coords = coords,
        netId = tonumber(options.netId) or netId,
        distance = tonumber(options.distance) or DEFAULT_DISTANCE,
        volume = tonumber(options.volume) or DEFAULT_VOLUME,
    })
    return true
end

exports('PlaySotyflyUrl', playUrlFromExport)

exports('StopSotyfly', function()
    TriggerServerEvent('streetkings:sotyfly:stop')
    return true
end)

exports('GetSotyflyPlayerState', function()
    return getOwnPlaybackState()
end)

RegisterNetEvent('streetkings:sotyfly:sessions', function(sessions)
    if type(sessions) ~= 'table' then return end
    for sessionId, session in pairs(sessions) do
        if not activeSessions[sessionId] then
            startSession(session)
        else
            activeSessions[sessionId] = session
            updateSessionPosition(sessionId, session.coords, session.netId)
        end
    end
end)

RegisterNetEvent('streetkings:sotyfly:play', function(session)
    startSession(session)
end)

RegisterNetEvent('streetkings:sotyfly:position', function(sessionId, coords, netId)
    updateSessionPosition(sessionId, coords, netId)
end)

RegisterNetEvent('streetkings:sotyfly:pause', function(sessionId)
    local session = activeSessions[sessionId]
    if session then session.paused = true end
    if xsoundReady() then
        pcall(function() exports['xsound']:Pause(soundName(sessionId)) end)
    end
end)

RegisterNetEvent('streetkings:sotyfly:resume', function(sessionId)
    local session = activeSessions[sessionId]
    if session then session.paused = false end
    if xsoundReady() then
        pcall(function() exports['xsound']:Resume(soundName(sessionId)) end)
    end
end)

RegisterNetEvent('streetkings:sotyfly:stop', function(sessionId)
    destroySession(sessionId)
end)

RegisterNetEvent('streetkings:sotyfly:error', function(reason)
    if SKNotify then
        SKNotify({ type = 'error', title = 'Sotyfly', body = tostring(reason or 'Error') })
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        registerSotyflyApp()
    end
end)

CreateThread(function()
    Wait(850)
    registerSotyflyApp()
    TriggerServerEvent('streetkings:sotyfly:requestSessions')
end)

CreateThread(function()
    while true do
        Wait(900)
        if ownSessionId and activeSessions[ownSessionId] then
            local coords, netId = coordsPayload()
            TriggerServerEvent('streetkings:sotyfly:updatePosition', coords, netId)
            updateSessionPosition(ownSessionId, coords, netId)
        end
    end
end)
