SKObjectives = SKObjectives or {}

local handler = {}

local function cleanup(ctx)
    if ctx.cleaned then return end
    ctx.cleaned = true
    ctx.active = false
    if ctx.blip and DoesBlipExist(ctx.blip) then
        RemoveBlip(ctx.blip)
        ctx.blip = nil
    end
end

local function lockPassengers(peds, veh)
    for i, ped in ipairs(peds or {}) do
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            SetEntityInvincible(ped, true)
            SetPedCanBeDraggedOut(ped, false)
            SetPedConfigFlag(ped, 251, true) -- cannot exit vehicle
            SetBlockingOfNonTemporaryEvents(ped, true)
            if DoesEntityExist(veh) and GetVehiclePedIsIn(ped, false) ~= veh then
                -- Warp back in if somehow out (rare edge case)
                TaskWarpPedIntoVehicle(ped, veh, i - 1)
            end
        end
    end
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
            if not ctx.active then return end
            TriggerServerEvent('streetkings:missions:midMessage', m.sender or 'Unknown', m.avatar or 'unknown', m.body)
        end)
    end
end

local function runChatter(ctx, queue)
    if type(queue) ~= 'table' or #queue == 0 then return end
    local start = GetGameTimer()
    CreateThread(function()
        for _, line in ipairs(queue) do
            if not ctx.active then return end
            local waitMs = math.max(0, (line.atMs or 0) - (GetGameTimer() - start))
            if waitMs > 0 then Wait(waitMs) end
            SendNUIMessage({
                type = 'missions:subtitle',
                speaker = line.speaker,
                body = line.body,
                duration = line.duration or 2800,
            })
        end
    end)
end

function handler.start(ctx)
    local obj = ctx.objective
    if type(obj.dropoffCoords) ~= 'vector3' then return nil end
    ctx.active = true
    ctx.peds = SKGetawayRobbers or {}
    ctx.vehicle = SKGetawayVehicle or GetVehiclePedIsIn(PlayerPedId(), false)

    local drop = obj.dropoffCoords
    local blip = AddBlipForCoord(drop.x, drop.y, drop.z)
    SetBlipSprite(blip, 67)
    SetBlipColour(blip, 1)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 8)
    ctx.blip = blip

    if type(obj.wantedStars) == 'number' and obj.wantedStars > 0 then
        SetPlayerWantedLevel(PlayerId(), obj.wantedStars, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
    end

    runChatter(ctx, obj.chatter)
    scheduleMidMessages(ctx, obj)

    CreateThread(function()
        local arrivalRadius = obj.arrivalRadius or 18.0
        local arrivalSqr = arrivalRadius * arrivalRadius
        while ctx.active do
            local veh = ctx.vehicle
            if not veh or veh == 0 or not DoesEntityExist(veh) then
                veh = GetVehiclePedIsIn(PlayerPedId(), false)
                if veh ~= 0 and DoesEntityExist(veh) then ctx.vehicle = veh end
            end

            if veh ~= 0 and DoesEntityExist(veh) then
                lockPassengers(ctx.peds, veh)

                if type(obj.wantedStars) == 'number' and obj.wantedStars > 0 then
                    local current = GetPlayerWantedLevel(PlayerId())
                    if current < obj.wantedStars then
                        SetPlayerWantedLevel(PlayerId(), obj.wantedStars, false)
                        SetPlayerWantedLevelNow(PlayerId(), false)
                    end
                end

                local pos = GetEntityCoords(veh)
                local dx = pos.x - drop.x
                local dy = pos.y - drop.y
                if (dx * dx + dy * dy) <= arrivalSqr then
                    ctx.active = false
                    SetPlayerWantedLevel(PlayerId(), 0, false)
                    SetPlayerWantedLevelNow(PlayerId(), false)
                    SKGetawayRobbers = ctx.peds
                    SKGetawayVehicle = ctx.vehicle

                    if not obj.noExitVehicle then
                        local player = PlayerPedId()
                        if IsPedInAnyVehicle(player, false) then
                            TaskLeaveVehicle(player, veh, 0)
                        end
                        for _, p in ipairs(ctx.peds or {}) do
                            if p and p ~= 0 and DoesEntityExist(p) and IsPedInAnyVehicle(p, false) then
                                TaskLeaveVehicle(p, veh, 256)
                            end
                        end
                        Wait(1800)
                    end

                    local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'getaway_ride' })
                    if not result or not result.ok then ctx.active = true end
                    return
                end
            end
            Wait(500)
        end
    end)

    return {
        remove = function()
            cleanup(ctx)
        end,
    }
end

function handler.stop(ctx)
    cleanup(ctx)
end

SKObjectives[ObjectiveType.GETAWAY_RIDE] = handler
