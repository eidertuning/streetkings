local currentWeather  = nil
local prevWeather     = 'CLEAR'
local transitionPct   = 1.0
local transitioning   = false

local SUNNY_WEATHERS    = { CLEAR = true, EXTRASUNNY = true }
local DAYTIME_START_H   = 6
local DAYTIME_END_H     = 20

local clockH = 0
local clockM = 0
local clockS = 0
local clockReady = false

local function updateContrails(weather)
    if SUNNY_WEATHERS[weather] and clockH >= DAYTIME_START_H and clockH < DAYTIME_END_H then
        CreateThread(function()
            PreloadCloudHat("contrails")
            LoadCloudHat("contrails", 1.0)
        end)
    else
        UnloadCloudHat("contrails")
    end
end

---@param weather string
---@param prev    string
---@param pct     number 0.0–1.0
local function applyWeather(weather, prev, pct)
    SetWeatherOwnedByNetwork(false)
    if pct >= 1.0 then
        transitioning = false
        SetWeatherTypeOvertimePersist(weather, 0.0)
    else
        transitioning = true
        SetWeatherTypeTransition(prev, weather, pct)
    end
end

---@param payload table
local function onSync(payload)
    clockH = payload.h
    clockM = payload.m
    clockS = payload.s
    clockReady = true

    local weatherChanged = payload.weather ~= currentWeather

    currentWeather = payload.weather
    prevWeather    = payload.prevWeather
    transitionPct  = payload.transitionPct

    if weatherChanged or transitioning then
        applyWeather(currentWeather, prevWeather, transitionPct)
    end

    if weatherChanged then
        updateContrails(currentWeather)
    end
end

RegisterNetEvent('streetkings:environment:sync', onSync)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerServerEvent('streetkings:environment:requestSync')
end)

CreateThread(function()
    while true do
        local state = SKC and SKC.GetGameState()
        if state == GameState.MAIN_MENU or state == GameState.INITIATION then
            NetworkOverrideClockTime(21, 45, 0)
            Wait(100)
        elseif clockReady then
            NetworkOverrideClockTime(clockH, clockM, clockS)
            Wait(100)
        else
            Wait(500)
        end
    end
end)

exports('GetCurrentTime', function() return { h = clockH, m = clockM, s = clockS } end)
exports('GetCurrentWeather', function() return currentWeather end)

-- Traffic density -----------------------------------------------------------

local TRAFFIC_DENSITY_FREEROAM = 0.4
local TRAFFIC_DENSITY_EVENT = 0.2

local function trafficDensityApplies(state)
    return state == GameState.FREEROAM 
    or state == GameState.EVENT 
    or state == GameState.MISSION
    or state == GameState.MULTIPLAYER_LOBBY
    or state == GameState.MULTIPLAYER_EVENT
end

local function getTrafficDensityMultiplier(state)
    if state == GameState.EVENT 
    or state == GameState.MISSION
    or state == GameState.MULTIPLAYER_EVENT
    or state == GameState.MULTIPLAYER_LOBBY
    then
        return TRAFFIC_DENSITY_EVENT
    end
    return TRAFFIC_DENSITY_FREEROAM
end

CreateThread(function()
    while true do
        local state = SKC.GetGameState()
        if trafficDensityApplies(state) then
            local mult = getTrafficDensityMultiplier(state)
            SetVehicleDensityMultiplierThisFrame(mult)
            SetRandomVehicleDensityMultiplierThisFrame(mult)
            SetParkedVehicleDensityMultiplierThisFrame(mult)
            SetAllLowPriorityVehicleGeneratorsActive(true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)