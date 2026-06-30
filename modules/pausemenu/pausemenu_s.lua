if SKConfig.DisablePauseMenu then return end

local function roleBadge(role, fallbackIcon)
    if type(role) ~= 'table' or role.enabled ~= true then return nil end
    local label = tostring(role.label or role.tag or role.key or '')
    if label == '' then return nil end
    return {
        key = role.key or label,
        label = label,
        color = role.color or '#ff0a73',
        icon = role.icon or fallbackIcon or 'fa-solid fa-id-badge',
    }
end

lib.callback.register('streetkings:pausemenu:getProfile', function(source)
    local doc = SKSaves and SKSaves.getDocument and SKSaves.getDocument(source) or nil
    local profile = doc and doc.profile or {}
    local roles = SKPermissions and SKPermissions.GetPlayerRoleData and SKPermissions.GetPlayerRoleData(source) or nil
    local avatar = SKDiscord and SKDiscord.GetAvatarUrl and SKDiscord.GetAvatarUrl(source) or ''
    local discordId = SKDiscord and SKDiscord.GetDiscordId and SKDiscord.GetDiscordId(source) or ''

    local badges = {}
    local vipBadge = roles and roleBadge(roles.vip, 'fa-solid fa-gem') or nil
    local staffBadge = roles and roleBadge(roles.staff, 'fa-solid fa-shield-halved') or nil
    local racingBadge = roles and roleBadge(roles.racing, 'fa-solid fa-flag-checkered') or nil
    if vipBadge then badges[#badges + 1] = vipBadge end
    if staffBadge then badges[#badges + 1] = staffBadge end
    if racingBadge then badges[#badges + 1] = racingBadge end

    local alias = profile and profile.alias or ''
    if type(alias) ~= 'string' then alias = '' end

    return {
        alias = alias,
        discordId = discordId,
        avatarUrl = avatar,
        serverName = GetConvar('sv_hostname', 'Five Horizon'),
        badges = badges,
        rank = vipBadge and vipBadge.label or (racingBadge and racingBadge.label or 'Piloto'),
        vip = roles and roles.vip or nil,
        staff = roles and roles.staff or nil,
        racing = roles and roles.racing or nil,
        activeSave = doc ~= nil,
    }
end)

RegisterNetEvent('streetkings:pausemenu:exitGame', function()
    local src = source
    DropPlayer(src, 'Thank you for playing Street Kings!')
end)
