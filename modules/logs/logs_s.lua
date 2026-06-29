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
    return ('%02d:%02d.%03d'):format(math.floor(totalSeconds / 60), totalSeconds % 60, ms % 1000)
end

local function yesNo(value)
    return value and 'Si' or 'No'
end

local function nowLabel()
    return os.date('%Y-%m-%d %H:%M:%S')
end

local function addField(fields, name, value, inline)
    if value == nil or value == '' then return end
    fields[#fields + 1] = {
        name = trim(name, 256),
        value = trim(value, MAX_FIELD_VALUE),
        inline = inline == true,
    }
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

local function discordMention(source)
    if getConfig().includeDiscordMentions == false then return nil end

    local discordIdentifier = getIdentifiers(source).discord
    local discordId = type(discordIdentifier) == 'string' and discordIdentifier:match('^discord:(%d+)$') or nil
    if not discordId then return nil end

    return ('<@%s>'):format(discordId)
end

local function appendDiscordMention(label, source)
    local mention = discordMention(source)
    if not mention then return label end
    return ('%s | %s'):format(label, mention)
end

local function identifierSummary(source)
    if getConfig().includeIdentifiers == false then return nil end

    local identifiers = getIdentifiers(source)
    local lines = {}
    for _, key in ipairs({ 'license', 'discord', 'fivem', 'steam', 'ip' }) do
        if identifiers[key] then
            if key == 'discord' then
                lines[#lines + 1] = ('%s | %s'):format(identifiers[key], discordMention(source) or 'sin @')
            else
                lines[#lines + 1] = identifiers[key]
            end
        end
    end

    if #lines == 0 then return nil end
    return table.concat(lines, '\n')
end

local function getDocument(source)
    return SKSaves and SKSaves.getDocument and SKSaves.getDocument(source) or nil
end

local function getAlias(source)
    local document = getDocument(source)
    local profile = document and document.profile or nil
    local alias = profile and profile.alias or nil
    if type(alias) == 'string' and alias ~= '' then return alias end
    return GetPlayerName(source) or 'Desconocido'
end

local function playerPublic(source)
    if type(source) ~= 'number' or source <= 0 then return 'Sistema' end
    return appendDiscordMention(getAlias(source), source)
end

local function playerAdmin(source)
    if type(source) ~= 'number' or source <= 0 then return 'Consola / sistema' end
    local skId = SKPlayerIds and SKPlayerIds.Get and SKPlayerIds.Get(source) or nil
    local idText = skId and ('SK #%s | Source %d'):format(skId, source) or ('Source %d'):format(source)
    return appendDiscordMention(('%s | %s | %s'):format(getAlias(source), idText, GetPlayerName(source) or 'Desconocido'), source)
end

local function coordsText(source)
    if type(source) ~= 'number' or source <= 0 then return nil end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    if not coords then return nil end

    return ('x=%.2f, y=%.2f, z=%.2f, h=%.2f'):format(coords.x, coords.y, coords.z, heading or 0.0)
end

local function coordsPayloadText(coords)
    if not coords then return nil end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not x or not y or not z then return nil end

    return ('x=%.2f, y=%.2f, z=%.2f, h=%.2f'):format(x, y, z, tonumber(coords.h) or 0.0)
end

local function saveSummary(source)
    if not SKSaves or not SKSaves.hasActiveSave or not SKSaves.hasActiveSave(source) then return nil end

    local document = getDocument(source)
    local profile = document and document.profile or {}
    local economy = document and document.economy or {}
    local progression = document and document.progression or {}
    local saveId = SKSaves.getActiveSaveId and SKSaves.getActiveSaveId(source) or nil

    return table.concat({
        ('saveId=%s'):format(cleanText(saveId)),
        ('alias=%s'):format(cleanText(profile.alias)),
        ('nivel=%s'):format(cleanText(progression.level)),
        ('cash=%s'):format(money(economy.cash or 0)),
        ('vip=%s'):format(cleanText(profile.vipTier, 'none')),
    }, '\n')
end

local function eventInfo(eventId)
    local event = type(eventId) == 'string' and SKEvents and SKEvents[eventId] or nil
    if not event then return cleanText(eventId, 'Desconocido'), nil end

    local details = {}
    details[#details + 1] = ('id=%s'):format(cleanText(event.id or eventId))
    details[#details + 1] = ('tipo=%s'):format(cleanText(event.type))
    details[#details + 1] = ('modo=%s'):format(cleanText(event.mode))
    details[#details + 1] = ('trazado=%s'):format(cleanText(event.scheme))
    if event.goalTime then details[#details + 1] = ('meta=%ss'):format(event.goalTime) end
    if event.duration then details[#details + 1] = ('duracion=%ss'):format(event.duration) end

    return event.name or event.title or event.id or eventId, table.concat(details, '\n')
end

local function speedCameraInfo(eventId)
    for _, cam in ipairs(SKSpeedCameras or {}) do
        if cam.id == eventId then
            return cam.name or cam.id, {
                coords = cam.coords,
                triggerSpeedMph = cam.triggerSpeedMph,
            }
        end
    end
    return cleanText(eventId, 'Radar'), nil
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
            parts[#parts + 1] = ('Jugador XP +%d | nivel %s -> %s'):format(reward.player.xpGained, cleanText(reward.player.oldLevel), cleanText(reward.player.newLevel))
        end
        if reward.vehicle and tonumber(reward.vehicle.xpGained) and reward.vehicle.xpGained > 0 then
            parts[#parts + 1] = ('Vehiculo XP +%d | nivel %s -> %s'):format(reward.vehicle.xpGained, cleanText(reward.vehicle.oldLevel), cleanText(reward.vehicle.newLevel))
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, '\n')
end

local function addAdminContext(fields, source)
    addField(fields, 'Hora servidor', nowLabel(), true)
    addField(fields, 'Coordenadas', coordsText(source), false)
    addField(fields, 'Save activo', saveSummary(source), false)
    addField(fields, 'Identificadores', identifierSummary(source), false)
end

local function buildGeneric(kind, data, channel)
    local fields = {}
    for key, value in pairs(data or {}) do
        if type(value) ~= 'table' then
            addField(fields, key, tostring(value), true)
        end
    end
    return {
        title = kind,
        description = channel == 'public' and 'Evento del servidor.' or 'Evento interno de StreetKings.',
        colorKey = channel == 'public' and 'public' or 'admin',
        fields = fields,
    }
end

local builders = {}

builders.playerConnected = function(data, channel)
    local fields = {}
    if channel == 'public' then
        addField(fields, 'Jugador', cleanText(data.name), true)
        return {
            title = 'Jugador conectado',
            description = ('%s se conecto a StreetKings.'):format(cleanText(data.name)),
            colorKey = 'success',
            fields = fields,
        }
    end

    addField(fields, 'Jugador', ('%s | ID %s'):format(cleanText(data.name), cleanText(data.source)), false)
    addAdminContext(fields, data.source)
    return {
        title = 'Jugador conectado',
        description = 'Un jugador entro al servidor.',
        colorKey = 'success',
        fields = fields,
    }
end

builders.playerDisconnected = function(data, channel)
    local fields = {}
    if channel == 'public' then
        addField(fields, 'Jugador', cleanText(data.alias or data.name), true)
        return {
            title = 'Jugador desconectado',
            description = ('%s salio de StreetKings.'):format(cleanText(data.alias or data.name)),
            colorKey = 'warning',
            fields = fields,
        }
    end

    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Motivo', cleanText(data.reason), false)
    addAdminContext(fields, data.source)
    return {
        title = 'Jugador desconectado',
        description = 'Un jugador salio del servidor.',
        colorKey = 'warning',
        fields = fields,
    }
end

builders.saveSelected = function(data, channel)
    local fields = {}
    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Slot', cleanText(data.slotIndex), true)
    addField(fields, 'Save ID', cleanText(data.saveId), false)
    addField(fields, 'Nuevo save', yesNo(data.isNew), true)
    addAdminContext(fields, data.source)
    return {
        title = 'Partida cargada',
        description = 'Un jugador selecciono una ranura de personaje.',
        colorKey = channel == 'public' and 'public' or 'admin',
        fields = fields,
    }
end

builders.activitySubmitted = function(data, channel)
    local eventName, eventDetails = eventInfo(data.eventId)
    local fields = {}

    if channel == 'public' then
        addField(fields, 'Jugador', playerPublic(data.source), true)
        addField(fields, 'Evento', eventName, true)
        addField(fields, 'Resultado', scoreText(data.scoreType, data.scoreValue), true)
        addField(fields, 'Vehiculo', cleanText(data.vehicleModel, 'Sin modelo'), true)
        return {
            title = data.scoreType == 'speed' and 'Radar registrado' or 'Resultado publicado',
            description = ('%s completo %s.'):format(playerPublic(data.source), eventName),
            colorKey = 'success',
            fields = fields,
        }
    end

    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Evento', ('%s (`%s`)'):format(eventName, cleanText(data.eventId)), true)
    addField(fields, 'Tipo de actividad', cleanText(data.scoreType), true)
    addField(fields, 'Resultado', scoreText(data.scoreType, data.scoreValue), true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleModel, 'Sin modelo'), true)
    addField(fields, 'Clase', cleanText(data.vehicleClass, '-'), true)
    addField(fields, 'Diario', yesNo(data.daily), true)
    addField(fields, 'Meta cumplida', yesNo(data.goalMet), true)
    addField(fields, 'Datos del evento', eventDetails, false)
    addField(fields, 'Recompensa', rewardText(data.reward, data.cash), false)
    addAdminContext(fields, data.source)

    return {
        title = 'Resultado de carrera / actividad',
        description = 'Resultado validado y guardado en leaderboard.',
        colorKey = 'success',
        fields = fields,
    }
end

builders.speedCameraPhoto = function(data, channel)
    local camName, cam = speedCameraInfo(data.eventId)
    local speed = math.floor(tonumber(data.speedMph or data.speed) or 0)
    local wantedLevel = math.max(0, math.min(5, math.floor(tonumber(data.wantedLevel) or 0)))
    local fields = {}

    if channel == 'public' then
        addField(fields, 'Jugador', playerPublic(data.source), true)
        addField(fields, 'Radar', camName, true)
        addField(fields, 'Velocidad', scoreText('speed', speed), true)
        addField(fields, 'Vehiculo', cleanText(data.vehicleModel, 'Sin modelo'), true)
        return {
            title = 'Radar de velocidad',
            description = ('%s fue captado por un radar.'):format(playerPublic(data.source)),
            colorKey = 'warning',
            fields = fields,
            image = data.imageUrl,
        }
    end

    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Radar', ('%s (`%s`)'):format(camName, cleanText(data.eventId)), true)
    addField(fields, 'Velocidad', scoreText('speed', speed), true)
    addField(fields, 'Nivel de busqueda', tostring(wantedLevel), true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleModel, 'Sin modelo'), true)
    if cam and cam.triggerSpeedMph then
        addField(fields, 'Velocidad minima', scoreText('speed', cam.triggerSpeedMph), true)
    end
    addField(fields, 'Coordenadas radar', coordsPayloadText(cam and cam.coords), false)
    addField(fields, 'Coordenadas vehiculo', coordsPayloadText(data.vehicleCoords), false)
    addAdminContext(fields, data.source)

    return {
        title = 'Foto de radar',
        description = 'Un radar valido capturo al jugador y se envio el ticket al NUI.',
        colorKey = 'warning',
        fields = fields,
        image = data.imageUrl,
    }
end

builders.activityRejected = function(data, channel)
    local fields = {}
    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Motivo', cleanText(data.reason), true)
    addField(fields, 'Evento', cleanText(data.eventId), true)
    addField(fields, 'Puntuacion enviada', cleanText(data.scoreValue), true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleModel), true)
    addAdminContext(fields, data.source)

    return {
        title = 'Resultado rechazado',
        description = 'Una puntuacion fue bloqueada por validacion del servidor.',
        colorKey = 'warning',
        fields = fields,
    }
end

builders.npcRace = function(data, channel)
    local fields = {}
    if channel == 'public' then
        addField(fields, 'Jugador', playerPublic(data.source), true)
        addField(fields, 'Resultado', data.won and 'Victoria' or 'Derrota', true)
        addField(fields, 'Tiempo', data.elapsedMs and duration(data.elapsedMs) or nil, true)
        return {
            title = 'Reto callejero',
            description = data.won and ('%s gano un reto callejero.'):format(playerPublic(data.source)) or ('%s perdio un reto callejero.'):format(playerPublic(data.source)),
            colorKey = data.won and 'success' or 'warning',
            fields = fields,
        }
    end

    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Resultado', data.won and 'Victoria' or 'Derrota', true)
    addField(fields, 'Tiempo', data.elapsedMs and duration(data.elapsedMs) or nil, true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleModel), true)
    addField(fields, 'Clase GTA', cleanText(data.vehicleClass), true)
    addField(fields, 'Dinero', data.cash and money(data.cash) or nil, true)
    addField(fields, 'Recompensa', rewardText(data.reward, nil), false)
    addAdminContext(fields, data.source)

    return {
        title = 'Reto callejero NPC',
        description = data.won and 'El jugador gano una persecucion callejera.' or 'El jugador perdio una persecucion callejera.',
        colorKey = data.won and 'success' or 'warning',
        fields = fields,
    }
end

builders.policeEscape = function(data, channel)
    local fields = {}
    if channel == 'public' then
        addField(fields, 'Jugador', playerPublic(data.source), true)
        return {
            title = 'Persecucion escapada',
            description = ('%s escapo de la policia.'):format(playerPublic(data.source)),
            colorKey = 'success',
            fields = fields,
        }
    end

    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Resultado', 'Escapo de la policia', true)
    addAdminContext(fields, data.source)
    return {
        title = 'Persecucion completada',
        description = 'El jugador escapo de una persecucion policial.',
        colorKey = 'success',
        fields = fields,
    }
end

builders.policeBust = function(data, channel)
    local fields = {}
    if channel == 'public' then
        addField(fields, 'Jugador', playerPublic(data.source), true)
        addField(fields, 'Multa', money(data.deducted or 0), true)
        return {
            title = 'Arresto policial',
            description = ('%s fue arrestado por la policia.'):format(playerPublic(data.source)),
            colorKey = 'error',
            fields = fields,
        }
    end

    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Multa', money(data.deducted or 0), true)
    addField(fields, 'Efectivo antes', money(data.beforeCash or 0), true)
    addField(fields, 'Efectivo despues', money(data.afterCash or 0), true)
    addAdminContext(fields, data.source)
    return {
        title = 'Jugador arrestado',
        description = 'Se aplico una multa policial.',
        colorKey = 'error',
        fields = fields,
    }
end

builders.dealershipPurchase = function(data, channel)
    local fields = {}
    if channel == 'public' then
        addField(fields, 'Jugador', playerPublic(data.source), true)
        addField(fields, 'Vehiculo', cleanText(data.vehicleName or data.vehicleModel), true)
        addField(fields, 'Precio', money(data.price or 0), true)
        return {
            title = 'Compra de vehiculo',
            description = ('%s compro un %s.'):format(playerPublic(data.source), cleanText(data.vehicleName or data.vehicleModel)),
            colorKey = 'success',
            fields = fields,
        }
    end

    addField(fields, 'Jugador', playerAdmin(data.source), false)
    addField(fields, 'Concesionario', cleanText(data.dealershipId), true)
    addField(fields, 'Vehiculo', cleanText(data.vehicleName or data.vehicleModel), true)
    addField(fields, 'Modelo spawn', cleanText(data.vehicleModel), true)
    addField(fields, 'Clase', cleanText(data.vehicleClass), true)
    addField(fields, 'Precio', money(data.price or 0), true)
    addField(fields, 'Balance despues', money(data.balance or 0), true)
    addField(fields, 'Etiqueta', data.requiredVip and ('VIP: ' .. cleanText(data.requiredVip)) or 'Publico', true)
    addAdminContext(fields, data.source)
    return {
        title = 'Compra en concesionario',
        description = 'Compra validada y guardada en garage.',
        colorKey = 'success',
        fields = fields,
        image = data.vehicleImageUrl,
    }
end

builders.vipChanged = function(data)
    local fields = {}
    addField(fields, 'Admin', playerAdmin(data.source), false)
    addField(fields, 'Jugador', playerAdmin(data.target), false)
    addField(fields, 'VIP anterior', cleanText(data.oldTier, 'none'), true)
    addField(fields, 'VIP nuevo', cleanText(data.newTier, 'none'), true)
    addField(fields, 'Identificadores admin', identifierSummary(data.source), false)
    addAdminContext(fields, data.target)

    return {
        title = 'VIP actualizado',
        description = 'Un administrador cambio el nivel VIP de un jugador.',
        colorKey = 'admin',
        fields = fields,
    }
end

builders.adminCommand = function(data)
    local fields = {}
    addField(fields, 'Admin', playerAdmin(data.source), false)
    addField(fields, 'Comando', '/' .. cleanText(data.command), true)
    addField(fields, 'Objetivo', data.target and playerAdmin(data.target) or nil, false)
    addField(fields, 'Detalles', cleanText(data.details), false)
    addAdminContext(fields, data.source)

    return {
        title = 'Comando administrativo',
        description = 'Se ejecuto una accion administrativa.',
        colorKey = 'admin',
        fields = fields,
    }
end

builders.moduleEvent = function(data, channel)
    local fields = {}
    if channel == 'public' then
        addField(fields, 'Apartado', cleanText(data.module), true)
        addField(fields, 'Accion', cleanText(data.action), true)
        addField(fields, 'Jugador', data.source and playerPublic(data.source) or nil, false)
        addField(fields, 'Resumen', cleanText(data.publicMessage), false)
        return {
            title = cleanText(data.title, 'Actividad del framework'),
            description = cleanText(data.publicMessage, 'Se registro una accion del servidor.'),
            colorKey = 'public',
            fields = fields,
        }
    end

    addField(fields, 'Modulo', cleanText(data.module), true)
    addField(fields, 'Accion', cleanText(data.action), true)
    addField(fields, 'Jugador', data.source and playerAdmin(data.source) or nil, false)
    addField(fields, 'Objetivo', data.target and playerAdmin(data.target) or nil, false)
    addField(fields, 'Resumen publico', cleanText(data.publicMessage), false)
    addField(fields, 'Detalles', cleanText(data.details), false)
    addAdminContext(fields, data.source)

    return {
        title = cleanText(data.title, 'Actividad del framework'),
        description = cleanText(data.adminMessage, 'Accion detallada del framework.'),
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

local function getWebhook(kind, channel)
    local channelConfig = (getConfig().channels or {})[channel]
    if type(channelConfig) ~= 'table' or channelConfig.enabled == false then return nil end

    if kind == 'moduleEvent' then
        local moduleName = SKLogs._activeModuleName
        local moduleConfig = moduleName and (getConfig().moduleWebhooks or {})[moduleName] or nil
        if type(moduleConfig) == 'table' and type(moduleConfig[channel]) == 'string' and moduleConfig[channel] ~= '' then
            return moduleConfig[channel]
        end
    end

    local webhookConfig = (getConfig().webhooks or {})[kind]
    if type(webhookConfig) == 'table' and type(webhookConfig[channel]) == 'string' and webhookConfig[channel] ~= '' then
        return webhookConfig[channel]
    end

    return type(channelConfig.webhook) == 'string' and channelConfig.webhook ~= '' and channelConfig.webhook or nil
end

local function getDedicatedWebhook(kind, channel)
    local webhookConfig = (getConfig().webhooks or {})[kind]
    if type(webhookConfig) == 'table' and type(webhookConfig[channel]) == 'string' and webhookConfig[channel] ~= '' then
        return webhookConfig[channel]
    end
    return nil
end

local function sendEmbed(kind, channel, embed)
    local cfg = getConfig()
    if cfg.enabled == false then return end

    local webhook = getWebhook(kind, channel)
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

local function buildEmbed(kind, data, channel)
    local built = builders[kind] and builders[kind](data, channel) or buildGeneric(kind, data, channel)
    local cfg = getConfig()
    local colorKey = built.colorKey or (channel == 'public' and 'public' or 'admin')
    local color = (cfg.colors or {})[colorKey] or (cfg.colors or {}).admin or 16763904

    return {
        title = trim(built.title or kind, 256),
        description = trim(built.description or '', MAX_DESCRIPTION),
        color = color,
        fields = built.fields or {},
        image = type(built.image) == 'string' and built.image ~= '' and { url = built.image } or nil,
        thumbnail = type(built.thumbnail) == 'string' and built.thumbnail ~= '' and { url = built.thumbnail } or nil,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = {
            text = cleanText(cfg.footer, 'StreetKings'),
        },
    }
end

function SKLogs.Emit(kind, data, preferredChannel)
    if type(kind) ~= 'string' or kind == '' then return end

    data = type(data) == 'table' and data or {}
    for _, channel in ipairs(resolveChannels(kind, preferredChannel)) do
        sendEmbed(kind, channel, buildEmbed(kind, data, channel))
    end
end

function SKLogs.Module(moduleName, action, data, preferredChannel)
    if type(moduleName) ~= 'string' or moduleName == '' then return end
    data = type(data) == 'table' and data or {}
    data.module = moduleName
    data.action = action or data.action or 'event'
    SKLogs._activeModuleName = moduleName
    SKLogs.Emit('moduleEvent', data, preferredChannel)
    SKLogs._activeModuleName = nil
end

function SKLogs.Public(kind, data)
    SKLogs.Emit(kind, data, 'public')
end

exports('LogModulePublic', function(moduleName, action, data)
    SKLogs.Module(moduleName, action, data, 'public')
end)

exports('LogModuleAdmin', function(moduleName, action, data)
    SKLogs.Module(moduleName, action, data, 'admin')
end)

exports('LogModule', function(moduleName, action, data, channel)
    SKLogs.Module(moduleName, action, data, channel)
end)

function SKLogs.Admin(kind, data)
    SKLogs.Emit(kind, data, 'admin')
end

local function speedCameraPhotoConfigForClient()
    local cfg = getConfig()
    local photo = type(cfg.speedCameraPhoto) == 'table' and cfg.speedCameraPhoto or {}
    if photo.enabled == false then
        return { enabled = false }
    end

    local discord = type(photo.discord) == 'table' and photo.discord or {}
    local screenshot = type(photo.screenshot) == 'table' and photo.screenshot or {}
    local webhook = nil
    if discord.enabled ~= false then
        webhook = type(discord.webhook) == 'string' and discord.webhook ~= '' and discord.webhook or nil
        webhook = webhook or getDedicatedWebhook('speedCameraPhoto', 'admin')
    end

    return {
        enabled = true,
        displayForMs = tonumber(photo.displayForMs) or 15000,
        webhook = webhook,
        screenshot = {
            encoding = type(screenshot.encoding) == 'string' and screenshot.encoding or 'jpg',
            quality = tonumber(screenshot.quality) or 0.85,
        },
    }
end

local function clampSpeedCameraPhotoData(data)
    data = type(data) == 'table' and data or {}
    return {
        eventId = type(data.eventId) == 'string' and data.eventId:sub(1, 64) or '',
        name = type(data.name) == 'string' and data.name:sub(1, 96) or '',
        speedMph = math.max(0, math.min(300, math.floor(tonumber(data.speedMph) or 0))),
        wantedLevel = math.max(0, math.min(5, math.floor(tonumber(data.wantedLevel) or 0))),
        vehicleModel = type(data.vehicleModel) == 'string' and data.vehicleModel:sub(1, 64) or '',
        vehicleCoords = type(data.vehicleCoords) == 'table' and data.vehicleCoords or nil,
        imageUrl = type(data.imageUrl) == 'string' and data.imageUrl:sub(1, 1024) or nil,
    }
end

lib.callback.register('streetkings:speedcam:getPhotoConfig', function(_)
    return speedCameraPhotoConfigForClient()
end)

RegisterNetEvent('streetkings:speedcam:photoLog', function(data)
    local src = source --[[@as integer]]
    if not SKSaves or not SKSaves.hasActiveSave or not SKSaves.hasActiveSave(src) then return end

    local payload = clampSpeedCameraPhotoData(data)
    local context = SKEventsSubmit and SKEventsSubmit.consumeSpeedCameraPhotoContext
        and SKEventsSubmit.consumeSpeedCameraPhotoContext(src, payload.eventId)
        or nil
    if not context then return end

    payload.eventId = context.eventId
    payload.speedMph = context.speedMph
    payload.wantedLevel = context.wantedLevel
    payload.vehicleModel = context.vehicleModel
    payload.source = src
    SKLogs.Emit('speedCameraPhoto', payload, 'admin')
end)

AddEventHandler('playerJoining', function()
    local src = source --[[@as integer]]
    SKLogs.Emit('playerConnected', {
        source = src,
        name = GetPlayerName(src) or 'Desconocido',
    })
end)
