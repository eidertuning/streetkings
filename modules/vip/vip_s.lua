SKVip = {
    players = {},
}

local VIP_STUDIO_APP = {
    id = 'vipstudio',
    label = 'VIP Studio',
    icon = 'fa-crown',
    glyph = 'VIP',
    color = '#ffd147',
    category = 'system',
    ui = 'html/apps/vipstudio/index.html',
    description = 'Personaliza tu nametag VIP y etiquetas de admin.',
    version = '1.0.0',
    developer = 'Five Horizon',
}

local NONE_ROLE = {
    key = 'none',
    tier = 'none',
    label = '',
    priority = 0,
    color = '#9ca3af',
    icon = 'fa-solid fa-road',
    permissions = {},
    customization = {},
    allowedPresets = {},
}

local DEFAULT_TAG = {
    enabled = true,
    selectedTier = '',
    textColor = '#ffffff',
    mainColor = '',
    borderColor = '',
    backgroundColor = '#000000',
    backgroundStyle = 'dark',
    icon = '',
    bannerStyle = 'default',
    effect = 'none',
    glow = false,
    animated = false,
    rainbow = false,
    showAdminTag = true,
    adminDisplayMode = 'admin_plus_vip',
    adminColor = '#ef4444',
    adminIcon = 'fa-solid fa-shield-halved',
    adminBannerStyle = 'admin',
}

local DEFAULT_PRESETS = {
    icons = { 'fa-solid fa-road', 'fa-solid fa-gauge-high' },
    borders = { 'thin' },
    backgrounds = { 'dark' },
    bannerStyles = { 'default', 'clean' },
    effects = { 'none' },
}

local function nowMs()
    return GetGameTimer()
end

local function registerVipStudioApp()
    pcall(function()
        exports[GetCurrentResourceName()]:RegisterTabletApp(VIP_STUDIO_APP)
    end)
end

local function shallowCopy(value)
    local copy = {}
    if type(value) == 'table' then
        for key, item in pairs(value) do
            if type(item) == 'table' then
                local nested = {}
                for nestedKey, nestedItem in pairs(item) do
                    nested[nestedKey] = nestedItem
                end
                copy[key] = nested
            else
                copy[key] = item
            end
        end
    end
    return copy
end

local function tableIncludes(list, value)
    if type(list) ~= 'table' then return false end
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

local function appendUnique(list, value)
    if type(value) ~= 'string' or value == '' or tableIncludes(list, value) then return end
    list[#list + 1] = value
end

local function sortedVipRoles()
    local roles = {}
    local cfgRoles = type(SKConfig.DiscordVipRoles) == 'table' and SKConfig.DiscordVipRoles or {}
    for key, role in pairs(cfgRoles) do
        if type(role) == 'table' then
            local copy = shallowCopy(role)
            copy.key = tostring(key)
            copy.tier = tostring(key)
            copy.priority = tonumber(copy.priority) or 0
            copy.permissions = type(copy.permissions) == 'table' and copy.permissions or {}
            copy.customization = type(copy.customization) == 'table' and copy.customization or {}
            copy.allowedPresets = type(copy.allowedPresets) == 'table' and copy.allowedPresets or {}
            roles[#roles + 1] = copy
        end
    end
    table.sort(roles, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    return roles
end

local function configuredDiscordRoleIds()
    local ids = {}
    for _, role in ipairs(sortedVipRoles()) do
        if type(role.discordRoleId) == 'string' and role.discordRoleId ~= '' then
            ids[role.discordRoleId] = true
        end
    end
    return ids
end

local function roleForKey(key)
    for _, role in ipairs(sortedVipRoles()) do
        if role.key == key then return role end
    end
    return nil
end

local function getDiscordIdentifier(source)
    if SKDiscord and type(SKDiscord.GetDiscordId) == 'function' then
        local discordId = SKDiscord.GetDiscordId(source)
        if type(discordId) == 'string' and discordId ~= '' then
            return discordId, ('discord:%s'):format(discordId)
        end
    end

    local identifier = GetPlayerIdentifierByType(source --[[@as string]], 'discord')
    local discordId = type(identifier) == 'string' and identifier:match('^discord:(%d+)$') or nil
    return discordId, identifier
end

local function getBotToken()
    local token = GetConvar('sk_discord_bot_token', '')
    if token == '' then token = GetConvar('streetkings_discord_bot_token', '') end
    return token
end

local function hasConfiguredDiscordRoles()
    for roleId in pairs(configuredDiscordRoleIds()) do
        if roleId ~= '' then return true end
    end
    return false
end

local function fetchGuildMember(discordId)
    local token = getBotToken()
    local guildId = tostring(SKConfig.DiscordGuildId or '')
    if token == '' or guildId == '' or not discordId or discordId == '' then
        return nil, 'discord_not_configured'
    end

    local p = promise.new()
    local url = ('https://discord.com/api/v10/guilds/%s/members/%s'):format(guildId, discordId)
    PerformHttpRequest(url, function(status, body)
        p:resolve({ status = status, body = body })
    end, 'GET', '', {
        ['Authorization'] = ('Bot %s'):format(token),
        ['Content-Type'] = 'application/json',
    })

    local response = Citizen.Await(p)
    if not response or response.status ~= 200 then
        return nil, ('discord_status_%s'):format(response and response.status or 'unknown')
    end

    local ok, decoded = pcall(json.decode, response.body or '{}')
    if not ok or type(decoded) ~= 'table' then
        return nil, 'discord_decode_failed'
    end
    return decoded, nil
end

local function resolveVipRole(roleIds)
    roleIds = type(roleIds) == 'table' and roleIds or {}
    local owned = {}
    for _, roleId in ipairs(roleIds) do
        owned[tostring(roleId)] = true
    end

    for _, role in ipairs(sortedVipRoles()) do
        local discordRoleId = tostring(role.discordRoleId or '')
        if discordRoleId ~= '' and owned[discordRoleId] then
            return role
        end
    end
    return NONE_ROLE
end

local function normalizeHexColor(value, fallback)
    value = type(value) == 'string' and value or ''
    if value:match('^#%x%x%x%x%x%x$') then return value end
    return fallback
end

local function cleanString(value, fallback, maxLength)
    value = type(value) == 'string' and value or ''
    value = value:gsub('[\r\n\t]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return fallback end
    return value:sub(1, maxLength)
end

local function safeOption(value, allowed, fallback)
    value = cleanString(value, fallback, 64)
    return tableIncludes(allowed, value) and value or fallback
end

local function isAceAllowed(source, ace)
    local allowed = IsPlayerAceAllowed(source, ace)
    return allowed == true or allowed == 1
end

local function isAdmin(source)
    if source == 0 then return true end
    if SKPermissions and type(SKPermissions.IsStaff) == 'function' then
        return SKPermissions.IsStaff(source)
    end
    for _, ace in ipairs({
        'command',
        'admin',
        'group.admin',
        'group.superadmin',
        'streetkings.admin',
        'streetkings.vipstudio.admin',
        'command.sk_refresh_vip',
        'command.sk_refresh_vip_id',
        'command.sk_vip_debug',
    }) do
        if isAceAllowed(source, ace) then return true end
    end
    return false
end

local function baseTagConfig()
    return shallowCopy(DEFAULT_TAG)
end

local function fallbackVipRoleFromAce(source)
    local aceMap = {
        {
            key = 'vip_3',
            aces = {
                'streetkings.vipplusplus',
                'streetkings.vip+++',
                'streetkings.vipelite',
                'group.vipelite',
            },
        },
        {
            key = 'vip_2',
            aces = {
                'streetkings.vipplus',
                'streetkings.vip++',
                'group.vipplus',
            },
        },
        {
            key = 'vip_1',
            aces = {
                'streetkings.vip',
                'group.vip',
            },
        },
    }

    for _, entry in ipairs(aceMap) do
        for _, ace in ipairs(entry.aces) do
            if isAceAllowed(source, ace) then
                local role = roleForKey(entry.key)
                if role then return role end
            end
        end
    end

    return nil
end

local function getAllowedPresets(vipRole, admin)
    local presets = shallowCopy(DEFAULT_PRESETS)
    vipRole = type(vipRole) == 'table' and vipRole or NONE_ROLE

    for key, values in pairs(vipRole.allowedPresets or {}) do
        if type(values) == 'table' then
            presets[key] = presets[key] or {}
            for _, value in ipairs(values) do
                appendUnique(presets[key], value)
            end
        end
    end

    if admin then
        local adminCfg = type(SKConfig.AdminNametag) == 'table' and SKConfig.AdminNametag or {}
        for _, value in ipairs(adminCfg.icons or {}) do appendUnique(presets.icons, value) end
        for _, value in ipairs(adminCfg.effects or {}) do appendUnique(presets.effects, value) end
        appendUnique(presets.bannerStyles, adminCfg.bannerStyle or 'admin')
        appendUnique(presets.backgrounds, 'admin')
        appendUnique(presets.borders, 'admin')
    end

    return presets
end

local function applyAceGroup(source, nextRole, previousRole)
    if previousRole and type(previousRole.aceGroup) == 'string' and previousRole.aceGroup ~= ''
        and (not nextRole or previousRole.aceGroup ~= nextRole.aceGroup)
    then
        ExecuteCommand(('remove_principal player.%d %s'):format(source, previousRole.aceGroup))
    end

    if nextRole and type(nextRole.aceGroup) == 'string' and nextRole.aceGroup ~= '' then
        ExecuteCommand(('add_principal player.%d %s'):format(source, nextRole.aceGroup))
    end
end

local function publicRole(role)
    role = type(role) == 'table' and role or NONE_ROLE
    return {
        key = role.key or role.tier or 'none',
        tier = role.tier or role.key or 'none',
        label = role.label or '',
        priority = tonumber(role.priority) or 0,
        color = role.color or '#9ca3af',
        icon = role.icon or 'fa-solid fa-road',
        aceGroup = role.aceGroup,
        permissions = type(role.permissions) == 'table' and role.permissions or {},
        customization = type(role.customization) == 'table' and role.customization or {},
        allowedPresets = type(role.allowedPresets) == 'table' and role.allowedPresets or {},
    }
end

local function roleFromPermissionsVip(vip)
    if type(vip) ~= 'table' or vip.enabled ~= true then return NONE_ROLE end
    local base = roleForKey(vip.key) or {}
    local role = shallowCopy(base)
    role.key = vip.key or base.key or 'none'
    role.tier = vip.legacyTier or base.legacyTier or base.tier or role.key
    role.label = vip.label or base.label or ''
    role.priority = tonumber(base.priority) or ((tonumber(vip.level) or 0) * 10)
    role.color = vip.color or base.color or '#9ca3af'
    role.icon = vip.icon or base.icon or 'fa-solid fa-road'
    role.aceGroup = vip.aceGroup or base.aceGroup
    role.permissions = type(base.permissions) == 'table' and shallowCopy(base.permissions) or {}
    for permission, allowed in pairs(vip.permissions or {}) do
        if allowed then role.permissions[permission] = true end
    end
    role.customization = type(base.customization) == 'table' and shallowCopy(base.customization) or {}
    role.allowedPresets = type(base.allowedPresets) == 'table' and shallowCopy(base.allowedPresets) or {}
    return role
end

local function roleFromPermissionsStaff(staff)
    if type(staff) ~= 'table' or staff.enabled ~= true then return nil end
    return publicRole({
        key = staff.key or 'staff',
        tier = staff.key or 'staff',
        label = staff.label or 'STAFF',
        priority = tonumber(staff.priority) or 1000,
        color = staff.color or '#ef4444',
        icon = staff.icon or 'fa-solid fa-shield-halved',
        permissions = staff.permissions,
    })
end

local function setCachedRole(source, role, reason)
    local previous = SKVip.players[source]
    local oldRole = previous and previous.role or NONE_ROLE
    role = publicRole(role)

    SKVip.players[source] = {
        source = source,
        role = role,
        tier = role.tier or role.key,
        label = role.label or '',
        refreshedAt = nowMs(),
        reason = reason or 'ok',
    }
    applyAceGroup(source, role, oldRole)

    if (oldRole.key or oldRole.tier) ~= (role.key or role.tier) then
        if SKLogs then
            SKLogs.Module('vip', 'vip_sync_changed', {
                source = source,
                title = 'VIP sincronizado',
                publicMessage = ('El VIP de un jugador cambio a %s.'):format(role.label ~= '' and role.label or 'sin VIP'),
                details = ('old=%s\nnew=%s\nreason=%s'):format(oldRole.label or oldRole.key or 'none', role.label or role.key or 'none', reason or 'ok'),
            })
            if (oldRole.priority or 0) > 0 and (role.priority or 0) <= 0 then
                SKLogs.Module('vip', 'role_removed', {
                    source = source,
                    title = 'VIP retirado',
                    publicMessage = 'Un jugador ya no tiene rol VIP activo.',
                    details = ('old=%s\nreason=%s'):format(oldRole.label or oldRole.key or 'none', reason or 'ok'),
                })
            end
        end
        TriggerEvent('streetkings:vip:updated', source, role, oldRole)
        TriggerClientEvent('streetkings:vip:updated', source, role)
    end

    return SKVip.players[source]
end

function SKVip.Get(source)
    return SKVip.players[source] or setCachedRole(source, NONE_ROLE, 'not_refreshed')
end

function SKVip.Refresh(source, force)
    source = tonumber(source)
    if not source or source <= 0 then return nil end

    if SKPermissions and type(SKPermissions.RefreshPlayerDiscordPermissions) == 'function' then
        local data = SKPermissions.RefreshPlayerDiscordPermissions(source, force == true)
        return setCachedRole(source, roleFromPermissionsVip(data and data.vip), data and data.reason or 'permissions_synced')
    end

    local cached = SKVip.players[source]
    local refreshMs = tonumber(SKConfig.DiscordVipRefreshMs) or 300000
    if cached and not force and (nowMs() - (cached.refreshedAt or 0)) < refreshMs then
        return cached
    end

    local aceRole = fallbackVipRoleFromAce(source)
    local discordId = getDiscordIdentifier(source)
    if not discordId or not hasConfiguredDiscordRoles() then
        return setCachedRole(source, aceRole or (cached and cached.role) or NONE_ROLE, aceRole and 'ace_synced' or 'discord_not_configured')
    end

    local member, err = fetchGuildMember(discordId)
    if not member then
        return setCachedRole(source, aceRole or (cached and cached.role) or NONE_ROLE, aceRole and ('ace_fallback_' .. (err or 'discord_failed')) or (err or 'discord_failed'))
    end

    local discordRole = resolveVipRole(member.roles)
    if aceRole and (aceRole.priority or 0) > (discordRole.priority or 0) then
        return setCachedRole(source, aceRole, 'discord_synced_ace_override')
    end

    return setCachedRole(source, discordRole, 'discord_synced')
end

function SKVip.Has(source)
    if SKPermissions and type(SKPermissions.HasVip) == 'function' then
        return SKPermissions.HasVip(source)
    end
    local state = SKVip.Refresh(source, false)
    return state and state.role and (state.role.priority or 0) > 0 or false
end

function SKVip.HasLevel(source, levelOrTier)
    if SKPermissions and type(SKPermissions.HasVipTier) == 'function' then
        return SKPermissions.HasVipTier(source, levelOrTier)
    end
    local state = SKVip.Refresh(source, false)
    local role = state and state.role or NONE_ROLE
    if type(levelOrTier) == 'number' then
        return (role.priority or 0) >= levelOrTier
    end
    local required = roleForKey(tostring(levelOrTier or ''))
    if required then
        return (role.priority or 0) >= (required.priority or 0)
    end
    return false
end

function SKVip.HasPermission(source, permission)
    if SKPermissions and type(SKPermissions.HasVipPermission) == 'function' then
        return SKPermissions.HasVipPermission(source, permission)
    end
    local state = SKVip.Refresh(source, false)
    local permissions = state and state.role and state.role.permissions or {}
    return permissions[tostring(permission or '')] == true
end

function SKVip.GetDefaultRole(source)
    local level = SKSaves and SKSaves.read and tonumber(SKSaves.read(source, 'progression.level')) or 1
    level = math.max(1, math.floor(level or 1))
    local best = nil
    local roles = type(SKConfig.DefaultNametagRoles) == 'table' and SKConfig.DefaultNametagRoles or {}
    for key, role in pairs(roles) do
        if type(role) == 'table' then
            local minLevel = tonumber(role.minLevel) or 1
            local maxLevel = tonumber(role.maxLevel) or math.huge
            if level >= minLevel and level <= maxLevel and (not best or (tonumber(role.priority) or 0) > (tonumber(best.priority) or 0)) then
                best = shallowCopy(role)
                best.key = tostring(key)
                best.tier = tostring(key)
            end
        end
    end

    if not best then
        best = {
            key = 'piloto',
            tier = 'piloto',
            label = 'PILOTO',
            priority = 1,
            color = '#9ca3af',
            icon = 'fa-solid fa-road',
        }
    end

    return publicRole(best)
end

function SKVip.GetTagConfig(source)
    local stored = SKSaves and SKSaves.read and SKSaves.read(source, 'profile.vipTag') or nil
    local config = baseTagConfig()
    if type(stored) == 'table' then
        for key in pairs(config) do
            if stored[key] ~= nil then config[key] = stored[key] end
        end
    end
    return config
end

function SKVip.ValidateTagConfig(source, input)
    local state = SKVip.Refresh(source, false)
    local vipRole = state and state.role or NONE_ROLE
    local admin = isAdmin(source)
    if (vipRole.priority or 0) <= 0 and not admin then
        return false, nil, 'locked'
    end

    input = type(input) == 'table' and input or {}
    local permissions = type(vipRole.customization) == 'table' and vipRole.customization or {}
    local presets = getAllowedPresets(vipRole, admin)
    local config = baseTagConfig()

    config.enabled = input.enabled ~= false
    config.selectedTier = (vipRole.priority or 0) > 0 and (vipRole.key or vipRole.tier or '') or ''
    config.textColor = normalizeHexColor(input.textColor, config.textColor)
    config.mainColor = normalizeHexColor(input.mainColor, vipRole.color or config.mainColor)
    config.borderColor = normalizeHexColor(input.borderColor, config.mainColor)
    config.backgroundColor = normalizeHexColor(input.backgroundColor, config.backgroundColor)

    config.backgroundStyle = permissions.backgrounds and safeOption(input.backgroundStyle, presets.backgrounds, config.backgroundStyle) or config.backgroundStyle
    config.bannerStyle = safeOption(input.bannerStyle, presets.bannerStyles, config.bannerStyle)
    config.effect = permissions.effects and safeOption(input.effect, presets.effects, config.effect) or 'none'
    config.icon = permissions.icons and safeOption(input.icon, presets.icons, vipRole.icon or config.icon) or (vipRole.icon or config.icon)
    config.glow = permissions.glow == true and input.glow == true
    config.animated = permissions.animated == true and input.animated == true
    config.rainbow = permissions.rainbow == true and input.rainbow == true

    if admin then
        local adminCfg = type(SKConfig.AdminNametag) == 'table' and SKConfig.AdminNametag or {}
        config.showAdminTag = input.showAdminTag ~= false
        config.adminDisplayMode = safeOption(input.adminDisplayMode, adminCfg.displayModes or { 'admin_plus_vip' }, 'admin_plus_vip')
        config.adminColor = normalizeHexColor(input.adminColor, adminCfg.color or '#ef4444')
        config.adminIcon = safeOption(input.adminIcon, adminCfg.icons or { 'fa-solid fa-shield-halved' }, adminCfg.icon or 'fa-solid fa-shield-halved')
        config.adminBannerStyle = adminCfg.bannerStyle or 'admin'
    end

    return true, config, nil
end

function SKVip.SetTagConfig(source, input)
    if not SKSaves or not SKSaves.hasActiveSave or not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save' }
    end

    local ok, config, reason = SKVip.ValidateTagConfig(source, input)
    if not ok then
        if SKLogs then
            SKLogs.Module('vip', 'tag_rejected_option', {
                source = source,
                title = 'VIP Studio rechazado',
                publicMessage = 'Una configuracion VIP fue rechazada.',
                details = ('reason=%s'):format(reason or 'unknown'),
            }, 'admin')
        end
        return { ok = false, error = reason or 'invalid_config' }
    end

    local previous = SKVip.GetTagConfig(source)
    local saved = SKSaves.write(source, 'profile.vipTag', config)
    if not saved then return { ok = false, error = 'write_failed' } end

    if SKLogs then
        SKLogs.Module('vip', 'tag_saved', {
            source = source,
            title = 'Nametag VIP guardado',
            publicMessage = 'Un jugador guardo su nametag VIP.',
            details = ('main=%s\nborder=%s\nicon=%s\neffect=%s'):format(config.mainColor, config.borderColor, config.icon, config.effect),
        })
        if isAdmin(source) and (
            previous.showAdminTag ~= config.showAdminTag
            or previous.adminDisplayMode ~= config.adminDisplayMode
            or previous.adminIcon ~= config.adminIcon
            or previous.adminColor ~= config.adminColor
        ) then
            SKLogs.Module('vip', 'admin_mode_changed', {
                source = source,
                title = 'Nametag admin cambiado',
                publicMessage = 'Un admin actualizo su modo de nametag.',
                details = ('show=%s\nmode=%s\nicon=%s\ncolor=%s'):format(tostring(config.showAdminTag), config.adminDisplayMode, config.adminIcon, config.adminColor),
            }, 'admin')
        end
    end
    TriggerEvent('streetkings:vip:tagUpdated', source)
    return { ok = true, config = config, nametag = SKVip.GetEffectiveNametag(source) }
end

function SKVip.ResetTagConfig(source)
    if not SKSaves or not SKSaves.hasActiveSave or not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save' }
    end
    local ok = SKSaves.write(source, 'profile.vipTag', baseTagConfig())
    if not ok then return { ok = false, error = 'write_failed' } end
    if SKLogs then
        SKLogs.Module('vip', 'tag_reset', {
            source = source,
            title = 'Nametag VIP restablecido',
            publicMessage = 'Un jugador restablecio su nametag VIP.',
            details = 'profile.vipTag reset',
        })
    end
    TriggerEvent('streetkings:vip:tagUpdated', source)
    return { ok = true, config = SKVip.GetTagConfig(source), nametag = SKVip.GetEffectiveNametag(source) }
end

function SKVip.GetEffectiveRole(source)
    local vip = SKVip.Refresh(source, false)
    local vipRole = vip and vip.role or NONE_ROLE
    if (vipRole.priority or 0) > 0 then
        return publicRole(vipRole)
    end
    return SKVip.GetDefaultRole(source)
end

function SKVip.GetEffectiveNametag(source)
    local config = SKVip.GetTagConfig(source)
    local vip = SKVip.Refresh(source, false)
    local vipRole = vip and vip.role or NONE_ROLE
    local defaultRole = SKVip.GetDefaultRole(source)
    local permissionData = SKPermissions and SKPermissions.GetPlayerRoleData and SKPermissions.GetPlayerRoleData(source) or nil
    local staffRole = roleFromPermissionsStaff(permissionData and permissionData.staff)
    local admin = isAdmin(source)
    local adminCfg = type(SKConfig.AdminNametag) == 'table' and SKConfig.AdminNametag or {}
    local role = (vipRole.priority or 0) > 0 and vipRole or defaultRole
    local secondaryRole = nil

    if admin and config.showAdminTag ~= false then
        local mode = config.adminDisplayMode or 'admin_plus_vip'
        if mode == 'admin_only' or mode == 'admin_plus_vip' then
            role = staffRole or publicRole({
                key = 'admin',
                tier = 'admin',
                label = adminCfg.label or 'ADMIN',
                priority = adminCfg.priority or 1000,
                color = config.adminColor or adminCfg.color or '#ef4444',
                icon = config.adminIcon or adminCfg.icon or 'fa-solid fa-shield-halved',
            })
            if mode == 'admin_plus_vip' and (vipRole.priority or 0) > 0 then
                secondaryRole = publicRole(vipRole)
            end
        elseif mode == 'vip_only' and (vipRole.priority or 0) > 0 then
            role = publicRole(vipRole)
        end
    end

    local alias = SKSaves and SKSaves.read and SKSaves.read(source, 'profile.alias') or nil
    if type(alias) ~= 'string' or alias == '' then alias = GetPlayerName(source) or 'Piloto' end
    local level = SKSaves and SKSaves.read and SKSaves.read(source, 'progression.level') or 1

    local mainColor = config.mainColor ~= '' and config.mainColor or (role.color or '#9ca3af')
    return {
        source = source,
        alias = alias,
        level = tonumber(level) or 1,
        isAdmin = admin,
        isVip = (vipRole.priority or 0) > 0,
        vip = publicRole(vipRole),
        role = publicRole(role),
        secondaryRole = secondaryRole,
        display = {
            enabled = config.enabled ~= false,
            textColor = normalizeHexColor(config.textColor, '#ffffff'),
            mainColor = normalizeHexColor(mainColor, '#9ca3af'),
            borderColor = normalizeHexColor(config.borderColor, mainColor),
            backgroundColor = normalizeHexColor(config.backgroundColor, '#000000'),
            backgroundStyle = cleanString(config.backgroundStyle, 'dark', 24),
            icon = config.icon ~= '' and config.icon or (role.icon or 'fa-solid fa-road'),
            bannerStyle = cleanString(config.bannerStyle, role.key == 'admin' and 'admin' or 'default', 24),
            effect = cleanString(config.effect, 'none', 24),
            glow = config.glow == true or role.key == 'admin',
            animated = config.animated == true,
            rainbow = config.rainbow == true,
        },
    }
end

function SKVip.GetStudioData(source)
    if not SKSaves or not SKSaves.hasActiveSave or not SKSaves.hasActiveSave(source) then
        return { ok = false, error = 'no_active_save' }
    end

    local state = SKVip.Refresh(source, false)
    local role = state and state.role or NONE_ROLE
    local admin = isAdmin(source)
    local permissionData = SKPermissions and SKPermissions.GetPlayerRoleData and SKPermissions.GetPlayerRoleData(source) or nil
    local allRoles = {}
    for _, vipRole in ipairs(sortedVipRoles()) do
        allRoles[#allRoles + 1] = publicRole(vipRole)
    end

    return {
        ok = true,
        isVip = (role.priority or 0) > 0,
        isAdmin = admin,
        staff = permissionData and permissionData.staff or nil,
        permissionsData = permissionData,
        vip = publicRole(role),
        defaultRole = SKVip.GetDefaultRole(source),
        effective = SKVip.GetEffectiveNametag(source),
        config = SKVip.GetTagConfig(source),
        permissions = type(role.permissions) == 'table' and role.permissions or {},
        customization = type(role.customization) == 'table' and role.customization or {},
        allowedPresets = getAllowedPresets(role, admin),
        adminNametag = type(SKConfig.AdminNametag) == 'table' and SKConfig.AdminNametag or {},
        roles = allRoles,
        refreshedAt = state and state.refreshedAt or 0,
        reason = state and state.reason or '',
    }
end

lib.callback.register('streetkings:vip:getSelf', function(source)
    return SKVip.Refresh(source, false)
end)

lib.callback.register('streetkings:vip:getStudioData', function(source)
    return SKVip.GetStudioData(source)
end)

lib.callback.register('streetkings:vip:saveTagConfig', function(source, data)
    return SKVip.SetTagConfig(source, data and data.config or data)
end)

lib.callback.register('streetkings:vip:resetTagConfig', function(source)
    return SKVip.ResetTagConfig(source)
end)

lib.callback.register('streetkings:vip:refresh', function(source)
    return { ok = true, vip = SKVip.Refresh(source, true), studio = SKVip.GetStudioData(source) }
end)

local function canRunAdminCommand(source)
    if source == 0 then return true end
    return isAdmin(source)
end

RegisterCommand('sk_refresh_vip', function(source)
    if not canRunAdminCommand(source) then return end
    if source <= 0 then
        for _, player in ipairs(GetPlayers()) do
            SKVip.Refresh(tonumber(player), true)
        end
    else
        SKVip.Refresh(source, true)
    end
    if SKLogs then
        SKLogs.Emit('adminCommand', {
            source = source,
            command = 'sk_refresh_vip',
            details = source <= 0 and 'refresh=all' or 'refresh=self',
        }, 'admin')
    end
end, false)

RegisterCommand('sk_refresh_vip_id', function(source, args)
    if not canRunAdminCommand(source) then return end
    local target = tonumber(args and args[1])
    if target and GetPlayerName(target) then
        SKVip.Refresh(target, true)
        if SKLogs then
            SKLogs.Emit('adminCommand', {
                source = source,
                command = 'sk_refresh_vip_id',
                target = target,
                details = ('refresh target=%d'):format(target),
            }, 'admin')
        end
    end
end, false)

RegisterCommand('sk_vip_debug', function(source, args)
    if not canRunAdminCommand(source) then return end
    local target = tonumber(args and args[1]) or source
    local state = SKVip.Refresh(target, true)
    print(('[SK:VIP] target=%s tier=%s label=%s reason=%s'):format(target, state and state.tier or 'none', state and state.label or '', state and state.reason or 'unknown'))
    if SKLogs then
        SKLogs.Emit('adminCommand', {
            source = source,
            command = 'sk_vip_debug',
            target = target,
            details = ('tier=%s reason=%s'):format(state and state.tier or 'none', state and state.reason or 'unknown'),
        }, 'admin')
    end
end, false)

AddEventHandler('streetkings:freeroam:enter', function()
    local src = source --[[@as integer]]
    SKVip.Refresh(src, false)
end)

AddEventHandler('playerJoining', function()
    local src = source --[[@as integer]]
    CreateThread(function()
        Wait(2500)
        if GetPlayerName(src) then
            SKVip.Refresh(src, false)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    local cached = SKVip.players[src]
    if cached and cached.role and type(cached.role.aceGroup) == 'string' and cached.role.aceGroup ~= '' then
        ExecuteCommand(('remove_principal player.%d %s'):format(src, cached.role.aceGroup))
    end
    SKVip.players[src] = nil
end)

CreateThread(function()
    while true do
        Wait(math.max(60000, tonumber(SKConfig.DiscordVipRefreshMs) or 300000))
        for _, player in ipairs(GetPlayers()) do
            SKVip.Refresh(tonumber(player), false)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        registerVipStudioApp()
    end
end)

CreateThread(function()
    Wait(750)
    registerVipStudioApp()
end)

exports('HasVipLevel', function(source, levelOrTier) return SKVip.HasLevel(source, levelOrTier) end)
exports('RefreshVip', function(source)
    if SKPermissions and SKPermissions.RefreshPlayerDiscordPermissions then
        return SKPermissions.RefreshPlayerDiscordPermissions(source, true)
    end
    return SKVip.Refresh(source, true)
end)
exports('GetDefaultNametagRole', function(source) return SKVip.GetDefaultRole(source) end)
exports('GetEffectiveNametagRole', function(source) return SKVip.GetEffectiveRole(source) end)
exports('GetEffectiveNametag', function(source) return SKVip.GetEffectiveNametag(source) end)
exports('GetVipTagConfig', function(source) return SKVip.GetTagConfig(source) end)
exports('ValidateVipTagConfig', function(source, config) return SKVip.ValidateTagConfig(source, config) end)
exports('SetVipTagConfig', function(source, config) return SKVip.SetTagConfig(source, config) end)
exports('ResetVipTagConfig', function(source) return SKVip.ResetTagConfig(source) end)
exports('GetVipStudioData', function(source) return SKVip.GetStudioData(source) end)
