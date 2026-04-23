-- Objectives: stopVehicle + chaseVehicle (Mission 7)
-- Both stay in FREEROAM (requiresFreeroam=true). State shared via module-level `session`.
-- stopVehicle: spawn at 80m, cutscene at 20m, advance when cutscene ends.
-- chaseVehicle: pick up entities from session, run chase, advance on engine kill.
SKObjectives = SKObjectives or {}

local BREAK_IN_ANIM  = { dict = 'mini@repair', name = 'fixing_a_ped', flags = 1 }
local RECKLESS_FLAGS = 262716
local FLEE_SPEED     = 35.0
local SPAWN_RADIUS   = 80.0
local TRIGGER_RADIUS = 20.0
local RAM_COOLDOWN   = 1500
local RAM_CHECK_MS   = 200
local RAM_MIN_SPEED  = 8.0

local session = nil

local function killEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    NetworkRequestControlOfEntity(entity)
    SetEntityAsMissionEntity(entity, false, true)
    DeleteEntity(entity)
end

local function pinEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    NetworkRequestControlOfEntity(entity)
end

local function removeBlip(key)
    if session and session[key] and DoesBlipExist(session[key]) then
        RemoveBlip(session[key])
    end
    if session then session[key] = nil end
end

local function wipeSession()
    if not session then return end
    if session.outerZone then session.outerZone:remove() session.outerZone = nil end
    if session.innerZone then session.innerZone:remove() session.innerZone = nil end
    removeBlip('startBlip')
    removeBlip('chaseBlip')
    killEntity(session.thief)
    killEntity(session.vehicle)
    session = nil
end

local function playBreakInAnim(ped)
    if not SK.LoadAnimDict(BREAK_IN_ANIM.dict) then return end
    TaskPlayAnim(ped, BREAK_IN_ANIM.dict, BREAK_IN_ANIM.name, 4.0, -4.0, -1, BREAK_IN_ANIM.flags, 0.0, false, false, false)
end

-- Objective 1: stopVehicle --------------------------------------------------

local doSpawnAndSetupInnerZone, runCutscene

doSpawnAndSetupInnerZone = function(obj)
    if not session or session.state ~= 'spawning' then return end

    local vehCfg   = obj.vehicle
    local thiefCfg = obj.thief

    local vehHash = SK.LoadModel(vehCfg.model)
    if not vehHash then wipeSession() return end
    local sc  = vehCfg.spawnCoords
    local veh = CreateVehicle(vehHash, sc.x, sc.y, sc.z, sc.w or 0.0, true, false)
    SK.UnloadModel(vehHash)
    if veh == 0 then wipeSession() return end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, false, true, false)
    SetVehicleDoorsLocked(veh, 2)
    session.vehicle = veh

    local thiefHash = SK.LoadModel(thiefCfg.model)
    if not thiefHash then wipeSession() return end
    local psc = thiefCfg.spawnCoords
    local ped = CreatePed(4, thiefHash, psc.x, psc.y, psc.z, thiefCfg.spawnHeading or 0.0, true, false)
    SK.UnloadModel(thiefHash)
    if ped == 0 then wipeSession() return end
    SetPedDefaultComponentVariation(ped)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCanBeTargetted(ped, false)
    session.thief = ped

    TaskTurnPedToFaceEntity(ped, veh, 1500)
    Wait(1500)
    FreezeEntityPosition(ped, true)
    playBreakInAnim(ped)

    if not session or session.state ~= 'spawning' then return end
    session.state = 'waiting_trigger'

    session.innerZone = lib.zones.sphere({
        coords  = obj.coords,
        radius  = TRIGGER_RADIUS,
        onEnter = function()
            if not session or session.state ~= 'waiting_trigger' then return end
            session.state = 'cutscene'
            if session.innerZone then session.innerZone:remove() session.innerZone = nil end
            removeBlip('startBlip')
            CreateThread(function() runCutscene(obj) end)
        end,
    })

    if session.outerZone then session.outerZone:remove() session.outerZone = nil end
end

runCutscene = function(obj)
    local thief = session and session.thief or 0
    local veh   = session and session.vehicle or 0
    local ft    = obj.fleeTarget or vector3(3823.4277, 4464.0933, 2.7149)

    pinEntity(veh)
    pinEntity(thief)
    FreezeEntityPosition(thief, false)

    local enterAtMs = (obj.thief and obj.thief.enterVehicleAtMs) or 4000
    CreateThread(function()
        Wait(enterAtMs)
        if not session or session.state == 'done' then return end
        if not DoesEntityExist(thief) or not DoesEntityExist(veh) then return end
        ClearPedTasks(thief)
        SetVehicleDoorsLocked(veh, 0)
        TaskEnterVehicle(thief, veh, 15000, -1, 2.0, 1, 0)

        local deadline = GetGameTimer() + 8000
        while GetGameTimer() < deadline do
            if not session or session.state == 'done' then return end
            if not DoesEntityExist(thief) or not DoesEntityExist(veh) then return end
            if GetVehiclePedIsIn(thief, false) == veh then break end
            Wait(50)
        end

        if not session or session.state == 'done' then return end
        if not DoesEntityExist(thief) or not DoesEntityExist(veh) then return end
        if GetVehiclePedIsIn(thief, false) ~= veh then
            SetPedIntoVehicle(thief, veh, -1)
        end
        SetVehicleEngineOn(veh, true, false, false)
        TaskVehicleDriveToCoordLongrange(thief, veh, ft.x, ft.y, ft.z, FLEE_SPEED, RECKLESS_FLAGS, 5.0)
    end)

    local cin = obj.cinematic or {}
    SKCutscene.playLive({
        title     = cin.title,
        subtitle  = cin.subtitle,
        lookAt    = cin.lookAt,
        shots     = cin.shots or {},
        subtitles = cin.subtitles or {},
    }, {})

    if not session or session.state == 'done' then return end

    if DoesEntityExist(thief) and DoesEntityExist(veh) and GetVehiclePedIsIn(thief, false) ~= veh then
        SetPedIntoVehicle(thief, veh, -1)
        SetVehicleEngineOn(veh, true, false, false)
        TaskVehicleDriveToCoordLongrange(thief, veh, ft.x, ft.y, ft.z, FLEE_SPEED, RECKLESS_FLAGS, 5.0)
    end

    session.state = 'handoff'
    lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'stop_vehicle' })
end

local stopHandler = {}

function stopHandler.start(ctx)
    local obj = ctx.objective
    if type(obj.coords) ~= 'vector3' then return nil end

    wipeSession()
    session = {
        state     = 'waiting_spawn',
        vehicle   = 0,
        thief     = 0,
        outerZone = nil,
        innerZone = nil,
        startBlip = nil,
        chaseBlip = nil,
    }

    local c = obj.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 501)
    SetBlipColour(blip, 46)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 46)
    session.startBlip = blip

    session.outerZone = lib.zones.sphere({
        coords  = obj.coords,
        radius  = SPAWN_RADIUS,
        onEnter = function()
            if not session or session.state ~= 'waiting_spawn' then return end
            session.state = 'spawning'
            CreateThread(function() doSpawnAndSetupInnerZone(obj) end)
        end,
    })

    return {
        remove = function()
            if session and session.state ~= 'handoff' then
                wipeSession()
            end
        end,
    }
end

function stopHandler.stop(ctx)
    if session and session.state ~= 'handoff' then
        wipeSession()
    end
end

SKObjectives[ObjectiveType.STOP_VEHICLE] = stopHandler

-- Objective 2: chaseVehicle -------------------------------------------------

local chaseHandler = {}

local function scheduleMidMessages(obj)
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
            if not session or session.state ~= 'chasing' then return end
            TriggerServerEvent('streetkings:missions:midMessage', m.sender or 'Unknown', m.avatar or 'unknown', m.body)
        end)
    end
end

function chaseHandler.start(ctx)
    local obj = ctx.objective

    if not session or not session.vehicle or session.vehicle == 0 or not DoesEntityExist(session.vehicle) then
        lib.callback.await('streetkings:missions:abort', false)
        return nil
    end

    session.state = 'chasing'
    scheduleMidMessages(obj)

    local veh   = session.vehicle
    local thief = session.thief

    local chaseBlip = AddBlipForEntity(veh)
    SetBlipSprite(chaseBlip, 225)
    SetBlipColour(chaseBlip, 1)
    SetBlipFlashes(chaseBlip, true)
    session.chaseBlip = chaseBlip

    if DoesEntityExist(thief) then
        SetEntityInvincible(thief, false)
    end

    local chase        = obj.chase or {}
    local maxDistance  = (chase.maxDistance or 150.0)
    local lostMs       = (chase.lostSeconds or 6) * 1000
    local ramsRequired = obj.ramsRequired or 8

    CreateThread(function()
        local outOfRange   = nil
        local ramCount     = 0
        local lastRamTime  = 0
        local engineKilled = false
        local reason       = nil

        while session and session.state == 'chasing' do
            if not DoesEntityExist(veh) then reason = 'success' break end

            if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh)) > maxDistance then
                if not outOfRange then
                    outOfRange = GetGameTimer()
                elseif GetGameTimer() - outOfRange > lostMs then
                    reason = 'lost' break
                end
            else
                outOfRange = nil
            end

            if engineKilled and GetEntitySpeed(veh) < 1.0 then
                reason = 'success' break
            end

            local now = GetGameTimer()
            if not engineKilled and now - lastRamTime > RAM_COOLDOWN then
                local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
                if playerVeh and playerVeh ~= 0 and DoesEntityExist(playerVeh)
                    and HasEntityCollidedWithAnything(veh)
                    and GetEntitySpeed(playerVeh) > RAM_MIN_SPEED
                then
                    lastRamTime = now
                    ramCount = ramCount + 1
                    if ramCount >= ramsRequired then
                        local extra  = ramCount - ramsRequired
                        local chance = 0.4 + (extra * 0.15)
                        if chance >= 1.0 or math.random() < chance then
                            engineKilled = true
                            SetVehicleEngineHealth(veh, -1.0)
                            SetVehicleUndriveable(veh, true)
                            ApplyForceToEntity(veh, 1, 0.0, 0.0, 0.0, 3.0, 0.0, 0.0, 0, true, true, true, false, true)
                            if DoesEntityExist(thief) then ClearPedTasks(thief) end
                        end
                    end
                end
            end

            Wait(RAM_CHECK_MS)
        end

        if reason == 'success' then
            local msg = obj.successMessage
            if type(msg) == 'table' and type(msg.body) == 'string' then
                TriggerServerEvent('streetkings:missions:midMessage', msg.sender or 'Saint', msg.avatar or 'saint', msg.body)
            end
            wipeSession()
            Wait(400)
            lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'chase_vehicle' })
        elseif reason == 'lost' then
            wipeSession()
            SendNUIMessage({ type = 'missions:subtitle', speaker = '', body = "You lost them.", duration = 2500 })
            Wait(2700)
            lib.callback.await('streetkings:missions:abort', false)
        end
    end)

    return { remove = function() wipeSession() end }
end

function chaseHandler.stop(ctx)
    wipeSession()
end

SKObjectives[ObjectiveType.CHASE_VEHICLE] = chaseHandler
