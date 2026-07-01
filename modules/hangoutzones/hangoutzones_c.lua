local activeZones      = {}
local activePoints     = {}
local interiorPoints   = {}
local waypoints        = {}
local blips            = {}

local insidePassiveZone = false
local insideInterior    = false
local activeInteriorDef = nil
local activeInteriorId  = nil
local zoneEntryVehicle  = nil

function SKHangoutZones.isInsideZone()
    return insidePassiveZone
end

local PASSIVE_DISABLE_CONTROLS = {
    24, 25, 47, 58, 140, 141, 142, 143, 263, 264,
}

---------------------------------------------------------------------------
-- Passive mode
---------------------------------------------------------------------------

local passiveTickGen = 0

local PASSIVE_GHOST_ALPHA = 160
local passiveGhosted = false

local function applyGhostAlpha(ped)
    local inVeh = IsPedInAnyVehicle(ped, false)
    if inVeh and not passiveGhosted then
        passiveGhosted = true
        SetEntityAlpha(ped, PASSIVE_GHOST_ALPHA, false)
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then SetEntityAlpha(veh, PASSIVE_GHOST_ALPHA, false) end
    elseif not inVeh and passiveGhosted then
        passiveGhosted = false
        ResetEntityAlpha(ped)
        if zoneEntryVehicle and DoesEntityExist(zoneEntryVehicle) then
            ResetEntityAlpha(zoneEntryVehicle)
        end
    end
end

local function clearGhostAlpha(ped)
    if not passiveGhosted then return end
    passiveGhosted = false
    ResetEntityAlpha(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then ResetEntityAlpha(veh) end
end

local function startPassiveTick()
    passiveTickGen = passiveTickGen + 1
    local gen = passiveTickGen

    CreateThread(function()
        local ped = PlayerPedId()
        SetEntityInvincible(ped, true)
        SetPlayerCanDoDriveBy(PlayerId(), false)

        while gen == passiveTickGen do
            ped = PlayerPedId()

            for _, ctrl in ipairs(PASSIVE_DISABLE_CONTROLS) do
                DisableControlAction(0, ctrl, true)
            end

            local playerId = PlayerId()
            for _, id in ipairs(GetActivePlayers()) do
                if id ~= playerId then
                    local otherPed = GetPlayerPed(id)
                    if otherPed and otherPed ~= 0 then
                        SetEntityNoCollisionEntity(ped, otherPed, true)
                        local otherVeh = GetVehiclePedIsIn(otherPed, false)
                        if otherVeh and otherVeh ~= 0 then
                            local myVeh = GetVehiclePedIsIn(ped, false)
                            if myVeh and myVeh ~= 0 then
                                SetEntityNoCollisionEntity(myVeh, otherVeh, true)
                            end
                            SetEntityNoCollisionEntity(ped, otherVeh, true)
                        end
                    end
                end
            end

            applyGhostAlpha(ped)
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

            local currentVeh = GetVehiclePedIsIn(ped, false)
            if currentVeh ~= 0 and zoneEntryVehicle and currentVeh ~= zoneEntryVehicle then
                TaskLeaveVehicle(ped, currentVeh, 16)
            end

            Wait(0)
        end
    end)
end

local function stopPassiveTick()
    passiveTickGen = passiveTickGen + 1

    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetPlayerCanDoDriveBy(PlayerId(), true)
    clearGhostAlpha(ped)
end

---------------------------------------------------------------------------
-- Interior entry / exit
---------------------------------------------------------------------------

local enterInterior, exitInterior

enterInterior = function(zoneDef)
    if insideInterior then return end
    local interior = zoneDef.interior
    if not interior then return end

    insideInterior    = true
    activeInteriorDef = zoneDef
    TriggerServerEvent('streetkings:hangoutzones:enterZone', zoneDef.id)

    DoScreenFadeOut(SKHangoutZones.ZONE_ENTER_FADE_MS)
    while not IsScreenFadedOut() do Wait(0) end

    SKFreeroam.deleteActiveVehicle()

    if interior.ipl ~= '' then RequestIpl(interior.ipl) end

    local intId = interior.interiorId or GetInteriorAtCoords(interior.spawn.x, interior.spawn.y, interior.spawn.z)
    if intId and intId ~= 0 and IsValidInterior(intId) then
        PinInteriorInMemory(intId)
        LoadInterior(intId)
        while not IsInteriorReady(intId) do Wait(0) end
        RefreshInterior(intId)
        activeInteriorId = intId
    else
        activeInteriorId = nil
    end

    Wait(SKHangoutZones.BLACKOUT_MS)

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, interior.spawn.x, interior.spawn.y, interior.spawn.z, false, false, false)
    SetEntityHeading(ped, interior.spawn.w)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, true)
    startPassiveTick()

    local exitPoint = lib.points.new({
        coords   = vector3(interior.exit.x, interior.exit.y, interior.exit.z),
        distance = SKHangoutZones.INTERACT_DISTANCE,
        onEnter = function()
            SendNUIMessage({ type = 'prompt:show', key = SKInput.getInteractLabel(), text = _L('lua.prompts.exit', { name = zoneDef.name }) })
        end,
        onExit = function()
            SendNUIMessage({ type = 'prompt:hide' })
        end,
        nearby = function(self)
            local key = SKInput.getInteractLabel()
            if key ~= self._lastKey then
                self._lastKey = key
                SendNUIMessage({ type = 'prompt:show', key = key, text = _L('lua.prompts.exit', { name = zoneDef.name }) })
            end
            if SKInput.isInteractJustReleased() then exitInterior() end
        end,
    })
    interiorPoints[#interiorPoints + 1] = exitPoint

    DoScreenFadeIn(SKHangoutZones.ZONE_EXIT_FADE_MS)
    SKNotify({ type = 'info', title = _L('lua.notify.entered_zone', { name = zoneDef.name }), duration = 3000 })
end

exitInterior = function()
    if not insideInterior then return end

    SendNUIMessage({ type = 'prompt:hide' })
    for i = #interiorPoints, 1, -1 do
        interiorPoints[i]:remove()
        table.remove(interiorPoints, i)
    end

    local interior = activeInteriorDef.interior

    if activeInteriorId then
        UnpinInterior(activeInteriorId)
        activeInteriorId = nil
    end
    if interior.ipl ~= '' then RemoveIpl(interior.ipl) end

    SetEntityInvincible(PlayerPedId(), false)
    stopPassiveTick()

    SKFreeroam.setReturnPosition(vector4(
        interior.entranceCoords.x,
        interior.entranceCoords.y,
        interior.entranceCoords.z,
        interior.entranceHeading
    ))

    insideInterior    = false
    activeInteriorDef = nil
    TriggerServerEvent('streetkings:hangoutzones:exitZone')
    SKC.SetGameState(GameState.FREEROAM)
end

---------------------------------------------------------------------------
-- Zone setup / teardown
---------------------------------------------------------------------------

local function createZoneForEntry(zoneDef)
    local center = zoneDef.waypointCoords or SKHangoutZones.getCenter(zoneDef)

    if zoneDef.poly then
        local polyZone = lib.zones.poly({
            points    = zoneDef.poly,
            thickness = zoneDef.maxZ - zoneDef.minZ,

            onEnter = function()
                insidePassiveZone = true
                zoneEntryVehicle  = SKFreeroam.getActiveVehicle()
                if zoneEntryVehicle and DoesEntityExist(zoneEntryVehicle) then
                    SetVehicleDoorsLocked(zoneEntryVehicle, 1)
                end
                startPassiveTick()
                TriggerServerEvent('streetkings:hangoutzones:enterZone', zoneDef.id)
                SKNotify({ type = 'info', title = _L('lua.notify.entering_safe_zone', { name = zoneDef.name }), duration = 3000 })
            end,

            onExit = function()
                insidePassiveZone = false
                TriggerServerEvent('streetkings:hangoutzones:exitZone')
                if not insideInterior then
                    local ped = PlayerPedId()
                    if zoneEntryVehicle and DoesEntityExist(zoneEntryVehicle) then
                        ResetEntityAlpha(zoneEntryVehicle)
                        SetVehicleDoorsLocked(zoneEntryVehicle, 2)
                        if not IsPedInAnyVehicle(ped, false) then
                            TaskWarpPedIntoVehicle(ped, zoneEntryVehicle, -1)
                        end
                    end
                    zoneEntryVehicle = nil
                    stopPassiveTick()
                    SKNotify({ type = 'info', title = _L('lua.notify.leaving_safe_zone'), duration = 2000 })
                end
            end,

            inside = function()
                if not insidePassiveZone then
                    insidePassiveZone = true
                    zoneEntryVehicle  = SKFreeroam.getActiveVehicle()
                    if zoneEntryVehicle and DoesEntityExist(zoneEntryVehicle) then
                        SetVehicleDoorsLocked(zoneEntryVehicle, 1)
                    end
                    startPassiveTick()
                    TriggerServerEvent('streetkings:hangoutzones:enterZone', zoneDef.id)
                    SKNotify({ type = 'info', title = _L('lua.notify.entering_safe_zone', { name = zoneDef.name }), duration = 3000 })
                end
            end,
        })
        activeZones[#activeZones + 1] = polyZone
    end

    local wpId = SKWaypoint.Create({
        coords     = center,
        text       = zoneDef.name,
        color      = zoneDef.waypointColor,
        icon       = zoneDef.waypointIcon,
        showDist   = true,
        groundBeam = true,
        maxRender  = SKHangoutZones.WAYPOINT_MAX_RENDER,
    })
    waypoints[#waypoints + 1] = wpId

    local blip = AddBlipForCoord(center.x, center.y, center.z)
    SetBlipSprite(blip, 492)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.5)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(zoneDef.name)
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip

    if zoneDef.interior then
        local entrance  = zoneDef.interior.entranceCoords
        local promptTxt = zoneDef.poly and _L('lua.prompts.enter_interior', { name = zoneDef.name }) or _L('lua.prompts.enter', { name = zoneDef.name })
        local entrancePoint = lib.points.new({
            coords   = entrance,
            distance = SKHangoutZones.INTERACT_DISTANCE,
            onEnter = function()
                SendNUIMessage({ type = 'prompt:show', key = SKInput.getInteractLabel(), text = promptTxt })
            end,
            onExit = function()
                SendNUIMessage({ type = 'prompt:hide' })
            end,
            nearby = function(self)
                local key = SKInput.getInteractLabel()
                if key ~= self._lastKey then
                    self._lastKey = key
                    SendNUIMessage({ type = 'prompt:show', key = key, text = promptTxt })
                end
                if SKInput.isInteractJustReleased() then
                    CreateThread(function() enterInterior(zoneDef) end)
                end
            end,
        })
        activePoints[#activePoints + 1] = entrancePoint
    end
end

local function clearAllZones()
    for _, z in ipairs(activeZones)    do z:remove()           end
    for _, p in ipairs(activePoints)   do p:remove()           end
    for _, p in ipairs(interiorPoints) do p:remove()           end
    for _, w in ipairs(waypoints)      do SKWaypoint.Remove(w) end
    for _, b in ipairs(blips)          do RemoveBlip(b)        end
    activeZones, activePoints, interiorPoints, waypoints, blips = {}, {}, {}, {}, {}

    SendNUIMessage({ type = 'prompt:hide' })

    if insidePassiveZone or insideInterior then stopPassiveTick() end
    insidePassiveZone = false
    zoneEntryVehicle  = nil

    if insideInterior then
        if activeInteriorId then
            UnpinInterior(activeInteriorId)
            activeInteriorId = nil
        end
        local interior = activeInteriorDef and activeInteriorDef.interior
        if interior and interior.ipl ~= '' then RemoveIpl(interior.ipl) end
        SetEntityInvincible(PlayerPedId(), false)
        insideInterior    = false
        activeInteriorDef = nil
    end
end

---------------------------------------------------------------------------
-- Freeroam lifecycle hooks
---------------------------------------------------------------------------

AddEventHandler('streetkings:hangoutzones:freeroamEnter', function()
    for _, zoneDef in ipairs(SKHangoutZones.CATALOG) do
        createZoneForEntry(zoneDef)
    end
end)

AddEventHandler('streetkings:hangoutzones:freeroamExit', function()
    clearAllZones()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearAllZones()
end)
