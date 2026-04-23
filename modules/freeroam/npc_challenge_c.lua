local challengeActive  = false
local cooldownUntil    = 0
local COOLDOWN_MS      = 45000
local TRIGGER_CHANCE        = 65
local TIER_MISMATCH_CHANCE  = 12
local RAY_LENGTH       = 10.0
local DEST_MIN         = 800
local DEST_MAX         = 1400
local FINISH_RADIUS    = 30.0
local RACE_TIMEOUT     = 150000
local NPC_DRIVE_SPEED  = 100.0
local NPC_DRIVE_FLAGS  = 786468
local RETASK_INTERVAL  = 3000
local BURNOUT_REQ           = 2000
local BURNOUT_REQ_MISSION   = 1000
local CALM_BURNOUT_INTERVAL = 2000
local HEADING_DOT_MIN       = 0.55
local MEET_RACER_RADIUS     = 12.0

---@return boolean
local function isInNpcChallengeObjective()
    if not SKMissionsClient or not SKMissionsClient.getState then return false end
    local s = SKMissionsClient.getState()
    if not s or not s.ok or not s.active then return false end
    local def = s.active.def
    local idx = s.active.objectiveIndex or 1
    local objective = def and def.objectives and def.objectives[idx]
    return objective ~= nil and objective.type == 'npcChallenge'
end

---@param playerVeh integer
---@return integer|nil, integer|nil
local function findClosestMeetRacer(playerVeh)
    local origin = GetEntityCoords(playerVeh)
    local bestVeh, bestPed, bestDist = nil, nil, MEET_RACER_RADIUS * MEET_RACER_RADIUS

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= playerVeh and DoesEntityExist(veh) then
            local state = Entity(veh).state
            if state and state.skMeetRacer == true then
                local driver = GetPedInVehicleSeat(veh, -1)
                if driver ~= 0 and not IsPedAPlayer(driver) then
                    local p = GetEntityCoords(veh)
                    local dx, dy, dz = p.x - origin.x, p.y - origin.y, p.z - origin.z
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 < bestDist then
                        bestVeh, bestPed, bestDist = veh, driver, d2
                    end
                end
            end
        end
    end

    return bestVeh, bestPed
end

local RACE_TIER = {
    [7]  = 1, -- Super
    [6]  = 1, -- Sports
    [5]  = 1, -- Sports Classics
    [4]  = 1, -- Muscle
    [22] = 1, -- Open Wheel
    [3]  = 2, -- Coupes
    [1]  = 2, -- Sedans
    [0]  = 2, -- Compacts
    [2]  = 2, -- SUVs
    [9]  = 3, -- Off-road
    [12] = 3, -- Vans
    [8]  = 4, -- Motorcycles
}

local function getVehTier(veh)
    return RACE_TIER[GetVehicleClass(veh)]
end

local activeBlip       = nil
local activeCheckpoint = nil
local activeNpcBlip    = nil
local activeNpcVeh     = nil
local activeNpcPed     = nil
local drawingMarker    = false
local burnoutStart     = 0
local lastCalmBurnout  = 0

local function cleanup()
    drawingMarker = false

    if activeBlip and DoesBlipExist(activeBlip) then
        RemoveBlip(activeBlip)
    end
    activeBlip = nil

    if activeNpcBlip and DoesBlipExist(activeNpcBlip) then
        RemoveBlip(activeNpcBlip)
    end
    activeNpcBlip = nil

    if activeCheckpoint then
        DeleteCheckpoint(activeCheckpoint)
    end
    activeCheckpoint = nil

    ClearGpsMultiRoute()
    DeleteWaypoint()

    if activeNpcPed and DoesEntityExist(activeNpcPed) then
        SetBlockingOfNonTemporaryEvents(activeNpcPed, false)
        SetPedKeepTask(activeNpcPed, false)
        SetDriverAggressiveness(activeNpcPed, 0.0)
        SetEntityAsMissionEntity(activeNpcPed, false, true)
        SetEntityAsNoLongerNeeded(activeNpcPed)
    end
    if activeNpcVeh and DoesEntityExist(activeNpcVeh) then
        SetVehicleLights(activeNpcVeh, 0)
        SetVehicleHandbrake(activeNpcVeh, false)
        SetEntityInvincible(activeNpcVeh, false)
        SetEntityAsMissionEntity(activeNpcVeh, false, true)
        SetEntityAsNoLongerNeeded(activeNpcVeh)
    end

    activeNpcVeh = nil
    activeNpcPed = nil
    challengeActive = false
end

local function lockdownNpc(npcPed, npcVeh)
    local deadline = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(npcVeh) or not NetworkHasControlOfEntity(npcPed) do
        NetworkRequestControlOfEntity(npcVeh)
        NetworkRequestControlOfEntity(npcPed)
        if GetGameTimer() > deadline then break end
        Wait(50)
    end

    SetEntityAsMissionEntity(npcPed, true, true)
    SetEntityAsMissionEntity(npcVeh, true, true)
    SetEntityInvincible(npcVeh, true)

    SetBlockingOfNonTemporaryEvents(npcPed, true)
    SetPedKeepTask(npcPed, true)
    SetPedCanBeDraggedOut(npcPed, false)
    SetPedFleeAttributes(npcPed, 0, false)
    SetPedCombatAttributes(npcPed, 46, true)
    SetPedConfigFlag(npcPed, 128, false)
    SetPedConfigFlag(npcPed, 281, true)
    SetDriverAbility(npcPed, 1.0)
    SetDriverAggressiveness(npcPed, 1.0)

    local group = GetHashKey('YOURTEAM_NPCRACE')
    AddRelationshipGroup('YOURTEAM_NPCRACE')
    SetPedRelationshipGroupHash(npcPed, group)
    SetRelationshipBetweenGroups(1, group, GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(1, GetHashKey('PLAYER'), group)
end

local function pickDestination()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local dist = math.random(DEST_MIN, DEST_MAX)
    local target = pos + fwd * dist

    local found, roadPos = GetClosestVehicleNodeWithHeading(target.x, target.y, target.z, 0, 3.0, 0)
    if found then
        return vector3(roadPos.x, roadPos.y, roadPos.z)
    end
    return vector3(target.x, target.y, target.z)
end

local function runCountdown(playerVeh, npcVeh)
    FreezeEntityPosition(playerVeh, true)
    FreezeEntityPosition(npcVeh, true)
    SetVehicleHandbrake(playerVeh, true)
    SetVehicleHandbrake(npcVeh, true)

    SKNotify({ title = 'Challenge Accepted!', type = 'info', duration = 2000 })
    Wait(1500)

    for _, count in ipairs({ 3, 2, 1 }) do
        SendNUIMessage({ type = 'event:countdown', count = count })
        PlaySoundFrontend(-1, 'CHECKPOINT_UNDER_THE_BRIDGE', 'HUD_MINI_GAME_SOUNDSET', true)
        Wait(1000)
    end

    SendNUIMessage({ type = 'event:countdown', count = 0 })
    PlaySoundFrontend(-1, 'CHECKPOINT_AHEAD', 'HUD_MINI_GAME_SOUNDSET', true)
    StartVehicleHorn(npcVeh, 1500, GetHashKey('HELDDOWN'), false)

    FreezeEntityPosition(playerVeh, false)
    FreezeEntityPosition(npcVeh, false)
    SetVehicleHandbrake(playerVeh, false)
    SetVehicleHandbrake(npcVeh, false)
end

local function startMarkerThread(npcVeh)
    drawingMarker = true
    CreateThread(function()
        while drawingMarker and DoesEntityExist(npcVeh) do
            local p = GetEntityCoords(npcVeh)
            DrawMarker(
                2, p.x, p.y, p.z + 2.0,
                0.0, 0.0, 0.0,
                0.0, 180.0, 0.0,
                0.4, 0.4, 0.4,
                255, 210, 0, 200,
                true, true, 2, false, nil, nil, false
            )
            Wait(0)
        end
    end)
end

local function sameRoughHeading(playerVeh, otherVeh)
    local pf = GetEntityForwardVector(playerVeh)
    local of = GetEntityForwardVector(otherVeh)
    local dot = pf.x * of.x + pf.y * of.y + pf.z * of.z
    return dot >= HEADING_DOT_MIN
end

local function playPedSpeech(ped, speechName)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    PlayPedAmbientSpeechNative(ped, speechName, 'SPEECH_PARAMS_FORCE')
end

local function startChallenge(npcVeh, npcPed)
    challengeActive = true
    activeNpcVeh = npcVeh
    activeNpcPed = npcPed

    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if playerVeh == 0 then
        cleanup()
        return
    end

    local vehClass = GetVehicleClass(npcVeh)

    lockdownNpc(npcPed, npcVeh)
    ClearPedTasks(npcPed)
    SetVehicleHandbrake(npcVeh, true)
    playPedSpeech(npcPed, 'GENERIC_INSULT')

    local destination = pickDestination()

    activeBlip = AddBlipForCoord(destination.x, destination.y, destination.z)
    SetBlipSprite(activeBlip, 38)
    SetBlipColour(activeBlip, 66)
    SetBlipRoute(activeBlip, true)
    SetBlipRouteColour(activeBlip, 66)
    SetBlipAsShortRange(activeBlip, false)
    SetBlipHighDetail(activeBlip, true)
    SetBlipDisplay(activeBlip, 4)
    SetNewWaypoint(destination.x, destination.y)

    activeNpcBlip = AddBlipForEntity(npcVeh)
    SetBlipSprite(activeNpcBlip, 225)
    SetBlipColour(activeNpcBlip, 47)
    SetBlipScale(activeNpcBlip, 1.0)

    activeCheckpoint = CreateCheckpoint(
        4, destination.x, destination.y, destination.z,
        destination.x, destination.y, destination.z,
        25.0, 255, 210, 0, 180, 0
    )

    ClearGpsMultiRoute()
    StartGpsMultiRoute(6, false, true)
    AddPointToGpsMultiRoute(destination.x, destination.y, destination.z)
    SetGpsMultiRouteRender(true)

    startMarkerThread(npcVeh)
    runCountdown(playerVeh, npcVeh)
    TriggerServerEvent('streetkings:npcchallenge:begin', destination.x, destination.y, destination.z)
    local npcVehState = npcVeh and Entity(npcVeh).state
    if npcVehState and npcVehState.skMeetRacer then
        local vehNet = NetworkGetEntityIsNetworked(npcVeh) and NetworkGetNetworkIdFromEntity(npcVeh) or nil
        local pedNet = npcPed and NetworkGetEntityIsNetworked(npcPed)
            and NetworkGetNetworkIdFromEntity(npcPed) or nil
        TriggerServerEvent('streetkings:meet:exemptChallenger', vehNet, pedNet)
    end
    SetEntityAsMissionEntity(npcVeh, true, true)
    SetEntityAsMissionEntity(npcPed, true, true)
    TaskVehicleDriveToCoordLongrange(
        npcPed, npcVeh,
        destination.x, destination.y, destination.z,
        NPC_DRIVE_SPEED, NPC_DRIVE_FLAGS, 5.0
    )

    local raceStart  = GetGameTimer()
    local lastRetask = raceStart

    local won       = nil
    local elapsedMs = 0

    while won == nil do
        Wait(0)
        local ped = PlayerPedId()

        local gs = SKC.GetGameState()
        if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then
            SKNotify({ title = 'Challenge Cancelled', type = 'warning' })
            TriggerServerEvent('streetkings:npcchallenge:cancel')
            cleanup()
            return
        end

        if not IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
            SKNotify({ title = 'Challenge Forfeited', type = 'error' })
            TriggerServerEvent('streetkings:npcchallenge:cancel')
            cleanup()
            return
        end

        local now = GetGameTimer()
        if (now - lastRetask) > RETASK_INTERVAL then
            TaskVehicleDriveToCoordLongrange(
                npcPed, npcVeh,
                destination.x, destination.y, destination.z,
                NPC_DRIVE_SPEED, NPC_DRIVE_FLAGS, 5.0
            )
            lastRetask = now
        end

        local playerPos = GetEntityCoords(ped)
        local npcPos    = GetEntityCoords(npcPed)
        elapsedMs       = now - raceStart

        if #(playerPos - destination) < FINISH_RADIUS then
            won = true
        elseif #(npcPos - destination) < FINISH_RADIUS then
            won = false
        elseif elapsedMs > RACE_TIMEOUT then
            won = false
        end
    end

    SetTimeScale(0.05)
    Wait(250)

    local vehicleModelLabel = SK.GetVehicleModelLabel(playerVeh)
    local amount
    if won then
        amount = lib.callback.await('streetkings:npcchallenge:reward', false, vehClass, elapsedMs, vehicleModelLabel)
    else
        amount = lib.callback.await('streetkings:npcchallenge:penalty', false, vehClass, vehicleModelLabel)
    end

    local cashAmount = amount.cash or 0
    local rewardData = amount.reward or {
        cash = { amount = won and cashAmount or -cashAmount },
    }

    if amount.reward then
        rewardData.cash = { amount = won and cashAmount or -cashAmount }
    end

    SendNUIMessage({
        type    = 'event:results',
        name    = 'Street Challenge',
        elapsed = elapsedMs / 1000.0,
        passed  = won,
        verdict = won and 'YOU WON' or 'YOU LOST',
        summary = amount.reward and amount.reward.summary or '',
        reward  = rewardData,
        continueKey = SKInput.getInteractLabel(),
    })

    local continueKey = SKInput.getInteractLabel()
    while not SKInput.isInteractJustReleased() do
        local nextContinueKey = SKInput.getInteractLabel()
        if nextContinueKey ~= continueKey then
            continueKey = nextContinueKey
            SendNUIMessage({ type = 'event:updateContinueKey', continueKey = continueKey })
        end
        Wait(0)
    end

    SetTimeScale(1.0)
    SendNUIMessage({ type = 'event:hide' })
    cleanup()

    TriggerEvent('streetkings:npcchallenge:finished', { won = won })
end

local declinedNpcs  = {}

local function pruneDeclined()
    for ped in pairs(declinedNpcs) do
        if not DoesEntityExist(ped) then
            declinedNpcs[ped] = nil
        end
    end
end

local function scanNearbyBurnoutVehicles(playerVeh, pickCandidate)
    local fwd      = GetEntityForwardVector(playerVeh)
    local pos      = GetEntityCoords(playerVeh)
    local rightVec = vector3(fwd.y, -fwd.x, 0.0)
    local leftDir  = vector3(-fwd.y, fwd.x, 0.0)

    local rays = {
        { origin = pos + rightVec * 1.5, endPos = pos + rightVec * RAY_LENGTH },
        { origin = pos + leftDir  * 1.5, endPos = pos + leftDir  * RAY_LENGTH },
    }

    for _, ray in ipairs(rays) do
        ray.handle = StartShapeTestRay(
            ray.origin.x, ray.origin.y, ray.origin.z,
            ray.endPos.x, ray.endPos.y, ray.endPos.z,
            10, playerVeh, 0
        )
    end

    Wait(0)

    local playerTier    = getVehTier(playerVeh)
    local bestVeh, bestPed = nil, nil

    for _, ray in ipairs(rays) do
        local result, hit, _, _, hitEntity = GetShapeTestResult(ray.handle)
        ray.hit      = result == 2 and hit == 1
        ray.candidate = false

        if ray.hit and hitEntity ~= 0 and IsEntityAVehicle(hitEntity) then
            local driver = GetPedInVehicleSeat(hitEntity, -1)
            if driver ~= 0 and not IsPedAPlayer(driver) and not declinedNpcs[driver] then
                SetPedConfigFlag(driver, 128, false)
                SetPedFleeAttributes(driver, 0, false)
                if pickCandidate and not bestVeh then
                    local speed   = GetEntitySpeed(hitEntity)
                    local heading = sameRoughHeading(playerVeh, hitEntity)
                    local npcTier = getVehTier(hitEntity)
                    if speed < 1.0 and heading then
                        bestVeh       = hitEntity
                        bestPed       = driver
                        ray.candidate = true
                    end
                end
            end
        end
    end

    return bestVeh, bestPed
end

local scanThread = nil

local function startScanning()
    if scanThread then return end
    burnoutStart = 0
    scanThread = CreateThread(function()
        local function scanAllowed()
            local gs = SKC.GetGameState()
            return gs == GameState.FREEROAM or gs == GameState.MISSION
        end
        while scanAllowed() do
            Wait(250)
            pruneDeclined()

            if challengeActive then
                goto continue
            end

            local missionMode = isInNpcChallengeObjective()

            if not missionMode and GetGameTimer() < cooldownUntil then
                goto continue
            end

            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then
                burnoutStart = 0
                lastCalmBurnout = 0
                goto continue
            end

            if not IsVehicleInBurnout(veh) then
                burnoutStart = 0
                lastCalmBurnout = 0
                goto continue
            end

            if burnoutStart == 0 then
                burnoutStart = GetGameTimer()
            end

            local now = GetGameTimer()
            local burnoutMs = now - burnoutStart
            local burnoutGate = missionMode and BURNOUT_REQ_MISSION or BURNOUT_REQ
            if burnoutMs < burnoutGate then
                if not missionMode and now - lastCalmBurnout >= CALM_BURNOUT_INTERVAL then
                    lastCalmBurnout = now
                    scanNearbyBurnoutVehicles(veh, false)
                end
                goto continue
            end

            local npcVeh, npcPed
            if missionMode then
                npcVeh, npcPed = findClosestMeetRacer(veh)
            else
                npcVeh, npcPed = scanNearbyBurnoutVehicles(veh, true)
            end

            if not npcVeh then
                burnoutStart = 0
                lastCalmBurnout = 0
                cooldownUntil = GetGameTimer() + 2000
                goto continue
            end

            local chance
            if missionMode then
                chance = 100
            else
                local tiersMatch = getVehTier(veh) == getVehTier(npcVeh)
                chance = tiersMatch and TRIGGER_CHANCE or TIER_MISMATCH_CHANCE
            end
            local roll = math.random(1, 100)

            if roll <= chance then
                burnoutStart = 0
                lastCalmBurnout = 0
                cooldownUntil = GetGameTimer() + COOLDOWN_MS
                startChallenge(npcVeh, npcPed)
            else
                burnoutStart = 0
                lastCalmBurnout = 0
                cooldownUntil = GetGameTimer() + 2000
                if npcPed then
                    declinedNpcs[npcPed] = true
                end
                SKNotify({ title = 'They declined to race you!', type = 'warning' })
                if npcPed and DoesEntityExist(npcPed) then
                    playPedSpeech(npcPed, 'GENERIC_NO')
                end
            end

            ::continue::
        end
        scanThread = nil
    end)
end

local function stopScanning()
    scanThread = nil
end

AddEventHandler('streetkings:event:freeroamEnter', startScanning)
AddEventHandler('streetkings:event:freeroamExit', function(nextState)
    if nextState ~= GameState.MISSION then
        stopScanning()
    end
    if challengeActive then
        cleanup()
    end
    declinedNpcs = {}
end)