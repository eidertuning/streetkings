SKEventsValidation = SKEventsValidation or {}

local RUN_START_RADIUS = 30.0
local RUN_CHECKPOINT_RADIUS = 30.0
local RUN_FINISH_RADIUS = 30.0
local CLIENT_EVENT_PICKUP_RADIUS = 20.0
local RUN_ELAPSED_GRACE_MS = 3000
local RUN_TIMEOUT_MS = 20 * 60 * 1000
local activeTimedRuns = {}

---@param source integer
---@return string
local function runnerLabel(source)
    return ('%s (%d)'):format(GetPlayerName(source) or 'unknown', source)
end

---@param message string
local function printEventTolerance(message)
    print(('^3[SK:Events] %s^7'):format(message))
end

---@param message string
local function printEventReject(message)
    print(('^1[SK:Events] %s^7'):format(message))
end

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
local function getPlayerRunState(source)
    local ped = GetPlayerPed(source)
    local vehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    return ped, vehicle, coords
end

---@param source integer
---@param eventId string|nil
function SKEventsValidation.clearTimedRun(source, eventId)
    local run = activeTimedRuns[source]
    if not run then
        return
    end
    if eventId and run.eventId ~= eventId then
        return
    end
    activeTimedRuns[source] = nil
end

---@param source integer
---@param eventId string
function SKEventsValidation.beginTimedRun(source, eventId)
    if not SKSaves.hasActiveSave(source) then
        return
    end

    local activity, scoreType = SKEventsQuery.getActivityContext(eventId)
    if not activity or scoreType ~= 'time' then
        return
    end

    local ped, vehicle, coords = getPlayerRunState(source)
    if ped == 0 or vehicle == 0 then
        return
    end

    local startCoords = vector3(activity.start.x, activity.start.y, activity.start.z)
    local startDistance = distanceBetween(coords, startCoords)
    if startDistance > RUN_START_RADIUS then
        printEventReject(('%s failed run start validation | event=%s | distance=%.2f | allowed=%.2f'):format(
            runnerLabel(source),
            eventId,
            startDistance,
            RUN_START_RADIUS
        ))
        return
    end

    if startDistance > CLIENT_EVENT_PICKUP_RADIUS then
        printEventTolerance(('%s started near start tolerance | event=%s | distance=%.2f / %.2f'):format(
            runnerLabel(source),
            eventId,
            startDistance,
            RUN_START_RADIUS
        ))
    end

    local checkpoints = SKEventRoute.buildCheckpointList(activity)
    local finishCoords = checkpoints[#checkpoints]
    if not finishCoords then
        return
    end

    activeTimedRuns[source] = {
        eventId = eventId,
        startedAt = GetGameTimer(),
        scheme = activity.scheme,
        checkpoints = checkpoints,
        validatedCheckpoints = {},
        validatedCount = 0,
        nextCheckpointIndex = 1,
        finishCoords = finishCoords,
        vehicleModel = GetEntityModel(vehicle),
    }
end

---@param source integer
---@param eventId string
---@return table|nil, integer|nil, integer|nil, vector3|nil
local function getActiveTimedRunState(source, eventId)
    local run = activeTimedRuns[source]
    if not run or run.eventId ~= eventId then
        printEventReject(('%s has no active run state | event=%s'):format(runnerLabel(source), eventId))
        return nil, nil, nil, nil
    end

    local now = GetGameTimer()
    if (now - run.startedAt) > RUN_TIMEOUT_MS then
        SKEventsValidation.clearTimedRun(source, eventId)
        printEventReject(('%s run expired | event=%s | elapsed=%dms | timeout=%dms'):format(
            runnerLabel(source),
            eventId,
            now - run.startedAt,
            RUN_TIMEOUT_MS
        ))
        return nil, nil, nil, nil
    end

    local ped, vehicle, coords = getPlayerRunState(source)
    if ped == 0 or vehicle == 0 then
        printEventReject(('%s invalid player state during run | event=%s'):format(runnerLabel(source), eventId))
        return nil, nil, nil, nil
    end

    if run.vehicleModel ~= GetEntityModel(vehicle) then
        printEventReject(('%s vehicle mismatch during run | event=%s | expected=%s | got=%s'):format(
            runnerLabel(source),
            eventId,
            tostring(run.vehicleModel),
            tostring(GetEntityModel(vehicle))
        ))
        return nil, nil, nil, nil
    end

    return run, now, vehicle, coords
end

---@param source integer
---@param eventId string
---@param checkpointIndex integer
---@return boolean
function SKEventsValidation.validateCheckpointHit(source, eventId, checkpointIndex)
    local run, _, _, coords = getActiveTimedRunState(source, eventId)
    if not run then
        return false
    end

    if type(checkpointIndex) ~= 'number' or checkpointIndex % 1 ~= 0 then
        printEventReject(('%s sent invalid checkpoint index | event=%s | checkpoint=%s'):format(
            runnerLabel(source),
            eventId,
            tostring(checkpointIndex)
        ))
        return false
    end

    local checkpoint = run.checkpoints[checkpointIndex]
    if not checkpoint then
        printEventReject(('%s sent out-of-range checkpoint index | event=%s | checkpoint=%d | total=%d'):format(
            runnerLabel(source),
            eventId,
            checkpointIndex,
            #run.checkpoints
        ))
        return false
    end

    local checkpointDistance = distanceBetween(coords, checkpoint)
    if checkpointDistance > RUN_CHECKPOINT_RADIUS then
        printEventReject(('%s checkpoint rejected by position | event=%s | checkpoint=%d | distance=%.2f | allowed=%.2f'):format(
            runnerLabel(source),
            eventId,
            checkpointIndex,
            checkpointDistance,
            RUN_CHECKPOINT_RADIUS
        ))
        return false
    end

    if checkpointDistance > CLIENT_EVENT_PICKUP_RADIUS then
        printEventTolerance(('%s checkpoint accepted near tolerance | event=%s | checkpoint=%d | distance=%.2f / %.2f'):format(
            runnerLabel(source),
            eventId,
            checkpointIndex,
            checkpointDistance,
            RUN_CHECKPOINT_RADIUS
        ))
    end

    if run.scheme == CheckpointScheme.UNORDERED then
        if run.validatedCheckpoints[checkpointIndex] then
            printEventReject(('%s duplicate unordered checkpoint hit rejected | event=%s | checkpoint=%d'):format(
                runnerLabel(source),
                eventId,
                checkpointIndex
            ))
            return false
        end

        run.validatedCheckpoints[checkpointIndex] = true
        run.validatedCount = run.validatedCount + 1
        return true
    end

    if checkpointIndex ~= run.nextCheckpointIndex then
        printEventReject(('%s out-of-order checkpoint hit rejected | event=%s | checkpoint=%d | expected=%d'):format(
            runnerLabel(source),
            eventId,
            checkpointIndex,
            run.nextCheckpointIndex
        ))
        return false
    end

    run.validatedCheckpoints[checkpointIndex] = true
    run.validatedCount = run.validatedCount + 1
    run.nextCheckpointIndex = run.nextCheckpointIndex + 1
    return true
end

---@param source integer
---@param eventId string
---@param scoreValue integer
---@return boolean, string|nil
function SKEventsValidation.validateTimedRun(source, eventId, scoreValue)
    local run, now, _, coords = getActiveTimedRunState(source, eventId)
    if not run then
        return false, 'run_not_started'
    end

    if run.validatedCount ~= #run.checkpoints then
        printEventReject(('%s finish rejected with missing checkpoints | event=%s | validated=%d | total=%d'):format(
            runnerLabel(source),
            eventId,
            run.validatedCount,
            #run.checkpoints
        ))
        return false, 'missing_checkpoints'
    end

    local finishDistance = distanceBetween(coords, run.finishCoords)
    if finishDistance > RUN_FINISH_RADIUS then
        printEventReject(('%s finish rejected by position | event=%s | distance=%.2f | allowed=%.2f'):format(
            runnerLabel(source),
            eventId,
            finishDistance,
            RUN_FINISH_RADIUS
        ))
        return false, 'finish_position_mismatch'
    end

    if finishDistance > CLIENT_EVENT_PICKUP_RADIUS then
        printEventTolerance(('%s finish accepted near tolerance | event=%s | distance=%.2f / %.2f'):format(
            runnerLabel(source),
            eventId,
            finishDistance,
            RUN_FINISH_RADIUS
        ))
    end

    local serverElapsedMs = now - run.startedAt
    local elapsedDeltaMs = serverElapsedMs - scoreValue
    if elapsedDeltaMs > 5000 then
        printEventTolerance(('%s finish elapsed drift observed | event=%s | client=%dms | server=%dms | delta=%dms | grace=%dms'):format(
            runnerLabel(source),
            eventId,
            scoreValue,
            serverElapsedMs,
            elapsedDeltaMs,
            RUN_ELAPSED_GRACE_MS
        ))
    end

    return true, nil
end

RegisterNetEvent('streetkings:events:beginRun', function(eventId)
    SKEventsValidation.beginTimedRun(source --[[@as integer]], eventId)
end)

RegisterNetEvent('streetkings:events:cancelRun', function(eventId)
    SKEventsValidation.clearTimedRun(source --[[@as integer]], eventId)
end)

RegisterNetEvent('streetkings:events:checkpointHit', function(eventId, checkpointIndex)
    SKEventsValidation.validateCheckpointHit(source --[[@as integer]], eventId, checkpointIndex)
end)

AddEventHandler('playerDropped', function()
    activeTimedRuns[source] = nil
end)