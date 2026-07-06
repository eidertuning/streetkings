SKFuel = SKFuel or {}

local fuelLevel = 100.0
local condition = 100.0
local loaded = false
local trackedVehicle = 0
local trackedCanPersist = false
local trackedClass = 'DEFAULT'
local lastSaveAt = 0
local lastSavedFuel = 100.0
local lastSavedCondition = 100.0
local warnedLowFuel = false
local loadSerial = 0

local raceMode = false
local raceVehicle = 0
local raceSnapshotFuel = 100.0
local raceSnapshotCondition = 100.0

local function cfg()
    return SKFuelConfig or {}
end

local function clampPct(value, fallback)
    local n = tonumber(value)
    if not n then n = fallback or 0.0 end
    if n < 0.0 then return 0.0 end
    if n > 100.0 then return 100.0 end
    return n
end

local function roundPct(value)
    return math.floor(clampPct(value) * 10 + 0.5) / 10
end

local function defaultFuel()
    local defaults = cfg().defaults or {}
    return clampPct(defaults.fuelLevel, 100.0)
end

local function defaultCondition()
    local defaults = cfg().defaults or {}
    return clampPct(defaults.condition, 100.0)
end

local function getConditionFromVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return condition end
    local engine = clampPct(GetVehicleEngineHealth(vehicle) / 10.0, 100.0)
    local body = clampPct(GetVehicleBodyHealth(vehicle) / 10.0, 100.0)
    local tank = clampPct(GetVehiclePetrolTankHealth(vehicle) / 10.0, 100.0)
    return math.min(engine, body, tank)
end

local function applyFuelLevel(vehicle, value)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    SetVehicleFuelLevel(vehicle, clampPct(value))
end

local function applyCondition(vehicle, value)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local health = math.max(100.0, clampPct(value) * 10.0)
    SetVehicleEngineHealth(vehicle, health)
    SetVehicleBodyHealth(vehicle, health)
    SetVehiclePetrolTankHealth(vehicle, health)
    if health > 150.0 then
        SetVehicleUndriveable(vehicle, false)
    end
end

local function applyStateToVehicle(vehicle)
    applyFuelLevel(vehicle, fuelLevel)
    applyCondition(vehicle, condition)
end

local function resetTracking()
    trackedVehicle = 0
    trackedCanPersist = false
    trackedClass = 'DEFAULT'
    loaded = false
    warnedLowFuel = false
end

local function saveState(force)
    if raceMode or not loaded or not trackedCanPersist then return end
    local now = GetGameTimer()
    local consumption = cfg().consumption or {}
    local saveInterval = tonumber(consumption.saveIntervalMs) or 15000
    local saveDelta = tonumber(consumption.saveDelta) or 0.35
    if not force and now - lastSaveAt < saveInterval then return end
    if not force and math.abs(fuelLevel - lastSavedFuel) < saveDelta and math.abs(condition - lastSavedCondition) < saveDelta then return end

    lastSaveAt = now
    lastSavedFuel = roundPct(fuelLevel)
    lastSavedCondition = roundPct(condition)
    TriggerServerEvent('streetkings:fuel:saveActive', lastSavedFuel, lastSavedCondition)
end

local function getClassMultiplier(vehicle)
    local consumption = cfg().consumption or {}
    local byClass = consumption.byClass or {}
    local byGtaClass = consumption.byGtaClass or {}

    local classMultiplier = tonumber(byClass[trackedClass]) or tonumber(byClass.DEFAULT) or 1.0
    if trackedClass == 'DEFAULT' and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local gtaClass = GetVehicleClass(vehicle)
        classMultiplier = tonumber(byGtaClass[gtaClass]) or tonumber(byGtaClass.DEFAULT) or classMultiplier
    end

    return classMultiplier
end

local function loadActiveVehicleState(vehicle, serial)
    CreateThread(function()
        local result = lib.callback.await('streetkings:fuel:loadActive', false)
        if trackedVehicle ~= vehicle or raceMode or loadSerial ~= serial then return end

        if not result or result.ok ~= true then
            fuelLevel = defaultFuel()
            condition = getConditionFromVehicle(vehicle)
            trackedCanPersist = false
            trackedClass = 'DEFAULT'
            loaded = true
            return
        end

        local expectedHash = GetHashKey(result.modelName or '')
        trackedCanPersist = expectedHash == 0 or GetEntityModel(vehicle) == expectedHash
        trackedClass = result.vehicleClass or 'DEFAULT'
        fuelLevel = clampPct(result.fuelLevel, defaultFuel())
        condition = clampPct(result.condition, defaultCondition())
        loaded = true
        lastSaveAt = GetGameTimer()
        lastSavedFuel = roundPct(fuelLevel)
        lastSavedCondition = roundPct(condition)

        if trackedCanPersist then
            applyStateToVehicle(vehicle)
        else
            fuelLevel = clampPct(GetVehicleFuelLevel(vehicle), defaultFuel())
            condition = getConditionFromVehicle(vehicle)
        end
    end)
end

local function beginTracking(vehicle)
    if trackedVehicle ~= 0 and trackedVehicle ~= vehicle then
        saveState(true)
    end

    trackedVehicle = vehicle
    trackedCanPersist = false
    trackedClass = 'DEFAULT'
    loaded = false
    loadSerial = loadSerial + 1
    warnedLowFuel = false
    fuelLevel = clampPct(GetVehicleFuelLevel(vehicle), defaultFuel())
    condition = getConditionFromVehicle(vehicle)

    if raceMode then
        loaded = true
        fuelLevel = 100.0
        condition = 100.0
        applyStateToVehicle(vehicle)
        return
    end

    loadActiveVehicleState(vehicle, loadSerial)
end

local function consumeFuel(vehicle, dt)
    if cfg().enabled == false or raceMode or not loaded or not trackedCanPersist then return end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then return end
    if not GetIsVehicleEngineRunning(vehicle) then return end

    local consumption = cfg().consumption or {}
    local drain = (tonumber(consumption.idlePerSecond) or 0.006)
        + (GetVehicleCurrentRpm(vehicle) * (tonumber(consumption.rpmPerSecond) or 0.026))
        + (GetEntitySpeed(vehicle) * (tonumber(consumption.speedPerMeterPerSecond) or 0.0014))
    drain = drain * getClassMultiplier(vehicle) * dt

    fuelLevel = clampPct(fuelLevel - drain, 0.0)
    condition = getConditionFromVehicle(vehicle)
    applyFuelLevel(vehicle, fuelLevel)

    local lowThreshold = tonumber(consumption.lowFuelThreshold) or 12.0
    if fuelLevel <= 0.0 then
        SetVehicleFuelLevel(vehicle, 0.0)
        SetVehicleEngineHealth(vehicle, math.min(GetVehicleEngineHealth(vehicle), tonumber(consumption.emptyEngineHealth) or 120.0))
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleUndriveable(vehicle, true)
        if not warnedLowFuel then
            warnedLowFuel = true
            SKNotify({ title = _L('lua.notify.fuel_empty'), type = 'error' })
        end
    elseif fuelLevel <= lowThreshold and not warnedLowFuel then
        warnedLowFuel = true
        SKNotify({ title = _L('lua.notify.fuel_low'), type = 'warning' })
    elseif fuelLevel > lowThreshold + 5.0 then
        warnedLowFuel = false
    end
end

function SKFuel.refillCurrentVehicle(repairVehicle)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return false end

    if trackedVehicle ~= vehicle then
        beginTracking(vehicle)
    end

    if not loaded or not trackedCanPersist then
        loadSerial = loadSerial + 1
        local result = lib.callback.await('streetkings:fuel:loadActive', false)
        if result and result.ok == true and GetEntityModel(vehicle) == GetHashKey(result.modelName or '') then
            trackedVehicle = vehicle
            trackedCanPersist = true
            trackedClass = result.vehicleClass or 'DEFAULT'
            loaded = true
        end
    end

    fuelLevel = 100.0
    if repairVehicle ~= false then
        condition = 100.0
        applyCondition(vehicle, condition)
    else
        condition = getConditionFromVehicle(vehicle)
    end
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineOn(vehicle, true, true, false)
    applyFuelLevel(vehicle, fuelLevel)
    saveState(true)
    warnedLowFuel = false
    return true
end

function SKFuel.getHudState(vehicle)
    if raceMode then
        return {
            fuelLevel = 100.0,
            condition = 100.0,
            fuelDisabled = true,
        }
    end

    if vehicle ~= 0 and vehicle == trackedVehicle and loaded then
        return {
            fuelLevel = clampPct(fuelLevel, defaultFuel()),
            condition = clampPct(condition, defaultCondition()),
            fuelDisabled = false,
        }
    end

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return {
            fuelLevel = clampPct(GetVehicleFuelLevel(vehicle), defaultFuel()),
            condition = getConditionFromVehicle(vehicle),
            fuelDisabled = false,
        }
    end

    return {
        fuelLevel = defaultFuel(),
        condition = defaultCondition(),
        fuelDisabled = false,
    }
end

function SKFuel.beginRace(vehicle)
    if not loaded or not trackedCanPersist then
        local result = lib.callback.await('streetkings:fuel:loadActive', false)
        if result and result.ok == true then
            raceSnapshotFuel = clampPct(result.fuelLevel, defaultFuel())
            raceSnapshotCondition = clampPct(result.condition, defaultCondition())
        else
            raceSnapshotFuel = clampPct(fuelLevel, defaultFuel())
            raceSnapshotCondition = clampPct(condition, defaultCondition())
        end
    else
        raceSnapshotFuel = clampPct(fuelLevel, defaultFuel())
        raceSnapshotCondition = clampPct(condition, defaultCondition())
    end
    saveState(true)
    raceMode = true
    raceVehicle = vehicle or GetVehiclePedIsIn(PlayerPedId(), false)
    trackedVehicle = raceVehicle
    trackedCanPersist = false
    trackedClass = 'RACE'
    loaded = true
    fuelLevel = 100.0
    condition = 100.0
    applyStateToVehicle(raceVehicle)
end

function SKFuel.endRace()
    if not raceMode then return end
    local vehicle = raceVehicle
    if vehicle == 0 then vehicle = GetVehiclePedIsIn(PlayerPedId(), false) end
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        applyFuelLevel(vehicle, raceSnapshotFuel)
        applyCondition(vehicle, raceSnapshotCondition)
    end
    raceMode = false
    raceVehicle = 0
    fuelLevel = raceSnapshotFuel
    condition = raceSnapshotCondition
    resetTracking()
end

RegisterNetEvent('streetkings:fuel:stationRefill', function()
    SKFuel.refillCurrentVehicle(true)
end)

RegisterNetEvent('streetkings:fuel:remoteRefuel', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 or vehicle ~= trackedVehicle or not trackedCanPersist then return end
    fuelLevel = 100.0
    applyFuelLevel(vehicle, fuelLevel)
    lastSavedFuel = 100.0
    warnedLowFuel = false
end)

RegisterNetEvent('streetkings:fuel:raceStart', function(vehicle)
    SKFuel.beginRace(vehicle)
end)

RegisterNetEvent('streetkings:fuel:raceEnd', function()
    SKFuel.endRace()
end)

CreateThread(function()
    local lastTick = GetGameTimer()
    while true do
        local tickMs = tonumber((cfg().consumption or {}).tickMs) or 1000
        if cfg().enabled == false then
            Wait(tickMs)
        else
            local now = GetGameTimer()
            local dt = math.max(0.0, (now - lastTick) / 1000.0)
            lastTick = now

            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
                if vehicle ~= trackedVehicle then
                    beginTracking(vehicle)
                elseif raceMode then
                    fuelLevel = 100.0
                    condition = 100.0
                    applyFuelLevel(vehicle, 100.0)
                else
                    consumeFuel(vehicle, dt)
                    saveState(false)
                end
            else
                if trackedVehicle ~= 0 then
                    saveState(true)
                    resetTracking()
                end
            end

            Wait(tickMs)
        end
    end
end)

exports('GetFuelState', function()
    return SKFuel.getHudState(GetVehiclePedIsIn(PlayerPedId(), false))
end)

exports('RefillCurrentVehicle', function(repairVehicle)
    return SKFuel.refillCurrentVehicle(repairVehicle)
end)
