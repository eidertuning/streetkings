SKFreeroam = {}

local SPAWN_POSITION = vector4(-253.6088, -749.0374, 32.2117, 158.7402)

local activeVehicle  = nil
local playerDead     = false
local returnPosition = nil
local debugOnFootMode = false
local debugOnFootDetached = false

local noCollisionVehicleNetIds = {}

local SPAWN_PROTECTION_MS  = 4000
local SPAWN_FLASH_INTERVAL = 150
local SPAWN_GHOST_ALPHA    = 160
local spawnProtectionUntil = 0


local function applyPlayerVehicleNoCollision()
    if not activeVehicle or not DoesEntityExist(activeVehicle) then
        return
    end

    local activeVehicleNetId = NetworkGetNetworkIdFromEntity(activeVehicle)
    for _, netId in ipairs(noCollisionVehicleNetIds) do
        if netId ~= activeVehicleNetId and NetworkDoesEntityExistWithNetworkId(netId) then
            local otherVehicle = NetworkGetEntityFromNetworkId(netId)
            if otherVehicle ~= 0 and DoesEntityExist(otherVehicle) then
                SetEntityNoCollisionEntity(activeVehicle, otherVehicle, true)
            end
        end
    end
end

local function startSpawnProtection()
    spawnProtectionUntil = GetGameTimer() + SPAWN_PROTECTION_MS
end

local function tickSpawnProtection()
    local now = GetGameTimer()
    if now >= spawnProtectionUntil then return false end

    local ped = PlayerPedId()
    applyPlayerVehicleNoCollision()

    local cycle = math.floor((spawnProtectionUntil - now) / SPAWN_FLASH_INTERVAL) % 2
    local veh = GetVehiclePedIsIn(ped, false)
    if cycle == 0 then
        SetEntityAlpha(ped, SPAWN_GHOST_ALPHA, false)
        if veh ~= 0 then SetEntityAlpha(veh, SPAWN_GHOST_ALPHA, false) end
    else
        ResetEntityAlpha(ped)
        if veh ~= 0 then ResetEntityAlpha(veh) end
    end

    return true
end

local function endSpawnProtection()
    spawnProtectionUntil = 0
    local ped = PlayerPedId()
    ResetEntityAlpha(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then ResetEntityAlpha(veh) end
end

---@return integer|nil
function SKFreeroam.getActiveVehicle()
    return activeVehicle
end

function SKFreeroam.deleteActiveVehicle()
    if activeVehicle and DoesEntityExist(activeVehicle) then
        DeleteEntity(activeVehicle)
    end
    activeVehicle = nil
end

---@param pos vector4
function SKFreeroam.setReturnPosition(pos)
    returnPosition = pos
end

function SKFreeroam.restoreToReturnPosition()
    if not activeVehicle or not DoesEntityExist(activeVehicle) then
        SKC.SetGameState(GameState.FREEROAM)
        return
    end

    CreateThread(function()
        DoScreenFadeOut(0)
        local spawnPos = returnPosition or SPAWN_POSITION
        returnPosition = nil

        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityCoords(ped, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
        SKAvatar.applyActiveAppearance()
        ped = PlayerPedId()
        FreezeEntityPosition(ped, false)

        SetEntityCoords(activeVehicle, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
        SetEntityHeading(activeVehicle, spawnPos.w)
        SetVehicleOnGroundProperly(activeVehicle)

        local savedMods   = lib.callback.await('streetkings:shop:getVehicleMods', false)
        local savedColors = lib.callback.await('streetkings:shop:getVehicleColors', false)
        SetVehicleModKit(activeVehicle, 0)
        for modType, modIndex in pairs(savedMods) do
            local numericModType = tonumber(modType)
            if not SKShopShared.isExcludedModType(numericModType) then
                SKShopShared.applyVehicleMod(activeVehicle, numericModType, modIndex)
            end
        end
        if savedColors.primary then
            SetVehicleCustomPrimaryColour(activeVehicle, savedColors.primary.r, savedColors.primary.g, savedColors.primary.b)
        end
        if savedColors.secondary then
            SetVehicleCustomSecondaryColour(activeVehicle, savedColors.secondary.r, savedColors.secondary.g, savedColors.secondary.b)
        end

        lib.callback.await('streetkings:progression:syncActiveVehicleMods', false, SKProgression.collectVehicleAvailability(activeVehicle))

        SetVehicleDirtLevel(activeVehicle, 0.0)
        TaskWarpPedIntoVehicle(ped, activeVehicle, -1)
        while not IsPedInVehicle(ped, activeVehicle, false) do Wait(0) end

        SetEntityMaxHealth(ped, 115)
        SetEntityHealth(ped, 115)
        RenderScriptCams(false, false, 0, true, true)
        SKSpeedo.setEnabled(true)
        SKCamera.delayEnable(activeVehicle, 200)
        DoScreenFadeIn(500)
    end)
end

---@return boolean
local function isOnFootPermitted()
    local inZone = SKHangoutZones and type(SKHangoutZones.isInsideZone) == 'function' and SKHangoutZones.isInsideZone()
    return inZone or debugOnFootMode
end

---@param pos vector4
---@return integer vehicle entity
local function requestVehicleFromServer(pos)
    local result = lib.callback.await('streetkings:freeroam:spawnVehicle', false,
        pos.x, pos.y, pos.z, pos.w)
    if not result or result.ok ~= true or type(result.netId) ~= 'number' then
        error(('streetkings: failed to spawn freeroam vehicle (%s)'):format(tostring(result and result.reason or 'unknown')))
    end

    while not NetworkDoesEntityExistWithNetworkId(result.netId) do Wait(0) end
    return NetworkGetEntityFromNetworkId(result.netId)
end

---@param vehicle integer
local function requestVehicleControl(vehicle)
    while not NetworkHasControlOfEntity(vehicle) do
        NetworkRequestControlOfEntity(vehicle)
        Wait(0)
    end
end

---@param netId integer
---@param timeoutMs integer
---@return integer|nil
local function awaitVehicleByNetId(netId, timeoutMs)
    local deadline = GetGameTimer() + timeoutMs
    while GetGameTimer() < deadline do
        if NetworkDoesEntityExistWithNetworkId(netId) then
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                return vehicle
            end
        end
        Wait(0)
    end
    return nil
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        DeleteEntity(veh)
    end
    activeVehicle = nil
end)

RegisterNetEvent('streetkings:freeroam:forceVehicle', function()
    if debugOnFootMode then return end
    if SKVehicleLock.isLeaveAllowed() then return end
    if isOnFootPermitted() then return end

    local ped = PlayerPedId()
    if activeVehicle and DoesEntityExist(activeVehicle) and not IsPedInVehicle(ped, activeVehicle, false) then
        TaskWarpPedIntoVehicle(ped, activeVehicle, -1)
    end
end)

RegisterNetEvent('streetkings:freeroam:setNoCollisionVehicles', function(netIds)
    noCollisionVehicleNetIds = netIds
end)

---@return boolean
function SKFreeroam.debugDitchVehicle()
    if SKC.GetGameState() ~= GameState.FREEROAM then
        return false
    end

    local ped = PlayerPedId()
    if not activeVehicle or not DoesEntityExist(activeVehicle) or not IsPedInVehicle(ped, activeVehicle, false) then
        return false
    end

    debugOnFootMode = true
    debugOnFootDetached = false
    TaskLeaveVehicle(ped, activeVehicle, 0)
    return true
end

local drivingStatsActive = false
local sessionMiles       = 0.0
local sessionTopSpeed    = 0.0
local lastStatsPos       = nil

local function flushDrivingStats()
    if sessionMiles > 0 or sessionTopSpeed > 0 then
        TriggerServerEvent('streetkings:stats:syncDriving', sessionMiles, sessionTopSpeed)
        sessionMiles    = 0.0
        sessionTopSpeed = 0.0
    end
end

local function startDrivingStatsThread()
    if drivingStatsActive then return end
    drivingStatsActive = true
    lastStatsPos       = GetEntityCoords(PlayerPedId())
    local syncTimer    = 0

    CreateThread(function()
        while drivingStatsActive do
            Wait(2000)
            if not drivingStatsActive then break end

            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local pos = GetEntityCoords(ped)
                local dist = #(pos - lastStatsPos)
                local miles = dist * 0.000621371
                if miles > 0 and miles < 5 then
                    sessionMiles = sessionMiles + miles
                end
                lastStatsPos = pos

                local speedMph = GetEntitySpeed(GetVehiclePedIsIn(ped, false)) * 2.236936
                if speedMph > sessionTopSpeed then
                    sessionTopSpeed = speedMph
                end
            else
                lastStatsPos = GetEntityCoords(ped)
            end

            syncTimer = syncTimer + 2000
            if syncTimer >= 30000 then
                flushDrivingStats()
                syncTimer = 0
            end
        end
    end)
end

SKC.RegisterGameState(GameState.FREEROAM, {
    onEnter = function(prevState)
        playerDead = false
        debugOnFootMode = false
        debugOnFootDetached = false
        SKNametags.startFreeroam()
        startDrivingStatsThread()
        SKPolice.onFreeroamEnter()
        CreateThread(function()
            if prevState == GameState.EVENT or prevState == GameState.MISSION then
                local ped = PlayerPedId()
                TaskWarpPedIntoVehicle(ped, activeVehicle, -1)
                while not IsPedInVehicle(ped, activeVehicle, false) do Wait(0) end
                SetEntityMaxHealth(ped, 115)
                SetEntityHealth(ped, 115)
                SetBigmapActive(false, false)
                TriggerEvent('streetkings:shop:freeroamEnter')
                TriggerEvent('streetkings:garage:freeroamEnter')
                TriggerEvent('streetkings:dealership:freeroamEnter')
                TriggerEvent('streetkings:event:freeroamEnter')
                TriggerEvent('streetkings:speedcameras:freeroamEnter')
                TriggerEvent('streetkings:property:freeroamEnter')
                TriggerEvent('streetkings:repair:freeroamEnter')
                TriggerEvent('streetkings:avatar:freeroamEnter')
                TriggerEvent('streetkings:hangoutzones:freeroamEnter')
                return
            end

            local seamlessReturn = (prevState == GameState.MULTIPLAYER_LOBBY or prevState == GameState.MULTIPLAYER_EVENT)
                and SKMultiplayer and SKMultiplayer.consumePendingSeamlessReturn
                and SKMultiplayer.consumePendingSeamlessReturn()
                or nil
            if seamlessReturn and seamlessReturn.seamless then
                TriggerServerEvent('streetkings:freeroam:enter')
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)
                if (veh == 0 or not DoesEntityExist(veh)) and type(seamlessReturn.vehicleNetId) == 'number' then
                    veh = awaitVehicleByNetId(seamlessReturn.vehicleNetId, 5000) or 0
                    if veh ~= 0 and DoesEntityExist(veh) and not IsPedInVehicle(ped, veh, false) then
                        TaskWarpPedIntoVehicle(ped, veh, -1)
                    end
                end
                activeVehicle = veh ~= 0 and veh or nil
                SetEntityMaxHealth(ped, 115)
                SetEntityHealth(ped, 115)
                SetBigmapActive(false, false)
                SKSpeedo.setEnabled(true)
                TriggerEvent('streetkings:shop:freeroamEnter')
                TriggerEvent('streetkings:garage:freeroamEnter')
                TriggerEvent('streetkings:dealership:freeroamEnter')
                TriggerEvent('streetkings:event:freeroamEnter')
                TriggerEvent('streetkings:speedcameras:freeroamEnter')
                TriggerEvent('streetkings:property:freeroamEnter')
                TriggerEvent('streetkings:repair:freeroamEnter')
                TriggerEvent('streetkings:avatar:freeroamEnter')
                TriggerEvent('streetkings:hangoutzones:freeroamEnter')
                return
            end

            DoScreenFadeOut(0)

            local spawnPos   = returnPosition or SPAWN_POSITION
            returnPosition   = nil

            local ped = PlayerPedId()
            FreezeEntityPosition(ped, false)
            SetEntityCoords(ped, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
            SKAvatar.applyActiveAppearance()
            ped = PlayerPedId()
            FreezeEntityPosition(ped, false)
            SetEntityCoords(ped, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)

            if activeVehicle and DoesEntityExist(activeVehicle) then
                DeleteEntity(activeVehicle)
                activeVehicle = nil
            end

            TriggerServerEvent('streetkings:freeroam:enter')
            activeVehicle = requestVehicleFromServer(spawnPos)
            requestVehicleControl(activeVehicle)

            local savedMods    = lib.callback.await('streetkings:shop:getVehicleMods', false)
            local savedColors  = lib.callback.await('streetkings:shop:getVehicleColors', false)
            SetVehicleModKit(activeVehicle, 0)
            for modType, modIndex in pairs(savedMods) do
                local numericModType = tonumber(modType)
                if not SKShopShared.isExcludedModType(numericModType) then
                    SKShopShared.applyVehicleMod(activeVehicle, numericModType, modIndex)
                end
            end
            if savedColors.primary then
                SetVehicleCustomPrimaryColour(activeVehicle, savedColors.primary.r, savedColors.primary.g, savedColors.primary.b)
            end
            if savedColors.secondary then
                SetVehicleCustomSecondaryColour(activeVehicle, savedColors.secondary.r, savedColors.secondary.g, savedColors.secondary.b)
            end

            lib.callback.await('streetkings:progression:syncActiveVehicleMods', false, SKProgression.collectVehicleAvailability(activeVehicle))

            SetVehicleDirtLevel(activeVehicle, 0.0)
            TaskWarpPedIntoVehicle(ped, activeVehicle, -1)

            while not IsPedInVehicle(ped, activeVehicle, false) do Wait(0) end

            SetEntityMaxHealth(ped, 115)
            SetEntityHealth(ped, 115)

            SetBigmapActive(false, false)

            RenderScriptCams(false, false, 0, true, true)
            TriggerEvent('streetkings:shop:freeroamEnter')
            TriggerEvent('streetkings:garage:freeroamEnter')
            TriggerEvent('streetkings:dealership:freeroamEnter')
            TriggerEvent('streetkings:event:freeroamEnter')
            TriggerEvent('streetkings:speedcameras:freeroamEnter')
            TriggerEvent('streetkings:property:freeroamEnter')
            TriggerEvent('streetkings:repair:freeroamEnter')
            TriggerEvent('streetkings:avatar:freeroamEnter')
            TriggerEvent('streetkings:hangoutzones:freeroamEnter')

            SKSpeedo.setEnabled(true)
            SetVehRadioStation(activeVehicle, math.random(2) == 1 and "RADIO_03_HIPHOP_NEW" or "RADIO_09_HIPHOP_OLD")
            SKCamera.delayEnable(activeVehicle, 200)
            startSpawnProtection()
            DoScreenFadeIn(500)
        end)
    end,

    onExit = function(nextState)
        drivingStatsActive = false
        flushDrivingStats()
        SKNametags.stop()

        if spawnProtectionUntil > 0 then endSpawnProtection() end
        debugOnFootMode = false
        debugOnFootDetached = false
        local isMultiplayerNext = nextState == GameState.MULTIPLAYER_LOBBY or nextState == GameState.MULTIPLAYER_EVENT
        if isMultiplayerNext then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            returnPosition = vector4(pos.x, pos.y, pos.z, GetEntityHeading(ped))
        elseif not SKShop.isShopState(nextState) and not SKGarage.isGarageState(nextState) and not SKDealership.isDealershipState(nextState) and not SKAvatar.isAvatarState(nextState) and nextState ~= GameState.FREEROAM then
            returnPosition = nil
        end

        if nextState == GameState.MISSION then
            TriggerEvent('streetkings:event:freeroamExit', nextState)
            TriggerEvent('streetkings:property:freeroamExit')
            TriggerEvent('streetkings:hangoutzones:freeroamExit')
            local ped = PlayerPedId()
            SetEntityMaxHealth(ped, 200)
            SetEntityHealth(ped, 200)
            ClearPlayerWantedLevel(PlayerId())
            SKPolice.onFreeroamExit()
            return
        end

        TriggerEvent('streetkings:shop:freeroamExit')
        TriggerEvent('streetkings:garage:freeroamExit')
        TriggerEvent('streetkings:dealership:freeroamExit')
        TriggerEvent('streetkings:event:freeroamExit')
        TriggerEvent('streetkings:speedcameras:freeroamExit')
        TriggerEvent('streetkings:property:freeroamExit')
        TriggerEvent('streetkings:repair:freeroamExit')
        TriggerEvent('streetkings:avatar:freeroamExit')
        TriggerEvent('streetkings:hangoutzones:freeroamExit')
        local ped = PlayerPedId()
        SetEntityMaxHealth(ped, 200)
        SetEntityHealth(ped, 200)
        ClearPlayerWantedLevel(PlayerId())
        SKPolice.onFreeroamExit()

        if nextState == GameState.EVENT then return end

        if nextState == GameState.MULTIPLAYER_LOBBY then
            TriggerServerEvent('streetkings:freeroam:exit')
            activeVehicle = nil
            return
        end

        SKSpeedo.setEnabled(false)
        SKCamera.onFreeroamExit()
        TriggerServerEvent('streetkings:freeroam:exit')
        SKFreeroam.deleteActiveVehicle()
    end,

    onTick = function()
        if debugOnFootMode and activeVehicle and DoesEntityExist(activeVehicle) then
            local inActiveVehicle = IsPedInVehicle(PlayerPedId(), activeVehicle, false)
            if not debugOnFootDetached and not inActiveVehicle then
                debugOnFootDetached = true
            elseif debugOnFootDetached and inActiveVehicle then
                debugOnFootMode = false
                debugOnFootDetached = false
            end
        end
        if spawnProtectionUntil > 0 then
            if not tickSpawnProtection() then
                endSpawnProtection()
            end
        elseif SKHangoutZones.isInsideZone() then
            applyPlayerVehicleNoCollision()
        end
        SKVehicleLock.tick(activeVehicle, isOnFootPermitted)
        if not playerDead and IsEntityDead(PlayerPedId()) then
            playerDead = true
            SKC.Wasted()
        end
    end,

    tickWait = 0,
})

exports('GetPlayerVehicle', SKFreeroam.getActiveVehicle)
exports('IsInFreeroam', function() return SKC.GetGameState() == GameState.FREEROAM end)
exports('IsPlayerWasted', function() return playerDead end)

function SKC.Wasted()
    CreateThread(function()
        local confirmed = lib.callback.await('streetkings:freeroam:confirmHospitalBill', false)
        if not confirmed or not confirmed.ok then
            return
        end

        DoScreenFadeOut(400)
        Wait(500)
        local pos = SPAWN_POSITION
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, pos.w, true, false)
        SendNUIMessage({ type = 'youDied', show = true })
        Wait(5000)
        SendNUIMessage({ type = 'youDied', show = false })
        if SKPhone and SKPhone.isOpen() then
            SKPhone.close()
        end
        SKGarage.enterFromMenu()
    end)
end