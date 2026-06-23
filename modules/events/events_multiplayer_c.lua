---@class SKMultiplayerModule
SKMultiplayer = SKMultiplayer or {}

---@class SKMultiplayerActiveRace
---@field lobbyId string
---@field eventId string
---@field eventName string
---@field vehicleClass string
---@field releaseInMs integer
---@field releaseSyncedAtMs integer
---@field gridPos { x: number, y: number, z: number, w: number }
---@field roster { source: integer, alias: string }[]
---@field checkpointCount integer
---@field checkpoints vector3[]
---@field checkpointsPerLap integer
---@field lapTotal integer
---@field collision boolean
---@field nitrousEnabled boolean
---@field trafficDensityPct integer
---@field def table
---@field myCpIndex integer
---@field peerSnapshots table<integer, table>
---@field checkpointHandle integer|nil
---@field blipHandle integer|nil
---@field blipHandleNext integer|nil
---@field waypointId integer|nil
---@field forfeited boolean
---@field finished boolean
---@field awaitingResults boolean
---@field elapsedMs integer|nil
---@field goReceived boolean

-- Internal state --------------------------------------------------------

---@type table|nil
local activeLobby            = nil
---@type SKMultiplayerActiveRace|nil
local activeRace             = nil
local activeVehicleNetId     = nil
local lastStandingsUpdateMs  = 0
local pendingSeamlessReturn  = false
local pendingSeamlessReturnVehicleNetId = nil
local lobbyDeathHandled      = false
local raceDeathHandled       = false

local STANDINGS_UPDATE_INTERVAL_MS = 250
local CHECKPOINT_PICKUP_RADIUS     = 20.0

-- Helpers ---------------------------------------------------------------

---@return integer|nil
local function vehicleFromNetId(netId)
    if not netId then return nil end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return nil end
    return NetworkGetEntityFromNetworkId(netId)
end

---@param netId integer
---@param timeoutMs integer
---@return integer|nil
local function awaitVehicle(netId, timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 10000)
    while GetGameTimer() < deadline do
        local veh = vehicleFromNetId(netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            return veh
        end
        Wait(0)
    end
    return nil
end

---@param vehicle integer
local function requestVehicleControl(vehicle)
    while not NetworkHasControlOfEntity(vehicle) do
        NetworkRequestControlOfEntity(vehicle)
        Wait(0)
    end
end

---@param vehicle integer
local function repairVehicleForRace(vehicle)
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
end

---@param def table
---@param lapTotal integer
---@return vector3[]
local function buildRaceCheckpoints(def, lapTotal)
    local baseCheckpoints = SKEventRoute.buildCheckpointList(def)
    if def.scheme ~= CheckpointScheme.CIRCUIT or lapTotal <= 1 then
        return baseCheckpoints
    end

    local checkpoints = {}
    for _ = 1, lapTotal do
        for _, checkpoint in ipairs(baseCheckpoints) do
            checkpoints[#checkpoints + 1] = checkpoint
        end
    end

    return checkpoints
end

---@param race SKMultiplayerActiveRace
---@param checkpointIndex integer
---@return integer|nil
local function getLapCurrent(race, checkpointIndex)
    if race.def.scheme ~= CheckpointScheme.CIRCUIT then
        return nil
    end
    return math.min(race.lapTotal, math.floor((checkpointIndex - 1) / race.checkpointsPerLap) + 1)
end

local function applyRaceVehicleNoCollision()
    if not activeRace or activeRace.collision then
        return
    end

    local myPed = PlayerPedId()
    local myVehicle = GetVehiclePedIsIn(myPed, false)
    if myVehicle == 0 or not DoesEntityExist(myVehicle) then
        return
    end

    local myServerId = GetPlayerServerId(PlayerId())
    for _, entry in ipairs(activeRace.roster) do
        if entry.source ~= myServerId then
            local snapshot = activeRace.peerSnapshots[entry.source]
            local targetVehicle = snapshot and vehicleFromNetId(snapshot.vehicleNetId) or nil
            local targetPlayer = GetPlayerFromServerId(entry.source)
            if targetPlayer ~= -1 then
                local targetPed = GetPlayerPed(targetPlayer)
                if (not targetVehicle or targetVehicle == 0 or not DoesEntityExist(targetVehicle)) then
                    targetVehicle = GetVehiclePedIsIn(targetPed, false)
                end
                if targetVehicle ~= 0 and DoesEntityExist(targetVehicle) then
                    SetEntityNoCollisionEntity(myVehicle, targetVehicle, true)
                    SetEntityNoCollisionEntity(targetVehicle, myVehicle, true)
                    SetEntityNoCollisionEntity(myPed, targetVehicle, true)
                    SetEntityNoCollisionEntity(targetPed, myVehicle, true)
                end
            end
        end
    end
end

---@param title string
---@param type string
local function notify(title, type)
    SKNotify({ title = title, type = type or 'info', duration = 3500 })
end

---@return boolean
local function canInitiateMultiplayerJoin()
    if SKC.GetGameState() ~= GameState.FREEROAM then
        notify('You cannot join while in this state.', 'error')
        return false
    end
    if SKPolice.hasWantedLevel() then
        SKPolice.notifyAccessBlockedByWantedLevel()
        return false
    end
    return true
end

-- Lobby HUD -------------------------------------------------------------

local function computeLobbyTick(lobby)
    if not lobby then return nil end
    local now = GetGameTimer()
    if not lobby._clientSyncedAtMs then return lobby end

    local drift = now - lobby._clientSyncedAtMs
    local expiresInSeconds = math.max(0, (lobby.expiresInSeconds or 0) - math.floor(drift / 1000))
    local startsInSeconds = nil
    if lobby.startsInSeconds then
        startsInSeconds = math.max(0, lobby.startsInSeconds - math.floor(drift / 1000))
    end

    local payload = {}
    for k, v in pairs(lobby) do payload[k] = v end
    payload.expiresInSeconds = expiresInSeconds
    payload.startsInSeconds = startsInSeconds
    return payload
end

local function pushLobbyHud()
    if not activeLobby then return end
    local payload = computeLobbyTick(activeLobby)
    payload.selfServerId = GetPlayerServerId(PlayerId())
    SendNUIMessage({ type = 'mp:lobbyUpdate', lobby = payload })
end

---@return integer|nil
local function getCurrentMultiplayerVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end
    return vehicleFromNetId(activeVehicleNetId)
end

local function clearActiveRaceUi()
    SendNUIMessage({ type = 'event:hide' })
    SendNUIMessage({ type = 'mp:standingsHide' })
    SendNUIMessage({ type = 'event:timerStop' })
    if activeRace then
        SKEventPreview.clearCheckpoint(activeRace.checkpointHandle, activeRace.blipHandle, activeRace.blipHandleNext)
        SKEventPreview.clearGpsTrack()
        activeRace.checkpointHandle = nil
        activeRace.blipHandle = nil
        activeRace.blipHandleNext = nil
        if activeRace.waypointId then
            SKWaypoint.Remove(activeRace.waypointId)
            activeRace.waypointId = nil
        end
    end
end

local function handleLobbyDeath()
    if lobbyDeathHandled then
        return
    end

    lobbyDeathHandled = true
    CreateThread(function()
        lib.callback.await('streetkings:events:leaveRaceLobby', false)
        activeLobby = nil
        SendNUIMessage({ type = 'mp:lobbyHide' })
        if SKPhone.isOpen() then
            SKPhone.close()
        end
        SKC.Wasted()
    end)
end

local function handleRaceDeath()
    if raceDeathHandled then
        return
    end

    raceDeathHandled = true
    if activeRace then
        activeRace.forfeited = true
    end

    CreateThread(function()
        lib.callback.await('streetkings:mp:forfeit', false)
        clearActiveRaceUi()
        if SKPhone.isOpen() then
            SKPhone.close()
        end
        SKC.Wasted()
    end)
end

-- Lobby game state ------------------------------------------------------

---@param prevState string|nil
local function onLobbyEnter(prevState)
    DeleteWaypoint()
    lobbyDeathHandled = false
    activeVehicleNetId = nil
    SendNUIMessage({
        type = 'mp:lobbyShow',
        lobby = (function()
            local p = computeLobbyTick(activeLobby) or activeLobby
            p.selfServerId = GetPlayerServerId(PlayerId())
            return p
        end)(),
    })
end

---@param nextState string
local function onLobbyExit(nextState)
    SendNUIMessage({ type = 'mp:lobbyHide' })

    if nextState == GameState.MULTIPLAYER_EVENT then return end
    activeVehicleNetId = nil
end

local function onLobbyTick()
    local vehicle = getCurrentMultiplayerVehicle()
    if vehicle and DoesEntityExist(vehicle) then
        SKVehicleLock.tick(vehicle, function() return false end)
    end

    if not lobbyDeathHandled and IsEntityDead(PlayerPedId()) then
        handleLobbyDeath()
        return
    end

    if lobbyDeathHandled then return end

    local now = GetGameTimer()
    if (now - lastStandingsUpdateMs) >= 1000 then
        lastStandingsUpdateMs = now
        pushLobbyHud()
    end
end

-- Race game state -------------------------------------------------------

---@param race SKMultiplayerActiveRace
---@param ped integer
---@return number elapsed
local function runRaceCheckpointLoop(race, ped)
    local def = race.def
    local checkpoints = race.checkpoints
    local total = #checkpoints
    local startTime = GetGameTimer()

    for i, cp in ipairs(checkpoints) do
        SendNUIMessage({
            type              = 'event:updateProgress',
            checkpointCurrent = i,
            checkpointTotal   = total,
            lapCurrent        = getLapCurrent(race, i),
            lapTotal          = def.type == EventType.RACE and def.scheme == CheckpointScheme.CIRCUIT and race.lapTotal or nil,
        })

        local from = i == 1 and SKEventRoute.toVector3(def.start) or checkpoints[i - 1]
        local remaining = { from }
        for j = i, total do remaining[#remaining + 1] = checkpoints[j] end
        if SKSettings.getMapWaypointMode() == 'wholeRoute' then
            SKEventPreview.renderGpsTrack(remaining)
        else
            SKEventPreview.clearGpsTrack()
        end

        local isLast = (i == total)
        local nextCp = checkpoints[i + 1]

        SKEventPreview.clearCheckpoint(race.checkpointHandle, race.blipHandle, race.blipHandleNext)
        race.checkpointHandle, race.blipHandle, race.blipHandleNext = SKEventPreview.createCheckpoint(cp, nextCp, isLast, true)
        if race.waypointId then
            SKWaypoint.Remove(race.waypointId)
        end
        race.waypointId = SKWaypoint.Create({
            coords = cp,
            text = isLast and 'FINISH' or 'CHECKPOINT',
            color = '#ffd200',
            icon = isLast and 'flag-checkered' or 'circle-dot',
            showDist = true,
            groundBeam = true,
        })

        while true do
            if SKC.GetGameState() ~= GameState.MULTIPLAYER_EVENT then
                SKEventPreview.clearGpsTrack()
                return 0
            end
            if race.forfeited then
                SKEventPreview.clearGpsTrack()
                return 0
            end
            local pos = GetEntityCoords(ped)
            if #(pos - cp) < CHECKPOINT_PICKUP_RADIUS then
                local result = lib.callback.await('streetkings:mp:checkpointHit', false, i)
                if result and result.ok then
                    TriggerEvent('streetkings:nitrous:checkpointCleared')
                    SKSettings.playSelectedCheckpointSound()
                    race.myCpIndex = i
                    break
                end
            end
            Wait(0)
        end
    end

    SKEventPreview.clearGpsTrack()
    SKEventPreview.clearCheckpoint(race.checkpointHandle, race.blipHandle, race.blipHandleNext)
    race.checkpointHandle = nil
    race.blipHandle = nil
    race.blipHandleNext = nil
    if race.waypointId then
        SKWaypoint.Remove(race.waypointId)
        race.waypointId = nil
    end

    return (GetGameTimer() - startTime) / 1000.0
end

---@param releaseInMs integer
---@param releaseSyncedAtMs integer
local function runSyncedCountdown(releaseInMs, releaseSyncedAtMs)
    local lastCount = nil

    while true do
        if not activeRace or activeRace.goReceived then
            return
        end

        local remainingMs = math.max(0, releaseInMs - (GetGameTimer() - releaseSyncedAtMs))
        local nextCount = nil

        if remainingMs > 0 then
            nextCount = math.ceil(remainingMs / 1000)
            if nextCount > 3 then
                nextCount = nil
            end
        end

        if nextCount ~= nil and nextCount ~= lastCount then
            SendNUIMessage({ type = 'event:countdown', count = nextCount })
            lastCount = nextCount
        end

        if remainingMs <= 0 then
            return
        end

        Wait(0)
    end
end

---@param data table
local function enterRace(data)
    local def = SKEvents[data.eventId]
    local checkpoints = buildRaceCheckpoints(def, data.lapTotal or 1)

    activeRace = {
        lobbyId = data.lobbyId,
        eventId = data.eventId,
        eventName = data.eventName,
        vehicleClass = data.vehicleClass,
        releaseInMs = 0,
        releaseSyncedAtMs = 0,
        gridPos = data.gridPos,
        roster = data.roster,
        checkpointCount = data.checkpointCount,
        checkpoints = checkpoints,
        checkpointsPerLap = data.checkpointsPerLap or #checkpoints,
        lapTotal = data.lapTotal or 1,
        collision = data.collision ~= false,
        nitrousEnabled = data.nitrousEnabled ~= false,
        trafficDensityPct = data.trafficDensityPct or 20,
        def = def,
        myCpIndex = 0,
        peerSnapshots = {},
        checkpointHandle = nil,
        blipHandle = nil,
        blipHandleNext = nil,
        waypointId = nil,
        forfeited = false,
        finished = false,
        awaitingResults = false,
        elapsedMs = nil,
        goReceived = false,
    }
end

---@param prevState string|nil
local function onRaceEnter(prevState)
    assert(activeRace, 'onRaceEnter called with no active race')
    TriggerEvent('streetkings:nitrous:setMultiplayerRaceDisabled', activeRace.nitrousEnabled == false)
    TriggerEvent('streetkings:environment:setMultiplayerTrafficDensity', activeRace.trafficDensityPct / 100.0)
    DeleteWaypoint()
    raceDeathHandled = false
    SKNametags.setRoster(activeRace.roster)
    CreateThread(function()
        if not IsScreenFadedOut() then DoScreenFadeOut(400) end
        Wait(450)

        local prepVeh = GetVehiclePedIsIn(PlayerPedId(), false)
        local prepModelLabel = SK.GetVehicleModelLabel(prepVeh)
        local result = lib.callback.await('streetkings:mp:prepareRaceVehicle', false, prepModelLabel)
        if not result or result.ok ~= true or not activeRace then
            notify('Failed to start race.', 'error')
            SKC.SetGameState(GameState.FREEROAM)
            return
        end

        activeVehicleNetId = result.netId
        activeRace.checkpointCount = result.checkpointCount or activeRace.checkpointCount
        activeRace.releaseInMs = result.releaseInMs or activeRace.releaseInMs
        activeRace.releaseSyncedAtMs = GetGameTimer()

        local vehicle = awaitVehicle(result.netId, 15000)
        if not vehicle then
            notify('Failed to prepare race vehicle.', 'error')
            SKC.SetGameState(GameState.FREEROAM)
            return
        end
        requestVehicleControl(vehicle)
        repairVehicleForRace(vehicle)

        local ped = PlayerPedId()
        local pos = activeRace.gridPos
        SetEntityCoords(vehicle, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(vehicle, pos.w)
        SetVehicleOnGroundProperly(vehicle)
        
        SetEntityMaxHealth(ped, 115)
        SetEntityHealth(ped, 115)
        SetRadarZoom(0)
        DisplayHud(true)
        DisplayRadar(true)
        SKSpeedo.setEnabled(true)

        DoScreenFadeIn(500)
        Wait(1000)
        FreezeEntityPosition(vehicle, true)
        runSyncedCountdown(activeRace.releaseInMs, activeRace.releaseSyncedAtMs)
        while activeRace and not activeRace.goReceived do
            Wait(0)
        end
        if SKC.GetGameState() ~= GameState.MULTIPLAYER_EVENT or not activeRace then return end
        FreezeEntityPosition(vehicle, false)
        SendNUIMessage({ type = 'event:countdown', count = 0 })

        local timerPayload = {
            type              = 'event:timerStart',
            goalTime          = activeRace.def.goalTime,
            checkpointCurrent = 1,
            checkpointTotal   = #activeRace.checkpoints,
        }
        if activeRace.def.scheme == CheckpointScheme.CIRCUIT then
            timerPayload.lapCurrent = 1
            timerPayload.lapTotal   = activeRace.lapTotal
        end
        SendNUIMessage(timerPayload)

        SendNUIMessage({
            type = 'mp:standingsShow',
            entries = {},
            totalPlayers = #activeRace.roster,
        })

        local race = activeRace
        local elapsed = runRaceCheckpointLoop(race, ped)

        if SKC.GetGameState() ~= GameState.MULTIPLAYER_EVENT then return end

        SendNUIMessage({ type = 'event:timerStop' })

        if activeRace.forfeited then
            return
        end

        activeRace.finished = true
        activeRace.awaitingResults = true
        local elapsedMs = math.floor(elapsed * 1000)
        activeRace.elapsedMs = elapsedMs
        lib.callback.await('streetkings:mp:finish', false, elapsedMs)

        notify('Finished. Waiting for others...', 'info')
    end)
end

---@param nextState string
local function onRaceExit(nextState)
    SKNametags.stop()
    clearActiveRaceUi()
    SKWaypoint.RemoveAll()
    activeVehicleNetId = nil
    SKSpeedo.setEnabled(false)
    TriggerEvent('streetkings:nitrous:setMultiplayerRaceDisabled', false)
    TriggerEvent('streetkings:environment:setMultiplayerTrafficDensity', nil)
    SetTimeScale(1.0)
    if SKPhone.isOpen() then SKPhone.close() end
    if not IsScreenFadedIn() then DoScreenFadeIn(500) end
    DisplayRadar(true)
    DisplayHud(true)
    activeRace = nil
end

local function computeStandings()
    if not activeRace then return {} end

    local myServerId = GetPlayerServerId(PlayerId())
    local entries = {}
    for _, entry in ipairs(activeRace.roster) do
        local src = entry.source
        local snap = activeRace.peerSnapshots[src]
        local cpIndex = snap and snap.cpIndex or 0
        local distToNextCp = snap and snap.distToNextCp or 999999
        local finished = snap and snap.finished or false
        local forfeited = snap and snap.forfeited or false
        local elapsedMs = snap and snap.elapsedMs or nil

        if src == myServerId then
            cpIndex = activeRace.myCpIndex
            local nextCp = activeRace.checkpoints[cpIndex + 1] or activeRace.checkpoints[cpIndex]
            if nextCp then
                local ped = PlayerPedId()
                local p = GetEntityCoords(ped)
                local dx = p.x - nextCp.x
                local dy = p.y - nextCp.y
                local dz = p.z - nextCp.z
                distToNextCp = math.sqrt(dx * dx + dy * dy + dz * dz)
            end
            finished = activeRace.finished
            forfeited = activeRace.forfeited
            elapsedMs = activeRace.elapsedMs
        else
            local targetPlayer = GetPlayerFromServerId(src)
            if targetPlayer ~= -1 then
                local targetPed = GetPlayerPed(targetPlayer)
                if targetPed ~= 0 and DoesEntityExist(targetPed) then
                    local nextCp = activeRace.checkpoints[cpIndex + 1]
                    if nextCp then
                        local p = GetEntityCoords(targetPed)
                        local dx = p.x - nextCp.x
                        local dy = p.y - nextCp.y
                        local dz = p.z - nextCp.z
                        distToNextCp = math.sqrt(dx * dx + dy * dy + dz * dz)
                    end
                end
            end
        end

        entries[#entries + 1] = {
            source = src,
            alias = entry.alias,
            cpIndex = cpIndex,
            cpTotal = #activeRace.checkpoints,
            distToNextCp = distToNextCp,
            finished = finished,
            forfeited = forfeited,
            elapsedMs = elapsedMs,
            isSelf = src == myServerId,
        }
    end

    table.sort(entries, function(a, b)
        if a.forfeited ~= b.forfeited then return not a.forfeited end
        if a.finished ~= b.finished then return a.finished end
        if a.cpIndex ~= b.cpIndex then return a.cpIndex > b.cpIndex end
        return a.distToNextCp < b.distToNextCp
    end)

    return entries
end

local function onRaceTick()
    if not activeRace then return end
    local vehicle = getCurrentMultiplayerVehicle()
    if vehicle and DoesEntityExist(vehicle) then
        SKVehicleLock.tick(vehicle, function() return false end)
    end

    if not raceDeathHandled and IsEntityDead(PlayerPedId()) then
        handleRaceDeath()
        return
    end

    if raceDeathHandled then
        return
    end

    applyRaceVehicleNoCollision()
    local now = GetGameTimer()
    if (now - lastStandingsUpdateMs) < STANDINGS_UPDATE_INTERVAL_MS then return end
    lastStandingsUpdateMs = now

    local entries = computeStandings()
    SendNUIMessage({
        type = 'mp:standingsUpdate',
        entries = entries,
        totalPlayers = #activeRace.roster,
    })
end

-- Public API ------------------------------------------------------------

---@param eventId string
---@param options table|nil
function SKMultiplayer.hostRace(eventId, options)
    if SKC.GetGameState() ~= GameState.FREEROAM then return end
    if SKPolice.hasWantedLevel() then
        SKPolice.notifyAccessBlockedByWantedLevel()
        return
    end
    CreateThread(function()
        local result = lib.callback.await('streetkings:events:createRaceLobby', false, eventId, options)
        if not result or result.ok ~= true then
            notify('Could not open lobby: ' .. tostring(result and result.reason or 'unknown'), 'error')
            return
        end

        result.lobby._clientSyncedAtMs = GetGameTimer()
        activeLobby = result.lobby
        SKC.SetGameState(GameState.MULTIPLAYER_LOBBY)
    end)
end

---@param lobbyId string
function SKMultiplayer.joinLobbyFromMessage(lobbyId)
    if not canInitiateMultiplayerJoin() then return end
    CreateThread(function()
        local result = lib.callback.await('streetkings:events:joinRaceLobby', false, lobbyId)
        if not result or result.ok ~= true then
            local reason = result and result.reason or 'unknown'
            local msg = 'Could not join lobby.'
            if reason == 'class_mismatch' then
                msg = ('Class mismatch: host requires %s.'):format(result.hostClass or '—')
            elseif reason == 'lobby_full' then
                msg = 'Lobby is full.'
            elseif reason == 'lobby_missing' or reason == 'lobby_started' then
                msg = 'That lobby is no longer available.'
            elseif reason == 'no_active_vehicle' then
                msg = 'No active vehicle.'
            end
            notify(msg, 'error')
            return
        end
        result.lobby._clientSyncedAtMs = GetGameTimer()
        activeLobby = result.lobby
        if SKPhone.isOpen() then
            SKPhone.close()
        end
        SKC.SetGameState(GameState.MULTIPLAYER_LOBBY)
    end)
end

function SKMultiplayer.leaveLobby()
    if SKC.GetGameState() ~= GameState.MULTIPLAYER_LOBBY then return end
    CreateThread(function()
        lib.callback.await('streetkings:events:leaveRaceLobby', false)
        SKC.SetGameState(GameState.FREEROAM)
    end)
end

---@return table|nil
function SKMultiplayer.getLobbyPhoneState()
    if SKC.GetGameState() ~= GameState.MULTIPLAYER_LOBBY or not activeLobby then
        return nil
    end

    local myServerId = GetPlayerServerId(PlayerId())
    local isHost = activeLobby.hostSource == myServerId
    local playerCount = type(activeLobby.players) == 'table' and #activeLobby.players or 0
    if not isHost or playerCount == 0 then
        return nil
    end

    return {
        eventName = activeLobby.eventName,
        isMultiplayer = true,
        actionMode = playerCount == 1 and 'lobbyHostClose' or 'lobbyHostStart',
        canRecover = true,
        canForfeit = false,
    }
end

function SKMultiplayer.startRaceNow()
    if SKC.GetGameState() ~= GameState.MULTIPLAYER_LOBBY then
        return
    end

    CreateThread(function()
        local result = lib.callback.await('streetkings:events:startRaceNow', false)
        if not result or result.ok ~= true then
            notify('Could not start race.', 'error')
            return
        end
        SKPhone.close()
    end)
end

---@return boolean
function SKMultiplayer.requestForfeit()
    if SKC.GetGameState() ~= GameState.MULTIPLAYER_EVENT then return false end
    if not activeRace or activeRace.finished or activeRace.forfeited then return false end
    activeRace.forfeited = true
    CreateThread(function()
        local result = lib.callback.await('streetkings:mp:forfeit', false)
        if not result or result.ok ~= true then
            if activeRace then
                activeRace.forfeited = false
            end
            notify('Could not forfeit race.', 'error')
            return
        end

        local claimResult = lib.callback.await('streetkings:mp:claimRaceReturn', false)
        pendingSeamlessReturn = claimResult ~= nil and claimResult.seamless == true
        pendingSeamlessReturnVehicleNetId = pendingSeamlessReturn and (claimResult.netId or activeVehicleNetId) or nil
        SKC.SetGameState(GameState.FREEROAM)
    end)
    return true
end

---@return table|nil
function SKMultiplayer.getPhoneState()
    if SKC.GetGameState() ~= GameState.MULTIPLAYER_EVENT or not activeRace then return nil end
    return {
        eventName = activeRace.eventName,
        canRecover = false,
        canForfeit = not activeRace.finished and not activeRace.forfeited,
        isMultiplayer = true,
        forfeitCost = SKEventsConfig.MULTIPLAYER_FORFEIT_COST,
    }
end

RegisterNUICallback('phone:multiplayerLobby:close', function(_, cb)
    cb({})
    SKPhone.close()
    SKMultiplayer.leaveLobby()
end)

RegisterNUICallback('phone:multiplayerLobby:startNow', function(_, cb)
    cb({})
    SKMultiplayer.startRaceNow()
end)

-- Net events ------------------------------------------------------------

RegisterNetEvent('streetkings:mp:lobbyUpdate', function(payload)
    if not payload then return end
    payload._clientSyncedAtMs = GetGameTimer()
    activeLobby = payload
    if SKC.GetGameState() == GameState.MULTIPLAYER_LOBBY then
        pushLobbyHud()
    end
end)

RegisterNetEvent('streetkings:mp:lobbyClosed', function(payload)
    local reason = payload and payload.reason or 'closed'
    local state = SKC.GetGameState()
    if state == GameState.MULTIPLAYER_LOBBY then
        if reason == 'expired' then
            notify('Lobby expired.', 'warning')
        elseif reason == 'finished' then
            -- no-op; results flow handles exit
            return
        else
            notify('Lobby closed.', 'info')
        end
        activeLobby = nil
        pendingSeamlessReturn = payload and payload.seamless == true
        pendingSeamlessReturnVehicleNetId = nil
        SKC.SetGameState(GameState.FREEROAM)
    end
end)

---@return { seamless: boolean, vehicleNetId: integer|nil }
function SKMultiplayer.consumePendingSeamlessReturn()
    local result = {
        seamless = pendingSeamlessReturn,
        vehicleNetId = pendingSeamlessReturnVehicleNetId,
    }
    pendingSeamlessReturn = false
    pendingSeamlessReturnVehicleNetId = nil
    return result
end

RegisterNetEvent('streetkings:mp:raceStarting', function(data)
    if SKC.GetGameState() ~= GameState.MULTIPLAYER_LOBBY then return end
    if not data or type(data.lobbyId) ~= 'string' then return end
    enterRace(data)
    waitingForRaceStart = true
    SKC.SetGameState(GameState.MULTIPLAYER_EVENT)
    waitingForRaceStart = false
end)

RegisterNetEvent('streetkings:mp:raceGo', function()
    if SKC.GetGameState() ~= GameState.MULTIPLAYER_EVENT or not activeRace then return end
    activeRace.goReceived = true
end)

RegisterNetEvent('streetkings:mp:positions', function(snapshots)
    if not activeRace or type(snapshots) ~= 'table' then return end
    for _, s in ipairs(snapshots) do
        if type(s) == 'table' and type(s.source) == 'number' then
            activeRace.peerSnapshots[s.source] = s
        end
    end
end)

RegisterNetEvent('streetkings:mp:raceResults', function(payload)
    if not payload then return end
    CreateThread(function()
        if SKC.GetGameState() ~= GameState.MULTIPLAYER_EVENT then return end

        DoScreenFadeOut(500)
        Wait(550)
        DoScreenFadeIn(500)
        while not IsScreenFadedIn() do Wait(0) end

        SendNUIMessage({ type = 'mp:standingsHide' })

        local my = payload.myResult
        local myPos = my and my.position or 0
        local totalPlayers = payload.totalPlayers or #payload.results
        local elapsedSec = my and my.elapsedMs and (my.elapsedMs / 1000.0) or nil
        local didNotFinish = my and (my.forfeited or my.dnf) or false

        SendNUIMessage({
            type        = 'event:results',
            name        = payload.eventName,
            elapsed     = elapsedSec,
            dnf         = my and my.dnf == true or false,
            forfeited   = my and my.forfeited == true or false,
            passed      = my and not didNotFinish or nil,
            verdict     = my and my.dnf and 'DNF'
                or (my and my.forfeited and 'FORFEITED')
                or (myPos == 1 and 'VICTORY' or ('P' .. tostring(myPos))),
            reward      = my and my.reward or nil,
            vehicleClass = payload.vehicleClass,
            continueKey  = SKInput.getInteractLabel(),
        })

        local entries = {}
        for _, r in ipairs(payload.results) do
            entries[#entries + 1] = {
                rank  = r.position,
                alias = r.alias,
                score = r.elapsedMs,
                dnf = r.dnf == true,
                forfeited = r.forfeited == true,
                isSelf = r.source == GetPlayerServerId(PlayerId()),
                vehicleModel = r.vehicleModel or '',
            }
        end
        SendNUIMessage({
            type         = 'event:leaderboard',
            entries      = entries,
            personalBest = my and my.elapsedMs or nil,
            period       = LeaderboardPeriod.ALL,
            scoreType    = 'time',
            eventId      = payload.eventId,
            vehicleClass = payload.vehicleClass,
        })

        local continueKey = SKInput.getInteractLabel()
        while not SKInput.isInteractJustReleased() do
            local nextContinueKey = SKInput.getInteractLabel()
            if nextContinueKey ~= continueKey then
                continueKey = nextContinueKey
                SendNUIMessage({ type = 'event:updateContinueKey', continueKey = continueKey })
            end
            Wait(0)
        end

        SendNUIMessage({ type = 'event:hide' })
        local claimResult = lib.callback.await('streetkings:mp:claimRaceReturn', false)
        pendingSeamlessReturn = claimResult ~= nil and claimResult.seamless == true
        pendingSeamlessReturnVehicleNetId = pendingSeamlessReturn and (claimResult.netId or activeVehicleNetId) or nil
        SKC.SetGameState(GameState.FREEROAM)
    end)
end)

-- Register states ------------------------------------------------------

SKC.RegisterGameState(GameState.MULTIPLAYER_LOBBY, {
    onEnter = onLobbyEnter,
    onExit  = onLobbyExit,
    onTick  = onLobbyTick,
    tickWait = 0,
})

SKC.RegisterGameState(GameState.MULTIPLAYER_EVENT, {
    onEnter = onRaceEnter,
    onExit  = onRaceExit,
    onTick  = onRaceTick,
    tickWait = 0,
})