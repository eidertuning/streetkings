SKPolice = {}

-- Config --------------------------------------------------------------------

SKPolice.PoliceVehicles = {
    `police`,
    `police2`,
    `police3`,
    `police4`,
    `sheriff`,
    `sheriff2`,
    `policet`,
    `policeb`,
    `pranger`,
}

SKPolice.RadarDetector = {
    enabled          = true,
    maxDetectDistance = 150.0,
    minIntervalMs    = 180,
    maxIntervalMs    = 1600,
}

SKPolice.TrapConfig = {
    triggerSpeedMph  = 60.0,
    spawnDistance    = 250.0,
    detectDistance   = 45.0,
    defaultCopPed    = 's_m_y_hwaycop_01',
    blips = {
        enabled    = false,
        showStatic = false,
        sprite     = 56,
        color      = 3,
        scale      = 0.5,
        shortRange = true,
        name       = 'Trap Cop',
    },
}

-- State ---------------------------------------------------------------------

SKPolice.TrapPoints      = {}
SKPolice.TrapCopVehicles = {}
SKPolice.TrapCopPeds     = {}

local pursuit = {
    active  = false,
    started = nil,
    running = false,
}
local crimeCooldown     = 0
local CRIME_COOLDOWN    = 30000
local TRAFFIC_COLLISION_REPORT_CHANCE = 0.08
local incidents         = {}
local INCIDENT_LIFETIME = 120000
local policeDisabled    = false

-- Helpers -------------------------------------------------------------------

---@return boolean
function SKPolice.isInFreeroam()
    local gs = SKC.GetGameState()
    return gs == GameState.FREEROAM or gs == GameState.MISSION
end

---@return boolean
function SKPolice.isChasing()
    return GetPlayerWantedLevel(PlayerId()) > 0 or pursuit.active or pursuit.running
end

---@return boolean
function SKPolice.hasWantedLevel()
    return GetPlayerWantedLevel(PlayerId()) > 0
end

function SKPolice.notifyAccessBlockedByWantedLevel()
    SKNotify({ type = 'error', title = 'Lose Your Wanted Level First' })
end

---@param distance number
---@return integer|nil entity, boolean isNear
function SKPolice.IsNearPolice(distance)
    local playerPos = GetEntityCoords(PlayerPedId())
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local model = GetEntityModel(vehicle)
            for _, copModel in ipairs(SKPolice.PoliceVehicles) do
                if copModel == model then
                    if #(playerPos - GetEntityCoords(vehicle)) < distance then
                        return vehicle, true
                    end
                end
            end
        end
    end
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedInAnyVehicle(ped, false) then
            if SKPolice.TrapCopPeds[ped] or GetPedRelationshipGroupHash(ped) == GetHashKey('COP') then
                if #(playerPos - GetEntityCoords(ped)) < distance then
                    return ped, true
                end
            end
        end
    end
    return nil, false
end

---@param maxDistance number
---@return number
local function getNearestTrapCopDistance(maxDistance)
    local playerPos = GetEntityCoords(PlayerPedId())
    local nearest   = maxDistance + 1.0
    for _, pt in ipairs(SKPolice.TrapPoints) do
        if pt.spawnedVehicle and DoesEntityExist(pt.spawnedVehicle) then
            local dist = #(playerPos - GetEntityCoords(pt.spawnedVehicle))
            if dist < nearest then nearest = dist end
        end
    end
    return nearest
end

---@param show boolean
---@param seconds number|nil
local function BustCountdownUI(show, seconds)
    if show then
        SendNUIMessage({ type = 'police:bustCountdown', show = true, seconds = seconds or 0 })
    else
        SendNUIMessage({ type = 'police:bustCountdown', show = false })
    end
end

-- Police disable toggle -----------------------------------------------------

---@param disabled boolean
function SKPolice.setPoliceDisabled(disabled)
    policeDisabled = disabled
    if not disabled then return end
    ClearPlayerWantedLevel(PlayerId())
    SKPolice.resetPursuit()
    for _, pt in ipairs(SKPolice.TrapPoints) do
        if pt.spawnedVehicle or pt.spawnedPed then
            deleteTrap(pt)
            pt._triggered      = false
            pt._pendingCleanup = false
        end
    end
    for _, entry in ipairs(incidents) do
        DeleteIncident(entry.handle)
    end
    incidents = {}
end

---@param data table
---@return boolean
function SKPolice.applySpeedCameraWanted(data)
    if policeDisabled then return false end
    if not SKPolice.isInFreeroam() then return false end

    local wantedLevel = math.floor(tonumber(data and data.wantedLevel) or 0)
    wantedLevel = math.max(0, math.min(5, wantedLevel))
    if wantedLevel <= 0 then return false end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return false end

    local current = GetPlayerWantedLevel(PlayerId())
    if current >= wantedLevel then return false end

    local applied = math.max(current, wantedLevel)
    SetDispatchCopsForPlayer(PlayerId(), true)
    SetPlayerWantedLevel(PlayerId(), applied, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
    SetVehicleIsWanted(vehicle, true)
    ReportPoliceSpottedPlayer(PlayerId())
    return true
end

RegisterNetEvent('streetkings:police:applySpeedCameraWanted', function(data)
    SKPolice.applySpeedCameraWanted(data)
end)

-- Pursuit state reset -------------------------------------------------------

function SKPolice.resetPursuit()
    pursuit.active  = false
    pursuit.started = nil
    pursuit.running = false
    bustedTimer     = 0
    BustCountdownUI(false)

    for _, pt in ipairs(SKPolice.TrapPoints) do
        if pt._triggered then
            pt._triggered       = false
            pt._pendingCleanup  = false
            deleteTrap(pt)
        end
    end
end

-- Outcome functions ---------------------------------------------------------

---@return boolean
function SKPolice.busted()
    if SKMissionsClient.isFinaleActive() then
        BustCountdownUI(false)
        ClearPlayerWantedLevel(PlayerId())
        lib.callback.await('streetkings:missions:resetMission', false)
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        SendNUIMessage({ type = 'missions:hide' })
        SKC.Wasted()
        return true
    end

    local confirmed = lib.callback.await('streetkings:police:confirmBust', false)
    if not confirmed or not confirmed.ok then
        return false
    end

    BustCountdownUI(false)
    bustedTimer = GetGameTimer()
    ClearPlayerWantedLevel(PlayerId())
    DoScreenFadeOut(500)
    Wait(600)
    SendNUIMessage({ type = 'arrested', show = true })
    Wait(5000)
    DoScreenFadeOut(400)
    Wait(500)
    SendNUIMessage({ type = 'arrested', show = false })
    if SKPhone.isOpen() then
        SKPhone.close()
    end
    SKGarage.enterFromMenu()
    return true
end

---@param entity integer  the cop vehicle that caught the player
function SKPolice.caughtSpeeding(entity)
    caughtSpeedingTime = GetGameTimer()

    SKCamera.disable()

    for i = 10, 1, -1 do
        SetTimeScale(i / 10)
        Wait(35)
    end
    Cinematic = true
    local cinCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local playerVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    AttachCamToEntity(cinCam, playerVehicle, 0.0, 20.0, 4.0, true)
    PointCamAtEntity(cinCam, entity, 0.0, 0.0, 0.0, true)
    SetCamActive(cinCam, true)
    RenderScriptCams(true, true, 0, true, true)

    SetPlayerWantedLevel(PlayerId(), 2, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
    SetVehicleIsWanted(playerVehicle, true)
    ReportPoliceSpottedPlayer(PlayerId())

    Wait(5000)

    SetCamActive(cinCam, false)
    DestroyCam(cinCam, false)
    RenderScriptCams(false, true, 0, true, true)

    for i = 1, 10 do
        SetTimeScale(i / 10)
        Wait(35)
    end
    Cinematic = false
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then
        SKCamera.disable()
        SKCamera.enable(veh)
    end
end

-- Trap management -----------------------------------------------------------

---@param point table
local function createTrapVehicleAndCop(point)
    if point.spawnedVehicle and DoesEntityExist(point.spawnedVehicle) then return end
    if SKPolice.isChasing() then return end

    local vehicleHash = SK.LoadModel(point.vehicle or SKPolice.TrapConfig.defaultCopPed)
    local copHash     = SK.LoadModel(point.cop or SKPolice.TrapConfig.defaultCopPed)
    if not vehicleHash or not copHash then return end

    local v = CreateVehicle(vehicleHash, point.coords.x, point.coords.y, point.coords.z, point.heading or 0.0, false, true)
    if not DoesEntityExist(v) then return end

    SetEntityAsMissionEntity(v, true, true)
    SetVehicleOnGroundProperly(v)
    SetVehicleDoorsLocked(v, 4)
    SetVehicleSiren(v, false)
    SetVehicleHasMutedSirens(v, false)
    SetVehicleEngineOn(v, true, true, false)

    local ped = CreatePedInsideVehicle(v, 4, copHash, -1, false, true)
    if not DoesEntityExist(ped) then
        DeleteEntity(v)
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeDraggedOut(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedKeepTask(ped, true)

    SKPolice.TrapCopVehicles[v]   = true
    SKPolice.TrapCopPeds[ped]     = true
    point.spawnedVehicle          = v
    point.spawnedPed              = ped

    if SKPolice.TrapConfig.blips.enabled then
        local blip = AddBlipForEntity(v)
        SetBlipSprite(blip, SKPolice.TrapConfig.blips.sprite)
        SetBlipColour(blip, SKPolice.TrapConfig.blips.color)
        SetBlipScale(blip, SKPolice.TrapConfig.blips.scale)
        SetBlipAsShortRange(blip, SKPolice.TrapConfig.blips.shortRange)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(SKPolice.TrapConfig.blips.name)
        EndTextCommandSetBlipName(blip)
        point.spawnedBlip = blip
    end
end

---@param point table
function deleteTrap(point)
    if point.spawnedPed and DoesEntityExist(point.spawnedPed) then
        SKPolice.TrapCopPeds[point.spawnedPed] = nil
        DeleteEntity(point.spawnedPed)
        point.spawnedPed = nil
    end
    if point.spawnedVehicle and DoesEntityExist(point.spawnedVehicle) then
        SKPolice.TrapCopVehicles[point.spawnedVehicle] = nil
        DeleteEntity(point.spawnedVehicle)
        point.spawnedVehicle = nil
    end
    if point.spawnedBlip and DoesBlipExist(point.spawnedBlip) then
        RemoveBlip(point.spawnedBlip)
        point.spawnedBlip = nil
    end
end

---@param point table
local function startTrapChase(point)
    if not point.spawnedPed or not DoesEntityExist(point.spawnedPed) then return end
    SetVehicleSiren(point.spawnedVehicle, true)
    TaskVehicleChase(point.spawnedPed, PlayerPedId())
    SetTaskVehicleChaseBehaviorFlag(point.spawnedPed, 32, true)
    SetTaskVehicleChaseIdealPursuitDistance(point.spawnedPed, 30.0)
    point._triggered = true
    CreateThread(function()
        SKPolice.caughtSpeeding(point.spawnedVehicle)
    end)
    CreateThread(function()
        while point._triggered and point.spawnedVehicle and DoesEntityExist(point.spawnedVehicle) do
            Wait(1000)
            if not SKPolice.isInFreeroam() then break end
            local playerPed = PlayerPedId()
            local dist = #(GetEntityCoords(point.spawnedVehicle) - GetEntityCoords(playerPed))
            if dist <= 50.0 and HasEntityClearLosToEntity(point.spawnedVehicle, playerPed, 17) then
                ReportPoliceSpottedPlayer(PlayerId())
            end
        end
    end)
end

---@param locations table
function SKPolice.InitTrapPoints(locations)
    for _, cfg in ipairs(locations) do
        local pt = lib.points.new({
            coords   = cfg.coords,
            distance = SKPolice.TrapConfig.spawnDistance,
        })
        pt.vehicle       = cfg.vehicle
        pt.cop           = cfg.cop
        pt.heading       = cfg.heading
        pt._triggered     = false
        pt._pendingCleanup = false
        pt.spawnedVehicle = nil
        pt.spawnedPed    = nil
        pt.spawnedBlip   = nil

        function pt:onEnter()
            createTrapVehicleAndCop(self)
        end

        function pt:onExit()
            if self._triggered then
                self._pendingCleanup = true
                return
            end
            deleteTrap(self)
        end

        function pt:nearby()
            if not SKPolice.isInFreeroam() then return end
            if policeDisabled then return end
            if not self.spawnedVehicle or not DoesEntityExist(self.spawnedVehicle) then return end
            if self._triggered then return end
            if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
            if GetPlayerWantedLevel(PlayerId()) > 0 then return end

            local veh      = GetVehiclePedIsIn(PlayerPedId(), false)
            local speedMph = GetEntitySpeed(veh) * 2.236936
            if speedMph < SKPolice.TrapConfig.triggerSpeedMph then return end

            if self.currentDistance <= SKPolice.TrapConfig.detectDistance then
                if HasEntityClearLosToEntityInFront(self.spawnedPed, PlayerPedId()) then
                    startTrapChase(self)
                end
            end
        end

        if SKPolice.TrapConfig.blips.showStatic then
            local staticBlip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
            SetBlipSprite(staticBlip, SKPolice.TrapConfig.blips.sprite)
            SetBlipColour(staticBlip, SKPolice.TrapConfig.blips.color)
            SetBlipScale(staticBlip, SKPolice.TrapConfig.blips.scale)
            SetBlipAsShortRange(staticBlip, false)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(SKPolice.TrapConfig.blips.name)
            EndTextCommandSetBlipName(staticBlip)
            pt.staticBlip = staticBlip
        end

        table.insert(SKPolice.TrapPoints, pt)
    end
end

-- Crime dispatch (entityDamaged) --------------------------------------------

---@param victim integer
---@return boolean
local function hasWitness(victim)
    local playerPed = PlayerPedId()
    local victimCoords = GetEntityCoords(victim)
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) and not IsPedInAnyVehicle(ped, false) then
            if #(GetEntityCoords(ped) - victimCoords) <= 50.0 then
                if HasEntityClearLosToEntity(ped, victim, 17) then
                    return true
                end
            end
        end
    end
    return false
end

AddEventHandler('entityDamaged', function(victim, culprit, _weaponHash, _baseDamage)
    if not SKPolice.isInFreeroam() then return end
    if policeDisabled then return end
    if SKPolice.isChasing() then return end
    if GetGameTimer() - crimeCooldown < CRIME_COOLDOWN then return end

    local playerPed     = PlayerPedId()
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    if playerVehicle == 0 then return end
    if culprit ~= playerVehicle then return end

    local victimIsPed     = IsEntityAPed(victim) and victim ~= playerPed and not IsPedAPlayer(victim)
    local victimIsVehicle = IsEntityAVehicle(victim) and not SKPolice.TrapCopVehicles[victim]

    if victimIsPed then
        if not hasWitness(victim) then return end
        local _, incident = CreateIncidentWithEntity(7, PlayerPedId(), 4, 20.0)
        table.insert(incidents, { handle = incident, expiresAt = GetGameTimer() + INCIDENT_LIFETIME })
        SetDispatchCopsForPlayer(PlayerId(), true)
    elseif victimIsVehicle then
        local model = GetEntityModel(victim)
        for _, copModel in ipairs(SKPolice.PoliceVehicles) do
            if copModel == model then return end
        end
        if not hasWitness(victim) then return end
        if math.random() > TRAFFIC_COLLISION_REPORT_CHANCE then return end
    else
        return
    end

    crimeCooldown = GetGameTimer()
    SetPlayerWantedLevel(PlayerId(), 1, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
end)

-- Thread: incident cleanup --------------------------------------------------

CreateThread(function()
    while true do
        Wait(5000)
        if SKPolice.isInFreeroam() and #incidents > 0 then
            local now = GetGameTimer()
            for i = #incidents, 1, -1 do
                if now >= incidents[i].expiresAt then
                    DeleteIncident(incidents[i].handle)
                    table.remove(incidents, i)
                end
            end
        end
    end
end)

-- Resource stop cleanup -----------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, entry in ipairs(incidents) do
        DeleteIncident(entry.handle)
    end
    incidents = {}
    for _, pt in ipairs(SKPolice.TrapPoints) do
        deleteTrap(pt)
        if pt.staticBlip and DoesBlipExist(pt.staticBlip) then
            RemoveBlip(pt.staticBlip)
        end
        if pt.remove then pt:remove() end
    end
    SKPolice.TrapPoints      = {}
    SKPolice.TrapCopVehicles = {}
    SKPolice.TrapCopPeds     = {}
end)

-- Thread: radar detector ----------------------------------------------------

CreateThread(function()
    while not RequestScriptAudioBank('audiodirectory/custom_sounds', false) do
        Wait(0)
    end
end)

CreateThread(function()
    local lastBeep = 0
    while true do
        Wait(50)
        if not SKPolice.isInFreeroam() then
            Wait(1000)
        elseif SKPolice.isChasing() then
            Wait(500)
        elseif not policeDisabled and SKPolice.RadarDetector.enabled and IsPedInAnyVehicle(PlayerPedId(), false) then
            local maxD = SKPolice.RadarDetector.maxDetectDistance
            local d    = getNearestTrapCopDistance(maxD)
            if d <= maxD then
                local t        = math.max(0.0, math.min(1.0, d / maxD))
                local interval = math.floor(
                    SKPolice.RadarDetector.minIntervalMs
                    + (SKPolice.RadarDetector.maxIntervalMs - SKPolice.RadarDetector.minIntervalMs) * t
                )
                if GetGameTimer() - lastBeep >= interval then
                    PlaySoundFrontend(-1, 'radar_detector', 'sk_soundset', true)
                    lastBeep = GetGameTimer()
                end
            else
                Wait(250)
            end
        else
            Wait(200)
        end
    end
end)

-- Thread: pursuit state machine --------------------------------------------

CreateThread(function()
    local bustedTime = 4

    while true do
        Wait(250)
        if not SKPolice.isInFreeroam() then
            Wait(1000)
        elseif policeDisabled then
            if GetPlayerWantedLevel(PlayerId()) > 0 then
                ClearPlayerWantedLevel(PlayerId())
            end
        else
            if IsPedInAnyVehicle(PlayerPedId(), false) and GetPlayerWantedLevel(PlayerId()) > 0 then
                if not pursuit.active then
                    pursuit.active  = true
                    pursuit.started = GetGameTimer()
                end

                local _, isNear = SKPolice.IsNearPolice(12.0)
                if Cinematic then
                    bustedTime = 4
                    BustCountdownUI(false)
                elseif isNear and GetEntitySpeed(PlayerPedId()) < 3.0 then
                    Wait(750)
                    bustedTime = bustedTime - 1
                    if bustedTime >= 0 then
                        BustCountdownUI(true, bustedTime)
                    end
                    if bustedTime == 0 then
                        if not SKPolice.busted() then
                            bustedTime = 4
                            BustCountdownUI(false)
                        end
                    end
                else
                    bustedTime = 4
                    BustCountdownUI(false)
                end
            else
                bustedTime = 4
                BustCountdownUI(false)

                if pursuit.active or pursuit.running then
                    TriggerServerEvent('streetkings:stats:policeEscape')
                    pursuit.active  = false
                    pursuit.running = false
                    pursuit.started = nil
                    for _, pt in ipairs(SKPolice.TrapPoints) do
                        if pt._pendingCleanup then
                            deleteTrap(pt)
                            pt._triggered      = false
                            pt._pendingCleanup = false
                        end
                    end
                end
            end
        end
    end
end)

-- Lifecycle hooks (called by freeroam_c.lua) --------------------------------

local trapPointsInitialized = false

function SKPolice.onFreeroamEnter()
    if not trapPointsInitialized then
        trapPointsInitialized = true
        CreateThread(function()
            local locations = lib.callback.await('streetkings:police:getActiveTraps', false)
            SKPolice.InitTrapPoints(locations)
        end)
    end
end

function SKPolice.onFreeroamExit()
    SKPolice.resetPursuit()

    for _, pt in ipairs(SKPolice.TrapPoints) do
        deleteTrap(pt)
        if pt.staticBlip and DoesBlipExist(pt.staticBlip) then
            RemoveBlip(pt.staticBlip)
        end
        if pt.remove then pt:remove() end
    end
    SKPolice.TrapPoints      = {}
    SKPolice.TrapCopVehicles = {}
    SKPolice.TrapCopPeds     = {}
    trapPointsInitialized    = false
end

exports('IsPoliceChasing', SKPolice.isChasing)
exports('GetWantedLevel', function() return GetPlayerWantedLevel(PlayerId()) end)
exports('IsNearPolice', SKPolice.IsNearPolice)
exports('ApplySpeedCameraWanted', SKPolice.applySpeedCameraWanted)
