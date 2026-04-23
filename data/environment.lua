SKEnvironment = {}

---@class EnvironmentPeriod
---@field startHour  integer
---@field endHour    integer
---@field msPerGameMinute number
---@field weathers   string[]

---@type EnvironmentPeriod[]
SKEnvironment.periods = {
    {
        startHour        = 21,
        endHour          = 5,
        msPerGameMinute  = 3125,
        weathers         = { 'CLEAR', 'CLOUDS', 'FOGGY' },
    },
    {
        startHour        = 5,
        endHour          = 10,
        msPerGameMinute  = 3000,
        weathers         = { 'CLOUDS', 'OVERCAST', 'FOGGY', 'SMOG' },
    },
    {
        startHour        = 10,
        endHour          = 16,
        msPerGameMinute  = 833,
        weathers         = { 'CLEAR', 'EXTRASUNNY', 'CLOUDS' },
    },
    {
        startHour        = 16,
        endHour          = 21,
        msPerGameMinute  = 3000,
        weathers         = { 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY' },
    },
}

SKEnvironment.SYNC_INTERVAL_MS      = 2000
SKEnvironment.WEATHER_CHANGE_SECS   = 3600
SKEnvironment.WEATHER_TRANSITION_MS = 45000
SKEnvironment.START_HOUR            = 22

---@param hour integer  0–23
---@return EnvironmentPeriod
function SKEnvironment.getPeriod(hour)
    for _, period in ipairs(SKEnvironment.periods) do
        if period.startHour > period.endHour then
            if hour >= period.startHour or hour < period.endHour then
                return period
            end
        else
            if hour >= period.startHour and hour < period.endHour then
                return period
            end
        end
    end
    return SKEnvironment.periods[1]
end
