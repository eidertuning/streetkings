local MONEY_PATHS = {
    cash = 'economy.cash',
}

lib.addCommand('tp', {
    help = 'Teleport to coordinates',
    restricted = 'group.admin',
}, function(source, _, raw)
    local values = {}

    for value in raw:gmatch('[%-]?%d+%.?%d*') do
        values[#values + 1] = tonumber(value)
    end

    local x = values[1]
    local y = values[2]
    local z = values[3]

    if not x or not y or not z then return end
    TriggerClientEvent('streetkings:admin:teleport', source, x, y, z)
end)

lib.addCommand({'tpm', 'warp'}, {
    help = 'Teleport to waypoint marker',
    restricted = 'group.admin',
}, function(source)
    TriggerClientEvent('streetkings:admin:teleportMarker', source)
end)

lib.addCommand('logout', {
    help = 'Save and return to main menu',
    restricted = 'group.admin',
}, function(source)
    if SKSaves.hasActiveSave(source) then
        SKSaves.persist(source)
        SKSaves.clearActive(source)
    end
    TriggerClientEvent('streetkings:admin:logout', source)
end)

lib.addCommand('givemoney', {
    help = 'Give money to a player',
    params = {
        { name = 'id',     help = 'Player server ID',  type = 'playerId' },
        { name = 'type',   help = 'cash',              type = 'string'   },
        { name = 'amount', help = 'Amount to give',    type = 'number'   },
    },
    restricted = 'group.admin',
}, function(_, args)
    local path = MONEY_PATHS[args.type]
    if not path or not SKSaves.hasActiveSave(args.id) then return end
    SKSaves.write(args.id, path, SKSaves.read(args.id, path) + args.amount)
end)

lib.addCommand('setmoney', {
    help = 'Set money for a player',
    params = {
        { name = 'id',     help = 'Player server ID',  type = 'playerId' },
        { name = 'type',   help = 'cash',              type = 'string'   },
        { name = 'amount', help = 'Amount to set',     type = 'number'   },
    },
    restricted = 'group.admin',
}, function(_, args)
    local path = MONEY_PATHS[args.type]
    if not path or not SKSaves.hasActiveSave(args.id) then return end
    SKSaves.write(args.id, path, args.amount)
end)

lib.addCommand('v3', {
    help = 'Copy current position as vector3 to clipboard',
    restricted = 'group.admin',
}, function(source)
    local coords = GetEntityCoords(GetPlayerPed(source))
    TriggerClientEvent('streetkings:admin:copyCoords', source, coords)
end)

lib.addCommand('v4', {
    help = 'Copy current position and heading as vector4 to clipboard',
    restricted = 'group.admin',
}, function(source)
    local ped    = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerClientEvent('streetkings:admin:copyCoords4', source, coords, heading)
end)

lib.addCommand('time', {
    help = 'Set the server time',
    params = {
        { name = 'hour', help = 'Hour (0–23)', type = 'number' },
    },
    restricted = 'group.admin',
}, function(_, args)
    SKEnvironment.SetHour(args.hour)
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
    restricted = 'group.admin',
}, function(_, args)
    local weather = args.weather:upper()
    if not VALID_WEATHERS[weather] then return end
    SKEnvironment.SetWeather(weather)
end)