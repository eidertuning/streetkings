SKEventsLeaderboards = {}

---@param source integer
---@param eventId string
---@param period string
---@return table
function SKEventsLeaderboards.getTimeTrialLeaderboardPayload(source, eventId, period)
    local vehicleClass = SKEventsRewards.getActiveVehicleClass(source)
    if not vehicleClass then
        return { entries = {}, personalBest = nil, scoreType = 'time', vehicleClass = '' }
    end

    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license then
        return { entries = {}, personalBest = nil, scoreType = 'time', vehicleClass = vehicleClass }
    end

    local rows = SKEventsQuery.fetchTimeTrialRows(eventId, vehicleClass, period)
    local entries, personalBest = SKEventsQuery.buildTimeTrialLeaderboardData(rows, license, 10)

    return {
        entries = entries,
        personalBest = personalBest,
        scoreType = 'time',
        vehicleClass = vehicleClass,
    }
end

lib.callback.register('streetkings:events:getLeaderboard', function(source, eventId, period)
    if not SKEventsServer.dbReady then return {} end
    if type(eventId) ~= 'string' then return {} end
    if type(period) ~= 'string' then period = LeaderboardPeriod.ALL end

    if SKEventsQuery.isTimeTrialEvent(eventId) then
        return SKEventsLeaderboards.getTimeTrialLeaderboardPayload(source, eventId, period).entries
    end

    local orderDir, agg = SKEventsQuery.getOrderAndAgg(eventId)
    local vmSub = SKEventsQuery.vehicleModelSubquery(orderDir)
    local query = string.format(
        'SELECT `license`, MAX(`alias`) AS `alias`, %s(`score_value`) AS `score_value`, %s FROM `event_leaderboards` AS `a` WHERE `event_id` = ? %s GROUP BY `license` ORDER BY `score_value` %s LIMIT 10',
        agg,
        vmSub,
        SKEventsQuery.getPeriodFilter(period),
        orderDir
    )
    local playerLicense = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    local rows = MySQL.query.await(query, { eventId }) or {}
    local entries = {}

    for i, row in ipairs(rows) do
        entries[i] = {
            rank = i,
            alias = row.alias,
            score = row.score_value,
            isSelf = playerLicense ~= nil and row.license == playerLicense,
            vehicleModel = row.vehicle_model or '',
        }
    end

    return entries
end)

lib.callback.register('streetkings:events:getPersonalBest', function(source, eventId)
    if not SKEventsServer.dbReady then return nil end
    if type(eventId) ~= 'string' then return nil end

    if SKEventsQuery.isTimeTrialEvent(eventId) then
        local payload = SKEventsLeaderboards.getTimeTrialLeaderboardPayload(source, eventId, LeaderboardPeriod.ALL)
        return payload.personalBest
    end

    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license then return nil end

    local _, agg = SKEventsQuery.getOrderAndAgg(eventId)
    local query = string.format(
        'SELECT %s(`score_value`) AS `best` FROM `event_leaderboards` WHERE `event_id` = ? AND `license` = ?',
        agg
    )
    local row = MySQL.single.await(query, { eventId, license })

    if not row or row.best == nil then
        return nil
    end

    return row.best
end)

lib.callback.register('streetkings:events:getNpcLeaderboard', function(source, period)
    return SKEventsQuery.fetchNpcLeaderboard(source, period)
end)

lib.callback.register('streetkings:events:getNpcPersonalBest', function(source, period)
    return SKEventsQuery.fetchNpcPersonalBest(source, period)
end)

lib.callback.register('streetkings:events:getCategories', function(source)
    return SKEventsDaily.buildCategories(source)
end)

lib.callback.register('streetkings:events:getCategoryLeaderboard', function(source, categoryId, period)
    if not SKEventsServer.dbReady then return { entries = {}, personalBest = nil, scoreType = 'time', vehicleClass = '' } end
    if type(categoryId) ~= 'string' then return { entries = {}, personalBest = nil, scoreType = 'time', vehicleClass = '' } end
    if type(period) ~= 'string' then period = LeaderboardPeriod.ALL end

    if categoryId == 'npc_street' then
        return {
            entries = SKEventsQuery.fetchNpcLeaderboard(source, period),
            personalBest = SKEventsQuery.fetchNpcPersonalBest(source, period),
            scoreType = 'wl',
            vehicleClass = '',
        }
    end

    if SKEventsQuery.isTimeTrialEvent(categoryId) then
        return SKEventsLeaderboards.getTimeTrialLeaderboardPayload(source, categoryId, period)
    end

    local scoreType = 'time'
    if SKEventsQuery.isSpeedCamEvent(categoryId) then
        scoreType = 'speed'
    elseif SKEventsQuery.isStuntJumpEvent(categoryId) then
        scoreType = 'points'
    elseif SKEventsQuery.isRampageEvent(categoryId) then
        scoreType = 'points'
    end
    local orderDir, agg = SKEventsQuery.getOrderAndAgg(categoryId)
    local playerLicense = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    local vmSub = SKEventsQuery.vehicleModelSubquery(orderDir)
    local query = string.format(
        'SELECT `license`, MAX(`alias`) AS `alias`, %s(`score_value`) AS `score_value`, %s FROM `event_leaderboards` AS `a` WHERE `event_id` = ? %s GROUP BY `license` ORDER BY `score_value` %s LIMIT 10',
        agg,
        vmSub,
        SKEventsQuery.getPeriodFilter(period),
        orderDir
    )
    local rows = MySQL.query.await(query, { categoryId }) or {}
    local entries = {}

    for i, row in ipairs(rows) do
        entries[i] = {
            rank = i,
            alias = row.alias,
            score = row.score_value,
            isSelf = playerLicense ~= nil and row.license == playerLicense,
            vehicleModel = row.vehicle_model or '',
        }
    end

    local personalBest = nil
    if playerLicense then
        local personalBestQuery = string.format(
            'SELECT %s(`score_value`) AS `best` FROM `event_leaderboards` WHERE `event_id` = ? AND `license` = ? %s',
            agg,
            SKEventsQuery.getPeriodFilter(period)
        )
        local row = MySQL.single.await(personalBestQuery, { categoryId, playerLicense })
        if row and row.best ~= nil then
            personalBest = row.best
        end
    end

    return {
        entries = entries,
        personalBest = personalBest,
        scoreType = scoreType,
        vehicleClass = '',
    }
end)

lib.callback.register('streetkings:events:getDailyPlaylist', function(source)
    if not SKEventsServer.dbReady then
        return { dayKey = '', vehicleClass = '', entries = {} }
    end

    return SKEventsDaily.buildDailyPlaylistPayload(source)
end)

lib.callback.register('streetkings:events:getDailyEventState', function(source, eventId)
    if not SKEventsServer.dbReady then return nil end
    if type(eventId) ~= 'string' then return nil end
    if not SKEventsQuery.isTimeTrialEvent(eventId) then return nil end

    return SKEventsDaily.getTimeTrialEventState(source, SKEvents[eventId], eventId)
end)

lib.callback.register('streetkings:events:getEventRewardPreview', function(source, eventId)
    if not SKEventsServer.dbReady then return nil end
    if type(eventId) ~= 'string' then return nil end
    if not SKEventsQuery.isTimeTrialEvent(eventId) then return nil end

    local state = SKEventsDaily.getTimeTrialEventState(source, SKEvents[eventId], eventId)
    return state and state.rewardPreview or nil
end)