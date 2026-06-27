SKGarage = {}

---@return table
local function getGarageInteriors()
    return assert(SKGarageConfig and SKGarageConfig.INTERIORS, 'streetkings: missing garage interiors config')
end

---@return table
local function getGarageLocations()
    return assert(SKGarageConfig and SKGarageConfig.LOCATIONS, 'streetkings: missing garage locations config')
end

-- Display config ------------------------------------------------------------

local CAM_DIST_DEFAULT    = 3.75
local CAM_DIST_MIN        = 2.0
local CAM_DIST_MAX        = 5.25
local CAM_ANGLE_H_DEFAULT = 160.0
local CAM_ANGLE_V_DEFAULT = 12.0
local CAMERA_ROTATE_SPEED = 2.5
local CAMERA_ZOOM_SPEED   = 0.08
local GARAGE_BLIP_CATEGORY = 18
local garageBlipCategoryRegistered = false
local GARAGE_TINT_KEY_BY_NAME = {
    gray = 1,
    red = 2,
    blue = 3,
    orange = 4,
    yellow = 5,
    green = 6,
    pink = 7,
    teal = 8,
    darkGray = 9,
}
local DEFAULT_GARAGE_TINT = 'gray'

-- State ---------------------------------------------------------------------

local activePoints      = {}
local discoveredGarages = {}
local blips             = {}
local garageWaypoints   = {}

local pendingGarage = nil
local garageCam     = nil
local garageVehicle = nil
local camDist       = CAM_DIST_DEFAULT
local camAngleH     = CAM_ANGLE_H_DEFAULT
local camAngleV     = CAM_ANGLE_V_DEFAULT
local currentGarageTint = DEFAULT_GARAGE_TINT
local garageControllerModeEnabled = false
local garageControllerTracker = SKControllerFriendly.newTracker()

-- Helpers -------------------------------------------------------------------

---@param garageId string
---@return boolean
local function isDiscovered(garageId)
    for _, id in ipairs(discoveredGarages) do
        if id == garageId then return true end
    end
    return false
end

---@param garageId string
---@return table|nil
local function getLocationById(garageId)
    for _, location in ipairs(getGarageLocations()) do
        if location.id == garageId then
            return location
        end
    end
end

---@param location table
---@return table
local function getGarageInterior(location)
    local interior = getGarageInteriors()[location.interiorId]
    assert(interior, ('streetkings: missing garage interior config for %s'):format(location.interiorId))
    return interior
end

local function registerGarageBlipCategory()
    if garageBlipCategoryRegistered then return end
    garageBlipCategoryRegistered = true
    AddTextEntry(('BLIP_CAT_%d'):format(GARAGE_BLIP_CATEGORY), 'Garages')
end

---@param location table
---@return integer
local function addWaypoint(location)
    return SKWaypoint.Create({
        coords       = location.coords,
        text         = location.name,
        color        = '#3ab4ff',
        icon         = 'warehouse',
        showDist     = true,
        groundBeam   = true,
        maxRender    = 250.0,
        interactable = true,
    })
end

---@param location table
---@return integer
local function addBlip(location)
    registerGarageBlipCategory()
    local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
    SetBlipSprite(blip, 813)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    SetBlipCategory(blip, GARAGE_BLIP_CATEGORY)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(location.name)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function updateGarageCamera()
    if not garageCam or not garageVehicle or not DoesEntityExist(garageVehicle) then return end
    local pos  = GetEntityCoords(garageVehicle)
    local radH = math.rad(camAngleH)
    local radV = math.rad(camAngleV)
    local cx   = pos.x + camDist * math.cos(radV) * math.sin(radH)
    local cy   = pos.y - camDist * math.cos(radV) * math.cos(radH)
    local cz   = pos.z + 1.2 + camDist * math.sin(radV)
    SetCamCoord(garageCam, cx, cy, cz)
    PointCamAtCoord(garageCam, pos.x, pos.y, pos.z + 0.3)
end

---@param tintKey string
---@param refresh boolean
local function applyGarageTint(tintKey, refresh)
    local tintIndex = assert(GARAGE_TINT_KEY_BY_NAME[tintKey], ('streetkings: invalid garage tint %s'):format(tintKey))
    exports.bob74_ipl:GetChopShopSalvageObject().Tint.SetColor(tintIndex, refresh)
    currentGarageTint = tintKey
end

---@param controllerState SKControllerFriendlyPollResult
local function applyGarageControllerCameraInput(controllerState)
    if math.abs(controllerState.lookX) >= garageControllerTracker.analogDeadzone then
        camAngleH = (camAngleH + controllerState.lookX * CAMERA_ROTATE_SPEED) % 360
    end
    if math.abs(controllerState.lookY) >= garageControllerTracker.analogDeadzone then
        camAngleV = math.max(-20.0, math.min(40.0, camAngleV - controllerState.lookY * CAMERA_ROTATE_SPEED))
    end

    local zoomDelta = (controllerState.triggerLeft - controllerState.triggerRight) * CAMERA_ZOOM_SPEED
    if math.abs(zoomDelta) >= 0.001 then
        camDist = math.max(CAM_DIST_MIN, math.min(CAM_DIST_MAX, camDist + zoomDelta))
    end
end

---@param nextEnabled boolean
local function setGarageControllerModeEnabled(nextEnabled)
    nextEnabled = nextEnabled == true
    if garageControllerModeEnabled == nextEnabled then
        return
    end

    garageControllerModeEnabled = nextEnabled
    SendNUIMessage({
        type = 'garage:controllerMode',
        enabled = nextEnabled,
    })
end

---@param vehicle integer
---@param vehicleData table
local function applyVehicleData(vehicle, vehicleData)
    SetVehicleModKit(vehicle, 0)
    local mods   = vehicleData.mods or {}
    local colors = vehicleData.colors or {}
    for modType, modIndex in pairs(mods) do
        local numericModType = tonumber(modType)
        if not SKShopShared.isExcludedModType(numericModType) then
            SKShopShared.applyVehicleMod(vehicle, numericModType, modIndex)
        end
    end
    SKShop.applyVehicleColor(vehicle, 'primary', colors.primary)
    SKShop.applyVehicleColor(vehicle, 'secondary', colors.secondary)
    SKShop.applyVehicleNeons(vehicle, vehicleData.neons)
end

---@param modelName string
---@param spawn vector4
---@param vehicleData table
---@param plate string
---@return integer
local function spawnDisplayVehicle(modelName, spawn, vehicleData, plate)
    local model = SK.LoadModel(modelName)
    if not model then return 0 end
    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, false, false)
    SetEntityCoordsNoOffset(veh, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(veh, spawn.w)
    applyVehicleData(veh, vehicleData)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDirtLevel(veh, 0.0)
    return veh
end

---@param ped integer
---@param vehicle integer
local function putPedInGarageVehicle(ped, vehicle)
    SetPedIntoVehicle(ped, vehicle, -1)

    local deadline = GetGameTimer() + 1000
    while not IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do
        Wait(0)
    end

    assert(IsPedInVehicle(ped, vehicle, false), 'streetkings: failed to place ped in garage vehicle')
end

-- Public helpers ------------------------------------------------------------

---@param stateId string
---@return boolean
function SKGarage.isGarageState(stateId)
    return stateId == GameState.GARAGE
end

---@param location table
---@param recordVisit boolean|nil
local function enterGarage(location, recordVisit)
    if SKPolice.hasWantedLevel() then
        SKPolice.notifyAccessBlockedByWantedLevel()
        return
    end

    local ec = location.exitCoords
    SKFreeroam.setReturnPosition(vector4(ec.x, ec.y, ec.z, location.exitHeading))

    if recordVisit ~= false then
        lib.callback.await('streetkings:garage:recordVisit', false, location.id)
        if not isDiscovered(location.id) then
            discoveredGarages[#discoveredGarages + 1] = location.id
        end
    end

    pendingGarage = location
    SendNUIMessage({ type = 'prompt:hide' })
    SKC.SetGameState(GameState.GARAGE)
end

---@param location table
function SKGarage.enter(location)
    enterGarage(location, true)
end

---@param garageId string
---@return table|nil
function SKGarage.getLocationById(garageId)
    return getLocationById(garageId)
end

---@return string
function SKGarage.getDefaultId()
    local locations = getGarageLocations()
    for _, location in ipairs(locations) do
        if location.autoDefault then
            return location.id
        end
    end
    return locations[1].id
end

---@param garageId string
---@param recordVisit boolean|nil
---@return boolean
function SKGarage.enterById(garageId, recordVisit)
    local location = getLocationById(garageId)
    if not location then
        return false
    end

    enterGarage(location, recordVisit)
    return true
end

function SKGarage.enterFromMenu()
    local data    = lib.callback.await('streetkings:garage:getEnterData', false)
    local garage  = nil
    local locations = getGarageLocations()

    if data.lastGarageId then
        garage = getLocationById(data.lastGarageId)
    end

    if not garage then
        garage = locations[1]
    end

    garage = assert(garage, 'streetkings: missing default garage location')
    local ec = garage.exitCoords
    SKFreeroam.setReturnPosition(vector4(ec.x, ec.y, ec.z, garage.exitHeading))
    pendingGarage = garage
    SKC.SetGameState(GameState.GARAGE)
end

-- Game state ----------------------------------------------------------------

SKC.RegisterGameState(GameState.GARAGE, {
    onEnter = function()
        CreateThread(function()
            DoScreenFadeOut(0)

            local garage = pendingGarage
            local interior = getGarageInterior(garage)
            local spawn = interior.displaySpawn
            local ped    = PlayerPedId()
            SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
            SetEntityHeading(ped, spawn.w)

            local data          = lib.callback.await('streetkings:garage:getEnterData', false)
            local activeEntry   = data.vehicles[data.activeVehicleId]
            if not activeEntry then
                DoScreenFadeIn(0)
                SKC.SetGameState(GameState.MAIN_MENU)
                return
            end

            applyGarageTint(data.garageTint or DEFAULT_GARAGE_TINT, true)
            garageVehicle = spawnDisplayVehicle(
                activeEntry.modelName,
                spawn,
                activeEntry.data,
                activeEntry.plate
            )

            putPedInGarageVehicle(ped, garageVehicle)

            camDist = CAM_DIST_DEFAULT
            camAngleH = CAM_ANGLE_H_DEFAULT
            camAngleV = CAM_ANGLE_V_DEFAULT

            garageCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            updateGarageCamera()
            SetCamActive(garageCam, true)
            RenderScriptCams(true, false, 0, true, true)

            DisplayHud(false)
            DisplayRadar(false)
            SKSpeedo.setEnabled(false)
            SKControllerFriendly.resetTracker(garageControllerTracker)
            setGarageControllerModeEnabled(false)

            SetNuiFocus(true, true)
            SendNUIMessage({
                type            = 'garage:open',
                vehicles        = data.vehicles,
                activeVehicleId = data.activeVehicleId,
                balance         = data.balance,
                garageTint      = currentGarageTint,
                playerLevel = data.playerLevel,
                playerXp = data.playerXp,
                playerCurrentLevelXp = data.playerCurrentLevelXp,
                playerNextLevelXp = data.playerNextLevelXp,
                playerMaxLevel = data.playerMaxLevel,
            })

            SetEntityVisible(ped, false, false)
            DoScreenFadeIn(500)
        end)
    end,

    onTick = function()
        DisableAllControlActions(0)
        DisableAllControlActions(1)
        DisableAllControlActions(2)

        local controllerState = SKControllerFriendly.poll(garageControllerTracker)
        setGarageControllerModeEnabled(controllerState.controllerEnabled)

        if controllerState.controllerEnabled then
            applyGarageControllerCameraInput(controllerState)

            for _, action in ipairs(controllerState.pressedActions) do
                SendNUIMessage({
                    type = 'garage:controllerInput',
                    action = action,
                })
            end

        end

        updateGarageCamera()
    end,

    onExit = function()
        SetEntityVisible(PlayerPedId(), true, false)
        DisplayHud(true)
        DisplayRadar(true)
        SKSpeedo.setEnabled(true)
        SKControllerFriendly.resetTracker(garageControllerTracker)
        setGarageControllerModeEnabled(false)

        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'garage:close' })

        if garageCam then
            DestroyCam(garageCam, false)
            garageCam = nil
        end
        RenderScriptCams(false, false, 0, true, true)

        local ped = PlayerPedId()
        if garageVehicle and DoesEntityExist(garageVehicle) then
            FreezeEntityPosition(ped, true)
            DeleteEntity(garageVehicle)
            garageVehicle = nil
        end

        pendingGarage = nil
    end,

    tickWait = 0,
})

-- Freeroam lifecycle --------------------------------------------------------

AddEventHandler('streetkings:garage:freeroamEnter', function()
    for _, point in ipairs(activePoints) do point:remove() end
    activePoints = {}
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    blips = {}

    discoveredGarages = lib.callback.await('streetkings:garage:loadDiscovered', false)

    for _, location in ipairs(getGarageLocations()) do
        if location.autoDiscover then
            if not isDiscovered(location.id) then
                discoveredGarages[#discoveredGarages + 1] = location.id
            end
            if not blips[location.id] then
                blips[location.id] = addBlip(location)
            end
            if not garageWaypoints[location.id] then
                garageWaypoints[location.id] = addWaypoint(location)
            end
        elseif isDiscovered(location.id) then
            blips[location.id] = addBlip(location)
            garageWaypoints[location.id] = addWaypoint(location)
        else
            garageWaypoints[location.id] = SKWaypoint.Create({
                coords     = location.coords,
                text       = '???',
                color      = '#888888',
                icon       = 'question',
                showDist   = true,
                groundBeam = true,
                maxRender  = 250.0,
            })
        end

        local outerPoint = lib.points.new({
            coords   = location.coords,
            distance = 100.0,

            onEnter = function()
                if not isDiscovered(location.id) then
                    discoveredGarages[#discoveredGarages + 1] = location.id
                    blips[location.id] = addBlip(location)
                    if garageWaypoints[location.id] then
                        SKWaypoint.Update(garageWaypoints[location.id], {
                            text = location.name,
                            color = '#3ab4ff',
                            icon = 'warehouse',
                            interactable = true,
                        })
                    else
                        garageWaypoints[location.id] = addWaypoint(location)
                    end
                    lib.callback.await('streetkings:garage:recordVisit', false, location.id)
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
                    SKGarage.enter(location)
                end
            end,
        })

        activePoints[#activePoints + 1] = outerPoint
        activePoints[#activePoints + 1] = innerPoint
    end
end)

AddEventHandler('streetkings:garage:freeroamExit', function()
    for _, point in ipairs(activePoints) do
        point:remove()
    end
    activePoints = {}

    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}

    for _, wpId in pairs(garageWaypoints) do
        SKWaypoint.Remove(wpId)
    end
    garageWaypoints = {}

    SendNUIMessage({ type = 'prompt:hide' })
end)

-- NUI callbacks -------------------------------------------------------------

RegisterNUICallback('garage:cameraRotate', function(data, cb)
    camAngleH = (camAngleH - data.dx * 0.3) % 360
    camAngleV = math.max(-20.0, math.min(40.0, camAngleV + data.dy * 0.3))
    cb({})
end)

RegisterNUICallback('garage:cameraZoom', function(data, cb)
    local delta = type(data.delta) == 'number' and data.delta or 0
    camDist = math.max(CAM_DIST_MIN, math.min(CAM_DIST_MAX, camDist + delta))
    cb({})
end)

RegisterNUICallback('garage:skipTrack', function(_, cb)
    SKSoundtrack.SkipCurrentTrack()
    cb({})
end)

RegisterNUICallback('garage:previewVehicle', function(data, cb)
    if not garageVehicle or not DoesEntityExist(garageVehicle) then cb({}); return end

    local garage = pendingGarage
    local interior = getGarageInterior(garage)
    local spawn = interior.displaySpawn
    local ped    = PlayerPedId()

    CreateThread(function()
        local serverData = lib.callback.await('streetkings:garage:getEnterData', false)
        local entry      = serverData.vehicles[data.vehicleId]

        FreezeEntityPosition(ped, true)
        DeleteEntity(garageVehicle)

        garageVehicle = spawnDisplayVehicle(
            entry.modelName,
            spawn,
            entry.data,
            entry.plate
        )
        putPedInGarageVehicle(ped, garageVehicle)
        FreezeEntityPosition(ped, false)
    end)

    cb({})
end)

RegisterNUICallback('garage:setActiveVehicle', function(data, cb)
    local result = lib.callback.await('streetkings:garage:setActiveVehicle', false, data.vehicleId)
    cb(result)
    if not result.ok then return end

    local garage     = pendingGarage
    local interior   = getGarageInterior(garage)
    local spawn      = interior.displaySpawn
    local serverData = lib.callback.await('streetkings:garage:getEnterData', false)
    local entry      = serverData.vehicles[data.vehicleId]

    CreateThread(function()
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        DeleteEntity(garageVehicle)

        garageVehicle = spawnDisplayVehicle(
            entry.modelName,
            spawn,
            entry.data,
            entry.plate
        )
        putPedInGarageVehicle(ped, garageVehicle)
        FreezeEntityPosition(ped, false)
    end)
end)

RegisterNUICallback('garage:setTint', function(data, cb)
    local tintKey = data and data.tintKey
    if type(tintKey) ~= 'string' then
        cb({ ok = false })
        return
    end

    applyGarageTint(tintKey, true)
    cb(lib.callback.await('streetkings:garage:setTint', false, tintKey))
end)

RegisterNUICallback('phone:vehicles:getData', function(_, cb)
    cb(lib.callback.await('streetkings:garage:getPhoneOverview', false))
end)

RegisterNUICallback('garage:exit', function(_, cb)
    cb({})
    SKC.SetGameState(GameState.FREEROAM)
end)

RegisterNUICallback('garage:quitToMainMenu', function(_, cb)
    cb({})
    CreateThread(function()
        DoScreenFadeOut(500)
        Wait(500)
        SKC.SetGameState(GameState.MAIN_MENU)
    end)
end)
-- ce_skadmin bridge: refresca visualmente el garaje cuando un admin cambia XP/datos del vehículo.
RegisterNetEvent('streetkings:garage:adminRefresh', function(payload)
    if type(payload) ~= 'table' then return end
    if not SKC or not SKC.GetGameState or not GameState then return end
    if SKC.GetGameState() ~= GameState.GARAGE then return end
    payload.type = 'garage:adminRefresh'
    SendNUIMessage(payload)
end)
