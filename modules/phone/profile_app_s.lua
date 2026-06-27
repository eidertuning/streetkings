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

lib.callback.register('streetkings:profileApp:getProfile', function(source)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save' }
    end

    return {
        ok = true,
        profile = {
            alias = SKSaves.read(source, 'profile.alias') or '',
            cash = SKSaves.read(source, 'economy.cash') or 0,
            level = SKSaves.read(source, 'progression.level') or 1,
            playerXp = SKSaves.read(source, 'progression.playerXp') or 0,
        },
    }
end)

lib.callback.register('streetkings:profileApp:saveProfile', function(source, data)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save' }
    end

    local alias = cleanAlias(data and data.alias)
    if alias == '' then
        return { ok = false, error = 'empty_alias' }
    end

    local ok = SKSaves.write(source, 'profile.alias', alias)
    return {
        ok = ok,
        error = ok and nil or 'write_failed',
        profile = {
            alias = alias,
            cash = SKSaves.read(source, 'economy.cash') or 0,
            level = SKSaves.read(source, 'progression.level') or 1,
            playerXp = SKSaves.read(source, 'progression.playerXp') or 0,
        },
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
