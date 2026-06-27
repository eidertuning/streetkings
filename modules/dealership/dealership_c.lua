SKDealership = {}

---@return string[]
local function getClassOrder()
    return assert(SKDealershipConfig and SKDealershipConfig.CLASS_ORDER, 'streetkings: missing dealership class order config')
end

---@return table
local function getDealerTypes()
    return assert(SKDealershipConfig and SKDealershipConfig.DEALER_TYPES, 'streetkings: missing dealership types config')
end

---@return table
local function getDealershipLocations()
    return assert(SKDealershipConfig and SKDealershipConfig.LOCATIONS, 'streetkings: missing dealership locations config')
end

---@class SKDealershipLocation
---@field id string
---@field dealerType string
---@field coords vector3
---@field displayCoords vector3
---@field displayHeading number
---@field exitHeading number
---@field name string

---@class SKDealershipVehicleEntry
---@field model string
---@field name string
---@field brand string
---@field price integer
---@field class string
---@field customizability integer
---@field image table|nil
---@field requiredVipTier string|nil

-- Display config ------------------------------------------------------------

local CAM_DIST_DEFAULT    = 5.25
local CAM_DIST_MIN        = 2.75
local CAM_DIST_MAX        = 8.5
local CAM_ANGLE_H_DEFAULT = 160.0
local CAM_ANGLE_V_DEFAULT = 12.0
local CAMERA_ROTATE_SPEED = 2.5
local CAMERA_ZOOM_SPEED   = 0.12
local DEALERSHIP_BLIP_CATEGORY = 21
local dealershipBlipCategoryRegistered = false

-- State ---------------------------------------------------------------------

local activePoints          = {}
local dealershipWaypoints   = {}
local discoveredDealers     = {}
local blips                 = {}

local pendingLocation    = nil
local dealerVehicle      = nil
local dealerCam          = nil
local camDist            = CAM_DIST_DEFAULT
local camAngleH          = CAM_ANGLE_H_DEFAULT
local camAngleV          = CAM_ANGLE_V_DEFAULT
local customizabilityByModel = {}
local dealershipControllerModeEnabled = false
local dealershipControllerTracker = SKControllerFriendly.newTracker()

-- Helpers -------------------------------------------------------------------

---@param dealerId string
---@return boolean
local function isDiscovered(dealerId)
    for _, id in ipairs(discoveredDealers) do
        if id == dealerId then return true end
    end
    return false
end

local function registerDealershipBlipCategory()
    if dealershipBlipCategoryRegistered then return end
    dealershipBlipCategoryRegistered = true
    AddTextEntry(('BLIP_CAT_%d'):format(DEALERSHIP_BLIP_CATEGORY), 'Dealerships')
end

---@param location table
---@return integer
local function addBlip(location)
    registerDealershipBlipCategory()
    local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
    SetBlipSprite(blip, 811)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 1.2)
    SetBlipAsShortRange(blip, false)
    SetBlipCategory(blip, DEALERSHIP_BLIP_CATEGORY)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(location.name)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function updateDealerCamera()
    if not dealerCam or not dealerVehicle or not DoesEntityExist(dealerVehicle) then return end
    local pos  = GetEntityCoords(dealerVehicle)
    local radH = math.rad(camAngleH)
    local radV = math.rad(camAngleV)
    local cx   = pos.x + camDist * math.cos(radV) * math.sin(radH)
    local cy   = pos.y - camDist * math.cos(radV) * math.cos(radH)
    local cz   = pos.z + 1.2 + camDist * math.sin(radV)
    SetCamCoord(dealerCam, cx, cy, cz)
    PointCamAtCoord(dealerCam, pos.x, pos.y, pos.z + 0.8)
end

---@param controllerState SKControllerFriendlyPollResult
local function applyDealershipControllerCameraInput(controllerState)
    if math.abs(controllerState.lookX) >= dealershipControllerTracker.analogDeadzone then
        camAngleH = (camAngleH + controllerState.lookX * CAMERA_ROTATE_SPEED) % 360
    end
    if math.abs(controllerState.lookY) >= dealershipControllerTracker.analogDeadzone then
        camAngleV = math.max(-20.0, math.min(40.0, camAngleV + controllerState.lookY * CAMERA_ROTATE_SPEED))
    end

    local zoomDelta = (controllerState.triggerLeft - controllerState.triggerRight) * CAMERA_ZOOM_SPEED
    if math.abs(zoomDelta) >= 0.001 then
        camDist = math.max(CAM_DIST_MIN, math.min(CAM_DIST_MAX, camDist + zoomDelta))
    end
end

---@param enabled boolean
local function setDealershipControllerModeEnabled(enabled)
    if dealershipControllerModeEnabled == enabled then return end
    dealershipControllerModeEnabled = enabled
    SendNUIMessage({
        type = 'dealership:controllerMode',
        enabled = enabled,
    })
end

---@param modelName string
---@param coords vector3
---@param heading number
---@return integer
local function spawnDisplayVehicle(modelName, coords, heading)
    local model = SK.LoadModel(modelName)
    if not model then return 0 end
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, heading, false, false)
    SetVehicleModKit(veh, 0)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleRadioEnabled(veh, false)
    SetVehRadioStation(veh, 'OFF')
    return veh
end

---@param visualOptionCount integer
---@return integer
local function getCustomizabilityStars(visualOptionCount)
    if visualOptionCount >= 150 then
        return 5
    end
    if visualOptionCount >= 120 then
        return 4
    end
    if visualOptionCount >= 80 then
        return 3
    end
    if visualOptionCount >= 50 then
        return 2
    end
    return 1
end

---@param modelName string
---@param coords vector3
---@param heading number
---@return integer
local function getVehicleCustomizability(modelName, coords, heading)
    if customizabilityByModel[modelName] then return customizabilityByModel[modelName] end

    local vehicle = spawnDisplayVehicle(modelName, coords, heading)
    local visualOptionCount = 0

    for modType = 0, 49 do
        if SKShopShared.isVisualModType(modType) then
            local optionCount = SKShopShared.getVehicleModOptionCount(vehicle, modType)
            if optionCount > 0 then
                visualOptionCount = visualOptionCount + optionCount
            end
        end
    end

    DeleteEntity(vehicle)
    SK.UnloadModel(modelName)

    local stars = getCustomizabilityStars(visualOptionCount)
    customizabilityByModel[modelName] = stars
    return stars
end

---@param models string[]
---@return table
local function getVehicleStudioImages(models)
    local cfg = SKVehicleImageConfig or {}
    if cfg.provider ~= 'jg' then return {} end
    if GetResourceState('jg-vehiclestudio') ~= 'started' then return {} end

    local ok, images = pcall(function()
        return exports['jg-vehiclestudio']:getImages(models, cfg.jgImageId or 'default')
    end)

    if not ok or type(images) ~= 'table' then
        return {}
    end

    return images
end

---@param dealerType string
---@param displayCoords vector3
---@param displayHeading number
---@return SKDealershipVehicleEntry[]
local function getSortedVehicles(dealerType, displayCoords, displayHeading)
    local all = assert(SKGameVehicles[dealerType], ('streetkings: missing dealership vehicles for %s'):format(dealerType))
    local dealerConfig = assert(getDealerTypes()[dealerType], ('streetkings: missing dealership config for %s'):format(dealerType))
    local models = {}
    for _, v in ipairs(all) do
        models[#models + 1] = v.model
    end
    local vehicleStudioImages = getVehicleStudioImages(models)
    local sorted = {}
    for _, cls in ipairs(getClassOrder()) do
        for _, v in ipairs(all) do
            if v.class == cls then
                ---@type { name: string, brand: string }
                local sharedVehicle = assert(SKVehicles[v.model], ('streetkings: missing shared vehicle metadata for %s'):format(v.model))
                sorted[#sorted + 1] = {
                    model = v.model,
                    name = sharedVehicle.name,
                    brand = sharedVehicle.brand,
                    price = v.price,
                    class = v.class,
                    image = SKResolveVehicleImage(v.model, v.image, vehicleStudioImages[v.model]),
                    requiredVipTier = v.vipTier or dealerConfig.vipTier,
                    customizability = getVehicleCustomizability(v.model, displayCoords, displayHeading),
                }
            end
        end
    end
    return sorted
end

-- Public helpers ------------------------------------------------------------

---@param stateId string
---@return boolean
function SKDealership.isDealershipState(stateId)
    return stateId == GameState.DEALERSHIP
end

-- Enter dealership ----------------------------------------------------------

---@param location SKDealershipLocation
function SKDealership.enter(location)
    if SKPolice.hasWantedLevel() then
        SKPolice.notifyAccessBlockedByWantedLevel()
        return
    end

    local vehicle = SKFreeroam.getActiveVehicle()
    local vpos    = GetEntityCoords(vehicle)
    SKFreeroam.setReturnPosition(vector4(vpos.x, vpos.y, vpos.z, location.exitHeading))

    pendingLocation = location
    SendNUIMessage({ type = 'prompt:hide' })
    SKC.SetGameState(GameState.DEALERSHIP)
end

-- Game state ----------------------------------------------------------------

SKC.RegisterGameState(GameState.DEALERSHIP, {
    onEnter = function()
        CreateThread(function()
            DoScreenFadeOut(0)

            local location = assert(pendingLocation, 'streetkings: missing dealership location')
            local ped      = PlayerPedId()
            SetEntityCoords(ped, location.displayCoords.x, location.displayCoords.y, location.displayCoords.z, false, false, false, false)

            local vehicles = getSortedVehicles(location.dealerType, location.displayCoords, location.displayHeading)
            local first    = assert(vehicles[1], ('streetkings: no dealership vehicles for %s'):format(location.dealerType))

            dealerVehicle = spawnDisplayVehicle(first.model, location.displayCoords, location.displayHeading)

            TaskWarpPedIntoVehicle(ped, dealerVehicle, -1)
            while not IsPedInVehicle(ped, dealerVehicle, false) do Wait(0) end

            camDist = CAM_DIST_DEFAULT
            camAngleH = CAM_ANGLE_H_DEFAULT
            camAngleV = CAM_ANGLE_V_DEFAULT

            dealerCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            updateDealerCamera()
            SetCamActive(dealerCam, true)
            RenderScriptCams(true, false, 0, true, true)

            local dealershipState = lib.callback.await('streetkings:dealership:getState', false)

            local config  = assert(getDealerTypes()[location.dealerType], ('streetkings: missing dealership config for %s'):format(location.dealerType))

            SetEntityVisible(ped, false, false)
            DisplayHud(false)
            DisplayRadar(false)
            SKSpeedo.setEnabled(false)
            SKSoundtrack.setBlocked(true)
            SKControllerFriendly.resetTracker(dealershipControllerTracker)
            setDealershipControllerModeEnabled(false)

            SetNuiFocus(true, true)
            SendNUIMessage({
                type       = 'dealership:open',
                dealerType = location.dealerType,
                label      = config.label,
                vehicles   = vehicles,
                balance    = dealershipState.balance,
                playerLevel = dealershipState.playerLevel,
                playerVipTier = dealershipState.vipTier,
                ownedModels = dealershipState.ownedModels,
            })

            SetVehicleRadioEnabled(dealerVehicle, false)
            SetVehRadioStation(dealerVehicle, 'OFF')
            DoScreenFadeIn(500)
        end)
    end,

    onTick = function()
        DisableAllControlActions(0)
        DisableAllControlActions(1)
        DisableAllControlActions(2)

        local controllerState = SKControllerFriendly.poll(dealershipControllerTracker)
        setDealershipControllerModeEnabled(controllerState.controllerEnabled)

        if controllerState.controllerEnabled then
            applyDealershipControllerCameraInput(controllerState)

            for _, action in ipairs(controllerState.pressedActions) do
                SendNUIMessage({
                    type = 'dealership:controllerInput',
                    action = action,
                })
            end

        end

        updateDealerCamera()
    end,

    onExit = function()
        local ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        DisplayHud(true)
        DisplayRadar(true)
        SKSpeedo.setEnabled(true)
        SKSoundtrack.setBlocked(false)
        SKControllerFriendly.resetTracker(dealershipControllerTracker)
        setDealershipControllerModeEnabled(false)

        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'dealership:close' })

        if dealerCam then
            DestroyCam(dealerCam, false)
            dealerCam = nil
        end
        RenderScriptCams(false, false, 0, true, true)

        if dealerVehicle and DoesEntityExist(dealerVehicle) then
            FreezeEntityPosition(ped, true)
            DeleteEntity(dealerVehicle)
            dealerVehicle = nil
        end

        pendingLocation = nil
    end,

    tickWait = 0,
})

-- Discovery & points setup --------------------------------------------------

---@param location SKDealershipLocation
local function setupLocationPoints(location)
    local discovered = isDiscovered(location.id)
    local wpId = SKWaypoint.Create({
        coords       = location.coords,
        text         = discovered and location.name or '???',
        color        = discovered and '#ffd200' or '#888888',
        icon         = discovered and 'car' or 'question',
        showDist     = true,
        groundBeam   = true,
        maxRender    = 250.0,
        interactable = discovered,
    })
    dealershipWaypoints[#dealershipWaypoints + 1] = wpId

    local discoveryPoint = lib.points.new({
        coords   = location.coords,
        distance = 40.0,

        onEnter = function()
            if not isDiscovered(location.id) then
                discoveredDealers[#discoveredDealers + 1] = location.id
                blips[location.id] = addBlip(location)
                SKWaypoint.Update(wpId, {
                    text = location.name,
                    color = '#ffd200',
                    icon = 'car',
                    interactable = true,
                })
                lib.callback.await('streetkings:dealership:discover', false, location.id)
                SKNotify({ type = 'success', title = location.name .. ' Discovered!' })
            end
        end,
    })

    local promptKey = nil
    local innerPoint = lib.points.new({
        coords   = location.coords,
        distance = 5.0,

        onEnter = function()
            promptKey = SKInput.getInteractLabel()
            SendNUIMessage({ type = 'prompt:show', key = promptKey, text = 'Enter ' .. location.name })
        end,

        onExit = function()
            promptKey = nil
            SendNUIMessage({ type = 'prompt:hide' })
        end,

        nearby = function()
            local nextPromptKey = SKInput.getInteractLabel()
            if nextPromptKey ~= promptKey then
                promptKey = nextPromptKey
                SendNUIMessage({ type = 'prompt:show', key = promptKey, text = 'Enter ' .. location.name })
            end
            if SKInput.isInteractJustReleased() then
                SKDealership.enter(location)
            end
        end,
    })

    activePoints[#activePoints + 1] = discoveryPoint
    activePoints[#activePoints + 1] = innerPoint
end

-- Freeroam lifecycle --------------------------------------------------------

AddEventHandler('streetkings:dealership:freeroamEnter', function()
    for _, point in ipairs(activePoints) do point:remove() end
    activePoints = {}
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    blips = {}

    discoveredDealers = lib.callback.await('streetkings:dealership:loadDiscovered', false)

    for _, location in ipairs(getDealershipLocations()) do
        if isDiscovered(location.id) then
            blips[location.id] = addBlip(location)
        end
        setupLocationPoints(location)
    end
end)

AddEventHandler('streetkings:dealership:freeroamExit', function()
    for _, point in ipairs(activePoints) do
        point:remove()
    end
    activePoints = {}

    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}

    for _, wpId in ipairs(dealershipWaypoints) do
        SKWaypoint.Remove(wpId)
    end
    dealershipWaypoints = {}

    SendNUIMessage({ type = 'prompt:hide' })
end)

-- NUI callbacks -------------------------------------------------------------

RegisterNUICallback('dealership:cameraRotate', function(data, cb)
    camAngleH = (camAngleH - data.dx * 0.3) % 360
    camAngleV = math.max(-20.0, math.min(40.0, camAngleV + data.dy * 0.3))
    cb({})
end)

RegisterNUICallback('dealership:previewVehicle', function(data, cb)
    if not dealerVehicle or not DoesEntityExist(dealerVehicle) then cb({}); return end

    local location = assert(pendingLocation, 'streetkings: missing dealership preview location')
    local ped      = PlayerPedId()

    CreateThread(function()
        FreezeEntityPosition(ped, true)
        DeleteEntity(dealerVehicle)

        dealerVehicle = spawnDisplayVehicle(data.model, location.displayCoords, location.displayHeading)
        TaskWarpPedIntoVehicle(ped, dealerVehicle, -1)
        while not IsPedInVehicle(ped, dealerVehicle, false) do Wait(0) end
        FreezeEntityPosition(ped, false)
    end)

    cb({})
end)

RegisterNUICallback('dealership:purchase', function(data, cb)
    local result = lib.callback.await('streetkings:dealership:purchase', false, data.model, data.name, data.price)
    cb(result)
end)

RegisterNUICallback('dealership:exit', function(_, cb)
    cb({})
    SKC.SetGameState(GameState.FREEROAM)
end)
