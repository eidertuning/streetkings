SKTailing = {}

local session = nil

local DEFAULT_SAFE   = { minDistance = 15.0, maxDistance = 55.0 }
local DEFAULT_DANGER = { tooCloseDistance = 10.0, tooFarDistance = 80.0 }
local DEFAULT_DETECT = { lostSeconds = 8.0 }
local VISION_CONE_ANGLE_DEG = 45.0
local VISION_CONE_RANGE     = 30.0
local ARRIVAL_DISTANCE      = 15.0
local RAM_PROXIMITY      = 5.0
local RAM_SPEED_DROP     = 8.0

local SUSPICION_MAX         = 100
local SUSPICION_RATE_DANGER = 1.0
local SUSPICION_RATE_WARN   = 0.4
local SUSPICION_RATE_CONE   = 0.6
local SUSPICION_DECAY       = 0.3

local function releaseEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if IsEntityAPed(ent) then
        SetPedAsNoLongerNeeded(ent)
    else
        SetEntityAsNoLongerNeeded(ent)
    end
end

local function cleanupSession(release)
    if not session then return end
    if session.targetPed and session.targetPed ~= 0 and DoesEntityExist(session.targetPed) then
        SetBlockingOfNonTemporaryEvents(session.targetPed, false)
        TaskSmartFleePed(session.targetPed, PlayerPedId(), 200.0, -1, false, false)
    end
    releaseEntity(session.targetPed)
    releaseEntity(session.targetVehicle)
    releaseEntity(session.meetingCop)
    if session.blip and DoesBlipExist(session.blip) then RemoveBlip(session.blip) end
    SendNUIMessage({ type = 'missions:tailHide' })
    session = nil
end

local function playerInVisionCone(targetPed, targetVehicle, playerCoords)
    if not DoesEntityExist(targetPed) then return false end
    local tCoords  = GetEntityCoords(targetPed)
    local fwdEntity = (targetVehicle and DoesEntityExist(targetVehicle) and IsPedInAnyVehicle(targetPed, false))
        and targetVehicle or targetPed
    local tForward = GetEntityForwardVector(fwdEntity)
    local toPlayer = vector3(playerCoords.x - tCoords.x, playerCoords.y - tCoords.y, 0.0)
    local dist = math.sqrt(toPlayer.x * toPlayer.x + toPlayer.y * toPlayer.y)
    if dist < 1.0 or dist > VISION_CONE_RANGE then return false end
    local norm = vector3(toPlayer.x / dist, toPlayer.y / dist, 0.0)
    local dot = norm.x * tForward.x + norm.y * tForward.y
    return math.deg(math.acos(math.min(1.0, math.max(-1.0, dot)))) <= VISION_CONE_ANGLE_DEG
end

function SKTailing.beginFromSession(ped, vehicle, obj, callbacks)
    SKTailing.stop()

    local meeting = obj.meeting or {}
    local safe    = obj.safeZone   or DEFAULT_SAFE
    local danger  = obj.dangerZone or DEFAULT_DANGER
    local detect  = obj.detection  or DEFAULT_DETECT
    local meetCoords = meeting.coords

    if type(meetCoords) ~= 'vector3' then
        callbacks.onFail('no_meeting_coords')
        return
    end

    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, 225)
    SetBlipColour(blip, 46)
    SetBlipScale(blip, 0.5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Target')
    EndTextCommandSetBlipName(blip)

    session = {
        targetPed        = ped,
        targetVehicle    = vehicle,
        blip             = blip,
        meeting          = meeting,
        safe             = safe,
        danger           = danger,
        detect           = detect,
        onSuccess        = callbacks.onSuccess,
        onFail           = callbacks.onFail,
        suspicion        = 0,
        lostElapsed      = 0,
        stopped          = false,
        stuckTicks       = 0,
        lastTargetSpeed  = 0,
    }

    SendNUIMessage({ type = 'missions:tailShow' })

    local initDist = math.floor(#(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle)))
    SendNUIMessage({
        type          = 'missions:tailUpdate',
        distance      = initDist,
        zone          = 'safe',
        spotted       = false,
        suspicionPct  = 0,
        lostPct       = 0,
    })

    CreateThread(function()
        local s = session
        if not s then return end

        local arrivalTimeout = GetGameTimer() + 600000
        while not s.stopped do
            if GetGameTimer() > arrivalTimeout then
                SKTailing.stop()
                if s.onFail then pcall(s.onFail, 'timeout') end
                return
            end

            if not DoesEntityExist(s.targetVehicle) then
                SKTailing.stop()
                if s.onFail then pcall(s.onFail, 'target_lost') end
                return
            end

            local gabeCoords = GetEntityCoords(s.targetVehicle)
            if #(gabeCoords - meetCoords) < ARRIVAL_DISTANCE then
                s.stopped = true
                SendNUIMessage({ type = 'missions:tailHide' })

                SetVehicleForwardSpeed(s.targetVehicle, 0.0)
                TaskVehicleTempAction(s.targetPed, s.targetVehicle, 27, 3000)
                Wait(1500)

                local cop = nil
                if type(meeting.copPedModel) == 'string' then
                    local copHash = SK.LoadModel(meeting.copPedModel)
                    if copHash then
                        local groundZ = meetCoords.z
                        local _, gz = GetGroundZFor_3dCoord(meetCoords.x, meetCoords.y, meetCoords.z + 2.0, false)
                        if gz and gz > 0 then groundZ = gz end
                        cop = CreatePed(4, copHash, meetCoords.x + 2.5, meetCoords.y + 1.0, groundZ, 0.0, true, false)
                        SetEntityAsMissionEntity(cop, true, true)
                        SetPedDefaultComponentVariation(cop)
                        SetBlockingOfNonTemporaryEvents(cop, true)
                        SetEntityInvincible(cop, true)
                        PlaceObjectOnGroundProperly(cop)
                        s.meetingCop = cop
                    end
                end

                TaskLeaveVehicle(s.targetPed, s.targetVehicle, 0)
                local exitEnd = GetGameTimer() + 5000
                while GetGameTimer() < exitEnd do
                    if not DoesEntityExist(s.targetPed) then break end
                    if not IsPedInVehicle(s.targetPed, s.targetVehicle, false) then break end
                    Wait(100)
                end
                Wait(300)

                if cop and DoesEntityExist(cop) and DoesEntityExist(s.targetPed) then
                    TaskTurnPedToFaceEntity(cop, s.targetPed, 2000)
                    Wait(500)
                    local copPos = GetEntityCoords(cop)
                    TaskGoStraightToCoord(s.targetPed, copPos.x, copPos.y, copPos.z, 1.0, 8000, GetEntityHeading(cop) + 180.0, 0.5)
                    local walkEnd = GetGameTimer() + 8000
                    while GetGameTimer() < walkEnd do
                        if not DoesEntityExist(s.targetPed) then break end
                        if #(GetEntityCoords(s.targetPed) - copPos) < 1.8 then break end
                        Wait(100)
                    end
                    Wait(200)
                    TaskTurnPedToFaceEntity(s.targetPed, cop, 1000)
                    Wait(1000)
                end

                local gabeEnt = s.targetPed
                local copEnt = cop
                if DoesEntityExist(gabeEnt) and copEnt and DoesEntityExist(copEnt) then
                    local subtitles = {
                        { atMs = 400,   speaker = 'You',    body = "That's not a buyer. That's a badge.",                              duration = 3000, talker = nil },
                        { atMs = 3800,  speaker = 'Gabe',   body = "It's all set for Friday. Saint's using a new driver - kid's got no record.", duration = 3500, talker = 'gabe' },
                        { atMs = 7600,  speaker = 'Vargas', body = "Good. I want the whole crew at the yard. Every last one of them.",         duration = 3200, talker = 'cop' },
                        { atMs = 11000, speaker = 'Gabe',   body = "Just keep my name out of the paperwork.",                         duration = 3000, talker = 'gabe' },
                    }
                    local shots = {
                        { entity = copEnt,  offset = vector3(1.5, 2.5, 1.2),  fov = 50.0, durationMs = 3500 },
                        { entity = gabeEnt, offset = vector3(-1.5, 2.2, 1.0), fov = 45.0, durationMs = 4500 },
                        { entity = copEnt,  offset = vector3(0.8, -2.5, 1.0), fov = 48.0, durationMs = 6000 },
                    }

                    SK.LoadAnimDict('mp_facial')
                    SK.LoadAnimDict('mp_common')

                    local function setTalker(who)
                        if not DoesEntityExist(gabeEnt) or not DoesEntityExist(copEnt) then return end
                        if who == 'gabe' then
                            PlayFacialAnim(gabeEnt, 'mic_chatter', 'mp_facial')
                            PlayFacialAnim(copEnt, 'mood_normal_1', 'facials@gen_male@variations@normal')
                        elseif who == 'cop' then
                            PlayFacialAnim(copEnt, 'mic_chatter', 'mp_facial')
                            PlayFacialAnim(gabeEnt, 'mood_normal_1', 'facials@gen_male@variations@normal')
                        else
                            PlayFacialAnim(gabeEnt, 'mood_normal_1', 'facials@gen_male@variations@normal')
                            PlayFacialAnim(copEnt, 'mood_normal_1', 'facials@gen_male@variations@normal')
                        end
                    end

                    Cinematic = true
                    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                    SetCamActive(cam, true)
                    RenderScriptCams(true, true, 800, true, true)

                    local cutsceneStart = GetGameTimer()
                    CreateThread(function()
                        for _, sub in ipairs(subtitles) do
                            local waitTime = sub.atMs - (GetGameTimer() - cutsceneStart)
                            if waitTime > 0 then Wait(waitTime) end
                            setTalker(sub.talker)
                            SendNUIMessage({ type = 'missions:subtitle', speaker = sub.speaker, body = sub.body, duration = sub.duration })
                        end
                        Wait(3200)
                        setTalker(nil)
                    end)

                    -- Givetake during shot 1
                    TaskPlayAnim(gabeEnt, 'mp_common', 'givetake1_b', 2.0, -2.0, 3000, 0, 0, false, false, false)
                    TaskPlayAnim(copEnt, 'mp_common', 'givetake1_a', 2.0, -2.0, 3000, 0, 0, false, false, false)

                    for i, shot in ipairs(shots) do
                        local entCoords = GetEntityCoords(shot.entity)
                        SetCamCoord(cam, entCoords.x + shot.offset.x, entCoords.y + shot.offset.y, entCoords.z + shot.offset.z)
                        PointCamAtEntity(cam, shot.entity, 0.0, 0.0, 0.0, true)
                        SetCamFov(cam, shot.fov)
                        local shotEnd = GetGameTimer() + shot.durationMs
                        while GetGameTimer() < shotEnd do
                            HideHudAndRadarThisFrame()
                            Wait(0)
                        end
                        if i == 1 then
                            if DoesEntityExist(gabeEnt) then StopAnimTask(gabeEnt, 'mp_common', 'givetake1_b', -2.0) end
                            if DoesEntityExist(copEnt) then StopAnimTask(copEnt, 'mp_common', 'givetake1_a', -2.0) end
                        end
                    end

                    RenderScriptCams(false, true, 800, false, false)
                    Cinematic = false
                    Wait(800)
                    if DoesCamExist(cam) then DestroyCam(cam, false) end

                    if DoesEntityExist(gabeEnt) then
                        PlayFacialAnim(gabeEnt, 'mood_normal_1', 'facials@gen_male@variations@normal')
                    end
                    if DoesEntityExist(copEnt) then
                        PlayFacialAnim(copEnt, 'mood_normal_1', 'facials@gen_male@variations@normal')
                    end
                    RemoveAnimDict('mp_facial')
                    RemoveAnimDict('mp_common')
                end

                if DoesEntityExist(s.targetPed) then
                    ClearPedTasks(s.targetPed)
                end
                if cop and DoesEntityExist(cop) then
                    ClearPedTasks(cop)
                end

                local gabePed = s.targetPed
                local gabeVeh = s.targetVehicle
                if DoesEntityExist(gabePed) and DoesEntityExist(gabeVeh) then
                    TaskEnterVehicle(gabePed, gabeVeh, 10000, -1, 2.0, 1, 0)
                    local enterEnd = GetGameTimer() + 10000
                    while GetGameTimer() < enterEnd do
                        if not DoesEntityExist(gabePed) then break end
                        if GetVehiclePedIsIn(gabePed, false) == gabeVeh then break end
                        Wait(100)
                    end
                    if DoesEntityExist(gabePed) and GetVehiclePedIsIn(gabePed, false) ~= gabeVeh then
                        SetPedIntoVehicle(gabePed, gabeVeh, -1)
                    end
                    SetVehicleEngineOn(gabeVeh, true, false, false)
                    TaskVehicleDriveWander(gabePed, gabeVeh, 20.0, 786603)
                    SetBlockingOfNonTemporaryEvents(gabePed, false)
                end

                if cop and DoesEntityExist(cop) then
                    SetBlockingOfNonTemporaryEvents(cop, false)
                    ClearPedTasks(cop)
                end

                local delCop = cop
                local delPed = gabePed
                local delVeh = gabeVeh
                CreateThread(function()
                    Wait(30000)
                    if delCop and DoesEntityExist(delCop) then
                        SetEntityAsMissionEntity(delCop, true, true)
                        DeleteEntity(delCop)
                    end
                    if delPed and DoesEntityExist(delPed) then
                        SetEntityAsMissionEntity(delPed, true, true)
                        DeleteEntity(delPed)
                    end
                    if delVeh and DoesEntityExist(delVeh) then
                        SetEntityAsMissionEntity(delVeh, true, true)
                        DeleteEntity(delVeh)
                    end
                end)

                s.meetingCop = nil
                s.targetPed = 0
                s.targetVehicle = 0
                local success = s.onSuccess
                SKTailing.stop()
                if success then pcall(success) end
                return
            end

            if GetEntitySpeed(s.targetVehicle) < 0.5 then
                s.stuckTicks = s.stuckTicks + 1
                if s.stuckTicks >= 20 then
                    s.stuckTicks = 0
                    TaskVehicleDriveToCoordLongrange(
                        s.targetPed, s.targetVehicle,
                        meetCoords.x, meetCoords.y, meetCoords.z,
                        meeting.driveSpeed or 14.0, 786603, 4.0
                    )
                end
            else
                s.stuckTicks = 0
            end

            Wait(500)
        end
    end)

    CreateThread(function()
        local s = session
        Wait(3000)
        while not s.stopped and session == s do
            if not DoesEntityExist(s.targetVehicle) then
                SKTailing.stop()
                if s.onFail then pcall(s.onFail, 'target_lost') end
                return
            end

            local playerCoords = GetEntityCoords(PlayerPedId())
            local targetCoords = GetEntityCoords(s.targetVehicle)
            local dist = #(playerCoords - targetCoords)

            local curTargetSpeed = GetEntitySpeed(s.targetVehicle)
            if dist < RAM_PROXIMITY and s.lastTargetSpeed > RAM_SPEED_DROP
                and curTargetSpeed < s.lastTargetSpeed * 0.4
            then
                SKTailing.stop(true)
                if s.onFail then pcall(s.onFail, 'spooked') end
                return
            end
            s.lastTargetSpeed = curTargetSpeed

            local zone = 'safe'
            if dist < (s.danger.tooCloseDistance or DEFAULT_DANGER.tooCloseDistance) then
                zone = 'tooClose'
            elseif dist < (s.safe.minDistance or DEFAULT_SAFE.minDistance) then
                zone = 'warnClose'
            elseif dist > (s.danger.tooFarDistance or DEFAULT_DANGER.tooFarDistance) then
                zone = 'tooFar'
            elseif dist > (s.safe.maxDistance or DEFAULT_SAFE.maxDistance) then
                zone = 'warnFar'
            end
            local cone = playerInVisionCone(s.targetPed, s.targetVehicle, playerCoords)

            local gain = 0
            if zone == 'tooClose' then gain = gain + SUSPICION_RATE_DANGER end
            if zone == 'warnClose' then gain = gain + SUSPICION_RATE_WARN end
            if cone then gain = gain + SUSPICION_RATE_CONE end
            if gain > 0 then
                s.suspicion = math.min(SUSPICION_MAX, s.suspicion + gain)
            else
                s.suspicion = math.max(0, s.suspicion - SUSPICION_DECAY)
            end

            local dt = 0.1
            if zone == 'tooFar' then
                s.lostElapsed = s.lostElapsed + dt
            else
                s.lostElapsed = math.max(0, s.lostElapsed - dt * 0.5)
            end
            SendNUIMessage({
                type          = 'missions:tailUpdate',
                distance      = math.floor(dist),
                zone          = zone,
                spotted       = cone,
                suspicionPct  = s.suspicion / SUSPICION_MAX,
                lostPct       = math.min(1.0, s.lostElapsed / (s.detect.lostSeconds or DEFAULT_DETECT.lostSeconds)),
            })
            if s.suspicion >= SUSPICION_MAX then
                SKTailing.stop(true)
                if s.onFail then pcall(s.onFail, 'spotted') end
                return
            end
            if s.lostElapsed >= (s.detect.lostSeconds or DEFAULT_DETECT.lostSeconds) then
                SKTailing.stop(true)
                if s.onFail then pcall(s.onFail, 'lost') end
                return
            end
            Wait(100)
        end
    end)
end

function SKTailing.stop(release)
    if not session then return end
    session.stopped = true
    cleanupSession(release)
end
