SKConfig = {
    DisableSpeedometer = false, -- Disable the speedometer
    DisablePauseMenu   = false, -- Disable the pause menu
    Locale             = 'es',  -- Default language: 'es' or 'en'
    FallbackLocale     = 'en',  -- Used when a key is missing in the selected language
    DiscordAvatarEndpoint = '', -- Optional: 'https://your-api/avatar/{id}' for real Discord avatars
    DiscordBotToken    = '',    -- Optional fallback. Prefer server.cfg: set streetkings_discord_bot_token "BOT_TOKEN"

    DiscordGuildId = '',        -- Discord guild/server id used for VIP role checks
    DiscordVipRefreshMs = 300000,

    DiscordVipRoles = {
        vip_1 = {
            label = 'VIP',
            discordRoleId = '',
            priority = 10,
            color = '#facc15',
            icon = 'fa-solid fa-crown',
            aceGroup = 'group.vip',
            customization = {
                colors = true,
                borders = true,
                icons = true,
                effects = false,
                animated = false,
                glow = true,
                rainbow = false,
                backgrounds = true,
            },
            allowedPresets = {
                icons = { 'fa-solid fa-crown', 'fa-solid fa-star', 'fa-solid fa-gem' },
                borders = { 'thin', 'double', 'gold' },
                backgrounds = { 'dark', 'glass', 'gold' },
                bannerStyles = { 'default', 'vip', 'clean' },
                effects = { 'none', 'glow' },
            },
            permissions = {
                nametag = true,
                vipStudio = true,
            },
        },
        vip_2 = {
            label = 'VIP+',
            discordRoleId = '',
            priority = 20,
            color = '#9ee5ff',
            icon = 'fa-solid fa-gem',
            aceGroup = 'group.vipplus',
            customization = {
                colors = true,
                borders = true,
                icons = true,
                effects = true,
                animated = true,
                glow = true,
                rainbow = false,
                backgrounds = true,
            },
            allowedPresets = {
                icons = { 'fa-solid fa-gem', 'fa-solid fa-bolt', 'fa-solid fa-fire', 'fa-solid fa-crown' },
                borders = { 'thin', 'double', 'gold', 'neon' },
                backgrounds = { 'dark', 'glass', 'gold', 'neon' },
                bannerStyles = { 'default', 'vip', 'elite', 'clean' },
                effects = { 'none', 'glow', 'pulse' },
            },
            permissions = {
                nametag = true,
                vipStudio = true,
                animatedNametag = true,
            },
        },
        vip_3 = {
            label = 'VIP ELITE',
            discordRoleId = '',
            priority = 30,
            color = '#ff006a',
            icon = 'fa-solid fa-shield-halved',
            aceGroup = 'group.vipelite',
            customization = {
                colors = true,
                borders = true,
                icons = true,
                effects = true,
                animated = true,
                glow = true,
                rainbow = true,
                backgrounds = true,
            },
            allowedPresets = {
                icons = { 'fa-solid fa-shield-halved', 'fa-solid fa-crown', 'fa-solid fa-gem', 'fa-solid fa-fire', 'fa-solid fa-bolt' },
                borders = { 'thin', 'double', 'gold', 'neon', 'elite' },
                backgrounds = { 'dark', 'glass', 'gold', 'neon', 'elite' },
                bannerStyles = { 'default', 'vip', 'elite', 'clean', 'admin' },
                effects = { 'none', 'glow', 'pulse', 'scan', 'rainbow' },
            },
            permissions = {
                nametag = true,
                vipStudio = true,
                animatedNametag = true,
                eliteNametag = true,
            },
        },
    },

    DefaultNametagRoles = {
        pilot = {
            label = 'PILOTO',
            minLevel = 1,
            maxLevel = 24,
            priority = 1,
            color = '#9ca3af',
            icon = 'fa-solid fa-road',
        },
        pilot_pro = {
            label = 'PILOTO PRO',
            minLevel = 25,
            priority = 2,
            color = '#9ee5ff',
            icon = 'fa-solid fa-gauge-high',
        },
    },

    AdminNametag = {
        label = 'ADMIN',
        color = '#ef4444',
        icon = 'fa-solid fa-shield-halved',
        priority = 1000,
        bannerStyle = 'admin',
        effects = { 'none', 'glow', 'pulse', 'scan' },
        icons = { 'fa-solid fa-shield-halved', 'fa-solid fa-screwdriver-wrench', 'fa-solid fa-user-shield' },
        displayModes = { 'admin_plus_vip', 'admin_only', 'vip_only' },
    },
}
