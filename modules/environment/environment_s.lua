local totalGameMinutes = SKEnvironment.START_HOUR * 60.0

local currentWeather   = 'CLEAR'
local prevWeather      = 'CLEAR'
local transitionStart  = 0
local weatherChangedAt = 0

---@return integer hour, integer minute, integer second
local function gameTime()
    local total   = math.floor(totalGameMinutes)
    local hours   = math.floor(total / 60) % 24
    local minutes = total % 60
    return hours, minutes, 0
end

---@param hour integer
---@return string
local function pickWeather(hour)
    local period   = SKEnvironment.getPeriod(hour)
    local weathers = period.weathers
    return weathers[math.random(#weathers)]
end

---@return number 0.0–1.0
local function transitionPct()
    local elapsed = (GetGameTimer() - transitionStart)
    return math.min(elapsed / SKEnvironment.WEATHER_TRANSITION_MS, 1.0)
end

---@return table
local function buildSyncPayload()
    local h, m, s = gameTime()
    return {
        h           = h,
        m           = m,
        s           = s,
        weather     = currentWeather,
        prevWeather = prevWeather,
        transitionPct = transitionPct(),
    }
end

RegisterNetEvent('streetkings:environment:requestSync', function()
    local src = source --[[@as integer]]
    TriggerClientEvent('streetkings:environment:sync', src, buildSyncPayload())
end)

---@param hour integer 0–23
function SKEnvironment.SetHour(hour)
    totalGameMinutes = (hour % 24) * 60.0
    TriggerClientEvent('streetkings:environment:sync', -1, buildSyncPayload())
end

---@param weather string
function SKEnvironment.SetWeather(weather)
    prevWeather     = currentWeather
    currentWeather  = weather
    transitionStart = GetGameTimer()
    weatherChangedAt = GetGameTimer()
    TriggerClientEvent('streetkings:environment:sync', -1, buildSyncPayload())
end

CreateThread(function()
    local lastBroadcast   = 0
    local tickInterval    = 1000

    while true do
        Wait(tickInterval)

        local now    = GetGameTimer()
        local h, _   = gameTime()
        local period = SKEnvironment.getPeriod(h)

        totalGameMinutes = totalGameMinutes + (tickInterval / period.msPerGameMinute)

        local newHour = gameTime()
        if now - weatherChangedAt >= SKEnvironment.WEATHER_CHANGE_SECS * 1000 then
            weatherChangedAt = now
            local nextWeather = pickWeather(newHour)
            if nextWeather ~= currentWeather then
                prevWeather     = currentWeather
                currentWeather  = nextWeather
                transitionStart = now
            end
        end

        if now - lastBroadcast >= SKEnvironment.SYNC_INTERVAL_MS then
            lastBroadcast = now
            local payload = buildSyncPayload()
            TriggerClientEvent('streetkings:environment:sync', -1, payload)
        end
    end
end)

exports('SetTime', function(hour)
    if type(hour) ~= 'number' then return false end
    SKEnvironment.SetHour(hour)
    return true
end)
exports('SetWeather', function(weather)
    if type(weather) ~= 'string' or weather == '' then return false end
    SKEnvironment.SetWeather(weather)
    return true
end)