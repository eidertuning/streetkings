-- "Prove Yourself" — tutorial mission - a homage to PS1 Driver

local MPS_TO_MPH      = 2.236936
local CONE_MODEL      = `prop_roadcone02a`

local tutorialVehicle = 0
local coneProps       = {}
local attemptCount    = 0
local running         = false
local resultPending   = false

local controllerTracker = SKControllerFriendly.newTracker()
local controllerMode    = false

local MANEUVER_KEYS   = {
    'burnout', 'handbrake', 'slalom', 'turn180',
    'turn360', 'reverse180', 'speed', 'braketest',
    'drift', 'checkpoints',
}

local MANEUVER_LABELS = {
    burnout     = 'BURNOUT',
    handbrake   = 'HANDBRAKE',
    slalom      = 'SLALOM AROUND CONES',
    turn180     = '180 TURN',
    turn360     = '360 TURN',
    reverse180  = 'REVERSE 180',
    speed       = 'SPEED',
    braketest   = 'BRAKE TEST',
    drift       = 'DRIFT',
    checkpoints = 'CHECKPOINTS',
}

local completed       = {}
local burnoutStart    = 0
local yawAccum        = 0.0
local yawStart        = 0
local prevYaw         = nil
local yaw360Accum     = 0.0
local yaw360Start     = 0
local yaw360PrevYaw   = nil
local brakePhaseStart = 0
local brakeArmed      = false
local rev180Reversing = false
local rev180Yaw       = 0.0
local rev180PrevYaw   = nil
local slalomNext      = 1
local slalomLastSide  = nil
local cpHit           = {}
local cpFlashUntil    = {}
local driftStart      = 0

local function normalizeAngle(a)
    a = a % 360.0
    if a > 180.0 then a = a - 360.0 end
    if a < -180.0 then a = a + 360.0 end
    return a
end

local function resetManeuverState()
    completed = {}
    for _, k in ipairs(MANEUVER_KEYS) do completed[k] = false end
    burnoutStart    = 0
    yawAccum        = 0.0
    yawStart        = 0
    prevYaw         = nil
    yaw360Accum     = 0.0
    yaw360Start     = 0
    yaw360PrevYaw   = nil
    brakePhaseStart = 0
    brakeArmed      = false
    rev180Reversing = false
    rev180Yaw       = 0.0
    rev180PrevYaw   = nil
    slalomNext      = 1
    slalomLastSide  = nil
    cpHit           = {}
    cpFlashUntil    = {}
    driftStart      = 0
end

local function completedCount()
    local n = 0
    for _, v in pairs(completed) do if v then n = n + 1 end end
    return n
end

local function markComplete(key)
    if completed[key] then return end
    completed[key] = true
    SendNUIMessage({ type = 'tutorial:complete', key = key, count = completedCount(), total = #MANEUVER_KEYS })
end

local function spawnCones()
    SK.LoadModel(CONE_MODEL)
    for _, pos in ipairs(TutorialConfig.SLALOM_CONES) do
        local obj = CreateObject(CONE_MODEL, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(obj, pos.w)
        FreezeEntityPosition(obj, true)
        coneProps[#coneProps + 1] = obj
    end
    SK.UnloadModel(CONE_MODEL)
    for _, obj in ipairs(coneProps) do
        while not HasCollisionLoadedAroundEntity(obj) do Wait(0) end
        PlaceObjectOnGroundProperly(obj)
    end
end

local function cleanupCones()
    for _, obj in ipairs(coneProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    coneProps = {}
end

local function applyTutorialVehicleColors(veh, colors)
    if type(colors) ~= 'table' then return end
    local p, s = colors.primary, colors.secondary
    if type(p) ~= 'table' or type(s) ~= 'table' then return end
    if type(p.r) ~= 'number' or type(p.g) ~= 'number' or type(p.b) ~= 'number' then return end
    if type(s.r) ~= 'number' or type(s.g) ~= 'number' or type(s.b) ~= 'number' then return end
    SetVehicleModKit(veh, 0)
    SetVehicleCustomPrimaryColour(veh, math.floor(p.r), math.floor(p.g), math.floor(p.b))
    SetVehicleCustomSecondaryColour(veh, math.floor(s.r), math.floor(s.g), math.floor(s.b))
end

local function spawnTutorialVehicle()
    local spawnInfo = lib.callback.await('streetkings:tutorial:getVehicleModel', false)
    if type(spawnInfo) ~= 'table' or not spawnInfo.modelName then return 0 end
    local modelName = spawnInfo.modelName

    local hash = SK.LoadModel(modelName)
    if not hash then return 0 end

    local sp = TutorialConfig.VEHICLE_SPAWN
    local veh = CreateVehicle(hash, sp.x, sp.y, sp.z, sp.w, false, false)
    SetEntityAsMissionEntity(veh, true, true)
    SK.UnloadModel(hash)

    SetEntityInvincible(veh, true)
    SetVehicleCanBeVisiblyDamaged(veh, false)
    applyTutorialVehicleColors(veh, spawnInfo.colors)

    local ped = PlayerPedId()
    for attempt = 1, 3 do
        TaskWarpPedIntoVehicle(ped, veh, -1)
        local deadline = GetGameTimer() + 2000
        while not IsPedInVehicle(ped, veh, false) do
            if GetGameTimer() > deadline then break end
            Wait(50)
        end
        if IsPedInVehicle(ped, veh, false) then break end
    end
    Wait(1000)
    FreezeEntityPosition(veh, true)
    return veh
end

local function cleanupVehicle()
    if tutorialVehicle ~= 0 and DoesEntityExist(tutorialVehicle) then
        DeleteEntity(tutorialVehicle)
    end
    tutorialVehicle = 0
end

local function drawCheckpointMarkers()
    if not running then return end
    local checkpoints = TutorialConfig.CHECKPOINTS
    if not checkpoints then return end
    local now = GetGameTimer()

    for i, cp in ipairs(checkpoints) do
        local hit = cpHit[i]
        local r, g, b, a = 255, 209, 71, 100
        local scale = 3.0

        if hit then
            r, g, b = 74, 222, 128
            local flashEnd = cpFlashUntil[i] or 0
            if now < flashEnd then
                local t = (flashEnd - now) / 400
                a = math.floor(100 + 155 * t)
                scale = 3.0 + 1.5 * t
            end
        end

        DrawMarker(
            1, cp.x, cp.y, cp.z - 1.0,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            scale, scale, 4.0,
            r, g, b, a,
            false, false, 2, false, nil, nil, false
        )
    end
end

local function detectManeuvers(veh)
    local cfg    = TutorialConfig
    local now    = GetGameTimer()
    local speed  = GetEntitySpeed(veh) * MPS_TO_MPH
    local rot    = GetEntityRotation(veh, 2)
    local pos    = GetEntityCoords(veh)
    local curYaw = rot.z

    if not completed.burnout then
        if IsVehicleInBurnout(veh) then
            if burnoutStart == 0 then burnoutStart = now end
            if (now - burnoutStart) >= cfg.BURNOUT_DURATION_MS then
                markComplete('burnout')
            end
        else
            burnoutStart = 0
        end
    end

    if not completed.handbrake then
        if IsControlPressed(0, 76) and speed > cfg.MIN_HANDBRAKE_SPEED_MPH then
            markComplete('handbrake')
        end
    end

    if not completed.speed then
        if speed >= cfg.SPEED_TARGET_MPH then
            markComplete('speed')
        end
    end

    if not completed.braketest then
        if speed >= cfg.BRAKE_HIGH_SPEED_MPH then
            brakeArmed = true
            brakePhaseStart = now
        end
        if brakeArmed and speed < cfg.BRAKE_STOP_SPEED_MPH then
            if (now - brakePhaseStart) <= cfg.BRAKE_TIME_WINDOW_MS then
                markComplete('braketest')
            end
            brakeArmed = false
        end
    end

    if prevYaw then
        local delta = normalizeAngle(curYaw - prevYaw)

        if speed >= cfg.TURN_MIN_SPEED_MPH then
            if yawStart == 0 then yawStart = now end
            yawAccum      = yawAccum + delta
            local absYaw  = math.abs(yawAccum)
            local elapsed = now - yawStart

            if not completed.turn180 and absYaw >= cfg.TURN_180_MIN_DEG and absYaw <= cfg.TURN_180_MAX_DEG and elapsed <= cfg.TURN_WINDOW_MS then
                markComplete('turn180')
            end

            if elapsed > cfg.TURN_WINDOW_MS then
                yawAccum = 0.0
                yawStart = now
            end
        else
            yawAccum = 0.0
            yawStart = 0
        end
    end
    prevYaw = curYaw

    if not completed.turn360 then
        if yaw360PrevYaw then
            local delta360 = normalizeAngle(curYaw - yaw360PrevYaw)
            local speed360Min = cfg.TURN_360_MIN_SPEED_MPH or 3

            if speed >= speed360Min then
                if yaw360Start == 0 then yaw360Start = now end
                yaw360Accum   = yaw360Accum + delta360
                local abs360  = math.abs(yaw360Accum)
                local elapsed = now - yaw360Start
                local window  = cfg.TURN_360_WINDOW_MS or 6000

                if abs360 >= cfg.TURN_360_MIN_DEG and elapsed <= window then
                    markComplete('turn360')
                end

                if elapsed > window then
                    yaw360Accum = 0.0
                    yaw360Start = now
                end
            else
                yaw360Accum = 0.0
                yaw360Start = 0
            end
        end
        yaw360PrevYaw = curYaw
    end

    if not completed.reverse180 then
        local speedVec = GetEntitySpeedVector(veh, true)
        local goingReverse = speedVec.y < -(cfg.REVERSE_MIN_SPEED_MPH / MPS_TO_MPH)

        if goingReverse and not rev180Reversing then
            rev180Reversing = true
            rev180Yaw = 0.0
            rev180PrevYaw = curYaw
        end

        if rev180Reversing then
            if rev180PrevYaw then
                rev180Yaw = rev180Yaw + normalizeAngle(curYaw - rev180PrevYaw)
            end
            rev180PrevYaw = curYaw

            local goingForward = speedVec.y > (cfg.TURN_MIN_SPEED_MPH / MPS_TO_MPH)
            if goingForward and math.abs(rev180Yaw) >= cfg.TURN_180_MIN_DEG then
                markComplete('reverse180')
            end

            if speed < 1 then
                rev180Reversing = false
                rev180Yaw = 0.0
                rev180PrevYaw = nil
            end
        end
    end

    if not completed.drift then
        local speedVec = GetEntitySpeedVector(veh, true)
        local lateralAbs = math.abs(speedVec.x)
        local forwardSpd = speedVec.y

        if lateralAbs >= cfg.DRIFT_MIN_LATERAL_MPS and forwardSpd >= cfg.DRIFT_MIN_FORWARD_MPS then
            if driftStart == 0 then driftStart = now end
            if (now - driftStart) >= cfg.DRIFT_DURATION_MS then
                markComplete('drift')
            end
        else
            driftStart = 0
        end
    end

    if not completed.slalom then
        local cones = cfg.SLALOM_CONES
        if slalomNext <= #cones then
            local cone = cones[slalomNext]
            local axis = cfg.SLALOM_AXIS
            local crossed = false

            if axis == 'y' then
                if slalomNext == 1 then
                    crossed = pos.y >= cone.y - 4.0 and pos.y <= cone.y + 4.0
                else
                    local prevCone = cones[slalomNext - 1]
                    local dir = cone.y > prevCone.y and 1 or -1
                    crossed = (dir > 0 and pos.y >= cone.y) or (dir < 0 and pos.y <= cone.y)
                end
            else
                if slalomNext == 1 then
                    crossed = pos.x >= cone.x - 4.0 and pos.x <= cone.x + 4.0
                else
                    local prevCone = cones[slalomNext - 1]
                    local dir = cone.x > prevCone.x and 1 or -1
                    crossed = (dir > 0 and pos.x >= cone.x) or (dir < 0 and pos.x <= cone.x)
                end
            end

            if crossed then
                local side
                if axis == 'y' then
                    side = pos.x > cone.x and 'right' or 'left'
                else
                    side = pos.y > cone.y and 'right' or 'left'
                end

                if not (slalomLastSide and side == slalomLastSide) then
                    slalomLastSide = side
                    slalomNext = slalomNext + 1
                    if slalomNext > #cones then
                        markComplete('slalom')
                    end
                end
            end
        end
    end

    if not completed.checkpoints then
        local checkpoints = cfg.CHECKPOINTS
        local radius = cfg.CHECKPOINT_RADIUS
        for i, cp in ipairs(checkpoints) do
            if not cpHit[i] and #(pos - cp) < radius then
                cpHit[i] = true
                cpFlashUntil[i] = now + 400
            end
        end
        local allHit = true
        for i = 1, #checkpoints do
            if not cpHit[i] then
                allHit = false
                break
            end
        end
        if allHit then markComplete('checkpoints') end
    end
end

local function playCountdown()
    for i = 3, 1, -1 do
        SendNUIMessage({ type = 'tutorial:countdown', value = tostring(i) })
        PlaySoundFrontend(-1, 'CHECKPOINT_UNDER_THE_BRIDGE', 'HUD_MINI_GAME_SOUNDSET', true)
        Wait(1000)
    end
    SendNUIMessage({ type = 'tutorial:countdown', value = 'GO!' })
    PlaySoundFrontend(-1, 'CHECKPOINT_AHEAD', 'HUD_MINI_GAME_SOUNDSET', true)
    Wait(600)
    SendNUIMessage({ type = 'tutorial:countdown', value = nil })
end

local function playIntro()
    local cfg = TutorialConfig
    Cinematic = true
    DoScreenFadeOut(0)
    SKAvatar.applyActiveAppearance()
    local sp = cfg.VEHICLE_SPAWN
    SetEntityCoords(PlayerPedId(), sp.x, sp.y, sp.z, false, false, false, false)
    RequestCollisionAtCoord(sp.x, sp.y, sp.z)
    local collisionDeadline = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) do
        if GetGameTimer() > collisionDeadline then break end
        Wait(100)
    end
    spawnCones()
    tutorialVehicle = spawnTutorialVehicle()
    local camFrom = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camFrom, cfg.CAM_START.x, cfg.CAM_START.y, cfg.CAM_START.z)
    PointCamAtCoord(camFrom, cfg.CAM_LOOKAT.x, cfg.CAM_LOOKAT.y, cfg.CAM_LOOKAT.z)
    SetCamFov(camFrom, 55.0)
    SetCamActive(camFrom, true)
    RenderScriptCams(true, false, 0, true, true)
    DoScreenFadeIn(800)
    while not IsScreenFadedIn() do Wait(0) end
    SendNUIMessage({
        type    = 'missions:subtitle',
        speaker = 'Hector',
        body    = cfg.HECTOR_INTRO,
        duration = 6500,
    })
    local camTo = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camTo, cfg.CAM_END.x, cfg.CAM_END.y, cfg.CAM_END.z)
    PointCamAtCoord(camTo, cfg.CAM_LOOKAT.x, cfg.CAM_LOOKAT.y, cfg.CAM_LOOKAT.z)
    SetCamFov(camTo, 45.0)
    local interpMs = 4000
    SetCamActiveWithInterp(camTo, camFrom, interpMs, true, true)
    local elapsed = 0
    while elapsed < interpMs do
        HideHudAndRadarThisFrame()
        Wait(0)
        elapsed = elapsed + GetFrameTime() * 1000
    end
    Wait(500)
    RenderScriptCams(false, true, 1500, false, false)
    Wait(1500)
    DestroyCam(camFrom, false)
    DestroyCam(camTo, false)

    if tutorialVehicle ~= 0 and DoesEntityExist(tutorialVehicle) then
        FreezeEntityPosition(tutorialVehicle, false)
    end
    Cinematic = false
    SKCamera.delayEnable(tutorialVehicle, 200)
end

local function handleChoice(choice)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'tutorial:hide' })
    resultPending = false
    controllerMode = false

    CreateThread(function()
        DoScreenFadeOut(500)
        Wait(500)

        if choice == 'continue' then
            SetTimeScale(1.0)
            SKCamera.disable()
            cleanupCones()
            cleanupVehicle()
            SKGarage.enterFromMenu()
        elseif choice == 'skip' then
            lib.callback.await('streetkings:tutorial:skip', false)
            SKCamera.disable()
            cleanupCones()
            cleanupVehicle()
            SKGarage.enterFromMenu()
        else
            SKCamera.disable()
            if tutorialVehicle ~= 0 and DoesEntityExist(tutorialVehicle) then
                local sp = TutorialConfig.VEHICLE_SPAWN
                SetEntityCoords(tutorialVehicle, sp.x, sp.y, sp.z, false, false, false, true)
                SetEntityHeading(tutorialVehicle, sp.w)
                SetVehicleFixed(tutorialVehicle)
                FreezeEntityPosition(tutorialVehicle, true)
            end
            DoScreenFadeIn(500)
            Wait(500)
            SKCamera.delayEnable(tutorialVehicle, 200)
            startAttempt()
        end
    end)
end

RegisterNUICallback('tutorial:choice', function(data, cb)
    cb('ok')
    if not resultPending then return end
    local choice = data and data.choice or 'retry'
    handleChoice(choice)
end)

local function showResults(success)
    running = false
    resultPending = true
    DoScreenFadeOut(500)
    Wait(600)
    if success then
        SetTimeScale(0.3)
        Wait(800)
        SetTimeScale(1.0)

        local result = lib.callback.await('streetkings:tutorial:complete', false)

        SendNUIMessage({
            type    = 'tutorial:end',
            success = true,
            reward  = result and result.reward or nil,
        })

        if result and result.summary then
            SKNotify({ title = 'Tutorial Completed!', type = 'success', duration = 4000 })
        end
    else
        attemptCount = attemptCount + 1
        SendNUIMessage({
            type    = 'tutorial:fail',
            canSkip = true,
        })
    end

    SetNuiFocus(true, true)
end

function startAttempt()
    resetManeuverState()
    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
        Wait(600)
    end

    if tutorialVehicle ~= 0 and DoesEntityExist(tutorialVehicle) then
        FreezeEntityPosition(tutorialVehicle, false)
    end

    local maneuvers = {}
    for _, k in ipairs(MANEUVER_KEYS) do
        maneuvers[#maneuvers + 1] = { key = k, label = MANEUVER_LABELS[k] }
    end

    SendNUIMessage({
        type      = 'tutorial:show',
        timer     = TutorialConfig.TIMER_SECONDS,
        maneuvers = maneuvers,
    })

    if tutorialVehicle ~= 0 and DoesEntityExist(tutorialVehicle) then
        FreezeEntityPosition(tutorialVehicle, true)
    end

    playCountdown()

    if tutorialVehicle ~= 0 and DoesEntityExist(tutorialVehicle) then
        FreezeEntityPosition(tutorialVehicle, false)
    end

    running = true
    local endTime = GetGameTimer() + TutorialConfig.TIMER_SECONDS * 1000

    CreateThread(function()
        while running and SKC.GetGameState() == GameState.TUTORIAL do
            local now = GetGameTimer()
            local remaining = math.max(0, endTime - now)

            if tutorialVehicle ~= 0 and DoesEntityExist(tutorialVehicle) then
                detectManeuvers(tutorialVehicle)
            end

            SendNUIMessage({
                type      = 'tutorial:tick',
                remaining = remaining,
                count     = completedCount(),
                total     = #MANEUVER_KEYS,
            })

            if completedCount() >= #MANEUVER_KEYS then
                showResults(true)
                return
            end

            if remaining <= 0 then
                showResults(false)
                return
            end

            Wait(0)
        end
    end)
end

-- GameState registration

SKC.RegisterGameState(GameState.TUTORIAL, {
    onEnter = function()
        CreateThread(function()
            playIntro()
            startAttempt()
        end)
    end,

    onExit = function()
        running = false
        resultPending = false
        controllerMode = false
        Cinematic = false
        SetTimeScale(1.0)
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'tutorial:hide' })
        SKCamera.disable()
        cleanupCones()
        cleanupVehicle()
    end,

    onTick = function()
        HideHudAndRadarThisFrame()
        DisplayRadar(false)
        drawCheckpointMarkers()

        if resultPending then
            DisableAllControlActions(0)
            local state = SKControllerFriendly.poll(controllerTracker)
            local wasControllerMode = controllerMode
            controllerMode = state.controllerEnabled

            if controllerMode ~= wasControllerMode then
                SendNUIMessage({ type = 'tutorial:controllerMode', enabled = controllerMode })
            end

            if controllerMode then
                for _, action in ipairs(state.pressedActions) do
                    SendNUIMessage({ type = 'tutorial:controllerInput', action = action })
                end
            end
        end
    end,

    tickWait = 0,
})