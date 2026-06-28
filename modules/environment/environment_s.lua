local totalGameMinutes = SKEnvironment.START_HOUR * 60.0

local currentWeather   = 'CLEAR'
local prevWeather      = 'CLEAR'
local transitionStart  = 0
local weatherChangedAt = 0
local timeFrozen       = false
local weatherFrozen    = false
local autoWeather      = true

local VALID_WEATHERS = {
    EXTRASUNNY = true,
    CLEAR = true,
    CLOUDS = true,
    SMOG = true,
    FOGGY = true,
    OVERCAST = true,
    RAIN = true,
    THUNDER = true,
    CLEARING = true,
    NEUTRAL = true,
    SNOW = true,
    BLIZZARD = true,
    SNOWLIGHT = true,
    XMAS = true,
    HALLOWEEN = true,
}

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

---@return number
local function transitionPct()
    local elapsed = GetGameTimer() - transitionStart
    return math.min(elapsed / SKEnvironment.WEATHER_TRANSITION_MS, 1.0)
end

---@return table
local function buildSyncPayload()
    local h, m, s = gameTime()
    return {
        h = h,
        m = m,
        s = s,
        weather = currentWeather,
        prevWeather = prevWeather,
        transitionPct = transitionPct(),
        timeFrozen = timeFrozen,
        weatherFrozen = weatherFrozen,
        autoWeather = autoWeather,
    }
end

local function syncEnvironment(target)
    local payload = buildSyncPayload()
    GlobalState.streetkingsEnvironment = payload
    TriggerClientEvent('streetkings:environment:sync', target or -1, payload)
end

local function normalizeHour(hour)
    hour = tonumber(hour)
    if not hour then return nil end
    return math.floor(hour) % 24
end

local function normalizeMinute(minute)
    minute = tonumber(minute or 0)
    if not minute then return nil end
    return math.max(0, math.min(59, math.floor(minute)))
end

local function normalizeWeather(weather)
    if type(weather) ~= 'string' then return nil end
    weather = weather:upper():gsub('%s+', '')
    if weather == '' or not VALID_WEATHERS[weather] then return nil end
    return weather
end

RegisterNetEvent('streetkings:environment:requestSync', function()
    local src = source --[[@as integer]]
    syncEnvironment(src)
end)

---@param hour integer
---@param minute integer|nil
function SKEnvironment.SetTime(hour, minute)
    hour = normalizeHour(hour)
    minute = normalizeMinute(minute)
    if not hour or minute == nil then return false end
    totalGameMinutes = (hour * 60.0) + minute
    syncEnvironment(-1)
    return true
end

---@param hour integer
function SKEnvironment.SetHour(hour)
    return SKEnvironment.SetTime(hour, 0)
end

---@param weather string
function SKEnvironment.SetWeather(weather)
    weather = normalizeWeather(weather)
    if not weather then return false end
    prevWeather      = currentWeather
    currentWeather   = weather
    transitionStart  = GetGameTimer()
    weatherChangedAt = GetGameTimer()
    syncEnvironment(-1)
    return true
end

function SKEnvironment.GetState()
    return buildSyncPayload()
end

function SKEnvironment.ForceSync(target)
    syncEnvironment(target or -1)
    return true
end

function SKEnvironment.SetTimeFrozen(frozen)
    timeFrozen = frozen == true
    syncEnvironment(-1)
    return true
end

function SKEnvironment.SetWeatherFrozen(frozen)
    weatherFrozen = frozen == true
    syncEnvironment(-1)
    return true
end

function SKEnvironment.SetAutoWeather(enabled)
    autoWeather = enabled == true
    syncEnvironment(-1)
    return true
end

CreateThread(function()
    local lastBroadcast = 0
    local tickInterval = 1000

    while true do
        Wait(tickInterval)

        local now = GetGameTimer()
        local h = gameTime()
        local period = SKEnvironment.getPeriod(h)

        if not timeFrozen then
            totalGameMinutes = totalGameMinutes + (tickInterval / period.msPerGameMinute)
        end

        local newHour = gameTime()
        if autoWeather and not weatherFrozen and now - weatherChangedAt >= SKEnvironment.WEATHER_CHANGE_SECS * 1000 then
            weatherChangedAt = now
            local nextWeather = pickWeather(newHour)
            if nextWeather ~= currentWeather then
                prevWeather = currentWeather
                currentWeather = nextWeather
                transitionStart = now
            end
        end

        if now - lastBroadcast >= SKEnvironment.SYNC_INTERVAL_MS then
            lastBroadcast = now
            syncEnvironment(-1)
        end
    end
end)

exports('GetEnvironmentState', SKEnvironment.GetState)
exports('ForceEnvironmentSync', SKEnvironment.ForceSync)
exports('SetTime', function(hour, minute)
    return SKEnvironment.SetTime(hour, minute)
end)
exports('SetWeather', function(weather)
    return SKEnvironment.SetWeather(weather)
end)
exports('SetTimeFrozen', SKEnvironment.SetTimeFrozen)
exports('SetWeatherFrozen', SKEnvironment.SetWeatherFrozen)
exports('SetAutoWeather', SKEnvironment.SetAutoWeather)
