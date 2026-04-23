-- Objective: visitLocation
SKObjectives = SKObjectives or {}

local handler = {}

function handler.start(ctx)
    local obj = ctx.objective
    if not obj or type(obj.coords) ~= 'vector3' then return nil end

    local coords = obj.coords
    local radius = obj.radius or 6.0
    local triggered = false

    if obj.waypointOnly then
        SetNewWaypoint(coords.x, coords.y)
    else
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, obj.blipSprite or 480)
        SetBlipColour(blip, obj.blipColor or 5)
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, obj.blipColor or 5)
        ctx.blip = blip
    end

    if type(obj.bankAlarm) == 'string' then
        CreateThread(function()
            local loadAlarm = PrepareAlarm(obj.bankAlarm)
           while not loadAlarm do
            Wait(100)
           end
            StartAlarm(obj.bankAlarm, true)
            SKBankAlarm = { active = true, id = obj.bankAlarm }
        end)
    end

    local label = obj.label or 'Drive to the marker'
    local promptShown = false

    local outer = lib.points.new({
        coords = coords,
        distance = 80.0,
        nearby = function()
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0,
                0, 0, 0, 0, 0, 0,
                radius * 1.5, radius * 1.5, 1.0,
                80, 180, 255, 140,
                false, true, 2, false, nil, nil, false)
        end,
    })

    local inner = lib.points.new({
        coords = coords,
        distance = radius,
        onEnter = function()
            if triggered then return end
            if obj.requiresVehicle then
                if not IsPedInAnyVehicle(PlayerPedId(), false) then
                    SendNUIMessage({ type = 'prompt:show', key = '!', text = 'Stay in your car' })
                    return
                end
            end
            triggered = true
            SendNUIMessage({ type = 'prompt:hide' })
            local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'visit_location' })
            if not result or not result.ok then triggered = false end
        end,
        onExit = function()
            if promptShown then
                SendNUIMessage({ type = 'prompt:hide' })
                promptShown = false
            end
        end,
        nearby = function()
            if triggered then return end
            if obj.requiresVehicle and not IsPedInAnyVehicle(PlayerPedId(), false) then
                promptShown = true
                SendNUIMessage({ type = 'prompt:show', key = '!', text = 'Return to your car' })
            elseif promptShown then
                promptShown = false
                SendNUIMessage({ type = 'prompt:hide' })
            end
        end,
    })

    ctx.points = { outer, inner }

    return {
        remove = function()
            for _, p in ipairs(ctx.points or {}) do
                if p and p.remove then p:remove() end
            end
            if ctx.blip and DoesBlipExist(ctx.blip) then RemoveBlip(ctx.blip) end
            ctx.blip = nil
            ctx.points = nil
        end,
    }
end

function handler.stop(ctx)
    for _, p in ipairs(ctx.points or {}) do
        if p and p.remove then p:remove() end
    end
    if ctx.blip and DoesBlipExist(ctx.blip) then RemoveBlip(ctx.blip) end
    if SKBankAlarm and SKBankAlarm.active then
        StopAlarm(SKBankAlarm.id, true)
        SKBankAlarm = nil
    end
    ctx.blip = nil
    ctx.points = nil
end

SKObjectives[ObjectiveType.VISIT_LOCATION] = handler
