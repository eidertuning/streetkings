SKEventsSubmit = {}

local function logActivityRejected(source, eventId, scoreValue, vehicleModel, reason)
    if SKLogs then
        SKLogs.Emit('activityRejected', {
            source = source,
            eventId = eventId,
            scoreValue = scoreValue,
            vehicleModel = vehicleModel,
            reason = reason,
        })
    end
    return { ok = false, reason = reason }
end

---@param source integer
---@param eventId string
---@param scoreValue integer
---@param vehicleModel string|nil
---@return table
function SKEventsSubmit.submitExEventScore(source, eventId, scoreValue, vehicleModel)
    local valid, reason = SKExEventValidation.validateScore(source, eventId, scoreValue)
    if not valid then
        return logActivityRejected(source, eventId, scoreValue, vehicleModel, reason)
    end

    local _, scoreType = SKEventsQuery.getActivityContext(eventId)
    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license then
        return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'no_license')
    end

    local savedAlias = SKSaves.read(source, 'profile.alias')
    local alias = (savedAlias ~= '' and savedAlias) or GetPlayerName(source) or 'Unknown'
    local model = (type(vehicleModel) == 'string' and #vehicleModel <= 64) and vehicleModel or ''

    MySQL.insert.await(
        'INSERT INTO `event_leaderboards` (`license`, `alias`, `event_id`, `vehicle_class`, `score_value`, `vehicle_model`) VALUES (?, ?, ?, ?, ?, ?)',
        { license, alias, eventId, '', scoreValue, model }
    )

    local reward
    if scoreType == 'speed' then
        reward = SKEventsRewards.awardSpeedCameraXp(source, eventId, scoreValue)
        SKStats.increment(source, 'speedCameraFlashes', 1)
    elseif SKEventsQuery.isRampageEvent(eventId) then
        reward = SKEventsRewards.awardRampageXp(source, eventId, scoreValue)
        SKStats.increment(source, 'rampagesCompleted', 1)
    else
        reward = SKEventsRewards.awardStuntJumpXp(source, eventId, scoreValue)
        SKStats.increment(source, 'stuntJumpsCompleted', 1)
    end

    TriggerEvent('streetkings:messages:trigger', source, 'activityCompleted', {
        eventId = eventId,
        scoreType = scoreType,
    })

    if reward.playerFirst then
        TriggerEvent('streetkings:messages:trigger', source, 'firstActivityCompleted', {
            eventId = eventId,
            scoreType = scoreType,
        })
    end

    if SKLogs then
        SKLogs.Emit('activitySubmitted', {
            source = source,
            eventId = eventId,
            scoreType = scoreType,
            scoreValue = scoreValue,
            vehicleModel = model,
            vehicleClass = '',
            daily = false,
            goalMet = false,
            reward = reward,
        })
    end

    return {
        ok = true,
        reward = reward,
        scoreType = scoreType,
        vehicleClass = '',
        daily = false,
        rewardClaimed = false,
        claimAwarded = false,
    }
end

---@param source integer
---@param eventId string
---@param scoreValue integer
---@param vehicleModel string|nil
---@return table
function SKEventsSubmit.submitTimeTrialScore(source, eventId, scoreValue, vehicleModel)
    local activity = SKEvents[eventId]
    local eventState = SKEventsDaily.ensureEventState(source)
    local vehicleClass = SKEventsRewards.getActiveVehicleClass(source)
    if not vehicleClass then
        return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'no_active_vehicle')
    end

    local validRun, invalidReason = SKEventsValidation.validateTimedRun(source, eventId, scoreValue)
    if not validRun then
        return logActivityRejected(source, eventId, scoreValue, vehicleModel, invalidReason)
    end

    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license then
        return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'no_license')
    end

    local savedAlias = SKSaves.read(source, 'profile.alias')
    local alias = (savedAlias ~= '' and savedAlias) or GetPlayerName(source) or 'Unknown'
    local model = (type(vehicleModel) == 'string' and #vehicleModel <= 64) and vehicleModel or ''
    local playlistSet = SKEventsDaily.buildDailyPlaylistSet()
    local isDaily = playlistSet[eventId] == true
    local claimAwarded = isDaily and eventState.claimedRewards[eventId] ~= true
    local alreadyClaimed = isDaily and eventState.claimedRewards[eventId] == true
    local goalMet = activity.goalTime ~= nil and scoreValue <= math.floor(activity.goalTime * 1000)

    MySQL.insert.await(
        'INSERT INTO `event_leaderboards` (`license`, `alias`, `event_id`, `vehicle_class`, `score_value`, `vehicle_model`) VALUES (?, ?, ?, ?, ?, ?)',
        { license, alias, eventId, vehicleClass, scoreValue, model }
    )

    SKStats.increment(source, 'racesCompleted', 1)
    if goalMet then
        SKStats.increment(source, 'racesWon', 1)
    end

    local rewardData, rewardContext = SKEventsRewards.awardTimeTrialRun(source, eventId, vehicleClass, scoreValue, goalMet, claimAwarded, alreadyClaimed)

    if claimAwarded then
        eventState.claimedRewards[eventId] = true
        SKSaves.write(source, 'meta.data.events.claimedRewards', eventState.claimedRewards)
    end

    SKEventsValidation.clearTimedRun(source, eventId)

    TriggerEvent('streetkings:messages:trigger', source, 'activityCompleted', {
        eventId = eventId,
        scoreType = 'time',
    })
    SKEventsRewards.notifyEventReward(source, eventId, rewardData, rewardContext)

    if SKLogs then
        SKLogs.Emit('activitySubmitted', {
            source = source,
            eventId = eventId,
            scoreType = 'time',
            scoreValue = scoreValue,
            vehicleModel = model,
            vehicleClass = vehicleClass,
            daily = isDaily,
            goalMet = goalMet,
            reward = rewardData,
        })
    end

    return {
        ok = true,
        reward = rewardData,
        scoreType = 'time',
        vehicleClass = vehicleClass,
        daily = isDaily,
        rewardClaimed = alreadyClaimed,
        claimAwarded = claimAwarded,
    }
end

---@param source integer
---@param eventId string
---@param scoreValue number
---@param vehicleModel string|nil
---@return table
function SKEventsSubmit.submitActivityScore(source, eventId, scoreValue, vehicleModel)
    if not SKEventsServer.dbReady then return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'db_not_ready') end
    if not SKSaves.hasActiveSave(source) then return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'no_active_save') end
    if type(eventId) ~= 'string' or #eventId > 64 then return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'invalid_event') end
    if type(scoreValue) ~= 'number' then return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'invalid_score') end

    scoreValue = math.floor(scoreValue)
    if scoreValue <= 0 or scoreValue > 9999999 then return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'invalid_score') end

    local activity, scoreType = SKEventsQuery.getActivityContext(eventId)
    if not activity or not scoreType then return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'unknown_event') end

    local cfg = SKEventsConfig
    local now = GetGameTimer()
    if SKEventsServer.lastSubmit[source] and (now - SKEventsServer.lastSubmit[source]) < cfg.RATE_LIMIT_MS then
        return logActivityRejected(source, eventId, scoreValue, vehicleModel, 'rate_limited')
    end
    SKEventsServer.lastSubmit[source] = now

    if scoreType ~= 'time' then
        return SKEventsSubmit.submitExEventScore(source, eventId, scoreValue, vehicleModel)
    end

    return SKEventsSubmit.submitTimeTrialScore(source, eventId, scoreValue, vehicleModel)
end

lib.callback.register('streetkings:events:submitTime', function(source, eventId, scoreValue, vehicleModel)
    return SKEventsSubmit.submitActivityScore(source, eventId, scoreValue, vehicleModel)
end)
