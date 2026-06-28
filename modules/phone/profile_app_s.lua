local PROFILE_APP = {
    id = 'profile',
    label = 'Perfil',
    icon = 'fa-user',
    glyph = 'P',
    color = '#14b8a6',
    category = 'system',
    ui = 'html/apps/profile/index.html',
    description = 'Demo app for the StreetKings tablet external app SDK.',
    version = '1.0.0',
    developer = 'StreetKings',
}

local function registerProfileApp()
    exports[GetCurrentResourceName()]:RegisterTabletApp(PROFILE_APP)
end

local function cleanAlias(value)
    value = tostring(value or ''):gsub('[\r\n\t]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, 32)
end

local function cleanPhotoUrl(value)
    value = tostring(value or ''):gsub('[\r\n\t]', '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return '' end
    if not value:match('^https?://') and not value:match('^nui://') then
        return nil
    end
    return value:sub(1, 512)
end

lib.callback.register('streetkings:profileApp:getProfile', function(source)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save' }
    end

    return {
        ok = true,
        profile = {
            alias = SKSaves.read(source, 'profile.alias') or '',
            photoUrl = SKSaves.read(source, 'profile.photoUrl') or '',
            cash = SKSaves.read(source, 'economy.cash') or 0,
            level = SKSaves.read(source, 'progression.level') or 1,
            playerXp = SKSaves.read(source, 'progression.playerXp') or 0,
        },
        tablet = exports[GetCurrentResourceName()]:GetTabletConfig(source).config,
    }
end)

lib.callback.register('streetkings:profileApp:saveProfile', function(source, data)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save' }
    end

    local alias = cleanAlias(data and data.alias)
    local photoUrl = cleanPhotoUrl(data and data.photoUrl)
    if alias == '' then
        return { ok = false, error = 'empty_alias' }
    end
    if photoUrl == nil then
        return { ok = false, error = 'invalid_photo_url' }
    end

    local okAlias = SKSaves.write(source, 'profile.alias', alias)
    local okPhoto = SKSaves.write(source, 'profile.photoUrl', photoUrl)
    local ok = okAlias and okPhoto
    return {
        ok = ok,
        error = ok and nil or 'write_failed',
        profile = {
            alias = alias,
            photoUrl = photoUrl,
            cash = SKSaves.read(source, 'economy.cash') or 0,
            level = SKSaves.read(source, 'progression.level') or 1,
            playerXp = SKSaves.read(source, 'progression.playerXp') or 0,
        },
        tablet = exports[GetCurrentResourceName()]:GetTabletConfig(source).config,
    }
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        registerProfileApp()
    end
end)

CreateThread(function()
    Wait(750)
    registerProfileApp()
end)
