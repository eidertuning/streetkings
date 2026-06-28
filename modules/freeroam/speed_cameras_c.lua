local activeZones = {}
local activeProps = {}
local activeBlips = {}
local cooldowns   = {}
local COOLDOWN_MS = 30000
local MPS_TO_MPH  = 2.236936
local SPEED_CAMERA_BLIP_CATEGORY = 22
local speedCameraBlipCategoryRegistered = false

local function registerSpeedCameraBlipCategory()
    if speedCameraBlipCategoryRegistered then return end
    speedCameraBlipCategoryRegistered = true
    AddTextEntry(('BLIP_CAT_%d'):format(SPEED_CAMERA_BLIP_CATEGORY), 'Speed Camera')
end

-- Credit: The scaleform guy (CFX discord)  --------------------------------------

local clonedArrayCleared = false

local function AddFakeConeToBlip(blipIndex, fVisualFieldMinAzimuthAngle, fVisualFieldMaxAzimuthAngle, fCentreOfGazeMaxAngle, fPeripheralRange, fFocusRange, fRotation, bContinuousUpdate)
    if not clonedArrayCleared then
        N_0x8410c5e0cd847b9d()
        clonedArrayCleared = true
    end
    N_0xf83d0febe75e62c9(blipIndex, fVisualFieldMinAzimuthAngle, fVisualFieldMaxAzimuthAngle, fCentreOfGazeMaxAngle, fPeripheralRange, fFocusRange, fRotation, bContinuousUpdate)
    SetBlipShowCone(blipIndex, true)
end

local function RemoveFakeConeFromBlip(blipIndex)
    SetBlipShowCone(blipIndex, false)
    N_0x35a3cd97b2c0a6d2(blipIndex)
end

-- Cinematic -----------------------------------------------------------------

local function cleanupCinematic(cinCam)
    Cinematic = false
    pcall(StopCamShaking, cinCam, true)
    ClearTimecycleModifier()
    SendNUIMessage({ type = 'speedcam:flash', show = false })
    if cinCam and DoesCamExist(cinCam) then
        SetCamActive(cinCam, false)
        DestroyCam(cinCam, false)
    end
    RenderScriptCams(false, true, 0, true, true)
end

local function triggerSpeedCam(cam, speedMph, camIndex)
    if Cinematic then return end
    Cinematic = true

    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if playerVeh == 0 then Cinematic = false return end

    SKCamera.disable()

    local cinCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cinCam, cam.camCoords.x, cam.camCoords.y, cam.camCoords.z)
    PointCamAtEntity(cinCam, playerVeh, 0.0, 0.2, 0.0, true)
    SetCamFov(cinCam, 38.0)
    SetCamActive(cinCam, true)
    RenderScriptCams(true, true, 0, true, true)

    SetTimecycleModifier('CAMERA_secuirity_FUZZ')
    SetTimecycleModifierStrength(0.65)
    pcall(ShakeCam, cinCam, 'HAND_SHAKE', 0.08)

    SendNUIMessage({
        type     = 'speedcam:flash',
        show     = true,
        speed    = math.floor(speedMph),
        name     = cam.name,
        camIndex = camIndex or 1,
    })

    local submitResult = lib.callback.await('streetkings:events:submitTime', false, cam.id, math.floor(speedMph), SK.GetVehicleModelLabel(playerVeh))
    PlaySoundFrontend(-1, 'speedcamera', 'sk_soundset', true)
    Wait(1250)
    cleanupCinematic(cinCam)

    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then
        SKCamera.delayEnable(veh, 75)
    end
    Cinematic = false

    if submitResult and submitResult.reward and submitResult.reward.summary ~= '' then
        SKNotify({
            type     = 'success',
            title    = submitResult.reward.summary,
            duration = 3500,
        })
    end
end

-- Zone enter ----------------------------------------------------------------

local function onCamEnter(cam, camIndex)
    local gs = SKC.GetGameState()
    if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then return end
    if Cinematic then return end

    local now = GetGameTimer()
    if cooldowns[cam.id] and now < cooldowns[cam.id] then return end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return end

    local speedMph = GetEntitySpeed(veh) * MPS_TO_MPH
    if speedMph < cam.triggerSpeedMph then return end

    cooldowns[cam.id] = now + COOLDOWN_MS
    TriggerServerEvent('streetkings:events:beginSpeedCam', cam.id)

    CreateThread(function()
        local ok, err = pcall(triggerSpeedCam, cam, speedMph, camIndex)
        if not ok then
            ClearTimecycleModifier()
            RenderScriptCams(false, true, 0, true, true)
            SendNUIMessage({ type = 'speedcam:flash', show = false })
            Cinematic = false
        end
    end)
end

-- Zones and props -----------------------------------------------------------

local function setupZones()
    if not SKSpeedCameras then return end
    registerSpeedCameraBlipCategory()

    local propHash = SK.LoadModel(`p_tv_cam_02_s`)

    for idx, cam in ipairs(SKSpeedCameras) do
        if propHash then
            local prop = CreateObjectNoOffset(
                propHash,
                cam.propCoords.x, cam.propCoords.y, cam.propCoords.z,
                false, false, false
            )
            PlaceObjectOnGroundProperly(prop)
            SetEntityHeading(prop, cam.propHeading or 0.0)
            FreezeEntityPosition(prop, true)
            SetEntityCollision(prop, false, false)
            activeProps[#activeProps + 1] = prop
            local blip = AddBlipForEntity(prop)
            SetBlipSprite(blip, 827)
            SetBlipColour(blip, 3)
            SetBlipScale(blip, 0.5)
            SetBlipAsShortRange(blip, false)
            SetBlipCategory(blip, SPEED_CAMERA_BLIP_CATEGORY)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString('')
            EndTextCommandSetBlipName(blip)

            local heading = GetEntityHeading(prop)
            AddFakeConeToBlip(blip, cam.coneMinAngle, cam.coneMaxAngle, 0.36, 1.0, cam.coneFocusRange,
                (math.pi / 180.0) * (heading + 180.0), true)

            activeBlips[#activeBlips + 1] = blip
        end

        local zone = lib.zones.sphere({
            coords  = cam.coords,
            radius  = cam.radius or 12,
            debug   = cam.debug or false,
            onEnter = function()
                onCamEnter(cam, idx)
            end,
        })
        activeZones[#activeZones + 1] = zone
    end

    if propHash then SK.UnloadModel(propHash) end
end

local function clearZones()
    for _, zone in ipairs(activeZones) do zone:remove() end
    activeZones = {}

    for _, blip in ipairs(activeBlips) do
        if DoesBlipExist(blip) then
            RemoveFakeConeFromBlip(blip)
            RemoveBlip(blip)
        end
    end
    activeBlips = {}

    for _, prop in ipairs(activeProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    activeProps = {}

    cooldowns = {}
end

-- Lifecycle -----------------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearZones()
    ClearTimecycleModifier()
    SetTimeScale(1.0)
end)

AddEventHandler('streetkings:speedcameras:freeroamEnter', function()
    clearZones()
    setupZones()
end)

AddEventHandler('streetkings:speedcameras:freeroamExit', function()
    clearZones()
end)
