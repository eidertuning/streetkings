SKObjectives = SKObjectives or {}

local handler = {}

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
            if not ctx.active then return end
            TriggerServerEvent('streetkings:missions:midMessage', m.sender or 'Unknown', m.avatar or 'unknown', m.body)
        end)
    end
end

local function spawnTrapCop(cfg)
    local vehHash = SK.LoadModel(cfg.vehicleModel or 'police3')
    local pedHash = SK.LoadModel(cfg.pedModel or 's_m_y_cop_01')
    if not vehHash or not pedHash then return nil, nil end

    local c = cfg.coords
    local veh = CreateVehicle(vehHash, c.x, c.y, c.z, c.w or 0.0, true, false)
    if not DoesEntityExist(veh) then return nil, nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDoorsLocked(veh, 4)
    SetVehicleSiren(veh, false)
    SetVehicleHasMutedSirens(veh, false)
    SetVehicleEngineOn(veh, true, true, false)

    local ped = CreatePedInsideVehicle(veh, 4, pedHash, -1, true, false)
    if not DoesEntityExist(ped) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteEntity(veh)
        return nil, nil
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetPedDefaultComponentVariation(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)

    return veh, ped
end

local function cleanupTrap(ctx)
    if ctx.trapPed and DoesEntityExist(ctx.trapPed) then
        SetEntityAsMissionEntity(ctx.trapPed, true, true)
        DeleteEntity(ctx.trapPed)
    end
    if ctx.trapVeh and DoesEntityExist(ctx.trapVeh) then
        SetEntityAsMissionEntity(ctx.trapVeh, true, true)
        DeleteEntity(ctx.trapVeh)
    end
    ctx.trapPed = nil
    ctx.trapVeh = nil
end

function handler.start(ctx)
    local obj = ctx.objective
    local stars = obj.stars or 3
    ctx.active = true

    if obj.trapCop then
        local copVeh, copPed = spawnTrapCop(obj.trapCop)
        ctx.trapVeh = copVeh
        ctx.trapPed = copPed

        if copVeh and copPed then
            SetVehicleSiren(copVeh, true)
            TaskVehicleChase(copPed, PlayerPedId())
            SetTaskVehicleChaseBehaviorFlag(copPed, 32, true)
            SetTaskVehicleChaseIdealPursuitDistance(copPed, 30.0)
            ReportPoliceSpottedPlayer(PlayerId())

            local cinematicStart = GetGameTimer()
            CreateThread(function()
                local subs = {
                    { atMs = 400,  speaker = 'Radio', body = "Dispatch - all units, suspect spotted downtown. Pursue and detain.", duration = 3000 },
                    { atMs = 2800, speaker = 'You',   body = "Sirens. Already?",                          duration = 2000 },
                    { atMs = 5200, speaker = 'You',   body = "Only Saint knew I'd be here.",               duration = 2500 },
                    { atMs = 8000, speaker = 'You',   body = "Drive. Think later.",                        duration = 2000 },
                }
                for _, sub in ipairs(subs) do
                    local waitTime = sub.atMs - (GetGameTimer() - cinematicStart)
                    if waitTime > 0 then Wait(waitTime) end
                    SendNUIMessage({ type = 'missions:subtitle', speaker = sub.speaker, body = sub.body, duration = sub.duration })
                end
            end)

            SKPolice.caughtSpeeding(copVeh)

            SetPlayerWantedLevel(PlayerId(), stars, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
            ReportPoliceSpottedPlayer(PlayerId())

            if DoesEntityExist(copPed) then
                TaskVehicleChase(copPed, PlayerPedId())
                SetTaskVehicleChaseBehaviorFlag(copPed, 32, true)
                SetTaskVehicleChaseIdealPursuitDistance(copPed, 30.0)
            end

            CreateThread(function()
                while ctx.active and copVeh and DoesEntityExist(copVeh) do
                    Wait(1000)
                    local dist = #(GetEntityCoords(copVeh) - GetEntityCoords(PlayerPedId()))
                    if dist <= 50.0 and HasEntityClearLosToEntity(copVeh, PlayerPedId(), 17) then
                        ReportPoliceSpottedPlayer(PlayerId())
                    end
                end
            end)
        end
    end

    if type(obj.bankAlarmTimeout) == 'number' and SKBankAlarm and SKBankAlarm.active then
        CreateThread(function()
            Wait(obj.bankAlarmTimeout * 1000)
            if SKBankAlarm and SKBankAlarm.active then
                StopAlarm(SKBankAlarm.id, true)
                SKBankAlarm = nil
            end
        end)
    end

    scheduleMidMessages(ctx, obj)

    SetPlayerWantedLevel(PlayerId(), stars, false)
    SetPlayerWantedLevelNow(PlayerId(), false)

    local dropoff = obj.dropoffCoords
    if type(dropoff) == 'vector3' then
        local blip = AddBlipForCoord(dropoff.x, dropoff.y, dropoff.z)
        SetBlipSprite(blip, 501)
        SetBlipColour(blip, 46)
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, 46)
        ctx.blip = blip
    end

    local function finish(source)
        if not ctx.active then return end
        ctx.active = false
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = source })
        if not result or not result.ok then ctx.active = true end
    end

    CreateThread(function()
        Wait(10000)
        while ctx.active do
            if dropoff then
                local pcoords = GetEntityCoords(PlayerPedId())
                if #(pcoords - dropoff) < 10.0 then
                    finish('escape_dropoff')
                    return
                end
            end

            if GetPlayerWantedLevel(PlayerId()) == 0 then
                finish('escape_cleared')
                return
            end

            if ArePlayerStarsGreyedOut(PlayerId()) then
                SetPlayerWantedLevel(PlayerId(), 0, false)
                SetPlayerWantedLevelNow(PlayerId(), false)
                finish('escape_cleared')
                return
            end

            Wait(2500)
        end
    end)

    return {
        remove = function()
            ctx.active = false
            if ctx.blip and DoesBlipExist(ctx.blip) then RemoveBlip(ctx.blip) end
            ctx.blip = nil
            cleanupTrap(ctx)
            if SKBankAlarm and SKBankAlarm.active then
                StopAlarm(SKBankAlarm.id, true)
                SKBankAlarm = nil
            end
        end,
    }
end

function handler.stop(ctx)
    ctx.active = false
    if ctx.blip and DoesBlipExist(ctx.blip) then RemoveBlip(ctx.blip) end
    ctx.blip = nil
    cleanupTrap(ctx)
    if SKBankAlarm and SKBankAlarm.active then
        StopAlarm(SKBankAlarm.id, true)
        SKBankAlarm = nil
    end
end

SKObjectives[ObjectiveType.ESCAPE] = handler
