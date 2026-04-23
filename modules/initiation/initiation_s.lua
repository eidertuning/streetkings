local STARTER_MODELS = SKStarterVehiclesByModel

---@param colors table|nil
---@return boolean
local function isValidStarterColors(colors)
    if type(colors) ~= 'table' or type(colors.primary) ~= 'table' or type(colors.secondary) ~= 'table' then
        return false
    end

    for _, key in ipairs({ 'primary', 'secondary' }) do
        local color = colors[key]
        if type(color.r) ~= 'number' or type(color.g) ~= 'number' or type(color.b) ~= 'number' then
            return false
        end
    end

    return true
end

lib.callback.register('streetkings:initiation:selectStarterVehicle', function(source, modelName, colors)
    local meta = STARTER_MODELS[modelName]
    if not meta then
        return { ok = false, error = 'invalid_model' }
    end
    if not isValidStarterColors(colors) then
        return { ok = false, error = 'invalid_colors' }
    end

    local document = SKSaves.getDocument(source)
    if not document then
        return { ok = false, error = SKSaves.Error.NO_ACTIVE_DOCUMENT }
    end

    if document.garage.activeVehicleId ~= '' then
        return { ok = false, error = 'already_selected' }
    end

    local vehicleId = lib.string.random('........^-....^-....^-....^-............')

    local vehicleData = SKProgression.newVehicleData(meta.vehicleType)
    vehicleData.colors.primary = { r = colors.primary.r, g = colors.primary.g, b = colors.primary.b }
    vehicleData.colors.secondary = { r = colors.secondary.r, g = colors.secondary.g, b = colors.secondary.b }

    document.garage.vehicles[vehicleId] = {
        id          = vehicleId,
        modelName   = modelName,
        displayName = meta.displayName,
        sortIndex   = 0,
        plate       = SKVehiclePlate.generate(),
        data        = vehicleData,
    }
    document.garage.activeVehicleId = vehicleId

    local ok = SKSaves.persist(source)
    if not ok then
        return { ok = false, error = 'persist_failed' }
    end

    TriggerEvent('streetkings:messages:trigger', source, 'vehicleAcquired', {
        acquisitionSource = 'starter',
        vehicleId = vehicleId,
        modelName = modelName,
        isFirstVehicle = true,
    })

    return { ok = true, vehicleId = vehicleId }
end)
