SKPermissions = {
    cache = {},
}

local DEFAULT_REFRESH_MS = 300000
local DEFAULT_NAMETAG_SETTINGS = {
    hideOwnNametag = false,
    showOtherNametags = true,
    preferredNametagType = nil,
}

local function nowMs()
    return GetGameTimer()
end

local function shallowCopy(value)
    local copy = {}
    if type(value) ~= 'table' then return copy end
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
    return copy
end

local function permissionsMap(values)
    local out = {}
    if type(values) ~= 'table' then return out end
    for key, value in pairs(values) do
        if type(key) == 'number' then
            out[tostring(value)] = true
        elseif value == true then
            out[tostring(key)] = true
        end
    end
    return out
end

local function mergePermissions(target, values)
    for permission, allowed in pairs(permissionsMap(values)) do
        if allowed then target[permission] = true end
    end
end

local function cfg()
    return type(SKConfig) == 'table' and type(SKConfig.DiscordPermissions) == 'table'
        and SKConfig.DiscordPermissions or {}
end

local function refreshMs()
    local minutes = tonumber(cfg().refreshMinutes)
    if minutes and minutes > 0 then return math.floor(minutes * 60000) end
    return tonumber(SKConfig and SKConfig.DiscordVipRefreshMs) or DEFAULT_REFRESH_MS
end

local function roleConfig()
    local roles = cfg().roles
    return type(roles) == 'table' and roles or {}
end

local function sortedRoles()
    local roles = {}
    for key, role in pairs(roleConfig()) do
        if type(role) == 'table' then
            local copy = shallowCopy(role)
            copy.key = tostring(key)
            copy.priority = tonumber(copy.priority) or 0
            copy.staffLevel = tonumber(copy.staffLevel) or 0
            copy.vipLevel = tonumber(copy.vipLevel) or 0
            copy.racingLevel = tonumber(copy.racingLevel) or 0
            copy.permissions = permissionsMap(copy.permissions)
            roles[#roles + 1] = copy
        end
    end
    table.sort(roles, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    return roles
end

local function roleForKey(key)
    key = tostring(key or '')
    for _, role in ipairs(sortedRoles()) do
        if role.key == key then return role end
    end
    return nil
end

local function getIdentifier(source, idType)
    if tonumber(source) == 0 then return nil end
    return GetPlayerIdentifierByType(source --[[@as string]], idType)
end

local function getDiscordId(source)
    if SKDiscord and type(SKDiscord.GetDiscordId) == 'function' then
        local id = SKDiscord.GetDiscordId(source)
        if type(id) == 'string' and id ~= '' then return id end
    end

    local identifier = getIdentifier(source, 'discord')
    return type(identifier) == 'string' and identifier:match('^discord:(%d+)$') or nil
end

local function getBotToken()
    local primary = tostring(cfg().botTokenConvar or 'sk_discord_bot_token')
    local token = GetConvar(primary, '')
    if token ~= '' then return token end

    local legacy = cfg().legacyBotTokenConvars
    if type(legacy) == 'table' then
        for _, name in ipairs(legacy) do
            token = GetConvar(tostring(name), '')
            if token ~= '' then return token end
        end
    end

    return ''
end

local function fetchGuildMember(discordId)
    if cfg().enabled == false then return nil, 'disabled' end

    local token = getBotToken()
    local guildId = tostring(cfg().guildId or SKConfig.DiscordGuildId or '')
    if token == '' or guildId == '' or not discordId or discordId == '' then
        return nil, 'discord_not_configured'
    end

    local p = promise.new()
    PerformHttpRequest(('https://discord.com/api/v10/guilds/%s/members/%s'):format(guildId, discordId), function(status, body)
        p:resolve({ status = status, body = body })
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. token,
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

local function ownsDiscordRole(owned, role)
    local roleId = tostring(role.discordRoleId or '')
    return roleId ~= '' and owned[roleId] == true
end

local function playerAceAllowed(source, ace)
    if source == 0 then return true end
    if type(ace) ~= 'string' or ace == '' then return false end
    local ok, allowed = pcall(IsPlayerAceAllowed, source, ace)
    return ok and (allowed == true or allowed == 1)
end

local function aceFallbackKeys(source)
    local keys = {}
    if source == 0 then return { 'founder' } end
    if playerAceAllowed(source, 'group.owner') or playerAceAllowed(source, 'sk.owner') then keys[#keys + 1] = 'founder' end
    if playerAceAllowed(source, 'group.developer') or playerAceAllowed(source, 'sk.developer') then keys[#keys + 1] = 'developer' end
    if playerAceAllowed(source, 'group.admin') or playerAceAllowed(source, 'sk.admin') or playerAceAllowed(source, 'command') then keys[#keys + 1] = 'admin' end
    if playerAceAllowed(source, 'group.mod') or playerAceAllowed(source, 'sk.mod') then keys[#keys + 1] = 'moderator' end
    if playerAceAllowed(source, 'group.racing_organizer') or playerAceAllowed(source, 'sk.racing.organizer') then keys[#keys + 1] = 'racing_organizer' end
    if playerAceAllowed(source, 'streetkings.vipplusplus') or playerAceAllowed(source, 'streetkings.vip+++') or playerAceAllowed(source, 'group.vipelite') then keys[#keys + 1] = 'vip_3' end
    if playerAceAllowed(source, 'streetkings.vipplus') or playerAceAllowed(source, 'streetkings.vip++') or playerAceAllowed(source, 'group.vipplus') then keys[#keys + 1] = 'vip_2' end
    if playerAceAllowed(source, 'streetkings.vip') or playerAceAllowed(source, 'group.vip') then keys[#keys + 1] = 'vip_1' end
    return keys
end

local function getPlayerLevel(source)
    if SKSaves and SKSaves.read and SKSaves.hasActiveSave and SKSaves.hasActiveSave(source) then
        return tonumber(SKSaves.read(source, 'progression.level')) or 1
    end
    return 1
end

local function internalRacingRole(source)
    local level = getPlayerLevel(source)
    local best = nil
    for _, role in ipairs(sortedRoles()) do
        if (role.racingLevel or 0) > 0 then
            local minLevel = tonumber(role.minLevel) or 1
            local maxLevel = tonumber(role.maxLevel) or math.huge
            if level >= minLevel and level <= maxLevel and (not best or (role.racingLevel or 0) > (best.racingLevel or 0)) then
                best = role
            end
        end
    end
    return best or roleForKey('piloto') or roleForKey('pilot')
end

local function publicRole(role)
    role = type(role) == 'table' and role or {}
    return {
        key = role.key or 'none',
        label = role.label or '',
        tag = role.tag or role.label or '',
        color = role.color or '#9ca3af',
        icon = role.icon or 'fa-solid fa-road',
        priority = tonumber(role.priority) or 0,
        group = role.group,
        aceGroup = role.aceGroup,
        level = tonumber(role.staffLevel or role.vipLevel or role.racingLevel) or 0,
        permissions = permissionsMap(role.permissions),
    }
end

local function emptyStaff()
    return { enabled = false, key = 'none', label = '', level = 0, permissions = {} }
end

local function emptyVip()
    return { enabled = false, key = 'none', label = '', tag = '', color = '#9ca3af', icon = 'fa-solid fa-road', level = 0, permissions = {} }
end

local function normalRacing(role)
    role = role or roleForKey('piloto') or roleForKey('pilot') or {}
    return {
        enabled = true,
        key = role.key or 'piloto',
        label = role.label or 'Piloto',
        tag = role.tag or role.label or 'Piloto',
        color = role.color or '#9ca3af',
        icon = role.icon or 'fa-solid fa-road',
        level = tonumber(role.racingLevel) or 1,
        permissions = permissionsMap(role.permissions),
    }
end

local function buildData(source, member, reason)
    local discordId = getDiscordId(source)
    local owned = {}
    if type(member) == 'table' and type(member.roles) == 'table' then
        for _, roleId in ipairs(member.roles) do
            owned[tostring(roleId)] = true
        end
    end

    local matched = {}
    for _, role in ipairs(sortedRoles()) do
        if ownsDiscordRole(owned, role) then matched[#matched + 1] = role end
    end

    for _, key in ipairs(aceFallbackKeys(source)) do
        local role = roleForKey(key)
        if role then matched[#matched + 1] = role end
    end

    local racingRole = internalRacingRole(source)
    if racingRole then matched[#matched + 1] = racingRole end

    local permissions = { user = true }
    local staffRole = nil
    local vipRole = nil
    local bestRacing = racingRole
    for _, role in ipairs(matched) do
        mergePermissions(permissions, role.permissions)
        if (role.staffLevel or 0) > 0 and (not staffRole or (role.staffLevel or 0) > (staffRole.staffLevel or 0)) then
            staffRole = role
        end
        if (role.vipLevel or 0) > 0 and (not vipRole or (role.vipLevel or 0) > (vipRole.vipLevel or 0)) then
            vipRole = role
        end
        if (role.racingLevel or 0) > 0 and (not bestRacing or (role.racingLevel or 0) > (bestRacing.racingLevel or 0)) then
            bestRacing = role
        end
    end

    local staff = emptyStaff()
    if staffRole then
        staff = publicRole(staffRole)
        staff.enabled = true
        staff.level = tonumber(staffRole.staffLevel) or 0
    end

    local vip = emptyVip()
    if vipRole then
        vip = publicRole(vipRole)
        vip.enabled = true
        vip.level = tonumber(vipRole.vipLevel) or 0
        vip.legacyTier = vipRole.legacyTier
    end

    local racing = normalRacing(bestRacing)
    mergePermissions(permissions, racing.permissions)

    return {
        source = source,
        identifier = getIdentifier(source, 'license') or ('player:' .. tostring(source)),
        discordId = discordId,
        staff = staff,
        vip = vip,
        racing = racing,
        permissions = permissions,
        reason = reason or 'ok',
        refreshedAt = os.time(),
        refreshedAtMs = nowMs(),
    }
end

local function roleChanged(previous, nextData, key)
    local before = previous and previous[key] or {}
    local after = nextData and nextData[key] or {}
    return (before.key or 'none') ~= (after.key or 'none') or (before.level or 0) ~= (after.level or 0)
end

local function principalNames(data)
    local names = { ('player.%d'):format(data.source) }
    if type(data.discordId) == 'string' and data.discordId ~= '' then
        names[#names + 1] = 'identifier.discord:' .. data.discordId
    end
    return names
end

local function applyAcePrincipals(previous, data)
    local old = previous and previous._principals or {}
    for _, item in ipairs(old) do
        ExecuteCommand(('remove_principal %s %s'):format(item.principal, item.group))
    end

    local groups = {}
    if data.staff and data.staff.aceGroup then groups[data.staff.aceGroup] = true end
    if data.vip and data.vip.aceGroup then groups[data.vip.aceGroup] = true end
    if data.racing and data.racing.aceGroup then groups[data.racing.aceGroup] = true end
    if not next(groups) then groups['group.user'] = true end

    local applied = {}
    for _, principal in ipairs(principalNames(data)) do
        for group in pairs(groups) do
            ExecuteCommand(('add_principal %s %s'):format(principal, group))
            applied[#applied + 1] = { principal = principal, group = group }
        end
    end
    data._principals = applied
end

local function clientData(data)
    local copy = shallowCopy(data or {})
    copy._principals = nil
    return copy
end

local function emitUpdates(source, data, previous)
    TriggerEvent('sk_permissions:server:refreshed', source, data, previous)
    TriggerClientEvent('sk_permissions:client:updated', source, clientData(data))

    if roleChanged(previous, data, 'staff') then
        TriggerEvent('sk_staff:server:updated', source, data.staff, previous and previous.staff)
        TriggerClientEvent('sk_staff:client:updated', source, data.staff)
    end
    if roleChanged(previous, data, 'vip') then
        TriggerEvent('sk_vip:server:updated', source, data.vip, previous and previous.vip)
        TriggerClientEvent('sk_vip:client:updated', source, data.vip)
    end
    if roleChanged(previous, data, 'racing') then
        TriggerEvent('sk_racing:server:updated', source, data.racing, previous and previous.racing)
        TriggerClientEvent('sk_racing:client:updated', source, data.racing)
    end
end

function SKPermissions.RefreshPlayerDiscordPermissions(source, force)
    source = tonumber(source)
    if not source then return nil end
    if source == 0 then
        local data = buildData(0, nil, 'console')
        SKPermissions.cache[0] = data
        return data
    end

    local cached = SKPermissions.cache[source]
    if cached and not force and (nowMs() - (cached.refreshedAtMs or 0)) < refreshMs() then
        return cached
    end

    local previous = cached
    local discordId = getDiscordId(source)
    local member, reason = nil, 'discord_missing'
    if discordId then
        member, reason = fetchGuildMember(discordId)
    end

    if not member and cached then
        cached.reason = reason or 'discord_failed_cached'
        cached.refreshedAtMs = nowMs()
        cached.refreshedAt = os.time()
        return cached
    end

    local data = buildData(source, member, member and 'discord_synced' or (reason or 'normal'))
    data.nametagSettings = SKPermissions.GetNametagSettings(source)
    applyAcePrincipals(previous, data)
    SKPermissions.cache[source] = data
    emitUpdates(source, data, previous)
    return data
end

function SKPermissions.GetPlayerRoleData(source)
    return SKPermissions.RefreshPlayerDiscordPermissions(source, false)
end

function SKPermissions.GetPlayerPermissions(source)
    local data = SKPermissions.GetPlayerRoleData(source)
    return data and data.permissions or { user = true }
end

function SKPermissions.HasPermission(source, permission)
    if tonumber(source) == 0 then return true end
    permission = tostring(permission or '')
    if permission == '' then return false end
    local perms = SKPermissions.GetPlayerPermissions(source)
    if perms[permission] or perms['admin.all'] or perms['owner'] then return true end
    local prefix = permission:match('^([^%.]+)%.')
    return prefix and perms[prefix .. '.all'] == true or false
end

local function roleEnabled(source, roleKey)
    local data = SKPermissions.GetPlayerRoleData(source)
    local role = data and data[roleKey]
    return role and role.enabled == true or false
end

function SKPermissions.IsOwner(source) return SKPermissions.HasPermission(source, 'owner') end
function SKPermissions.IsDeveloper(source) return SKPermissions.HasPermission(source, 'developer') end
function SKPermissions.IsAdmin(source) return SKPermissions.HasPermission(source, 'admin') or SKPermissions.HasPermission(source, 'admin.menu') end
function SKPermissions.IsModerator(source) return SKPermissions.HasPermission(source, 'mod') end
function SKPermissions.IsStaff(source) return roleEnabled(source, 'staff') or SKPermissions.IsOwner(source) end
function SKPermissions.HasStaffPermission(source, permission) return SKPermissions.HasPermission(source, permission) end

function SKPermissions.GetStaffLevel(source)
    local data = SKPermissions.GetPlayerRoleData(source)
    return data and data.staff and tonumber(data.staff.level) or 0
end

function SKPermissions.GetVip(source)
    local data = SKPermissions.GetPlayerRoleData(source)
    return data and data.vip or emptyVip()
end

function SKPermissions.HasVip(source) return SKPermissions.GetVip(source).enabled == true end

function SKPermissions.GetVipLevel(source)
    return tonumber(SKPermissions.GetVip(source).level) or 0
end

function SKPermissions.HasVipTier(source, tierKey)
    local vip = SKPermissions.GetVip(source)
    local role = roleForKey(tostring(tierKey or ''))
    if not role then
        local legacy = { vip = 1, vipplus = 2, vipplusplus = 3 }
        return SKPermissions.GetVipLevel(source) >= (legacy[tostring(tierKey or '')] or 0)
    end
    return SKPermissions.GetVipLevel(source) >= (tonumber(role.vipLevel) or 0)
end

function SKPermissions.HasVipPermission(source, permission)
    return SKPermissions.HasPermission(source, permission)
end

function SKPermissions.GetRacingRole(source)
    local data = SKPermissions.GetPlayerRoleData(source)
    return data and data.racing or normalRacing()
end

function SKPermissions.IsRacingOrganizer(source) return SKPermissions.HasPermission(source, 'racing.organizer') end
function SKPermissions.IsPilot(source) return SKPermissions.HasPermission(source, 'racing.pilot') end
function SKPermissions.IsPilotPro(source) return SKPermissions.HasPermission(source, 'racing.pilot_pro') end
function SKPermissions.HasRacingPermission(source, permission) return SKPermissions.HasPermission(source, permission) end

function SKPermissions.GetNametagSettings(source)
    local settings = shallowCopy(DEFAULT_NAMETAG_SETTINGS)
    if SKSaves and SKSaves.hasActiveSave and SKSaves.hasActiveSave(source) then
        local stored = SKSaves.read(source, 'profile.nametagSettings')
        if type(stored) == 'table' then
            for key in pairs(settings) do
                if stored[key] ~= nil then settings[key] = stored[key] end
            end
        end
    end
    return settings
end

local function saveNametagSettings(source, settings)
    if not SKSaves or not SKSaves.hasActiveSave or not SKSaves.hasActiveSave(source) then return false end
    return SKSaves.write(source, 'profile.nametagSettings', settings)
end

function SKPermissions.SetHideOwnNametag(source, state)
    local settings = SKPermissions.GetNametagSettings(source)
    settings.hideOwnNametag = state == true
    saveNametagSettings(source, settings)
    TriggerEvent('sk_nametag:server:settingsUpdated', source, settings)
    TriggerClientEvent('sk_nametag:client:settingsUpdated', source, settings)
    return true
end

function SKPermissions.SetShowOtherNametags(source, state)
    local settings = SKPermissions.GetNametagSettings(source)
    settings.showOtherNametags = state ~= false
    saveNametagSettings(source, settings)
    TriggerEvent('sk_nametag:server:settingsUpdated', source, settings)
    TriggerClientEvent('sk_nametag:client:settingsUpdated', source, settings)
    return true
end

function SKPermissions.GetPlayerNametagData(source)
    local data = SKPermissions.GetPlayerRoleData(source)
    return {
        serverId = source,
        name = GetPlayerName(source) or ('Player %s'):format(source),
        staff = data and data.staff or emptyStaff(),
        vip = data and data.vip or emptyVip(),
        racing = data and data.racing or normalRacing(),
        hiddenNametag = SKPermissions.GetNametagSettings(source).hideOwnNametag == true,
        nametagSettings = SKPermissions.GetNametagSettings(source),
    }
end

function SKPermissions.CanUseVipShop(source) return SKPermissions.HasPermission(source, 'vip.shop') end
function SKPermissions.CanUseVipVehicleShop(source) return SKPermissions.HasPermission(source, 'vip.vehicle_shop') end
function SKPermissions.CanUseVipWorkshop(source) return SKPermissions.HasPermission(source, 'vip.workshop') end
function SKPermissions.CanUseVipTuning(source) return SKPermissions.HasPermission(source, 'vip.tuning') end
function SKPermissions.CanUseVipRepairDiscount(source) return SKPermissions.HasPermission(source, 'vip.repair_discount') end
function SKPermissions.CanUseVipCosmetics(source) return SKPermissions.HasPermission(source, 'vip.cosmetics') end
function SKPermissions.CanUseAdminMenu(source) return SKPermissions.HasPermission(source, 'admin.menu') end
function SKPermissions.CanKickPlayers(source) return SKPermissions.HasPermission(source, 'admin.kick') end
function SKPermissions.CanBanPlayers(source) return SKPermissions.HasPermission(source, 'admin.ban') end
function SKPermissions.CanUseAdminVehicle(source) return SKPermissions.HasPermission(source, 'admin.vehicle') end
function SKPermissions.CanSpectate(source) return SKPermissions.HasPermission(source, 'admin.spectate') end
function SKPermissions.CanTeleport(source) return SKPermissions.HasPermission(source, 'admin.teleport') end
function SKPermissions.CanManageRacingEvents(source) return SKPermissions.HasPermission(source, 'racing.manage') end
function SKPermissions.CanCreateRacingEvents(source) return SKPermissions.HasPermission(source, 'racing.create_event') end
function SKPermissions.CanManageLeaderboards(source) return SKPermissions.HasPermission(source, 'racing.manage_leaderboards') end

RegisterNetEvent('sk_permissions:server:requestRefresh', function()
    SKPermissions.RefreshPlayerDiscordPermissions(source --[[@as integer]], true)
end)

RegisterNetEvent('sk_permissions:server:setNametagSettings', function(settings)
    local src = source --[[@as integer]]
    if type(settings) ~= 'table' then return end
    if settings.hideOwnNametag ~= nil then SKPermissions.SetHideOwnNametag(src, settings.hideOwnNametag == true) end
    if settings.showOtherNametags ~= nil then SKPermissions.SetShowOtherNametags(src, settings.showOtherNametags ~= false) end
end)

RegisterCommand('refreshperms', function(source, args)
    if source ~= 0 and not SKPermissions.HasPermission(source, 'admin.menu') then return end
    local target = tonumber(args and args[1]) or source
    if source == 0 and (not target or target <= 0) then
        for _, player in ipairs(GetPlayers()) do
            SKPermissions.RefreshPlayerDiscordPermissions(tonumber(player), true)
        end
        return
    end
    if target and GetPlayerName(target) then
        SKPermissions.RefreshPlayerDiscordPermissions(target, true)
    end
end, false)

AddEventHandler('playerJoining', function()
    local src = source --[[@as integer]]
    CreateThread(function()
        Wait(2000)
        if GetPlayerName(src) then
            SKPermissions.RefreshPlayerDiscordPermissions(src, false)
        end
    end)
end)

AddEventHandler('streetkings:freeroam:enter', function()
    SKPermissions.RefreshPlayerDiscordPermissions(source --[[@as integer]], false)
end)

AddEventHandler('streetkings:progression:playerLevelChanged', function(src)
    if src and GetPlayerName(src) then
        SKPermissions.RefreshPlayerDiscordPermissions(src, true)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    local cached = SKPermissions.cache[src]
    if cached and type(cached._principals) == 'table' then
        for _, item in ipairs(cached._principals) do
            ExecuteCommand(('remove_principal %s %s'):format(item.principal, item.group))
        end
    end
    SKPermissions.cache[src] = nil
end)

CreateThread(function()
    while true do
        Wait(math.max(60000, refreshMs()))
        for _, player in ipairs(GetPlayers()) do
            SKPermissions.RefreshPlayerDiscordPermissions(tonumber(player), true)
        end
    end
end)

exports('GetPlayerRoleData', SKPermissions.GetPlayerRoleData)
exports('GetPlayerPermissions', SKPermissions.GetPlayerPermissions)
exports('HasPermission', SKPermissions.HasPermission)
exports('IsOwner', SKPermissions.IsOwner)
exports('IsDeveloper', SKPermissions.IsDeveloper)
exports('IsAdmin', SKPermissions.IsAdmin)
exports('IsModerator', SKPermissions.IsModerator)
exports('IsStaff', SKPermissions.IsStaff)
exports('HasStaffPermission', SKPermissions.HasStaffPermission)
exports('GetStaffLevel', SKPermissions.GetStaffLevel)
exports('GetVipLevel', SKPermissions.GetVipLevel)
exports('HasVipTier', SKPermissions.HasVipTier)
exports('GetRacingRole', SKPermissions.GetRacingRole)
exports('IsRacingOrganizer', SKPermissions.IsRacingOrganizer)
exports('IsPilot', SKPermissions.IsPilot)
exports('IsPilotPro', SKPermissions.IsPilotPro)
exports('HasRacingPermission', SKPermissions.HasRacingPermission)
exports('RefreshPlayerDiscordPermissions', SKPermissions.RefreshPlayerDiscordPermissions)
exports('GetPlayerNametagData', SKPermissions.GetPlayerNametagData)
exports('SetHideOwnNametag', SKPermissions.SetHideOwnNametag)
exports('SetShowOtherNametags', SKPermissions.SetShowOtherNametags)
exports('GetNametagSettings', SKPermissions.GetNametagSettings)
exports('CanUseVipShop', SKPermissions.CanUseVipShop)
exports('CanUseVipVehicleShop', SKPermissions.CanUseVipVehicleShop)
exports('CanUseVipWorkshop', SKPermissions.CanUseVipWorkshop)
exports('CanUseVipTuning', SKPermissions.CanUseVipTuning)
exports('CanUseVipRepairDiscount', SKPermissions.CanUseVipRepairDiscount)
exports('CanUseVipCosmetics', SKPermissions.CanUseVipCosmetics)
exports('CanUseAdminMenu', SKPermissions.CanUseAdminMenu)
exports('CanKickPlayers', SKPermissions.CanKickPlayers)
exports('CanBanPlayers', SKPermissions.CanBanPlayers)
exports('CanUseAdminVehicle', SKPermissions.CanUseAdminVehicle)
exports('CanSpectate', SKPermissions.CanSpectate)
exports('CanTeleport', SKPermissions.CanTeleport)
exports('CanManageRacingEvents', SKPermissions.CanManageRacingEvents)
exports('CanCreateRacingEvents', SKPermissions.CanCreateRacingEvents)
exports('CanManageLeaderboards', SKPermissions.CanManageLeaderboards)
