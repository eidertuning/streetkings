SKInitiation = SKInitiation or {}

SKInitiation.STARTER_VEHICLES = SKStarterVehicles
local STARTER_VEHICLES = SKInitiation.STARTER_VEHICLES

local SPAWN_POSITIONS = {
    { x = -375.4286, y = 283.7802, z = 84.2439, h = 14.1732 },
    { x = -378.3692, y = 282.0791, z = 84.2271, h = 11.3386 },
    { x = -381.0989, y = 279.1385, z = 84.1934, h = 11.3386 },
}

local PED_POSITION     = { x = -375.4286, y = 283.7802, z = 74.2439, h = 14.1732 }
local CAM_POSITION     = { x = -377.2500, y = 303.7500, z = 86.0500 }
local CAM_FOV          = 19.0

-- DEV: temporary camera adjustment tool
local devCamOffset  = { x = 0.0, y = 0.0, z = 0.0 }
local devFovOffset  = 0.0
local devMoveTimer  = 0
local DEV_STEP      = 0.25
local DEV_FOV_STEP  = 1.0
local DEV_INTERVAL  = 80

local CAM_LOOK_AT = {
    x = (SPAWN_POSITIONS[1].x + SPAWN_POSITIONS[2].x + SPAWN_POSITIONS[3].x) / 3,
    y = (SPAWN_POSITIONS[1].y + SPAWN_POSITIONS[2].y + SPAWN_POSITIONS[3].y) / 3,
    z = (SPAWN_POSITIONS[1].z + SPAWN_POSITIONS[2].z + SPAWN_POSITIONS[3].z) / 3 + 1.0,
}

local stagedVehicles = {}
local stagedVehicleColors = {}
local sceneCamera    = nil
local R, G, B = 255, 209, 71
local initiationControllerTracker = SKControllerFriendly.newTracker()
local initiationControllerMode = false

---@type table<integer, { x: number, y: number, z: number, h: number }>|nil
local stagedVehicleBase = nil

--- @type integer|nil  index into STARTER_VEHICLES
SKInitiation.hoveredIndex = nil

---@return { r: integer, g: integer, b: integer }
local function randomStarterColor()
    return {
        r = math.random(40, 255),
        g = math.random(40, 255),
        b = math.random(40, 255),
    }
end

---@param vehicle integer
---@param colors { primary: { r: integer, g: integer, b: integer }, secondary: { r: integer, g: integer, b: integer } }
local function applyStarterColors(vehicle, colors)
    SetVehicleModKit(vehicle, 0)
    SetVehicleCustomPrimaryColour(vehicle, colors.primary.r, colors.primary.g, colors.primary.b)
    SetVehicleCustomSecondaryColour(vehicle, colors.secondary.r, colors.secondary.g, colors.secondary.b)
end

---@param index integer
---@return { primary: { r: integer, g: integer, b: integer }, secondary: { r: integer, g: integer, b: integer } }|nil
function SKInitiation.getStarterVehicleColors(index)
    return stagedVehicleColors[index]
end

local function syncStarterVehicleTransforms()
    if not stagedVehicleBase then return end
    local hi = SKInitiation.hoveredIndex
    if SKInitiation.isConfirming then
        hi = nil
    end
    for i, vehicle in ipairs(stagedVehicles) do
        local base = stagedVehicleBase[i]
        if base and DoesEntityExist(vehicle) then
            if not NetworkHasControlOfEntity(vehicle) then
                NetworkRequestControlOfEntity(vehicle)
            end
            local zOffset = (hi == i) and 0.07 or 0.0
            SetEntityCoordsNoOffset(vehicle, base.x, base.y, base.z + zOffset, false, false, false)
            SetEntityHeading(vehicle, base.h)
        end
    end
end

local function captureStagedVehicleBases()
    stagedVehicleBase = {}
    for i, vehicle in ipairs(stagedVehicles) do
        if DoesEntityExist(vehicle) then
            local c = GetEntityCoords(vehicle)
            stagedVehicleBase[i] = {
                x = c.x,
                y = c.y,
                z = c.z,
                h = GetEntityHeading(vehicle),
            }
        end
    end
end

---@param vehicle integer
local function drawStarterHoverSpotlight(vehicle)
    local c = GetEntityCoords(vehicle)
    local height = 8.0
    DrawSpotLight(
        c.x, c.y, c.z + height,
        0.0, 0.0, -1.0,
        255, 255, 255,
        height + 2.0,
        20.0,
        0.5,
        20.0,
        15.0
    )
end


---@param mouseX number  normalised [0,1]
---@param mouseY number  normalised [0,1]
---@return integer|nil  index into stagedVehicles
local function raycastHoveredVehicle(mouseX, mouseY)
    local camPos = GetFinalRenderedCamCoord()
    local camRot = GetFinalRenderedCamRot(2)
    local camFov = GetFinalRenderedCamFov()

    local rx = math.rad(camRot.x)
    local rz = math.rad(camRot.z)

    local fwdX =  -math.sin(rz) * math.cos(rx)
    local fwdY =   math.cos(rz) * math.cos(rx)
    local fwdZ =   math.sin(rx)

    local rightX = math.cos(rz)
    local rightY = math.sin(rz)

    local upX =  math.sin(rz) * math.sin(rx)
    local upY = -math.cos(rz) * math.sin(rx)
    local upZ =  math.cos(rx)

    local halfH  = math.tan(math.rad(camFov * 0.5))
    local screenW, screenH = GetActiveScreenResolution()
    local halfW  = halfH * (screenW / screenH)

    local ndcX = (mouseX - 0.5) * 2.0
    local ndcY = -(mouseY - 0.5) * 2.0

    local dirX = fwdX + rightX * ndcX * halfW + upX * ndcY * halfH
    local dirY = fwdY + rightY * ndcX * halfW + upY * ndcY * halfH
    local dirZ = fwdZ                         + upZ * ndcY * halfH

    local len = math.sqrt(dirX ^ 2 + dirY ^ 2 + dirZ ^ 2)
    dirX, dirY, dirZ = dirX / len, dirY / len, dirZ / len

    local destX = camPos.x + dirX * 100.0
    local destY = camPos.y + dirY * 100.0
    local destZ = camPos.z + dirZ * 100.0

    local handle = StartShapeTestRay(
        camPos.x, camPos.y, camPos.z,
        destX,    destY,    destZ,
        2, PlayerPedId(), 0
    )
    local _, hit, _, _, entityHit = GetShapeTestResult(handle)

    if hit == 1 and entityHit ~= 0 then
        for i, veh in ipairs(stagedVehicles) do
            if veh == entityHit then return i end
        end
    end
    return nil
end

local function spawnStarterVehicles()
    stagedVehicles = {}
    stagedVehicleColors = {}
    for i, v in ipairs(STARTER_VEHICLES) do
        local hash = SK.LoadModel(v.model)
        if not hash then goto continue end

        local pos = SPAWN_POSITIONS[i]
        local vehicle = CreateVehicle(hash, pos.x, pos.y, pos.z, pos.h, false, false)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetEntityInvincible(vehicle, true)
        SetVehicleGravity(vehicle, false)
        SK.UnloadModel(hash)

        local colors = {
            primary = randomStarterColor(),
            secondary = randomStarterColor(),
        }
        applyStarterColors(vehicle, colors)

        stagedVehicles[i] = vehicle
        stagedVehicleColors[i] = colors
        ::continue::
    end
end

local function snapVehiclesToGround()
    for _, vehicle in ipairs(stagedVehicles) do
        if DoesEntityExist(vehicle) then
            SetVehicleOnGroundProperly(vehicle)
        end
    end
end

local function destroyStarterVehicles()
    for _, vehicle in ipairs(stagedVehicles) do
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
    stagedVehicles = {}
    stagedVehicleColors = {}
    stagedVehicleBase = nil
end

function SKInitiation.resetHover()
    SKInitiation.hoveredIndex = nil
    SendNUIMessage({ action = 'streetkings:initiation', hoverVehicle = false })
end

---@param index integer
local function setHoveredByIndex(index)
    if index < 1 then index = #STARTER_VEHICLES end
    if index > #STARTER_VEHICLES then index = 1 end
    SKInitiation.hoveredIndex = index
    local v = STARTER_VEHICLES[index]
    SendNUIMessage({
        action       = 'streetkings:initiation',
        hoverVehicle = {
            model = v.model,
            name  = v.displayName,
            brand = v.brand,
            stats = v.stats,
            value = v.value,
        },
    })
end

local function controllerSelectHovered()
    if not SKInitiation.hoveredIndex then return end
    TriggerEvent('streetkings:initiation:controllerSelect')
end

local function enterScene()
    local ped = PlayerPedId()
    SetEntityCoords(ped, PED_POSITION.x, PED_POSITION.y, PED_POSITION.z, false, false, false, false)
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)

    sceneCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(sceneCamera, CAM_POSITION.x, CAM_POSITION.y, CAM_POSITION.z)
    PointCamAtCoord(sceneCamera, CAM_LOOK_AT.x, CAM_LOOK_AT.y, CAM_LOOK_AT.z)
    SetCamFov(sceneCamera, CAM_FOV)
    SetCamActive(sceneCamera, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function lockInitiationCamera()
    if not sceneCamera or not DoesCamExist(sceneCamera) then return end
    SetCamCoord(sceneCamera,
        CAM_POSITION.x + devCamOffset.x,
        CAM_POSITION.y + devCamOffset.y,
        CAM_POSITION.z + devCamOffset.z)
    PointCamAtCoord(sceneCamera, CAM_LOOK_AT.x, CAM_LOOK_AT.y, CAM_LOOK_AT.z)
    SetCamFov(sceneCamera, CAM_FOV + devFovOffset)
end

local function leaveScene()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)

    if sceneCamera then
        SetCamActive(sceneCamera, false)
        DestroyCam(sceneCamera, false)
        sceneCamera = nil
    end
    RenderScriptCams(false, false, 0, true, true)
end

SKC.RegisterGameState(GameState.INITIATION, {
    onEnter = function()
        SKControllerFriendly.resetTracker(initiationControllerTracker)
        initiationControllerMode = false
        CreateThread(function()
            spawnStarterVehicles()
            enterScene()

            RequestCollisionAtCoord(CAM_POSITION.x, CAM_POSITION.y, CAM_POSITION.z)
            while not HasCollisionLoadedAroundEntity(PlayerPedId()) do Wait(100) end

            snapVehiclesToGround()
            captureStagedVehicleBases()
            SKInitiation.open()
            DoScreenFadeIn(500)
        end)
    end,

    onExit = function()
        if devCamMode then
            devCamMode = false
            SetNuiFocus(false, false)
        end
        SKInitiation.close()
        leaveScene()
        destroyStarterVehicles()
        SKInitiation.hoveredIndex = nil
        SKInitiation.isConfirming = false
    end,

    onTick = function()
        syncStarterVehicleTransforms()
        lockInitiationCamera()
        HideHudAndRadarThisFrame()
        DisableAllControlActions(0)

        local controllerState = SKControllerFriendly.poll(initiationControllerTracker)
        local wasControllerMode = initiationControllerMode
        initiationControllerMode = controllerState.controllerEnabled

        if initiationControllerMode ~= wasControllerMode then
            SendNUIMessage({
                action         = 'streetkings:initiation',
                controllerMode = initiationControllerMode,
            })
        end

        if SKInitiation.isConfirming then
            if initiationControllerMode then
                for _, action in ipairs(controllerState.pressedActions) do
                    SendNUIMessage({
                        action          = 'streetkings:initiation',
                        controllerInput = action,
                    })
                end
            end
            return
        end

        if initiationControllerMode then
            for _, action in ipairs(controllerState.pressedActions) do
                if action == 'left' then
                    setHoveredByIndex((SKInitiation.hoveredIndex or 2) - 1)
                elseif action == 'right' then
                    setHoveredByIndex((SKInitiation.hoveredIndex or 0) + 1)
                elseif action == 'accept' then
                    controllerSelectHovered()
                end
            end
        else
            local cursorX, cursorY = GetNuiCursorPosition()
            local screenW, screenH = GetActiveScreenResolution()
            local mouseX = cursorX / screenW
            local mouseY = cursorY / screenH

            local newHovered = raycastHoveredVehicle(mouseX, mouseY)

            if newHovered ~= SKInitiation.hoveredIndex then
                SKInitiation.hoveredIndex = newHovered

                if newHovered then
                    local v = STARTER_VEHICLES[newHovered]
                    SendNUIMessage({
                        action       = 'streetkings:initiation',
                        hoverVehicle = {
                            model    = v.model,
                            name     = v.displayName,
                            brand    = v.brand,
                            stats    = v.stats,
                            value    = v.value,
                        },
                    })
                else
                    SendNUIMessage({
                        action       = 'streetkings:initiation',
                        hoverVehicle = false,
                    })
                end
            end
        end

        local hi = SKInitiation.hoveredIndex
        if hi and stagedVehicles[hi] and DoesEntityExist(stagedVehicles[hi]) then
            drawStarterHoverSpotlight(stagedVehicles[hi])
        end

        devCamTick()
    end,

    tickWait = 0,
})