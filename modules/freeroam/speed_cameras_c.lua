local activeZones = {}
local activeProps = {}
local activeBlips = {}
local cooldowns   = {}
local COOLDOWN_MS = 30000
local MPS_TO_MPH  = 2.236936
local SPEED_CAMERA_BLIP_CATEGORY = 22
local speedCameraBlipCategoryRegistered = false
local speedCameraPhotoConfig = nil

local function registerSpeedCameraBlipCategory()
    if speedCameraBlipCategoryRegistered then return end
    speedCameraBlipCategoryRegistered = true
    AddTextEntry(('BLIP_CAT_%d'):format(SPEED_CAMERA_BLIP_CATEGORY), 'Speed Camera')
end

local function getSpeedCameraPhotoConfig()
    if speedCameraPhotoConfig ~= nil then return speedCameraPhotoConfig end

    local ok, cfg = pcall(function()
        return lib.callback.await('streetkings:speedcam:getPhotoConfig', false)
    end)

    speedCameraPhotoConfig = ok and type(cfg) == 'table' and cfg or { enabled = false }
    return speedCameraPhotoConfig
end

local function screenshotWebhookUrl(webhook)
    if type(webhook) ~= 'string' or webhook == '' then return nil end
    if (webhook:find('discord.com/api/webhooks', 1, true) or webhook:find('discordapp.com/api/webhooks', 1, true))
        and not webhook:find('[?&]wait=')
    then
        return webhook .. (webhook:find('?', 1, true) and '&wait=true' or '?wait=true')
    end
    return webhook
end

local function parseScreenshotUrl(response)
    if type(response) ~= 'string' or response == '' then return nil end

    local ok, payload = pcall(json.decode, response)
    if not ok or type(payload) ~= 'table' then return nil end

    if type(payload.attachments) == 'table' and type(payload.attachments[1]) == 'table' then
        local url = payload.attachments[1].url or payload.attachments[1].proxy_url
        if type(url) == 'string' and url ~= '' then return url end
    end

    if type(payload.url) == 'string' and payload.url ~= '' then return payload.url end
    return nil
end

local function entityCoordsPayload(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local coords = GetEntityCoords(entity)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = GetEntityHeading(entity),
    }
end

local function showSpeedCamTicket(cam, speedMph, wantedLevel, vehicleLabel, duration, imageUrl)
    SendNUIMessage({
        type = 'speedcam:ticketPhoto',
        show = true,
        duration = duration or 15000,
        image = imageUrl,
        speed = math.floor(tonumber(speedMph) or 0),
        wantedLevel = math.floor(tonumber(wantedLevel) or 0),
        name = cam and cam.name or '',
        vehicle = vehicleLabel or '',
    })
end

local function emitSpeedCamPhotoLog(cam, speedMph, wantedLevel, vehicleLabel, playerVeh, imageUrl)
    TriggerServerEvent('streetkings:speedcam:photoLog', {
        eventId = cam and cam.id or '',
        name = cam and cam.name or '',
        speedMph = math.floor(tonumber(speedMph) or 0),
        wantedLevel = math.floor(tonumber(wantedLevel) or 0),
        vehicleModel = vehicleLabel or '',
        vehicleCoords = entityCoordsPayload(playerVeh),
        imageUrl = imageUrl,
    })
end

local function captureSpeedCamPhoto(cam, speedMph, wantedLevel, vehicleLabel, playerVeh)
    local cfg = getSpeedCameraPhotoConfig()
    if cfg.enabled == false then return end

    local duration = tonumber(cfg.displayForMs) or 15000
    local finished = false
    showSpeedCamTicket(cam, speedMph, wantedLevel, vehicleLabel, duration, nil)

    local function finish(imageUrl)
        if finished then return end
        finished = true
        if imageUrl then
            showSpeedCamTicket(cam, speedMph, wantedLevel, vehicleLabel, duration, imageUrl)
        end
        emitSpeedCamPhotoLog(cam, speedMph, wantedLevel, vehicleLabel, playerVeh, imageUrl)
    end

    local webhook = screenshotWebhookUrl(cfg.webhook)
    if webhook and GetResourceState('screenshot-basic') == 'started' then
        local screenshot = type(cfg.screenshot) == 'table' and cfg.screenshot or {}
        local options = {
            encoding = type(screenshot.encoding) == 'string' and screenshot.encoding or 'jpg',
            quality = tonumber(screenshot.quality) or 0.85,
        }

        local ok = pcall(function()
            exports['screenshot-basic']:requestScreenshotUpload(webhook, 'files[]', options, function(response)
                finish(parseScreenshotUrl(response))
            end)
        end)

        if ok then
            CreateThread(function()
                Wait(4500)
                finish(nil)
            end)
            return
        end
    end

    finish(nil)
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

local function cleanupCinematic()
    Cinematic = false
    SetTimeScale(1.0)
    StopGameplayCamShaking(true)
    ClearTimecycleModifier()
    SendNUIMessage({ type = 'speedcam:flash', show = false })
end

local function triggerSpeedCam(cam, speedMph, camIndex)
    if Cinematic then return end
    Cinematic = true

    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if playerVeh == 0 then Cinematic = false return end

    local cinCam = nil
    local vehicleLabel = SK.GetVehicleModelLabel(playerVeh)

    SetTimeScale(0.45)
    SetTimecycleModifier('BulletTimeLight')
    SetTimecycleModifierStrength(0.75)
    ShakeGameplayCam('DRUNK_SHAKE', 0.12)

    SendNUIMessage({
        type     = 'speedcam:flash',
        show     = true,
        speed    = math.floor(speedMph),
        name     = cam.name,
        camIndex = camIndex or 1,
    })

    local submitResult = lib.callback.await('streetkings:events:submitTime', false, cam.id, math.floor(speedMph), vehicleLabel)
    local policePayload = submitResult and submitResult.speedCameraPolice or nil
    local wantedLevel = math.floor(tonumber((policePayload and policePayload.wantedLevel) or (submitResult and submitResult.wantedLevel)) or 0)
    if submitResult and submitResult.ok then
        captureSpeedCamPhoto(cam, speedMph, wantedLevel, vehicleLabel, playerVeh)
    end

    PlaySoundFrontend(-1, 'speedcamera', 'sk_soundset', true)
    Wait(1250)
    cleanupCinematic()
    Cinematic = false

    if policePayload and wantedLevel > 0 then
        TriggerEvent('streetkings:police:applySpeedCameraWanted', policePayload)
    end

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
            cleanupCinematic()
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
    StopGameplayCamShaking(true)
    RenderScriptCams(false, true, 0, true, true)
    SendNUIMessage({ type = 'speedcam:flash', show = false })
    SendNUIMessage({ type = 'speedcam:ticketPhoto', show = false })
end)

AddEventHandler('streetkings:speedcameras:freeroamEnter', function()
    clearZones()
    setupZones()
end)

AddEventHandler('streetkings:speedcameras:freeroamExit', function()
    clearZones()
end)
