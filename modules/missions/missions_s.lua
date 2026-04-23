SKMissionsServer = {}

local ADVANCE_COOLDOWN_MS = 400
local UNLOCK_TICK_SECONDS = 30
local MAX_POSITION_DELTA_SQR = 225.0 -- 15m tolerance squared

local lastAdvance = {} ---@type table<integer, integer>
local unlockWatchers = {} ---@type table<integer, integer>
local unlockWatcherTokens = {} ---@type table<integer, integer>

---@param src integer
---@return SKSaveMissionsDocument|nil
local function readMissions(src)
    if not SKSaves.hasActiveSave(src) then return nil end
    local missions = SKSaves.read(src, 'missions')
    if type(missions) ~= 'table' then
        missions = SKSaves.defaultMissions()
        SKSaves.write(src, 'missions', missions)
    end
    return missions
end

---@param src integer
---@param missions SKSaveMissionsDocument
local function writeMissions(src, missions)
    SKSaves.write(src, 'missions', missions)
end

---@param mission table
---@return integer
local function rollCooldown(mission)
    if SKMissionsConfig and SKMissionsConfig.DEV_SKIP_COOLDOWN then return 0 end
    local cd = mission and mission.cooldown
    if type(cd) ~= 'table' then return 0 end
    local min = cd.minSeconds or 0
    local max = cd.maxSeconds or min
    return SKMissionsShared.rollCooldown(min, max)
end

---@param src integer
---@param missions SKSaveMissionsDocument
---@return table|nil, string|nil, integer|nil
local function getPendingMission(missions)
    return SKMissionDefs.getNext(missions)
end

---@param src integer
---@param missions SKSaveMissionsDocument
---@param mission table
---@return table|nil
local function buildBannerPayload(mission)
    if type(mission) ~= 'table' then return nil end
    local sb = mission.startBlip
    if type(sb) ~= 'table' or type(sb.coords) ~= 'vector3' then return nil end
    return {
        missionId = mission.id,
        label = mission.title or sb.label or 'New Mission',
        subtitle = mission.subtitle or '',
        coords = { x = sb.coords.x, y = sb.coords.y, z = sb.coords.z },
    }
end

---@param src integer
---@param mission table
---@param banner table|nil optional banner payload attached to the main unlock SMS
local function enqueueUnlockMessage(src, mission, banner)
    local msg = mission and mission.unlockMessage
    if type(msg) == 'table' and type(msg.body) == 'string' and msg.body ~= '' then
        local sender = msg.sender or (mission.giver and mission.giver.name) or 'Unknown'
        local avatar = msg.avatar or (mission.giver and mission.giver.avatar) or 'unknown'
        SKMessages.enqueue(src, sender, avatar, msg.body, 0, nil, banner)
    end

    if mission and type(mission.unlockFollowUps) == 'table' then
        for _, m in ipairs(mission.unlockFollowUps) do
            if type(m) == 'table' and type(m.body) == 'string' and m.body ~= '' then
                local sender = m.sender or (mission.giver and mission.giver.name) or 'Unknown'
                local avatar = m.avatar or (mission.giver and mission.giver.avatar) or 'unknown'
                SKMessages.enqueue(src, sender, avatar, m.body, m.delaySeconds or 0)
            end
        end
    end
end

---@param src integer
---@param mission table
local function pushAutoWaypoint(src, mission)
    local payload = buildBannerPayload(mission)
    if not payload then return end
    TriggerClientEvent('streetkings:missions:autoWaypoint', src, payload)
end

---@param src integer
---@return table
local function buildSnapshot(src)
    local missions = readMissions(src)
    if not missions then
        return { ok = false, reason = 'no_active_save' }
    end

    local now = os.time()
    local pending, chapterId, missionIndex = getPendingMission(missions)

    if not pending then
        return {
            ok = true,
            status = MissionStatus.FINISHED,
            chapterId = nil,
            missionIndex = 0,
            active = nil,
            pending = nil,
            cooldownRemaining = 0,
            flags = missions.flags or {},
        }
    end

    if pending.unlockMessage and not missions.currentMissionId then
        local unlockEnqueued = missions.flags and missions.flags['msg_unlock_' .. pending.id]
        local unlockDelivered = missions.flags and missions.flags['msg_delivered_' .. pending.id]
        if unlockEnqueued and not unlockDelivered then
            return {
                ok = true,
                status = MissionStatus.LOCKED,
                chapterId = chapterId,
                missionIndex = missionIndex,
                active = nil,
                pending = nil,
                cooldownRemaining = 0,
                flags = missions.flags or {},
            }
        end
    end

    local active = nil
    if missions.currentMissionId then
        local def = SKMissionDefs.get(missions.currentMissionId)
        if def then
            local oIdx = missions.currentObjectiveIndex or 1
            local objective = def.objectives and def.objectives[oIdx] or nil
            local required = (objective and tonumber(objective.count)) or 0
            local progressKey = ('objProgress:%s:%d'):format(missions.currentMissionId, oIdx)
            local current = tonumber(missions.flags and missions.flags[progressKey]) or 0
            active = {
                missionId = missions.currentMissionId,
                objectiveIndex = oIdx,
                def = def,
                progress = {
                    current = current,
                    required = required,
                },
            }
        end
    end

    local status
    if active then
        status = MissionStatus.ACTIVE
    elseif (missions.nextAvailableAt or 0) > now then
        status = MissionStatus.COOLDOWN
    else
        status = MissionStatus.AVAILABLE
    end

    return {
        ok = true,
        status = status,
        chapterId = chapterId,
        missionIndex = missionIndex,
        active = active,
        pending = {
            missionId = pending.id,
            def = pending,
        },
        cooldownRemaining = math.max(0, (missions.nextAvailableAt or 0) - now),
        flags = missions.flags or {},
    }
end

---@param src integer
local function pushSnapshot(src)
    local snapshot = buildSnapshot(src)
    TriggerClientEvent('streetkings:missions:sync', src, snapshot)
end

---@param src integer
---@param missionId string
function SKMissionsServer.markUnlockDelivered(src, missionId)
    if type(missionId) ~= 'string' or missionId == '' then return end
    if not SKSaves.hasActiveSave(src) then return end
    local missions = readMissions(src)
    if not missions then return end
    missions.flags = missions.flags or {}
    local key = 'msg_delivered_' .. missionId
    if missions.flags[key] then return end
    missions.flags[key] = true
    writeMissions(src, missions)
    pushSnapshot(src)
end

---@param src integer
---@param missions SKSaveMissionsDocument
---@return boolean
local function tryUnlockNext(src, missions)
    if missions.currentMissionId then return false end
    if (missions.nextAvailableAt or 0) > os.time() then return false end

    local pending, _, _ = getPendingMission(missions)
    if not pending then return false end

    local flagKey = 'msg_unlock_' .. pending.id
    if missions.flags[flagKey] then return false end

    missions.flags[flagKey] = true
    writeMissions(src, missions)
    enqueueUnlockMessage(src, pending, buildBannerPayload(pending))
    pushSnapshot(src)
    return true
end

---@param src integer
local function startUnlockWatcher(src)
    if unlockWatchers[src] then return end
    local nextToken = (unlockWatcherTokens[src] or 0) + 1
    unlockWatcherTokens[src] = nextToken
    unlockWatchers[src] = nextToken

    CreateThread(function()
        while unlockWatchers[src] == nextToken do
            Wait(UNLOCK_TICK_SECONDS * 1000)
            if unlockWatchers[src] ~= nextToken or not SKSaves.hasActiveSave(src) then return end

            local missions = readMissions(src)
            if missions then
                tryUnlockNext(src, missions)
            end
        end
    end)
end

---@param src integer
local function stopUnlockWatcher(src)
    unlockWatchers[src] = nil
    lastAdvance[src] = nil
end

---@param src integer
---@param missions SKSaveMissionsDocument
---@param mission table
---@param chapterId string
---@param missionIndex integer
local function startMission(src, missions, mission, chapterId, missionIndex)
    missions.chapter = SKMissionDefs.chapterPosition(chapterId)
    missions.chapterMissionIndex = missionIndex - 1
    missions.currentMissionId = mission.id
    missions.currentObjectiveIndex = 1
    writeMissions(src, missions)
    pushSnapshot(src)
end

---@param src integer
---@param missions SKSaveMissionsDocument
---@param mission table
local function completeMission(src, missions, mission)
    local chapterPos = missions.chapter
    local chapterId = SKMissionDefs.listChapters()[chapterPos]

    missions.completed[mission.id] = os.time()
    missions.currentMissionId = nil
    missions.currentObjectiveIndex = 0
    missions.lastCompletedAt = os.time()
    missions.chapterMissionIndex = (missions.chapterMissionIndex or 0) + 1

    if type(mission.flagsOnComplete) == 'table' then
        for k, v in pairs(mission.flagsOnComplete) do
            missions.flags[k] = v
        end
    end

    local cooldown = rollCooldown(mission)
    missions.nextAvailableAt = os.time() + cooldown

    local rewards = mission.rewards or {}
    if type(rewards.cash) == 'number' and rewards.cash > 0 then
        local cash = SKSaves.read(src, 'economy.cash') or 0
        SKSaves.write(src, 'economy.cash', cash + rewards.cash)
        SKStats.increment(src, 'totalCashEarned', rewards.cash)
    end
    if type(rewards.playerXp) == 'number' and rewards.playerXp > 0 then
        SKProgression.awardPlayerXp(src, rewards.playerXp)
    end

    if type(mission.endMessage) == 'table' and type(mission.endMessage.body) == 'string' then
        local sender = mission.endMessage.sender or (mission.giver and mission.giver.name) or 'Unknown'
        local avatar = mission.endMessage.avatar or (mission.giver and mission.giver.avatar) or 'unknown'
        SKMessages.enqueue(src, sender, avatar, mission.endMessage.body, 2)
    end

    if type(mission.followUpMessages) == 'table' then
        for _, m in ipairs(mission.followUpMessages) do
            if type(m) == 'table' and type(m.body) == 'string' and m.body ~= '' then
                local sender = m.sender or (mission.giver and mission.giver.name) or 'Unknown'
                local avatar = m.avatar or (mission.giver and mission.giver.avatar) or 'unknown'
                SKMessages.enqueue(src, sender, avatar, m.body, m.delaySeconds or 0)
            end
        end
    end

    writeMissions(src, missions)

    TriggerClientEvent('streetkings:missions:completed', src, {
        missionId = mission.id,
        rewards = rewards,
        cooldownSeconds = cooldown,
        finale = mission.finale == true,
    })
    pushSnapshot(src)
end

---@param src integer
---@return boolean
local function rateLimited(src)
    local now = GetGameTimer()
    local last = lastAdvance[src] or 0
    if now - last < ADVANCE_COOLDOWN_MS then return true end
    lastAdvance[src] = now
    return false
end

---@param src integer
---@param missionId string
---@param objective table
---@param context table|nil
---@return boolean
local function validateObjective(src, missionId, objective, context)
    if type(context) == 'table' and context.source == 'dev_skip' then return true end
    local otype = objective.type
    if otype == ObjectiveType.VISIT_LOCATION then
        local coords = objective.coords
        if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return true end
        local ped = GetPlayerPed(src)
        if ped == 0 then return false end
        local pcoords = GetEntityCoords(ped)
        local dx = pcoords.x - (coords.x or 0)
        local dy = pcoords.y - (coords.y or 0)
        local dz = pcoords.z - (coords.z or 0)
        local distSq = dx * dx + dy * dy + dz * dz
        local radius = (objective.radius or 6.0) + 3.0
        return distSq <= (radius * radius + MAX_POSITION_DELTA_SQR)
    elseif otype == ObjectiveType.COMPLETE_EVENT then
        return type(context) == 'table' and context.source == 'server_event'
    elseif otype == ObjectiveType.NPC_CHALLENGE then
        return type(context) == 'table' and context.source == 'server_npc_challenge'
    elseif otype == ObjectiveType.CUTSCENE or otype == ObjectiveType.DIALOG then
        return true
    elseif otype == ObjectiveType.PICKUP_PACKAGE or otype == ObjectiveType.DELIVER_PACKAGE then
        return true
    elseif otype == ObjectiveType.TAIL_NPC or otype == ObjectiveType.ESCAPE then
        return true
    elseif otype == ObjectiveType.SCRIPTED_RACE then
        return type(context) == 'table' and context.source == 'scripted_race'
    end
    return true
end

---@param src integer
---@param context table|nil
---@return table
function SKMissionsServer.advanceObjective(src, context)
    if rateLimited(src) then return { ok = false, reason = 'rate_limited' } end
    local missions = readMissions(src)
    if not missions then return { ok = false, reason = 'no_active_save' } end
    if not missions.currentMissionId then return { ok = false, reason = 'no_active_mission' } end

    local mission = SKMissionDefs.get(missions.currentMissionId)
    if not mission then return { ok = false, reason = 'unknown_mission' } end

    local idx = missions.currentObjectiveIndex or 1
    local objective = mission.objectives[idx]
    if not objective then return { ok = false, reason = 'no_active_objective' } end

    if not validateObjective(src, mission.id, objective, context) then
        return { ok = false, reason = 'validation_failed' }
    end

    if type(objective.completionMessage) == 'table' and type(objective.completionMessage.body) == 'string' then
        local msg = objective.completionMessage
        local sender = msg.sender or (mission.giver and mission.giver.name) or 'Unknown'
        local avatar = msg.avatar or (mission.giver and mission.giver.avatar) or 'unknown'
        SKMessages.enqueue(src, sender, avatar, msg.body, 0)
    end

    idx = idx + 1
    if idx > #mission.objectives then
        completeMission(src, missions, mission)
        return { ok = true, completed = true }
    end

    missions.currentObjectiveIndex = idx
    writeMissions(src, missions)
    pushSnapshot(src)
    return { ok = true, completed = false, objectiveIndex = idx }
end

---@param src integer
---@return table
function SKMissionsServer.startPendingMission(src)
    if rateLimited(src) then return { ok = false, reason = 'rate_limited' } end
    local missions = readMissions(src)
    if not missions then return { ok = false, reason = 'no_active_save' } end
    if missions.currentMissionId then return { ok = false, reason = 'mission_active' } end
    if (missions.nextAvailableAt or 0) > os.time() then return { ok = false, reason = 'on_cooldown' } end

    local pending, chapterId, missionIndex = getPendingMission(missions)
    if not pending then return { ok = false, reason = 'no_pending' } end

    startMission(src, missions, pending, chapterId, missionIndex)
    return { ok = true, missionId = pending.id }
end

---@param src integer
---@return table
function SKMissionsServer.abortMission(src)
    local missions = readMissions(src)
    if not missions then return { ok = false, reason = 'no_active_save' } end
    if not missions.currentMissionId then return { ok = true, aborted = false } end

    missions.currentMissionId = nil
    missions.currentObjectiveIndex = 0
    writeMissions(src, missions)
    pushSnapshot(src)
    return { ok = true, aborted = true }
end

---@param src integer
---@param eventId string
---@param context table
local function onEventCompleted(src, eventId, context)
    if not SKSaves.hasActiveSave(src) then return end
    local missions = readMissions(src)
    if not missions or not missions.currentMissionId then return end

    local mission = SKMissionDefs.get(missions.currentMissionId)
    if not mission then return end

    local idx = missions.currentObjectiveIndex or 1
    local objective = mission.objectives[idx]
    if not objective or objective.type ~= ObjectiveType.COMPLETE_EVENT then return end

    local filter = objective.filter or {}
    if filter.eventId and filter.eventId ~= eventId then return end
    if filter.scoreType and filter.scoreType ~= context.scoreType then return end
    if filter.goalMet == true and not context.goalMet then return end

    local required = tonumber(objective.count) or 1
    if required <= 1 then
        SKMissionsServer.advanceObjective(src, { source = 'server_event', eventId = eventId, context = context })
        return
    end

    local progressKey = ('objProgress:%s:%d'):format(mission.id, idx)
    local current = tonumber(missions.flags[progressKey]) or 0
    current = current + 1

    if current >= required then
        missions.flags[progressKey] = nil
        writeMissions(src, missions)
        SKMissionsServer.advanceObjective(src, { source = 'server_event', eventId = eventId, context = context })
    else
        missions.flags[progressKey] = current
        writeMissions(src, missions)
        pushSnapshot(src)
    end
end

lib.callback.register('streetkings:missions:getState', function(source)
    if not SKSaves.hasActiveSave(source) then return { ok = false, reason = 'no_active_save' } end
    return buildSnapshot(source)
end)

lib.callback.register('streetkings:missions:startPending', function(source)
    if not SKSaves.hasActiveSave(source) then return { ok = false, reason = 'no_active_save' } end
    return SKMissionsServer.startPendingMission(source)
end)

lib.callback.register('streetkings:missions:advanceObjective', function(source, context)
    if not SKSaves.hasActiveSave(source) then return { ok = false, reason = 'no_active_save' } end
    return SKMissionsServer.advanceObjective(source, context)
end)

lib.callback.register('streetkings:missions:abort', function(source)
    if not SKSaves.hasActiveSave(source) then return { ok = false, reason = 'no_active_save' } end
    return SKMissionsServer.abortMission(source)
end)

function SKMissionsServer.resetMission(src)
    local missions = readMissions(src)
    if not missions then return { ok = false, reason = 'no_active_save' } end
    if not missions.currentMissionId then return { ok = false, reason = 'no_active_mission' } end
    missions.currentObjectiveIndex = 1
    for k in pairs(missions.flags or {}) do
        if type(k) == 'string' and k:find('^objProgress:') then
            missions.flags[k] = nil
        end
    end
    writeMissions(src, missions)
    pushSnapshot(src)
    return { ok = true }
end

lib.callback.register('streetkings:missions:resetMission', function(source)
    if not SKSaves.hasActiveSave(source) then return { ok = false, reason = 'no_active_save' } end
    return SKMissionsServer.resetMission(source)
end)

---@param src integer
function SKMissionsServer.initializeForPlayer(src)
    if not SKSaves.hasActiveSave(src) then return end
    local missions = readMissions(src)
    if not missions then return end

    local tutorialDone = SKSaves.read(src, 'progression.tutorialCompleted')
    if tutorialDone and missions.chapter == 0 then
        missions.chapter = 1
        missions.chapterMissionIndex = 0
        missions.nextAvailableAt = 0
        writeMissions(src, missions)
    end

    if missions.currentMissionId then
        local mdef = SKMissionDefs.get(missions.currentMissionId)
        if mdef and mdef.resetOnLoad then
            missions.currentMissionId = nil
            missions.currentObjectiveIndex = 0
            missions.nextAvailableAt = 0
            for k in pairs(missions.flags or {}) do
                if type(k) == 'string' and k:find('^objProgress:') then
                    missions.flags[k] = nil
                end
            end
            writeMissions(src, missions)
        end
    end

    startUnlockWatcher(src)
    local unlocked = tryUnlockNext(src, missions)
    if not unlocked and not missions.currentMissionId and (missions.nextAvailableAt or 0) <= os.time() then
        local pending, _, _ = getPendingMission(missions)
        if pending and missions.flags and missions.flags['msg_delivered_' .. pending.id] then
            pushAutoWaypoint(src, pending)
        end
    end
    pushSnapshot(src)
end

AddEventHandler('streetkings:freeroam:enter', function()
    local src = source --[[@as integer]]
    SKMissionsServer.initializeForPlayer(src)
end)

AddEventHandler('streetkings:freeroam:exit', function()
    local src = source --[[@as integer]]
    local missions = readMissions(src)
    if missions and missions.currentMissionId then return end
    stopUnlockWatcher(src)
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    stopUnlockWatcher(src)
    unlockWatcherTokens[src] = nil
end)

AddEventHandler('streetkings:server:recordNpcRace', function(src, isWin)
    if not src or not SKSaves.hasActiveSave(src) then return end
    local missions = readMissions(src)
    if not missions or not missions.currentMissionId then return end

    local mission = SKMissionDefs.get(missions.currentMissionId)
    if not mission then return end

    local idx = missions.currentObjectiveIndex or 1
    local objective = mission.objectives[idx]
    if not objective or objective.type ~= ObjectiveType.NPC_CHALLENGE then return end

    local won = isWin == true

    if missions.currentMissionId == 'local_legend' then
        missions.flags = missions.flags or {}
        missions.flags['mission1_wonChallenge'] = won
        writeMissions(src, missions)

        local body = won
            and "Ha. You took him clean. Knew I had the right guy. Now go run a solo event - show it wasn't luck."
            or  "Shake it off, rookie. Everybody eats asphalt once. Go run a solo event and sharpen up."
        SKMessages.enqueue(src, 'Hector', 'hector', body, 0)
    end

    SKMissionsServer.advanceObjective(src, { source = 'server_npc_challenge', won = won })
end)

-- This is just a hack to hook into the events submit function and advance the mission objective when the event is completed
local originalSubmit = SKEventsSubmit.submitActivityScore
SKEventsSubmit.submitActivityScore = function(source, eventId, scoreValue, vehicleModel)
    local result = originalSubmit(source, eventId, scoreValue, vehicleModel)
    if result and result.ok then
        local goalMet = false
        if result.scoreType == 'time' then
            local activity = SKEvents and SKEvents[eventId]
            if activity and type(activity.goalTime) == 'number' then
                goalMet = scoreValue <= math.floor(activity.goalTime * 1000)
            end
        end
        onEventCompleted(source, eventId, {
            scoreType = result.scoreType,
            scoreValue = scoreValue,
            goalMet = goalMet,
        })
    end
    return result
end

lib.addCommand('missionskip', {
    help = 'Force-advance the current mission objective',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return end
    SKMissionsServer.advanceObjective(source, { source = 'dev_skip' })
end)

lib.addCommand('missioncooldownclear', {
    help = 'Clear the next-mission cooldown so the next unlock fires immediately',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return end
    local missions = readMissions(source)
    if not missions then return end
    missions.nextAvailableAt = 0
    writeMissions(source, missions)
    tryUnlockNext(source, missions)
end)

lib.addCommand('missionreset', {
    help = 'Reset all mission progress on the active save (development)',
    restricted = 'group.admin',
}, function(source)
    if source == 0 or not SKSaves.hasActiveSave(source) then return end
    local fresh = SKSaves.defaultMissions()
    fresh.chapter = 1
    SKSaves.write(source, 'missions', fresh)
    SKMissionsServer.initializeForPlayer(source)
end)

lib.addCommand('testmission', {
    help = 'Jump to a specific mission number (e.g. /testmission 3)',
    restricted = 'group.admin',
    params = {
        { name = 'number', type = 'number', help = 'Mission number (1-based index in current chapter)', optional = false },
    },
}, function(source, args)
    if source == 0 or not SKSaves.hasActiveSave(source) then return end
    local num = math.floor(args.number)
    if num < 1 then return end

    local fresh = SKSaves.defaultMissions()
    fresh.chapter = 1
    fresh.chapterMissionIndex = num - 1
    fresh.nextAvailableAt = 0
    fresh.currentMissionId = nil

    for i = 1, num - 1 do
        local m = SKMissionDefs.getByIndex('chapter1', i)
        if m then fresh.completed[m.id] = true end
    end

    SKSaves.write(source, 'missions', fresh)
    SKMissionsServer.initializeForPlayer(source)
end)

RegisterNetEvent('streetkings:missions:midMessage', function(sender, avatar, body)
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then return end
    if type(sender) ~= 'string' or type(avatar) ~= 'string' or type(body) ~= 'string' then return end
    SKMessages.enqueue(src, sender, avatar, body, 0)
end)