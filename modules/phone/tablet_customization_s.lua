local DEFAULT_TABLET = {
    wallpaper = 'streetkings',
    notifications = {
        enabled = true,
        messagePreviews = true,
    },
    appOrder = {
        'Messages',
        'Map',
        'Vehicles',
        'Stats',
        'profile',
        'RealEstate',
        'Towing',
        'Leaderboards',
        'Settings',
    },
    appOverrides = {},
}

local WALLPAPERS = {
    streetkings = true,
    midnight = true,
    neon = true,
    garage = true,
}

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do
        result[key] = copy(item)
    end
    return result
end

local function cleanText(value, maxLen)
    value = tostring(value or ''):gsub('[\r\n\t]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, maxLen or 64)
end

local function normalizeAppId(value)
    value = tostring(value or '')
    if value == '' or #value > 32 then return nil end
    if not value:match('^[%w_]+$') then return nil end
    return value
end

local function normalizeColor(value)
    value = cleanText(value, 32)
    if value:match('^#%x%x%x$') or value:match('^#%x%x%x%x%x%x$') then
        return value
    end
    return nil
end

local function defaultTablet()
    return copy(DEFAULT_TABLET)
end

local function normalizeConfig(input)
    local cfg = defaultTablet()
    input = type(input) == 'table' and input or {}

    if WALLPAPERS[tostring(input.wallpaper or '')] then
        cfg.wallpaper = tostring(input.wallpaper)
    end

    if type(input.notifications) == 'table' then
        cfg.notifications.enabled = input.notifications.enabled ~= false
        cfg.notifications.messagePreviews = input.notifications.messagePreviews ~= false
    end

    if type(input.appOrder) == 'table' then
        cfg.appOrder = {}
        local seen = {}
        for _, rawId in ipairs(input.appOrder) do
            local appId = normalizeAppId(rawId)
            if appId and not seen[appId] then
                seen[appId] = true
                cfg.appOrder[#cfg.appOrder + 1] = appId
            end
        end
    end

    if type(input.appOverrides) == 'table' then
        cfg.appOverrides = {}
        for rawId, rawOverride in pairs(input.appOverrides) do
            local appId = normalizeAppId(rawId)
            if appId and type(rawOverride) == 'table' then
                local override = {}
                local label = cleanText(rawOverride.label, 32)
                local glyph = cleanText(rawOverride.glyph, 4)
                local color = normalizeColor(rawOverride.color)
                if label ~= '' then override.label = label end
                if glyph ~= '' then override.glyph = glyph end
                if color then override.color = color end
                if next(override) then cfg.appOverrides[appId] = override end
            end
        end
    end

    return cfg
end

local function readTabletConfig(source)
    local stored = SKSaves.read(source, 'meta.data.tablet')
    return normalizeConfig(stored)
end

local function writeTabletConfig(source, config)
    return SKSaves.write(source, 'meta.data.tablet', normalizeConfig(config))
end

local function getConfig(source)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save', config = defaultTablet() }
    end

    return { ok = true, config = readTabletConfig(source) }
end

lib.callback.register('streetkings:tablet:getConfig', function(source)
    return getConfig(source)
end)

lib.callback.register('streetkings:tablet:setConfig', function(source, data)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save', config = defaultTablet() }
    end

    local config = normalizeConfig(data and data.config or data)
    local ok = writeTabletConfig(source, config)
    return { ok = ok, error = ok and nil or 'write_failed', config = config }
end)

lib.callback.register('streetkings:tablet:setLayout', function(source, data)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save', config = defaultTablet() }
    end

    local config = readTabletConfig(source)
    config.appOrder = normalizeConfig({ appOrder = data and data.appOrder or {} }).appOrder
    local ok = writeTabletConfig(source, config)
    return { ok = ok, error = ok and nil or 'write_failed', config = config }
end)

lib.callback.register('streetkings:tablet:setAppOverride', function(source, data)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save', config = defaultTablet() }
    end

    local appId = normalizeAppId(data and data.appId)
    if not appId then
        return { ok = false, error = 'invalid_app_id', config = readTabletConfig(source) }
    end

    local config = readTabletConfig(source)
    local overrides = normalizeConfig({
        appOverrides = {
            [appId] = data and data.override or {},
        },
    }).appOverrides
    config.appOverrides[appId] = overrides[appId]
    local ok = writeTabletConfig(source, config)
    return { ok = ok, error = ok and nil or 'write_failed', config = config }
end)

exports('GetTabletConfig', function(source)
    return getConfig(source)
end)

exports('SetTabletConfig', function(source, config)
    if not SKSaves.hasActiveSave(source) then return false, 'no_active_save' end
    local ok = writeTabletConfig(source, config)
    return ok, ok and nil or 'write_failed'
end)
