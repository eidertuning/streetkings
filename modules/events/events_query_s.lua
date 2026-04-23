SKEventsQuery = {}

---@param eventId string
---@return boolean
function SKEventsQuery.isSpeedCamEvent(eventId)
    return type(eventId) == 'string' and eventId:find('^speedcam_') ~= nil
end

---@param eventId string
---@return boolean
function SKEventsQuery.isNpcWinLossEvent(eventId)
    return eventId == 'npc_street_wins' or eventId == 'npc_street_losses'
end

---@param eventId string
---@return boolean
function SKEventsQuery.isStuntJumpEvent(eventId)
    return type(eventId) == 'string' and eventId:find('^stunt_') ~= nil
end

---@param eventId string
---@return boolean
function SKEventsQuery.isRampageEvent(eventId)
    return type(eventId) == 'string' and eventId:find('^rampage_') ~= nil
end

---@param eventId string
---@return boolean
function SKEventsQuery.isTimeTrialEvent(eventId)
    return type(eventId) == 'string' and SKEvents ~= nil and type(SKEvents[eventId]) == 'table'
end

---@param eventId string
---@return string, string
function SKEventsQuery.getOrderAndAgg(eventId)
    if SKEventsQuery.isSpeedCamEvent(eventId) then
        return 'DESC', 'MAX'
    end
    if SKEventsQuery.isStuntJumpEvent(eventId) then
        return 'DESC', 'MAX'
    end
    if SKEventsQuery.isRampageEvent(eventId) then
        return 'DESC', 'MAX'
    end
    if SKEventsQuery.isNpcWinLossEvent(eventId) then
        return 'DESC', 'SUM'
    end
    return 'ASC', 'MIN'
end

---@param orderDir string
---@return string
function SKEventsQuery.vehicleModelSubquery(orderDir)
    local dir = orderDir == 'ASC' and 'ASC' or 'DESC'
    return string.format(
        '(SELECT `vehicle_model` FROM `event_leaderboards` AS `b` WHERE `b`.`license` = `a`.`license` AND `b`.`event_id` = `a`.`event_id` ORDER BY `b`.`score_value` %s LIMIT 1) AS `vehicle_model`',
        dir
    )
end

---@param period string
---@return string
function SKEventsQuery.getPeriodFilter(period)
    if period == LeaderboardPeriod.DAY then
        return 'AND `created_at` >= DATE_SUB(NOW(), INTERVAL 1 DAY)'
    elseif period == LeaderboardPeriod.WEEK then
        return 'AND `created_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY)'
    elseif period == LeaderboardPeriod.MONTH then
        return 'AND `created_at` >= DATE_SUB(NOW(), INTERVAL 30 DAY)'
    end
    return ''
end

---@param eventId string
---@return table|nil, string|nil
function SKEventsQuery.getActivityContext(eventId)
    if SKEventsQuery.isSpeedCamEvent(eventId) then
        if not SKSpeedCameras then
            return nil, nil
        end

        for _, cam in ipairs(SKSpeedCameras) do
            if cam.id == eventId then
                return cam, 'speed'
            end
        end

        return nil, nil
    end

    if SKEventsQuery.isStuntJumpEvent(eventId) then
        if SKStuntJumps ~= nil and SKStuntJumps[eventId] ~= nil then
            return SKStuntJumps[eventId], 'points'
        end
        return nil, nil
    end

    if SKEventsQuery.isRampageEvent(eventId) then
        if SKEvents ~= nil and SKEvents[eventId] ~= nil then
            return SKEvents[eventId], 'points'
        end
        return nil, nil
    end

    if not SKEventsQuery.isTimeTrialEvent(eventId) then
        return nil, nil
    end

    return SKEvents[eventId], 'time'
end

---@param eventId string
---@param vehicleClass string
---@param period string
---@return table[]
function SKEventsQuery.fetchTimeTrialRows(eventId, vehicleClass, period)
    local vmSub = '(SELECT `vehicle_model` FROM `event_leaderboards` AS `b` WHERE `b`.`license` = `a`.`license` AND `b`.`event_id` = `a`.`event_id` AND `b`.`vehicle_class` = `a`.`vehicle_class` ORDER BY `b`.`score_value` ASC LIMIT 1) AS `vehicle_model`'
    local query = string.format(
        'SELECT `license`, MAX(`alias`) AS `alias`, MIN(`score_value`) AS `score_value`, %s FROM `event_leaderboards` AS `a` WHERE `event_id` = ? AND `vehicle_class` = ? %s GROUP BY `license` ORDER BY `score_value` ASC',
        vmSub,
        SKEventsQuery.getPeriodFilter(period)
    )

    return MySQL.query.await(query, { eventId, vehicleClass }) or {}
end

function SKEventsQuery.fetchLeaderboardRows(eventId, vehicleClass, period)
    local order, agg = SKEventsQuery.getOrderAndAgg(eventId)
    local vmSub = SKEventsQuery.vehicleModelSubquery(order)
    local query = string.format(
        'SELECT `license`, MAX(`alias`) AS `alias`, %s(`score_value`) AS `score_value`, %s FROM `event_leaderboards` AS `a` WHERE `event_id` = ? AND `vehicle_class` = ? %s GROUP BY `license` ORDER BY `score_value` %s',
        agg,
        vmSub,
        SKEventsQuery.getPeriodFilter(period),
        order
    )

    return MySQL.query.await(query, { eventId, vehicleClass }) or {}
end

---@param rows table[]
---@param playerLicense string
---@param limit integer
---@return table[], integer|nil, integer|nil, number|nil
function SKEventsQuery.buildTimeTrialLeaderboardData(rows, playerLicense, limit)
    local entries = {}
    local personalBest = nil
    local personalRank = nil
    local personalPercentile = nil
    local totalEntries = #rows

    for i, row in ipairs(rows) do
        if i <= limit then
            entries[i] = {
                rank = i,
                alias = row.alias,
                score = row.score_value,
                isSelf = row.license == playerLicense,
                vehicleModel = row.vehicle_model or '',
            }
        end

        if row.license == playerLicense then
            personalBest = row.score_value
            personalRank = i
            if totalEntries <= 1 then
                personalPercentile = 0
            else
                personalPercentile = (i - 1) / (totalEntries - 1)
            end
        end
    end

    return entries, personalBest, personalRank, personalPercentile
end

---@param playerSource integer
---@param period string
---@return table[]
function SKEventsQuery.fetchNpcLeaderboard(playerSource, period)
    if not SKEventsServer.dbReady then return {} end
    if type(period) ~= 'string' then period = LeaderboardPeriod.ALL end

    local periodFilter = SKEventsQuery.getPeriodFilter(period)
    local winsRows = MySQL.query.await(
        'SELECT `license`, MAX(`alias`) AS `alias`, SUM(`score_value`) AS `wins` FROM `event_leaderboards` WHERE `event_id` = ? '
            .. periodFilter .. ' GROUP BY `license`',
        { 'npc_street_wins' }
    ) or {}
    local lossesRows = MySQL.query.await(
        'SELECT `license`, MAX(`alias`) AS `alias`, SUM(`score_value`) AS `losses` FROM `event_leaderboards` WHERE `event_id` = ? '
            .. periodFilter .. ' GROUP BY `license`',
        { 'npc_street_losses' }
    ) or {}

    local byLicense = {}
    for _, row in ipairs(winsRows) do
        byLicense[row.license] = { alias = row.alias, wins = row.wins, losses = 0 }
    end
    for _, row in ipairs(lossesRows) do
        local entry = byLicense[row.license]
        if entry then
            entry.losses = row.losses
        else
            byLicense[row.license] = { alias = row.alias, wins = 0, losses = row.losses }
        end
    end

    local playerLicense = GetPlayerIdentifierByType(playerSource --[[@as string]], 'license')
    local list = {}

    for license, data in pairs(byLicense) do
        list[#list + 1] = {
            license = license,
            alias = data.alias,
            wins = data.wins,
            losses = data.losses,
        }
    end

    table.sort(list, function(a, b)
        if a.wins ~= b.wins then return a.wins > b.wins end
        local aGames = a.wins + a.losses
        local bGames = b.wins + b.losses
        local aRatio = aGames > 0 and (a.wins / aGames) or 0
        local bRatio = bGames > 0 and (b.wins / bGames) or 0
        if aRatio ~= bRatio then return aRatio > bRatio end
        return a.losses < b.losses
    end)

    local entries = {}
    for i = 1, math.min(10, #list) do
        local entry = list[i]
        entries[i] = {
            rank = i,
            alias = entry.alias,
            wins = entry.wins,
            losses = entry.losses,
            isSelf = playerLicense ~= nil and entry.license == playerLicense,
        }
    end

    return entries
end

---@param playerSource integer
---@param period string
---@return table|nil
function SKEventsQuery.fetchNpcPersonalBest(playerSource, period)
    if not SKEventsServer.dbReady then return nil end
    if type(period) ~= 'string' then period = LeaderboardPeriod.ALL end

    local license = GetPlayerIdentifierByType(playerSource --[[@as string]], 'license')
    if not license then return nil end

    local base = ' FROM `event_leaderboards` WHERE `event_id` = ? AND `license` = ? ' .. SKEventsQuery.getPeriodFilter(period)
    local winsRow = MySQL.single.await('SELECT COALESCE(SUM(`score_value`), 0) AS `wins`' .. base, { 'npc_street_wins', license })
    local lossesRow = MySQL.single.await('SELECT COALESCE(SUM(`score_value`), 0) AS `losses`' .. base, { 'npc_street_losses', license })
    local wins = winsRow and winsRow.wins or 0
    local losses = lossesRow and lossesRow.losses or 0

    if wins == 0 and losses == 0 then
        return nil
    end

    return { wins = wins, losses = losses }
end