SKCutscene = {}

SKCutscene.definitions = SKCutscene.definitions or {}

---@param id string
---@param def table
function SKCutscene.register(id, def)
    assert(type(id) == 'string' and id ~= '', 'streetkings: cutscene id required')
    SKCutscene.definitions[id] = def
end

local active = false

---@return boolean
function SKCutscene.isActive()
    return active
end

---@param shot table
---@param defaultLookAt vector3|nil
---@return integer
local function createCameraFromShot(shot, defaultLookAt)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local pos = shot.coords or shot.pos
    if pos then SetCamCoord(cam, pos.x, pos.y, pos.z) end
    if shot.rot then
        SetCamRot(cam, shot.rot.x, shot.rot.y, shot.rot.z, 2)
    end
    local lookAt = shot.lookAt or defaultLookAt
    if lookAt then
        PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
    end
    SetCamFov(cam, shot.fov or 50.0)
    return cam
end

---@param ped number
---@param animDef table|nil
local function playPedAnim(ped, animDef)
    if not animDef then return end
    if SK.LoadAnimDict(animDef.dict) then
        TaskPlayAnim(ped, animDef.dict, animDef.name, animDef.blendIn or 4.0, animDef.blendOut or -4.0,
            animDef.duration or -1, animDef.flags or 1, 0.0, false, false, false)
        RemoveAnimDict(animDef.dict)
    end
end

---@param actorDef table
---@param useSyncScene boolean
---@return integer
local function spawnActor(actorDef, useSyncScene)
    local hash = SK.LoadModel(actorDef.model)
    if not hash then return 0 end
    local coords = actorDef.coords
    local heading = actorDef.heading or 0.0
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, heading, false, false)
    SK.UnloadModel(hash)
    SetPedDefaultComponentVariation(ped)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if not (useSyncScene and actorDef.syncAnim) then
        FreezeEntityPosition(ped, true)
        if actorDef.anim then
            playPedAnim(ped, actorDef.anim)
        end
    end
    return ped
end

---@param line table
local function showSubtitle(line)
    local duration = line.duration or 3500
    SendNUIMessage({
        type = 'missions:subtitle',
        speaker = line.speaker,
        body = line.body,
        duration = duration,
    })
end

---@param line table
---@param ctx table
local function playSubtitleActorAnim(line, ctx)
    local spec = line.playAnimOnActor
    if type(spec) ~= 'table' or not ctx.actors then return end
    local idx = spec.index or 1
    local ped = ctx.actors[idx]
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local duration = line.duration or 3500

    if spec.facial then
        -- Pure facial animation - no body task conflict, no carry restore needed.
        CreateThread(function()
            if not SK.LoadAnimDict('mp_facial') then return end
            PlayFacialAnim(ped, 'mic_chatter', 'mp_facial')
            Wait(duration)
            if DoesEntityExist(ped) then
                PlayFacialAnim(ped, 'mood_normal_1', 'facials@gen_male@variations@normal')
            end
            RemoveAnimDict('mp_facial')
        end)
        return
    end

    local dict, name = spec.dict, spec.name
    if type(dict) ~= 'string' or type(name) ~= 'string' then return end
    if not SK.LoadAnimDict(dict) then return end
    TaskPlayAnim(ped, dict, name,
        spec.blendIn or 4.0, spec.blendOut or -4.0,
        duration, spec.flags or 49, 0.0, false, false, false)
    local restoreAnim = ctx.actorRestoreAnims and ctx.actorRestoreAnims[idx]
    if restoreAnim and type(restoreAnim.dict) == 'string' then
        CreateThread(function()
            Wait(duration + 100)
            if not DoesEntityExist(ped) then return end
            if SK.LoadAnimDict(restoreAnim.dict) then
                TaskPlayAnim(ped, restoreAnim.dict, restoreAnim.name,
                    restoreAnim.blendIn or 4.0, restoreAnim.blendOut or -4.0,
                    -1, restoreAnim.flags or 50, 0.0, false, false, false)
            end
        end)
    end
end

---@param ctx table
local function cleanupActors(ctx)
    for _, ped in ipairs(ctx.actors or {}) do
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, false)
            SetEntityAsMissionEntity(ped, false, true)
            SetPedAsNoLongerNeeded(ped)
        end
    end
    ctx.actors = {}
end

local function disableControlsThisFrame()
    HideHudAndRadarThisFrame()
    DisableAllControlActions(0)
    EnableControlAction(0, 73, true)
end

-- Synchronized scene helpers -------------------------------------------------

---@param def table
---@param ctx table
---@return boolean
local function startSyncScene(def, ctx)
    local scene = def.syncScene
    if type(scene) ~= 'table' then return false end

    local origin = scene.origin
    if type(origin) ~= 'vector3' then return false end

    local rot = scene.rot or vector3(0.0, 0.0, 0.0)
    local rotOrder = scene.rotOrder or 2

    local sceneId = CreateSynchronizedScene(
        origin.x, origin.y, origin.z,
        rot.x, rot.y, rot.z, rotOrder
    )
    if sceneId == -1 then return false end

    SetSynchronizedSceneLooped(sceneId, scene.looped == true)
    SetSynchronizedSceneHoldLastFrame(sceneId, scene.holdLastFrame == true)
    if type(scene.rate) == 'number' then
        SetSynchronizedSceneRate(sceneId, scene.rate)
    end
    if type(scene.phase) == 'number' then
        SetSynchronizedScenePhase(sceneId, scene.phase)
    end

    ctx.syncSceneId = sceneId
    ctx.syncScenePlayerAttached = false

    for i, actorDef in ipairs(def.actors or {}) do
        local syncAnim = actorDef.syncAnim
        local ped = ctx.actors and ctx.actors[i]
        if syncAnim and ped and ped ~= 0 and DoesEntityExist(ped) and SK.LoadAnimDict(syncAnim.dict) then
            TaskSynchronizedScene(
                ped, sceneId,
                syncAnim.dict, syncAnim.name,
                syncAnim.blendIn or 4.0,
                syncAnim.blendOut or -4.0,
                syncAnim.flags or 0,
                syncAnim.ragdollFlags or 0,
                syncAnim.moverBlend or 1148846080,
                syncAnim.ikFlags or 0
            )
            SetPedCanPlayAmbientAnims(ped, false)
        end
    end

    local attachPlayer = scene.attachPlayer
    if type(attachPlayer) == 'table' and SK.LoadAnimDict(attachPlayer.dict) then
        local player = PlayerPedId()
        TaskSynchronizedScene(
            player, sceneId,
            attachPlayer.dict, attachPlayer.name,
            attachPlayer.blendIn or 4.0,
            attachPlayer.blendOut or -4.0,
            attachPlayer.flags or 0,
            attachPlayer.ragdollFlags or 0,
            attachPlayer.moverBlend or 1148846080,
            attachPlayer.ikFlags or 0
        )
        ctx.syncScenePlayerAttached = true
    end

    return true
end

---@param ctx table
local function stopSyncScene(ctx)
    if type(ctx.syncSceneId) == 'number' and ctx.syncSceneId ~= -1 then
        if IsSynchronizedSceneRunning(ctx.syncSceneId) then
            DisposeSynchronizedScene(ctx.syncSceneId)
        else
            DisposeSynchronizedScene(ctx.syncSceneId)
        end
    end
    if ctx.syncScenePlayerAttached then
        local player = PlayerPedId()
        if DoesEntityExist(player) then
            ClearPedTasks(player)
        end
    end
    ctx.syncSceneId = nil
    ctx.syncScenePlayerAttached = false
end

---@param def table
---@param ctx table
local function runShotSequence(def, ctx)
    local shots = def.shots or {}
    local firstShot = shots[1]
    if not firstShot then return end

    local currentCam = createCameraFromShot(firstShot, def.lookAt)
    SetCamActive(currentCam, true)
    RenderScriptCams(true, false, 0, true, true)

    SendNUIMessage({ type = 'missions:cutsceneStart', title = def.title, subtitle = def.subtitle })

    DoScreenFadeIn(500)

    local subtitleQueue = def.subtitles or {}
    local subtitleIndex = 1
    local startTime = GetGameTimer()

    local function updateSubtitles(elapsedMs)
        while subtitleIndex <= #subtitleQueue and subtitleQueue[subtitleIndex].atMs <= elapsedMs do
            local line = subtitleQueue[subtitleIndex]
            showSubtitle(line)
            playSubtitleActorAnim(line, ctx)
            subtitleIndex = subtitleIndex + 1
        end
    end

    local dwell = firstShot.durationMs or 2500
    local tEnd = GetGameTimer() + dwell
    while GetGameTimer() < tEnd do
        disableControlsThisFrame()
        updateSubtitles(GetGameTimer() - startTime)
        if IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73) then
            break
        end
        Wait(0)
    end

    for i = 2, #shots do
        local nextShot = shots[i]
        local nextCam = createCameraFromShot(nextShot, def.lookAt)
        local interpMs = nextShot.interpMs or 2500
        SetCamActiveWithInterp(nextCam, currentCam, interpMs, true, true)

        local elapsed = 0
        while elapsed < interpMs do
            disableControlsThisFrame()
            updateSubtitles(GetGameTimer() - startTime)
            if IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73) then
                elapsed = interpMs
                break
            end
            Wait(0)
            elapsed = elapsed + GetFrameTime() * 1000
        end

        DestroyCam(currentCam, false)
        currentCam = nextCam

        local holdMs = nextShot.durationMs or 2000
        local tHoldEnd = GetGameTimer() + holdMs
        while GetGameTimer() < tHoldEnd do
            disableControlsThisFrame()
            updateSubtitles(GetGameTimer() - startTime)
            if IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73) then
                break
            end
            Wait(0)
        end
    end

    local trailingEnd = GetGameTimer() + 500
    while GetGameTimer() < trailingEnd do
        disableControlsThisFrame()
        updateSubtitles(GetGameTimer() - startTime)
        Wait(0)
    end

    SendNUIMessage({ type = 'missions:cutsceneEnd' })
    RenderScriptCams(false, true, 800, false, false)
    Wait(820)
    if DoesCamExist(currentCam) then DestroyCam(currentCam, false) end
end

-- Main entry ----------------------------------------------------------------

---@param id string
---@param extraCtx table|nil
---@return boolean
function SKCutscene.play(id, extraCtx)
    local def = SKCutscene.definitions[id]
    if not def then
        print(('[missions] missing cutscene definition "%s"'):format(id))
        return false
    end

    if active then return false end
    active = true

    local ctx = {}
    for k, v in pairs(extraCtx or {}) do ctx[k] = v end
    ctx.actors = ctx.actors or {}

    local shots = def.shots or {}
    local firstShot = shots[1]

    -- Subtitle-only mode (e.g. mid-mission text reveals): no screen fade,
    -- no camera takeover - just queue the lines.
    if not firstShot then
        local subtitleQueue = def.subtitles or {}
        local startTime = GetGameTimer()
        CreateThread(function()
            for _, line in ipairs(subtitleQueue) do
                local wait = math.max(0, (line.atMs or 0) - (GetGameTimer() - startTime))
                if wait > 0 then Wait(wait) end
                showSubtitle(line)
            end
        end)
        active = false
        return true
    end

    Cinematic = true

    DoScreenFadeOut(300)
    Wait(320)

    local useSyncScene = type(def.syncScene) == 'table'

    for _, actorDef in ipairs(def.actors or {}) do
        local ped = spawnActor(actorDef, useSyncScene)
        if ped ~= 0 then ctx.actors[#ctx.actors + 1] = ped end
    end

    if useSyncScene then
        startSyncScene(def, ctx)
    end

    runShotSequence(def, ctx)

    if useSyncScene then
        stopSyncScene(ctx)
    end
    cleanupActors(ctx)
    Cinematic = false
    active = false

    if def.onComplete then
        pcall(def.onComplete, ctx)
    end

    return true
end

---@param spec table  -- { title, subtitle, shots, lookAt, subtitles }
---@param ctx table|nil  -- { actors = { pedA, pedB, ... }, onDone = function }
---@return boolean
function SKCutscene.playLive(spec, ctx)
    if type(spec) ~= 'table' then return false end
    if active then return false end

    local shots = spec.shots or {}
    if not shots[1] then return false end

    active = true
    ctx = ctx or {}
    ctx.actors = ctx.actors or {}

    Cinematic = true

    DoScreenFadeOut(300)
    Wait(320)

    runShotSequence(spec, ctx)

    Cinematic = false
    active = false

    if type(ctx.onDone) == 'function' then
        pcall(ctx.onDone)
    end

    return true
end