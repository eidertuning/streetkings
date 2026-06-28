local SOTYFLY_APP = {
    id = 'sotyfly',
    label = 'Sotyfly',
    icon = 'fa-music',
    glyph = 'Sf',
    color = 'linear-gradient(135deg, #1DB954, #11833b)',
    category = 'media',
    ui = 'html/apps/sotyfly/index.html',
    description = 'StreetKings synced music player.',
    version = '2.0.0',
    developer = 'Five Horizon',
}

local Config = SKMusicConfig or {}
local activeSources = {}
local startedSounds = {}
local appVisible = false
local listenerVolume = tonumber(GetResourceKvpString('sk_sotyfly_listener_volume')) or (Config.DefaultPlayerMusicVolume or 0.7)
local currentPlayerState = nil

local function cfg(key, fallback)
    local value = Config[key]
    if value == nil then return fallback end
    return value
end

local function registerSotyflyApp()
    exports[GetCurrentResourceName()]:RegisterTabletApp(SOTYFLY_APP)
end

local function xsoundReady()
    return GetResourceState('xsound') == 'started'
end

local function notifyError(message)
    if SKNotify then
        SKNotify({ type = 'error', title = 'Sotyfly', body = message or 'Error' })
    end
end

local function musicDisabled()
    if not SKSettings or not SKSettings.getGeneralConfig then return false end
    local ok, config = pcall(SKSettings.getGeneralConfig)
    return ok and type(config) == 'table' and config.musicDisabled == true
end

local function sendAppEvent(eventName, data)
    exports[GetCurrentResourceName()]:SendTabletAppMessage('sotyfly', eventName, data or {})
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

local function sourceCoords(sourceData)
    if sourceData.vehicleNetId and sourceData.vehicleNetId ~= 0 and NetworkDoesNetworkIdExist(sourceData.vehicleNetId) then
        local entity = NetToEnt(sourceData.vehicleNetId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            return coords
        end
    end
    local c = sourceData.coords or {}
    return vector3(tonumber(c.x) or 0.0, tonumber(c.y) or 0.0, tonumber(c.z) or 0.0)
end

local function distanceToSource(sourceData)
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - sourceCoords(sourceData))
end

local function timeOffset(sourceData)
    sourceData._serverOffset = sourceData._serverOffset or ((tonumber(sourceData.serverNow) or os.time()) - os.time())
    return sourceData._serverOffset
end

local function serverNow(sourceData)
    return os.time() + timeOffset(sourceData)
end

local function elapsedSeconds(sourceData)
    local endTime = sourceData.paused and tonumber(sourceData.pausedAt) or serverNow(sourceData)
    local elapsed = (endTime or serverNow(sourceData)) - (tonumber(sourceData.startedAt) or serverNow(sourceData)) - (tonumber(sourceData.totalPausedDuration) or 0)
    return math.max(0, elapsed)
end

local function destroySound(soundName)
    if xsoundReady() then
        pcall(function() exports['xsound']:Destroy(soundName) end)
    end
    startedSounds[soundName] = nil
end

local function setSoundVolume(soundName, volume)
    if not xsoundReady() then return end
    local ok = pcall(function()
        exports['xsound']:setVolumeMax(soundName, volume)
    end)
    if not ok then
        pcall(function()
            exports['xsound']:setVolume(soundName, volume)
        end)
    end
end

local function ensureSound(sourceData)
    if not xsoundReady() then return false end
    if musicDisabled() then return false end
    local soundName = sourceData.soundName
    if not soundName or soundName == '' or not sourceData.url then return false end
    local coords = sourceCoords(sourceData)
    if startedSounds[soundName] then
        pcall(function()
            exports['xsound']:Position(soundName, coords)
        end)
        return true
    end

    pcall(function()
        exports['xsound']:Destroy(soundName)
        exports['xsound']:PlayUrlPos(soundName, sourceData.url, 0.0, coords, false)
        exports['xsound']:Distance(soundName, tonumber(cfg('MaxAudibleDistance', 25.0)) or 25.0)
    end)
    startedSounds[soundName] = true

    CreateThread(function()
        Wait(450)
        if not activeSources[soundName] or not startedSounds[soundName] then return end
        pcall(function()
            exports['xsound']:setTimeStamp(soundName, elapsedSeconds(sourceData))
            if sourceData.paused then exports['xsound']:Pause(soundName) end
        end)
    end)
    return true
end

local function distanceFactor(distance)
    local full = tonumber(cfg('FullVolumeDistance', 5.0)) or 5.0
    local max = tonumber(cfg('MaxAudibleDistance', 25.0)) or 25.0
    if distance <= full then return 1.0 end
    if distance >= max then return 0.0 end
    local factor = 1.0 - ((distance - full) / (max - full))
    factor = math.max(0.0, math.min(factor, 1.0))
    if cfg('FadeCurve', 'smooth') == 'smooth' then
        factor = factor * factor * (3.0 - 2.0 * factor)
    end
    return factor
end

local function updateMiniHud()
    if not cfg('EnableMiniHud', true) then return end
    SendNUIMessage({
        type = 'sotyfly:minihud',
        visible = (not appVisible) and not musicDisabled() and currentPlayerState ~= nil and currentPlayerState.title ~= nil,
        player = currentPlayerState,
        daily = currentPlayerState and currentPlayerState.daily or nil,
    })
end

local function buildPlayerState(sourceData, daily)
    if not sourceData then return nil end
    return {
        key = sourceData.soundName,
        soundName = sourceData.soundName,
        trackId = sourceData.trackId,
        title = sourceData.title,
        channelTitle = sourceData.channelTitle,
        thumbnail = sourceData.thumbnail,
        currentMs = math.floor(elapsedSeconds(sourceData) * 1000),
        durationMs = (tonumber(sourceData.duration) or 0) * 1000,
        playing = sourceData.paused ~= true,
        paused = sourceData.paused == true,
        sourceVolume = tonumber(sourceData.volume) or cfg('DefaultSourceVolume', 0.35),
        listenerVolume = listenerVolume,
        synced = true,
        xsoundReady = xsoundReady(),
        musicDisabled = musicDisabled(),
        daily = daily,
    }
end

local function updateOwnPlayerState(payload)
    local serverId = GetPlayerServerId(PlayerId())
    local ownSource = nil
    for _, sourceData in pairs(activeSources) do
        if tonumber(sourceData.owner) == serverId then
            ownSource = sourceData
            break
        end
    end
    currentPlayerState = buildPlayerState(ownSource, payload and payload.daily or nil)
    sendAppEvent('state', { player = currentPlayerState, musicDisabled = musicDisabled() })
    updateMiniHud()
end

local function mergeSource(sourceData)
    if type(sourceData) ~= 'table' or type(sourceData.soundName) ~= 'string' then return end
    sourceData._serverOffset = nil
    activeSources[sourceData.soundName] = sourceData
    updateOwnPlayerState()
end

RegisterNUICallback('sotyfly:getData', function(_, cb)
    local result = lib.callback.await('streetmusic:server:syncState', false) or { ok = false }
    activeSources = {}
    for _, sourceData in pairs(result.activeSources or {}) do
        if type(sourceData) == 'table' and sourceData.soundName then
            activeSources[sourceData.soundName] = sourceData
        end
    end
    listenerVolume = tonumber(GetResourceKvpString('sk_sotyfly_listener_volume')) or listenerVolume
    result.listenerVolume = listenerVolume
    result.musicDisabled = musicDisabled()
    if result.player then result.player.musicDisabled = result.musicDisabled end
    updateOwnPlayerState(result)
    cb(result)
end)

RegisterNUICallback('sotyfly:search', function(data, cb)
    cb(lib.callback.await('streetmusic:server:search', false, data and data.query or '') or { ok = false, reason = 'search_failed' })
end)

RegisterNUICallback('sotyfly:playTrack', function(data, cb)
    if musicDisabled() then
        local message = 'Debes ir a Ajustes y activar el audio para usar Sotyfly.'
        notifyError(message)
        cb({ ok = false, reason = 'music_disabled', message = message, musicDisabled = true })
        return
    end
    data = type(data) == 'table' and data or {}
    local coords, netId = coordsPayload()
    data.coords = coords
    data.vehicleNetId = netId
    local result = lib.callback.await('streetmusic:server:playTrack3D', false, data) or { ok = false }
    if result.ok and result.player then mergeSource(result.player) end
    if not result.ok and result.message then notifyError(result.message) end
    cb(result)
end)

RegisterNUICallback('sotyfly:playFromUrl', function(data, cb)
    if musicDisabled() then
        local message = 'Debes ir a Ajustes y activar el audio para usar Sotyfly.'
        notifyError(message)
        cb({ ok = false, reason = 'music_disabled', message = message, musicDisabled = true })
        return
    end
    data = type(data) == 'table' and data or {}
    local coords, netId = coordsPayload()
    data.coords = coords
    data.vehicleNetId = netId
    local result = lib.callback.await('streetmusic:server:playFromUrl', false, data) or { ok = false }
    if result.ok and result.player then mergeSource(result.player) end
    if not result.ok and result.message then notifyError(result.message) end
    cb(result)
end)

RegisterNUICallback('sotyfly:pause', function(_, cb)
    local result = lib.callback.await('streetmusic:server:pauseTrack', false) or { ok = false }
    if result.player then mergeSource(result.player) end
    cb(result)
end)

RegisterNUICallback('sotyfly:resume', function(_, cb)
    local result = lib.callback.await('streetmusic:server:resumeTrack', false) or { ok = false }
    if result.player then mergeSource(result.player) end
    cb(result)
end)

RegisterNUICallback('sotyfly:stop', function(_, cb)
    cb(lib.callback.await('streetmusic:server:stopTrack', false) or { ok = true })
    currentPlayerState = nil
    updateMiniHud()
end)

RegisterNUICallback('sotyfly:next', function(_, cb)
    local result = lib.callback.await('streetmusic:server:skipTrack', false, 1) or { ok = false }
    if result.ok and result.player then mergeSource(result.player) end
    cb(result)
end)

RegisterNUICallback('sotyfly:previous', function(_, cb)
    local result = lib.callback.await('streetmusic:server:skipTrack', false, -1) or { ok = false }
    if result.ok and result.player then mergeSource(result.player) end
    cb(result)
end)

RegisterNUICallback('sotyfly:skip', function(_, cb)
    local result = lib.callback.await('streetmusic:server:skipTrack', false, 1) or { ok = false }
    if result.ok and result.player then mergeSource(result.player) end
    cb(result)
end)

RegisterNUICallback('sotyfly:setSourceVolume', function(data, cb)
    local result = lib.callback.await('streetmusic:server:setSourceVolume', false, data and data.volume) or { ok = false }
    if result.player then mergeSource(result.player) end
    cb(result)
end)

RegisterNUICallback('sotyfly:setListenerVolume', function(data, cb)
    listenerVolume = math.max(0.0, math.min(tonumber(data and data.volume) or listenerVolume, 1.0))
    SetResourceKvp('sk_sotyfly_listener_volume', tostring(listenerVolume))
    cb(lib.callback.await('streetmusic:server:setListenerVolume', false, listenerVolume) or { ok = true, volume = listenerVolume })
end)

RegisterNUICallback('sotyfly:createPlaylist', function(data, cb)
    cb(lib.callback.await('streetmusic:server:createPlaylist', false, data or {}) or { ok = false })
end)

RegisterNUICallback('sotyfly:deletePlaylist', function(data, cb)
    cb(lib.callback.await('streetmusic:server:deletePlaylist', false, data and data.playlistId) or { ok = false })
end)

RegisterNUICallback('sotyfly:renamePlaylist', function(data, cb)
    cb(lib.callback.await('streetmusic:server:renamePlaylist', false, data or {}) or { ok = false })
end)

RegisterNUICallback('sotyfly:addTrackToPlaylist', function(data, cb)
    cb(lib.callback.await('streetmusic:server:addTrackToPlaylist', false, data or {}) or { ok = false })
end)

RegisterNUICallback('sotyfly:removeTrackFromPlaylist', function(data, cb)
    cb(lib.callback.await('streetmusic:server:removeTrackFromPlaylist', false, data or {}) or { ok = false })
end)

RegisterNUICallback('sotyfly:getPlaylistTracks', function(data, cb)
    cb(lib.callback.await('streetmusic:server:getPlaylistTracks', false, data and data.playlistId) or { ok = false })
end)

RegisterNUICallback('sotyfly:setVisible', function(data, cb)
    appVisible = data and data.visible == true
    SKSoundtrack.SetSotyflyVisible(appVisible)
    updateMiniHud()
    cb({ ok = true })
end)

RegisterNUICallback('sotyfly:openPlayer', function(_, cb)
    exports[GetCurrentResourceName()]:OpenTabletApp('sotyfly')
    cb({ ok = true })
end)

RegisterNetEvent('streetmusic:client:createOrUpdateSound', function(sourceData)
    mergeSource(sourceData)
end)

RegisterNetEvent('streetmusic:client:syncSources', function(sources)
    activeSources = {}
    for _, sourceData in pairs(sources or {}) do
        if type(sourceData) == 'table' and sourceData.soundName then
            activeSources[sourceData.soundName] = sourceData
        end
    end
    updateOwnPlayerState()
end)

RegisterNetEvent('streetmusic:client:stopSound', function(soundName)
    destroySound(soundName)
    activeSources[soundName] = nil
    updateOwnPlayerState()
end)

RegisterNetEvent('streetmusic:client:pauseSound', function(soundName, sourceData)
    if sourceData then mergeSource(sourceData) end
    if xsoundReady() then pcall(function() exports['xsound']:Pause(soundName) end) end
end)

RegisterNetEvent('streetmusic:client:resumeSound', function(soundName, sourceData)
    if sourceData then mergeSource(sourceData) end
    if xsoundReady() then pcall(function() exports['xsound']:Resume(soundName) end) end
end)

RegisterNetEvent('streetmusic:client:updateSoundPosition', function(soundName, coords, vehicleNetId)
    local sourceData = activeSources[soundName]
    if not sourceData then return end
    sourceData.coords = coords or sourceData.coords
    sourceData.vehicleNetId = tonumber(vehicleNetId) or sourceData.vehicleNetId or 0
end)

RegisterNetEvent('streetmusic:client:updateNearbyVolumes', function()
    -- Exposed logical event; the interval thread performs the actual work.
end)

RegisterNetEvent('streetmusic:client:updateMiniHud', updateMiniHud)
RegisterNetEvent('streetmusic:client:openPlayer', function() exports[GetCurrentResourceName()]:OpenTabletApp('sotyfly') end)
RegisterNetEvent('streetmusic:client:closePlayer', function() SKPhone.close() end)

RegisterNetEvent('streetkings:sotyfly:error', function(reason)
    notifyError(tostring(reason or 'Error'))
end)

exports('PlaySotyflyUrl', function(url, title, options)
    local coords, netId = coordsPayload()
    options = type(options) == 'table' and options or {}
    options.url = url
    options.title = title
    options.coords = coords
    options.vehicleNetId = tonumber(options.vehicleNetId) or netId
    local result = lib.callback.await('streetmusic:server:playFromUrl', false, options) or { ok = false }
    if result.ok and result.player then mergeSource(result.player) end
    return result.ok == true, result.reason
end)

exports('StopSotyfly', function()
    local result = lib.callback.await('streetmusic:server:stopTrack', false) or { ok = true }
    return result.ok == true
end)

exports('GetSotyflyPlayerState', function()
    return currentPlayerState
end)

CreateThread(function()
    Wait(850)
    registerSotyflyApp()
    TriggerServerEvent('streetkings:sotyfly:requestSessions')
end)

CreateThread(function()
    while true do
        Wait(tonumber(cfg('UpdatePositionInterval', 500)) or 500)

        if musicDisabled() then
            for soundName in pairs(startedSounds) do
                destroySound(soundName)
            end
            updateOwnPlayerState({ musicDisabled = true })
        else
            local sorted = {}
            for soundName, sourceData in pairs(activeSources) do
                local dist = distanceToSource(sourceData)
                sorted[#sorted + 1] = { soundName = soundName, sourceData = sourceData, distance = dist }
            end
            table.sort(sorted, function(a, b) return a.distance < b.distance end)

            local nearbyCount = 0
            local maxNearby = tonumber(cfg('MaxNearbySources', 5)) or 5
            for _, item in ipairs(sorted) do
                local sourceData = item.sourceData
                local maxDistance = tonumber(cfg('MaxAudibleDistance', 25.0)) or 25.0
                if item.distance <= maxDistance and nearbyCount < maxNearby then
                    nearbyCount = nearbyCount + 1
                    if ensureSound(sourceData) and xsoundReady() then
                        local factor = distanceFactor(item.distance)
                        local finalVolume = (tonumber(sourceData.volume) or cfg('DefaultSourceVolume', 0.35)) * listenerVolume * factor
                        finalVolume = math.max(tonumber(cfg('MinVolume', 0.0)) or 0.0, math.min(finalVolume, 1.0))
                        pcall(function()
                            exports['xsound']:Position(sourceData.soundName, sourceCoords(sourceData))
                        end)
                        setSoundVolume(sourceData.soundName, finalVolume)
                    end
                elseif startedSounds[item.soundName] then
                    destroySound(item.soundName)
                end
            end

            updateOwnPlayerState()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(tonumber(cfg('UpdatePositionInterval', 500)) or 500)
        if currentPlayerState then
            local coords, netId = coordsPayload()
            TriggerServerEvent('streetmusic:server:updatePosition', coords, netId)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for soundName in pairs(startedSounds) do
        destroySound(soundName)
    end
end)
