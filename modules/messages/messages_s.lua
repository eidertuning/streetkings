SKMessages = {}

local UNLOCK_MESSAGE_SENDER = 'StreetKings'
local UNLOCK_MESSAGE_AVATAR = 'streetkings'
local MESSAGE_DELIVERY_INTERVAL_SECONDS = 30
local SCHEDULER_CHECK_INTERVAL_MS = 1000
local LEGACY_HECTOR_FIRST_DELAY_SECONDS = 15
local hasSentMessage

---@type table<integer, { token: integer, enteredAt: integer }>
local activeSchedulerSessions = {}

---@param delayMinutes SKMessageTriggerDelayMinutes
---@return integer
local function delayRangeToSeconds(delayMinutes)
    local minSeconds = math.floor(delayMinutes.min * 60)
    local maxSeconds = math.floor(delayMinutes.max * 60)
    if minSeconds == maxSeconds then
        return minSeconds
    end

    return math.random(minSeconds, maxSeconds)
end

local function validateMessageDefs()
    for defId, def in pairs(SKMessageDefs) do
        assert(type(def.sender) == 'string' and def.sender ~= '', ('streetkings: invalid message sender for %s'):format(defId))
        assert(type(def.avatar) == 'string' and def.avatar ~= '', ('streetkings: invalid message avatar for %s'):format(defId))
        assert(type(def.once) == 'boolean', ('streetkings: invalid once flag for %s'):format(defId))
        assert(type(def.body) == 'string' and def.body ~= '', ('streetkings: invalid message body for %s'):format(defId))

        if def.trigger ~= nil then
            assert(type(def.trigger) == 'table', ('streetkings: invalid message trigger for %s'):format(defId))
            assert(type(def.trigger.kind) == 'string' and def.trigger.kind ~= '', ('streetkings: invalid trigger kind for %s'):format(defId))
            assert(type(def.trigger.delayMinutes) == 'table', ('streetkings: missing trigger delay range for %s'):format(defId))
            assert(type(def.trigger.delayMinutes.min) == 'number' and def.trigger.delayMinutes.min >= 0, ('streetkings: invalid trigger delay min for %s'):format(defId))
            assert(type(def.trigger.delayMinutes.max) == 'number' and def.trigger.delayMinutes.max >= def.trigger.delayMinutes.min, ('streetkings: invalid trigger delay max for %s'):format(defId))
            assert(def.trigger.conditions == nil or type(def.trigger.conditions) == 'table', ('streetkings: invalid trigger conditions for %s'):format(defId))
        end
    end
end

validateMessageDefs()

---@param metaData table
---@return table
local function ensureMetaData(metaData)
    if type(metaData.messages) ~= 'table' then metaData.messages = {} end
    if type(metaData.flags) ~= 'table' then metaData.flags = {} end
    if type(metaData.messageQueue) ~= 'table' then metaData.messageQueue = {} end
    if type(metaData.messageDelivery) ~= 'table' then metaData.messageDelivery = {} end
    if type(metaData.messageDelivery.lastDeliveredAt) ~= 'number' then metaData.messageDelivery.lastDeliveredAt = 0 end
    if type(metaData.messageScheduler) ~= 'table' then metaData.messageScheduler = {} end
    if type(metaData.messageScheduler.pending) ~= 'table' then metaData.messageScheduler.pending = {} end

    if type(metaData.hectorWelcomeSequence) == 'table' then
        local legacy = metaData.hectorWelcomeSequence
        local elapsedSeconds = type(legacy.elapsedSeconds) == 'number' and math.max(0, math.floor(legacy.elapsedSeconds)) or 0

        if not hasSentMessage(metaData, 'hector_welcome') and not metaData.messageScheduler.pending.hector_welcome then
            metaData.messageScheduler.pending.hector_welcome = {
                delaySeconds = LEGACY_HECTOR_FIRST_DELAY_SECONDS,
                elapsedSeconds = elapsedSeconds,
                triggerKind = 'legacyHectorWelcome',
            }
        end

        if not hasSentMessage(metaData, 'hector_welcome_followup_one')
            and not metaData.messageScheduler.pending.hector_welcome_followup_one
            and type(legacy.secondDelaySeconds) == 'number'
        then
            metaData.messageScheduler.pending.hector_welcome_followup_one = {
                delaySeconds = math.max(0, math.floor(legacy.secondDelaySeconds)),
                elapsedSeconds = elapsedSeconds,
                triggerKind = 'legacyHectorWelcome',
            }
        end

        if not hasSentMessage(metaData, 'hector_welcome_followup_two')
            and not metaData.messageScheduler.pending.hector_welcome_followup_two
            and type(legacy.thirdDelaySeconds) == 'number'
        then
            metaData.messageScheduler.pending.hector_welcome_followup_two = {
                delaySeconds = math.max(0, math.floor(legacy.thirdDelaySeconds)),
                elapsedSeconds = elapsedSeconds,
                triggerKind = 'legacyHectorWelcome',
            }
        end
    end

    metaData.hectorWelcomeSequence = nil
    return metaData
end

---@param metaData table
---@param defId string
---@return boolean
hasSentMessage = function(metaData, defId)
    return metaData.flags['msg_sent_' .. defId] == true
end

---@param actual any
---@param expected any
---@return boolean
local function matchesCondition(actual, expected)
    if type(expected) ~= 'table' then
        return actual == expected
    end

    local hasNumericKeys = false
    for key in pairs(expected) do
        if type(key) == 'number' then
            hasNumericKeys = true
            break
        end
    end

    if hasNumericKeys then
        for _, value in ipairs(expected) do
            if matchesCondition(actual, value) then
                return true
            end
        end
        return false
    end

    if type(actual) ~= 'table' then
        return false
    end

    for key, value in pairs(expected) do
        if not matchesCondition(actual[key], value) then
            return false
        end
    end

    return true
end

---@param def SKMessageDef
---@param kind string
---@param payload table
---@return boolean
local function triggerMatches(def, kind, payload)
    local trigger = def.trigger
    if not trigger or trigger.kind ~= kind then
        return false
    end

    if trigger.conditions == nil then
        return true
    end

    for key, expected in pairs(trigger.conditions) do
        if not matchesCondition(payload[key], expected) then
            return false
        end
    end

    return true
end

---@param message table
---@return table
local function buildStoredMessage(message)
    return {
        id = message.id,
        sender = message.sender,
        avatar = message.avatar,
        body = message.body,
        action = message.action,
        timestamp = os.time(),
        read = false,
    }
end

---@param src integer
---@param message table
local function notifyMessage(src, message)
    TriggerClientEvent('streetkings:messages:newMessage', src, {
        sender = message.sender,
        avatar = message.avatar,
        body = message.body,
        action = message.action,
    })
end

---@param metaData table
---@param message table
---@return table
local function deliverStoredMessage(metaData, message)
    local stored = buildStoredMessage(message)
    table.insert(metaData.messages, stored)
    return stored
end

---@param metaData table
---@param message table
local function enqueuePendingMessage(metaData, message)
    local queued = {
        id = message.id,
        sender = message.sender,
        avatar = message.avatar,
        body = message.body,
        action = message.action,
        banner = message.banner,
        deliverAt = message.deliverAt or 0,
    }

    local insertAt = #metaData.messageQueue + 1
    for i, existing in ipairs(metaData.messageQueue) do
        if queued.deliverAt < (existing.deliverAt or 0) then
            insertAt = i
            break
        end
    end

    table.insert(metaData.messageQueue, insertAt, queued)
end

---@param metaData table
---@return integer
local function getSecondsUntilNextDelivery(metaData)
    local elapsedSeconds = math.max(0, os.time() - metaData.messageDelivery.lastDeliveredAt)
    return math.max(0, MESSAGE_DELIVERY_INTERVAL_SECONDS - elapsedSeconds)
end

---@param src integer
---@param metaData table
---@return boolean, table|nil
local function deliverNextQueuedMessage(src, metaData)
    if #metaData.messageQueue == 0 then
        return false, nil
    end

    local queued = metaData.messageQueue[1]
    if type(queued.deliverAt) == 'number' and queued.deliverAt > os.time() then
        return false, nil
    end

    if getSecondsUntilNextDelivery(metaData) > 0 then
        return false, nil
    end

    queued = table.remove(metaData.messageQueue, 1)
    local stored = deliverStoredMessage(metaData, queued)
    metaData.messageDelivery.lastDeliveredAt = os.time()
    notifyMessage(src, stored)
    if type(queued.banner) == 'table' then
        TriggerClientEvent('streetkings:missions:autoWaypoint', src, queued.banner)
        if type(queued.banner.missionId) == 'string' and SKMissionsServer and SKMissionsServer.markUnlockDelivered then
            SKMissionsServer.markUnlockDelivered(src, queued.banner.missionId)
        end
    end
    return true, stored
end

---@param metaData table
---@param defId string
---@return boolean
local function queueStoredDef(metaData, defId)
    local def = assert(SKMessageDefs[defId], ('streetkings: missing message def %s'):format(defId))

    if def.once then
        local flagKey = 'msg_sent_' .. defId
        if metaData.flags[flagKey] then
            return false
        end
        metaData.flags[flagKey] = true
    end

    enqueuePendingMessage(metaData, {
        id = defId,
        sender = def.sender,
        avatar = def.avatar,
        body = def.body,
    })
    return true
end

---@param src integer
---@param metaData table
---@return integer
local function flushSchedulerProgress(src, metaData)
    local session = activeSchedulerSessions[src]
    if not session then
        return 0
    end

    local now = os.time()
    local delta = math.max(0, now - session.enteredAt)
    if delta == 0 then
        return 0
    end

    for _, pending in pairs(metaData.messageScheduler.pending) do
        pending.elapsedSeconds = pending.elapsedSeconds + delta
    end

    session.enteredAt = now
    return delta
end

---@param src integer
---@return integer
local function activeSessionElapsedSeconds(src)
    local session = activeSchedulerSessions[src]
    if not session then
        return 0
    end

    return math.max(0, os.time() - session.enteredAt)
end

---@param metaData table
---@param defId string
---@param payload table
---@return boolean
local function scheduleMessageDef(metaData, defId, payload)
    local def = assert(SKMessageDefs[defId], ('streetkings: missing message def %s'):format(defId))
    if not def.trigger then
        return false
    end

    if def.once and hasSentMessage(metaData, defId) then
        return false
    end

    if metaData.messageScheduler.pending[defId] then
        return false
    end

    local pending = {
        delaySeconds = delayRangeToSeconds(def.trigger.delayMinutes),
        elapsedSeconds = 0,
        triggerKind = def.trigger.kind,
    }

    if next(payload) ~= nil then
        pending.payload = payload
    end

    metaData.messageScheduler.pending[defId] = pending
    return true
end

---@param src integer
---@param metaData table
---@return boolean
local function collectDueMessages(src, metaData)
    local due = {}
    local sessionElapsed = activeSessionElapsedSeconds(src)

    for defId, pending in pairs(metaData.messageScheduler.pending) do
        if pending.elapsedSeconds + sessionElapsed >= pending.delaySeconds then
            due[#due + 1] = defId
        end
    end

    if #due == 0 then
        return false
    end

    table.sort(due)
    flushSchedulerProgress(src, metaData)

    local changed = false
    for _, defId in ipairs(due) do
        local pending = metaData.messageScheduler.pending[defId]
        if pending and pending.elapsedSeconds >= pending.delaySeconds then
            metaData.messageScheduler.pending[defId] = nil
            changed = queueStoredDef(metaData, defId) or changed
        end
    end

    return changed
end

---@param src integer
local function startSchedulerSession(src)
    local previous = activeSchedulerSessions[src]
    local token = previous and (previous.token + 1) or 1
    activeSchedulerSessions[src] = {
        token = token,
        enteredAt = os.time(),
    }

    CreateThread(function()
        while true do
            Wait(SCHEDULER_CHECK_INTERVAL_MS)

            local session = activeSchedulerSessions[src]
            if not session or session.token ~= token or not SKSaves.hasActiveSave(src) then
                return
            end

            local metaData = SKSaves.read(src, 'meta.data')
            ensureMetaData(metaData)
            local changed = collectDueMessages(src, metaData)
            if not changed then
                goto continue
            end

            SKSaves.write(src, 'meta.data', metaData)

            ::continue::
        end
    end)
end

---@param src integer
local function stopSchedulerSession(src)
    if not activeSchedulerSessions[src] then
        return
    end

    if SKSaves.hasActiveSave(src) then
        local metaData = SKSaves.read(src, 'meta.data')
        ensureMetaData(metaData)
        local delta = flushSchedulerProgress(src, metaData)
        if delta > 0 then
            SKSaves.write(src, 'meta.data', metaData)
        end
    end

    activeSchedulerSessions[src] = nil
end

---@param src integer
---@param sender string
---@param avatar string
---@param body string
---@param delaySeconds integer|nil
---@param action SKMessageAction|nil
---@param banner table|nil optional autoWaypoint payload fired when this message actually delivers
function SKMessages.enqueue(src, sender, avatar, body, delaySeconds, action, banner)
    local metaData = SKSaves.read(src, 'meta.data')
    ensureMetaData(metaData)

    enqueuePendingMessage(metaData, {
        sender = sender,
        avatar = avatar,
        body = body,
        action = action,
        banner = banner,
        deliverAt = type(delaySeconds) == 'number' and (os.time() + math.max(0, math.floor(delaySeconds))) or 0,
    })

    SKSaves.write(src, 'meta.data', metaData)
end

---@param sender string
---@param avatar string
---@param body string
---@param action SKMessageAction|nil
---@param options { excludeSource: integer|nil }|nil
function SKMessages.broadcast(sender, avatar, body, action, options)
    local excludeSource = options and options.excludeSource or nil
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if source and source ~= excludeSource and SKSaves.hasActiveSave(source) then
            SKMessages.enqueue(source, sender, avatar, body, nil, action)
        end
    end
end

---@param src integer
---@param sender string
---@param avatar string
---@param body string
---@param delaySeconds integer
function SKMessages.enqueueDelayed(src, sender, avatar, body, delaySeconds)
    SKMessages.enqueue(src, sender, avatar, body, delaySeconds)
end

---@param src integer
---@param body string
function SKMessages.enqueueUnlockMessage(src, body)
    if type(body) ~= 'string' or body == '' then return end
    SKMessages.enqueue(src, UNLOCK_MESSAGE_SENDER, UNLOCK_MESSAGE_AVATAR, body)
end

---@param src integer
---@param defId string
---@return boolean
function SKMessages.send(src, defId)
    local metaData = SKSaves.read(src, 'meta.data')
    ensureMetaData(metaData)

    local queued = queueStoredDef(metaData, defId)
    if not queued then
        return false
    end

    SKSaves.write(src, 'meta.data', metaData)
    return true
end

---@param src integer
---@param kind string
---@param payload table|nil
---@return boolean
function SKMessages.trigger(src, kind, payload)
    if type(src) ~= 'number' or type(kind) ~= 'string' or not SKSaves.hasActiveSave(src) then
        return false
    end

    payload = type(payload) == 'table' and payload or {}

    local metaData = SKSaves.read(src, 'meta.data')
    ensureMetaData(metaData)

    if activeSchedulerSessions[src] then
        flushSchedulerProgress(src, metaData)
    end

    local changed = false
    for defId, def in pairs(SKMessageDefs) do
        if triggerMatches(def, kind, payload) and scheduleMessageDef(metaData, defId, payload) then
            changed = true
        end
    end

    local dueChanged = false
    if activeSchedulerSessions[src] then
        dueChanged = collectDueMessages(src, metaData)
        changed = changed or dueChanged
    end

    if not changed then
        return false
    end

    SKSaves.write(src, 'meta.data', metaData)
    return true
end

AddEventHandler('streetkings:messages:trigger', function(src, kind, payload)
    SKMessages.trigger(src, kind, payload)
end)

AddEventHandler('streetkings:freeroam:enter', function()
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then
        return
    end

    startSchedulerSession(src)
end)

AddEventHandler('streetkings:freeroam:exit', function()
    local src = source --[[@as integer]]
    if SKSaves.hasActiveSave(src) then
        local missions = SKSaves.read(src, 'missions')
        if type(missions) == 'table' and missions.currentMissionId then return end
    end
    stopSchedulerSession(src)
end)

AddEventHandler('playerDropped', function()
    stopSchedulerSession(source --[[@as integer]])
end)

lib.callback.register('streetkings:messages:getData', function(source)
    local metaData = SKSaves.read(source, 'meta.data')
    ensureMetaData(metaData)

    local unread = 0
    for _, msg in ipairs(metaData.messages) do
        if not msg.read then unread = unread + 1 end
    end

    return { messages = metaData.messages, unread = unread }
end)

lib.callback.register('streetkings:messages:markRead', function(source, sender)
    local metaData = SKSaves.read(source, 'meta.data')
    ensureMetaData(metaData)

    for _, msg in ipairs(metaData.messages) do
        if msg.sender == sender then
            msg.read = true
        end
    end

    SKSaves.write(source, 'meta.data', metaData)
    return { ok = true }
end)

lib.callback.register('streetkings:messages:deliverQueued', function(source)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, delivered = false }
    end

    local metaData = SKSaves.read(source, 'meta.data')
    ensureMetaData(metaData)

    if #metaData.messageQueue == 0 then
        return { ok = true, delivered = false }
    end

    local delivered = select(1, deliverNextQueuedMessage(source, metaData))
    if not delivered then
        return { ok = true, delivered = false, remainingSeconds = getSecondsUntilNextDelivery(metaData) }
    end

    SKSaves.write(source, 'meta.data', metaData)

    return { ok = true, delivered = true, remainingSeconds = 0 }
end)

exports('SendPhoneMessage', function(source, sender, avatar, body, delaySeconds, action, banner)
    if type(sender) ~= 'string' or type(body) ~= 'string' then return false end
    if not SKSaves.hasActiveSave(source) then return false end
    SKMessages.enqueue(source, sender, avatar, body, delaySeconds, action, banner)
    return true
end)
exports('BroadcastPhoneMessage', function(sender, avatar, body, action, options)
    if type(sender) ~= 'string' or type(body) ~= 'string' then return false end
    SKMessages.broadcast(sender, avatar, body, action, options)
    return true
end)