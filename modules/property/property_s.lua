---@param document SKSaveDocument
---@return table<string, boolean>
local function getOwnedLookup(document)
    return document.properties.owned
end

---@param document SKSaveDocument
---@return string[]
local function buildOwnedPropertyIds(document)
    local ownedPropertyIds = {}

    for propertyId, owned in pairs(getOwnedLookup(document)) do
        if owned then
            ownedPropertyIds[#ownedPropertyIds + 1] = propertyId
        end
    end

    table.sort(ownedPropertyIds)
    return ownedPropertyIds
end

---@param entry SKPropertyEntry
---@param ownedLookup table<string, boolean>
---@param cash integer
---@return table
local function buildListingDto(entry, ownedLookup, cash)
    local owned = ownedLookup[entry.id] == true

    return {
        id = entry.id,
        name = entry.name,
        building = entry.building,
        description = entry.description,
        category = entry.category,
        purchasePrice = entry.purchasePrice,
        warpPrice = SKProperty.WARP_PRICE,
        owned = owned,
        canAfford = cash >= entry.purchasePrice,
        canAffordWarp = cash >= SKProperty.WARP_PRICE,
        mapLabel = entry.mapLabel,
        exterior = {
            x = entry.exterior.x,
            y = entry.exterior.y,
            z = entry.exterior.z,
        },
    }
end

---@param document SKSaveDocument
---@param focusedPropertyId string|nil
---@return table
local function buildPhoneState(document, focusedPropertyId)
    local cash = document.economy.cash
    local ownedLookup = getOwnedLookup(document)
    local listings = {}

    for _, entry in ipairs(SKProperty.getAll()) do
        listings[#listings + 1] = buildListingDto(entry, ownedLookup, cash)
    end

    return {
        properties = listings,
        ownedPropertyIds = buildOwnedPropertyIds(document),
        focusedPropertyId = focusedPropertyId,
        cash = cash,
        warpPrice = SKProperty.WARP_PRICE,
    }
end

---@param source integer
---@return SKSaveDocument
local function requireDocument(source)
    return assert(SKSaves.getDocument(source), 'streetkings: missing active property document')
end

lib.callback.register('streetkings:property:getFreeroamState', function(source)
    local document = requireDocument(source)
    return {
        ownedPropertyIds = buildOwnedPropertyIds(document),
    }
end)

lib.callback.register('streetkings:property:getPhoneListings', function(source, focusedPropertyId)
    local document = requireDocument(source)
    return buildPhoneState(document, focusedPropertyId)
end)

lib.callback.register('streetkings:property:purchase', function(source, propertyId)
    local document = requireDocument(source)
    local entry = SKProperty.getById(propertyId)

    if not entry then
        return {
            ok = false,
            reason = 'not_found',
            phoneState = buildPhoneState(document, propertyId),
        }
    end

    if document.properties.owned[propertyId] then
        return {
            ok = false,
            reason = 'already_owned',
            phoneState = buildPhoneState(document, propertyId),
        }
    end

    if document.economy.cash < entry.purchasePrice then
        return {
            ok = false,
            reason = 'insufficient_funds',
            phoneState = buildPhoneState(document, propertyId),
        }
    end

    document.economy.cash = document.economy.cash - entry.purchasePrice
    document.properties.owned[propertyId] = true

    if not SKSaves.persist(source) then
        document.economy.cash = document.economy.cash + entry.purchasePrice
        document.properties.owned[propertyId] = nil
        return {
            ok = false,
            reason = 'save_failed',
            phoneState = buildPhoneState(document, propertyId),
        }
    end

    SKStats.increment(source, 'totalCashSpent', entry.purchasePrice)
    if SKLogs then
        SKLogs.Module('property', 'purchase_property', {
            source = source,
            title = 'Propiedad comprada',
            publicMessage = ('%s compro una propiedad.'):format(entry.name),
            details = ('propertyId=%s\nname=%s\nbuilding=%s\nprice=%s\ncash=%s'):format(propertyId, entry.name, entry.building, entry.purchasePrice, document.economy.cash),
        })
    end

    return {
        ok = true,
        propertyId = propertyId,
        phoneState = buildPhoneState(document, propertyId),
    }
end)

lib.callback.register('streetkings:property:requestWarp', function(source, propertyId)
    local document = requireDocument(source)
    local entry = SKProperty.getById(propertyId)

    if not entry then
        return { ok = false, reason = 'not_found' }
    end

    if not document.properties.owned[propertyId] then
        return { ok = false, reason = 'not_owned' }
    end

    if document.economy.cash < SKProperty.WARP_PRICE then
        return {
            ok = false,
            reason = 'insufficient_funds',
            cash = document.economy.cash,
            price = SKProperty.WARP_PRICE,
        }
    end

    document.economy.cash = document.economy.cash - SKProperty.WARP_PRICE

    if not SKSaves.persist(source) then
        document.economy.cash = document.economy.cash + SKProperty.WARP_PRICE
        return { ok = false, reason = 'save_failed' }
    end
    if SKLogs then
        SKLogs.Module('property', 'warp_property', {
            source = source,
            title = 'Viaje a propiedad',
            publicMessage = ('%s uso viaje rapido a una propiedad.'):format(entry.name),
            details = ('propertyId=%s\nprice=%s\ncash=%s\ncoords=%.2f, %.2f, %.2f'):format(propertyId, SKProperty.WARP_PRICE, document.economy.cash, entry.exterior.x, entry.exterior.y, entry.exterior.z),
        }, 'admin')
    end

    return {
        ok = true,
        propertyId = propertyId,
        cash = document.economy.cash,
        price = SKProperty.WARP_PRICE,
        exterior = {
            x = entry.exterior.x,
            y = entry.exterior.y,
            z = entry.exterior.z,
            w = entry.exterior.w,
        },
    }
end)
