SKEventsSubmit = {}

---@param source integer
---@param eventId string
---@param scoreValue integer
---@param vehicleModel string|nil
---@return table
function SKEventsSubmit.submitExEventScore(source, eventId, scoreValue, vehicleModel)
    local valid, reason = SKExEventValidation.validateScore(source, eventId, scoreValue)
    if not valid then
        return { ok = false, reason = reason }
    end

    local _, scoreType = SKEventsQuery.getActivityContext(eventId)
    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license then
        return { ok = false, reason = 'no_license' }
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
        return { ok = false, reason = 'no_active_vehicle' }
    end

    local validRun, invalidReason = SKEventsValidation.validateTimedRun(source, eventId, scoreValue)
    if not validRun then
        return { ok = false, reason = invalidReason }
    end

    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license then
        return { ok = false, reason = 'no_license' }
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
    if not SKEventsServer.dbReady then return { ok = false, reason = 'db_not_ready' } end
    if not SKSaves.hasActiveSave(source) then return { ok = false, reason = 'no_active_save' } end
    if type(eventId) ~= 'string' or #eventId > 64 then return { ok = false, reason = 'invalid_event' } end
    if type(scoreValue) ~= 'number' then return { ok = false, reason = 'invalid_score' } end

    scoreValue = math.floor(scoreValue)
    if scoreValue <= 0 or scoreValue > 9999999 then return { ok = false, reason = 'invalid_score' } end

    local activity, scoreType = SKEventsQuery.getActivityContext(eventId)
    if not activity or not scoreType then return { ok = false, reason = 'unknown_event' } end

    local cfg = SKEventsConfig
    local now = GetGameTimer()
    if SKEventsServer.lastSubmit[source] and (now - SKEventsServer.lastSubmit[source]) < cfg.RATE_LIMIT_MS then
        return { ok = false, reason = 'rate_limited' }
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