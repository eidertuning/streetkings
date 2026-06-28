local BUST_AMOUNT        = 1000
local BUST_COOLDOWN_MS   = 8000
local TRAP_SPAWN_PERCENT = 0.20

---@type table<integer, integer>
local lastBustAt = {}

---@param src integer
---@return boolean
local function canApplyBustFine(src)
    if not SKSaves.hasActiveSave(src) then
        return false
    end

    local now = GetGameTimer()
    if lastBustAt[src] and (now - lastBustAt[src]) < BUST_COOLDOWN_MS then
        return false
    end

    return true
end

AddEventHandler('playerDropped', function()
    lastBustAt[source --[[@as integer]]] = nil
end)

-- Select active traps on resource start ---------------------------------

local activeTraps = {}

local function selectActiveTraps()
    local locations = SKPoliceTrapLocations
    local count     = math.max(1, math.ceil(#locations * TRAP_SPAWN_PERCENT))
    local pool      = {}
    for i = 1, #locations do pool[i] = i end

    activeTraps = {}
    for i = 1, count do
        local pick = math.random(i, #pool)
        pool[i], pool[pick] = pool[pick], pool[i]
        activeTraps[#activeTraps + 1] = locations[pool[i]]
    end

end

selectActiveTraps()

-- Callbacks -------------------------------------------------------------

lib.callback.register('streetkings:police:getActiveTraps', function(_)
    return activeTraps
end)

lib.callback.register('streetkings:police:confirmBust', function(src)
    if not canApplyBustFine(src) then
        return { ok = false }
    end

    lastBustAt[src] = GetGameTimer()
    local current = SKSaves.read(src, 'economy.cash')
    local deducted = math.min(current, BUST_AMOUNT)
    local afterCash = math.max(0, current - BUST_AMOUNT)
    SKSaves.write(src, 'economy.cash', afterCash)
    SKStats.increment(src, 'totalCashSpent', deducted)
    SKStats.increment(src, 'policeBusts', 1)

    if SKLogs then
        SKLogs.Emit('policeBust', {
            source = src,
            deducted = deducted,
            beforeCash = current,
            afterCash = afterCash,
        })
    end

    return { ok = true }
end)
