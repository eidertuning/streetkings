-- Shared helper for curbside NPC handoff interactions on pickup/deliver objectives
--
-- A handoff is a tiny state machine:
--   spawn -> approach -> atWindow -> handoff -> dismiss -> done
--
-- Callers start the helper, ask whether the ped has reached the window, and
-- trigger the handoff when appropriate (pickup waits for a key press,
-- delivery auto-triggers, talk-only peds trigger on arrival for a chatter-only beat).

SKNpcHandoff = {}

local DEFAULT_PROP_BONE = 28422 -- SKEL_R_Hand commonly used for right-hand prop attach
local APPROACH_SPEED = 1.5
local WINDOW_REACHED_DIST = 1.4
local WINDOW_OFFSET_X = -1.25
local WINDOW_OFFSET_Y = 0.25
local WINDOW_OFFSET_Z = 0.0
local DEFAULT_HANDOFF_DURATION_MS = 2200
local RE_TASK_INTERVAL_MS = 750

---@param veh integer
---@return vector3|nil
local function windowCoord(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local off = GetOffsetFromEntityInWorldCoords(veh, WINDOW_OFFSET_X, WINDOW_OFFSET_Y, WINDOW_OFFSET_Z)
    return vector3(off.x, off.y, off.z)
end

---@param veh integer
---@param refPos vector3
---@return vector3|nil
local function pickDoorCoord(veh, refPos)
    if not veh or veh == 0 or not DoesEntityExist(veh) or type(refPos) ~= 'vector3' then return windowCoord(veh) end
    local d = GetOffsetFromEntityInWorldCoords(veh, WINDOW_OFFSET_X, WINDOW_OFFSET_Y, WINDOW_OFFSET_Z)
    local p = GetOffsetFromEntityInWorldCoords(veh, -WINDOW_OFFSET_X, WINDOW_OFFSET_Y, WINDOW_OFFSET_Z)
    local rx, ry = refPos.x, refPos.y
    local dd = (rx - d.x) * (rx - d.x) + (ry - d.y) * (ry - d.y)
    local pp = (rx - p.x) * (rx - p.x) + (ry - p.y) * (ry - p.y)
    if dd <= pp then return vector3(d.x, d.y, d.z) end
    return vector3(p.x, p.y, p.z)
end

-- Play the idle pose once and hold on the last frame. No re-task loop.
---@param ped integer
---@param anim table|nil
local function playHoldIdle(ped, anim)
    if not anim or type(anim.dict) ~= 'string' or type(anim.name) ~= 'string' then return end
    if not SK.LoadAnimDict(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.name,
        anim.blendIn or 4.0, anim.blendOut or -4.0,
        -1, anim.flags or 2, 0.0, false, false, false)
end

---@param ped integer
---@param anim table|nil
---@param durationMs integer|nil
local function playOneShotAnim(ped, anim, durationMs)
    if not anim or type(anim.dict) ~= 'string' or type(anim.name) ~= 'string' then return 0 end
    if not SK.LoadAnimDict(anim.dict) then return 0 end
    TaskPlayAnim(ped, anim.dict, anim.name,
        anim.blendIn or 4.0, anim.blendOut or -4.0,
        durationMs or -1, anim.flags or 48, 0.0, false, false, false)
    return durationMs or anim.durationMs or DEFAULT_HANDOFF_DURATION_MS
end

---@param cfg table
---@return integer ped, integer prop
local function spawnPedWithProp(cfg)
    local spawn = cfg.spawnCoords or vector3(0.0, 0.0, 0.0)
    local heading = cfg.spawnHeading or 0.0

    local pedHash = SK.LoadModel(cfg.model)
    if not pedHash then return 0, 0 end

    local ped = CreatePed(4, pedHash, spawn.x, spawn.y, spawn.z, heading, false, false)
    SK.UnloadModel(pedHash)
    SetPedDefaultComponentVariation(ped)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedConfigFlag(ped, 128, true) -- disable flinching
    SetEntityInvincible(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedDropsWeaponsWhenDead(ped, false)
    Wait(500)
    FreezeEntityPosition(ped, true)

    local prop = 0
    local wantProp = (cfg.mode == 'giving') and type(cfg.prop) == 'table'
    if wantProp then
        local propHash = SK.LoadModel(cfg.prop.model)
        if propHash then
            prop = CreateObject(propHash, spawn.x, spawn.y, spawn.z + 0.2, true, true, false)
            SK.UnloadModel(propHash)
            if prop ~= 0 then
                local boneTag = cfg.prop.bone or DEFAULT_PROP_BONE
                local bone    = GetPedBoneIndex(ped, boneTag)
                local offset  = cfg.prop.offset or vector3(0.0, 0.0, 0.0)
                local rot     = cfg.prop.rot or vector3(0.0, 0.0, 0.0)
                AttachEntityToEntity(prop, ped, bone,
                    offset.x, offset.y, offset.z,
                    rot.x, rot.y, rot.z,
                    true, true, false, true, 1, true)
            end
        end
    end

    return ped, prop
end

---@param ped integer
---@param prop integer
local function cleanUpPedAndProp(ped, prop, releaseMs)
    releaseMs = releaseMs or 0
    if releaseMs > 0 then Wait(releaseMs) end
    if prop and prop ~= 0 and DoesEntityExist(prop) then
        SetEntityAsMissionEntity(prop, false, true)
        DeleteEntity(prop)
    end
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        ClearPedTasks(ped)
        SetEntityAsMissionEntity(ped, false, true)
        SetPedAsNoLongerNeeded(ped)
    end
end

---@param ped integer
---@param prop integer
local function despawnPedAndProp(ped, prop)
    if prop and prop ~= 0 and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        SetEntityAsMissionEntity(prop, false, true)
        DeleteEntity(prop)
    end
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        ClearPedTasksImmediately(ped)
        SetEntityAsMissionEntity(ped, false, true)
        DeleteEntity(ped)
    end
end

local APPROACH_STOP_DIST  = 1.0
local APPROACH_REACH_DIST = 2.0 -- distance from player that counts as "at window"
local FACE_TURN_MS        = 1000
-- Fallback carry idle used when a receiving NPC takes the box
local CARRY_BOX_IDLE_DEFAULT = { dict = 'anim@heists@box_carry@', name = 'idle', flags = 50 }

---@param handle table
---@param playerVeh integer
local function runApproach(handle, playerVeh)
    local ped = handle.ped
    if not ped or not DoesEntityExist(ped) then return end
    if not playerVeh or playerVeh == 0 or not DoesEntityExist(playerVeh) then return end

    CreateThread(function()
        if not handle.active then return end
        handle.approaching = true
        FreezeEntityPosition(ped, false)
        local playerPed = PlayerPedId()
        TaskGoToEntity(ped, playerPed, -1, APPROACH_STOP_DIST, APPROACH_SPEED, 1073741824, 0)

        while handle.active and DoesEntityExist(ped) do
            local pedPos    = GetEntityCoords(ped)
            local playerPos = GetEntityCoords(playerPed)
            local dx = pedPos.x - playerPos.x
            local dy = pedPos.y - playerPos.y
            if (dx * dx + dy * dy) <= (APPROACH_REACH_DIST * APPROACH_REACH_DIST) then break end
            Wait(200)
        end

        handle.approaching = false
        if not handle.active then return end
        handle.atWindow = true

        TaskTurnPedToFaceEntity(ped, playerVeh, FACE_TURN_MS)
        Wait(FACE_TURN_MS)

        if not handle.active then return end
        playHoldIdle(ped, handle.cfg.idleWait)

        if type(handle.onReachedWindow) == 'function' then
            pcall(handle.onReachedWindow)
        end
    end)
end

---@param handle table
local function runChatter(handle)
    local queue = handle.cfg.chatter
    if type(queue) ~= 'table' or #queue == 0 then return end
    local start = GetGameTimer()
    CreateThread(function()
        for _, line in ipairs(queue) do
            if not handle.active then return end
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

---@param handle table
local function runHandoffAnim(handle)
    local cfg = handle.cfg
    local ped = handle.ped
    if not (ped and DoesEntityExist(ped)) then return end

    local durationMs = playOneShotAnim(ped, cfg.handoffAnim, cfg.handoffAnim and cfg.handoffAnim.durationMs)
    if durationMs <= 0 then durationMs = DEFAULT_HANDOFF_DURATION_MS end

    runChatter(handle)

    local detachMs = math.max(0, cfg.handoffDetachMs or math.floor(durationMs * 0.45))

    CreateThread(function()
        Wait(detachMs)
        if not handle.active then return end
        if cfg.mode == 'giving' then
            if handle.prop and handle.prop ~= 0 and DoesEntityExist(handle.prop) then
                DetachEntity(handle.prop, true, true)
                SetEntityAsMissionEntity(handle.prop, false, true)
                DeleteEntity(handle.prop)
                handle.prop = 0
            end
            -- Wait for the give anim to finish, then clear carry pose so the ped
            -- doesn't stand in box-carry stance with empty hands.
            local remaining = durationMs - detachMs
            if remaining > 0 then Wait(remaining + 100) end
            if ped and DoesEntityExist(ped) then
                ClearPedTasks(ped)
            end
        elseif cfg.mode == 'receiving' and type(cfg.prop) == 'table' then
            local propHash = SK.LoadModel(cfg.prop.model)
            if propHash then
                local p = GetEntityCoords(ped)
                local prop = CreateObject(propHash, p.x, p.y, p.z + 0.2, true, true, false)
                SK.UnloadModel(propHash)
                if prop ~= 0 then
                    local boneTag = cfg.prop.bone or DEFAULT_PROP_BONE
                    local bone    = GetPedBoneIndex(ped, boneTag)
                    local offset  = cfg.prop.offset or vector3(0.0, 0.0, 0.0)
                    local rot     = cfg.prop.rot or vector3(0.0, 0.0, 0.0)
                    AttachEntityToEntity(prop, ped, bone,
                        offset.x, offset.y, offset.z,
                        rot.x, rot.y, rot.z,
                        true, true, false, true, 1, true)
                    handle.prop = prop
                    playHoldIdle(ped, cfg.idleAfterHandoff or CARRY_BOX_IDLE_DEFAULT)
                end
            end
        end
    end)

    CreateThread(function()
        Wait(durationMs)
        if not handle.active then return end
        handle.handoffDone = true
        if type(handle.onHandoffComplete) == 'function' then
            pcall(handle.onHandoffComplete)
        end
    end)
end

---@param handle table
local function runDismiss(handle)
    local cfg = handle.cfg

    -- Take immediate ownership of the ped so stop() can no longer touch it.
    -- From this point on the dismiss thread is fully responsible for cleanup.
    local ped  = handle.ped
    local prop = handle.prop
    handle.ped  = 0
    handle.prop = 0
    handle.dismissed = true

    if not (ped and ped ~= 0 and DoesEntityExist(ped)) then
        if type(handle.onDismissed) == 'function' then pcall(handle.onDismissed) end
        return
    end

    local target = cfg.dismissWalkTarget or cfg.spawnCoords

    if type(target) == 'vector3' then
        TaskGoStraightToCoord(ped, target.x, target.y, target.z, cfg.dismissSpeed or APPROACH_SPEED, 10000, 0.0, 0.5)
    end

    CreateThread(function()
        if type(target) == 'vector3' then
            local deadline = GetGameTimer() + 10000
            while GetGameTimer() < deadline and DoesEntityExist(ped) do
                local pos = GetEntityCoords(ped)
                local dx  = pos.x - target.x
                local dy  = pos.y - target.y
                if (dx * dx + dy * dy) <= 1.6 then break end
                Wait(250)
            end
        end
        if cfg.deleteOnDismiss then
            despawnPedAndProp(ped, prop)
        else
            local releaseMs = cfg.dismissReleaseMs or 0
            cleanUpPedAndProp(ped, prop, releaseMs)
        end
        if type(handle.onDismissed) == 'function' then pcall(handle.onDismissed) end
    end)
end

---@param cfg table  -- the mission's `npc` block + any callbacks
---@param callbacks table|nil
---@return table handle
function SKNpcHandoff.start(cfg, callbacks)
    assert(type(cfg) == 'table', 'SKNpcHandoff.start: cfg required')
    callbacks = callbacks or {}

    local handle = {
        cfg = cfg,
        active = true,
        ped = 0,
        prop = 0,
        atWindow = false,
        handoffStarted = false,
        handoffDone = false,
        dismissed = false,
        onReachedWindow = callbacks.onReachedWindow,
        onHandoffComplete = callbacks.onHandoffComplete,
        onDismissed = callbacks.onDismissed,
    }

    handle.ped, handle.prop = spawnPedWithProp(cfg)
    if handle.ped == 0 then
        handle.active = false
        return handle
    end

    playHoldIdle(handle.ped, cfg.idleWait)
    local idleAnim = cfg.idleWait
    if cfg.mode == 'giving' and idleAnim and type(idleAnim.dict) == 'string' then
        CreateThread(function()
            while handle.active do
                Wait(500)
                if not handle.active then break end
                local ped = handle.ped
                if not ped or ped == 0 or not DoesEntityExist(ped) then break end
                if not handle.approaching and not handle.handoffStarted then
                    if not IsEntityPlayingAnim(ped, idleAnim.dict, idleAnim.name, 3) then
                        TaskPlayAnim(ped, idleAnim.dict, idleAnim.name,
                            idleAnim.blendIn or 4.0, idleAnim.blendOut or -4.0,
                            -1, idleAnim.flags or 50, 0.0, false, false, false)
                    end
                end
            end
        end)
    end

    return handle
end

---@param handle table
---@param playerVeh integer
function SKNpcHandoff.approach(handle, playerVeh)
    if not handle or not handle.active or handle.atWindow then return end
    runApproach(handle, playerVeh)
end

---@param handle table
---@return boolean
function SKNpcHandoff.isAtWindow(handle)
    return handle and handle.active and handle.atWindow == true and not handle.handoffStarted
end

---@param handle table
function SKNpcHandoff.triggerHandoff(handle)
    if not handle or not handle.active or handle.handoffStarted then return end
    if not handle.atWindow then return end
    handle.handoffStarted = true

    if type(handle.cfg.handoffAnim) == 'table' then
        runHandoffAnim(handle)
    else
        -- talkOnly path: no anim, just chatter then advance
        runChatter(handle)
        local queue = handle.cfg.chatter or {}
        local last = queue[#queue]
        local totalMs = last and ((last.atMs or 0) + (last.duration or 2500)) or 2000
        CreateThread(function()
            Wait(totalMs)
            if not handle.active then return end
            handle.handoffDone = true
            if type(handle.onHandoffComplete) == 'function' then
                pcall(handle.onHandoffComplete)
            end
        end)
    end
end

---@param handle table
function SKNpcHandoff.dismiss(handle)
    if not handle or not handle.active or handle.dismissed then return end
    runDismiss(handle)
end

---@param handle table
function SKNpcHandoff.stop(handle)
    if not handle then return end
    handle.active = false
    if handle.ped ~= 0 or handle.prop ~= 0 then
        despawnPedAndProp(handle.ped, handle.prop)
        handle.ped = 0
        handle.prop = 0
    end
end

-- One-shot cinematic handoff: cameras + subtitles + live ped tasks run
-- concurrently. Expected `spec` keys:
--   shots, lookAt, subtitles, title, subtitle (forwarded to SKCutscene.playLive)
--   approachAtMs     - when Saint starts walking to the car (default 0)
--   handoffAtMs      - when the hand-off anim + prop swap fires (optional;
--                      waits for atWindow after this timestamp)
--   handoffTimeoutMs - max wait for atWindow before forcing handoff (default 6000)
--   dismissAfterHandoff - set false to skip dismiss walk (default true)
---@param handle table
---@param spec table
---@param onDone function|nil
function SKNpcHandoff.runCinematic(handle, spec, onDone)
    local function finish()
        if type(onDone) == 'function' then pcall(onDone) end
    end

    if not handle or not handle.active or type(spec) ~= 'table' then
        finish()
        return
    end

    local approachAtMs = spec.approachAtMs or 0
    local handoffAtMs = spec.handoffAtMs
    local handoffTimeoutMs = spec.handoffTimeoutMs or 6000
    local dismissAfterHandoff = spec.dismissAfterHandoff ~= false

    local playerVeh = spec.playerVehicle
    if not playerVeh or playerVeh == 0 or not DoesEntityExist(playerVeh) then
        playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    end

    if approachAtMs <= 0 then
        if playerVeh and playerVeh ~= 0 then runApproach(handle, playerVeh) end
    else
        CreateThread(function()
            Wait(approachAtMs)
            if not handle.active then return end
            local veh = playerVeh
            if not veh or veh == 0 or not DoesEntityExist(veh) then
                veh = GetVehiclePedIsIn(PlayerPedId(), false)
            end
            if veh and veh ~= 0 then runApproach(handle, veh) end
        end)
    end

    if type(handoffAtMs) == 'number' then
        CreateThread(function()
            Wait(handoffAtMs)
            if not handle.active then return end
            local deadline = GetGameTimer() + handoffTimeoutMs
            while handle.active and not handle.atWindow and GetGameTimer() < deadline do
                Wait(100)
            end
            if not handle.active or handle.handoffStarted then return end
            handle.atWindow = true
            handle.handoffStarted = true
            if type(handle.cfg.handoffAnim) == 'table' then
                runHandoffAnim(handle)
            else
                handle.handoffDone = true
            end
        end)
    end


    if handle.ped and handle.ped ~= 0 and DoesEntityExist(handle.ped) then
        FreezeEntityPosition(handle.ped, false)
        TaskTurnPedToFaceEntity(handle.ped, PlayerPedId(), -1)
    end

    SKCutscene.playLive(spec, {
        actors = { handle.ped },
        actorRestoreAnims = { handle.cfg.idleWait },
        onDone = function()
            CreateThread(function()
                if type(handoffAtMs) == 'number' and not handle.handoffDone then
                    local deadline = GetGameTimer() + handoffTimeoutMs + 4000
                    while handle.active and not handle.handoffDone and GetGameTimer() < deadline do
                        Wait(100)
                    end
                end
                if handle.active and dismissAfterHandoff then
                    runDismiss(handle)
                end
                finish()
            end)
        end,
    })
end
