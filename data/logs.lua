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
        activityRejected = 'admin',
        npcRace = { 'public', 'admin' },
        policeEscape = { 'public', 'admin' },
        policeBust = { 'public', 'admin' },
        dealershipPurchase = { 'public', 'admin' },
        vipChanged = 'admin',
        adminCommand = 'admin',
    },

    includeIdentifiers = true,
    includeDiscordMentions = true,
    mirrorPublicToAdmin = false,
}
