SKExEventValidation = {}

local SPEED_CAM_WINDOW_MS  = 60000
local STUNT_JUMP_WINDOW_MS = 60000
local SPEED_CAM_RADIUS     = 80.0
local STUNT_JUMP_RADIUS    = 80.0
local RAMPAGE_START_RADIUS = 80.0
local MAX_SPEED_MPH        = 300
local MAX_STUNT_SCORE      = 50000

local speedCamById = {}
for _, cam in ipairs(SKSpeedCameras or {}) do
    speedCamById[cam.id] = cam
end

local activeAttempts = {}

---@param message string
local function printReject(message)
    print(('^1[SK:ExEvent] %s^7'):format(message))
end

---@param source integer
---@return string
local function playerLabel(source)
    return ('%s (%d)'):format(GetPlayerName(source) or 'unknown', source)
end

---@param a vector3|table
---@param b vector3|table
---@return number
local function distBetween(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

AddEventHandler('playerDropped', function()
    activeAttempts[source] = nil
end)

---@param source integer
function SKExEventValidation.clearAttempt(source)
    activeAttempts[source] = nil
end

RegisterNetEvent('streetkings:events:beginSpeedCam', function(camId)
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then return end
    if type(camId) ~= 'string' then return end

    local cam = speedCamById[camId]
    if not cam then
        printReject(('%s attempted unknown speed cam: %s'):format(playerLabel(src), camId))
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    if GetVehiclePedIsIn(ped, false) == 0 then
        printReject(('%s began speed cam while on foot: %s'):format(playerLabel(src), camId))
        return
    end

    local dist = distBetween(GetEntityCoords(ped), cam.coords)
    if dist > SPEED_CAM_RADIUS then
        printReject(('%s began speed cam too far | cam=%s | dist=%.2f | allowed=%.2f'):format(
            playerLabel(src), camId, dist, SPEED_CAM_RADIUS))
        return
    end

    activeAttempts[src] = {
        type      = 'speedcam',
        eventId   = camId,
        startedAt = GetGameTimer(),
        minScore  = cam.triggerSpeedMph,
    }
end)

RegisterNetEvent('streetkings:events:beginStuntJump', function(jumpId)
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then return end
    if type(jumpId) ~= 'string' then return end

    local def = SKStuntJumps and SKStuntJumps[jumpId]
    if not def or not def.zoneA or not def.zoneB then
        printReject(('%s attempted unknown stunt jump: %s'):format(playerLabel(src), jumpId))
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        printReject(('%s began stunt jump while on foot: %s'):format(playerLabel(src), jumpId))
        return
    end

    local vehCoords = GetEntityCoords(veh)
    local zA = def.zoneA.center
    local zB = def.zoneB.center
    local allowA = (def.zoneA.radius or 10.0) + STUNT_JUMP_RADIUS
    local allowB = (def.zoneB.radius or 10.0) + STUNT_JUMP_RADIUS
    local distA = distBetween(vehCoords, zA)
    local distB = distBetween(vehCoords, zB)

    if distA > allowA and distB > allowB then
        printReject(('%s began stunt jump too far from zones | jump=%s | distA=%.2f/%.2f distB=%.2f/%.2f'):format(
            playerLabel(src), jumpId, distA, allowA, distB, allowB))
        return
    end

    activeAttempts[src] = {
        type      = 'stunt',
        eventId   = jumpId,
        startedAt = GetGameTimer(),
    }
end)

RegisterNetEvent('streetkings:events:beginRampage', function(eventId)
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then return end
    if type(eventId) ~= 'string' or not SKEventsQuery.isRampageEvent(eventId) then return end

    local def = SKEvents and SKEvents[eventId]
    if not def or not def.start then
        printReject(('%s attempted unknown rampage: %s'):format(playerLabel(src), eventId))
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    local dist = distBetween(GetEntityCoords(ped), def.start)
    if dist > RAMPAGE_START_RADIUS then
        printReject(('%s began rampage too far from start | rampage=%s | dist=%.2f | allowed=%.2f'):format(
            playerLabel(src), eventId, dist, RAMPAGE_START_RADIUS))
        return
    end

    local duration = def.duration or 150
    activeAttempts[src] = {
        type      = 'rampage',
        eventId   = eventId,
        startedAt = GetGameTimer(),
        windowMs  = (duration + 30) * 1000,
        maxScore  = duration * 10000,
    }
end)

---@param source integer
---@param eventId string
---@param scoreValue integer
---@return boolean, string|nil
function SKExEventValidation.validateScore(source, eventId, scoreValue)
    local attempt = activeAttempts[source]
    if not attempt or attempt.eventId ~= eventId then
        printReject(('%s submitted %s with no active attempt'):format(playerLabel(source), eventId))
        return false, 'no_active_attempt'
    end

    local elapsed = GetGameTimer() - attempt.startedAt

    if attempt.type == 'speedcam' then
        if elapsed > SPEED_CAM_WINDOW_MS then
            activeAttempts[source] = nil
            printReject(('%s speed cam expired | cam=%s | elapsed=%dms'):format(playerLabel(source), eventId, elapsed))
            return false, 'attempt_expired'
        end
        if scoreValue < attempt.minScore then
            activeAttempts[source] = nil
            printReject(('%s speed cam below trigger | cam=%s | score=%d | min=%d'):format(
                playerLabel(source), eventId, scoreValue, attempt.minScore))
            return false, 'score_below_trigger'
        end
        if scoreValue > MAX_SPEED_MPH then
            activeAttempts[source] = nil
            printReject(('%s speed cam exceeds cap | cam=%s | score=%d | cap=%d'):format(
                playerLabel(source), eventId, scoreValue, MAX_SPEED_MPH))
            return false, 'score_exceeds_cap'
        end

    elseif attempt.type == 'stunt' then
        if elapsed > STUNT_JUMP_WINDOW_MS then
            activeAttempts[source] = nil
            printReject(('%s stunt jump expired | jump=%s | elapsed=%dms'):format(playerLabel(source), eventId, elapsed))
            return false, 'attempt_expired'
        end
        if scoreValue > MAX_STUNT_SCORE then
            activeAttempts[source] = nil
            printReject(('%s stunt jump exceeds cap | jump=%s | score=%d | cap=%d'):format(
                playerLabel(source), eventId, scoreValue, MAX_STUNT_SCORE))
            return false, 'score_exceeds_cap'
        end

    elseif attempt.type == 'rampage' then
        if elapsed > attempt.windowMs then
            activeAttempts[source] = nil
            printReject(('%s rampage expired | rampage=%s | elapsed=%dms | window=%dms'):format(
                playerLabel(source), eventId, elapsed, attempt.windowMs))
            return false, 'attempt_expired'
        end
        if scoreValue > attempt.maxScore then
            activeAttempts[source] = nil
            printReject(('%s rampage exceeds cap | rampage=%s | score=%d | cap=%d'):format(
                playerLabel(source), eventId, scoreValue, attempt.maxScore))
            return false, 'score_exceeds_cap'
        end
    end

    activeAttempts[source] = nil
    return true, nil
end