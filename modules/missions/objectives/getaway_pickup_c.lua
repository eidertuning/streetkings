SKObjectives = SKObjectives or {}

local handler = {}

local function loadWeapon(weapon)
    if type(weapon) ~= 'string' then return end
    local h = joaat(weapon)
    RequestWeaponAsset(h, 31, 0)
    local deadline = GetGameTimer() + 3000
    while not HasWeaponAssetLoaded(h) do
        if GetGameTimer() > deadline then return end
        Wait(0)
    end
end

local function spawnRobber(cfg)
    local hash = SK.LoadModel(cfg.model)
    if not hash then return 0 end
    local ped = CreatePed(4, hash, cfg.storeSpawn.x, cfg.storeSpawn.y, cfg.storeSpawn.z, cfg.storeHeading or 0.0, false, false)
    SK.UnloadModel(hash)
    if ped == 0 then return 0 end
    SetPedDefaultComponentVariation(ped)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCanBeTargetted(ped, false)
    SetPedDropsWeaponsWhenDead(ped, false)
    if cfg.weapon then
        loadWeapon(cfg.weapon)
        GiveWeaponToPed(ped, joaat(cfg.weapon), 200, false, true)
    end
    return ped
end

local function playerVehicle()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
    return 0
end

local function spawnChaseCop(pos)
    local vehHash = SK.LoadModel('police')
    if not vehHash then return end
    local pedHash = SK.LoadModel('s_m_y_cop_01')
    if not pedHash then SK.UnloadModel(vehHash) return end

    local veh = CreateVehicle(vehHash, pos.x, pos.y, pos.z, pos.w or 0.0, false, false)
    SK.UnloadModel(vehHash)
    if veh == 0 then return end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleSiren(veh, true)

    local ped = CreatePedInsideVehicle(veh, 4, pedHash, -1, false, false)
    SK.UnloadModel(pedHash)
    if ped == 0 then DeleteEntity(veh) return end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)

    TaskVehicleChase(ped, PlayerPedId())
    SetTaskVehicleChaseBehaviorFlag(ped, 32, true)
    SetTaskVehicleChaseIdealPursuitDistance(ped, 15.0)

    CreateThread(function()
        Wait(60000)
        if DoesEntityExist(ped) then SetPedAsNoLongerNeeded(ped) end
        if DoesEntityExist(veh) then SetEntityAsNoLongerNeeded(veh) end
    end)
end

local function runChatter(ctx, queue)
    if type(queue) ~= 'table' or #queue == 0 then return end
    local start = GetGameTimer()
    CreateThread(function()
        for _, line in ipairs(queue) do
            if not ctx.active then return end
            local waitMs = math.max(0, (line.atMs or 0) - (GetGameTimer() - start))
            if waitMs > 0 then Wait(waitMs) end
            SendNUIMessage({ type = 'missions:subtitle', speaker = line.speaker, body = line.body, duration = line.duration or 2800 })
        end
    end)
end

local function cleanup(ctx)
    if ctx.cleaned then return end
    ctx.cleaned = true
    ctx.active = false
    if ctx.blip and DoesBlipExist(ctx.blip) then
        RemoveBlip(ctx.blip)
        ctx.blip = nil
    end
    if SKBankAlarm and SKBankAlarm.active then
        StopAlarm(SKBankAlarm.id, true)
        SKBankAlarm = nil
    end
end

function handler.start(ctx)
    local obj = ctx.objective
    if type(obj.coords) ~= 'vector3' then return nil end
    local coords = obj.coords
    ctx.active = true
    ctx.peds = {}
    ctx.cleaned = false

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 1)
    ctx.blip = blip

    if type(obj.bankAlarm) == 'string' then
        CreateThread(function()
            PrepareAlarm(obj.bankAlarm)
            Wait(1000)
            StartAlarm(obj.bankAlarm, true)
            Wait(500)
            if not IsAlarmPlaying(obj.bankAlarm) then StartAlarm(obj.bankAlarm, true) end
            SKBankAlarm = { active = true, id = obj.bankAlarm }
        end)
    end

    for _, rob in ipairs(obj.robbers or {}) do
        ctx.peds[#ctx.peds + 1] = spawnRobber(rob)
    end

    CreateThread(function()
        while ctx.active do
            local veh = playerVehicle()
            if veh ~= 0 then
                local pcoords = GetEntityCoords(PlayerPedId())
                if #(pcoords - coords) < (obj.triggerRadius or 12.0) then
                    ctx.vehicle = veh

                    SetVehicleDoorsLocked(veh, 1)
                    for i, rob in ipairs(obj.robbers or {}) do
                        local ped = ctx.peds[i]
                        if ped and ped ~= 0 and DoesEntityExist(ped) then
                            TaskEnterVehicle(ped, veh, 8000, rob.seatIndex or (i - 1), 2.0, 1, 0)
                        end
                    end

                    local enterDeadline = GetGameTimer() + 8000
                    while GetGameTimer() < enterDeadline do
                        local allIn = true
                        for i, rob in ipairs(obj.robbers or {}) do
                            local ped = ctx.peds[i]
                            if ped and ped ~= 0 and DoesEntityExist(ped) and not IsPedInVehicle(ped, veh, false) then
                                allIn = false
                                break
                            end
                        end
                        if allIn then break end
                        Wait(250)
                    end

                    for i, rob in ipairs(obj.robbers or {}) do
                        local ped = ctx.peds[i]
                        if ped and ped ~= 0 and DoesEntityExist(ped) and not IsPedInVehicle(ped, veh, false) then
                            SetPedIntoVehicle(ped, veh, rob.seatIndex or (i - 1))
                        end
                    end
                    SetVehicleDoorsLocked(veh, 2)

                    if ctx.blip and DoesBlipExist(ctx.blip) then
                        RemoveBlip(ctx.blip)
                        ctx.blip = nil
                    end

                    SetPlayerWantedLevel(PlayerId(), obj.wantedStars or 4, false)
                    SetPlayerWantedLevelNow(PlayerId(), false)

                    for _, copPos in ipairs(obj.chaseCops or {}) do
                        spawnChaseCop(copPos)
                    end

                    runChatter(ctx, obj.chatter)
                    Wait(3000)

                    if not ctx.active then return end
                    ctx.active = false
                    SKGetawayRobbers = ctx.peds
                    SKGetawayVehicle = veh
                    lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'getaway_pickup' })
                    return
                end
            end
            Wait(500)
        end
    end)

    return {
        remove = function()
            if ctx.points then
                for _, p in ipairs(ctx.points) do if p and p.remove then p:remove() end end
                ctx.points = nil
            end
            cleanup(ctx)
        end,
    }
end

function handler.stop(ctx)
    if ctx.points then
        for _, p in ipairs(ctx.points) do if p and p.remove then p:remove() end end
        ctx.points = nil
    end
    cleanup(ctx)
end

SKObjectives[ObjectiveType.GETAWAY_PICKUP] = handler
