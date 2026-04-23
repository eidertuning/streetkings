SKStuntActiveId = nil

local activeJumps   = {}
local cooldowns     = {}
local attemptActive = false

local COOLDOWN_MS          = 3000
local MPS_TO_MPH           = 2.236936
local MIN_LAUNCH_SPEED_MPH = 15.0
local RESULTS_TIMEOUT_MS   = 8000
local ZONE_VISIT_WINDOW_MS = 5000
local ZONE_EXIT_GRACE_MS   = 1000
local LANDING_ZONE_GRACE_MS = 2000

local BLIP_CAT_STUNT = 16
local blipCatRegistered = false

local function registerStuntBlipCategory()
    if blipCatRegistered then return end
    blipCatRegistered = true
    AddTextEntry(('BLIP_CAT_%d'):format(BLIP_CAT_STUNT), 'Stunt Jumps')
end

local function normalizeAngle(a)
    a = a % 360.0
    if a > 180.0 then a = a - 360.0 end
    if a < -180.0 then a = a + 360.0 end
    return a
end

local function toVec3(v)
    if type(v) == 'vector3' then return v end
    if type(v) == 'table' then
        if v.x  then return vector3(v.x,  v.y,  v.z)  end
        if v[1] then return vector3(v[1], v[2], v[3]) end
    end
    return v
end

local function normalizeZone(zone)
    if not zone then return nil end
    zone.center = toVec3(zone.center)
    if zone.shape == 'box' and zone.size then
        local sz = toVec3(zone.size)
        local sx, sy = sz.x, sz.y
        zone.radius = math.max(sx, sy) * 0.5
        zone.shape, zone.size, zone.rotation = nil, nil, nil
    end
    if zone.ramp and zone.ramp.coords then
        zone.ramp.coords = toVec3(zone.ramp.coords)
    end
    return zone
end

local function normalizeDef(def)
    if def.zoneA then normalizeZone(def.zoneA) end
    if def.zoneB then normalizeZone(def.zoneB) end
    return def
end

local LANDING_GRACE_MS       = 500
local SETTLE_TIMEOUT_MS      = 3000
local AIR_FLICKER_GRACE_MS   = 200

local SPIN_TIERS = {
    { threshold = 540, bonus = 200 },
    { threshold = 360, bonus = 120 },
    { threshold = 160, bonus = 60 },
    { threshold = 95,  bonus = 25 },
}
local BARREL_ROLL_BONUS = 150

local function calculateTrickBonus(yawDeg, rollDeg)
    local bonus = 0
    for _, tier in ipairs(SPIN_TIERS) do
        if yawDeg >= tier.threshold then
            bonus = tier.bonus
            break
        end
    end
    local barrelRolls = math.floor(rollDeg / 360.0)
    bonus = bonus + barrelRolls * BARREL_ROLL_BONUS
    return bonus, barrelRolls
end

local function calculateScore(launchSpeed, totalYaw, totalRoll, airDistance)
    local base       = 15
    local speedBonus = math.floor(launchSpeed * 0.35)
    local trickBonus, barrelRolls = calculateTrickBonus(totalYaw, totalRoll)
    local distBonus  = math.floor(airDistance * 0.6)
    return {
        base       = base,
        speed      = speedBonus,
        trick      = trickBonus,
        distance   = distBonus,
        total      = base + speedBonus + trickBonus + distBonus,
        rawYaw     = totalYaw,
        rawRoll    = totalRoll,
        rawBarrel  = barrelRolls,
        rawSpeed   = launchSpeed,
        rawDist    = airDistance,
    }
end

local function spawnRampProp(rampDef)
    if not rampDef or not rampDef.model or not rampDef.coords then return nil end
    local hash = SK.LoadModel(rampDef.model, 10000)
    if not hash then
        print(('[SK:StuntJumps] Failed to load model: %s'):format(tostring(rampDef.model)))
        return nil
    end
    local c = rampDef.coords
    local obj = CreateObjectNoOffset(hash, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(obj, rampDef.heading or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SK.UnloadModel(hash)
    return obj
end

local function runAirborneTracking(jumpId, def, state, vehicle, ped)
    TriggerServerEvent('streetkings:events:beginStuntJump', jumpId)
    local launchZoneKey = state.lastVisitedZone
    local targetZone    = launchZoneKey == 'a' and def.zoneB or def.zoneA
    local targetCenter  = targetZone.center
    local targetRadius  = targetZone.radius or 10.0

    local launchSpeed = state.launchSpeed
    local launchPos   = GetEntityCoords(vehicle)

    local prevHeading    = GetEntityHeading(vehicle)
    local prevRoll       = GetEntityRoll(vehicle)
    local totalYaw       = 0.0
    local totalRoll      = 0.0
    local phase          = 'air'
    local cleanLanding   = false
    local crashDetected  = false
    local settleStart    = nil
    local wheelsAccum    = 0
    local lastWheelsTime = nil
    local airGapStart    = nil

    while true do
        local _gs = SKC.GetGameState()
        if _gs ~= GameState.FREEROAM then
            state.phase = 'idle'
            state.lastVisitedZone = nil
            attemptActive = false
            return
        end
        local now      = GetGameTimer()
        local inAirNow = IsEntityInAir(vehicle)
        local onWheels = IsVehicleOnAllWheels(vehicle)
        local grounded = not inAirNow or onWheels

        if IsEntityDead(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then break end

        if IsEntityUpsidedown(vehicle) then
            crashDetected = true
        end

        if phase == 'air' then
            local heading = GetEntityHeading(vehicle)
            local roll    = GetEntityRoll(vehicle)
            totalYaw  = totalYaw + math.abs(normalizeAngle(heading - prevHeading))
            totalRoll = totalRoll + math.abs(normalizeAngle(roll - prevRoll))
            prevHeading = heading
            prevRoll    = roll

            if grounded then
                phase         = 'settling'
                settleStart   = now
                wheelsAccum   = 0
                lastWheelsTime = onWheels and now or nil
                airGapStart   = nil
            end
        elseif phase == 'settling' then
            local heading = GetEntityHeading(vehicle)
            local roll    = GetEntityRoll(vehicle)
            totalYaw  = totalYaw + math.abs(normalizeAngle(heading - prevHeading))
            totalRoll = totalRoll + math.abs(normalizeAngle(roll - prevRoll))
            prevHeading = heading
            prevRoll    = roll

            if grounded then
                airGapStart = nil
                if onWheels then
                    if lastWheelsTime then
                        wheelsAccum = wheelsAccum + (now - lastWheelsTime)
                    end
                    lastWheelsTime = now
                else
                    lastWheelsTime = nil
                end
            else
                lastWheelsTime = nil
                if not airGapStart then
                    airGapStart = now
                elseif now - airGapStart > AIR_FLICKER_GRACE_MS then
                    phase       = 'air'
                    settleStart = nil
                    wheelsAccum = 0
                    airGapStart = nil
                end
            end

            if wheelsAccum >= LANDING_GRACE_MS then
                cleanLanding = true
                break
            end

            if settleStart and now - settleStart > SETTLE_TIMEOUT_MS then
                break
            end
        end

        DrawMarker(1, targetCenter.x, targetCenter.y, targetCenter.z, 0, 0, 0, 0, 0, 0,
            targetRadius * 2, targetRadius * 2, 1.0, 0, 200, 255, 80, false, true, 2, false, nil, nil, false)

        Wait(0)
    end

    local now = GetGameTimer()
    local inTarget
    if launchZoneKey == 'a' then
        inTarget = state.inZoneB
            or (state.exitTimeB and (now - state.exitTimeB) < LANDING_ZONE_GRACE_MS)
    else
        inTarget = state.inZoneA
            or (state.exitTimeA and (now - state.exitTimeA) < LANDING_ZONE_GRACE_MS)
    end
    if not inTarget then
        local landPos = GetEntityCoords(vehicle)
        inTarget = #(landPos - targetCenter) < targetRadius
    end
    local alive = not IsEntityDead(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped
    cooldowns[jumpId] = GetGameTimer() + COOLDOWN_MS
    state.phase = 'idle'
    state.lastVisitedZone = nil
    state.wasGrounded = false

    if not inTarget or not alive or crashDetected or not cleanLanding then
        attemptActive = false
        return
    end

    local landPos       = GetEntityCoords(vehicle)
    local airDistance    = #(landPos - launchPos)
    print(('[SK:StuntJumps] DEBUG | yaw=%.1f roll=%.1f barrels=%d | dist=%.1f speed=%.1f'):format(
        totalYaw, totalRoll, math.floor(totalRoll / 360.0), airDistance, launchSpeed))
    local score         = calculateScore(launchSpeed, totalYaw, totalRoll, airDistance)

    local submitResult = lib.callback.await('streetkings:events:submitTime', false, jumpId, score.total, SK.GetVehicleModelLabel(vehicle))
    if submitResult and submitResult.reward and submitResult.reward.summary ~= '' then
        SKNotify({ title = submitResult.reward.summary, type = 'success', duration = 3500 })
    end

    Wait(3000)
    SKStuntActiveId = jumpId
    SendNUIMessage({
        type        = 'event:results',
        name        = def.name,
        stunt       = true,
        landed      = true,
        score       = score,
        summary     = submitResult and submitResult.reward and submitResult.reward.summary or '',
        reward      = submitResult and submitResult.reward or nil,
        continueKey = SKInput.getInteractLabel(),
    })

    local leaderboardData = lib.callback.await('streetkings:events:getLeaderboard', false, jumpId, LeaderboardPeriod.ALL) or {}
    local personalBest = lib.callback.await('streetkings:events:getPersonalBest', false, jumpId)
    SendNUIMessage({
        type         = 'event:leaderboard',
        entries      = leaderboardData,
        personalBest = personalBest,
        period       = LeaderboardPeriod.ALL,
        scoreType    = 'points',
        eventId      = jumpId,
    })

    local deadline = GetGameTimer() + RESULTS_TIMEOUT_MS
    while GetGameTimer() < deadline do
        if SKInput.isInteractJustReleased() then break end
        local _gs2 = SKC.GetGameState()
        if _gs2 ~= GameState.FREEROAM then break end
        Wait(0)
    end

    SendNUIMessage({ type = 'event:hide' })
    SKStuntActiveId = nil
    attemptActive = false
end

local function teardownJump(jumpId)
    local entry = activeJumps[jumpId]
    if not entry then return end

    if entry.outerPoint then entry.outerPoint:remove() end
    if entry.innerZoneA then entry.innerZoneA:remove() end
    if entry.innerZoneB then entry.innerZoneB:remove() end

    for i = 1, #entry.props do
        if DoesEntityExist(entry.props[i]) then DeleteEntity(entry.props[i]) end
    end

    if entry.blip and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end

    activeJumps[jumpId] = nil
end

local function setupJump(jumpId, def)
    if activeJumps[jumpId] then teardownJump(jumpId) end
    if not def.zoneA or not def.zoneB then return end
    if not def.zoneA.center or not def.zoneB.center then return end

    normalizeDef(def)
    if def.zoneA.ramp and def.zoneA.ramp.model then SK.LoadModel(def.zoneA.ramp.model, 10000) end
    if def.zoneB.ramp and def.zoneB.ramp.model then SK.LoadModel(def.zoneB.ramp.model, 10000) end

    local props = {}
    local propA = spawnRampProp(def.zoneA.ramp)
    if propA then props[#props + 1] = propA end
    local propB = spawnRampProp(def.zoneB.ramp)
    if propB then props[#props + 1] = propB end

    local ac = def.zoneA.center
    local bc = def.zoneB.center
    registerStuntBlipCategory()
    local blip = AddBlipForCoord(ac.x, ac.y, ac.z)
    SetBlipSprite(blip, 500)
    SetBlipColour(blip, 46)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    SetBlipCategory(blip, BLIP_CAT_STUNT)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(def.name)
    EndTextCommandSetBlipName(blip)

    local radiusA = def.zoneA.radius or 10.0
    local radiusB = def.zoneB.radius or 10.0

    local state = {
        inZoneA         = false,
        inZoneB         = false,
        exitTimeA       = nil,
        exitTimeB       = nil,
        lastVisitedZone = nil,
        lastVisitTime   = 0,
        launchSpeed     = 0,
        phase           = 'idle',
        wasGrounded     = false,
    }

    local function createInnerZone(zoneDef, radius, onEnter, onExit)
        return lib.zones.sphere({
            coords  = zoneDef.center,
            radius  = radius,
            onEnter = onEnter,
            onExit  = onExit,
        })
    end

    local innerZoneA = createInnerZone(def.zoneA, radiusA, function()
        state.inZoneA = true
        state.lastVisitedZone = 'a'
        state.lastVisitTime = GetGameTimer()
    end, function()
        state.inZoneA = false
        state.exitTimeA = GetGameTimer()
    end)

    local innerZoneB = createInnerZone(def.zoneB, radiusB, function()
        state.inZoneB = true
        state.lastVisitedZone = 'b'
        state.lastVisitTime = GetGameTimer()
    end, function()
        state.inZoneB = false
        state.exitTimeB = GetGameTimer()
    end)

    local mx, my, mz = (ac.x + bc.x) / 2, (ac.y + bc.y) / 2, (ac.z + bc.z) / 2
    local halfDist    = #(ac - bc) / 2
    local outerRadius = halfDist + math.max(radiusA, radiusB) + 50.0

    local outerPoint = lib.points.new({
        coords   = vector3(mx, my, mz),
        distance = outerRadius,
        onEnter  = function()
            if state.phase == 'idle' then
                state.lastVisitedZone = nil
            end
        end,
        nearby = function()
            if state.phase ~= 'idle' then return end
            if attemptActive then return end
            if Cinematic then return end
            local _gs3 = SKC.GetGameState()
            if _gs3 ~= GameState.FREEROAM then return end

            local now = GetGameTimer()
            if cooldowns[jumpId] and now < cooldowns[jumpId] then return end
            if not state.lastVisitedZone then return end
            if (now - state.lastVisitTime) > ZONE_VISIT_WINDOW_MS then return end

            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then return end

            local inAir = IsEntityInAir(veh)
            local speed = GetEntitySpeed(veh) * MPS_TO_MPH

            local recentlyInZone = (state.inZoneA or state.inZoneB)
                or (state.exitTimeA and (now - state.exitTimeA) < ZONE_EXIT_GRACE_MS)
                or (state.exitTimeB and (now - state.exitTimeB) < ZONE_EXIT_GRACE_MS)

            if not inAir then
                if speed >= MIN_LAUNCH_SPEED_MPH and recentlyInZone then
                    state.wasGrounded = true
                    state.launchSpeed = speed
                end
                return
            end

            if not state.wasGrounded then
                if speed < MIN_LAUNCH_SPEED_MPH then return end
                state.launchSpeed = speed
            end

            state.phase = 'airborne'
            attemptActive = true

            CreateThread(function()
                local ok, err = pcall(runAirborneTracking, jumpId, def, state, veh, ped)
                if not ok then
                    print(('[SK:StuntJumps] Error: %s'):format(tostring(err)))
                    SetTimeScale(1.0)
                    SendNUIMessage({ type = 'event:hide' })
                    SKStuntActiveId = nil
                    state.phase = 'idle'
                    state.wasGrounded = false
                    attemptActive = false
                end
            end)
        end,
    })

    activeJumps[jumpId] = {
        def        = def,
        outerPoint = outerPoint,
        innerZoneA = innerZoneA,
        innerZoneB = innerZoneB,
        state      = state,
        props      = props,
        blip       = blip,
    }
end

local function clearAllJumps()
    for jumpId in pairs(activeJumps) do
        teardownJump(jumpId)
    end
    cooldowns = {}
end

local function setupAllJumps()
    clearAllJumps()

    local dbJumps = lib.callback.await('streetkings:stunts:load', false)
    if dbJumps then
        SKStuntJumps = SKStuntJumps or {}
        for id, def in pairs(dbJumps) do
            def.id = def.id or id
            SKStuntJumps[id] = def
        end
    end

    if SKStuntJumps then
        for id, def in pairs(SKStuntJumps) do
            setupJump(id, def)
        end
    end
end

RegisterNetEvent('streetkings:stunts:sync', function(jumpId, def)
    SKStuntJumps = SKStuntJumps or {}
    SKStuntJumps[jumpId] = def
    setupJump(jumpId, def)
end)

RegisterNetEvent('streetkings:stunts:removed', function(jumpId)
    teardownJump(jumpId)
    if SKStuntJumps then SKStuntJumps[jumpId] = nil end
end)

local jumpsActive = false

CreateThread(function()
    Wait(500)
    while true do
        local gs = SKC.GetGameState()
        if gs == GameState.FREEROAM then
            if not jumpsActive then
                setupAllJumps()
                jumpsActive = true
            end
        else
            if jumpsActive then
                clearAllJumps()
                jumpsActive = false
            end
        end
        Wait(1000)
    end
end)

exports('SetupTestJump', function(id, def) setupJump(id, def) end)
exports('TeardownTestJump', function(id) teardownJump(id) end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        clearAllJumps()
    end
end)