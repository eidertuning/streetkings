SKCamera = {}
Cinematic = false

-- Config --------------------------------------------------------------------

local CAMERA_PRESETS = {
    envi = {
        baseFov                   = 45.0,
        baseForwardOffset         = -5.05,
        sideOffset                = 0.0,
        upOffset                  = 0.55,
        pivotHeightOffset         = 0.9,
        velocityBlendRatio        = 0.98,
        velocityDirSmoothing      = 0.40,
        lateralFollowDeadzoneDeg  = 0.0,
        headingFollowDeadzoneDeg  = 0.0,
        headingFollowCatchupRatio = 1.0,
        headingFollowReturnRatio  = 1.0,
        gForceMultiplier          = 0.6,
        lateralEffectMultiplier   = 0.6,
        shakeIntensityMultiplier  = 0.6,
        gearPullbackEnabled       = true,
        gearPullbackStrength      = 2.00,
        gearPullbackAttack        = 0.025,
        gearPullbackDecay         = 0.025,
        accelSmoothing            = 0.25,
        maxSpeedForEffects        = 60.0,
        speedFovMultiplier        = 1.0,
        effectInterpolation       = 0.07,
        accelPositionMultiplier   = 1.2,
        cameraRollInterpolation   = 0.22,
        cameraPitchInterpolation  = 0.22,
        lowSpeedEffects           = 15,
        brakingFovLimit           = 15.0,
    },
    nine = {
        baseFov                   = 45.0,
        baseForwardOffset         = -5.05,
        sideOffset                = 0.0,
        upOffset                  = 0.55,
        pivotHeightOffset         = 0.9,
        velocityBlendRatio        = 0.98,
        velocityDirSmoothing      = 0.40,
        lateralFollowDeadzoneDeg  = 0.0,
        headingFollowDeadzoneDeg  = 0.0,
        headingFollowCatchupRatio = 1.0,
        headingFollowReturnRatio  = 1.0,
        gForceMultiplier          = 0.6,
        lateralEffectMultiplier   = 0.6,
        shakeIntensityMultiplier  = 0.6,
        gearPullbackEnabled       = true,
        gearPullbackStrength      = 2.00,
        gearPullbackAttack        = 0.025,
        gearPullbackDecay         = 0.025,
        accelSmoothing            = 0.25,
        maxSpeedForEffects        = 60.0,
        speedFovMultiplier        = 1.0,
        effectInterpolation       = 0.07,
        accelPositionMultiplier   = 1.2,
        cameraRollInterpolation   = 0.22,
        cameraPitchInterpolation  = 0.22,
        lowSpeedEffects           = 100,
        brakingFovLimit           = 15.0,
    },
    relaxed = {
        baseFov                   = 45.0,
        baseForwardOffset         = -5.05,
        sideOffset                = 0.0,
        upOffset                  = 0.55,
        pivotHeightOffset         = 0.9,
        velocityBlendRatio        = 0.82,
        velocityDirSmoothing      = 0.14,
        lateralFollowDeadzoneDeg  = 14.0,
        headingFollowDeadzoneDeg  = 24.0,
        headingFollowCatchupRatio = 0.22,
        headingFollowReturnRatio  = 0.035,
        gForceMultiplier          = 0.35,
        lateralEffectMultiplier   = 0.25,
        shakeIntensityMultiplier  = 0.18,
        gearPullbackEnabled       = true,
        gearPullbackStrength      = 1.10,
        gearPullbackAttack        = 0.018,
        gearPullbackDecay         = 0.016,
        accelSmoothing            = 0.14,
        maxSpeedForEffects        = 80.0,
        speedFovMultiplier        = 0.85,
        effectInterpolation       = 0.045,
        accelPositionMultiplier   = 0.45,
        cameraRollInterpolation   = 0.12,
        cameraPitchInterpolation  = 0.12,
        lowSpeedEffects           = 100,
        brakingFovLimit           = 13.0,
    },
}

local activePresetKey = 'relaxed'
local config = {}
local actionCamDisabled = false
local actionCamBlocked = false
local ACTION_CAM_DISABLED_KVP = 'sk_cam_disableActionCam'

---@param state string|nil
---@return boolean
local function cameraAllowedForState(state)
    return state == GameState.FREEROAM
        or state == GameState.EVENT
        or state == GameState.MISSION
        or state == GameState.TUTORIAL
        or state == GameState.MULTIPLAYER_LOBBY
        or state == GameState.MULTIPLAYER_EVENT
end

---@param source table
---@return table
local function cloneConfig(source)
    local copy = {}
    for k, v in pairs(source) do
        copy[k] = v
    end
    return copy
end

---@param presetKey string|nil
---@return string
local function resolvePresetKey(presetKey)
    if presetKey and CAMERA_PRESETS[presetKey] then
        return presetKey
    end
    return 'relaxed'
end

---@param presetKey string|nil
local function applyPresetConfig(presetKey)
    activePresetKey = resolvePresetKey(presetKey)
    config = cloneConfig(CAMERA_PRESETS[activePresetKey])
end

local function loadKvpConfig()
    applyPresetConfig(GetResourceKvpString('sk_cam_preset'))
    actionCamDisabled = GetResourceKvpString(ACTION_CAM_DISABLED_KVP) == 'true'
    for key, default in pairs(config) do
        local raw = GetResourceKvpString('sk_cam_' .. key)
        if raw then
            if type(default) == 'boolean' then
                config[key] = raw == 'true'
            else
                config[key] = tonumber(raw)
            end
        end
    end
end
loadKvpConfig()

-- Constants -----------------------------------------------------------------

local RAD_179       = math.pi * 179.0 / 180.0
local DEG_PER_RAD   = 180.0 / math.pi
local RAD_PER_DEG   = math.pi / 180.0
local TWO_PI        = 2.0 * math.pi
local ROLL_MIN      = -50.0
local ROLL_MAX      =  50.0
local PITCH_MIN     = -65.0
local PITCH_MAX     =  65.0
local COLLISION_PAD = 0.25
local LOW_SPEED_THRESHOLD = 9.0 -- ~20 mph in m/s

-- State ---------------------------------------------------------------------

local active  = false
local camera  = nil

local currentFov           = config.baseFov
local currentForwardOffset = config.baseForwardOffset
local lastFovSent          = config.baseFov

local previousSpeed          = 0.0
local currentSpeed           = 0.0   -- shared with handleInput
local currentAcceleration    = 0.0
local smoothedAcceleration   = 0.0
local smoothedBrakingAccel   = 0.0

local svdX, svdY, svdZ = 0.0, 1.0, 0.0   -- smoothedVelocityDirection (plain components, no alloc)
local lateralVelocity  = 0.0
local verticalVelocity = 0.0
local gfX, gfY, gfZ   = 0.0, 0.0, 0.0   -- gForces
local shakeIntensity   = 0.0
local lvpX, lvpY, lvpZ = 0.0, 0.0, 0.0  -- lastVehiclePosition

local previousGear      = 1
local gearPullback      = 0.0
local gearPullbackTarget = 0.0
local followHeadingRad   = nil

local userTilt       = 0.0
local userYaw        = 0.0
local userLookBehind = false
local yawReturnTimer = 0.0

local USER_YAW_RETURN_INTERPOLATION = 0.015

local speedFactor    = 1.0
local minimapThrottle = 0
local FOV_DELTA_THRESHOLD = 0.05
local autoEnableBlockedUntil = 0
local delayedEnableToken = 0
local wasCinematic = false
local tick

-- reusable tables to avoid per-frame table creating
local _static = { x = 0, y = 0, z = 0 }
local _tilt   = { x = 0, y = 0, z = 0 }
local _camPos = { x = 0, y = 0, z = 0 }

-- Math helpers --------------------------------------------------------------

local function lerp(a, b, t)
    return a + (b - a) * t
end

---@param value number
---@param minValue number
---@param maxValue number
---@return number
local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function fmod(a, b)
    return a - math.floor(a / b) * b
end

---@param angle number
---@return number
local function normalizeAngle(angle)
    return fmod(angle + math.pi, TWO_PI) - math.pi
end

---@param out table  output {x,y,z} to write into
---@param point table {x,y,z}
---@param ax number  normalised axis x
---@param ay number  normalised axis y
---@param az number  normalised axis z
---@param angle number radians
---@return table out
local function rotateAroundNormalised(out, point, ax, ay, az, angle)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    local dot   = point.x * ax + point.y * ay + point.z * az
    local cx    = ay * point.z - az * point.y
    local cy    = az * point.x - ax * point.z
    local cz    = ax * point.y - ay * point.x
    local one_c = 1.0 - cos_a
    out.x = point.x * cos_a + cx * sin_a + ax * dot * one_c
    out.y = point.y * cos_a + cy * sin_a + ay * dot * one_c
    out.z = point.z * cos_a + cz * sin_a + az * dot * one_c
    return out
end

-- Internal reset ------------------------------------------------------------

local function resetState(cancelDelayedEnable)
    userTilt       = 0.0
    userYaw        = 0.0
    userLookBehind = false
    yawReturnTimer = 0.0

    previousSpeed        = 0.0
    currentSpeed         = 0.0
    currentAcceleration  = 0.0
    smoothedAcceleration = 0.0

    currentFov           = config.baseFov
    currentForwardOffset = config.baseForwardOffset
    lastFovSent          = config.baseFov

    smoothedBrakingAccel = 0.0
    svdX, svdY, svdZ     = 0.0, 1.0, 0.0
    lateralVelocity      = 0.0
    verticalVelocity     = 0.0
    gfX, gfY, gfZ        = 0.0, 0.0, 0.0
    shakeIntensity       = 0.0
    lvpX, lvpY, lvpZ     = 0.0, 0.0, 0.0

    previousGear         = 1
    gearPullback         = 0.0
    gearPullbackTarget   = 0.0
    followHeadingRad     = nil
    speedFactor          = 1.0
    minimapThrottle      = 0
    autoEnableBlockedUntil = 0
    if cancelDelayedEnable then
        delayedEnableToken = delayedEnableToken + 1
    end
end

local function hasCamera()
    return camera ~= nil and DoesCamExist(camera)
end

local function isCameraRendering()
    return hasCamera() and GetRenderingCam() == camera
end

local function destroyCamera()
    RenderScriptCams(false, true, 500, true, true)
    local cam = camera
    if cam ~= nil and DoesCamExist(cam) then
        SetCamActive(cam, false)
        DestroyCam(cam, true)
    end
    camera = nil
    DestroyAllCams(true)
    local pos = GetEntityCoords(PlayerPedId())
    SetFocusArea(pos.x, pos.y, pos.z, 0, 0, 0)
    SetCamViewModeForContext(4, 4)
    UnlockMinimapAngle()
    ClearFocus()
    SetPlayerControl(PlayerId(), true, 0)
end

---@param speed number
local function getBaseTargetFov(speed)
    local speedRatio = math.min(speed / config.maxSpeedForEffects, 1.0)
    return config.baseFov * lerp(1.0, 0.75, speedRatio)
        + speedRatio * config.speedFovMultiplier * 25.0
end

---@param vehicle integer
local function primeDynamicState(vehicle)
    local vel = GetEntityVelocity(vehicle)
    local speed = math.sqrt((vel.x * vel.x) + (vel.y * vel.y) + (vel.z * vel.z))
    local pos = GetEntityCoords(vehicle, true)

    previousSpeed = speed
    currentSpeed = speed
    currentAcceleration = 0.0
    smoothedAcceleration = 0.0
    smoothedBrakingAccel = 0.0
    gearPullback = 0.0
    gearPullbackTarget = 0.0
    currentFov = getBaseTargetFov(speed)
    currentForwardOffset = config.baseForwardOffset
    lastFovSent = -1.0
    lvpX, lvpY, lvpZ = pos.x, pos.y, pos.z
end

local function disable()
    active = false
    destroyCamera()
    resetState(true)
end

---@param vehicle integer
local function initializeCamera(vehicle)
    if hasCamera() then return end
    camera = nil

    local gpos = GetGameplayCamCoord()
    local grot = GetGameplayCamRot(2)

    camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camera, gpos.x, gpos.y, gpos.z)
    SetCamRot(camera, grot.x, grot.y, grot.z, 2)
    SetCamFov(camera, currentFov)
    SetCamActive(camera, true)
    RenderScriptCams(true, false, 0, true, true)

    local fwd = GetEntityForwardVector(vehicle)
    local pos = GetEntityCoords(vehicle, true)
    svdX, svdY, svdZ = fwd.x, fwd.y, fwd.z
    lvpX, lvpY, lvpZ = pos.x, pos.y, pos.z
    followHeadingRad = math.atan(fwd.y, fwd.x)
    primeDynamicState(vehicle)
end

---@param vehicle integer
local function forceEnable(vehicle)
    destroyCamera()
    resetState(false)
    active = true
    autoEnableBlockedUntil = 0
    initializeCamera(vehicle)
    tick(vehicle)
end

-- Speed / acceleration effects ---------------------------------------------
-- Receives pre-fetched vehicle data from tick() to avoid duplicate native calls.

---@param vehicle  integer
---@param velX number  @param velY number  @param velZ number
---@param speed   number
---@param vehPos  vector3
---@param fwdX number  @param fwdY number  @param fwdZ number
---@param rtX  number  @param rtY  number  -- normalised right vector (Z=0)
local function calcSpeedEffects(vehicle, velX, velY, velZ, speed, vehPos, fwdX, fwdY, fwdZ, rtX, rtY)
    local dt = GetFrameTime()
    local isEnviPreset = activePresetKey == 'envi'

    if dt > 0.0 and dt < 0.1 and (lvpX ~= 0.0 or lvpY ~= 0.0 or lvpZ ~= 0.0) then
        local cvX = (vehPos.x - lvpX) / dt
        local cvY = (vehPos.y - lvpY) / dt
        local cvZ = (vehPos.z - lvpZ) / dt

        currentAcceleration = speed - previousSpeed
        previousSpeed       = speed

        local vdX, vdY, vdZ
        if speed > 1.0 then
            vdX, vdY, vdZ = velX / speed, velY / speed, velZ / speed
        else
            vdX, vdY, vdZ = fwdX, fwdY, fwdZ
        end

        if config.lateralFollowDeadzoneDeg > 0.0 then
            local planarForwardLen = math.sqrt(fwdX * fwdX + fwdY * fwdY)
            local planarVelocityLen = math.sqrt(vdX * vdX + vdY * vdY)
            if planarForwardLen > 0.0 and planarVelocityLen > 0.0 then
                local forwardDot = clamp(((fwdX / planarForwardLen) * (vdX / planarVelocityLen)) + ((fwdY / planarForwardLen) * (vdY / planarVelocityLen)), -1.0, 1.0)
                local followBlend = clamp(((math.acos(forwardDot) * DEG_PER_RAD) - config.lateralFollowDeadzoneDeg) / 16.0, 0.0, 1.0)
                vdX = lerp(fwdX, vdX, followBlend)
                vdY = lerp(fwdY, vdY, followBlend)
                vdZ = lerp(fwdZ, vdZ, followBlend)

                local blendedLen = math.sqrt(vdX * vdX + vdY * vdY + vdZ * vdZ)
                if blendedLen > 0.0 then
                    vdX, vdY, vdZ = vdX / blendedLen, vdY / blendedLen, vdZ / blendedLen
                else
                    vdX, vdY, vdZ = fwdX, fwdY, fwdZ
                end
            end
        end

        svdX = lerp(svdX, vdX, config.velocityDirSmoothing)
        svdY = lerp(svdY, vdY, config.velocityDirSmoothing)
        svdZ = lerp(svdZ, vdZ, config.velocityDirSmoothing)

        local dVX = cvX - velX
        local dVY = cvY - velY
        local laX = dVX * rtX  + dVY * rtY
        local laY = dVX * fwdX + dVY * fwdY
        local laZ = cvZ - velZ

        gfX = lerp(gfX, laX *  0.04 * config.gForceMultiplier, 0.2)
        gfY = lerp(gfY, -laY * 0.06 * config.gForceMultiplier, 0.1)
        gfZ = lerp(gfZ, -laZ * 0.004 * config.gForceMultiplier, 0.15)

        lateralVelocity  = lerp(lateralVelocity,  (velX * rtX + velY * rtY) * config.lateralEffectMultiplier, 0.075)
        verticalVelocity = lerp(verticalVelocity, velZ * config.lateralEffectMultiplier, 0.1)

        shakeIntensity = speed > 0.0
            and math.min(math.exp((-100.0 / speed) + 2.0), 1.0) * 0.006 * config.shakeIntensityMultiplier
            or 0.0

        if config.gearPullbackEnabled then
            local gear = GetVehicleCurrentGear(vehicle)
            if gear > previousGear and gear >= 1 then
                gearPullbackTarget = config.gearPullbackStrength
            end
            previousGear = gear
        end
    end

    lvpX, lvpY, lvpZ = vehPos.x, vehPos.y, vehPos.z
    currentSpeed         = speed
    smoothedAcceleration = lerp(smoothedAcceleration, currentAcceleration, config.accelSmoothing)
    smoothedBrakingAccel = lerp(smoothedBrakingAccel, currentAcceleration < 0.0 and currentAcceleration or 0.0, 0.12)
    gearPullbackTarget   = lerp(gearPullbackTarget, 0.0, config.gearPullbackDecay)
    gearPullback         = lerp(gearPullback, gearPullbackTarget, config.gearPullbackAttack)

    if isEnviPreset then
        local rawT = math.min(speed / LOW_SPEED_THRESHOLD, 1.0)
        local smoothT = rawT * rawT * (3.0 - 2.0 * rawT)
        local floor = config.lowSpeedEffects / 100.0
        speedFactor = floor + (1.0 - floor) * smoothT
    else
        speedFactor = 1.0
    end

    local speedRatio = math.min(speed / config.maxSpeedForEffects, 1.0)
    local brakingFov = isEnviPreset
        and math.max(-config.brakingFovLimit, math.abs(smoothedBrakingAccel) * -58.0 * speedFactor)
        or math.max(-config.brakingFovLimit, math.abs(smoothedBrakingAccel) * -58.0)
    local targetFov  = config.baseFov * lerp(1.0, 0.75, speedRatio)
                       + speedRatio * config.speedFovMultiplier * 25.0
                       + brakingFov
    currentFov = lerp(currentFov, targetFov, config.effectInterpolation)

    local accelEffect    = math.max(-5.0, math.min(5.0, smoothedAcceleration * config.accelPositionMultiplier))
    currentForwardOffset = lerp(currentForwardOffset, config.baseForwardOffset - accelEffect, config.effectInterpolation)
end

---@param targetX number
---@param targetY number
---@param targetZ number
---@return number
---@return number
---@return number
local function resolveCameraFollowForward(targetX, targetY, targetZ)
    local planarLen = math.sqrt(targetX * targetX + targetY * targetY)
    if planarLen <= 0.0 then
        return targetX, targetY, targetZ
    end

    local targetHeading = math.atan(targetY, targetX)
    if not followHeadingRad then
        followHeadingRad = targetHeading
    end

    local deadzone = (config.headingFollowDeadzoneDeg or 0.0) * RAD_PER_DEG
    local catchupRatio = config.headingFollowCatchupRatio or 1.0
    local returnRatio = config.headingFollowReturnRatio or 0.0
    local delta = normalizeAngle(targetHeading - followHeadingRad)

    if deadzone <= 0.0 or math.abs(delta) > deadzone then
        local step = deadzone <= 0.0 and math.abs(delta) or (math.abs(delta) - deadzone) * catchupRatio
        followHeadingRad = normalizeAngle(followHeadingRad + (delta < 0.0 and -1.0 or 1.0) * math.min(math.abs(delta), step))
    elseif math.abs(delta) > 0.0 and returnRatio > 0.0 then
        local step = math.abs(delta) * returnRatio
        followHeadingRad = normalizeAngle(followHeadingRad + (delta < 0.0 and -1.0 or 1.0) * math.min(math.abs(delta), step))
    end

    local outX = math.cos(followHeadingRad)
    local outY = math.sin(followHeadingRad)
    local outZ = targetZ
    local outLen = math.sqrt(outX * outX + outY * outY + outZ * outZ)
    if outLen > 0.0 then
        return outX / outLen, outY / outLen, outZ / outLen
    end

    return targetX, targetY, targetZ
end

-- Camera collision ---------------------------------------------------------

-- Mutates pos in-place
---@param pos table {x,y,z}
---@param ox number  @param oy number  @param oz number  origin (vehicle pos + offset)
local function applyCollision(pos, ox, oy, oz)
    local ray = StartShapeTestRay(ox, oy, oz, pos.x, pos.y, pos.z, 1, PlayerPedId(), 0)
    local retval, hit, hitCoords = GetShapeTestResult(ray)
    if retval == 2 and hit == 1 then
        local dx  = ox - hitCoords.x
        local dy  = oy - hitCoords.y
        local dz  = oz - hitCoords.z
        local len = math.sqrt(dx * dx + dy * dy + dz * dz)
        if len > 0.01 then
            local pad = COLLISION_PAD / len
            pos.x = hitCoords.x + dx * pad
            pos.y = hitCoords.y + dy * pad
            pos.z = hitCoords.z + dz * pad
        end
    end
end

-- Main camera tick ---------------------------------------------------------

tick = function(vehicle)
    local isEnviPreset = activePresetKey == 'envi'

    -- Fetch all vehicle data once -------------------------------------------
    local vehPos = GetEntityCoords(vehicle, true)
    local fwd    = GetEntityForwardVector(vehicle)
    local vel    = GetEntityVelocity(vehicle)
    local velX, velY, velZ = vel.x, vel.y, vel.z
    local speed  = math.sqrt(velX * velX + velY * velY + velZ * velZ)

    -- Right vector: cross(fwd, worldUp) = (fwd.y, -fwd.x, 0), normalised
    local rtX, rtY
    do
        local rx = fwd.y
        local ry = -fwd.x
        local rlen = math.sqrt(rx * rx + ry * ry)
        if rlen > 0.0 then rtX, rtY = rx / rlen, ry / rlen else rtX, rtY = 1.0, 0.0 end
    end

    -- Initialise camera on first tick --------------------------------------
    if not hasCamera() then
        initializeCamera(vehicle)
    end

    local cam = camera
    if not cam then return end

    calcSpeedEffects(vehicle, velX, velY, velZ, speed, vehPos, fwd.x, fwd.y, fwd.z, rtX, rtY)

    -- Throttle FOV native call to when it meaningfully changes
    if math.abs(currentFov - lastFovSent) > FOV_DELTA_THRESHOLD then
        SetCamFov(cam, currentFov)
        lastFovSent = currentFov
    end

    local fwdX, fwdY, fwdZ = fwd.x, fwd.y, fwd.z

    local effectiveVelocityBlend
    if isEnviPreset then
        local slipRatio = math.min(1.0, math.abs(lateralVelocity) / math.max(speed, 1.0))
        local driftBlendScale = 1.0 - (slipRatio * 0.7)
        effectiveVelocityBlend = config.velocityBlendRatio * driftBlendScale * speedFactor
    else
        effectiveVelocityBlend = config.velocityBlendRatio
    end

    local blX = lerp(fwdX, svdX, effectiveVelocityBlend)
    local blY = lerp(fwdY, svdY, effectiveVelocityBlend)
    local blZ = lerp(fwdZ, svdZ, effectiveVelocityBlend)
    local blen = math.sqrt(blX * blX + blY * blY + blZ * blZ)
    if blen > 0.01 then
        blX, blY, blZ = blX / blen, blY / blen, blZ / blen
    else
        blX, blY, blZ = fwdX, fwdY, fwdZ
    end

    local camFwdX, camFwdY, camFwdZ = resolveCameraFollowForward(blX, blY, blZ)
    local camRtX, camRtY
    do
        local rx = camFwdY
        local ry = -camFwdX
        local rlen = math.sqrt(rx * rx + ry * ry)
        if rlen > 0.0 then camRtX, camRtY = rx / rlen, ry / rlen else camRtX, camRtY = 1.0, 0.0 end
    end
    local upX = camRtY * camFwdZ
    local upY = -camRtX * camFwdZ
    local upZ = camRtX * camFwdY - camRtY * camFwdX

    local latOff  = lateralVelocity * 0.5
    local vertOff = math.abs(lateralVelocity) * 0.025
    local t       = GetGameTimer() * 0.002
    local shakeX  = shakeIntensity * math.sin(TWO_PI * 8.0 * t) * 1.5 * config.shakeIntensityMultiplier
    local shakeZ  = shakeIntensity * math.sin(TWO_PI * 6.0 * t) * 1.2 * config.shakeIntensityMultiplier
    local so      = config.sideOffset + latOff
    local fwdOff  = currentForwardOffset - gearPullback

    _static.x = camFwdX * fwdOff + camRtX * so + shakeX + gfX
    _static.y = camFwdY * fwdOff + camRtY * so          + gfY
    _static.z = camFwdZ * fwdOff                 + config.upOffset + vertOff + shakeZ + gfZ

    -- Tilt rotation (skip when near zero)
    local tilted
    if math.abs(userTilt) > 0.1 then
        tilted = rotateAroundNormalised(_tilt, _static, camRtX, camRtY, 0.0, userTilt * RAD_PER_DEG)
    else
        tilted = _static
    end

    local pivotZ = vehPos.z + config.pivotHeightOffset

    -- Yaw / look-behind rotation — writes directly into _camPos
    if userLookBehind then
        rotateAroundNormalised(_camPos, tilted, upX, upY, upZ, RAD_179)
        _camPos.x = vehPos.x + _camPos.x
        _camPos.y = vehPos.y + _camPos.y
        _camPos.z = pivotZ   + _camPos.z
    elseif math.abs(userYaw) > 0.1 then
        rotateAroundNormalised(_camPos, tilted, upX, upY, upZ, userYaw * RAD_PER_DEG)
        _camPos.x = vehPos.x + _camPos.x
        _camPos.y = vehPos.y + _camPos.y
        _camPos.z = pivotZ   + _camPos.z
    else
        _camPos.x = vehPos.x + tilted.x
        _camPos.y = vehPos.y + tilted.y
        _camPos.z = pivotZ   + tilted.z
    end

    if _camPos.x ~= _camPos.x or _camPos.x == math.huge or _camPos.x == -math.huge then
        _camPos.x = vehPos.x + camFwdX * fwdOff
        _camPos.y = vehPos.y + camFwdY * fwdOff
        _camPos.z = pivotZ + config.upOffset
    end

    applyCollision(_camPos, vehPos.x, vehPos.y, pivotZ)

    SetCamCoord(cam, _camPos.x, _camPos.y, _camPos.z)

    -- Rotation --------------------------------------------------------------
    local currentRot = GetCamRot(cam, 2)
    local roll, basePitch
    local vehRoll  = GetEntityRoll(vehicle)
    local vehPitch = GetEntityPitch(vehicle)

    if vehRoll < ROLL_MIN or vehRoll > ROLL_MAX or vehPitch < PITCH_MIN or vehPitch > PITCH_MAX then
        roll      = lerp(currentRot.y, 0.0, 0.1)
        basePitch = lerp(currentRot.x, 0.0, 0.1)
    else
        local latRoll = clamp(lateralVelocity * 0.1, -0.3, 0.3)
        local gfRoll  = clamp(gfX * 2.0, -0.2, 0.2)
        roll      = lerp(currentRot.y, -vehRoll + latRoll + gfRoll, config.cameraRollInterpolation)
        basePitch = lerp(currentRot.x, vehPitch, config.cameraPitchInterpolation)
    end
    roll = clamp(roll, ROLL_MIN, ROLL_MAX)

    local dx = vehPos.x - _camPos.x
    local dy = vehPos.y - _camPos.y
    local dz = pivotZ   - _camPos.z
    local hd = math.sqrt(dx * dx + dy * dy)
    local lookPitch, lookYaw = 0.0, 0.0
    if hd > 0.1 then
        lookPitch = math.atan(dz / hd) * DEG_PER_RAD
        lookYaw   = math.atan(dy, dx) * DEG_PER_RAD
    end

    local adjYaw   = lookYaw - 90.0
    local finalYaw = adjYaw
    finalYaw = fmod(finalYaw + 180.0, 360.0) - 180.0

    local finalPitch
    if math.abs(userTilt) < 0.1 then
        -- At rest: always lerp directly toward the geometrically correct look-at pitch
        finalPitch = lerp(currentRot.x, lookPitch, config.cameraPitchInterpolation)
    else
        local tiltRatio     = math.abs(userTilt) / 80.0
        local tiltInfluence = math.min(1.0, (tiltRatio ^ 0.2) * 1.5)
        finalPitch = lerp(basePitch, lookPitch, tiltInfluence)
    end
    finalPitch = finalPitch + clamp(gfY * 2.0 * (isEnviPreset and speedFactor or 1.0), -8.0, 8.0)
    finalPitch = finalPitch + clamp(smoothedAcceleration * -6.0 * (isEnviPreset and speedFactor or 1.0), -12.0, 0.0)
    finalPitch = clamp(finalPitch, PITCH_MIN, PITCH_MAX)

    local accelTilt = clamp(smoothedAcceleration * 4.0 * (isEnviPreset and speedFactor or 1.0), -8.0, 8.0)
    SetCamRot(cam, finalPitch + accelTilt, roll, finalYaw, 2)

    -- Throttle minimap update to every 3 frames
    minimapThrottle = minimapThrottle + 1
    if minimapThrottle >= 3 then
        LockMinimapAngle(math.floor(fmod(finalYaw, 360.0)))
        minimapThrottle = 0
    end
end

-- Input handling ------------------------------------------------------------

local function handleInput()
    local tiltCtrl = (GetControlValue(1, 2) / 256.0) - 0.5
    local yawCtrl  = (GetControlValue(1, 1) / 256.0) - 0.5
    userLookBehind = IsDisabledControlPressed(0, 26)

    if math.abs(tiltCtrl) > 0.02 or math.abs(yawCtrl) > 0.02 then
        if IsInputDisabled(1) then
            userTilt = userTilt - tiltCtrl * 12.0
            userYaw  = userYaw  - yawCtrl  * 32.0
        else
            userTilt = userTilt - tiltCtrl
            userYaw  = userYaw  - yawCtrl * 4.0
        end
        userTilt = math.max(-45.0, math.min(50.0, userTilt))
        userYaw  = fmod(userYaw + 180.0, 360.0) - 180.0
        yawReturnTimer = 1.0
    elseif math.abs(yawCtrl) <= 0.02 and math.abs(userYaw) > (USER_YAW_RETURN_INTERPOLATION + 0.01) then
        if yawReturnTimer <= 0.0 then
            local sm = currentSpeed < 3.0 and (currentSpeed / 3.0) or 1.0
            userYaw  = lerp(userYaw, 0.0, USER_YAW_RETURN_INTERPOLATION * sm)
            if math.abs(userYaw) < 0.1 then userYaw = 0.0 end
        else
            yawReturnTimer = yawReturnTimer - USER_YAW_RETURN_INTERPOLATION
        end
    end
end

---@return table
function SKCamera.getConfig()
    local copy = {}
    for k, v in pairs(config) do copy[k] = v end
    copy.presetKey = activePresetKey
    copy.disableActionCam = actionCamDisabled
    return copy
end

---@param key string
---@param value number|boolean
function SKCamera.setConfig(key, value)
    if key == 'disableActionCam' then
        actionCamDisabled = value == true
        SetResourceKvp(ACTION_CAM_DISABLED_KVP, tostring(actionCamDisabled))

        if actionCamDisabled then
            disable()
        else
            local state = SKC.GetGameState and SKC.GetGameState()
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and cameraAllowedForState(state) then
                SKCamera.enable(vehicle)
            end
        end

        return
    end

    if config[key] == nil then return end
    config[key] = value
    SetResourceKvp('sk_cam_' .. key, tostring(value))
end

---@param presetKey string
---@return table
function SKCamera.setPreset(presetKey)
    applyPresetConfig(presetKey)
    SetResourceKvp('sk_cam_preset', activePresetKey)
    for key in pairs(CAMERA_PRESETS.envi) do
        DeleteResourceKvp('sk_cam_' .. key)
    end
    resetState(false)
    return SKCamera.getConfig()
end

-- Public API ----------------------------------------------------------------

---@param vehicle integer
function SKCamera.enable(vehicle)
    if actionCamDisabled or actionCamBlocked then return end
    if active and hasCamera() then return end
    active = true
    autoEnableBlockedUntil = 0
    initializeCamera(vehicle)
end

---@param vehicle integer
---@param delayMs integer
function SKCamera.delayEnable(vehicle, delayMs)
    if actionCamDisabled or actionCamBlocked then
        disable()
        return
    end

    active = false
    autoEnableBlockedUntil = GetGameTimer() + delayMs
    delayedEnableToken = delayedEnableToken + 1
    local token = delayedEnableToken

    CreateThread(function()
        local stableCount = 0
        Wait(delayMs)

        for _ = 1, 6 do
            if token ~= delayedEnableToken then return end

            local state = SKC.GetGameState and SKC.GetGameState()
            if not cameraAllowedForState(state) then return end
            if not DoesEntityExist(vehicle) then return end

            local ped = PlayerPedId()
            if IsPedInVehicle(ped, vehicle, false) then
                if not isCameraRendering() then
                    forceEnable(vehicle)
                    stableCount = 0
                else
                    stableCount = stableCount + 1
                    if stableCount >= 2 then
                        return
                    end
                end
            else
                stableCount = 0
            end

            Wait(150)
        end
    end)
end

function SKCamera.disable()
    if not active then return end
    disable()
end

---@param blocked boolean
function SKCamera.setBlocked(blocked)
    actionCamBlocked = blocked == true
    if actionCamBlocked then
        disable()
    end
end

---@return boolean
function SKCamera.isActive()
    return active
end

function SKCamera.onFreeroamExit()
    if active then disable() end
end

exports('IsChaseCamEnabled', SKCamera.isActive)
exports('EnableChaseCam', SKCamera.enable)
exports('DisableChaseCam', SKCamera.disable)

exports('SetCinematicMode', function(bool)
    if type(bool) ~= 'boolean' then return false end
    Cinematic = bool
    return true
end)

exports('IsCinematicMode', function()
    return Cinematic
end)

-- Settings NUI callbacks ----------------------------------------------------

RegisterNUICallback('phone:settings:getConfig', function(_, cb)
    cb(SKCamera.getConfig())
end)

RegisterNUICallback('phone:settings:setCameraValue', function(data, cb)
    SKCamera.setConfig(data.key, data.value)
    cb({ ok = true })
end)

RegisterNUICallback('phone:settings:setCameraPreset', function(data, cb)
    cb(SKCamera.setPreset(data.presetKey))
end)

RegisterNUICallback('phone:settings:resetCameraDefaults', function(_, cb)
    for key, value in pairs(CAMERA_PRESETS[activePresetKey]) do
        config[key] = value
        DeleteResourceKvp('sk_cam_' .. key)
    end
    resetState(false)
    cb(SKCamera.getConfig())
end)

-- Main thread ---------------------------------------------------------------

CreateThread(function()
    while true do
        local state = SKC.GetGameState and SKC.GetGameState()
        if not cameraAllowedForState(state) then
            if active then disable() end
            Wait(1000)
        else
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local now = GetGameTimer()

            if veh ~= 0 then
                if not actionCamDisabled and not actionCamBlocked then
                    DisableControlAction(0, 0, true)
                    DisableControlAction(0, 26, true)
                end
                if not actionCamDisabled and not actionCamBlocked and (not active or not hasCamera()) and now >= autoEnableBlockedUntil then
                    SKCamera.enable(veh)
                end
                if active then
                    if Cinematic then
                        wasCinematic = true
                    else
                        if wasCinematic then
                            primeDynamicState(veh)
                            wasCinematic = false
                        end
                        handleInput()
                        tick(veh)
                    end
                end
            elseif active then
                wasCinematic = false
                disable()
            end

            Wait(veh ~= 0 and 0 or 50)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if not actionCamDisabled and not actionCamBlocked and active and not isCameraRendering() and not Cinematic then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                forceEnable(veh)
            end
        end
    end
end)