if SKConfig.DisableSpeedometer then return end

lib.callback.register('streetkings:speedo:loadOdometer', function(source)
    local document = SKSaves.getDocument(source)
    if not document then return 0.0 end

    local vehicleId = document.garage.activeVehicleId
    if not vehicleId or vehicleId == '' then return 0.0 end

    local entry = document.garage.vehicles[vehicleId]
    if not entry then return 0.0 end

    return entry.data.odometer or 0.0
end)

RegisterNetEvent('streetkings:speedo:saveOdometer', function(odometer)
    local src      = source
    local document = SKSaves.getDocument(src)
    if not document then return end

    local vehicleId = document.garage.activeVehicleId
    if not vehicleId or vehicleId == '' then return end

    local entry = document.garage.vehicles[vehicleId]
    if not entry then return end

    entry.data.odometer = odometer
    SKSaves.write(src, 'garage.vehicles.' .. vehicleId .. '.data', entry.data)
end)