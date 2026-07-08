Config = {}

Config.Command = 'skadmin'
Config.OpenKey = 'F10'
Config.Debug = true

Config.App = {
    id = 'sk_admin',
    label = 'Control',
    icon = 'fa-shield-halved',
    glyph = 'FH',
    color = 'linear-gradient(135deg, #ff0a73, #c86bff 52%, #8cecff)',
    ui = 'html/index.html',
    description = 'Sala de control admin integrada en la tablet con estilo Five Horizon.',
    version = '46.0.0',
    developer = 'CodeEider'
}

Config.Auth = {
    EnableAce = true,
    AcePermission = 'ce_skadmin.open',
    EnableLicenseWhitelist = true,
    AllowConsole = true
}

Config.LicenseAdmins = {
    ['license:bae22bda13e47b3c2ea70319f1c4de456c05306a'] = { rank = 'owner', label = 'Eider' },
}

Config.ProtectedLicenses = {
    ['license:bae22bda13e47b3c2ea70319f1c4de456c05306a'] = true,
}





Config.Launch = {
    -- Evita que la app cree un NUI fullscreen fuera de la tablet.
    TabletOnly = true,
    HideStandalonePage = true,
    RegisterDelayMs = 2000,
    RecheckMs = 30000
}

Config.Security = {
    -- La app solo se registra en la tablet si el cliente es admin.
    RegisterOnlyForAdmins = true,

    -- Si es false, /skadmin NO abre la app directamente; solo avisa que se abra desde la tablet.
    -- Esto evita que se use como panel suelto.
    AllowCommandOpen = false,

    -- Obliga a que la UI pida una sesión temporal antes de usar callbacks.
    RequireTabletSession = true,
    SessionTtlMs = 300000,

    -- Seguridad práctica: el HTML se oculta si no está dentro de la tablet.
    -- No lo bloqueamos en servidor porque el SDK puede no mandar el frame igual en todos los builds.
    RequireTabletFrame = false
}

Config.Database = {
    EnableSqlFallback = true,
    SaveTable = 'player_saves',
    AvatarTable = 'player_avatars',
    LatestSaveOrder = 'last_played_at DESC, updated_at DESC'
}

Config.Defaults = {
    cash = 1000,
    playerXp = 250,
    vehicleXp = 100,
    armor = 100,
    kickReason = 'Expulsado por administración.',
    phoneSender = 'Admin',
    phoneAvatar = 'admin',
    phoneMessage = 'Mensaje de administración.'
}

Config.World = {
    times = { 0, 6, 9, 12, 16, 20, 22 },
    weather = { 'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'RAIN', 'THUNDER', 'FOGGY', 'SMOG', 'XMAS' }
}

Config.Progression = {
    PlayerMaxLevel = 50,
    VehicleMaxLevel = 10,
    PlayerLevelThresholds = {
        [1]=0,[2]=80,[3]=171,[4]=275,[5]=394,[6]=530,[7]=685,[8]=861,[9]=1060,[10]=1284,
        [11]=1535,[12]=1815,[13]=2126,[14]=2470,[15]=2849,[16]=3265,[17]=3720,[18]=4216,[19]=4755,[20]=5339,
        [21]=5970,[22]=6650,[23]=7381,[24]=8165,[25]=9004,[26]=9900,[27]=10855,[28]=11871,[29]=12950,[30]=14094,
        [31]=15305,[32]=16585,[33]=17936,[34]=19360,[35]=20859,[36]=22435,[37]=24090,[38]=25826,[39]=27645,[40]=29549,
        [41]=31540,[42]=33620,[43]=35791,[44]=38055,[45]=40414,[46]=42870,[47]=45425,[48]=48081,[49]=50840,[50]=53704
    },
    VehicleLevelThresholds = { [1]=0,[2]=55,[3]=119,[4]=194,[5]=282,[6]=385,[7]=505,[8]=644,[9]=804,[10]=987 }
}

Config.Ranks = {
    owner = { label = 'OWNER', power = 100, permissions = { '*' } },
    manager = { label = 'MANAGER', power = 80, permissions = { '*' } },
    admin = { label = 'ADMIN', power = 60, permissions = {
        'players.view','player.goto','player.bring','player.spectate','player.freeze','player.revive','player.heal','player.armor','player.kill','player.kick',
        'economy.add','economy.remove','progression.playerxp','progression.vehiclexp','garage.view','garage.setactive','garage.add','garage.delete',
        'vehicle.repair','vehicle.clean','vehicle.flip','vehicle.warpwp','vehicle.speedometer','vehicle.soundtrack','vehicle.cinematic','vehicle.exitlock',
        'world.time','world.weather','phone.message','phone.broadcast','phone.toggle','capture.screen','capture.live','waypoints.create','waypoints.remove','diagnostics.view'
    } },
    moderator = { label = 'MOD', power = 40, permissions = {
        'players.view','player.goto','player.bring','player.spectate','player.freeze','player.revive','player.heal','player.kick',
        'vehicle.repair','vehicle.clean','vehicle.flip','phone.message','phone.toggle','diagnostics.view'
    } },
    support = { label = 'SUPPORT', power = 20, permissions = {
        'players.view','player.goto','player.bring','vehicle.repair','vehicle.clean','phone.message','diagnostics.view'
    } }
}

Config.Capture = {
    -- Legacy screenshot mode disabled. Live now uses only hidden WebGL + WebRTC.
    Enabled = false,
    Resource = '',
    FallbackResource = '',
    UseClientProxy = false,
    NotifyTarget = false,
    MaxPerMinute = 0
}

Config.Live = {
    Enabled = true,
    Width = 1280,
    Height = 720,
    FrameRate = 24,
    PollMs = 250,
    TimeoutMs = 15000,
    MaxSeconds = 300,
    LogSessions = true,
    NotifyTarget = false
}

Config.VehicleCatalog = {
    -- El catálogo de StreetKings se construye desde data/game_vehicles.lua.
    ClassOrder = { 'STARTER', 'C', 'B', 'A', 'S' },
    DealerOrder = { 'starter', 'tuner', 'sportscar', 'muscle', 'offroad' },
    DealerLabels = {
        starter = 'Starter',
        tuner = 'Tuner',
        sportscar = 'Sports',
        muscle = 'Muscle',
        offroad = 'Off-Road'
    }
}

Config.VehicleImages = {
    Enabled = true,

    -- 1) Primero intenta exports de JG Vehicle Studio: getImage/getImages.
    UseJgVehicleStudioExport = true,
    JgResource = 'jg-vehiclestudio',
    DefaultImageSet = nil,

    -- 2) Si no hay export o no devuelve URL, intenta rutas locales comunes.
    -- La UI ya no hace retry infinito: si una imagen falla, se cachea como no disponible.
    Sources = {
        'nui://jg-vehiclestudio/image/%s.webp',
        'nui://jg-vehiclestudio/image/%s.png',
        'nui://jg-advancedgarages/vehicle_images/%s.png',
        'nui://jg-dealerships/vehicle_images/%s.png',
        'nui://jg-vehicleimages/html/images/%s.png',
        'nui://streetkings/html/assets/vehicles/%s.webp',
        'nui://streetkings/html/assets/vehicles/%s.png'
    }
}
