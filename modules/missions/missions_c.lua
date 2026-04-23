-- Missions client - HUD state + giver interaction point
SKMissionsClient = {}

local state = {
    ok = false,
    status = nil,
    chapterId = nil,
    missionIndex = 0,
    active = nil,       ---@type table|nil
    pending = nil,      ---@type table|nil
    cooldownRemaining = 0,
    flags = {},
}

local giverPoint = nil
local giverPointsInner = nil
local giverApproachZone = nil
local giverBlip = nil
local currentObjectivePoint = nil
local objectiveState = {}

local HUD_UPDATE_MS = 500
local lastHudTick = 0

---@return boolean
local function inFreeroamLikeState()
    local gs = SKC and SKC.GetGameState and SKC.GetGameState() or nil
    return gs == GameState.FREEROAM or gs == GameState.MISSION
end

local function isMissionActive()
    return state.ok and state.status == MissionStatus.ACTIVE
end

function SKMissionsClient.isMissionActive()
    return isMissionActive()
end

function SKMissionsClient.isFinaleActive()
    if not isMissionActive() then return false end
    local def = state.active and state.active.def
    return def and def.finale == true
end

function SKMissionsClient.getPhoneState()
    if not isMissionActive() then return nil end
    local def = state.active and state.active.def
    return {
        missionName = def and def.title or 'Active Mission',
        canForfeit = true,
    }
end

---@param objective table|nil
---@param progress table|nil
local function describeObjective(objective, progress)
    if not objective then return '' end
    local base = (type(objective.label) == 'string' and objective.label ~= '') and objective.label or (objective.type or '')
    local required = tonumber(progress and progress.required) or 0
    if required > 1 then
        local current = tonumber(progress and progress.current) or 0
        return ('%s (%d/%d)'):format(base, current, required)
    end
    return base
end

local function postHud()
    if not state.ok then
        SendNUIMessage({ type = 'missions:hide' })
        return
    end

    if state.active then
        local def = state.active.def
        local objective = def and def.objectives and def.objectives[state.active.objectiveIndex or 1] or nil
        SendNUIMessage({
            type = 'missions:show',
            mission = {
                title = def and def.title or '',
                subtitle = def and def.subtitle or '',
                giver = def and def.giver or nil,
                objective = describeObjective(objective, state.active.progress),
                objectiveIndex = state.active.objectiveIndex,
                objectiveTotal = def and def.objectives and #def.objectives or 0,
            },
        })
    elseif state.pending and state.status == MissionStatus.AVAILABLE then
        local def = state.pending.def
        SendNUIMessage({
            type = 'missions:pending',
            mission = {
                title = def and def.title or '',
                giver = def and def.giver or nil,
            },
        })
    else
        SendNUIMessage({ type = 'missions:hide' })
    end
end

local function removeGiverPoints()
    if giverPoint and giverPoint.remove then giverPoint:remove() end
    if giverPointsInner and giverPointsInner.remove then giverPointsInner:remove() end
    if giverApproachZone and giverApproachZone.remove then giverApproachZone:remove() end
    giverPoint = nil
    giverPointsInner = nil
    giverApproachZone = nil
    if giverBlip and DoesBlipExist(giverBlip) then
        RemoveBlip(giverBlip)
    end
    giverBlip = nil
    SendNUIMessage({ type = 'prompt:hide' })
end

local function cleanupPreSpawnedNPC()
    SKMissionShared = SKMissionShared or {}
    if SKMissionShared.preSpawnedPed and DoesEntityExist(SKMissionShared.preSpawnedPed) then
        SetEntityAsMissionEntity(SKMissionShared.preSpawnedPed, false, true)
        DeleteEntity(SKMissionShared.preSpawnedPed)
    end
    if SKMissionShared.preSpawnedVeh and DoesEntityExist(SKMissionShared.preSpawnedVeh) then
        SetEntityAsMissionEntity(SKMissionShared.preSpawnedVeh, false, true)
        DeleteEntity(SKMissionShared.preSpawnedVeh)
    end
    SKMissionShared.preSpawnedVeh = nil
    SKMissionShared.preSpawnedPed = nil
end

local function removeObjectivePoint()
    if currentObjectivePoint and currentObjectivePoint.remove then currentObjectivePoint:remove() end
    currentObjectivePoint = nil

    if SKObjectives and objectiveState.handler and objectiveState.handler.stop then
        pcall(objectiveState.handler.stop, objectiveState)
    end
    objectiveState = {}
end

local function addGiverBlip(blipDef, titleOverride)
    if type(blipDef) ~= 'table' or type(blipDef.coords) ~= 'vector3' then return end
    local coords = blipDef.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipDef.sprite or 480)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, blipDef.color or 5)
    SetBlipAsShortRange(blip, false)
    ShowHeadingIndicatorOnBlip(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(titleOverride or blipDef.label or 'Mission')
    EndTextCommandSetBlipName(blip)
    giverBlip = blip
end

local function setupPendingGiverInteraction()
    removeGiverPoints()
    if not (state.ok and state.status == MissionStatus.AVAILABLE and state.pending) then return end

    local def = state.pending.def
    if type(def.startBlip) ~= 'table' then return end
    local coords = def.startBlip.coords
    if type(coords) ~= 'vector3' then return end

    addGiverBlip(def.startBlip, def.title)

    local promptShown = false
    local label = def.startBlip.label or ('Start: ' .. (def.title or 'Mission'))

    giverPoint = lib.points.new({
        coords = coords,
        distance = 60.0,
        nearby = function(self)
            DrawMarker(
                1,
                coords.x, coords.y, coords.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                2.5, 2.5, 1.2,
                80, 180, 255, 140,
                false, true, 2, false, nil, nil, false
            )
        end,
    })

    local autoStarting = false

    SKMissionShared = SKMissionShared or {}
    if def.opponentSpawn and def.opponentSpawn.coords then
        local spawnData = def.opponentSpawn
        local spawned = false
        giverApproachZone = lib.points.new({
            coords = coords,
            distance = 50.0,
            onEnter = function()
                if spawned or (SKMissionShared.preSpawnedVeh and DoesEntityExist(SKMissionShared.preSpawnedVeh)) then return end
                spawned = true
                CreateThread(function()
                    local vehHash = SK.LoadModel(spawnData.vehicleModel)
                    if not vehHash then return end

                    local pedHash = SK.LoadModel(spawnData.pedModel)
                    if not pedHash then SK.UnloadModel(vehHash) return end

                    local c = spawnData.coords
                    local veh = CreateVehicle(vehHash, c.x, c.y, c.z, c.w, true, false)
                    SK.UnloadModel(vehHash)
                    if veh == 0 then return end

                    SetVehicleOnGroundProperly(veh)
                    SetEntityAsMissionEntity(veh, true, true)
                    SetVehicleDoorsLocked(veh, 2)
                    SetEntityInvincible(veh, true)
                    SetVehicleEngineOn(veh, true, true, false)

                    local ped = CreatePed(4, pedHash, c.x, c.y, c.z, c.w, true, false)
                    SK.UnloadModel(pedHash)
                    if ped == 0 then DeleteEntity(veh) return end
                    SetPedDefaultComponentVariation(ped)

                    SetEntityAsMissionEntity(ped, true, true)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    SetPedIntoVehicle(ped, veh, -1)
                    SetEntityInvincible(ped, true)

                    SKMissionShared.preSpawnedVeh = veh
                    SKMissionShared.preSpawnedPed = ped
                end)
            end,
        })
    end

    if def.autoStart then
        giverPointsInner = lib.points.new({
            coords = coords,
            distance = 8.0,
            onEnter = function()
                if autoStarting then return end
                autoStarting = true
                lib.callback.await('streetkings:missions:startPending', false)
            end,
        })
    elseif def.forceAutoStart then
        if autoStarting then return end
        autoStarting = true
        lib.callback.await('streetkings:missions:startPending', false)
    else
        giverPointsInner = lib.points.new({
            coords = coords,
            distance = 4.5,
            onEnter = function()
                promptShown = true
                SendNUIMessage({ type = 'prompt:show', key = SKInput.getInteractLabel(), text = label })
            end,
            onExit = function()
                promptShown = false
                SendNUIMessage({ type = 'prompt:hide' })
            end,
            nearby = function()
                local key = SKInput.getInteractLabel()
                SendNUIMessage({ type = 'prompt:show', key = key, text = label })
                promptShown = true
                if SKInput.isInteractJustReleased() then
                    SendNUIMessage({ type = 'prompt:hide' })
                    promptShown = false
                    lib.callback.await('streetkings:missions:startPending', false)
                end
            end,
        })
    end
end

local function startObjectiveHandler()
    removeObjectivePoint()
    if not (state.ok and state.status == MissionStatus.ACTIVE and state.active) then return end

    local def = state.active.def
    local objective = def.objectives and def.objectives[state.active.objectiveIndex or 1] or nil
    if not objective then return end

    local handler = SKObjectives and SKObjectives[objective.type]
    if not handler or not handler.start then return end

    objectiveState = {
        handler = handler,
        objective = objective,
        missionDef = def,
        missionId = state.active.missionId,
        objectiveIndex = state.active.objectiveIndex,
    }

    local ok, pointOrErr = pcall(handler.start, objectiveState)
    if ok and pointOrErr then
        currentObjectivePoint = pointOrErr
    end
end

function SKMissionsClient.requestAdvance(context)
    return lib.callback.await('streetkings:missions:advanceObjective', false, context or {})
end

function SKMissionsClient.getState()
    return state
end

---@param snapshot table
local function applySnapshot(snapshot)
    local wasActive = isMissionActive()
    state = snapshot or { ok = false }
    if not state.ok then
        removeGiverPoints()
        removeObjectivePoint()
        if wasActive then cleanupPreSpawnedNPC() end
        postHud()
        if wasActive and SKC.GetGameState() == GameState.MISSION then
            SKC.SetGameState(GameState.FREEROAM)
        end
        return
    end

    if state.status == MissionStatus.ACTIVE then
        removeGiverPoints()
        local def = state.active and state.active.def
        local objIdx = state.active and state.active.objectiveIndex or 1
        local objective = def and def.objectives and def.objectives[objIdx]
        local objHandler = objective and SKObjectives and SKObjectives[objective.type]
        local needsFreeroam = (objective and objective.requiresFreeroam) or (objHandler and objHandler.requiresFreeroam)

        if needsFreeroam then
            if SKC.GetGameState() == GameState.MISSION then
                SKC.SetGameState(GameState.FREEROAM)
            end
        else
            if SKC.GetGameState() == GameState.FREEROAM then
                SKC.SetGameState(GameState.MISSION)
            end
        end
        startObjectiveHandler()
    else
        removeObjectivePoint()
        if wasActive then cleanupPreSpawnedNPC() end
        if wasActive and SKC.GetGameState() == GameState.MISSION then
            SKC.SetGameState(GameState.FREEROAM)
        end
        setupPendingGiverInteraction()
    end

    postHud()
end

RegisterNetEvent('streetkings:missions:sync', function(snapshot)
    applySnapshot(snapshot)
end)

RegisterNetEvent('streetkings:missions:completed', function(payload)
    SendNUIMessage({
        type = 'missions:completed',
        payload = payload,
    })
end)

RegisterNetEvent('streetkings:missions:autoWaypoint', function(payload)
    if type(payload) ~= 'table' or type(payload.coords) ~= 'table' then return end
    local c = payload.coords
    if type(c.x) ~= 'number' or type(c.y) ~= 'number' then return end
    SetNewWaypoint(c.x + 0.0, c.y + 0.0)
    SendNUIMessage({
        type = 'missions:banner',
        title = payload.label or 'New Mission',
        subtitle = payload.subtitle or '',
        kicker = 'New Mission',
    })
end)

AddEventHandler('streetkings:freeroam:enter', function()
    CreateThread(function()
        while not IsScreenFadedIn() do Wait(100) end
        Wait(500)
        local snapshot = lib.callback.await('streetkings:missions:getState', false)
        if snapshot then applySnapshot(snapshot) end
    end)
end)

AddEventHandler('streetkings:freeroam:exit', function()
    if isMissionActive() then return end
    removeGiverPoints()
    removeObjectivePoint()
    SendNUIMessage({ type = 'missions:hide' })
end)

RegisterNUICallback('phone:mission:forfeit', function(_, cb)
    if not isMissionActive() then
        cb({ ok = false })
        return
    end
    lib.callback.await('streetkings:missions:abort', false)
    if SKPhone.isOpen() then SKPhone.close() end
    if SKC.GetGameState() == GameState.MISSION then
        SKC.SetGameState(GameState.FREEROAM)
    end
    cb({ ok = true })
end)

RegisterCommand('missiondebug', function()
    local snapshot = lib.callback.await('streetkings:missions:getState', false)
    if not snapshot or not snapshot.ok then
        SKNotify({ title = 'Missions: no active save', type = 'warning' })
        return
    end
    SKNotify({
        title = ('Missions: %s | chapter %d | missionIdx %d'):format(snapshot.status or '?', snapshot.chapter or 0, snapshot.missionIndex or 0),
        type = 'info',
        duration = 6000,
    })
end, false)

CreateThread(function()
    while true do
        Wait(HUD_UPDATE_MS)
        local now = GetGameTimer()
        if inFreeroamLikeState() and state.ok and state.status == MissionStatus.ACTIVE and now - lastHudTick > HUD_UPDATE_MS then
            lastHudTick = now
            if objectiveState and objectiveState.handler and objectiveState.handler.tick then
                pcall(objectiveState.handler.tick, objectiveState)
            end
        end
    end
end)

local missionDeathHandled = false

SKC.RegisterGameState(GameState.MISSION, {
    onEnter = function()
        missionDeathHandled = false
    end,
    onExit = function(nextState)
        if SKShop.isShopState(nextState) or SKGarage.isGarageState(nextState)
            or SKDealership.isDealershipState(nextState) or SKAvatar.isAvatarState(nextState) then
            return
        end
        removeGiverPoints()
        removeObjectivePoint()
        SendNUIMessage({ type = 'missions:hide' })
    end,
    onTick = function()
        local veh = SKFreeroam.getActiveVehicle()
        if veh and DoesEntityExist(veh) then
            SKVehicleLock.tick(veh, function() return false end)
        end

        if not missionDeathHandled and IsEntityDead(PlayerPedId()) then
            missionDeathHandled = true
            CreateThread(function()
                lib.callback.await('streetkings:missions:resetMission', false)
                SetPlayerWantedLevel(PlayerId(), 0, false)
                SetPlayerWantedLevelNow(PlayerId(), false)
                removeObjectivePoint()
                SendNUIMessage({ type = 'missions:hide' })
                SKC.Wasted()
            end)
        end
    end,
    tickWait = 0,
})