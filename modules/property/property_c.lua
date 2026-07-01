local activePoints = {}
local blips = {}
local ownedProperties = {}
local propertyWaypoints = {}
local promptKey = nil
local pendingProperty = nil
local activeProperty = nil
local activeInteriorId = nil
local exitPoint = nil
local wardrobePoint = nil
local wardrobeReturnEntry = nil
local PROPERTY_ENTRY_FADE_OUT_MS = 500
local PROPERTY_ENTRY_BLACKOUT_MS = 700
local PROPERTY_BLIP_CAT_OWNED = 19
local PROPERTY_BLIP_CAT_UNOWNED = 20
local propertyBlipCategoriesRegistered = false

---@param ownedPropertyIds string[]
local function setOwnedProperties(ownedPropertyIds)
    ownedProperties = {}

    for _, propertyId in ipairs(ownedPropertyIds) do
        ownedProperties[propertyId] = true
    end
end

---@param propertyId string
---@return boolean
local function isOwned(propertyId) return ownedProperties[propertyId] == true end

local function registerPropertyBlipCategories()
    if propertyBlipCategoriesRegistered then return end
    propertyBlipCategoriesRegistered = true
    AddTextEntry(('BLIP_CAT_%d'):format(PROPERTY_BLIP_CAT_OWNED), 'Owned Properties')
    AddTextEntry(('BLIP_CAT_%d'):format(PROPERTY_BLIP_CAT_UNOWNED), 'Unowned Properties')
end

---@param entry SKPropertyEntry
---@return integer
local function addBlip(entry)
    registerPropertyBlipCategories()
    local owned = isOwned(entry.id)
    local blip = AddBlipForCoord(entry.exterior.x, entry.exterior.y, entry.exterior.z)
    SetBlipSprite(blip, entry.category == 'office' and 475 or 40)
    SetBlipColour(blip, owned and entry.blipColorOwned or entry.blipColorAvailable)
    SetBlipScale(blip, 0.5)
    SetBlipAsShortRange(blip, false)
    SetBlipCategory(blip, owned and PROPERTY_BLIP_CAT_OWNED or PROPERTY_BLIP_CAT_UNOWNED)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(entry.mapLabel)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function clearBlips()
    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end

    blips = {}
end

local function refreshBlips()
    clearBlips()

    for _, entry in ipairs(SKProperty.getAll()) do
        blips[entry.id] = addBlip(entry)
    end
end

local function clearFreeroamPoints()
    for _, point in ipairs(activePoints) do
        point:remove()
    end

    activePoints = {}
    promptKey = nil
    SendNUIMessage({ type = 'prompt:hide' })

    for _, wpId in ipairs(propertyWaypoints) do
        SKWaypoint.Remove(wpId)
    end
    propertyWaypoints = {}
end

---@param propertyId string
local function openPropertyPhone(propertyId)
    local payload = {
        appId = 'RealEstate',
        appData = { propertyId = propertyId },
    }

    if SKPhone.isOpen() then
        SendNUIMessage({
            type = 'phone:focusApp',
            appId = payload.appId,
            appData = payload.appData,
        })
        return
    end

    SKPhone.open(payload)
end

---@param entry SKPropertyEntry
local function promptText(entry)
    if isOwned(entry.id) then
        return _L('lua.prompts.enter', { name = entry.name })
    end

    if SKPropertyInvite.hasInvite(entry.id) then
        local invite = SKPropertyInvite.getActiveInvite()
        if invite then
            return _L('lua.prompts.join_player', { name = invite.inviterName })
        end
    end

    return _L('lua.prompts.view_property', { name = entry.name })
end

---@param entry SKPropertyEntry
local function startPropertyEntry(entry)
    if SKPhone.isOpen() then
        SKPhone.close()
    end

    pendingProperty = entry
    SendNUIMessage({ type = 'prompt:hide' })
    SKC.SetGameState(GameState.PROPERTY)
end

---@param entry SKPropertyEntry
local function enterProperty(entry)
    local gs = SKC.GetGameState()
    if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then
        return
    end

    if not isOwned(entry.id) then
        if SKPropertyInvite.hasInvite(entry.id) then
            SKPropertyInvite.enterFromInvite(entry)
            return
        end

        openPropertyPhone(entry.id)
        return
    end

    startPropertyEntry(entry)
end

---@return boolean
function SKProperty.isPropertyState(stateId)
    return stateId == GameState.PROPERTY
end

---@param propertyId string
---@return boolean
function SKProperty.isOwned(propertyId)
    return isOwned(propertyId)
end

---@param propertyId string
---@return boolean
function SKProperty.enterById(propertyId)
    local entry = SKProperty.getById(propertyId)
    if not entry or not isOwned(propertyId) then
        return false
    end

    startPropertyEntry(entry)
    return true
end

---@param propertyId string
---@return boolean
function SKProperty.forceEnterById(propertyId)
    local entry = SKProperty.getById(propertyId)
    if not entry then
        return false
    end

    startPropertyEntry(entry)
    return true
end

local function createExitPoint()
    local entry = activeProperty
    if not entry then
        return
    end

    exitPoint = lib.points.new({
        coords = vector3(entry.interiorDoor.x, entry.interiorDoor.y, entry.interiorDoor.z),
        distance = SKProperty.INTERIOR_EXIT_DISTANCE,

        onEnter = function()
            promptKey = SKInput.getInteractLabel()
            SendNUIMessage({ type = 'prompt:show', key = promptKey, text = _L('lua.prompts.exit_property') })
        end,

        onExit = function()
            promptKey = nil
            SendNUIMessage({ type = 'prompt:hide' })
        end,

        nearby = function()
            DrawMarker(
                1,
                entry.interiorDoor.x, entry.interiorDoor.y, entry.interiorDoor.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                entry.interiorMarkerScale.x, entry.interiorMarkerScale.y, entry.interiorMarkerScale.z,
                70, 200, 120, 160,
                false, true, 2, false, nil, nil, false
            )

            local nextPromptKey = SKInput.getInteractLabel()
            if nextPromptKey ~= promptKey then
                promptKey = nextPromptKey
                SendNUIMessage({ type = 'prompt:show', key = promptKey, text = _L('lua.prompts.exit_property') })
            end

            if SKInput.isInteractJustReleased() then
                SKC.SetGameState(GameState.FREEROAM)
            end
        end,
    })
end

local WARDROBE_INTERACT_DISTANCE = 1.8

local function createWardrobePoint()
    local entry = activeProperty
    if not entry or not entry.wardrobe then
        return
    end

    local wPos = entry.wardrobe
    local wardrobePromptKey = nil

    wardrobePoint = lib.points.new({
        coords = vector3(wPos.x, wPos.y, wPos.z),
        distance = WARDROBE_INTERACT_DISTANCE,

        onEnter = function()
            wardrobePromptKey = SKInput.getInteractLabel()
            SendNUIMessage({ type = 'prompt:show', key = wardrobePromptKey, text = 'Open Wardrobe' })
        end,

        onExit = function()
            wardrobePromptKey = nil
            SendNUIMessage({ type = 'prompt:hide' })
        end,

        nearby = function()
            local nextPromptKey = SKInput.getInteractLabel()
            if nextPromptKey ~= wardrobePromptKey then
                wardrobePromptKey = nextPromptKey
                SendNUIMessage({ type = 'prompt:show', key = wardrobePromptKey, text = 'Open Wardrobe' })
            end

            if SKInput.isInteractJustReleased() then
                SendNUIMessage({ type = 'prompt:hide' })
                wardrobeReturnEntry = entry
                SKAvatar.enterFromWardrobe(wPos)
            end
        end,
    })
end

SKC.RegisterGameState(GameState.PROPERTY, {
    onEnter = function()
        CreateThread(function()
            local returning = wardrobeReturnEntry
            if returning then
                wardrobeReturnEntry = nil
                activeProperty = returning

                if returning.interiorIpl ~= '' then
                    RequestIpl(returning.interiorIpl)
                end

                local interiorId = GetInteriorAtCoords(returning.interiorDoor.x, returning.interiorDoor.y, returning.interiorDoor.z)
                if interiorId ~= 0 then
                    PinInteriorInMemory(interiorId)
                    LoadInterior(interiorId)
                    RefreshInterior(interiorId)
                    activeInteriorId = interiorId
                else
                    activeInteriorId = nil
                end

                local ped = PlayerPedId()
                local wPos = returning.wardrobe
                SetEntityCoordsNoOffset(ped, wPos.x, wPos.y, wPos.z, false, false, false)
                SetEntityHeading(ped, wPos.w)
                FreezeEntityPosition(ped, false)
                SetEntityInvincible(ped, true)

                DisplayHud(false)
                DisplayRadar(false)
                SKSpeedo.setEnabled(false)
                createExitPoint()
                createWardrobePoint()
                DoScreenFadeIn(500)
                return
            end

            local entry = pendingProperty
            if not entry then
                SKC.SetGameState(GameState.FREEROAM)
                return
            end

            DoScreenFadeOut(PROPERTY_ENTRY_FADE_OUT_MS)
            while not IsScreenFadedOut() do Wait(0) end
            SKFreeroam.deleteActiveVehicle()

            if entry.interiorIpl ~= '' then
                RequestIpl(entry.interiorIpl)
            end

            local interiorId = GetInteriorAtCoords(entry.interiorDoor.x, entry.interiorDoor.y, entry.interiorDoor.z)
            if interiorId ~= 0 then
                PinInteriorInMemory(interiorId)
                LoadInterior(interiorId)
                RefreshInterior(interiorId)
                activeInteriorId = interiorId
            else
                activeInteriorId = nil
            end

            Wait(PROPERTY_ENTRY_BLACKOUT_MS)

            local ped = PlayerPedId()
            local spawn = SKProperty.getInteriorSpawnPosition(entry)
            SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
            SetEntityHeading(ped, spawn.w)
            FreezeEntityPosition(ped, false)
            SetEntityInvincible(ped, true)

            activeProperty = entry
            pendingProperty = nil
            DisplayHud(false)
            DisplayRadar(false)
            SKSpeedo.setEnabled(false)
            createExitPoint()
            createWardrobePoint()
            DoScreenFadeIn(500)
        end)
    end,

    onExit = function(nextState)
        if exitPoint then
            exitPoint:remove()
            exitPoint = nil
        end

        if wardrobePoint then
            wardrobePoint:remove()
            wardrobePoint = nil
        end

        SendNUIMessage({ type = 'prompt:hide' })

        if nextState == GameState.AVATAR and wardrobeReturnEntry then
            activeProperty = nil
            return
        end

        DisplayHud(true)
        DisplayRadar(true)
        SetEntityInvincible(PlayerPedId(), false)

        if activeInteriorId then
            UnpinInterior(activeInteriorId)
            activeInteriorId = nil
        end

        if activeProperty and activeProperty.interiorIpl ~= '' then
            RemoveIpl(activeProperty.interiorIpl)
        end

        if nextState == GameState.FREEROAM and activeProperty then
            local returnPosition = SKProperty.getExteriorReturnPosition(activeProperty)
            SKFreeroam.setReturnPosition(returnPosition)
        end

        activeProperty = nil
    end,

    tickWait = 0,
})

AddEventHandler('streetkings:property:freeroamEnter', function()
    clearFreeroamPoints()
    clearBlips()

    local state = lib.callback.await('streetkings:property:getFreeroamState', false)
    setOwnedProperties(state.ownedPropertyIds)
    refreshBlips()

    for _, entry in ipairs(SKProperty.getAll()) do
        local wpId = SKWaypoint.Create({
            coords       = vector3(entry.exterior.x, entry.exterior.y, entry.exterior.z),
            text         = entry.name,
            color        = isOwned(entry.id) and '#00d474' or '#aaaaaa',
            icon         = 'house',
            showDist     = true,
            groundBeam   = true,
            maxRender    = 250.0,
            interactable = true,
        })
        propertyWaypoints[#propertyWaypoints + 1] = wpId

        local innerPoint = lib.points.new({
            coords = vector3(entry.exterior.x, entry.exterior.y, entry.exterior.z),
            distance = SKProperty.FREEROAM_INTERACT_DISTANCE,

            onEnter = function()
                promptKey = SKInput.getInteractLabel()
                SendNUIMessage({ type = 'prompt:show', key = promptKey, text = promptText(entry) })
            end,

            onExit = function()
                promptKey = nil
                SendNUIMessage({ type = 'prompt:hide' })
            end,

            nearby = function()
                local nextPromptKey = SKInput.getInteractLabel()
                if nextPromptKey ~= promptKey then
                    promptKey = nextPromptKey
                    SendNUIMessage({ type = 'prompt:show', key = promptKey, text = promptText(entry) })
                end

                if SKInput.isInteractJustReleased() then
                    enterProperty(entry)
                end
            end,
        })

        activePoints[#activePoints + 1] = innerPoint
    end
end)

AddEventHandler('streetkings:property:freeroamExit', function()
    clearFreeroamPoints()
    clearBlips()
end)

---@param phoneState table
local function applyPhoneState(phoneState)
    if phoneState and type(phoneState.ownedPropertyIds) == 'table' then
        setOwnedProperties(phoneState.ownedPropertyIds)
        local gs = SKC.GetGameState()
        if gs == GameState.FREEROAM or gs == GameState.MISSION then
            refreshBlips()
        end
    end
end

---@param result table
local function notifyPurchaseFailure(result)
    if result.reason == 'already_owned' then
        SKNotify({ type = 'warning', title = _L('lua.notify.already_owned') })
        return
    end

    if result.reason == 'insufficient_funds' then
        SKNotify({ type = 'error', title = _L('lua.notify.need_more_cash') })
        return
    end

    SKNotify({ type = 'error', title = _L('lua.notify.purchase_failed') })
end

---@param result table
local function notifyWarpFailure(result)
    if result.reason == 'not_owned' then
        SKNotify({ type = 'warning', title = _L('lua.notify.property_not_owned') })
        return
    end

    if result.reason == 'insufficient_funds' then
        SKNotify({ type = 'error', title = _L('lua.notify.need_more_cash') })
        return
    end

    SKNotify({ type = 'error', title = _L('lua.notify.warp_failed') })
end

RegisterNUICallback('phone:realestate:list', function(data, cb)
    local gameState = SKC.GetGameState()
    if gameState ~= GameState.FREEROAM and gameState ~= GameState.PROPERTY then
        cb({ properties = {}, ownedPropertyIds = {}, focusedPropertyId = data and data.propertyId, cash = 0, warpPrice = SKProperty.WARP_PRICE })
        return
    end

    local phoneState = lib.callback.await('streetkings:property:getPhoneListings', false, data and data.propertyId)
    phoneState.insidePropertyId = activeProperty and activeProperty.id or nil
    applyPhoneState(phoneState)
    cb(phoneState)
end)

RegisterNUICallback('phone:realestate:purchase', function(data, cb)
    local gs = SKC.GetGameState()
    if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then
        cb({ ok = false, reason = 'invalid_state' })
        return
    end

    local result = lib.callback.await('streetkings:property:purchase', false, data.propertyId)
    if result.phoneState then
        applyPhoneState(result.phoneState)
    end
    cb(result)

    if not result.ok then
        notifyPurchaseFailure(result)
        return
    end

    SKNotify({ type = 'success', title = _L('lua.notify.property_purchased') })
end)

RegisterNUICallback('phone:realestate:warp', function(data, cb)
    local gs = SKC.GetGameState()
    if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then
        cb({ ok = false, reason = 'invalid_state' })
        return
    end

    local result = lib.callback.await('streetkings:property:requestWarp', false, data.propertyId)
    cb(result)

    if not result.ok then
        notifyWarpFailure(result)
        return
    end

    SKNotify({ type = 'success', title = _L('lua.notify.warped_to_property') })

    if SKPhone.isOpen() then
        SKPhone.close()
    end

    CreateThread(function()
        Wait(250)
        SKC.Warp(vector3(result.exterior.x, result.exterior.y, result.exterior.z), result.exterior.w)
    end)
end)

RegisterNUICallback('phone:realestate:setWaypoint', function(data, cb)
    local entry = SKProperty.getById(data.propertyId)
    if not entry then
        cb({ ok = false, reason = 'not_found' })
        return
    end

    SetNewWaypoint(entry.exterior.x, entry.exterior.y)
    SKNotify({ type = 'success', title = _L('lua.notify.property_marked') })
    cb({ ok = true })
end)

RegisterNUICallback('phone:realestate:forceEnter', function(data, cb)
    local gs = SKC.GetGameState()
    if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then
        cb({ ok = false, reason = 'invalid_state' })
        return
    end

    local adminState = lib.callback.await('phone:settings:hasPermission', false)
    if not adminState then
        cb({ ok = false, reason = 'forbidden' })    
        return
    end

    if not SKProperty.forceEnterById(data.propertyId) then
        cb({ ok = false, reason = 'not_found' })
        return
    end

    cb({ ok = true })
end)
