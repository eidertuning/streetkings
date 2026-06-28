-- Objective: pickupPackage
-- Supports an optional `npc` block for curbside handoffs.
-- When npc.cinematic is set, a single E press launches a takeover cutscene
-- that runs dialogue, walk-to-car, hand-off, and dismiss as one beat.
SKObjectives = SKObjectives or {}

local handler = {}

local function cleanupHandoff(ctx)
    if ctx.handoff then
        SKNpcHandoff.stop(ctx.handoff)
        ctx.handoff = nil
    end
end

function handler.start(ctx)
    local obj = ctx.objective
    if type(obj.coords) ~= 'vector3' then return nil end
    local coords = obj.coords
    local radius = obj.radius or 3.5
    local npcCfg = obj.npc
    local cinematic = npcCfg and npcCfg.cinematic or nil
    local triggered = false
    local promptShown = false
    ctx.active = true

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 46)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 8)
    ctx.blip = blip

    local function showPrompt(text)
        if promptShown or triggered then return end
        promptShown = true
        SendNUIMessage({ type = 'prompt:show', key = SKInput.getInteractLabel(), text = text or obj.label or _L('lua.prompts.pick_up_package') })
    end

    local function hidePrompt()
        if not promptShown then return end
        promptShown = false
        SendNUIMessage({ type = 'prompt:hide' })
    end

    local function advance(source)
        if triggered then return end
        triggered = true
        ctx.active = false
        hidePrompt()
        local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = source })
        if not result or not result.ok then
            triggered = false
            ctx.active = true
        end
    end

    local function ensureHandoff()
        if npcCfg and not ctx.handoff then
            ctx.handoff = SKNpcHandoff.start(npcCfg, {
                onReachedWindow = function() end,
                onHandoffComplete = function()
                    if cinematic then return end
                    if ctx.handoff then SKNpcHandoff.dismiss(ctx.handoff) end
                    advance('pickup_package_npc')
                end,
            })
            if not cinematic and npcCfg.autoApproach then
                CreateThread(function()
                    Wait(600)
                    if not ctx.active or triggered or not ctx.handoff then return end
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    if veh and veh ~= 0 then
                        SKNpcHandoff.approach(ctx.handoff, veh)
                    end
                end)
            end
        end
    end

    if npcCfg then
        local pp = GetEntityCoords(PlayerPedId())
        local dx, dy = pp.x - coords.x, pp.y - coords.y
        if (dx * dx + dy * dy) <= 3600.0 then ensureHandoff() end
    end

    local outer = lib.points.new({
        coords = coords,
        distance = 60.0,
        onEnter = function() ensureHandoff() end,
        onExit = function()
            if ctx.handoff and not triggered then
                cleanupHandoff(ctx)
            end
        end,
        nearby = function()
            if not npcCfg then
                DrawMarker(27, coords.x, coords.y, coords.z - 0.9,
                    0, 0, 0, 0, 0, 0,
                    radius, radius, 0.6,
                    220, 120, 40, 160,
                    false, true, 2, false, nil, nil, false)
            end
        end,
    })

    local function triggerApproach()
        if ctx.handoff then
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            if veh and veh ~= 0 then SKNpcHandoff.approach(ctx.handoff, veh) end
        end
    end

    if npcCfg and not cinematic then
        local pp = GetEntityCoords(PlayerPedId())
        local dx, dy = pp.x - coords.x, pp.y - coords.y
        if (dx * dx + dy * dy) <= (radius * radius) then triggerApproach() end
    end

    local function runCinematicHandoff()
        if triggered or not ctx.handoff then return end
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if not veh or veh == 0 then return end
        triggered = true
        ctx.active = false
        hidePrompt()
        local spec = {}
        for k, v in pairs(cinematic) do spec[k] = v end
        spec.playerVehicle = veh
        SKNpcHandoff.runCinematic(ctx.handoff, spec, function()
            local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'pickup_package_cinematic' })
            if not result or not result.ok then
                triggered = false
                ctx.active = true
            end
        end)
    end

    local inner = lib.points.new({
        coords = coords,
        distance = radius,
        onEnter = function()
            if triggered then return end
            if cinematic then return end
            if npcCfg then
                triggerApproach()
                return
            end
            showPrompt()
        end,
        onExit = function()
            if not npcCfg then hidePrompt() end
            if cinematic then hidePrompt() end
        end,
        nearby = function()
            if triggered then return end
            if cinematic then
                if not ctx.handoff or ctx.handoff.ped == 0 then return end
                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                if not veh or veh == 0 then
                    hidePrompt()
                    return
                end
                showPrompt(obj.label or 'Meet Saint')
                if SKInput.isInteractJustReleased() then
                    runCinematicHandoff()
                end
                return
            end
            if npcCfg then
                if ctx.handoff and SKNpcHandoff.isAtWindow(ctx.handoff) then
                    showPrompt()
                    if SKInput.isInteractJustReleased() then
                        hidePrompt()
                        SKNpcHandoff.triggerHandoff(ctx.handoff)
                    end
                end
                return
            end
            if SKInput.isInteractJustReleased() then
                advance('pickup_package')
            end
        end,
    })

    ctx.points = { outer, inner }

    return {
        remove = function()
            ctx.active = false
            for _, p in ipairs(ctx.points or {}) do if p and p.remove then p:remove() end end
            if ctx.blip and DoesBlipExist(ctx.blip) then RemoveBlip(ctx.blip) end
            hidePrompt()
            cleanupHandoff(ctx)
            ctx.blip = nil
            ctx.points = nil
        end,
    }
end

function handler.stop(ctx)
    ctx.active = false
    for _, p in ipairs(ctx.points or {}) do if p and p.remove then p:remove() end end
    if ctx.blip and DoesBlipExist(ctx.blip) then RemoveBlip(ctx.blip) end
    SendNUIMessage({ type = 'prompt:hide' })
    cleanupHandoff(ctx)
    ctx.blip = nil
    ctx.points = nil
end

SKObjectives[ObjectiveType.PICKUP_PACKAGE] = handler
