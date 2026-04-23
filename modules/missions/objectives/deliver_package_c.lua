-- Objective: deliverPackage (with optional timer + mid-mission cutscene)
-- Supports an optional `npc` block. When npc.cinematic is set, a single E
-- press at the dropoff launches a takeover cutscene that runs approach,
-- hand-off (prop passes to the receiver), dialogue, and dismiss as one beat.
-- Without cinematic, the legacy auto-handoff on arrival is used.
SKObjectives = SKObjectives or {}

local handler = {}

local function cleanupHandoff(ctx)
    if ctx.handoff then
        SKNpcHandoff.stop(ctx.handoff)
        ctx.handoff = nil
    end
end

local function startTimer(ctx, seconds)
    ctx.timerEnd = GetGameTimer() + seconds * 1000
    ctx.timerActive = true
    CreateThread(function()
        while ctx.timerActive do
            local remainingMs = ctx.timerEnd - GetGameTimer()
            if remainingMs <= 0 then
                ctx.timerActive = false
                SendNUIMessage({ type = 'missions:timer', seconds = 0, active = false })
                SendNUIMessage({ type = 'missions:timerFailed' })
                lib.callback.await('streetkings:missions:abort', false)
                return
            end
            SendNUIMessage({ type = 'missions:timer', seconds = math.ceil(remainingMs / 1000), active = true })
            Wait(500)
        end
        SendNUIMessage({ type = 'missions:timer', seconds = 0, active = false })
    end)
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

function handler.start(ctx)
    local obj = ctx.objective
    if type(obj.coords) ~= 'vector3' then return nil end
    local coords = obj.coords
    local radius = obj.radius or 4.5
    local npcCfg = obj.npc
    local cinematic = npcCfg and npcCfg.cinematic or nil
    local triggered = false
    local promptShown = false
    ctx.active = true

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 501)
    SetBlipColour(blip, 46)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 46)
    ctx.blip = blip

    if type(obj.timerSeconds) == 'number' and obj.timerSeconds > 0 then
        startTimer(ctx, obj.timerSeconds)
    end
    scheduleMidMessages(ctx, obj)

    local function showPrompt(text)
        if promptShown or triggered then return end
        promptShown = true
        SendNUIMessage({ type = 'prompt:show', key = SKInput.getInteractLabel(), text = text or obj.label or 'Hand over the package' })
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
        ctx.timerActive = false
        hidePrompt()
        if type(obj.cutsceneOnComplete) == 'string' then
            SKCutscene.play(obj.cutsceneOnComplete, {})
        end
        local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = source })
        if not result or not result.ok then
            triggered = false
            ctx.active = true
            if type(obj.timerSeconds) == 'number' and obj.timerSeconds > 0 then
                startTimer(ctx, math.max(5, math.ceil((ctx.timerEnd - GetGameTimer()) / 1000)))
            end
        end
    end

    local function ensureHandoff()
        if npcCfg and not ctx.handoff then
            ctx.handoff = SKNpcHandoff.start(npcCfg, {
                onReachedWindow = function()
                    if cinematic then return end
                    -- Legacy delivery: auto-trigger handoff the moment the ped reaches the window
                    if ctx.handoff then SKNpcHandoff.triggerHandoff(ctx.handoff) end
                end,
                onHandoffComplete = function()
                    if cinematic then return end
                    if ctx.handoff then SKNpcHandoff.dismiss(ctx.handoff) end
                    advance('deliver_package_npc')
                end,
            })
        end
    end

    if npcCfg then
        local pp = GetEntityCoords(PlayerPedId())
        local dx, dy = pp.x - coords.x, pp.y - coords.y
        if (dx * dx + dy * dy) <= 4900.0 then ensureHandoff() end
    end

    local outer = lib.points.new({
        coords = coords,
        distance = 70.0,
        onEnter = function() ensureHandoff() end,
        onExit = function()
            if ctx.handoff and not triggered then
                cleanupHandoff(ctx)
            end
        end,
        nearby = function()
            if not npcCfg then
                DrawMarker(1, coords.x, coords.y, coords.z - 1.0,
                    0, 0, 0, 0, 0, 0,
                    radius, radius, 1.2,
                    220, 120, 40, 150,
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
        ctx.timerActive = false
        hidePrompt()
        local spec = {}
        for k, v in pairs(cinematic) do spec[k] = v end
        spec.playerVehicle = veh
        SKNpcHandoff.runCinematic(ctx.handoff, spec, function()
            local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'deliver_package_cinematic' })
            if not result or not result.ok then
                triggered = false
                ctx.active = true
                if type(obj.timerSeconds) == 'number' and obj.timerSeconds > 0 then
                    startTimer(ctx, math.max(5, math.ceil((ctx.timerEnd - GetGameTimer()) / 1000)))
                end
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
            advance('deliver_package')
        end,
        onExit = function()
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
                showPrompt(obj.label or 'Hand over the package')
                if SKInput.isInteractJustReleased() then
                    runCinematicHandoff()
                end
            end
        end,
    })

    ctx.points = { outer, inner }

    return {
        remove = function()
            ctx.active = false
            ctx.timerActive = false
            SendNUIMessage({ type = 'missions:timer', seconds = 0, active = false })
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
    ctx.timerActive = false
    SendNUIMessage({ type = 'missions:timer', seconds = 0, active = false })
    for _, p in ipairs(ctx.points or {}) do if p and p.remove then p:remove() end end
    if ctx.blip and DoesBlipExist(ctx.blip) then RemoveBlip(ctx.blip) end
    SendNUIMessage({ type = 'prompt:hide' })
    cleanupHandoff(ctx)
    ctx.blip = nil
    ctx.points = nil
end

SKObjectives[ObjectiveType.DELIVER_PACKAGE] = handler
