SKObjectives = SKObjectives or {}

local CHECKPOINT_RADIUS = 20.0
local NPC_CP_RADIUS     = 25.0
local RETASK_INTERVAL   = 3000
local RACE_TIMEOUT      = 300000
local RUBBERBAND_GAP    = 3
local COUNTDOWN_COUNTS  = { 3, 2, 1 }

local raceActive = false

---@param playerVeh integer
---@param npcVeh integer
local function runCountdown(playerVeh, npcVeh)
    FreezeEntityPosition(playerVeh, true)
    FreezeEntityPosition(npcVeh, true)
    SetVehicleHandbrake(playerVeh, true)
    SetVehicleHandbrake(npcVeh, true)

    SKNotify({ title = 'Race Starting!', type = 'info', duration = 2000 })
    Wait(1500)

    for _, count in ipairs(COUNTDOWN_COUNTS) do
        SendNUIMessage({ type = 'event:countdown', count = count })
        PlaySoundFrontend(-1, 'CHECKPOINT_UNDER_THE_BRIDGE', 'HUD_MINI_GAME_SOUNDSET', true)
        Wait(1000)
    end

    SendNUIMessage({ type = 'event:countdown', count = 0 })
    PlaySoundFrontend(-1, 'CHECKPOINT_AHEAD', 'HUD_MINI_GAME_SOUNDSET', true)
    StartVehicleHorn(npcVeh, 1500, GetHashKey('HELDDOWN'), false)

    FreezeEntityPosition(npcVeh, false)
    FreezeEntityPosition(playerVeh, false)
    SetVehicleHandbrake(npcVeh, false)
    SetVehicleHandbrake(playerVeh, false)
end

local handler = {}

local activeState = nil

local function cleanupRace()
    if not activeState then return end
    local s = activeState

    if s.npcBlip and DoesBlipExist(s.npcBlip) then RemoveBlip(s.npcBlip) end
    SKEventPreview.clearCheckpoint(s.checkpoint, s.cpBlip, s.cpBlipNext)

    SKWaypoint.RemoveAll()
    SKEventPreview.clearGpsTrack()

    if s.npcPed and DoesEntityExist(s.npcPed) then
        ClearPedTasksImmediately(s.npcPed)
        SetEntityAsMissionEntity(s.npcPed, false, true)
        SetEntityAsNoLongerNeeded(s.npcPed)
    end
    if s.npcVeh and DoesEntityExist(s.npcVeh) then
        SetEntityAsMissionEntity(s.npcVeh, false, true)
        SetEntityAsNoLongerNeeded(s.npcVeh)
    end

    raceActive = false
    activeState = nil
end

---@param obj table
---@return table|nil, table|nil
local function getTrackData(obj)
    local trackId = obj.trackId
    if type(trackId) ~= 'string' or not SKEvents then return nil, nil end
    local track = SKEvents[trackId]
    if not track or not track.start or not track.checkpoints then return nil, nil end
    return track.start, track.checkpoints
end

---@param coords vector4
---@param opponent table
---@return integer, integer
local function spawnOpponentAt(coords, opponent)
    local vehHash = SK.LoadModel(opponent.vehicleModel or 'elegy', 8000)
    if not vehHash then return 0, 0 end

    local pedHash = SK.LoadModel(opponent.pedModel or 'a_m_y_hipster_02', 8000)
    if not pedHash then
        SK.UnloadModel(vehHash)
        return 0, 0
    end

    local veh = CreateVehicle(vehHash, coords.x, coords.y, coords.z, coords.w, true, false)
    SK.UnloadModel(vehHash)
    if veh == 0 then return 0, 0 end

    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleDoorsLocked(veh, 2)

    local ped = CreatePed(4, pedHash, coords.x, coords.y, coords.z, coords.w, true, false)
    SK.UnloadModel(pedHash)
    if ped == 0 then
        DeleteEntity(veh)
        return 0, 0
    end
    SetPedDefaultComponentVariation(ped)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedIntoVehicle(ped, veh, -1)
    SetEntityInvincible(ped, true)
    SetEntityInvincible(veh, true)

    local group = GetHashKey('YOURTEAM_MSNRACE')
    AddRelationshipGroup('YOURTEAM_MSNRACE')
    SetPedRelationshipGroupHash(ped, group)
    SetRelationshipBetweenGroups(1, group, GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(1, GetHashKey('PLAYER'), group)

    return veh, ped
end

---@param start vector4
---@param opponent table
---@return integer, integer
local function spawnOpponent(start, opponent)
    if opponent.spawnCoords then
        return spawnOpponentAt(opponent.spawnCoords, opponent)
    end

    local offsetRight = GetEntityForwardVector(PlayerPedId())
    local sx = start.x + offsetRight.y * 4.0
    local sy = start.y - offsetRight.x * 4.0
    local coords = vector4(sx, sy, start.z, start.w)
    return spawnOpponentAt(coords, opponent)
end

local function showCheckpoint(cpCoords, nextCoords, isLast)
    SKEventPreview.clearCheckpoint(activeState.checkpoint, activeState.cpBlip, activeState.cpBlipNext)
    activeState.checkpoint, activeState.cpBlip, activeState.cpBlipNext =
        SKEventPreview.createCheckpoint(cpCoords, nextCoords, isLast, true)

    if activeState.waypointId then SKWaypoint.Remove(activeState.waypointId) end
    activeState.waypointId = SKWaypoint.Create({
        coords     = cpCoords,
        text       = isLast and 'FINISH' or 'CHECKPOINT',
        color      = '#ffd147',
        icon       = isLast and 'flag-checkered' or 'circle-dot',
        showDist   = true,
    })
end

---@param ctx table
---@param start vector4
---@param checkpoints table
---@return boolean
local function runRace(ctx, start, checkpoints)
    local obj = ctx.objective
    local opponent = obj.opponent or {}

    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if playerVeh == 0 then
        SKNotify({ title = 'Get in a vehicle first!', type = 'warning' })
        return false
    end

    raceActive = true

    local npcVeh, npcPed
    if ctx.preSpawnedVeh and DoesEntityExist(ctx.preSpawnedVeh) then
        npcVeh = ctx.preSpawnedVeh
        npcPed = ctx.preSpawnedPed
        ctx.preSpawnedVeh = nil
        ctx.preSpawnedPed = nil
    else
        npcVeh, npcPed = spawnOpponent(start, opponent)
    end

    if npcVeh == 0 then
        SKNotify({ title = 'Failed to spawn opponent', type = 'error' })
        raceActive = false
        return false
    end

    activeState = {
        npcVeh = npcVeh,
        npcPed = npcPed,
        cpBlip = nil,
        cpBlipNext = nil,
        npcBlip = nil,
        checkpoint = nil,
        waypointId = nil,
    }

    activeState.npcBlip = AddBlipForEntity(npcVeh)
    SetBlipSprite(activeState.npcBlip, 225)
    SetBlipColour(activeState.npcBlip, 47)
    SetBlipScale(activeState.npcBlip, 1.0)

    runCountdown(playerVeh, npcVeh)

    local driveSpeed = opponent.driveSpeed or 80.0
    local driveFlags = opponent.driveFlags or 786468
    local npcCpIdx = 1
    local playerCpIdx = 1
    local totalCps = #checkpoints

    showCheckpoint(checkpoints[1], checkpoints[2], totalCps == 1)

    TaskVehicleDriveToCoordLongrange(
        npcPed, npcVeh,
        checkpoints[1].x, checkpoints[1].y, checkpoints[1].z,
        driveSpeed, driveFlags, 5.0
    )

    local raceStart  = GetGameTimer()
    local lastRetask = raceStart
    local won = nil

    while won == nil and raceActive do
        Wait(0)
        local ped = PlayerPedId()

        local gs = SKC.GetGameState()
        if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then
            cleanupRace()
            lib.callback.await('streetkings:missions:resetMission', false)
            return false
        end

        if not IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
            SKNotify({ title = 'Race Forfeited! Mission restarting...', type = 'error', duration = 4000 })
            Wait(2000)
            cleanupRace()
            lib.callback.await('streetkings:missions:resetMission', false)
            return false
        end

        local now = GetGameTimer()
        local playerPos = GetEntityCoords(ped)
        local npcPos = GetEntityCoords(npcPed)

        if playerCpIdx <= totalCps and #(playerPos - checkpoints[playerCpIdx]) < CHECKPOINT_RADIUS then
            playerCpIdx = playerCpIdx + 1
            if playerCpIdx <= totalCps then
                showCheckpoint(checkpoints[playerCpIdx], checkpoints[playerCpIdx + 1], playerCpIdx == totalCps)
                SKSettings.playSelectedCheckpointSound()
            else
            end
        end

        if npcCpIdx <= totalCps and #(npcPos - checkpoints[npcCpIdx]) < NPC_CP_RADIUS then
            npcCpIdx = npcCpIdx + 1
            if npcCpIdx <= totalCps then
                TaskVehicleDriveToCoordLongrange(
                    npcPed, npcVeh,
                    checkpoints[npcCpIdx].x, checkpoints[npcCpIdx].y, checkpoints[npcCpIdx].z,
                    driveSpeed, driveFlags, 5.0
                )
                lastRetask = now
            end
        end

        if (now - lastRetask) > RETASK_INTERVAL and npcCpIdx <= totalCps then
            TaskVehicleDriveToCoordLongrange(
                npcPed, npcVeh,
                checkpoints[npcCpIdx].x, checkpoints[npcCpIdx].y, checkpoints[npcCpIdx].z,
                driveSpeed, driveFlags, 5.0
            )
            lastRetask = now
        end

        local gap = playerCpIdx - npcCpIdx
        if gap >= RUBBERBAND_GAP and npcCpIdx <= totalCps then
            local warpIdx = math.max(1, playerCpIdx - 2)
            if warpIdx <= totalCps then
                local warpCp = checkpoints[warpIdx]
                SetEntityCoords(npcVeh, warpCp.x, warpCp.y, warpCp.z, false, false, false, false)
                SetVehicleOnGroundProperly(npcVeh)
                npcCpIdx = warpIdx
                TaskVehicleDriveToCoordLongrange(
                    npcPed, npcVeh,
                    checkpoints[npcCpIdx].x, checkpoints[npcCpIdx].y, checkpoints[npcCpIdx].z,
                    driveSpeed, driveFlags, 5.0
                )
                lastRetask = now
            end
        end

        if playerCpIdx > totalCps then
            won = true
        elseif npcCpIdx > totalCps then
            won = false
        elseif (now - raceStart) > RACE_TIMEOUT then
            won = false
        end
    end

    if won == nil then
        cleanupRace()
        return false
    end

    Wait(250)

    if won then
        SKNotify({ title = 'You Win!', type = 'success', duration = 4000 })
    else
        SKNotify({ title = 'You Lost! Mission restarting...', type = 'error', duration = 4000 })
    end

    Wait(1500)
    cleanupRace()

    if not won then
        lib.callback.await('streetkings:missions:resetMission', false)
    end

    return won
end

function handler.start(ctx)
    local obj = ctx.objective
    local start, checkpoints = getTrackData(obj)
    if not start or not checkpoints then
        SKNotify({ title = 'Track data missing!', type = 'error' })
        return nil
    end

    local startCoords = vector3(start.x, start.y, start.z)
    local opponent = obj.opponent or {}

    local interactionBlip = nil
    local interactionPoint = nil
    local interactionInner = nil
    local promptShown = false
    local raceWon = false

    SKMissionShared = SKMissionShared or {}
    if opponent.usePreSpawned and SKMissionShared.preSpawnedVeh and DoesEntityExist(SKMissionShared.preSpawnedVeh) then
        ctx.preSpawnedVeh = SKMissionShared.preSpawnedVeh
        ctx.preSpawnedPed = SKMissionShared.preSpawnedPed
        SKMissionShared.preSpawnedVeh = nil
        SKMissionShared.preSpawnedPed = nil
    elseif opponent.spawnCoords then
        local npcVeh, npcPed = spawnOpponentAt(opponent.spawnCoords, opponent)
        if npcVeh ~= 0 then
            ctx.preSpawnedVeh = npcVeh
            ctx.preSpawnedPed = npcPed
            SetVehicleEngineOn(npcVeh, true, true, false)
        end
    end

    if obj.autoStart then
        ctx._cleanup = function()
            if ctx.preSpawnedPed and DoesEntityExist(ctx.preSpawnedPed) then SetEntityAsMissionEntity(ctx.preSpawnedPed, false, true) DeleteEntity(ctx.preSpawnedPed) end
            if ctx.preSpawnedVeh and DoesEntityExist(ctx.preSpawnedVeh) then SetEntityAsMissionEntity(ctx.preSpawnedVeh, false, true) DeleteEntity(ctx.preSpawnedVeh) end
            ctx.preSpawnedVeh = nil
            ctx.preSpawnedPed = nil
            cleanupRace()
        end

        CreateThread(function()
            Wait(300)
            local won = runRace(ctx, start, checkpoints)
            if won then
                local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'scripted_race' })
                if not result or not result.ok then
                    SKNotify({ title = 'Failed to advance mission', type = 'error' })
                end
            end
        end)

        return {
            remove = function()
                if ctx._cleanup then ctx._cleanup() end
            end,
        }
    end

    local function setupInteraction()
        if interactionBlip and DoesBlipExist(interactionBlip) then RemoveBlip(interactionBlip) end
        if interactionPoint and interactionPoint.remove then interactionPoint:remove() end
        if interactionInner and interactionInner.remove then interactionInner:remove() end

        interactionBlip = AddBlipForCoord(startCoords.x, startCoords.y, startCoords.z)
        SetBlipSprite(interactionBlip, 315)
        SetBlipColour(interactionBlip, 66)
        SetBlipRoute(interactionBlip, true)
        SetBlipRouteColour(interactionBlip, 66)
        SetBlipAsShortRange(interactionBlip, false)

        interactionPoint = lib.points.new({
            coords = startCoords,
            distance = 60.0,
            nearby = function()
                DrawMarker(
                    1,
                    startCoords.x, startCoords.y, startCoords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    3.0, 3.0, 1.5,
                    255, 210, 0, 100,
                    false, true, 2, false, nil, nil, false
                )
            end,
        })

        interactionInner = lib.points.new({
            coords = startCoords,
            distance = 5.0,
            onEnter = function()
                promptShown = true
                SendNUIMessage({ type = 'prompt:show', key = SKInput.getInteractLabel(), text = 'Start Race' })
            end,
            onExit = function()
                promptShown = false
                SendNUIMessage({ type = 'prompt:hide' })
            end,
            nearby = function()
                if raceActive then return end
                local key = SKInput.getInteractLabel()
                SendNUIMessage({ type = 'prompt:show', key = key, text = raceWon and 'Race Complete' or 'Start Race' })
                promptShown = true

                if not raceWon and SKInput.isInteractJustReleased() then
                    SendNUIMessage({ type = 'prompt:hide' })
                    promptShown = false

                    local won = runRace(ctx, start, checkpoints)
                    if won then
                        raceWon = true
                        if interactionBlip and DoesBlipExist(interactionBlip) then RemoveBlip(interactionBlip) end
                        if interactionPoint and interactionPoint.remove then interactionPoint:remove() end
                        if interactionInner and interactionInner.remove then interactionInner:remove() end
                        interactionBlip = nil
                        interactionPoint = nil
                        interactionInner = nil

                        local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'scripted_race' })
                        if not result or not result.ok then
                            SKNotify({ title = 'Failed to advance mission', type = 'error' })
                        end
                    end
                end
            end,
        })
    end

    setupInteraction()

    ctx._cleanup = function()
        SendNUIMessage({ type = 'prompt:hide' })
        if interactionBlip and DoesBlipExist(interactionBlip) then RemoveBlip(interactionBlip) end
        if interactionPoint and interactionPoint.remove then interactionPoint:remove() end
        if interactionInner and interactionInner.remove then interactionInner:remove() end
        if ctx.preSpawnedPed and DoesEntityExist(ctx.preSpawnedPed) then SetEntityAsMissionEntity(ctx.preSpawnedPed, false, true) DeleteEntity(ctx.preSpawnedPed) end
        if ctx.preSpawnedVeh and DoesEntityExist(ctx.preSpawnedVeh) then SetEntityAsMissionEntity(ctx.preSpawnedVeh, false, true) DeleteEntity(ctx.preSpawnedVeh) end
        ctx.preSpawnedVeh = nil
        ctx.preSpawnedPed = nil
        cleanupRace()
    end

    return {
        remove = function()
            if ctx._cleanup then ctx._cleanup() end
        end,
    }
end

function handler.stop(ctx)
    if ctx._cleanup then ctx._cleanup() end
end

SKObjectives[ObjectiveType.SCRIPTED_RACE] = handler
