SKLogsConfig = {
    enabled = true,

    username = 'StreetKings Logs',
    avatarUrl = '',
    footer = 'StreetKings',

    channels = {
        public = {
            enabled = true,
            webhook = '',
        },
        admin = {
            enabled = true,
            webhook = '',
        },
    },

    -- Each log type can use its own public/admin webhook.
    -- If one is empty, the logger falls back to channels.public/admin.webhook.
    webhooks = {
        playerConnected = {
            public = '',
            admin = '',
        },
        playerDisconnected = {
            public = '',
            admin = '',
        },
        saveSelected = {
            admin = '',
        },
        activitySubmitted = {
            public = '',
            admin = '',
        },
        speedCameraPhoto = {
            public = '',
            admin = '',
        },
        activityRejected = {
            admin = '',
        },
        npcRace = {
            public = '',
            admin = '',
        },
        policeEscape = {
            public = '',
            admin = '',
        },
        policeBust = {
            public = '',
            admin = '',
        },
        dealershipPurchase = {
            public = '',
            admin = '',
        },
        vipChanged = {
            admin = '',
        },
        adminCommand = {
            admin = '',
        },
    },

    moduleWebhooks = {
        adminbridge = { public = '', admin = '' },
        admincommands = { public = '', admin = '' },
        avatar = { public = '', admin = '' },
        controllerfriendly = { public = '', admin = '' },
        core = { public = '', admin = '' },
        dealership = { public = '', admin = '' },
        devtools = { public = '', admin = '' },
        environment = { public = '', admin = '' },
        events = { public = '', admin = '' },
        freeroam = { public = '', admin = '' },
        garage = { public = '', admin = '' },
        gearbox = { public = '', admin = '' },
        hangoutzones = { public = '', admin = '' },
        init = { public = '', admin = '' },
        initiation = { public = '', admin = '' },
        leaderboard = { public = '', admin = '' },
        main_menu = { public = '', admin = '' },
        messages = { public = '', admin = '' },
        missions = { public = '', admin = '' },
        nametags = { public = '', admin = '' },
        nitrous = { public = '', admin = '' },
        notify = { public = '', admin = '' },
        pausemenu = { public = '', admin = '' },
        phone = { public = '', admin = '' },
        progression = { public = '', admin = '' },
        property = { public = '', admin = '' },
        repair = { public = '', admin = '' },
        settings = { public = '', admin = '' },
        shop = { public = '', admin = '' },
        soundtrack = { public = '', admin = '' },
        speedometer = { public = '', admin = '' },
        stats = { public = '', admin = '' },
        storage = { public = '', admin = '' },
        stunts = { public = '', admin = '' },
        tutorial = { public = '', admin = '' },
        vip = { public = '', admin = '' },
        waypoints = { public = '', admin = '' },
    },

    -- Optional speed camera screenshots. If screenshot-basic is running, the
    -- client can upload directly to this dedicated webhook or to
    -- webhooks.speedCameraPhoto.admin. Leave both empty to log without images.
    speedCameraPhoto = {
        enabled = true,
        displayForMs = 15000,
        discord = {
            enabled = true,
            webhook = '',
        },
        screenshot = {
            encoding = 'jpg',
            quality = 0.85,
        },
    },

    colors = {
        public = 16711935,
        admin = 16763904,
        success = 5814783,
        warning = 16750848,
        error = 16724787,
    },

    routing = {
        playerConnected = { 'public', 'admin' },
        playerDisconnected = { 'public', 'admin' },
        saveSelected = 'admin',
        activitySubmitted = { 'public', 'admin' },
        speedCameraPhoto = 'admin',
        activityRejected = 'admin',
        npcRace = { 'public', 'admin' },
        policeEscape = { 'public', 'admin' },
        policeBust = { 'public', 'admin' },
        dealershipPurchase = { 'public', 'admin' },
        vipChanged = 'admin',
        adminCommand = 'admin',
        moduleEvent = { 'public', 'admin' },
    },

    includeIdentifiers = true,
    includeDiscordMentions = true,
    mirrorPublicToAdmin = false,
}
