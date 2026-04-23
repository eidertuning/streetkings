---@class SKPropertyEntry
---@field id string
---@field name string
---@field building string
---@field description string
---@field category string
---@field purchasePrice integer
---@field exterior vector4
---@field interiorDoor vector4
---@field interiorIpl string
---@field mapLabel string
---@field markerColorOwned integer[]
---@field markerColorAvailable integer[]
---@field blipColorOwned integer
---@field blipColorAvailable integer
---@field exteriorMarkerScale vector3
---@field interiorMarkerScale vector3

local propertyList = nil
local propertyById = nil

local function ensurePropertyIndex()
    if propertyList and propertyById then
        return
    end

    local catalog = assert(SKProperty and SKProperty.CATALOG, 'streetkings: missing property catalog')
    propertyList = {}
    propertyById = {}

    for _, entry in ipairs(catalog) do
        propertyList[#propertyList + 1] = entry
        propertyById[entry.id] = entry
    end

    table.sort(propertyList, function(a, b)
        if a.category ~= b.category then
            return a.category < b.category
        end
        if a.building ~= b.building then
            return a.building < b.building
        end
        return a.name < b.name
    end)
end

---@return SKPropertyEntry[]
function SKProperty.getAll()
    ensurePropertyIndex()
    return assert(propertyList, 'streetkings: missing property list')
end

---@param propertyId string
---@return SKPropertyEntry|nil
function SKProperty.getById(propertyId)
    ensurePropertyIndex()
    local byId = assert(propertyById, 'streetkings: missing property lookup')
    return byId[propertyId]
end

---@param propertyId string
---@return boolean
function SKProperty.isValidId(propertyId)
    ensurePropertyIndex()
    local byId = assert(propertyById, 'streetkings: missing property lookup')
    return byId[propertyId] ~= nil
end

---@param entry SKPropertyEntry
---@return vector4
function SKProperty.getExteriorReturnPosition(entry)
    return vector4(entry.exterior.x, entry.exterior.y, entry.exterior.z, entry.exterior.w)
end

---@param entry SKPropertyEntry
---@return vector4
function SKProperty.getInteriorSpawnPosition(entry)
    return vector4(entry.interiorDoor.x, entry.interiorDoor.y, entry.interiorDoor.z, entry.interiorDoor.w)
end