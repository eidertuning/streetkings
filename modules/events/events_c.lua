local activeEventId    = nil
local activeEventVehicleClass = ''
local activeEventVehicle = nil
local activeEventIsMultiplayer = false
local activeRecoveryPoint = nil
local activeCheckpoint = nil
local activeBlip       = nil
local activeBlipNext   = nil
local activeWaypointId = nil
local timerStarted     = false
local CHECKPOINT_PICKUP_RADIUS = 20.0

local RACE_BLIP_CAT_SPRINT      = 12
local RACE_BLIP_CAT_CIRCUIT     = 13
local RACE_BLIP_CAT_DELIVERY    = 14
local RACE_BLIP_CAT_CHECKPOINT  = 15
local RACE_BLIP_CAT_RAMPAGE     = 17
local RACE_BLIP_LABEL_SPRINT    = 'Sprint Races'
local RACE_BLIP_LABEL_CIRCUIT   = 'Circuit Races'
local RACE_BLIP_LABEL_DELIVERY  = 'Delivery Events'
local RACE_BLIP_NAME_CHECKPOINT = 'Race Checkpoint'
local RACE_BLIP_LABEL_RAMPAGE   = 'Rampage Events'
local blipCategoriesRegistered  = false

local function registerBlipCategories()
    if blipCategoriesRegistered then return end
    blipCategoriesRegistered = true

    AddTextEntry(('BLIP_CAT_%d'):format(RACE_BLIP_CAT_SPRINT), RACE_BLIP_LABEL_SPRINT)
    AddTextEntry(('BLIP_CAT_%d'):format(RACE_BLIP_CAT_CIRCUIT), RACE_BLIP_LABEL_CIRCUIT)
    AddTextEntry(('BLIP_CAT_%d'):format(RACE_BLIP_CAT_DELIVERY), RACE_BLIP_LABEL_DELIVERY)
    AddTextEntry(('BLIP_CAT_%d'):format(RACE_BLIP_CAT_CHECKPOINT), RACE_BLIP_NAME_CHECKPOINT)
    AddTextEntry(('BLIP_CAT_%d'):format(RACE_BLIP_CAT_RAMPAGE), RACE_BLIP_LABEL_RAMPAGE)
end

---@param blip integer
---@param blipName string
---@param category integer
local function setBlipLegendGroup(blip, blipName, category)
    registerBlipCategories()
    SetBlipCategory(blip, category)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipName)
    EndTextCommandSetBlipName(blip)
end

-- Checkpoint visuals --------------------------------------------------------

--- Create or replace the active world checkpoint and minimap blip.
---@param current vector3
---@param nextCp vector3|nil  nil on the final checkpoint
---@param isLast boolean
local function showCheckpoint(current, nextCp, isLast)
    SKEventPreview.clearCheckpoint(activeCheckpoint, activeBlip, activeBlipNext)
    activeCheckpoint, activeBlip, activeBlipNext = SKEventPreview.createCheckpoint(current, nextCp, isLast, true)
    setBlipLegendGroup(activeBlip, RACE_BLIP_NAME_CHECKPOINT, RACE_BLIP_CAT_CHECKPOINT)

    if activeWaypointId then SKWaypoint.Remove(activeWaypointId) end
    activeWaypointId = SKWaypoint.Create({
        coords     = current,
        text       = isLast and 'FINISH' or 'CHECKPOINT',
        color      = '#ffd200',
        icon       = isLast and 'flag-checkered' or 'circle-dot',
        showDist   = true,
        groundBeam = true,
    })
end

--- Show all checkpoints at once (unordered scheme).
---@param checkpoints vector3[]
---@param authoredIndices integer[]
---@param authoredTotal integer
---@return integer[] cpHandles
---@return integer[] blipHandles
local function showAllCheckpoints(checkpoints, authoredIndices, authoredTotal)
    local cpHandles, blipHandles = SKEventPreview.showAllCheckpoints(checkpoints, authoredIndices, authoredTotal)
    for _, blipHandle in ipairs(blipHandles) do
        setBlipLegendGroup(blipHandle, RACE_BLIP_NAME_CHECKPOINT, RACE_BLIP_CAT_CHECKPOINT)
    end
    return cpHandles, blipHandles
end

--- Remove all remaining checkpoint handles and blip handles.
---@param cpHandles integer[]
---@param blipHandles integer[]
local function clearAllCheckpoints(cpHandles, blipHandles)
    SKEventPreview.clearCheckpointSet(cpHandles, blipHandles)
end

-- Event lifecycle -----------------------------------------------------------

---@return boolean
local function shouldRenderWholeRouteGps()
    return SKSettings.getMapWaypointMode() == 'wholeRoute'
end

---@param def table
---@param checkpointCurrent integer
---@param checkpointTotal integer
local function sendEventProgress(def, checkpointCurrent, checkpointTotal)
    local payload = {
        type = 'event:updateProgress',
        checkpointCurrent = checkpointCurrent,
        checkpointTotal   = checkpointTotal,
    }

    if def.type == EventType.RACE and def.scheme == CheckpointScheme.CIRCUIT then
        payload.lapCurrent = 1
        payload.lapTotal   = 1
    end

    SendNUIMessage(payload)
end

--- Clean up any active checkpoint / blip created during the event.
local function cleanupActive()
    if activeEventId then
        TriggerServerEvent('streetkings:events:cancelRun', activeEventId)
    end
    SKEventPreview.clearCheckpoint(activeCheckpoint, activeBlip, activeBlipNext)
    activeCheckpoint = nil
    activeBlip = nil
    activeBlipNext = nil
    SKWaypoint.RemoveAll()
    activeWaypointId = nil
    SKEventPreview.clearGpsTrack()
    timerStarted = false
    activeEventVehicle = nil
    activeEventIsMultiplayer = false
    activeRecoveryPoint = nil
    SetTimeScale(1.0)
end

---@param vehicle integer
local function repairEventVehicle(vehicle)
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
end

---@param coords vector3
---@param heading number
local function setRecoveryPoint(coords, heading)
    activeRecoveryPoint = {
        coords = coords,
        heading = heading,
    }
end

---@param from vector3
---@param to vector3
---@param fallbackHeading number
---@return number
local function headingToward(from, to, fallbackHeading)
    local dx = to.x - from.x
    local dy = to.y - from.y
    if dx == 0.0 and dy == 0.0 then
        return fallbackHeading
    end
    return GetHeadingFromVector_2d(dx, dy)
end

---@return boolean
local function canUseEventPhone()
    return SKC.GetGameState() == GameState.EVENT and timerStarted and activeEventId ~= nil and activeRecoveryPoint ~= nil
end

---@return table|nil
function SKEvents.getPhoneState()
    if not canUseEventPhone() then
        return nil
    end

    local def = SKEvents[activeEventId]
    if not def then
        return nil
    end

    return {
        eventName = def.name,
        canRecover = true,
        canForfeit = true,
        isMultiplayer = activeEventIsMultiplayer,
        forfeitCost = activeEventIsMultiplayer and SKEventsConfig.MULTIPLAYER_FORFEIT_COST or nil,
    }
end

---@return boolean
function SKEvents.recoverToLastCheckpoint()
    if not canUseEventPhone() then
        return false
    end

    local recoveryPoint = activeRecoveryPoint
    local vehicle = activeEventVehicle
    local ped = PlayerPedId()
    if not recoveryPoint or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    SetEntityCoords(vehicle, recoveryPoint.coords.x, recoveryPoint.coords.y, recoveryPoint.coords.z, false, false, false, false)
    SetEntityHeading(vehicle, recoveryPoint.heading)
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    SetVehicleForwardSpeed(vehicle, 0.0)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityCoords(ped, recoveryPoint.coords.x, recoveryPoint.coords.y, recoveryPoint.coords.z, false, false, false, false)
    SetEntityHeading(ped, recoveryPoint.heading)
    SetGameplayCamRelativeHeading(0.0)
    return true
end

---@return boolean
function SKEvents.forfeitActiveEvent()
    if SKC.GetGameState() == GameState.MULTIPLAYER_EVENT then
        return SKMultiplayer.requestForfeit()
    end

    if SKC.GetGameState() ~= GameState.EVENT or not activeEventId then
        return false
    end

    SKC.SetGameState(GameState.FREEROAM)
    return true
end

--- Run the countdown and unfreeze the vehicle
---@param vehicle integer
local function runCountdown(vehicle)
    for _, count in ipairs({ 3, 2, 1 }) do
        SendNUIMessage({ type = 'event:countdown', count = count })
        PlaySoundFrontend(-1, 'CHECKPOINT_UNDER_THE_BRIDGE', 'HUD_MINI_GAME_SOUNDSET', true)
        Wait(1000)
    end
    SendNUIMessage({ type = 'event:countdown', count = 0 })
    PlaySoundFrontend(-1, 'CHECKPOINT_AHEAD', 'HUD_MINI_GAME_SOUNDSET', true)
    FreezeEntityPosition(vehicle, false)
end

--- Checkpoint loop - returns elapsed seconds when the run is complete
---@param def table
---@param checkpoints vector3[]
---@param ped integer
---@param vehicle integer
---@return number elapsed
local function runSequentialLoop(def, checkpoints, ped, vehicle)
    local startTime = GetGameTimer()
    local total     = #checkpoints

    for i, cp in ipairs(checkpoints) do
        sendEventProgress(def, i, total)
        local from = i == 1 and SKEventRoute.toVector3(def.start) or checkpoints[i - 1]
        local remaining = { from }
        for j = i, total do remaining[#remaining + 1] = checkpoints[j] end
        if shouldRenderWholeRouteGps() then
            SKEventPreview.renderGpsTrack(remaining)
        else
            SKEventPreview.clearGpsTrack()
        end

        local isLast = (i == total)
        local nextCp = checkpoints[i + 1]
        showCheckpoint(cp, nextCp, isLast)

        while true do
            if SKC.GetGameState() ~= GameState.EVENT then
                SKEventPreview.clearGpsTrack()
                return 0
            end
            local pos = GetEntityCoords(ped)
            if #(pos - cp) < CHECKPOINT_PICKUP_RADIUS then
                TriggerServerEvent('streetkings:events:checkpointHit', activeEventId, i)
                TriggerEvent('streetkings:nitrous:checkpointCleared')
                SKSettings.playSelectedCheckpointSound()
                break
            end
            Wait(0)
        end

        if not isLast then
            setRecoveryPoint(cp, headingToward(cp, nextCp, GetEntityHeading(vehicle)))
        end
    end

    SKEventPreview.clearGpsTrack()
    SKEventPreview.clearCheckpoint(activeCheckpoint, activeBlip, activeBlipNext)
    activeCheckpoint = nil
    activeBlip = nil
    activeBlipNext = nil

    return (GetGameTimer() - startTime) / 1000.0
end

--- Unordered checkpoint loop - returns elapsed seconds when all checkpoints have been hit
---@param def table
---@param checkpoints vector3[]
---@param ped integer
---@return number elapsed
local function runUnorderedLoop(def, checkpoints, ped, vehicle)
    local startTime  = GetGameTimer()
    local remaining  = {}
    local remainingRouteIndexes = {}
    local total      = #checkpoints
    for i, cp in ipairs(checkpoints) do
        remaining[i] = cp
        remainingRouteIndexes[i] = i
    end

    sendEventProgress(def, 1, total)
    local lastHit = SKEventRoute.toVector3(def.start)
    if shouldRenderWholeRouteGps() then
        SKEventPreview.renderGpsTrack({ lastHit, table.unpack(remaining) })
    else
        SKEventPreview.clearGpsTrack()
    end
    local cpHandles, blipHandles = showAllCheckpoints(remaining, remainingRouteIndexes, total)

    while #remaining > 0 do
        if SKC.GetGameState() ~= GameState.EVENT then
            clearAllCheckpoints(cpHandles, blipHandles)
            SKEventPreview.clearGpsTrack()
            return 0
        end

        local pos = GetEntityCoords(ped)
        for i = #remaining, 1, -1 do
            if #(pos - remaining[i]) < CHECKPOINT_PICKUP_RADIUS then
                TriggerServerEvent('streetkings:events:checkpointHit', activeEventId, remainingRouteIndexes[i])
                TriggerEvent('streetkings:nitrous:checkpointCleared')
                SKSettings.playSelectedCheckpointSound()
                lastHit = remaining[i]
                setRecoveryPoint(lastHit, GetEntityHeading(vehicle))
                DeleteCheckpoint(cpHandles[i])
                if blipHandles[i] and DoesBlipExist(blipHandles[i]) then
                    RemoveBlip(blipHandles[i])
                end
                table.remove(remaining, i)
                table.remove(remainingRouteIndexes, i)
                table.remove(cpHandles, i)
                table.remove(blipHandles, i)
                if #remaining > 0 then
                    sendEventProgress(def, total - #remaining + 1, total)
                end
                if shouldRenderWholeRouteGps() then
                    SKEventPreview.renderGpsTrack({ lastHit, table.unpack(remaining) })
                else
                    SKEventPreview.clearGpsTrack()
                end
                break
            end
        end
        Wait(0)
    end

    SKEventPreview.clearGpsTrack()
    return (GetGameTimer() - startTime) / 1000.0
end

--- Full event flow: teleport -> countdown -> run -> results -> return to freeroam
---@param def table
local function runEvent(def)
    local ped     = PlayerPedId()
    local vehicle = SKFreeroam.getActiveVehicle()
    activeEventVehicle = vehicle
    setRecoveryPoint(vector3(def.start.x, def.start.y, def.start.z), def.start.w)

    -- Teleport to start
    DoScreenFadeOut(500)
    Wait(550)

    SetEntityCoords(vehicle, def.start.x, def.start.y, def.start.z, false, false, false, false)
    SetEntityHeading(vehicle, def.start.w)
    repairEventVehicle(vehicle)
    FreezeEntityPosition(vehicle, true)
    SetRadarZoom(0)
    DisplayHud(true)
    DisplayRadar(true)

    DoScreenFadeIn(500)
    Wait(500)

    -- Countdown
    runCountdown(vehicle)

    if def.type == EventType.RAMPAGE then
        SKRampage.run(def, vehicle, ped)
        return
    end

    local checkpoints = SKEventRoute.buildCheckpointList(def)

    TriggerServerEvent('streetkings:events:beginRun', activeEventId)

    -- Timer start
    local timerPayload = {
        type              = 'event:timerStart',
        goalTime          = def.goalTime,
        checkpointCurrent = #checkpoints > 0 and 1 or nil,
        checkpointTotal   = #checkpoints > 0 and #checkpoints or nil,
    }
    if def.type == EventType.RACE and def.scheme == CheckpointScheme.CIRCUIT then
        timerPayload.lapCurrent = 1
        timerPayload.lapTotal   = 1
    end
    SendNUIMessage(timerPayload)
    timerStarted = true

    -- Run checkpoints
    local elapsed

    if def.type == EventType.RACE and def.scheme == CheckpointScheme.UNORDERED then
        elapsed = runUnorderedLoop(def, checkpoints, ped, vehicle)
    else
        elapsed = runSequentialLoop(def, checkpoints, ped, vehicle)
    end

    if SKC.GetGameState() ~= GameState.EVENT then return end

    SendNUIMessage({ type = 'event:timerStop' })
    timerStarted = false

    local submitResult = nil
    if elapsed > 0 then
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        submitResult = lib.callback.await('streetkings:events:submitTime', false, activeEventId, math.floor(elapsed * 1000), SK.GetVehicleModelLabel(veh))
    end

    SetTimeScale(0.05)

    local leaderboardData = {}
    local personalBest = nil
    if elapsed > 0 then
        Wait(250)
        leaderboardData = lib.callback.await('streetkings:events:getLeaderboard', false, activeEventId, LeaderboardPeriod.ALL) or {}
        personalBest = lib.callback.await('streetkings:events:getPersonalBest', false, activeEventId)
        activeEventVehicleClass = submitResult and submitResult.vehicleClass or activeEventVehicleClass
    end

    local passed = def.goalTime and (elapsed <= def.goalTime) or nil
    SendNUIMessage({
        type     = 'event:results',
        name     = def.name,
        elapsed  = elapsed,
        goalTime = def.goalTime,
        passed   = passed,
        summary  = submitResult and submitResult.reward and submitResult.reward.summary or '',
        reward   = submitResult and submitResult.reward or nil,
        vehicleClass = submitResult and submitResult.vehicleClass or activeEventVehicleClass,
        claimAwarded = submitResult and submitResult.claimAwarded or false,
        rewardClaimed = submitResult and submitResult.rewardClaimed or false,
        continueKey = SKInput.getInteractLabel(),
    })
    SendNUIMessage({
        type         = 'event:leaderboard',
        entries      = leaderboardData,
        personalBest = personalBest,
        period       = LeaderboardPeriod.ALL,
        scoreType    = 'time',
        eventId      = activeEventId,
        vehicleClass = activeEventVehicleClass,
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

    SetTimeScale(1.0)
    SendNUIMessage({ type = 'event:hide' })
    SKC.SetGameState(GameState.FREEROAM)
end

---@param eventId string
---@param isMultiplayer boolean|nil
local function startEvent(eventId, isMultiplayer)
    local gs = SKC.GetGameState()
    if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then return end
    if not SKEvents[eventId] then return end
    if SKPolice.hasWantedLevel() then
        SKPolice.notifyAccessBlockedByWantedLevel()
        return
    end
    activeEventId = eventId
    activeEventIsMultiplayer = isMultiplayer == true
    SKC.SetGameState(GameState.EVENT)
end

-- Game state ----------------------------------------------------------------

SKC.RegisterGameState(GameState.EVENT, {
    onEnter = function()
        DeleteWaypoint()
        local def = activeEventId and SKEvents[activeEventId]
        if not def then
            print(('[SK:Events] no event def for id=%s — aborting'):format(tostring(activeEventId)))
            CreateThread(function()
                if not IsScreenFadedIn() then DoScreenFadeIn(500) Wait(500) end
                DisplayRadar(true)
                DisplayHud(true)
                SKC.SetGameState(GameState.FREEROAM)
            end)
            return
        end
        CreateThread(function()
            runEvent(def)
        end)
    end,

    onTick = function()
        if activeEventVehicle and DoesEntityExist(activeEventVehicle) then
            SKVehicleLock.tick(activeEventVehicle, function()
                return false
            end)
        end
    end,

    onExit = function()
        cleanupActive()
        if SKPhone.isOpen() then
            SKPhone.close()
        end
        SendNUIMessage({ type = 'event:hide' })
        if not IsScreenFadedIn() then DoScreenFadeIn(500) end
        DisplayRadar(true)
        DisplayHud(true)
        activeEventId = nil
    end,

    tickWait = 0,
})

SKEventsFreeroamMarkers.init({
    setBlipLegendGroup = setBlipLegendGroup,
    onStartDaily = function(eventId, vehicleClass)
        activeEventVehicleClass = vehicleClass
        startEvent(eventId)
    end,
    onStartMultiplayer = function(eventId, setupOptions)
        SKMultiplayer.hostRace(eventId, setupOptions)
    end,
})

SKEventsRampageMarkers.init({
    registerBlipCategories = registerBlipCategories,
    setBlipLegendGroup = setBlipLegendGroup,
    onStartRampage = function(eventId)
        activeEventVehicleClass = ''
        startEvent(eventId)
    end,
})

AddEventHandler('streetkings:event:freeroamEnter', function()
    CreateThread(SKEventsFreeroamMarkers.setup)
    CreateThread(SKEventsRampageMarkers.setup)
end)
AddEventHandler('streetkings:event:freeroamExit', function()
    SKEventsFreeroamMarkers.clear()
    SKEventsRampageMarkers.clear()
end)

RegisterNUICallback('phone:event:recover', function(_, cb)
    local ok = SKEvents.recoverToLastCheckpoint()
    if ok then
        SKPhone.close()
    end
    cb({ ok = ok })
end)

RegisterNUICallback('phone:event:forfeit', function(_, cb)
    local ok = SKEvents.forfeitActiveEvent()
    if ok and SKPhone.isOpen() then
        SKPhone.close()
    end
    cb({ ok = ok })
end)

RegisterNUICallback('events:changePeriod', function(data, cb)
    local eventId = activeEventId or SKStuntActiveId
    if not eventId or type(data.period) ~= 'string' then cb({}) return end
    local entries = lib.callback.await('streetkings:events:getLeaderboard', false, eventId, data.period) or {}
    local pb = lib.callback.await('streetkings:events:getPersonalBest', false, eventId)
    local isPoints = SKStuntActiveId or (activeEventId and activeEventId:find('^rampage_'))
    local sType = isPoints and 'points' or 'time'
    SendNUIMessage({
        type         = 'event:leaderboard',
        entries      = entries,
        personalBest = pb,
        period       = data.period,
        scoreType    = sType,
        eventId      = eventId,
    })
    cb({})
end)