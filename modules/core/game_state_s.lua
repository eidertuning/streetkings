SKGameStateServer = SKGameStateServer or {}

local TRANSITION_TTL_MS = 30000

---@type table<integer, string>
local currentBySource = {}

---@type table<integer, { token: string, prev: string|nil, next: string, issuedAt: integer, begun: boolean }>
local pendingBySource = {}

---@type table<string, true>
local validStateIds = {}
for _, stateId in pairs(GameState) do
    validStateIds[stateId] = true
end

---@param source integer
---@return { token: string, prev: string|nil, next: string, issuedAt: integer, begun: boolean }|nil
local function getPending(source)
    local pending = pendingBySource[source]
    if not pending then
        return nil
    end
    if (GetGameTimer() - pending.issuedAt) > TRANSITION_TTL_MS then
        pendingBySource[source] = nil
        return nil
    end
    return pending
end

---@param source integer
---@param prevState string|nil
---@param nextState string
---@return table
local function issueTransitionToken(source, prevState, nextState)
    if not validStateIds[nextState] then
        return { ok = false, reason = 'invalid_state' }
    end

    local currentState = currentBySource[source]
    if currentState ~= prevState then
        return { ok = false, reason = 'state_mismatch' }
    end

    if getPending(source) then
        return { ok = false, reason = 'transition_pending' }
    end

    local token = lib.string.random('................')
    pendingBySource[source] = {
        token = token,
        prev = prevState,
        next = nextState,
        issuedAt = GetGameTimer(),
        begun = false,
    }

    return { ok = true, token = token }
end

---@param source integer
---@return string|nil
function SKGameStateServer.get(source)
    return currentBySource[source]
end

---@param source integer
---@return string|nil
function SKGameStateServer.getPendingNext(source)
    local pending = getPending(source)
    return pending and pending.next or nil
end

---@param source integer
---@param state string|nil
function SKGameStateServer.set(source, state)
    currentBySource[source] = state
    pendingBySource[source] = nil
end

lib.callback.register('streetkings:core:requestStateTransition', function(source, prevState, nextState)
    if prevState ~= nil and type(prevState) ~= 'string' then
        return { ok = false, reason = 'invalid_prev_state' }
    end
    if type(nextState) ~= 'string' then
        return { ok = false, reason = 'invalid_next_state' }
    end
    return issueTransitionToken(source, prevState, nextState)
end)

RegisterNetEvent('streetkings:core:stateTransitionWill', function(token)
    local src = source --[[@as integer]]
    if type(token) ~= 'string' then
        return
    end
    local pending = getPending(src)
    if not pending or pending.token ~= token then
        return
    end
    pending.begun = true
end)

RegisterNetEvent('streetkings:core:stateTransitionDid', function(token)
    local src = source --[[@as integer]]
    if type(token) ~= 'string' then
        return
    end
    local pending = getPending(src)
    if not pending or pending.token ~= token or not pending.begun then
        return
    end
    currentBySource[src] = pending.next
    pendingBySource[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    currentBySource[src] = nil
    pendingBySource[src] = nil
end)

exports('GetPlayerGameState', SKGameStateServer.get)