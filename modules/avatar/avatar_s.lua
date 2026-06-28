SKAvatar = SKAvatar or {}

local dbReady = false
local accountCache = {}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `player_avatars` (
            `owner_identifier` VARCHAR(128) NOT NULL,
            `schema_version` SMALLINT UNSIGNED NOT NULL,
            `document_json` LONGTEXT NOT NULL,
            `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
            PRIMARY KEY (`owner_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await('ALTER TABLE `player_avatars` MODIFY COLUMN `owner_identifier` VARCHAR(128) NOT NULL')
    dbReady = true
end)

AddEventHandler('playerDropped', function()
    accountCache[source] = nil
end)

---@param source integer
---@return string|nil
local function ownerLicense(source)
    return GetPlayerIdentifierByType(source --[[@as string]], 'license')
end

---@param source integer
---@return string|nil
local function avatarOwnerKey(source)
    local owner = ownerLicense(source)
    if not owner then return nil end

    local saveId = SKSaves and SKSaves.getActiveSaveId and SKSaves.getActiveSaveId(source)
    if type(saveId) == 'string' and saveId ~= '' then
        return ('%s:%s'):format(owner, saveId)
    end

    return owner
end

---@param owner string
---@return table|nil
local function dbSelectAccount(owner)
    local row = MySQL.single.await(
        'SELECT schema_version, document_json FROM player_avatars WHERE owner_identifier = ?',
        { owner }
    )
    if not row then
        return nil
    end
    return SKAvatarShared.validateAccountDocument(json.decode(row.document_json))
end

---@param owner string
---@param document table
local function dbWriteAccount(owner, document)
    MySQL.query.await([[
        INSERT INTO player_avatars (owner_identifier, schema_version, document_json)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            schema_version = VALUES(schema_version),
            document_json = VALUES(document_json)
    ]], {
        owner,
        SKAvatarShared.SCHEMA_VERSION,
        json.encode(SKAvatarShared.validateAccountDocument(document)),
    })
end

---@param source integer
---@return table
local function getAccount(source)
    local cached = accountCache[source]
    local owner = avatarOwnerKey(source)
    if not owner then
        return SKAvatarShared.newAccountDocument()
    end

    if cached and cached.owner == owner then
        return cached.document
    end

    local document = dbSelectAccount(owner)
    if not document then
        local legacyOwner = ownerLicense(source)
        document = legacyOwner and legacyOwner ~= owner and dbSelectAccount(legacyOwner) or nil
        document = document and SKAvatarShared.clone(document) or SKAvatarShared.newAccountDocument()
        dbWriteAccount(owner, document)
    end

    accountCache[source] = { owner = owner, document = document }
    return document
end

---@param source integer
---@param document table
---@return table
local function persistAccount(source, document)
    local owner = avatarOwnerKey(source)
    local normalized = SKAvatarShared.validateAccountDocument(document)
    if owner then
        dbWriteAccount(owner, normalized)
        accountCache[source] = { owner = owner, document = normalized }
    end
    return normalized
end

---@param source integer
---@param amount integer
---@return integer, integer
function SKAvatar.addCosmeticCurrency(source, amount)
    local account = getAccount(source)
    local normalizedAmount = math.max(0, math.floor(amount))
    account.cosmetic_currency = account.cosmetic_currency + normalizedAmount
    persistAccount(source, account)
    return normalizedAmount, account.cosmetic_currency
end

---@param value any
---@param defaultValue integer
---@param minimum integer|nil
---@return integer
local function normalizeInteger(value, defaultValue, minimum)
    if type(value) ~= 'number' or value % 1 ~= 0 then
        return defaultValue
    end
    if minimum and value < minimum then
        return minimum
    end
    return value
end

---@param value any
---@param defaultValue number
---@param minimum number|nil
---@param maximum number|nil
---@return number
local function normalizeNumber(value, defaultValue, minimum, maximum)
    if type(value) ~= 'number' then
        return defaultValue
    end
    if minimum and value < minimum then
        return minimum
    end
    if maximum and value > maximum then
        return maximum
    end
    return value
end

---@param components table[]
---@return table<integer, table>
local function mapComponents(components)
    local mapped = {}
    for _, entry in ipairs(components) do
        mapped[entry.component_id] = entry
    end
    return mapped
end

---@param props table[]
---@return table<integer, table>
local function mapProps(props)
    local mapped = {}
    for _, entry in ipairs(props) do
        mapped[entry.prop_id] = entry
    end
    return mapped
end

---@param current table
---@param incoming table|nil
---@return table
local function sanitizeHeadBlend(current, incoming)
    incoming = type(incoming) == 'table' and incoming or {}
    return {
        shapeFirst = normalizeInteger(incoming.shapeFirst, current.shapeFirst, 0),
        shapeSecond = normalizeInteger(incoming.shapeSecond, current.shapeSecond, 0),
        shapeThird = normalizeInteger(incoming.shapeThird, current.shapeThird, 0),
        skinFirst = normalizeInteger(incoming.skinFirst, current.skinFirst, 0),
        skinSecond = normalizeInteger(incoming.skinSecond, current.skinSecond, 0),
        skinThird = normalizeInteger(incoming.skinThird, current.skinThird, 0),
        shapeMix = normalizeNumber(incoming.shapeMix, current.shapeMix, 0.0, 1.0),
        skinMix = normalizeNumber(incoming.skinMix, current.skinMix, 0.0, 1.0),
        thirdMix = normalizeNumber(incoming.thirdMix, current.thirdMix, 0.0, 1.0),
    }
end

---@param current table
---@param incoming table|nil
---@return table
local function sanitizeFaceFeatures(current, incoming)
    local sanitized = {}
    incoming = type(incoming) == 'table' and incoming or {}
    for _, key in ipairs(SKAvatarShared.FACE_FEATURES) do
        sanitized[key] = normalizeNumber(incoming[key], current[key], -1.0, 1.0)
    end
    return sanitized
end

---@param current table
---@param incoming table|nil
---@return table
local function sanitizeHeadOverlays(current, incoming)
    local sanitized = {}
    incoming = type(incoming) == 'table' and incoming or {}
    for _, key in ipairs(SKAvatarShared.HEAD_OVERLAYS) do
        local currentOverlay = current[key]
        local nextOverlay = type(incoming[key]) == 'table' and incoming[key] or {}
        sanitized[key] = {
            style = normalizeInteger(nextOverlay.style, currentOverlay.style, 0),
            opacity = normalizeNumber(nextOverlay.opacity, currentOverlay.opacity, 0.0, 1.0),
            color = normalizeInteger(nextOverlay.color, currentOverlay.color, 0),
            secondColor = normalizeInteger(nextOverlay.secondColor, currentOverlay.secondColor, 0),
        }
    end
    return sanitized
end

---@param current table
---@param incoming table|nil
---@return table
local function sanitizeHair(current, incoming)
    incoming = type(incoming) == 'table' and incoming or {}
    return {
        style = normalizeInteger(incoming.style, current.style, 0),
        color = normalizeInteger(incoming.color, current.color, 0),
        highlight = normalizeInteger(incoming.highlight, current.highlight, 0),
        texture = normalizeInteger(incoming.texture, current.texture, 0),
    }
end

---@param ownedLookup table
---@param categoryKey string
---@param drawable integer
---@param texture integer
---@return boolean
local function ownsVariation(ownedLookup, categoryKey, drawable, texture)
    if SKAvatarShared.isVariationAutoOwned(categoryKey, drawable) then
        return true
    end

    local categoryOwned = ownedLookup[categoryKey]
    if not categoryOwned then
        return false
    end
    return categoryOwned[SKAvatarShared.variationToken(drawable, texture)] == true
end

---@param currentAppearance table
---@param incomingAppearance table|nil
---@param ownedLookup table
---@return table[]
local function sanitizeComponents(currentAppearance, incomingAppearance, ownedLookup)
    local sanitized = {}
    local currentById = mapComponents(currentAppearance.components)
    local incomingById = mapComponents(type(incomingAppearance) == 'table' and incomingAppearance.components or {})

    for _, componentId in ipairs(SKAvatarShared.PED_COMPONENTS_IDS) do
        local currentEntry = currentById[componentId]
        local incomingEntry = incomingById[componentId] or currentEntry
        local category = SKAvatarShared.getCategoryBySlot('component', componentId)
        local drawable = normalizeInteger(incomingEntry.drawable, currentEntry.drawable, 0)
        local texture = normalizeInteger(incomingEntry.texture, currentEntry.texture, 0)

        if category and not ownsVariation(ownedLookup, category.key, drawable, texture) then
            sanitized[#sanitized + 1] = {
                component_id = componentId,
                drawable = currentEntry.drawable,
                texture = currentEntry.texture,
            }
        else
            sanitized[#sanitized + 1] = {
                component_id = componentId,
                drawable = drawable,
                texture = texture,
            }
        end
    end

    return sanitized
end

---@param currentAppearance table
---@param incomingAppearance table|nil
---@param ownedLookup table
---@return table[]
local function sanitizeProps(currentAppearance, incomingAppearance, ownedLookup)
    local sanitized = {}
    local currentById = mapProps(currentAppearance.props)
    local incomingById = mapProps(type(incomingAppearance) == 'table' and incomingAppearance.props or {})

    for _, propId in ipairs(SKAvatarShared.PED_PROPS_IDS) do
        local currentEntry = currentById[propId]
        local incomingEntry = incomingById[propId] or currentEntry
        local category = SKAvatarShared.getCategoryBySlot('prop', propId)
        local drawable = normalizeInteger(incomingEntry.drawable, currentEntry.drawable, -1)
        local texture = normalizeInteger(incomingEntry.texture, currentEntry.texture, -1)

        if category and not ownsVariation(ownedLookup, category.key, drawable, texture) then
            sanitized[#sanitized + 1] = {
                prop_id = propId,
                drawable = currentEntry.drawable,
                texture = currentEntry.texture,
            }
        else
            sanitized[#sanitized + 1] = {
                prop_id = propId,
                drawable = drawable,
                texture = texture,
            }
        end
    end

    return sanitized
end

---@param gender string
---@param currentAppearance table
---@param incomingAppearance table|nil
---@param ownedLookup table
---@return table
local function sanitizeAppearance(gender, currentAppearance, incomingAppearance, ownedLookup)
    local sanitized = SKAvatarShared.normalizeAppearance(gender, currentAppearance)
    incomingAppearance = type(incomingAppearance) == 'table' and incomingAppearance or {}

    sanitized.headBlend = sanitizeHeadBlend(currentAppearance.headBlend, incomingAppearance.headBlend)
    sanitized.faceFeatures = sanitizeFaceFeatures(currentAppearance.faceFeatures, incomingAppearance.faceFeatures)
    sanitized.headOverlays = sanitizeHeadOverlays(currentAppearance.headOverlays, incomingAppearance.headOverlays)
    sanitized.hair = sanitizeHair(currentAppearance.hair, incomingAppearance.hair)
    sanitized.eyeColor = normalizeInteger(incomingAppearance.eyeColor, currentAppearance.eyeColor, 0)
    sanitized.components = sanitizeComponents(currentAppearance, incomingAppearance, ownedLookup)
    sanitized.props = sanitizeProps(currentAppearance, incomingAppearance, ownedLookup)

    local hairEntry = SKAvatarShared.getComponentEntry(sanitized.components, 2)
    hairEntry.drawable = sanitized.hair.style
    hairEntry.texture = sanitized.hair.texture

    return sanitized
end

---@param appearance table
---@param category table
---@param drawable integer
---@param texture integer
local function applyVariationToAppearance(appearance, category, drawable, texture)
    if category.kind == 'component' then
        local entry = SKAvatarShared.getComponentEntry(appearance.components, category.slot)
        entry.drawable = drawable
        entry.texture = texture
        if category.slot == 2 then
            appearance.hair.style = drawable
            appearance.hair.texture = texture
        end
        return
    end

    local entry = SKAvatarShared.getPropEntry(appearance.props, category.slot)
    entry.drawable = drawable
    entry.texture = texture
end

---@param source integer
---@return table
local function accountPayload(source)
    local account = getAccount(source)
    return {
        activeGender = account.activeGender,
        cosmetic_currency = account.cosmetic_currency,
        appearances = SKAvatarShared.clone(account.appearances),
        ownedClothing = SKAvatarShared.clone(account.ownedClothing),
    }
end

---@param source integer
---@return table
local function activeAppearancePayload(source)
    local account = getAccount(source)
    return {
        activeGender = account.activeGender,
        appearance = SKAvatarShared.clone(account.appearances[account.activeGender]),
        account = accountPayload(source),
    }
end

lib.callback.register('streetkings:avatar:getState', function(source)
    if not dbReady then
        return { ok = false, error = 'db_not_ready' }
    end

    local owner = ownerLicense(source)
    if not owner then
        return { ok = false, error = 'no_license' }
    end

    return {
        ok = true,
        account = accountPayload(source),
    }
end)

lib.callback.register('streetkings:avatar:getActiveAppearance', function(source)
    if not dbReady then
        return { ok = false, error = 'db_not_ready' }
    end

    local owner = ownerLicense(source)
    if not owner then
        return { ok = false, error = 'no_license' }
    end

    local payload = activeAppearancePayload(source)
    payload.ok = true
    return payload
end)

lib.callback.register('streetkings:avatar:setGender', function(source, gender)
    if not dbReady then
        return { ok = false, error = 'db_not_ready' }
    end
    if not ownerLicense(source) then
        return { ok = false, error = 'no_license' }
    end
    if not SKAvatarShared.isGender(gender) then
        return { ok = false, error = 'invalid_gender' }
    end

    local account = getAccount(source)
    account.activeGender = gender
    persistAccount(source, account)

    return {
        ok = true,
        account = accountPayload(source),
    }
end)

lib.callback.register('streetkings:avatar:saveAppearance', function(source, appearance)
    if not dbReady then
        return { ok = false, error = 'db_not_ready' }
    end
    if not ownerLicense(source) then
        return { ok = false, error = 'no_license' }
    end

    local account = getAccount(source)
    local gender = account.activeGender
    local ownedLookup = account.ownedClothing[gender]
    account.appearances[gender] = sanitizeAppearance(gender, account.appearances[gender], appearance, ownedLookup)
    persistAccount(source, account)

    return {
        ok = true,
        account = accountPayload(source),
    }
end)

lib.callback.register('streetkings:avatar:equipOwnedVariation', function(source, categoryKey, drawable, texture)
    if not dbReady then
        return { ok = false, error = 'db_not_ready' }
    end
    if not ownerLicense(source) then
        return { ok = false, error = 'no_license' }
    end

    local category = SKAvatarShared.getCategoryByKey(categoryKey)
    if not category then
        return { ok = false, error = 'invalid_category' }
    end

    local account = getAccount(source)
    local gender = account.activeGender
    local normalizedDrawable = normalizeInteger(drawable, 0, category.kind == 'prop' and -1 or 0)
    local normalizedTexture = normalizeInteger(texture, category.kind == 'prop' and -1 or 0, category.kind == 'prop' and -1 or 0)

    if not ownsVariation(account.ownedClothing[gender], category.key, normalizedDrawable, normalizedTexture) then
        return { ok = false, error = 'not_owned' }
    end

    applyVariationToAppearance(account.appearances[gender], category, normalizedDrawable, normalizedTexture)
    account.appearances[gender] = sanitizeAppearance(gender, account.appearances[gender], account.appearances[gender], account.ownedClothing[gender])
    persistAccount(source, account)

    return {
        ok = true,
        account = accountPayload(source),
    }
end)

lib.callback.register('streetkings:avatar:purchaseClothing', function(source, categoryKey, drawable, texture)
    if not dbReady then
        return { ok = false, error = 'db_not_ready' }
    end
    if not ownerLicense(source) then
        return { ok = false, error = 'no_license' }
    end

    local category = SKAvatarShared.getCategoryByKey(categoryKey)
    if not category then
        return { ok = false, error = 'invalid_category' }
    end

    local account = getAccount(source)
    local gender = account.activeGender
    local normalizedDrawable = normalizeInteger(drawable, 0, category.kind == 'prop' and -1 or 0)
    local normalizedTexture = normalizeInteger(texture, category.kind == 'prop' and -1 or 0, category.kind == 'prop' and -1 or 0)
    local token = SKAvatarShared.variationToken(normalizedDrawable, normalizedTexture)
    local ownedLookup = account.ownedClothing[gender][category.key]
    local purchased = ownedLookup[token] == true

    if not purchased then
        if account.cosmetic_currency < category.price then
            return { ok = false, error = 'insufficient_funds', balance = account.cosmetic_currency }
        end
        account.cosmetic_currency = account.cosmetic_currency - category.price
        ownedLookup[token] = true
        SKStats.increment(source, 'clothingPurchased', 1)
    end

    applyVariationToAppearance(account.appearances[gender], category, normalizedDrawable, normalizedTexture)
    account.appearances[gender] = sanitizeAppearance(gender, account.appearances[gender], account.appearances[gender], account.ownedClothing[gender])
    persistAccount(source, account)

    return {
        ok = true,
        purchased = not purchased,
        account = accountPayload(source),
    }
end)

lib.callback.register('streetkings:avatar:purchaseCart', function(source, items)
    if not dbReady then
        return { ok = false, error = 'db_not_ready' }
    end
    if not ownerLicense(source) then
        return { ok = false, error = 'no_license' }
    end
    if type(items) ~= 'table' or #items == 0 then
        return { ok = false, error = 'empty_cart' }
    end

    local account = getAccount(source)
    local gender = account.activeGender

    local totalCost = 0
    local validated = {}
    for _, item in ipairs(items) do
        local category = SKAvatarShared.getCategoryByKey(item.categoryKey)
        if not category then
            return { ok = false, error = 'invalid_category' }
        end
        local normalizedDrawable = normalizeInteger(item.drawable, 0, category.kind == 'prop' and -1 or 0)
        local normalizedTexture  = normalizeInteger(item.texture,  category.kind == 'prop' and -1 or 0, category.kind == 'prop' and -1 or 0)
        local alreadyOwned = ownsVariation(account.ownedClothing[gender], category.key, normalizedDrawable, normalizedTexture)
        if not alreadyOwned then
            totalCost = totalCost + category.price
        end
        validated[#validated + 1] = {
            category = category,
            drawable = normalizedDrawable,
            texture  = normalizedTexture,
            alreadyOwned = alreadyOwned,
        }
    end

    if account.cosmetic_currency < totalCost then
        return { ok = false, error = 'insufficient_funds', balance = account.cosmetic_currency }
    end

    local purchasedCount = 0
    for _, item in ipairs(validated) do
        if not item.alreadyOwned then
            local token = SKAvatarShared.variationToken(item.drawable, item.texture)
            account.ownedClothing[gender][item.category.key][token] = true
            account.cosmetic_currency = account.cosmetic_currency - item.category.price
            purchasedCount = purchasedCount + 1
            SKStats.increment(source, 'clothingPurchased', 1)
        end
        applyVariationToAppearance(account.appearances[gender], item.category, item.drawable, item.texture)
    end

    account.appearances[gender] = sanitizeAppearance(gender, account.appearances[gender], account.appearances[gender], account.ownedClothing[gender])
    persistAccount(source, account)

    return {
        ok = true,
        purchasedCount = purchasedCount,
        account = accountPayload(source),
    }
end)
