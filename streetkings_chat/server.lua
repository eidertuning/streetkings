local Config = SKChatConfig or {}
local CORE = Config.CoreResource or 'streetkings'
local MAX_MESSAGE_LENGTH = tonumber(Config.MaxMessageLength) or 220

local function callCore(fn, ...)
    if GetResourceState(CORE) ~= 'started' then return nil end
    local args = { ... }
    local ok, result = pcall(function()
        if fn == 'GetPlayerGameState' then
            return exports[CORE]:GetPlayerGameState(args[1])
        end
        if fn == 'GetPlayerProfile' then
            return exports[CORE]:GetPlayerProfile(args[1])
        end
        if fn == 'GetPlayerRoleData' then
            return exports[CORE]:GetPlayerRoleData(args[1])
        end
        return nil
    end)
    return ok and result or nil
end

local function isFreeroam(source)
    return callCore('GetPlayerGameState', source) == (Config.AllowedState or 'freeroam')
end

local function cleanMessage(message)
    message = tostring(message or '')
    message = message:gsub('[\r\n\t]', ' '):gsub('%s+', ' ')
    message = message:gsub('^%s+', ''):gsub('%s+$', '')
    if #message > MAX_MESSAGE_LENGTH then
        message = message:sub(1, MAX_MESSAGE_LENGTH)
    end
    return message
end

local function playerAlias(source)
    local profile = callCore('GetPlayerProfile', source)
    if type(profile) == 'table' and type(profile.alias) == 'string' and profile.alias ~= '' then
        return profile.alias
    end
    return GetPlayerName(source) or ('Jugador ' .. tostring(source))
end

local function roleBadge(source)
    local data = callCore('GetPlayerRoleData', source)
    if type(data) ~= 'table' then
        return { label = 'Piloto', tone = 'racing' }
    end

    if data.staff and data.staff.enabled then
        return { label = data.staff.label or 'Staff', tone = 'staff' }
    end
    if data.vip and data.vip.enabled then
        return { label = data.vip.label or 'VIP', tone = 'vip' }
    end
    if data.racing and data.racing.label and data.racing.label ~= '' then
        return { label = data.racing.label, tone = 'racing' }
    end
    return { label = 'Piloto', tone = 'racing' }
end

local function makePayload(source, text, scope, target)
    local badge = roleBadge(source)
    return {
        scope = scope or 'global',
        source = source,
        target = target,
        author = playerAlias(source),
        id = source,
        tag = badge.label,
        tone = badge.tone,
        text = text,
        timestamp = os.time(),
    }
end

local function sendSystem(source, message)
    TriggerClientEvent('skchat:system', source, message)
end

local function freeroamPlayers()
    local list = {}
    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)
        if target and isFreeroam(target) then
            list[#list + 1] = target
        end
    end
    return list
end

local function broadcastGlobal(source, message)
    local payload = makePayload(source, message, 'global')
    for _, target in ipairs(freeroamPlayers()) do
        TriggerClientEvent('skchat:push', target, payload)
    end
end

local function sendPrivate(source, target, message)
    if message == '' then
        sendSystem(source, 'Escribe un mensaje privado.')
        return
    end
    if not target or target <= 0 or not GetPlayerName(target) then
        sendSystem(source, 'Ese jugador no esta conectado.')
        return
    end
    if not isFreeroam(target) then
        sendSystem(source, 'Ese jugador no esta en freeroam.')
        return
    end

    local toPayload = makePayload(source, message, 'private_in', target)
    local fromPayload = makePayload(source, message, 'private_out', target)
    fromPayload.targetName = playerAlias(target)

    TriggerClientEvent('skchat:push', target, toPayload)
    TriggerClientEvent('skchat:push', source, fromPayload)
end

local function handleMessage(source, rawMessage)
    if source <= 0 then return end
    if not isFreeroam(source) then
        sendSystem(source, 'El chat solo esta disponible en freeroam.')
        return
    end

    local message = cleanMessage(rawMessage)
    if message == '' then return end

    local targetText, privateText = message:match('^/mp%s+(%d+)%s+(.+)$')
    if targetText and privateText then
        sendPrivate(source, tonumber(targetText), cleanMessage(privateText))
        return
    end

    if message:sub(1, 1) == '/' then
        sendSystem(source, 'Comando no reconocido. Usa /mp id mensaje para privado.')
        return
    end

    broadcastGlobal(source, message)
end

RegisterNetEvent('skchat:submit', function(message)
    handleMessage(source --[[@as integer]], message)
end)

RegisterCommand(Config.PrivateCommand or 'mp', function(source, args)
    if source <= 0 then return end
    local target = tonumber(args[1] or '')
    table.remove(args, 1)
    sendPrivate(source, target, cleanMessage(table.concat(args, ' ')))
end, false)
