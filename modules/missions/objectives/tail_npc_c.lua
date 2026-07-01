-- Objective: tailNpc
-- Zone-based flow: outer sphere pre-spawns the target vehicle, inner sphere
-- at the player's parking spot triggers the intro cutscene, then tasks the actual follow to SKTailing.
SKObjectives = SKObjectives or {}

local handler = {}
local session = nil

local SPAWN_RADIUS   = 80.0
local TRIGGER_RADIUS = 8.0

local function killEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
end

local function wipeSession()
    if not session then return end
    if session.outerZone then session.outerZone:remove() session.outerZone = nil end
    if session.innerZone then session.innerZone:remove() session.innerZone = nil end
    if session.startBlip and DoesBlipExist(session.startBlip) then RemoveBlip(session.startBlip) end
    if session.introCam and DoesCamExist(session.introCam) then
        RenderScriptCams(false, false, 0, false, false)
        DestroyCam(session.introCam, false)
        Cinematic = false
        FreezeEntityPosition(PlayerPedId(), false)
    end
    if session.state == 'cutscene' and SKC and GameState then
        SKC.SetGameState(GameState.FREEROAM)
    end
    killEntity(session.ped)
    killEntity(session.vehicle)
    session.active = false
    session = nil
end

local function scheduleMidMessages(ctx, obj)
    local list = {}
    if type(obj.midMessage) == 'table' and type(obj.midMessage.body) == 'string' then
        list[#list+1] = obj.midMessage
    end
    if type(obj.midMessages) == 'table' then
        for _, m in ipairs(obj.midMessages) do
            if type(m) == 'table' and type(m.body) == 'string' then list[#list+1] = m end
        end
    end
    for _, m in ipairs(list) do
        CreateThread(function()
            Wait((m.delaySeconds or 30) * 1000)
            if not session or not session.active then return end
            TriggerServerEvent('streetkings:missions:midMessage', m.sender or 'Unknown', m.avatar or 'unknown', m.body)
        end)
    end
end

local function spawnTargetVehicle(obj)
    if not session or session.state ~= 'spawning' then return end

    local target = obj.target or {}
    local vehHash = SK.LoadModel(target.vehicleModel or 'premier')
    if not vehHash then wipeSession() return end
    local sc = target.startCoords or vector4(0, 0, 0, 0)
    local veh = CreateVehicle(vehHash, sc.x, sc.y, sc.z, sc.w, true, false)
    SK.UnloadModel(vehHash)
    if veh == 0 then wipeSession() return end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, false, true, false)
    SetVehicleDoorsLocked(veh, 2)
    session.vehicle = veh
    if not session then return end
    session.state = 'waiting_trigger'
    local parkCoords = obj.parkCoords or obj.coords
    session.innerZone = lib.zones.sphere({
        coords = parkCoords,
        radius = obj.triggerRadius or TRIGGER_RADIUS,
        onEnter = function()
            if not session or session.state ~= 'waiting_trigger' then return end
            session.state = 'cutscene'
            SKC.SetGameState(GameState.MISSION)
            if session.outerZone then session.outerZone:remove() session.outerZone = nil end
            if session.innerZone then session.innerZone:remove() session.innerZone = nil end
            if session.startBlip and DoesBlipExist(session.startBlip) then
                RemoveBlip(session.startBlip)
                session.startBlip = nil
            end
            CreateThread(function() runIntroCutscene(obj) end)
        end,
    })
end

function runIntroCutscene(obj)
    if not session then return end
    local target = obj.target or {}
    local introScene = obj.introScene or {}
    local meeting = obj.meeting or {}
    local doorCoords = introScene.doorCoords
    local pedHash = SK.LoadModel(target.pedModel or 'a_m_y_business_03')
    if not pedHash then wipeSession() return end

    local spawnPos = doorCoords or target.startCoords or vector4(0, 0, 0, 0)
    local ped = CreatePed(4, pedHash, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w or 0.0, true, false)
    SK.UnloadModel(pedHash)
    if ped == 0 then wipeSession() return end
    SetEntityAsMissionEntity(ped, true, true)
    SetPedDefaultComponentVariation(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetEntityInvincible(ped, true)
    session.ped = ped
    local veh = session.vehicle
    if not veh or veh == 0 or not DoesEntityExist(veh) then wipeSession() return end
    local vehPos = GetEntityCoords(veh)
    local pedPos = GetEntityCoords(ped)
    local midX = (vehPos.x + pedPos.x) / 2
    local midY = (vehPos.y + pedPos.y) / 2
    local midZ = (vehPos.z + pedPos.z) / 2
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, midX - 8.0, midY + 4.5, midZ + 2.0)
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.0, true)
    SetCamFov(cam, 50.0)
    SetCamActive(cam, true)
    session.introCam = cam
    Cinematic = true
    FreezeEntityPosition(PlayerPedId(), true)
    RenderScriptCams(true, true, 800, true, true)

    SendNUIMessage({
        type = 'missions:subtitle',
        speaker = 'You',
        body = "That's Gabe. Let's see where he's headed.",
        duration = 3500,
    })
    if doorCoords and type(doorCoords) == 'vector4' then
        TaskGoToEntity(ped, veh, -1, 1.5, 1.5, 0, 0)
        local walkDeadline = GetGameTimer() + 15000
        while GetGameTimer() < walkDeadline do
            if not session or not DoesEntityExist(ped) or not DoesEntityExist(veh) then break end
            if #(GetEntityCoords(ped) - GetEntityCoords(veh)) < 3.0 then break end
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end

    if not session then return end
    ClearPedTasks(ped)
    SetVehicleDoorsLocked(veh, 0)
    TaskEnterVehicle(ped, veh, 8000, -1, 2.0, 1, 0)
    local enterDeadline = GetGameTimer() + 8000
    while GetGameTimer() < enterDeadline do
        if not session or not DoesEntityExist(ped) or not DoesEntityExist(veh) then break end
        if GetVehiclePedIsIn(ped, false) == veh then break end
        HideHudAndRadarThisFrame()
        Wait(0)
    end
    if DoesEntityExist(ped) and DoesEntityExist(veh) and GetVehiclePedIsIn(ped, false) ~= veh then
        SetPedIntoVehicle(ped, veh, -1)
    end
    SetVehicleEngineOn(veh, true, false, false)
    SetPedKeepTask(ped, true)
    Wait(400)
    if not session then return end
    PointCamAtEntity(cam, veh, 0.0, 0.0, 0.0, true)
    local meetCoords = meeting.coords or vector3(0, 0, 0)
    TaskVehicleDriveToCoordLongrange(
        ped, veh, meetCoords.x, meetCoords.y, meetCoords.z,
        meeting.driveSpeed or 14.0, 786603, 4.0
    )
    local driveWatchEnd = GetGameTimer() + 1000
    while GetGameTimer() < driveWatchEnd do
        if not session then return end
        HideHudAndRadarThisFrame()
        Wait(0)
    end

    RenderScriptCams(false, true, 800, false, false)
    Cinematic = false
    FreezeEntityPosition(PlayerPedId(), false)
    Wait(800)
    if DoesCamExist(cam) then DestroyCam(cam, false) end

    if not session then return end
    scheduleMidMessages(session, obj)
    SKTailing.beginFromSession(ped, veh, obj, {
        onSuccess = function()
            SKC.SetGameState(GameState.FREEROAM)
            lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'tail_success' })
        end,
        onFail = function(reason)
            local failNotify = {
                spotted     = _L('lua.notify.tail_spotted'),
                spooked     = _L('lua.notify.tail_spooked'),
                lost        = _L('lua.notify.tail_lost'),
                timeout     = _L('lua.notify.tail_timeout'),
                target_lost = _L('lua.notify.tail_target_lost'),
            }
            SKNotify({ title = failNotify[reason] or _L('lua.notify.mission_failed'), type = 'error', duration = 5000 })
            SendNUIMessage({ type = 'missions:tailFailed', reason = reason })
            Wait(4000)
            TriggerServerEvent('streetkings:missions:midMessage', 'Saint', 'saint', "He must be getting suspicious. Lay low for a bit, I'll let you know when we can try again.")
            Wait(7000)
            SKC.SetGameState(GameState.FREEROAM)
            lib.callback.await('streetkings:missions:abort', false)
        end,
    })
end

function handler.start(ctx)
    local obj = ctx.objective
    wipeSession()
    session = {
        state     = 'waiting_spawn',
        active    = true,
        vehicle   = 0,
        ped       = 0,
        outerZone = nil,
        innerZone = nil,
        startBlip = nil,
    }
    local parkCoords = obj.parkCoords or obj.coords or vector3(0, 0, 0)
    local blip = AddBlipForCoord(parkCoords.x, parkCoords.y, parkCoords.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 46)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 8)
    session.startBlip = blip
    local spawnCenter = obj.target and obj.target.startCoords or parkCoords
    session.outerZone = lib.zones.sphere({
        coords = vector3(spawnCenter.x, spawnCenter.y, spawnCenter.z),
        radius = obj.spawnRadius or SPAWN_RADIUS,
        onEnter = function()
            if not session or session.state ~= 'waiting_spawn' then return end
            session.state = 'spawning'
            CreateThread(function() spawnTargetVehicle(obj) end)
        end,
        onExit = function()
            if not session or session.state ~= 'waiting_trigger' then return end
            killEntity(session.vehicle)
            session.vehicle = 0
            if session.innerZone then session.innerZone:remove() session.innerZone = nil end
            session.state = 'waiting_spawn'
        end,
    })

    return {
        remove = function()
            if session then
                session.active = false
                SKTailing.stop(false)
                wipeSession()
            end
        end,
    }
end

function handler.stop(ctx)
    if session then
        session.active = false
        SKTailing.stop(false)
        wipeSession()
    end
end

SKObjectives[ObjectiveType.TAIL_NPC] = handler
