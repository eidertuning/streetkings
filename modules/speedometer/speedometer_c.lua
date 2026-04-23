SKSpeedo = {}

if SKConfig.DisableSpeedometer then
    function SKSpeedo.setEnabled() end
    return
end

local enabled        = false
local lastSpeed      = -1.0
local lastRpm        = -1.0
local lastGear       = -1
local lastOdoDisplay = -1
local shown          = false

local odometerKm     = 0.0
local trackedVehicle = 0
local odoLoaded      = false
local lastOdoSaveMs  = 0

local ODOMETER_SAVE_INTERVAL_MS = 30000

local function saveOdometer()
    if trackedVehicle == 0 then return end
    TriggerServerEvent('streetkings:speedo:saveOdometer', odometerKm)
end

local function loadOdometerAsync(forVehicle)
    CreateThread(function()
        local km = lib.callback.await('streetkings:speedo:loadOdometer', false)
        if trackedVehicle ~= forVehicle then return end
        odometerKm    = km
        odoLoaded     = true
        lastOdoSaveMs = GetGameTimer()
        SendNUIMessage({ type = 'speedometer:odometer', odometer = odometerKm })
    end)
end

---@param on boolean
function SKSpeedo.setEnabled(on)
    enabled = on
    if not on then
        saveOdometer()
        shown        = false
        lastSpeed    = -1.0
        lastRpm      = -1.0
        lastGear     = -1
        lastOdoDisplay = -1
        trackedVehicle = 0
        odoLoaded    = false
        SendNUIMessage({ type = 'speedometer:hide' })
    end
end

exports('SetSpeedometerEnabled', function(on)
    if type(on) ~= 'boolean' then return false end
    SKSpeedo.setEnabled(on)
    return true
end)

CreateThread(function()
    while true do
        if enabled then
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            if veh ~= 0 and GetIsVehicleEngineRunning(veh) then
                if veh ~= trackedVehicle then
                    if trackedVehicle ~= 0 then
                        saveOdometer()
                    end
                    trackedVehicle = veh
                    odoLoaded      = false
                    odometerKm     = 0.0
                    lastOdoDisplay = -1
                    loadOdometerAsync(veh)
                end

                shown = true
                local speed = GetEntitySpeed(veh)
                local rpm   = GetVehicleCurrentRpm(veh)
                local gear  = GetVehicleCurrentGear(veh)

                if odoLoaded then
                    odometerKm = odometerKm + speed * 0.05 / 1000.0
                    local now  = GetGameTimer()
                    if now - lastOdoSaveMs >= ODOMETER_SAVE_INTERVAL_MS then
                        lastOdoSaveMs = now
                        saveOdometer()
                    end
                end

                local odoDisplay = math.floor(odometerKm)
                if gear ~= lastGear or math.abs(speed - lastSpeed) > 0.1 or math.abs(rpm - lastRpm) > 0.01 or odoDisplay ~= lastOdoDisplay then
                    lastSpeed      = speed
                    lastRpm        = rpm
                    lastGear       = gear
                    lastOdoDisplay = odoDisplay
                    SendNUIMessage({
                        type     = 'speedometer:update',
                        speed    = speed,
                        rpm      = rpm,
                        gear     = gear,
                        metric   = ShouldUseMetricMeasurements(),
                        odometer = odometerKm,
                    })
                end
            elseif shown then
                saveOdometer()
                shown          = false
                trackedVehicle = 0
                odoLoaded      = false
                lastSpeed      = -1.0
                lastRpm        = -1.0
                lastGear       = -1
                lastOdoDisplay = -1
                SendNUIMessage({ type = 'speedometer:hide' })
            end
        end
        Wait(50)
    end
end)