SKRampage = {}

local MPS_TO_MPH = 2.236936

local MIN_SPEED_MPH       = 15.0
local COOLDOWN_MS         = 8000
local COMBO_WINDOW_MS     = 3000
local COMBO_MAX           = 8
local TICK_INTERVAL_MS    = 500
local CLEANUP_INTERVAL_MS = 2000

local DETECTION_PED = 6.0
local DETECTION_VEH = 8.0
local DETECTION_OBJ = 5.0

local SCORE_PED    = 100
local SCORE_OBJECT = 50

local VEH_CLASS_SCORES = {
    [0]  = 100, -- Compacts
    [1]  = 125, -- Sedans
    [2]  = 150, -- SUVs
    [3]  = 125, -- Coupes
    [4]  = 175, -- Muscle
    [5]  = 150, -- Sports Classics
    [6]  = 200, -- Sports
    [7]  = 250, -- Super
    [8]  = 75,  -- Motorcycles
    [9]  = 125, -- Off-road
    [10] = 150, -- Industrial
    [11] = 100, -- Utility
    [12] = 150, -- Vans
    [13] = 50,  -- Cycles
    [14] = 300, -- Emergency
    [15] = 200, -- Military
    [16] = 75,  -- Commercial
    [17] = 75,  -- Trains
    [18] = 75,  -- Boats
    [19] = 100, -- Helicopters
    [20] = 100, -- Planes
    [21] = 75,  -- Service
    [22] = 200, -- Emergency
}

local function getVehicleHitScore(targetVeh)
    return VEH_CLASS_SCORES[GetVehicleClass(targetVeh)] or 100
end

local function isPlayerWasted(vehicle)
    local ped = PlayerPedId()
    return IsEntityDead(ped)
        or IsPedDeadOrDying(ped, true)
        or IsPedFatallyInjured(ped)
        or not DoesEntityExist(vehicle)
        or IsEntityDead(vehicle)
        or IsVehicleDriveable(vehicle) == false
end

function SKRampage.run(def, vehicle, ped)
    local score       = 0
    local cooldowns   = {}
    local lastHitTime = 0
    local combo       = 0
    local lastTick    = 0
    local lastCleanup = 0
    local endTime     = GetGameTimer() + def.duration * 1000

    TriggerServerEvent('streetkings:events:beginRampage', def.id)
    SendNUIMessage({
        type     = 'rampage:show',
        duration = def.duration,
    })

    while GetGameTimer() < endTime do
        if SKC.GetGameState() ~= GameState.EVENT then break end
        if isPlayerWasted(vehicle) then break end

        local now        = GetGameTimer()
        local remaining  = math.max(0, endTime - now)
        local vehCoords  = GetEntityCoords(vehicle)
        local speed      = GetEntitySpeed(vehicle) * MPS_TO_MPH

        if speed >= MIN_SPEED_MPH and HasEntityCollidedWithAnything(vehicle) then
            local pts = 0
            local hit = false

            for _, targetPed in ipairs(GetGamePool('CPed')) do
                if targetPed ~= ped
                    and DoesEntityExist(targetPed)
                    and not IsPedAPlayer(targetPed)
                    and not cooldowns[targetPed]
                    and #(GetEntityCoords(targetPed) - vehCoords) < DETECTION_PED
                then
                    pts = SCORE_PED
                    cooldowns[targetPed] = now + COOLDOWN_MS
                    hit = true
                    break
                end
            end

            if not hit then
                for _, targetVeh in ipairs(GetGamePool('CVehicle')) do
                    if targetVeh ~= vehicle
                        and DoesEntityExist(targetVeh)
                        and not cooldowns[targetVeh]
                        and #(GetEntityCoords(targetVeh) - vehCoords) < DETECTION_VEH
                    then
                        pts = getVehicleHitScore(targetVeh)
                        cooldowns[targetVeh] = now + COOLDOWN_MS
                        hit = true
                        break
                    end
                end
            end

            if not hit then
                for _, obj in ipairs(GetGamePool('CObject')) do
                    if DoesEntityExist(obj)
                        and IsEntityAnObject(obj)
                        and not IsEntityStatic(obj)
                        and not cooldowns[obj]
                        and #(GetEntityCoords(obj) - vehCoords) < DETECTION_OBJ
                    then
                        pts = SCORE_OBJECT
                        cooldowns[obj] = now + COOLDOWN_MS
                        hit = true
                        break
                    end
                end
            end

            if hit and pts > 0 then
                local speedMult = 1.0 + math.min(1.0, speed / 60.0)
                pts = math.floor(pts * speedMult)

                if (now - lastHitTime) < COMBO_WINDOW_MS then
                    combo = math.min(combo + 1, COMBO_MAX)
                else
                    combo = 1
                end
                lastHitTime = now

                local comboMult = 1.0 + (combo - 1) * 0.15
                pts = math.floor(pts * comboMult)

                score = score + pts

                SendNUIMessage({
                    type      = 'rampage:hit',
                    score     = score,
                    combo     = combo,
                    gained    = pts,
                    remaining = remaining,
                })
            end
        end

        if now - lastTick >= TICK_INTERVAL_MS then
            lastTick = now
            SendNUIMessage({
                type      = 'rampage:tick',
                remaining = remaining,
                score     = score,
            })
        end

        if now - lastCleanup >= CLEANUP_INTERVAL_MS then
            lastCleanup = now
            for entity, expiry in pairs(cooldowns) do
                if now > expiry then cooldowns[entity] = nil end
            end
        end

        Wait(50)
    end

    SendNUIMessage({ type = 'rampage:end' })

    if SKC.GetGameState() ~= GameState.EVENT then return end

    local wasted = isPlayerWasted(vehicle)

    if not wasted then
        SetTimeScale(0.3)
        Wait(400)
        SetTimeScale(1.0)
    end

    local submitResult
    if score > 0 then
        submitResult = lib.callback.await('streetkings:events:submitTime', false, def.id, score, SK.GetVehicleModelLabel(vehicle))
        if submitResult and submitResult.reward and submitResult.reward.summary ~= '' then
            SKNotify({ title = submitResult.reward.summary, type = 'success', duration = 3500 })
        end
    end
    if not wasted then
        SendNUIMessage({
            type        = 'event:results',
            name        = def.name,
            rampage     = true,
            wasted      = wasted,
            score       = { total = score },
            reward      = submitResult and submitResult.reward or nil,
            continueKey = SKInput.getInteractLabel(),
        })
    else
        SKC.Wasted()
        return
    end

    local leaderboardData = lib.callback.await('streetkings:events:getLeaderboard', false, def.id, LeaderboardPeriod.ALL) or {}
    local personalBest    = lib.callback.await('streetkings:events:getPersonalBest', false, def.id)
    SendNUIMessage({
        type         = 'event:leaderboard',
        entries      = leaderboardData,
        personalBest = personalBest,
        period       = LeaderboardPeriod.ALL,
        scoreType    = 'points',
        eventId      = def.id,
    })


    local continueKey = SKInput.getInteractLabel()
    while not SKInput.isInteractJustReleased() do
        local nextKey = SKInput.getInteractLabel()
        if nextKey ~= continueKey then
            continueKey = nextKey
            SendNUIMessage({ type = 'event:updateContinueKey', continueKey = continueKey })
        end
        if SKC.GetGameState() ~= GameState.EVENT then break end
        Wait(0)
    end
    SendNUIMessage({ type = 'event:hide' })
    SKC.SetGameState(GameState.FREEROAM)
end