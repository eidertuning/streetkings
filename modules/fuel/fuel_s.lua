SKFuel = SKFuel or {}

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

function SKFuel.NormalizeVehicleData(vehicleData)
    if type(vehicleData) ~= 'table' then return vehicleData end
    local changed = false

    if type(vehicleData.fuelLevel) ~= 'number' then
        vehicleData.fuelLevel = defaultFuel()
        changed = true
    else
        local nextValue = roundPct(vehicleData.fuelLevel)
        changed = changed or nextValue ~= vehicleData.fuelLevel
        vehicleData.fuelLevel = nextValue
    end

    if type(vehicleData.condition) ~= 'number' then
        vehicleData.condition = defaultCondition()
        changed = true
    else
        local nextValue = roundPct(vehicleData.condition)
        changed = changed or nextValue ~= vehicleData.condition
        vehicleData.condition = nextValue
    end

    return vehicleData, changed
end

local function findVehicleClass(modelName)
    local model = tostring(modelName or ''):lower()
    if model == '' then return 'DEFAULT' end

    if SKStarterVehiclesByModel and SKStarterVehiclesByModel[model] then
        return SKStarterVehiclesByModel[model].class or 'STARTER'
    end

    if type(SKGameVehicles) == 'table' then
        for _, list in pairs(SKGameVehicles) do
            for _, vehicle in ipairs(list) do
                if vehicle.model == model then
                    return vehicle.class or 'DEFAULT'
                end
            end
        end
    end

    return 'DEFAULT'
end

local function getActiveEntry(source)
    local document = SKSaves.getDocument(source)
    if not document or type(document.garage) ~= 'table' or type(document.garage.vehicles) ~= 'table' then
        return nil, nil, nil
    end

    local vehicleId = document.garage.activeVehicleId
    if type(vehicleId) ~= 'string' or vehicleId == '' then
        return nil, nil, document
    end

    local entry = document.garage.vehicles[vehicleId]
    if type(entry) ~= 'table' or type(entry.data) ~= 'table' then
        return nil, nil, document
    end

    return vehicleId, entry, document
end

local function buildStatusDto(entry)
    if type(entry) ~= 'table' then
        return {
            fuelLevel = defaultFuel(),
            condition = defaultCondition(),
            refuelPrice = 0,
            refuelPriceRemote = 0,
            vehicleClass = 'DEFAULT',
        }
    end

    local vehicleData = SKProgression.ensureVehicleData(entry.data or {})
    SKFuel.NormalizeVehicleData(vehicleData)

    local missingFuel = 100.0 - clampPct(vehicleData.fuelLevel, defaultFuel())
    local station = cfg().station or {}
    local tablet = cfg().tablet or {}
    local normalPrice = math.ceil(missingFuel * (tonumber(station.fuelPricePerPercent) or 0))
    local remotePrice = math.ceil(normalPrice * (tonumber(tablet.priceMultiplier) or 2.0))

    return {
        fuelLevel = roundPct(vehicleData.fuelLevel),
        condition = roundPct(vehicleData.condition),
        refuelPrice = normalPrice,
        refuelPriceRemote = remotePrice,
        vehicleClass = findVehicleClass(entry.modelName),
    }
end

function SKFuel.BuildVehicleStatusDto(entry)
    return buildStatusDto(entry)
end

function SKFuel.GetActiveFuelState(source)
    local vehicleId, entry = getActiveEntry(source)
    if not vehicleId then
        return nil
    end
    return buildStatusDto(entry)
end

function SKFuel.SaveActiveFuelState(source, fuelLevel, condition)
    local vehicleId, entry = getActiveEntry(source)
    if not vehicleId then
        return false, 'no_active_vehicle'
    end

    local vehicleData = SKProgression.ensureVehicleData(entry.data)
    vehicleData.fuelLevel = roundPct(fuelLevel)
    vehicleData.condition = roundPct(condition)
    SKFuel.NormalizeVehicleData(vehicleData)
    SKSaves.write(source, 'garage.vehicles.' .. vehicleId .. '.data', vehicleData)
    return true
end

function SKFuel.GetRefuelPrice(entry, multiplier)
    local status = buildStatusDto(entry)
    local base = status.refuelPrice or 0
    return math.ceil(base * (tonumber(multiplier) or 1.0))
end

function SKFuel.RefuelVehicle(source, vehicleId, multiplier, context)
    local document = SKSaves.getDocument(source)
    if not document or type(document.garage) ~= 'table' or type(document.garage.vehicles) ~= 'table' then
        return { ok = false, reason = 'no_active_document' }
    end

    if type(vehicleId) ~= 'string' or vehicleId == '' or type(document.garage.vehicles[vehicleId]) ~= 'table' then
        return { ok = false, reason = 'vehicle_not_found' }
    end

    local entry = document.garage.vehicles[vehicleId]
    local vehicleData = SKProgression.ensureVehicleData(entry.data or {})
    SKFuel.NormalizeVehicleData(vehicleData)
    local price = SKFuel.GetRefuelPrice(entry, multiplier)

    if price <= 0 then
        return {
            ok = true,
            reason = 'already_full',
            vehicleId = vehicleId,
            isActive = document.garage.activeVehicleId == vehicleId,
            balance = document.economy.cash,
            fuel = buildStatusDto(entry),
        }
    end

    if document.economy.cash < price then
        return { ok = false, reason = 'insufficient_funds', price = price, balance = document.economy.cash }
    end

    document.economy.cash = document.economy.cash - price
    vehicleData.fuelLevel = 100.0
    entry.data = vehicleData
    SKSaves.write(source, 'garage.vehicles.' .. vehicleId .. '.data', vehicleData)
    SKSaves.write(source, 'economy.cash', document.economy.cash)

    if SKStats then
        SKStats.increment(source, 'totalCashSpent', price)
    end

    local logContext = context == 'garage_exit' and {
        action = 'garage_exit_refuel',
        title = 'Repostaje al salir del garaje',
        publicMessage = ('Un jugador reposto %s antes de salir del garaje.'):format(entry.displayName or entry.modelName or 'un vehiculo'),
    } or {
        action = 'tablet_refuel',
        title = 'Repostaje remoto',
        publicMessage = ('Un jugador reposto %s desde la tablet.'):format(entry.displayName or entry.modelName or 'un vehiculo'),
    }

    if SKLogs then
        SKLogs.Module('garage', logContext.action, {
            source = source,
            title = logContext.title,
            publicMessage = logContext.publicMessage,
            details = ('vehicleId=%s\nmodel=%s\nfuel=100\nprice=%s\nbalance=%s'):format(vehicleId, entry.modelName or '-', price, document.economy.cash),
        }, 'admin')
    end

    return {
        ok = true,
        vehicleId = vehicleId,
        isActive = document.garage.activeVehicleId == vehicleId,
        balance = document.economy.cash,
        price = price,
        fuel = buildStatusDto(entry),
    }
end

lib.callback.register('streetkings:fuel:loadActive', function(source)
    local vehicleId, entry = getActiveEntry(source)
    if not vehicleId then
        return { ok = false, reason = 'no_active_vehicle' }
    end

    local vehicleData = SKProgression.ensureVehicleData(entry.data)
    local _, changed = SKFuel.NormalizeVehicleData(vehicleData)
    if changed then
        SKSaves.write(source, 'garage.vehicles.' .. vehicleId .. '.data', vehicleData)
    end

    local status = buildStatusDto(entry)
    status.ok = true
    status.vehicleId = vehicleId
    status.modelName = entry.modelName
    return status
end)

lib.callback.register('streetkings:fuel:tabletRefuel', function(source, vehicleId)
    local fuelCfg = cfg()
    if fuelCfg.enabled == false or (fuelCfg.tablet and fuelCfg.tablet.enabled == false) then
        return { ok = false, reason = 'disabled' }
    end

    local multiplier = fuelCfg.tablet and fuelCfg.tablet.priceMultiplier or 2.0
    return SKFuel.RefuelVehicle(source, vehicleId, multiplier, 'tablet')
end)

lib.callback.register('streetkings:fuel:garageRefuel', function(source, vehicleId)
    local fuelCfg = cfg()
    if fuelCfg.enabled == false or (fuelCfg.station and fuelCfg.station.refuelVehicle == false) then
        return { ok = false, reason = 'disabled' }
    end

    return SKFuel.RefuelVehicle(source, vehicleId, 1.0, 'garage_exit')
end)

RegisterNetEvent('streetkings:fuel:saveActive', function(fuelLevel, condition)
    local src = source
    if cfg().enabled == false then return end
    SKFuel.SaveActiveFuelState(src, fuelLevel, condition)
end)

exports('GetFuelState', SKFuel.GetActiveFuelState)
exports('SaveFuelState', SKFuel.SaveActiveFuelState)
exports('RefuelVehicle', SKFuel.RefuelVehicle)
exports('GetRefuelPrice', SKFuel.GetRefuelPrice)
