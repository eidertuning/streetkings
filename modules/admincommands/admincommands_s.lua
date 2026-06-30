local MONEY_PATHS = {
    cash = 'economy.cash',
}

local function canUseAdminCommand(source, permission)
    if source == 0 then return true end
    if SKPermissions and type(SKPermissions.HasPermission) == 'function' then
        return SKPermissions.HasPermission(source, permission or 'admin.menu')
    end
    return IsPlayerAceAllowed(source, 'group.admin') or IsPlayerAceAllowed(source, 'command')
end

lib.addCommand('tp', {
    help = 'Teleport to coordinates',
    restricted = false,
}, function(source, _, raw)
    if not canUseAdminCommand(source, 'admin.teleport') then return end
    local values = {}

    for value in raw:gmatch('[%-]?%d+%.?%d*') do
        values[#values + 1] = tonumber(value)
    end

    local x = values[1]
    local y = values[2]
    local z = values[3]

    if not x or not y or not z then return end
    TriggerClientEvent('streetkings:admin:teleport', source, x, y, z)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            command = 'tp',
            details = ('x=%.3f, y=%.3f, z=%.3f'):format(x, y, z),
        })
    end
end)

lib.addCommand({'tpm', 'warp'}, {
    help = 'Teleport to waypoint marker',
    restricted = false,
}, function(source)
    if not canUseAdminCommand(source, 'admin.teleport') then return end
    TriggerClientEvent('streetkings:admin:teleportMarker', source)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            command = 'tpm/warp',
            details = 'Teleport al waypoint del mapa',
        })
    end
end)

lib.addCommand('logout', {
    help = 'Save and return to main menu',
    restricted = false,
}, function(source)
    if not canUseAdminCommand(source, 'admin.menu') then return end
    if SKSaves.hasActiveSave(source) then
        SKSaves.persist(source)
        SKSaves.clearActive(source)
    end
    TriggerClientEvent('streetkings:admin:logout', source)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            command = 'logout',
            details = 'Save persistido y vuelta al menu principal',
        })
    end
end)

lib.addCommand('givemoney', {
    help = 'Give money to a player',
    params = {
        { name = 'id',     help = 'Player server ID',  type = 'playerId' },
        { name = 'type',   help = 'cash',              type = 'string'   },
        { name = 'amount', help = 'Amount to give',    type = 'number'   },
    },
    restricted = false,
}, function(source, args)
    if not canUseAdminCommand(source, 'admin.menu') then return end
    local path = MONEY_PATHS[args.type]
    if not path or not SKSaves.hasActiveSave(args.id) then return end
    local before = SKSaves.read(args.id, path)
    local after = before + args.amount
    SKSaves.write(args.id, path, after)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            target = args.id,
            command = 'givemoney',
            details = ('tipo=%s, cantidad=$%s, antes=$%s, despues=$%s'):format(args.type, args.amount, before, after),
        })
    end
end)

lib.addCommand('setmoney', {
    help = 'Set money for a player',
    params = {
        { name = 'id',     help = 'Player server ID',  type = 'playerId' },
        { name = 'type',   help = 'cash',              type = 'string'   },
        { name = 'amount', help = 'Amount to set',     type = 'number'   },
    },
    restricted = false,
}, function(source, args)
    if not canUseAdminCommand(source, 'admin.menu') then return end
    local path = MONEY_PATHS[args.type]
    if not path or not SKSaves.hasActiveSave(args.id) then return end
    local before = SKSaves.read(args.id, path)
    SKSaves.write(args.id, path, args.amount)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            target = args.id,
            command = 'setmoney',
            details = ('tipo=%s, antes=$%s, nuevo=$%s'):format(args.type, before, args.amount),
        })
    end
end)

lib.addCommand('v3', {
    help = 'Copy current position as vector3 to clipboard',
    restricted = false,
}, function(source)
    if not canUseAdminCommand(source, 'debug') then return end
    local coords = GetEntityCoords(GetPlayerPed(source))
    TriggerClientEvent('streetkings:admin:copyCoords', source, coords)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            command = 'v3',
            details = ('x=%.3f, y=%.3f, z=%.3f'):format(coords.x, coords.y, coords.z),
        })
    end
end)

lib.addCommand('v4', {
    help = 'Copy current position and heading as vector4 to clipboard',
    restricted = false,
}, function(source)
    if not canUseAdminCommand(source, 'debug') then return end
    local ped    = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerClientEvent('streetkings:admin:copyCoords4', source, coords, heading)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            command = 'v4',
            details = ('x=%.3f, y=%.3f, z=%.3f, h=%.3f'):format(coords.x, coords.y, coords.z, heading),
        })
    end
end)

lib.addCommand('time', {
    help = 'Set the server time',
    params = {
        { name = 'hour', help = 'Hour (0–23)', type = 'number' },
    },
    restricted = false,
}, function(source, args)
    if not canUseAdminCommand(source, 'admin.menu') then return end
    SKEnvironment.SetHour(args.hour)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            command = 'time',
            details = ('hora=%s'):format(args.hour),
        })
    end
end)

local VALID_WEATHERS = {
    CLEAR = true, EXTRASUNNY = true, CLOUDS = true, OVERCAST = true,
    RAIN = true, CLEARING = true, THUNDER = true, SMOG = true,
    FOGGY = true, XMAS = true, SNOWLIGHT = true, BLIZZARD = true,
    NEUTRAL = true,
}

lib.addCommand('weather', {
    help = 'Set the server weather',
    params = {
        { name = 'weather', help = 'Weather type (e.g. CLEAR, RAIN, FOGGY)', type = 'string' },
    },
    restricted = false,
}, function(source, args)
    if not canUseAdminCommand(source, 'admin.menu') then return end
    local weather = args.weather:upper()
    if not VALID_WEATHERS[weather] then return end
    SKEnvironment.SetWeather(weather)
    if SKLogs then
        SKLogs.Admin('adminCommand', {
            source = source,
            command = 'weather',
            details = ('clima=%s'):format(weather),
        })
    end
end)
