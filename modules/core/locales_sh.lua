SKLocale = SKLocale or {}

local function normalizeLocale(locale)
    locale = tostring(locale or ''):lower()
    if locale == '' then return 'en' end
    return locale:gsub('_', '-'):match('^([a-z]+)') or 'en'
end

local function getNested(source, key)
    if type(source) ~= 'table' or type(key) ~= 'string' then return nil end
    local current = source
    for part in key:gmatch('[^.]+') do
        if type(current) ~= 'table' then return nil end
        current = current[part]
        if current == nil then return nil end
    end
    return current
end

local function formatValue(value, replacements)
    if type(value) ~= 'string' or replacements == nil then return value end
    if type(replacements) == 'table' then
        return (value:gsub('{([%w_]+)}', function(name)
            local replacement = replacements[name]
            if replacement == nil then return '{' .. name .. '}' end
            return tostring(replacement)
        end))
    end
    return value
end

function SKLocale.current()
    return normalizeLocale((SKConfig and SKConfig.Locale) or 'en')
end

function SKLocale.fallback()
    return normalizeLocale((SKConfig and SKConfig.FallbackLocale) or 'en')
end

function SKLocale.getLocaleTable(locale)
    locale = normalizeLocale(locale or SKLocale.current())
    return Locales and Locales[locale] or nil
end

function SKLocale.get(key, replacements, locale)
    local currentLocale = normalizeLocale(locale or SKLocale.current())
    local fallbackLocale = SKLocale.fallback()
    local value = getNested(SKLocale.getLocaleTable(currentLocale), key)

    if value == nil and currentLocale ~= fallbackLocale then
        value = getNested(SKLocale.getLocaleTable(fallbackLocale), key)
    end

    if value == nil then return key end
    return formatValue(value, replacements)
end

function SKLocale.getUiTranslations(locale)
    local currentLocale = normalizeLocale(locale or SKLocale.current())
    local current = SKLocale.getLocaleTable(currentLocale) or {}
    local fallback = SKLocale.getLocaleTable(SKLocale.fallback()) or {}
    return {
        locale = currentLocale,
        fallbackLocale = SKLocale.fallback(),
        translations = current.ui or {},
        fallbackTranslations = fallback.ui or {},
    }
end

_L = SKLocale.get
