SKLogs = {}

local MAX_FIELD_VALUE = 1024
local MAX_DESCRIPTION = 3900

local function getConfig()
    return SKLogsConfig or {}
end

local function cleanText(value, fallback)
    local text = value == nil and (fallback or '') or tostring(value)
    text = text:gsub('`', "'")
    if text == '' then return fallback or '-' end
    return text
end

local function trim(text, maxLength)
    text = cleanText(text)
    if #text <= maxLength then return text end
    return text:sub(1, math.max(1, maxLength - 3)) .. '...'
end

local function money(value)
    value = math.floor(tonumber(value) or 0)
    local sign = value < 0 and '-' or ''
    local digits = tostring(math.abs(value))
    local formatted = digits:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return sign .. '$' .. formatted
end

local function duration(ms)
    ms = math.max(0, math.floor(tonumber(ms) or 0))
    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local millis = ms % 1000
    return ('%02d:%02d.%03d'):format(minutes, seconds, millis)
end

local function yesNo(value)
    return value and 'Si' or 'No'
end

local function getIdentifiers(source)
    local identifiers = {}
    if type(source) ~= 'number' or source <= 0 then return identifiers end

    for _, identifier in ipairs(GetPlayerIdentifiers(source) or {}) do
        local key = identifier:match('^([^:]+):')
        if key then identifiers[key] = identifier end
    end

    return identifiers
end

local function playerSummary(source)
    if type(source) ~= 'number' or source <= 0 then
        return 'Consola / sistema'
    end

    local name = GetPlayerName(source) or 'Desconocido'
    local alias = nil
    if SKSaves and SKSaves.hasActiveSave and SKSaves.hasActiveSave(source) then
        alias = SKSaves.read(source, 'profile.alias')
    end
    if type(alias) ~= 'string' or alias == '' then alias = name end

    return ('%s | ID %d | %s'):format(alias, source, name)
end

local function identifierSummary(source)
    local cfg = getConfig()
    if cfg.includeIdentifiers == false then return nil end

    local identifiers = getIdentifiers(source)
    local lines = {}
    for _, key in ipairs({ 'license', 'discord', 'fivem', 'steam' }) do
        if identifiers[key] then lines[#lines + 1] = identifiers[key] end
    end

    if #lines == 0 then return nil end
    return table.concat(lines, '\n')
end

local function addField(fields, name, value, inline)
    if value == nil or value == '' then return end
    fields[#fields + 1] = {
        name = trim(name, 256),
        value = trim(value, MAX_FIELD_VALUE),
        inline = inline == true,
    }
end

local function eventName(eventId)
    local event = type(eventId) == 'string' and SKEvents and SKEvents[eventId] or nil
    return event and (event.name or event.title or event.id) or eventId or 'Desconocido'
end

local function scoreText(scoreType, score)
    if scoreType == 'time' then return duration(score) end
    if scoreType == 'speed' then return ('%d mph'):format(math.floor(tonumber(score) or 0)) end
    return tostring(math.floor(tonumber(score) or 0))
end

local function rewardText(reward, cash)
    local parts = {}
    if tonumber(cash) and tonumber(cash) ~= 0 then
        parts[#parts + 1] = money(cash)
    end
    if type(reward) == 'table' then
        if type(reward.summary) == 'string' and reward.summary ~= '' then
            parts[#parts + 1] = reward.summary
        end
        if reward.player and tonumber(reward.player.xpGained) and reward.player.xpGained > 0 then
            parts[#parts + 1] = ('Jugador XP +%d'):format(reward.player.xpGained)
        end
        if reward.vehicle and tonumber(reward.vehicle.xpGained) and reward.vehicle.xpGained > 0 then
            parts[#parts + 1] = ('Vehiculo XP +%d'):format(reward.vehicle.xpGained)
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, '\n')
end

local function buildGenericFields(data)
    local fields = {}
    if type(data) ~= 'table' then return fields end
    for key, value in pairs(data) do
        if type(value) ~= 'table' then
            addField(fields, key, tostring(value), true)
        end
    end
    return fields
end

local builders = {}

builders.activitySubmitted = function(data)
    local fields = {}
    addField(fields, 'Jugador', playerSummary(data.source), false)
    addField(fields, 'Evento', ('%s (`%s`)'):format(eventName(data.eventId), cleanText(data.eventId)), true)
    addField(fields, 'Tipo', cleanText(data.scoreType), true)
    addField(fields, 'Resultado', scoreText(data.scoreType, data.scoreValue), true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleModel, 'Sin modelo'), true)
    addField(fields, 'Clase', cleanText(data.vehicleClass, '-'), true)
    addField(fields, 'Diario', yesNo(data.daily), true)
    addField(fields, 'Meta cumplida', yesNo(data.goalMet), true)
    addField(fields, 'Recompensa', rewardText(data.reward, data.cash), false)
    addField(fields, 'Identificadores', identifierSummary(data.source), false)

    return {
        title = 'Resultado de carrera / actividad',
        description = ('%s envio un resultado valido.'):format(playerSummary(data.source)),
        colorKey = 'success',
        fields = fields,
    }
end

builders.activityRejected = function(data)
    local fields = {}
    addField(fields, 'Jugador', playerSummary(data.source), false)
    addField(fields, 'Motivo', cleanText(data.reason), true)
    addField(fields, 'Evento', cleanText(data.eventId), true)
    addField(fields, 'Puntuacion enviada', cleanText(data.scoreValue), true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleModel), true)
    addField(fields, 'Identificadores', identifierSummary(data.source), false)

    return {
        title = 'Resultado rechazado',
        description = 'Una puntuacion fue bloqueada por validacion del servidor.',
        colorKey = 'warning',
        fields = fields,
    }
end

builders.npcRace = function(data)
    local fields = {}
    addField(fields, 'Jugador', playerSummary(data.source), false)
    addField(fields, 'Resultado', data.won and 'Victoria' or 'Derrota', true)
    addField(fields, 'Tiempo', data.elapsedMs and duration(data.elapsedMs) or nil, true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleModel), true)
    addField(fields, 'Clase GTA', cleanText(data.vehicleClass), true)
    addField(fields, 'Dinero', data.cash and money(data.cash) or nil, true)
    addField(fields, 'Recompensa', rewardText(data.reward, nil), false)
    addField(fields, 'Identificadores', identifierSummary(data.source), false)

    return {
        title = 'Reto callejero NPC',
        description = data.won and 'El jugador gano una persecucion callejera.' or 'El jugador perdio una persecucion callejera.',
        colorKey = data.won and 'success' or 'warning',
        fields = fields,
    }
end

builders.policeEscape = function(data)
    local fields = {}
    addField(fields, 'Jugador', playerSummary(data.source), false)
    addField(fields, 'Resultado', 'Escapo de la policia', true)
    addField(fields, 'Identificadores', identifierSummary(data.source), false)

    return {
        title = 'Persecucion completada',
        description = 'El jugador escapo de una persecucion policial.',
        colorKey = 'success',
        fields = fields,
    }
end

builders.policeBust = function(data)
    local fields = {}
    addField(fields, 'Jugador', playerSummary(data.source), false)
    addField(fields, 'Multa', money(data.deducted or 0), true)
    addField(fields, 'Efectivo antes', money(data.beforeCash or 0), true)
    addField(fields, 'Efectivo despues', money(data.afterCash or 0), true)
    addField(fields, 'Identificadores', identifierSummary(data.source), false)

    return {
        title = 'Jugador arrestado',
        description = 'Se aplico una multa policial.',
        colorKey = 'error',
        fields = fields,
    }
end

builders.dealershipPurchase = function(data)
    local fields = {}
    addField(fields, 'Jugador', playerSummary(data.source), false)
    addField(fields, 'Concesionario', cleanText(data.dealershipId), true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleName or data.vehicleModel), true)
    addField(fields, 'Modelo', cleanText(data.vehicleModel), true)
    addField(fields, 'Precio', money(data.price or 0), true)
    addField(fields, 'Balance', money(data.balance or 0), true)
    addField(fields, 'VIP requerido', cleanText(data.requiredVip, 'No'), true)
    addField(fields, 'Identificadores', identifierSummary(data.source), false)

    return {
        title = 'Compra en concesionario',
        description = 'Un jugador compro un vehiculo.',
        colorKey = 'success',
        fields = fields,
    }
end

builders.vipChanged = function(data)
    local fields = {}
    addField(fields, 'Admin', playerSummary(data.source), false)
    addField(fields, 'Jugador', playerSummary(data.target), false)
    addField(fields, 'VIP anterior', cleanText(data.oldTier, 'none'), true)
    addField(fields, 'VIP nuevo', cleanText(data.newTier, 'none'), true)
    addField(fields, 'Identificadores jugador', identifierSummary(data.target), false)

    return {
        title = 'VIP actualizado',
        description = 'Un administrador cambio el nivel VIP de un jugador.',
        colorKey = 'admin',
        fields = fields,
    }
end

builders.adminCommand = function(data)
    local fields = {}
    addField(fields, 'Admin', playerSummary(data.source), false)
    addField(fields, 'Comando', '/' .. cleanText(data.command), true)
    addField(fields, 'Objetivo', data.target and playerSummary(data.target) or nil, false)
    addField(fields, 'Detalles', cleanText(data.details), false)
    addField(fields, 'Identificadores admin', identifierSummary(data.source), false)

    return {
        title = 'Comando administrativo',
        description = 'Se ejecuto una accion administrativa.',
        colorKey = 'admin',
        fields = fields,
    }
end

local function resolveChannels(kind, preferred)
    if preferred then
        if type(preferred) == 'table' then return preferred end
        return { preferred }
    end

    local route = (getConfig().routing or {})[kind]
    if type(route) == 'table' then return route end
    if type(route) == 'string' then return { route } end
    return { 'admin' }
end

local function getWebhook(channel)
    local channelConfig = (getConfig().channels or {})[channel]
    if type(channelConfig) ~= 'table' or channelConfig.enabled == false then return nil end
    return type(channelConfig.webhook) == 'string' and channelConfig.webhook ~= '' and channelConfig.webhook or nil
end

local function sendEmbed(channel, embed)
    local cfg = getConfig()
    if cfg.enabled == false then return end

    local webhook = getWebhook(channel)
    if not webhook then return end

    local payload = {
        username = cleanText(cfg.username, 'StreetKings Logs'),
        embeds = { embed },
    }

    if type(cfg.avatarUrl) == 'string' and cfg.avatarUrl ~= '' then
        payload.avatar_url = cfg.avatarUrl
    end

    PerformHttpRequest(webhook, function(status)
        if status < 200 or status >= 300 then
            print(('[SK:Logs] Discord webhook failed | channel=%s | status=%s'):format(channel, tostring(status)))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

function SKLogs.Emit(kind, data, preferredChannel)
    if type(kind) ~= 'string' or kind == '' then return end

    data = type(data) == 'table' and data or {}
    local built = builders[kind] and builders[kind](data) or {
        title = kind,
        description = 'Evento StreetKings',
        colorKey = 'admin',
        fields = buildGenericFields(data),
    }

    local cfg = getConfig()
    local colorKey = built.colorKey or 'admin'
    local color = (cfg.colors or {})[colorKey] or (cfg.colors or {}).admin or 16763904
    local embed = {
        title = trim(built.title or kind, 256),
        description = trim(built.description or '', MAX_DESCRIPTION),
        color = color,
        fields = built.fields or {},
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = {
            text = cleanText(cfg.footer, 'StreetKings'),
        },
    }

    for _, channel in ipairs(resolveChannels(kind, preferredChannel)) do
        sendEmbed(channel, embed)
    end
end

function SKLogs.Public(kind, data)
    SKLogs.Emit(kind, data, 'public')
end

function SKLogs.Admin(kind, data)
    SKLogs.Emit(kind, data, 'admin')
end
