SKDiscord = SKDiscord or {}

local avatarCache = {}

local function discordIdFromSource(source)
    local identifier = GetPlayerIdentifierByType(source --[[@as string]], 'discord')
    return type(identifier) == 'string' and identifier:match('^discord:(%d+)$') or nil
end

local function defaultAvatarUrl(id)
    local lastDigit = tonumber(tostring(id or '0'):sub(-1)) or 0
    return ('https://cdn.discordapp.com/embed/avatars/%d.png'):format(lastDigit % 5)
end

local function configuredEndpointUrl(id)
    local endpoint = SKConfig and SKConfig.DiscordAvatarEndpoint or ''
    if type(endpoint) ~= 'string' or endpoint == '' then return nil end
    return endpoint:gsub('{id}', id)
end

local function getBotToken()
    local convarToken = GetConvar('sk_discord_bot_token', '')
    if type(convarToken) == 'string' and convarToken ~= '' then return convarToken end
    convarToken = GetConvar('streetkings_discord_bot_token', '')
    if type(convarToken) == 'string' and convarToken ~= '' then return convarToken end
    return ''
end

local function avatarUrlFromUser(id, user)
    if type(user) ~= 'table' then return nil end
    local avatar = user.avatar
    if type(avatar) ~= 'string' or avatar == '' then return defaultAvatarUrl(id) end
    local ext = avatar:sub(1, 2) == 'a_' and 'gif' or 'png'
    return ('https://cdn.discordapp.com/avatars/%s/%s.%s?size=256'):format(id, avatar, ext)
end

local function fetchDiscordUserAvatar(id)
    local token = getBotToken()
    if token == '' then return nil end

    local p = promise.new()
    PerformHttpRequest(('https://discord.com/api/v10/users/%s'):format(id), function(status, body)
        if status ~= 200 or type(body) ~= 'string' or body == '' then
            p:resolve(nil)
            return
        end

        local ok, user = pcall(json.decode, body)
        if not ok then
            p:resolve(nil)
            return
        end

        p:resolve(avatarUrlFromUser(id, user))
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. token,
        ['Content-Type'] = 'application/json',
    })

    return Citizen.Await(p)
end

function SKDiscord.GetDiscordId(source)
    return discordIdFromSource(source)
end

function SKDiscord.GetAvatarUrl(source)
    local id = discordIdFromSource(source)
    if not id then return '' end

    local cached = avatarCache[id]
    if cached then return cached end

    local endpointUrl = configuredEndpointUrl(id)
    if endpointUrl then
        avatarCache[id] = endpointUrl
        return endpointUrl
    end

    local url = fetchDiscordUserAvatar(id) or defaultAvatarUrl(id)
    avatarCache[id] = url
    return url
end

exports('GetDiscordAvatarUrl', function(source)
    return SKDiscord.GetAvatarUrl(source)
end)
