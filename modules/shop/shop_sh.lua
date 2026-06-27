SKShopShared = SKShopShared or {}

SKShopShared.VIP_TIERS = {
    none = 0,
    vip = 1,
    vipplus = 2,
    vipplusplus = 3,
}

---@param tier string|nil
---@return integer
function SKShopShared.getVipRank(tier)
    return SKShopShared.VIP_TIERS[tier or 'none'] or 0
end

---@param playerTier string|nil
---@param requiredTier string|nil
---@return boolean
function SKShopShared.hasVipAccess(playerTier, requiredTier)
    return SKShopShared.getVipRank(playerTier) >= SKShopShared.getVipRank(requiredTier)
end

---@param modType integer|string|nil
---@param modIndex integer|nil
---@return string|nil
function SKShopShared.getRequiredVipTier(modType, modIndex)
    local requirements = SKShopShared.VIP_MOD_REQUIREMENTS or {}
    local modReq = requirements[modType]
    if type(modReq) == 'table' then
        return modReq[modIndex] or modReq.default
    end
    return modReq
end

---@param modType integer
---@return boolean
function SKShopShared.isExcludedModType(modType)
    return modType == 14 or modType == 16 or modType == 21 -- Horn, armour and hydraulics respectively
end

---@param modType integer
---@return boolean
function SKShopShared.isToggleModType(modType)
    return modType == 18 or modType == 22 -- Turbo, Xenon Lights
end

---@param vehicle integer
---@param modType integer
---@return boolean
function SKShopShared.vehicleSupportsToggleMod(vehicle, modType)
    if not SKShopShared.isToggleModType(modType) then
        return false
    end

    local wasEnabled = IsToggleModOn(vehicle, modType)
    if wasEnabled then
        return true
    end

    ToggleVehicleMod(vehicle, modType, true)
    local supported = IsToggleModOn(vehicle, modType)
    if supported then
        ToggleVehicleMod(vehicle, modType, false)
    end

    return supported
end

---@param vehicle integer
---@param modType integer
---@return integer
function SKShopShared.getVehicleModOptionCount(vehicle, modType)
    if SKShopShared.isExcludedModType(modType) then
        return 0
    end

    if SKShopShared.isToggleModType(modType) then
        return SKShopShared.vehicleSupportsToggleMod(vehicle, modType) and 1 or 0
    end

    return GetNumVehicleMods(vehicle, modType)
end

---@param vehicle integer
---@param modType integer
---@return integer
function SKShopShared.getInstalledModIndex(vehicle, modType)
    if SKShopShared.isToggleModType(modType) then
        return IsToggleModOn(vehicle, modType) and 0 or -1
    end

    return GetVehicleMod(vehicle, modType)
end

---@param vehicle integer
---@param modType integer
---@param modIndex integer
function SKShopShared.applyVehicleMod(vehicle, modType, modIndex)
    if SKShopShared.isToggleModType(modType) then
        ToggleVehicleMod(vehicle, modType, modIndex >= 0)
        return
    end

    SetVehicleMod(vehicle, modType, modIndex, false)
end

---@param modType integer
---@return boolean
function SKShopShared.isPerformanceModType(modType)
    return SKShopShared.PERFORMANCE_MOD_PRICES[modType] ~= nil
        or modType == SKShopShared.NITROUS_UNLOCK_MOD_TYPE
end

---@param modType integer
---@return boolean
function SKShopShared.isVisualModType(modType)
    return not SKShopShared.isExcludedModType(modType) and not SKShopShared.isPerformanceModType(modType)
end

---@param shopTypeKey string|nil
---@param modType integer
---@return boolean
function SKShopShared.isShopModType(shopTypeKey, modType)
    if SKShopShared.isExcludedModType(modType) then
        return false
    end

    if shopTypeKey == 'visual' then
        return SKShopShared.isVisualModType(modType)
    end

    if shopTypeKey == 'performance' then
        return SKShopShared.isPerformanceModType(modType)
    end

    return false
end

---@param modType integer
---@param modIndex integer|nil
---@return integer|nil
local function getPerformanceModPrice(modType, modIndex)
    local basePrice = SKShopShared.PERFORMANCE_MOD_PRICES[modType]
    if not basePrice then
        return nil
    end

    if modIndex == nil or modIndex < 0 then
        return basePrice
    end

    return basePrice * (modIndex + 1)
end

---@param shopTypeKey string
---@param modType integer
---@param modIndex integer|nil
---@return integer|nil
function SKShopShared.getModPrice(shopTypeKey, modType, modIndex)
    if shopTypeKey == 'visual' and SKShopShared.isVisualModType(modType) then
        return SKShopShared.VISUAL_MOD_PRICE
    end

    if shopTypeKey == 'performance' then
        return getPerformanceModPrice(modType, modIndex)
    end
end

---@param shopTypeKey string
---@return table|nil
function SKShopShared.getShopType(shopTypeKey)
    return SKShopShared.TYPES[shopTypeKey]
end

---@param stateId string|nil
---@return string|nil
function SKShopShared.getShopTypeByState(stateId)
    for shopTypeKey, config in pairs(SKShopShared.TYPES) do
        if config.gameState == stateId then
            return shopTypeKey
        end
    end
end

---@param shopTypeKey string
---@return table|nil
function SKShopShared.getShopLocation(shopTypeKey)
    for _, location in ipairs(SKShopShared.LOCATIONS) do
        if location.shopType == shopTypeKey then
            return location
        end
    end
end

---@param shopTypeKey string
---@return vector4|nil
function SKShopShared.getShopTeleportTarget(shopTypeKey)
    local location = SKShopShared.getShopLocation(shopTypeKey)
    if not location then
        return nil
    end

    return vector4(location.coords.x, location.coords.y, location.coords.z, location.entryHeading)
end
