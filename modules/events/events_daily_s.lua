SKEventsDaily = {}

---@return string
function SKEventsDaily.getServerDayKey()
    return tostring(os.date('%Y-%m-%d', os.time() + 86400))
end

---@param seed string
---@param value string
---@return integer
local function seededWeight(seed, value)
    local hash = 0
    local text = seed .. ':' .. value

    for i = 1, #text do
        hash = (hash * 131 + text:byte(i)) % 2147483647
    end

    return hash
end

---@param state integer
---@return integer
local function nextRngState(state)
    return (state * 1103515245 + 12345) % 2147483647
end

---@param ids string[]
---@param dayKey string
---@param poolKey string
---@return string[]
local function shuffleIdsForDay(ids, dayKey, poolKey)
    table.sort(ids)

    local state = seededWeight(dayKey, poolKey)
    if state == 0 then
        state = 1
    end

    for i = #ids, 2, -1 do
        state = nextRngState(state)
        local j = (state % i) + 1
        ids[i], ids[j] = ids[j], ids[i]
    end

    return ids
end

---@param source integer
---@return table
function SKEventsDaily.ensureEventState(source)
    local metaData = SKSaves.read(source, 'meta.data')
    local eventState = metaData.events
    local dayKey = SKEventsDaily.getServerDayKey()

    if eventState.dayKey ~= dayKey then
        eventState.dayKey = dayKey
        eventState.claimedRewards = {}
        eventState.lastSeenPlaylist = ''
        SKSaves.write(source, 'meta.data', metaData)
    end

    return eventState
end

---@return string[]
function SKEventsDaily.buildDailyPlaylistIds()
    local cfg = SKEventsConfig
    local dayKey = SKEventsDaily.getServerDayKey()
    local raceIds = {}
    local deliveryIds = {}

    for eventId, def in pairs(SKEvents) do
        if def.type == EventType.DELIVERY then
            deliveryIds[#deliveryIds + 1] = eventId
        elseif def.type ~= EventType.RAMPAGE then
            raceIds[#raceIds + 1] = eventId
        end
    end

    shuffleIdsForDay(raceIds, dayKey, 'race')
    shuffleIdsForDay(deliveryIds, dayKey, 'delivery')

    local playlistIds = {}
    local deliveryCount = math.min(cfg.DAILY_GUARANTEED_DELIVERIES, #deliveryIds, cfg.DAILY_PLAYLIST_SIZE)
    local raceCount = math.min(#raceIds, cfg.DAILY_PLAYLIST_SIZE - deliveryCount)

    for i = 1, raceCount do
        playlistIds[#playlistIds + 1] = raceIds[i]
    end

    for i = 1, deliveryCount do
        playlistIds[#playlistIds + 1] = deliveryIds[i]
    end

    if #playlistIds < cfg.DAILY_PLAYLIST_SIZE then
        local remainder = {}

        for i = raceCount + 1, #raceIds do
            remainder[#remainder + 1] = raceIds[i]
        end
        for i = deliveryCount + 1, #deliveryIds do
            remainder[#remainder + 1] = deliveryIds[i]
        end

        shuffleIdsForDay(remainder, dayKey, 'remainder')

        for i = 1, math.min(#remainder, cfg.DAILY_PLAYLIST_SIZE - #playlistIds) do
            playlistIds[#playlistIds + 1] = remainder[i]
        end
    end

    return playlistIds
end

---@return table<string, boolean>
function SKEventsDaily.buildDailyPlaylistSet()
    local set = {}

    for _, eventId in ipairs(SKEventsDaily.buildDailyPlaylistIds()) do
        set[eventId] = true
    end

    return set
end

---@param source integer
---@param activity table
---@param eventId string
---@param eventState table
---@param isDaily boolean
---@param vehicleClass string
---@return table
function SKEventsDaily.buildDailyEventState(source, activity, eventId, eventState, isDaily, vehicleClass)
    local rows = SKEventsQuery.fetchLeaderboardRows(eventId, vehicleClass, LeaderboardPeriod.ALL)
    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license then
        return {
            eventId = eventId,
            isDaily = isDaily,
            rewardClaimed = false,
            rewardAvailable = false,
            vehicleClass = vehicleClass,
            rewardPreview = nil,
            boardSize = #rows,
        }
    end

    local _, personalBest, personalRank, personalPercentile = SKEventsQuery.buildTimeTrialLeaderboardData(rows, license, 10)
    local boardSize = #rows
    local entriesBeaten = personalRank and (boardSize - personalRank) or 0

    return {
        eventId = eventId,
        isDaily = isDaily,
        rewardClaimed = eventState.claimedRewards[eventId] == true,
        rewardAvailable = isDaily and eventState.claimedRewards[eventId] ~= true,
        vehicleClass = vehicleClass,
        boardSize = boardSize,
        personalBest = personalBest,
        personalRank = personalRank,
        personalPercentile = personalPercentile,
        rewardPreview = isDaily and SKEventsRewards.buildRewardPreview(activity, boardSize, entriesBeaten, personalPercentile or 1) or nil,
    }
end

---@param source integer
---@param activity table
---@param eventId string
---@return table
function SKEventsDaily.getTimeTrialEventState(source, activity, eventId)
    local eventState = SKEventsDaily.ensureEventState(source)
    local playlistSet = SKEventsDaily.buildDailyPlaylistSet()
    local vehicleClass = SKEventsRewards.getActiveVehicleClass(source)

    if not vehicleClass then
        return {
            eventId = eventId,
            isDaily = playlistSet[eventId] == true,
            rewardClaimed = false,
            rewardAvailable = false,
            vehicleClass = '',
            rewardPreview = nil,
            boardSize = 0,
        }
    end

    return SKEventsDaily.buildDailyEventState(source, activity, eventId, eventState, playlistSet[eventId] == true, vehicleClass)
end

---@param source integer
---@return table
function SKEventsDaily.buildDailyPlaylistPayload(source)
    local eventState = SKEventsDaily.ensureEventState(source)
    local playlistIds = SKEventsDaily.buildDailyPlaylistIds()
    local vehicleClass = SKEventsRewards.getActiveVehicleClass(source) or ''
    local entries = {}

    for index, eventId in ipairs(playlistIds) do
        local def = SKEvents[eventId]
        local state = vehicleClass ~= '' and SKEventsDaily.buildDailyEventState(source, def, eventId, eventState, true, vehicleClass) or {
            eventId = eventId,
            isDaily = true,
            rewardClaimed = false,
            rewardAvailable = false,
            vehicleClass = '',
            rewardPreview = nil,
            boardSize = 0,
        }

        entries[index] = {
            id = eventId,
            name = def.name,
            type = def.type,
            scheme = def.scheme,
            rewardClaimed = state.rewardClaimed,
            rewardAvailable = state.rewardAvailable,
            rewardPreview = state.rewardPreview,
            vehicleClass = state.vehicleClass,
        }
    end

    return {
        dayKey = eventState.dayKey,
        vehicleClass = vehicleClass,
        entries = entries,
    }
end

---@param source integer
---@param playlistPayload table
function SKEventsDaily.maybeSendDailyPlaylistMessage(source, playlistPayload)
    local cfg = SKEventsConfig
    local eventState = SKEventsDaily.ensureEventState(source)
    if eventState.lastSeenPlaylist == playlistPayload.dayKey then
        return
    end

    local names = {}
    for i = 1, math.min(#playlistPayload.entries, 4) do
        names[#names + 1] = playlistPayload.entries[i].name
    end

    local body = ([[Today's featured runs for %s class are live.

Check your map for the full list.

Complete them all in the day for a special reward.]]):format(playlistPayload.vehicleClass ~= '' and playlistPayload.vehicleClass or 'No Ride')

    SKMessages.enqueueDelayed(source, cfg.MESSAGE_SENDER, cfg.MESSAGE_AVATAR, body, 60)
    eventState.lastSeenPlaylist = playlistPayload.dayKey
    SKSaves.write(source, 'meta.data.events.lastSeenPlaylist', eventState.lastSeenPlaylist)
end

---@param source integer
---@return table[]
function SKEventsDaily.buildCategories(source)
    local cats = {}
    local groupOrder = { 'Daily Events', 'Street Races', 'Race Events', 'Deliveries', 'Rampage', 'Stunt Jumps', 'Speed Traps' }
    local playlistSet = SKEventsDaily.buildDailyPlaylistSet()

    cats[#cats + 1] = { id = 'npc_street', label = 'NPC Street Races', scoreType = 'wl', group = 'Street Races' }

    for _, def in pairs(SKEvents) do
        if type(def) ~= 'table' or not def.id then goto nextEvent end

        if def.type == EventType.RAMPAGE then
            cats[#cats + 1] = {
                id = def.id,
                label = def.name,
                scoreType = 'points',
                group = 'Rampage',
            }
        else
            local group = playlistSet[def.id] and 'Daily Events' or 'Race Events'
            if def.type == EventType.DELIVERY and not playlistSet[def.id] then
                group = 'Deliveries'
            end

            cats[#cats + 1] = {
                id = def.id,
                label = def.name,
                scoreType = 'time',
                group = group,
            }
        end

        ::nextEvent::
    end

    if SKSpeedCameras then
        for _, cam in ipairs(SKSpeedCameras) do
            cats[#cats + 1] = { id = cam.id, label = cam.name, scoreType = 'speed', group = 'Speed Traps' }
        end
    end

    if SKStuntJumps then
        for _, jump in pairs(SKStuntJumps) do
            cats[#cats + 1] = { id = jump.id, label = jump.name, scoreType = 'points', group = 'Stunt Jumps' }
        end
    end

    local groupIndex = {}
    for i, group in ipairs(groupOrder) do
        groupIndex[group] = i
    end

    table.sort(cats, function(a, b)
        local aGroup = groupIndex[a.group] or 99
        local bGroup = groupIndex[b.group] or 99
        if aGroup ~= bGroup then
            return aGroup < bGroup
        end
        return a.label < b.label
    end)

    return cats
end