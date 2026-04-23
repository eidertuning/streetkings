---@class SKAvatarAppearanceDocument
---@field model string
---@field headBlend table
---@field faceFeatures table
---@field headOverlays table
---@field components table[]
---@field props table[]
---@field hair table
---@field eyeColor integer

---@class SKAvatarAccountDocument
---@field activeGender string
---@field cosmetic_currency integer
---@field appearances table<string, SKAvatarAppearanceDocument>
---@field ownedClothing table
---@field meta table

SKAvatarShared = {
    SCHEMA_VERSION = 1,
    STARTING_COSMETIC_CURRENCY = 1000,
    PED_COMPONENTS_IDS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
    PED_PROPS_IDS = { 0, 1, 2, 6, 7 },
    FACE_FEATURES = {
        'noseWidth',
        'nosePeakHigh',
        'nosePeakSize',
        'noseBoneHigh',
        'nosePeakLowering',
        'noseBoneTwist',
        'eyeBrownHigh',
        'eyeBrownForward',
        'cheeksBoneHigh',
        'cheeksBoneWidth',
        'cheeksWidth',
        'eyesOpening',
        'lipsThickness',
        'jawBoneWidth',
        'jawBoneBackSize',
        'chinBoneLowering',
        'chinBoneLenght',
        'chinBoneSize',
        'chinHole',
        'neckThickness',
    },
    HEAD_OVERLAYS = {
        'blemishes',
        'beard',
        'eyebrows',
        'ageing',
        'makeUp',
        'blush',
        'complexion',
        'sunDamage',
        'lipstick',
        'moleAndFreckles',
        'chestHair',
        'bodyBlemishes',
    },
    EYE_COLORS = {
        'Green',
        'Emerald',
        'Light Blue',
        'Ocean Blue',
        'Light Brown',
        'Dark Brown',
        'Hazel',
        'Dark Gray',
        'Light Gray',
        'Pink',
        'Yellow',
        'Purple',
        'Blackout',
        'Shades of Gray',
        'Tequila Sunrise',
        'Atomic',
        'Warp',
        'ECola',
        'Space Ranger',
        'Ying Yang',
        'Bullseye',
        'Lizard',
        'Dragon',
        'Extra Terrestrial',
        'Goat',
        'Smiley',
        'Possessed',
        'Demon',
        'Infected',
        'Alien',
        'Undead',
        'Zombie',
    },
}

---@param value any
---@return any
function SKAvatarShared.clone(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = SKAvatarShared.clone(nestedValue)
    end
    return copy
end

---@param value any
---@return integer
local function integerOr(defaultValue, value)
    if type(value) == 'number' and value % 1 == 0 then
        return value
    end
    return defaultValue
end

---@param value any
---@return number
local function numberOr(defaultValue, value)
    if type(value) == 'number' then
        return value
    end
    return defaultValue
end

---@param value string
---@return boolean
function SKAvatarShared.isGender(value)
    return value == 'male' or value == 'female'
end

---@param model string
---@return string
function SKAvatarShared.genderFromModel(model)
    if model == SKAvatarData.Models.female then
        return 'female'
    end
    return 'male'
end

---@param key string
---@return table|nil
function SKAvatarShared.getCategoryByKey(key)
    return SKAvatarData.ClothingCategoriesByKey[key]
end

---@param kind string
---@param slot integer
---@return table|nil
function SKAvatarShared.getCategoryBySlot(kind, slot)
    local bucket = SKAvatarData.ClothingCategoriesBySlot[kind]
    if not bucket then
        return nil
    end
    return bucket[slot]
end

---@param drawable integer
---@param texture integer
---@return string
function SKAvatarShared.variationToken(drawable, texture)
    return ('%s:%s'):format(drawable, texture)
end

---@param categoryKey string
---@param drawable integer
---@return boolean
function SKAvatarShared.isVariationAutoOwned(categoryKey, drawable)
    if categoryKey == 'torso' then
        return drawable >= 0 and drawable <= 15
    end

    if categoryKey == 'shirts' then
        return drawable == 15
    end

    if categoryKey == 'tops' then
        return drawable == 15
    end

    return false
end

---@param componentId integer
---@param components table[]
---@return table|nil
function SKAvatarShared.getComponentEntry(components, componentId)
    for _, entry in ipairs(components) do
        if entry.component_id == componentId then
            return entry
        end
    end
end

---@param propId integer
---@param props table[]
---@return table|nil
function SKAvatarShared.getPropEntry(props, propId)
    for _, entry in ipairs(props) do
        if entry.prop_id == propId then
            return entry
        end
    end
end

---@param gender string
---@return table
local function defaultWearables(gender)
    return SKAvatarData.DefaultWearables[gender]
end

---@return table
local function newFaceFeatures()
    local features = {}
    for _, key in ipairs(SKAvatarShared.FACE_FEATURES) do
        features[key] = 0.0
    end
    return features
end

---@return table
local function newHeadOverlays()
    local overlays = {}
    for _, key in ipairs(SKAvatarShared.HEAD_OVERLAYS) do
        overlays[key] = {
            style = 0,
            opacity = 0.0,
            color = 0,
            secondColor = 0,
        }
    end
    return overlays
end

---@param gender string
---@return table
function SKAvatarShared.newAppearance(gender)
    local defaults = defaultWearables(gender)
    return {
        model = defaults.model,
        headBlend = SKAvatarShared.clone(defaults.headBlend),
        faceFeatures = newFaceFeatures(),
        headOverlays = newHeadOverlays(),
        components = SKAvatarShared.clone(defaults.components),
        props = SKAvatarShared.clone(defaults.props),
        hair = SKAvatarShared.clone(defaults.hair),
        eyeColor = 0,
    }
end

---@return table
local function newOwnedClothing()
    local owned = {
        male = {},
        female = {},
    }

    for gender, _ in pairs(SKAvatarData.Models) do
        local appearance = SKAvatarShared.newAppearance(gender)
        for _, category in ipairs(SKAvatarData.ClothingCategories) do
            owned[gender][category.key] = {}
            local token
            if category.kind == 'component' then
                local entry = assert(SKAvatarShared.getComponentEntry(appearance.components, category.slot), 'streetkings: missing default component')
                token = SKAvatarShared.variationToken(entry.drawable, entry.texture)
            else
                local entry = assert(SKAvatarShared.getPropEntry(appearance.props, category.slot), 'streetkings: missing default prop')
                token = SKAvatarShared.variationToken(entry.drawable, entry.texture)
            end
            owned[gender][category.key][token] = true
        end
    end

    return owned
end

---@return table
function SKAvatarShared.newAccountDocument()
    return {
        activeGender = 'male',
        cosmetic_currency = SKAvatarShared.STARTING_COSMETIC_CURRENCY,
        appearances = {
            male = SKAvatarShared.newAppearance('male'),
            female = SKAvatarShared.newAppearance('female'),
        },
        ownedClothing = newOwnedClothing(),
        meta = {
            schemaVersion = SKAvatarShared.SCHEMA_VERSION,
        },
    }
end

---@param defaults table[]
---@param incoming table[]|nil
---@param idKey string
---@param drawableDefault integer
---@param textureDefault integer
---@return table[]
local function normalizeVariationEntries(defaults, incoming, idKey, drawableDefault, textureDefault)
    local incomingById = {}
    if type(incoming) == 'table' then
        for _, entry in ipairs(incoming) do
            if type(entry) == 'table' and type(entry[idKey]) == 'number' then
                incomingById[entry[idKey]] = entry
            end
        end
    end

    local normalized = {}
    for _, defaultEntry in ipairs(defaults) do
        local resolved = incomingById[defaultEntry[idKey]] or defaultEntry
        normalized[#normalized + 1] = {
            [idKey] = defaultEntry[idKey],
            drawable = integerOr(drawableDefault, resolved.drawable),
            texture = integerOr(textureDefault, resolved.texture),
        }
    end
    return normalized
end

---@param defaults table
---@param incoming table|nil
---@return table
local function normalizeHeadBlend(defaults, incoming)
    incoming = type(incoming) == 'table' and incoming or {}
    return {
        shapeFirst = integerOr(defaults.shapeFirst, incoming.shapeFirst),
        shapeSecond = integerOr(defaults.shapeSecond, incoming.shapeSecond),
        shapeThird = integerOr(defaults.shapeThird, incoming.shapeThird),
        skinFirst = integerOr(defaults.skinFirst, incoming.skinFirst),
        skinSecond = integerOr(defaults.skinSecond, incoming.skinSecond),
        skinThird = integerOr(defaults.skinThird, incoming.skinThird),
        shapeMix = numberOr(defaults.shapeMix, incoming.shapeMix),
        skinMix = numberOr(defaults.skinMix, incoming.skinMix),
        thirdMix = numberOr(defaults.thirdMix, incoming.thirdMix),
    }
end

---@param incoming table|nil
---@return table
local function normalizeFaceFeatures(incoming)
    local normalized = newFaceFeatures()
    if type(incoming) ~= 'table' then
        return normalized
    end
    for _, key in ipairs(SKAvatarShared.FACE_FEATURES) do
        normalized[key] = numberOr(0.0, incoming[key])
    end
    return normalized
end

---@param incoming table|nil
---@return table
local function normalizeHeadOverlays(incoming)
    local normalized = newHeadOverlays()
    if type(incoming) ~= 'table' then
        return normalized
    end
    for _, key in ipairs(SKAvatarShared.HEAD_OVERLAYS) do
        local overlay = type(incoming[key]) == 'table' and incoming[key] or {}
        normalized[key] = {
            style = integerOr(0, overlay.style),
            opacity = numberOr(0.0, overlay.opacity),
            color = integerOr(0, overlay.color),
            secondColor = integerOr(0, overlay.secondColor),
        }
    end
    return normalized
end

---@param defaults table
---@param incoming table|nil
---@return table
local function normalizeHair(defaults, incoming)
    incoming = type(incoming) == 'table' and incoming or {}
    return {
        style = integerOr(defaults.style, incoming.style),
        color = integerOr(defaults.color, incoming.color),
        highlight = integerOr(defaults.highlight, incoming.highlight),
        texture = integerOr(defaults.texture, incoming.texture),
    }
end

---@param gender string
---@param incoming table|nil
---@return table
function SKAvatarShared.normalizeAppearance(gender, incoming)
    local defaults = defaultWearables(gender)
    incoming = type(incoming) == 'table' and incoming or {}

    local appearance = {
        model = SKAvatarData.Models[gender],
        headBlend = normalizeHeadBlend(defaults.headBlend, incoming.headBlend),
        faceFeatures = normalizeFaceFeatures(incoming.faceFeatures),
        headOverlays = normalizeHeadOverlays(incoming.headOverlays),
        components = normalizeVariationEntries(defaults.components, incoming.components, 'component_id', 0, 0),
        props = normalizeVariationEntries(defaults.props, incoming.props, 'prop_id', -1, -1),
        hair = normalizeHair(defaults.hair, incoming.hair),
        eyeColor = integerOr(0, incoming.eyeColor),
    }

    local hairEntry = SKAvatarShared.getComponentEntry(appearance.components, 2)
    hairEntry.drawable = appearance.hair.style
    hairEntry.texture = appearance.hair.texture

    return appearance
end

---@param incoming table|nil
---@return table
function SKAvatarShared.normalizeOwnedClothing(incoming)
    local normalized = newOwnedClothing()
    if type(incoming) ~= 'table' then
        return normalized
    end

    for gender, categories in pairs(normalized) do
        local incomingGender = type(incoming[gender]) == 'table' and incoming[gender] or {}
        for key, ownedEntries in pairs(categories) do
            local merged = {}
            for token in pairs(ownedEntries) do
                merged[token] = true
            end
            local incomingCategory = type(incomingGender[key]) == 'table' and incomingGender[key] or {}
            for token, isOwned in pairs(incomingCategory) do
                if isOwned then
                    merged[token] = true
                end
            end
            normalized[gender][key] = merged
        end
    end

    return normalized
end

---@param incoming table|nil
---@return table
function SKAvatarShared.normalizeAccountDocument(incoming)
    local defaults = SKAvatarShared.newAccountDocument()
    incoming = type(incoming) == 'table' and incoming or {}

    local document = {
        activeGender = SKAvatarShared.isGender(incoming.activeGender) and incoming.activeGender or defaults.activeGender,
        cosmetic_currency = math.max(0, integerOr(defaults.cosmetic_currency, incoming.cosmetic_currency)),
        appearances = {
            male = SKAvatarShared.normalizeAppearance('male', incoming.appearances and incoming.appearances.male),
            female = SKAvatarShared.normalizeAppearance('female', incoming.appearances and incoming.appearances.female),
        },
        ownedClothing = SKAvatarShared.normalizeOwnedClothing(incoming.ownedClothing),
        meta = {
            schemaVersion = SKAvatarShared.SCHEMA_VERSION,
        },
    }

    return document
end

---@param document table
---@return table
function SKAvatarShared.validateAccountDocument(document)
    assert(type(document) == 'table', 'streetkings: invalid avatar document')
    local normalized = SKAvatarShared.normalizeAccountDocument(document)
    assert(SKAvatarShared.isGender(normalized.activeGender), 'streetkings: invalid avatar gender')
    assert(type(normalized.cosmetic_currency) == 'number' and normalized.cosmetic_currency >= 0, 'streetkings: invalid avatar balance')
    return normalized
end