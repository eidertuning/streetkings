SKShop = {}

---@return table
local function getShopTypes()
    return assert(SKShopShared and SKShopShared.TYPES, 'streetkings: missing shop types config')
end

---@return table
local function getShopLocations()
    return assert(SKShopShared and SKShopShared.LOCATIONS, 'streetkings: missing shop locations config')
end

local CAM_DIST_DEFAULT    = 5.25
local CAM_DIST_MIN        = 2.75
local CAM_DIST_MAX        = 8.5
local CAM_ANGLE_H_DEFAULT = 160.0
local CAM_ANGLE_V_DEFAULT = 12.0
local CAMERA_ROTATE_SPEED = 2.5
local CAMERA_ZOOM_SPEED   = 0.12

-- State ---------------------------------------------------------------------

local activePoints    = {}
local shopWaypoints   = {}
local discoveredShops = {}
local blips = {}

local pendingModel  = nil
local pendingMods   = {}
local pendingColors = {}
local pendingNeons  = nil
local pendingPlate  = ''
local currentLocation = nil
local shopVehicle   = nil
local shopCam      = nil
local camDist      = CAM_DIST_DEFAULT
local camAngleH    = CAM_ANGLE_H_DEFAULT
local camAngleV    = CAM_ANGLE_V_DEFAULT
local currentVehicleProgression = nil
local visualShopHoodOpen = nil
local installedMods = {}
local lastPreviewedModType = nil
local shopControllerModeEnabled = false
local shopControllerTracker = SKControllerFriendly.newTracker()

local NEON_SIDE_TO_INDEX = {
    left  = 0,
    right = 1,
    front = 2,
    back  = 3,
}

---@param vehicle integer
---@param slot 'primary'|'secondary'
---@param color table|nil
function SKShop.applyVehicleColor(vehicle, slot, color)
    if type(color) ~= 'table' then return end
    if slot ~= 'primary' and slot ~= 'secondary' then return end

    local paintType = type(color.paintType) == 'number' and math.floor(color.paintType) or nil
    if paintType ~= nil then
        if slot == 'primary' then
            local pearlescentColor = GetVehicleExtraColours(vehicle)
            SetVehicleModColor_1(vehicle, paintType, 0, pearlescentColor)
        else
            SetVehicleModColor_2(vehicle, paintType, 0)
        end
    end

    if slot == 'primary' then
        SetVehicleCustomPrimaryColour(vehicle, color.r, color.g, color.b)
    else
        SetVehicleCustomSecondaryColour(vehicle, color.r, color.g, color.b)
    end
end

-- Helpers -------------------------------------------------------------------

---@param shopId string
---@return boolean
local function isDiscovered(shopId)
    for _, id in ipairs(discoveredShops) do
        if id == shopId then return true end
    end
    return false
end

---@param location table
---@return integer
local function addBlip(location)
    local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
    SetBlipSprite(blip, location.shopType == 'visual' and 838 or 833)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(location.name)
    EndTextCommandSetBlipName(blip)
    return blip
end

---@param vehicle integer
---@param shopTypeKey string
---@param progressionData table|nil
---@return table
local function buildModList(vehicle, shopTypeKey, progressionData)
    local mods   = {}
    for modType = 0, 49 do
        if SKShopShared.isShopModType(shopTypeKey, modType) then
            local basePrice = SKShopShared.getModPrice(shopTypeKey, modType, 0)
            local count = SKShopShared.getVehicleModOptionCount(vehicle, modType)
            if count > 0 then
                local options = { { index = -1, key = SKProgression.getModOptionKey(modType, -1), name = 'Stock', locked = false } }
                for i = 0, count - 1 do
                    local name = SKProgression.MOD_TYPE_NAMES[modType]
                    if not SKShopShared.isToggleModType(modType) then
                        local labelKey = GetModTextLabel(vehicle, modType, i)
                        name = GetLabelText(labelKey)
                    end
                    if not name or name == 'NULL' or name == '' then
                        name = (SKProgression.MOD_TYPE_NAMES[modType] or 'Mod') .. ' ' .. (i + 1)
                    end
                    local key = SKProgression.getModOptionKey(modType, i)
                    local unlockLevel = progressionData and progressionData.unlockLevels[key] or nil
                    local packName = nil
                    if SKProgression.isWheelModType(modType) then
                        local packIndex = SKProgression.getWheelPackIndex(i + 1, count)
                        packName = SKProgression.getWheelPackName(packIndex)
                    end
                    options[#options + 1] = {
                        index = i,
                        key = key,
                        name = name,
                        price = SKShopShared.getModPrice(shopTypeKey, modType, i),
                        locked = unlockLevel ~= nil and not (progressionData and progressionData.unlocks[key]),
                        unlockLevel = unlockLevel,
                        packName = packName,
                    }
                end
                mods[#mods + 1] = {
                    modType = modType,
                    name    = SKProgression.MOD_TYPE_NAMES[modType] or ('Mod ' .. modType),
                    current = SKShopShared.getInstalledModIndex(vehicle, modType),
                    basePrice = basePrice,
                    options = options,
                }
            end
        end
    end

    if shopTypeKey == 'performance' then
        local performanceOrder = {
            [11] = 1,
            [18] = 2,
            [12] = 3,
            [13] = 4,
            [15] = 5,
        }

        table.sort(mods, function(a, b)
            local aOrder = performanceOrder[a.modType] or (100 + a.modType)
            local bOrder = performanceOrder[b.modType] or (100 + b.modType)
            return aOrder < bOrder
        end)
    end

    return mods
end

---@return string|nil
local function resolveActiveShopTypeKey()
    return SKShopShared.getShopTypeByState(SKC.GetGameState())
end

local function updateShopCamera()
    if not shopCam or not shopVehicle or not DoesEntityExist(shopVehicle) then return end
    local pos  = GetEntityCoords(shopVehicle)
    local radH = math.rad(camAngleH)
    local radV = math.rad(camAngleV)
    local cx   = pos.x + camDist * math.cos(radV) * math.sin(radH)
    local cy   = pos.y - camDist * math.cos(radV) * math.cos(radH)
    local cz   = pos.z + 1.2 + camDist * math.sin(radV)
    SetCamCoord(shopCam, cx, cy, cz)
    PointCamAtCoord(shopCam, pos.x, pos.y, pos.z + 0.8)
end

---@param controllerState SKControllerFriendlyPollResult
local function applyShopControllerCameraInput(controllerState)
    if math.abs(controllerState.lookX) >= shopControllerTracker.analogDeadzone then
        camAngleH = (camAngleH + controllerState.lookX * CAMERA_ROTATE_SPEED) % 360
    end
    if math.abs(controllerState.lookY) >= shopControllerTracker.analogDeadzone then
        camAngleV = math.max(-20.0, math.min(40.0, camAngleV - controllerState.lookY * CAMERA_ROTATE_SPEED))
    end

    local zoomDelta = (controllerState.triggerLeft - controllerState.triggerRight) * CAMERA_ZOOM_SPEED
    if math.abs(zoomDelta) >= 0.001 then
        camDist = math.max(CAM_DIST_MIN, math.min(CAM_DIST_MAX, camDist + zoomDelta))
    end
end

---@param namespace string
---@param nextEnabled boolean
local function setShopControllerModeEnabled(namespace, nextEnabled)
    nextEnabled = nextEnabled == true
    if shopControllerModeEnabled == nextEnabled then
        return
    end

    shopControllerModeEnabled = nextEnabled
    SendNUIMessage({
        type = namespace .. ':controllerMode',
        enabled = nextEnabled,
    })
end

---@param modType integer
---@param modIndex integer
---@return boolean
local function isOptionUnlocked(modType, modIndex)
    if modIndex < 0 then
        return true
    end
    if not currentVehicleProgression then
        return false
    end

    local key = SKProgression.getModOptionKey(modType, modIndex)
    return currentVehicleProgression.unlocks[key] == true
end

---@param modType integer|nil
---@return boolean
local function shouldOpenVisualShopHood(modType)
    return modType == 39 or modType == 40 or modType == 41
end

---@param modType integer|nil
local function updateVisualShopPanels(modType)
    if not shopVehicle or not DoesEntityExist(shopVehicle) then
        return
    end

    local shouldOpenHood = shouldOpenVisualShopHood(modType)
    if visualShopHoodOpen == shouldOpenHood then
        return
    end

    visualShopHoodOpen = shouldOpenHood

    if shouldOpenHood then
        SetVehicleDoorOpen(shopVehicle, 4, false, false)
    else
        SetVehicleDoorShut(shopVehicle, 4, false)
    end
end

-- Public helpers ------------------------------------------------------------

---@param stateId string
---@return boolean
function SKShop.isShopState(stateId)
    for _, cfg in pairs(getShopTypes()) do
        if cfg.gameState == stateId then return true end
    end
    return false
end

---@param vehicle integer
---@param neons table|nil
function SKShop.applyVehicleNeons(vehicle, neons)
    if not neons or neons.enabled ~= true then
        for _, index in pairs(NEON_SIDE_TO_INDEX) do
            SetVehicleNeonLightEnabled(vehicle, index, false)
        end
        return
    end

    SetVehicleNeonLightsColour(vehicle, neons.color.r, neons.color.g, neons.color.b)
    for side, index in pairs(NEON_SIDE_TO_INDEX) do
        SetVehicleNeonLightEnabled(vehicle, index, neons.sides[side])
    end
end

-- Game state factory --------------------------------------------------------

---@param shopTypeKey string
function SKShop.registerShopState(shopTypeKey)
    local config = assert(SKShopShared.getShopType(shopTypeKey), 'Missing shop config: ' .. shopTypeKey)
    SKC.RegisterGameState(config.gameState, {
        onEnter = function()
            CreateThread(function()
                DoScreenFadeOut(0)

                local ped = PlayerPedId()
                local location = assert(currentLocation, 'Missing shop location for ' .. shopTypeKey)
                local display = location.display
                SetEntityCoords(ped, display.x, display.y, display.z, false, false, false, false)

                local model = SK.LoadModel(pendingModel --[[@as string|number]])
                if not model then return end

                shopVehicle = CreateVehicle(model, display.x, display.y, display.z, display.w, false, false)
                SetVehicleModKit(shopVehicle, 0)
                visualShopHoodOpen = nil

                installedMods = {}
                lastPreviewedModType = nil
                for modType, modIndex in pairs(pendingMods) do
                    if not SKShopShared.isExcludedModType(modType) then
                        SKShopShared.applyVehicleMod(shopVehicle, modType, modIndex)
                        installedMods[modType] = modIndex
                    end
                end

                SKShop.applyVehicleColor(shopVehicle, 'primary', pendingColors.primary)
                SKShop.applyVehicleColor(shopVehicle, 'secondary', pendingColors.secondary)
                SKShop.applyVehicleNeons(shopVehicle, pendingNeons)

                SetVehicleNumberPlateText(shopVehicle, pendingPlate)
                SetVehicleDirtLevel(shopVehicle, 0.0)
                WashDecalsFromVehicle(shopVehicle, 1.0)

                TaskWarpPedIntoVehicle(ped, shopVehicle, -1)
                while not IsPedInVehicle(ped, shopVehicle, false) do Wait(0) end

                camDist = CAM_DIST_DEFAULT
                camAngleH = CAM_ANGLE_H_DEFAULT
                camAngleV = CAM_ANGLE_V_DEFAULT

                shopCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                updateShopCamera()
                SetCamActive(shopCam, true)
                RenderScriptCams(true, false, 0, true, true)

                local balance     = lib.callback.await('streetkings:shop:getBalance', false)
                currentVehicleProgression = lib.callback.await(
                    'streetkings:progression:syncActiveVehicleMods',
                    false,
                    SKProgression.collectVehicleAvailability(shopVehicle)
                )
                currentVehicleProgression = currentVehicleProgression and currentVehicleProgression.vehicle or nil
                local mods = buildModList(shopVehicle, shopTypeKey, currentVehicleProgression)

                if shopTypeKey == 'performance' then -- These two aren't base game mods, they're custom scripted mods.
                    -- So they need to be injected manually into the performance shop mods list.
                    local gearboxType  = lib.callback.await('streetkings:shop:getActiveVehicleGearbox', false)
                    local gearboxIndex = ({ beginner = 0, expert = 1 })[gearboxType] or -1
                    local nitrousType  = lib.callback.await('streetkings:shop:getActiveVehicleNitrous', false)
                    local nitrousIndex = ({ street = 0, sport = 1, race = 2 })[nitrousType] or -1
                    local nitrousUnlockKeys = {
                        street = SKProgression.getModOptionKey(SKShopShared.NITROUS_UNLOCK_MOD_TYPE, SKShopShared.NITROUS_UNLOCKS.street.index),
                        sport = SKProgression.getModOptionKey(SKShopShared.NITROUS_UNLOCK_MOD_TYPE, SKShopShared.NITROUS_UNLOCKS.sport.index),
                        race = SKProgression.getModOptionKey(SKShopShared.NITROUS_UNLOCK_MOD_TYPE, SKShopShared.NITROUS_UNLOCKS.race.index),
                    }
                    local nitrousUnlockLevels = {
                        street = currentVehicleProgression and currentVehicleProgression.unlockLevels[nitrousUnlockKeys.street] or nil,
                        sport = currentVehicleProgression and currentVehicleProgression.unlockLevels[nitrousUnlockKeys.sport] or nil,
                        race = currentVehicleProgression and currentVehicleProgression.unlockLevels[nitrousUnlockKeys.race] or nil,
                    }
                    local nitrousLocked = {
                        street = nitrousUnlockLevels.street ~= nil and not (currentVehicleProgression and currentVehicleProgression.unlocks[nitrousUnlockKeys.street]),
                        sport = nitrousUnlockLevels.sport ~= nil and not (currentVehicleProgression and currentVehicleProgression.unlocks[nitrousUnlockKeys.sport]),
                        race = nitrousUnlockLevels.race ~= nil and not (currentVehicleProgression and currentVehicleProgression.unlocks[nitrousUnlockKeys.race]),
                    }
                    table.insert(mods, {
                        modType   = 'gearbox',
                        name      = 'Gearbox',
                        current   = gearboxIndex,
                        isGearbox = true,
                        basePrice = SKShopShared.GEARBOX_PRICES.beginner,
                        options   = {
                            { index = -1, key = 'gearbox:none',     name = 'Stock (Automatic)', price = 0,                                    locked = false },
                            { index = 0,  key = 'gearbox:beginner', name = 'Beginner Manual',   price = SKShopShared.GEARBOX_PRICES.beginner,  locked = false },
                            { index = 1,  key = 'gearbox:expert',   name = 'Expert Manual',     price = SKShopShared.GEARBOX_PRICES.expert,    locked = false },
                        },
                    })
                    table.insert(mods, {
                        modType   = 'nitrous',
                        name      = 'Nitrous',
                        current   = nitrousIndex,
                        isNitrous = true,
                        basePrice = SKShopShared.NITROUS_PRICES.street,
                        options   = {
                            { index = -1, key = 'nitrous:none',            name = 'No Nitrous',     price = 0,                                  locked = false },
                            { index = 0,  key = nitrousUnlockKeys.street,  name = 'Street Nitrous', price = SKShopShared.NITROUS_PRICES.street, locked = nitrousLocked.street, unlockLevel = nitrousUnlockLevels.street },
                            { index = 1,  key = nitrousUnlockKeys.sport,   name = 'Sport Nitrous',  price = SKShopShared.NITROUS_PRICES.sport,  locked = nitrousLocked.sport,  unlockLevel = nitrousUnlockLevels.sport },
                            { index = 2,  key = nitrousUnlockKeys.race,    name = 'Race Nitrous',   price = SKShopShared.NITROUS_PRICES.race,   locked = nitrousLocked.race,   unlockLevel = nitrousUnlockLevels.race },
                        },
                    })
                end
                if shopTypeKey == 'visual' then
                    local neons = lib.callback.await('streetkings:shop:getActiveVehicleNeons', false)
                    local neonUnlockKey = SKProgression.getModOptionKey(SKShopShared.NEON_UNLOCK_MOD_TYPE, SKShopShared.NEON_UNLOCK_MOD_INDEX)
                    local neonUnlockLevel = currentVehicleProgression and currentVehicleProgression.unlockLevels[neonUnlockKey] or nil
                    local neonLocked = neonUnlockLevel ~= nil and not (currentVehicleProgression and currentVehicleProgression.unlocks[neonUnlockKey])
                    table.insert(mods, {
                        modType   = 'neons',
                        name      = 'Neons',
                        current   = neons and 0 or -1,
                        isNeon    = true,
                        basePrice = SKShopShared.NEON_PRICE,
                        neons     = neons,
                        options   = {
                            { index = -1, key = 'neons:none', name = 'No Neons', locked = false, price = 0 },
                            { index = 0,  key = neonUnlockKey, name = 'Neon Kit', locked = neonLocked, unlockLevel = neonUnlockLevel, price = SKShopShared.NEON_PRICE },
                        },
                    })
                end

                local pr, pg, pb = GetVehicleCustomPrimaryColour(shopVehicle)
                local sr, sg, sb = GetVehicleCustomSecondaryColour(shopVehicle)
                local primaryPaintType = GetVehicleModColor_1(shopVehicle)
                local secondaryPaintType = GetVehicleModColor_2(shopVehicle)

                SetEntityVisible(ped, false, false)
                DisplayHud(false)
                DisplayRadar(false)
                SKSpeedo.setEnabled(false)
                SKSoundtrack.setBlocked(true)
                SKControllerFriendly.resetTracker(shopControllerTracker)
                setShopControllerModeEnabled(config.nui, false)

                SetNuiFocus(true, true)
                local payload = {
                    type = config.nui .. ':open',
                    shopType = shopTypeKey,
                    label = config.label,
                    mods = mods,
                    balance = balance,
                    vehicleLevel = currentVehicleProgression and currentVehicleProgression.level or 1,
                    vehicleProgression = currentVehicleProgression,
                }
                if config.allowsColors then
                    payload.colors = {
                        primary = { r = pr, g = pg, b = pb, paintType = primaryPaintType },
                        secondary = { r = sr, g = sg, b = sb, paintType = secondaryPaintType },
                    }
                    payload.neons = pendingNeons
                end
                SendNUIMessage(payload)

                SetVehicleRadioEnabled(shopVehicle, false)
                SetVehRadioStation(shopVehicle, 'OFF')
                DoScreenFadeIn(500)
            end)
        end,

        onTick = function()
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)

            local controllerState = SKControllerFriendly.poll(shopControllerTracker)
            setShopControllerModeEnabled(config.nui, controllerState.controllerEnabled)

            if controllerState.controllerEnabled then
                applyShopControllerCameraInput(controllerState)

                for _, action in ipairs(controllerState.pressedActions) do
                    SendNUIMessage({
                        type = config.nui .. ':controllerInput',
                        action = action,
                    })
                end

            end

            updateShopCamera()
        end,

        onExit = function()
            SetEntityVisible(PlayerPedId(), true, false)
            DisplayHud(true)
            DisplayRadar(true)
            SKSpeedo.setEnabled(true)
            SKSoundtrack.setBlocked(false)
            SKControllerFriendly.resetTracker(shopControllerTracker)
            setShopControllerModeEnabled(config.nui, false)

            SetNuiFocus(false, false)
            SendNUIMessage({ type = config.nui .. ':close' })

            if shopCam then
                DestroyCam(shopCam, false)
                shopCam = nil
            end
            RenderScriptCams(false, false, 0, true, true)

            local ped = PlayerPedId()
            if shopVehicle and DoesEntityExist(shopVehicle) then
                SetVehicleDoorShut(shopVehicle, 4, false)
                FreezeEntityPosition(ped, true)
                DeleteEntity(shopVehicle)
                shopVehicle = nil
            end

            pendingModel  = nil
            pendingMods   = {}
            pendingColors = {}
            pendingNeons  = nil
            pendingPlate  = ''
            currentLocation = nil
            currentVehicleProgression = nil
            visualShopHoodOpen = nil
            installedMods = {}
            lastPreviewedModType = nil
        end,

        tickWait = 0,
    })
end

-- Enter shop ----------------------------------------------------------------

---@param location table
function SKShop.enter(location)
    if SKPolice.hasWantedLevel() then
        SKPolice.notifyAccessBlockedByWantedLevel()
        return
    end

    local vehicle = SKFreeroam.getActiveVehicle() --[[@as integer]]
    local config  = assert(SKShopShared.getShopType(location.shopType), 'Missing shop config: ' .. location.shopType)
    local garageData = lib.callback.await('streetkings:garage:getEnterData', false)
    local activeEntry = assert(garageData.vehicles[garageData.activeVehicleId], 'Missing active vehicle entry')
    local vehicleData = activeEntry.data

    local vpos = GetEntityCoords(vehicle)
    SKFreeroam.setReturnPosition(vector4(vpos.x, vpos.y, vpos.z, location.exitHeading or GetEntityHeading(vehicle)))

    currentLocation = location
    pendingModel = GetHashKey(activeEntry.modelName)
    pendingPlate = activeEntry.plate
    pendingMods  = {}
    for modType, modIndex in pairs(vehicleData.mods) do
        local numericModType = assert(tonumber(modType), 'Invalid mod type key')
        if modIndex >= 0 and not SKShopShared.isExcludedModType(numericModType) then
            pendingMods[numericModType] = modIndex
        end
    end

    pendingColors = {}
    if vehicleData.colors.primary then
        pendingColors.primary = {
            r = vehicleData.colors.primary.r,
            g = vehicleData.colors.primary.g,
            b = vehicleData.colors.primary.b,
            paintType = vehicleData.colors.primary.paintType,
        }
    end
    if vehicleData.colors.secondary then
        pendingColors.secondary = {
            r = vehicleData.colors.secondary.r,
            g = vehicleData.colors.secondary.g,
            b = vehicleData.colors.secondary.b,
            paintType = vehicleData.colors.secondary.paintType,
        }
    end
    pendingNeons = vehicleData.neons

    SendNUIMessage({ type = 'prompt:hide' })
    SKC.SetGameState(config.gameState)
end

-- Discovery & points setup --------------------------------------------------

---@param location table
local function setupLocationPoints(location)
    local discovered = isDiscovered(location.id)
    local icon  = location.shopType == 'visual' and 'spray-can' or 'gauge-high'
    local wpId = SKWaypoint.Create({
        coords       = location.coords,
        text         = discovered and location.name or '???',
        color        = discovered and '#ffd200' or '#888888',
        icon         = discovered and icon or 'question',
        showDist     = true,
        groundBeam   = true,
        maxRender    = 250.0,
        interactable = discovered,
    })
    shopWaypoints[#shopWaypoints + 1] = wpId

    local discoveryPoint = lib.points.new({
        coords   = location.coords,
        distance = 40.0,

        onEnter = function()
            if not isDiscovered(location.id) then
                discoveredShops[#discoveredShops + 1] = location.id
                blips[location.id] = addBlip(location)
                SKWaypoint.Update(wpId, {
                    text = location.name,
                    color = '#ffd200',
                    icon = icon,
                    interactable = true,
                })
                lib.callback.await('streetkings:shop:discover', false, location.id)
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

        nearby = function(self)
            local nextPromptKey = SKInput.getInteractLabel()
            if nextPromptKey ~= promptKey then
                promptKey = nextPromptKey
                SendNUIMessage({ type = 'prompt:show', key = promptKey, text = 'Enter ' .. location.name })
            end
            if SKInput.isInteractJustReleased() then
                SKShop.enter(location)
            end
        end,
    })

    activePoints[#activePoints + 1] = discoveryPoint
    activePoints[#activePoints + 1] = innerPoint
end

-- Freeroam lifecycle --------------------------------------------------------

AddEventHandler('streetkings:shop:freeroamEnter', function()
    for _, point in ipairs(activePoints) do point:remove() end
    activePoints = {}
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    blips = {}

    discoveredShops = lib.callback.await('streetkings:shop:loadDiscovered', false)

    for _, location in ipairs(getShopLocations()) do
        if isDiscovered(location.id) then
            blips[location.id] = addBlip(location)
        end
        setupLocationPoints(location)
    end
end)

AddEventHandler('streetkings:shop:freeroamExit', function()
    for _, point in ipairs(activePoints) do
        point:remove()
    end
    activePoints = {}

    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}

    for _, wpId in ipairs(shopWaypoints) do
        SKWaypoint.Remove(wpId)
    end
    shopWaypoints = {}

    SendNUIMessage({ type = 'prompt:hide' })
end)

-- NUI callbacks -------------------------------------------------------------

---@param namespace string
local function registerShopCallbacks(namespace)
    RegisterNUICallback(namespace .. ':cameraRotate', function(data, cb)
        camAngleH = (camAngleH - data.dx * 0.3) % 360
        camAngleV = math.max(-20.0, math.min(40.0, camAngleV + data.dy * 0.3))
        cb({})
    end)

    RegisterNUICallback(namespace .. ':cameraZoom', function(data, cb)
        local delta = type(data.delta) == 'number' and data.delta or 0
        camDist = math.max(CAM_DIST_MIN, math.min(CAM_DIST_MAX, camDist + delta))
        cb({})
    end)

    RegisterNUICallback(namespace .. ':previewMod', function(data, cb)
        local shopTypeKey = resolveActiveShopTypeKey()
        if not shopTypeKey then
            cb({ ok = false, reason = 'invalid_state' })
            return
        end
        if not SKShopShared.isShopModType(shopTypeKey, data.modType) then
            cb({ ok = false, reason = 'invalid_mod' })
            return
        end

        if shopVehicle and DoesEntityExist(shopVehicle) then
            if not isOptionUnlocked(data.modType, data.modIndex) then
                cb({ ok = false, reason = 'locked' })
                return
            end
            SKShopShared.applyVehicleMod(shopVehicle, data.modType, data.modIndex)
            lastPreviewedModType = data.modType
        end
        cb({ ok = true })
    end)

    RegisterNUICallback(namespace .. ':previewCategory', function(data, cb)
        local shopTypeKey = resolveActiveShopTypeKey()
        if not shopTypeKey then
            cb({ ok = false, reason = 'invalid_state' })
            return
        end

        local modType = data and data.modType
        if modType ~= nil and type(modType) ~= 'number' then
            cb({ ok = false, reason = 'invalid_mod' })
            return
        end

        if lastPreviewedModType ~= nil and shopVehicle and DoesEntityExist(shopVehicle) then
            SKShopShared.applyVehicleMod(shopVehicle, lastPreviewedModType, installedMods[lastPreviewedModType] or -1)
            lastPreviewedModType = nil
        end

        if shopTypeKey == 'visual' then
            updateVisualShopPanels(modType)
        end

        cb({ ok = true })
    end)

    RegisterNUICallback(namespace .. ':purchaseMod', function(data, cb)
        local shopTypeKey = resolveActiveShopTypeKey()
        if not shopTypeKey then
            cb({ ok = false, reason = 'invalid_state' })
            return
        end
        if not SKShopShared.isShopModType(shopTypeKey, data.modType) then
            cb({ ok = false, reason = 'invalid_mod' })
            return
        end

        if not isOptionUnlocked(data.modType, data.modIndex) then
            cb({ ok = false, reason = 'locked' })
            return
        end

        local result = lib.callback.await('streetkings:shop:purchaseMod', false, shopTypeKey, data.modType, data.modIndex)

        if result.ok and shopVehicle and DoesEntityExist(shopVehicle) then
            SKShopShared.applyVehicleMod(shopVehicle, data.modType, data.modIndex)
            installedMods[data.modType] = data.modIndex
            lastPreviewedModType = nil
            PlaySoundFrontend(-1, 'airwrench' .. math.random(1, 3), 'sk_soundset', true)
        end

        cb(result)
    end)

    RegisterNUICallback(namespace .. ':exit', function(_, cb)
        cb({})
        SKC.SetGameState(GameState.FREEROAM)
    end)
end

RegisterNUICallback('modshop:previewColor', function(data, cb)
    if shopVehicle and DoesEntityExist(shopVehicle) then
        SKShop.applyVehicleColor(shopVehicle, data.slot, data)
    end
    cb({})
end)

RegisterNUICallback('modshop:purchaseColor', function(data, cb)
    local result = lib.callback.await('streetkings:shop:purchaseColor', false, data.slot, data.r, data.g, data.b, data.paintType)
    if result.ok and shopVehicle and DoesEntityExist(shopVehicle) then
        SKShop.applyVehicleColor(shopVehicle, data.slot, result.color)
    end
    cb(result)
end)

RegisterNUICallback('modshop:previewNeons', function(data, cb)
    if shopVehicle and DoesEntityExist(shopVehicle) then
        SKShop.applyVehicleNeons(shopVehicle, data.neons)
    end
    cb({ ok = true })
end)

RegisterNUICallback('modshop:purchaseNeons', function(data, cb)
    local result = lib.callback.await('streetkings:shop:purchaseNeons', false, data.enabled == true)

    if result.ok and shopVehicle and DoesEntityExist(shopVehicle) then
        SKShop.applyVehicleNeons(shopVehicle, result.neons)
        pendingNeons = result.neons
        PlaySoundFrontend(-1, 'airwrench' .. math.random(1, 3), 'sk_soundset', true)
    end

    cb(result)
end)

RegisterNUICallback('modshop:updateNeons', function(data, cb)
    local result = lib.callback.await('streetkings:shop:updateNeons', false, data.color, data.sides)

    if result.ok and shopVehicle and DoesEntityExist(shopVehicle) then
        SKShop.applyVehicleNeons(shopVehicle, result.neons)
        pendingNeons = result.neons
        PlaySoundFrontend(-1, 'airwrench' .. math.random(1, 3), 'sk_soundset', true)
    end

    cb(result)
end)

local VALID_GEARBOX_TYPES_CLIENT = { none = true, beginner = true, expert = true }
local VALID_NITROUS_TYPES_CLIENT = { none = true, street = true, sport = true, race = true }

RegisterNUICallback('perfshop:purchaseGearbox', function(data, cb)
    if not VALID_GEARBOX_TYPES_CLIENT[data.type] then
        cb({ ok = false, reason = 'invalid_type' })
        return
    end

    local result = lib.callback.await('streetkings:shop:purchaseGearbox', false, data.type)

    if result.ok then
        PlaySoundFrontend(-1, 'airwrench' .. math.random(1, 3), 'sk_soundset', true)
    end

    cb(result)
end)

RegisterNUICallback('perfshop:purchaseNitrous', function(data, cb)
    if not VALID_NITROUS_TYPES_CLIENT[data.type] then
        cb({ ok = false, reason = 'invalid_type' })
        return
    end

    local result = lib.callback.await('streetkings:shop:purchaseNitrous', false, data.type)

    if result.ok then
        PlaySoundFrontend(-1, 'airwrench' .. math.random(1, 3), 'sk_soundset', true)
    end

    cb(result)
end)

-- Init ----------------------------------------------------------------------

registerShopCallbacks('modshop')
registerShopCallbacks('perfshop')
SKShop.registerShopState('visual')
SKShop.registerShopState('performance')