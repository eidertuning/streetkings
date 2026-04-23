local DEVTOOLS_CONVAR = 'streetkings_enableDevtools'
if GetConvar(DEVTOOLS_CONVAR, 'false') ~= 'true' then
    return
end

SKRaceEditorFreecam = {}

local freecamEnabled = false
local freecamCamera = nil
local freecamRotation = vector3(0.0, 0.0, 0.0)
local freecamFrozenEntity = nil
local slowSpeed = 0.02
local normalSpeed = 0.12
local fastSpeed = 0.5
local focusUpdateIntervalMs = 250
local lastFocusUpdateAt = 0

---@return vector3
local function getForwardVector(rotation)
    local radZ = math.rad(rotation.z)
    local radX = math.rad(rotation.x)
    return vector3(
        -math.sin(radZ) * math.abs(math.cos(radX)),
        math.cos(radZ) * math.abs(math.cos(radX)),
        math.sin(radX)
    )
end

---@return vector3
local function getRightVector(rotation)
    local radZ = math.rad(rotation.z)
    return vector3(
        math.cos(radZ),
        math.sin(radZ),
        0.0
    )
end

---@return nil
local function handleCamera()
    if not freecamCamera then
        return
    end

    local cameraCoords = GetCamCoord(freecamCamera)
    local mouseX = GetDisabledControlNormal(0, 1) * 5.0
    local mouseY = GetDisabledControlNormal(0, 2) * 5.0

    freecamRotation = vector3(
        math.max(-89.0, math.min(89.0, freecamRotation.x - mouseY)),
        freecamRotation.y,
        freecamRotation.z - mouseX
    )

    SetCamRot(freecamCamera, freecamRotation.x, freecamRotation.y, freecamRotation.z, 2)

    local movementSpeed = normalSpeed
    if IsDisabledControlPressed(0, 19) then
        movementSpeed = slowSpeed
    elseif IsDisabledControlPressed(0, 21) then
        movementSpeed = fastSpeed
    end

    local forward = getForwardVector(freecamRotation)
    local right = getRightVector(freecamRotation)
    local up = vector3(0.0, 0.0, 1.0)
    local nextCoords = cameraCoords

    if IsDisabledControlPressed(0, 32) then
        nextCoords = nextCoords + forward * movementSpeed
    end
    if IsDisabledControlPressed(0, 33) then
        nextCoords = nextCoords - forward * movementSpeed
    end
    if IsDisabledControlPressed(0, 34) then
        nextCoords = nextCoords - right * movementSpeed
    end
    if IsDisabledControlPressed(0, 35) then
        nextCoords = nextCoords + right * movementSpeed
    end
    if IsDisabledControlPressed(0, 44) then
        nextCoords = nextCoords - up * movementSpeed
    end
    if IsDisabledControlPressed(0, 38) then
        nextCoords = nextCoords + up * movementSpeed
    end

    SetCamCoord(freecamCamera, nextCoords.x, nextCoords.y, nextCoords.z)

    local now = GetGameTimer()
    if now >= lastFocusUpdateAt then
        SetFocusPosAndVel(nextCoords.x, nextCoords.y, nextCoords.z, 0.0, 0.0, 0.0)
        lastFocusUpdateAt = now + focusUpdateIntervalMs
    end

    DisableAllControlActions(0)
    EnableControlAction(0, 1, true)
    EnableControlAction(0, 2, true)
    EnableControlAction(0, 19, true)
    EnableControlAction(0, 21, true)
    EnableControlAction(0, 22, true)
    EnableControlAction(0, 24, true)
    EnableControlAction(0, 25, true)
    EnableControlAction(0, 32, true)
    EnableControlAction(0, 33, true)
    EnableControlAction(0, 34, true)
    EnableControlAction(0, 35, true)
    EnableControlAction(0, 38, true)
    EnableControlAction(0, 44, true)
    EnableControlAction(0, 140, true)
    EnableControlAction(0, 177, true)
    EnableControlAction(0, 179, true)
    EnableControlAction(0, 191, true)
    EnableControlAction(0, 200, true)
    EnableControlAction(0, 245, true)
end

---@return nil
function SKRaceEditorFreecam.start()
    if freecamEnabled then
        return
    end

    freecamEnabled = true
    lastFocusUpdateAt = 0
    SKCamera.setBlocked(true)

    local gameplayCameraCoords = GetGameplayCamCoord()
    local gameplayCameraRotation = GetGameplayCamRot(2)

    freecamCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(freecamCamera, gameplayCameraCoords.x, gameplayCameraCoords.y, gameplayCameraCoords.z)
    SetCamRot(freecamCamera, gameplayCameraRotation.x, gameplayCameraRotation.y, gameplayCameraRotation.z, 2)
    SetCamFov(freecamCamera, GetGameplayCamFov())
    SetCamActive(freecamCamera, true)
    RenderScriptCams(true, false, 0, true, true)

    freecamRotation = gameplayCameraRotation

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        freecamFrozenEntity = vehicle
    else
        freecamFrozenEntity = ped
    end

    FreezeEntityPosition(freecamFrozenEntity, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(freecamFrozenEntity, false, false)

    CreateThread(function()
        while freecamEnabled do
            handleCamera()
            Wait(0)
        end
    end)
end

---@return nil
function SKRaceEditorFreecam.stop()
    if not freecamEnabled then
        return
    end

    freecamEnabled = false

    if freecamCamera then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(freecamCamera, false)
        freecamCamera = nil
    end

    local ped = PlayerPedId()
    if freecamFrozenEntity then
        FreezeEntityPosition(freecamFrozenEntity, false)
        SetEntityCollision(freecamFrozenEntity, true, true)
        freecamFrozenEntity = nil
    end
    SetEntityVisible(ped, true, false)
    ClearFocus()
    SKCamera.setBlocked(false)
end

---@return boolean
function SKRaceEditorFreecam.isEnabled()
    return freecamEnabled
end

---@return vector3|nil
function SKRaceEditorFreecam.raycast()
    if not freecamCamera then
        return nil
    end

    local hit, _, endCoords = lib.raycast.fromCamera(511, 4, 5000.0)
    if not hit then
        return nil
    end

    return endCoords
end

exports('StartRaceEditorFreecam', SKRaceEditorFreecam.start)
exports('StopRaceEditorFreecam', SKRaceEditorFreecam.stop)
exports('IsRaceEditorFreecamEnabled', SKRaceEditorFreecam.isEnabled)
exports('RaceEditorFreecamRaycast', SKRaceEditorFreecam.raycast)
