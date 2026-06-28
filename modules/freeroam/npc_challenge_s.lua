local REWARD_MIN     = 18
local REWARD_MAX     = 48
local COOLDOWN_MS    = 30000
local lastChallenge  = {}
local activeChallenges = {}

local CHALLENGE_DEST_MIN = 800.0
local CHALLENGE_DEST_MAX = 1400.0
local CHALLENGE_DEST_MARGIN = 150.0
local CHALLENGE_FINISH_RADIUS = 75.0
local CHALLENGE_ELAPSED_GRACE_MS = 3000
local CHALLENGE_TIMEOUT_MS = 3 * 60 * 1000

---@param source integer
---@return string
local function challengerLabel(source)
    return ('%s (%d)'):format(GetPlayerName(source) or 'unknown', source)
end

---@param message string
local function printChallengeTolerance(message)
    print(('^3[SK:NPC] %s^7'):format(message))
end

---@param message string
local function printChallengeReject(message)
    print(('^1[SK:NPC] %s^7'):format(message))
end

local NPC_FIRST_PLAYER_XP = 11
local NPC_FIRST_VEHICLE_XP = 9
local NPC_IMPROVED_PLAYER_XP = 5
local NPC_IMPROVED_VEHICLE_XP = 4

local CLASS_MULTIPLIER = {
    [7]  = 1.35,
    [6]  = 1.25,
    [5]  = 1.15,
    [4]  = 1.12,
    [3]  = 1.08,
    [9]  = 1.2,
}

---@param a vector3
---@param b vector3
---@return number
local function distanceBetween(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---@param source integer
---@return integer, integer, vector3
local function getPlayerChallengeState(source)
    local ped = GetPlayerPed(source)
    local vehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    return ped, vehicle, coords
end

---@param source integer
local function clearChallenge(source)
    activeChallenges[source] = nil
end

---@param value any
---@return boolean
local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@param source integer
---@param x number
---@param y number
---@param z number
local function beginChallenge(source, x, y, z)
    if not SKSaves.hasActiveSave(source) then
        return
    end

    if not isFiniteNumber(x) or not isFiniteNumber(y) or not isFiniteNumber(z) then
        printChallengeReject(('%s sent invalid challenge destination | x=%s | y=%s | z=%s'):format(
            challengerLabel(source),
            tostring(x),
            tostring(y),
            tostring(z)
        ))
        return
    end

    local ped, vehicle, coords = getPlayerChallengeState(source)
    if ped == 0 or vehicle == 0 then
        printChallengeReject(('%s failed challenge start validation due to player state'):format(challengerLabel(source)))
        return
    end

    local destination = vector3(x, y, z)
    local distanceToDestination = distanceBetween(coords, destination)
    if distanceToDestination < (CHALLENGE_DEST_MIN - CHALLENGE_DEST_MARGIN) or distanceToDestination > (CHALLENGE_DEST_MAX + CHALLENGE_DEST_MARGIN) then
        printChallengeReject(('%s failed challenge start validation | distance=%.2f | allowed=%.2f-%.2f'):format(
            challengerLabel(source),
            distanceToDestination,
            CHALLENGE_DEST_MIN - CHALLENGE_DEST_MARGIN,
            CHALLENGE_DEST_MAX + CHALLENGE_DEST_MARGIN
        ))
        return
    end

    if distanceToDestination < CHALLENGE_DEST_MIN or distanceToDestination > CHALLENGE_DEST_MAX then
        printChallengeTolerance(('%s challenge start accepted within destination margin | distance=%.2f | target=%.2f-%.2f | margin=%.2f'):format(
            challengerLabel(source),
            distanceToDestination,
            CHALLENGE_DEST_MIN,
            CHALLENGE_DEST_MAX,
            CHALLENGE_DEST_MARGIN
        ))
    end

    activeChallenges[source] = {
        startedAt = GetGameTimer(),
        destination = destination,
        vehicleModel = GetEntityModel(vehicle),
    }
end

---@param source integer
---@param elapsedMs integer
---@return boolean
local function validateChallengeReward(source, elapsedMs)
    local challenge = activeChallenges[source]
    if not challenge then
        printChallengeReject(('%s has no active challenge state'):format(challengerLabel(source)))
        return false
    end

    local now = GetGameTimer()
    if (now - challenge.startedAt) > CHALLENGE_TIMEOUT_MS then
        clearChallenge(source)
        printChallengeReject(('%s challenge expired | elapsed=%dms | timeout=%dms'):format(
            challengerLabel(source),
            now - challenge.startedAt,
            CHALLENGE_TIMEOUT_MS
        ))
        return false
    end

    local ped, vehicle, coords = getPlayerChallengeState(source)
    if ped == 0 or vehicle == 0 then
        printChallengeReject(('%s reward rejected due to invalid player state'):format(challengerLabel(source)))
        return false
    end

    if challenge.vehicleModel ~= GetEntityModel(vehicle) then
        printChallengeReject(('%s reward rejected due to vehicle mismatch | expected=%s | got=%s'):format(
            challengerLabel(source),
            tostring(challenge.vehicleModel),
            tostring(GetEntityModel(vehicle))
        ))
        return false
    end

    local finishDistance = distanceBetween(coords, challenge.destination)
    if finishDistance > CHALLENGE_FINISH_RADIUS then
        printChallengeReject(('%s reward rejected by finish position | distance=%.2f | allowed=%.2f'):format(
            challengerLabel(source),
            finishDistance,
            CHALLENGE_FINISH_RADIUS
        ))
        return false
    end

    if finishDistance > (CHALLENGE_FINISH_RADIUS * 0.6) then
        printChallengeTolerance(('%s reward accepted near finish tolerance | distance=%.2f / %.2f'):format(
            challengerLabel(source),
            finishDistance,
            CHALLENGE_FINISH_RADIUS
        ))
    end

    local serverElapsedMs = now - challenge.startedAt
    local elapsedDeltaMs = serverElapsedMs - elapsedMs
    if elapsedMs + CHALLENGE_ELAPSED_GRACE_MS < serverElapsedMs then
        printChallengeReject(('%s reward rejected by elapsed mismatch | client=%dms | server=%dms | delta=%dms | grace=%dms'):format(
            challengerLabel(source),
            elapsedMs,
            serverElapsedMs,
            elapsedDeltaMs,
            CHALLENGE_ELAPSED_GRACE_MS
        ))
        return false
    end

    if elapsedDeltaMs > 250 then
        printChallengeTolerance(('%s reward accepted within elapsed grace | client=%dms | server=%dms | delta=%dms | grace=%dms'):format(
            challengerLabel(source),
            elapsedMs,
            serverElapsedMs,
            elapsedDeltaMs,
            CHALLENGE_ELAPSED_GRACE_MS
        ))
    end

    return true
end

RegisterNetEvent('streetkings:npcchallenge:begin', function(x, y, z)
    beginChallenge(source --[[@as integer]], x, y, z)
end)

RegisterNetEvent('streetkings:npcchallenge:cancel', function()
    clearChallenge(source --[[@as integer]])
end)

local function normalizedClass(vehClass)
    if type(vehClass) ~= 'number' or vehClass < 0 or vehClass > 22 then
        return 0
    end
    return vehClass
end

local function rollStake(vehClass)
    local mult = CLASS_MULTIPLIER[normalizedClass(vehClass)] or 1.0
    return math.floor(math.random(REWARD_MIN, REWARD_MAX) * mult)
end

AddEventHandler('playerDropped', function()
    lastChallenge[source] = nil
    activeChallenges[source] = nil
end)

lib.callback.register('streetkings:npcchallenge:reward', function(src, vehClass, elapsedMs, vehicleModel)
    if not SKSaves.hasActiveSave(src) then
        return { cash = 0, reward = nil }
    end

    local now = GetGameTimer()
    if lastChallenge[src] and (now - lastChallenge[src]) < COOLDOWN_MS then
        return { cash = 0, reward = nil }
    end
    lastChallenge[src] = now

    if type(elapsedMs) ~= 'number' or elapsedMs <= 0 then
        clearChallenge(src)
        return { cash = 0, reward = nil }
    end

    elapsedMs = math.floor(elapsedMs)
    if not validateChallengeReward(src, elapsedMs) then
        clearChallenge(src)
        return { cash = 0, reward = nil }
    end
    clearChallenge(src)

    local reward = rollStake(vehClass)
    local current = SKSaves.read(src, 'economy.cash') or 0
    SKSaves.write(src, 'economy.cash', current + reward)
    SKStats.increment(src, 'totalCashEarned', reward)
    SKStats.increment(src, 'npcChallengesWon', 1)

    local document = SKSaves.getDocument(src)
    if not document then
        TriggerEvent('streetkings:server:recordNpcRace', src, true, vehicleModel)
        if SKLogs then
            SKLogs.Emit('npcRace', {
                source = src,
                won = true,
                elapsedMs = elapsedMs,
                vehicleModel = vehicleModel,
                vehicleClass = vehClass,
                cash = reward,
            })
        end
        return { cash = reward, reward = nil }
    end
    local progression = document.progression
    local _, vehicleEntry = SKProgression.getActiveVehicleEntry(src)
    local vehicleData = vehicleEntry and vehicleEntry.data or nil

    local playerReward = { xpGained = 0, oldLevel = progression.level, newLevel = progression.level, levelUps = {} }
    local vehicleReward = { xpGained = 0, oldLevel = vehicleData and vehicleData.level or 1, newLevel = vehicleData and vehicleData.level or 1, unlocks = {} }
    local rewardData = nil
    local playerFirst = false
    local playerImproved = false

    if vehicleData and type(elapsedMs) == 'number' and elapsedMs > 0 then
        local score = math.floor(elapsedMs)
        playerFirst, playerImproved = SKProgression.recordActivityBest(progression.bestActivityScores, 'npc_street', score, 'time')
        local vehicleFirst, vehicleImproved = SKProgression.recordActivityBest(vehicleData.bestActivityScores, 'npc_street', score, 'time')

        SKSaves.write(src, 'progression.bestActivityScores', progression.bestActivityScores)
        SKSaves.write(src, 'garage.vehicles.' .. document.garage.activeVehicleId .. '.data.bestActivityScores', vehicleData.bestActivityScores)

        playerReward = SKProgression.awardPlayerXp(src, playerImproved and (playerFirst and NPC_FIRST_PLAYER_XP or NPC_IMPROVED_PLAYER_XP) or 0)
        vehicleReward = SKProgression.awardVehicleXp(src, vehicleImproved and (vehicleFirst and NPC_FIRST_VEHICLE_XP or NPC_IMPROVED_VEHICLE_XP) or 0)
        local unlockMessage = SKProgression.buildVehicleUnlockMessage(vehicleReward)

        if unlockMessage ~= '' then
            SKMessages.enqueueUnlockMessage(src, unlockMessage)
        end

        rewardData = {
            player = playerReward,
            vehicle = vehicleReward,
            summary = SKProgression.buildRewardSummary({
                player = playerReward,
                vehicle = vehicleReward,
            }),
            awarded = playerReward.xpGained > 0 or vehicleReward.xpGained > 0,
        }
    end

    TriggerEvent('streetkings:server:recordNpcRace', src, true, vehicleModel)
    if SKLogs then
        SKLogs.Emit('npcRace', {
            source = src,
            won = true,
            elapsedMs = elapsedMs,
            vehicleModel = vehicleModel,
            vehicleClass = vehClass,
            cash = reward,
            reward = rewardData,
        })
    end
    TriggerEvent('streetkings:messages:trigger', src, 'activityCompleted', {
        eventId = 'npc_street',
        scoreType = 'time',
    })
    if playerFirst then
        TriggerEvent('streetkings:messages:trigger', src, 'firstActivityCompleted', {
            eventId = 'npc_street',
            scoreType = 'time',
        })
    end

    return {
        cash = reward,
        reward = rewardData,
    }
end)

lib.callback.register('streetkings:npcchallenge:penalty', function(src, vehClass, vehicleModel)
    if not SKSaves.hasActiveSave(src) then
        return { cash = 0 }
    end

    local now = GetGameTimer()
    if lastChallenge[src] and (now - lastChallenge[src]) < COOLDOWN_MS then
        return { cash = 0 }
    end
    lastChallenge[src] = now
    clearChallenge(src)

    local stake    = rollStake(vehClass)
    local current  = SKSaves.read(src, 'economy.cash') or 0
    local deducted = math.min(current, stake)
    SKSaves.write(src, 'economy.cash', math.max(0, current - stake))
    SKStats.increment(src, 'totalCashSpent', deducted)

    TriggerEvent('streetkings:server:recordNpcRace', src, false, vehicleModel)
    if SKLogs then
        SKLogs.Emit('npcRace', {
            source = src,
            won = false,
            vehicleModel = vehicleModel,
            vehicleClass = vehClass,
            cash = -deducted,
        })
    end
    return { cash = stake }
end)
