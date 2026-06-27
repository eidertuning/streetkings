SKShopShared = SKShopShared or {}

SKShopShared.VISUAL_MOD_PRICE = 500 -- Price for visual mods
SKShopShared.COLOR_PRICE = 200 -- Price for colors
SKShopShared.NEON_PRICE = 2500 -- Price for neon kit
SKShopShared.NEON_UNLOCK_MOD_TYPE = 50
SKShopShared.NEON_UNLOCK_MOD_INDEX = 0
SKShopShared.NITROUS_UNLOCK_MOD_TYPE = 51
SKShopShared.NITROUS_UNLOCKS = {
    street = { index = 0, level = 3 },
    sport  = { index = 1, level = 5 },
    race   = { index = 2, level = 8 },
}

SKShopShared.DEFAULT_NEONS = {
    enabled = true,
    color = { r = 0, g = 180, b = 255 },
    sides = { front = true, back = true, left = true, right = true },
}

SKShopShared.PERFORMANCE_MOD_PRICES = { -- Price for performance mods
    [11] = 3500, -- Price for ENGINE
    [12] = 2800, -- Price for BRAKES
    [13] = 3200, -- Price for TRANSMISSION
    [15] = 2400, -- Price for SUSPENSION
    [18] = 4000, -- Price for TURBO
}

-- Gearbox upgrade prices (not a native vehicle mod — handled separately)
SKShopShared.GEARBOX_PRICES = {
    beginner = 2500,
    expert   = 3500,
}

SKShopShared.NITROUS_PRICES = {
    street = 3500,
    sport  = 6500,
    race   = 8500,
}

SKShopShared.TYPES = {
    visual = {
        key = 'visual',
        gameState = GameState.VISUALSHOP,
        label = 'Modificaciones Visuales',
        nui = 'modshop',
        allowsColors = true,
    },
    performance = {
        key = 'performance',
        gameState = GameState.PERFORMANCESHOP,
        label = 'Taller de Rendimiento',
        nui = 'perfshop',
        allowsColors = false,
    },
}

SKShopShared.LOCATIONS = {
    {
        id = 'visual_downtown',
        shopType = 'visual',
        coords = vector3(-361.0286, -132.9494, 38.3956),
        entryHeading = 70.0,
        exitHeading = 70.0,
        name = 'Modificaciones Visuales',
        display = vector4(-146.6166, -596.6301, 166.0, 180.0),
    },
    {
        id = 'performance_cypress',
        shopType = 'performance',
        coords = vector3(-1140.7384, -1986.4088, 11.5648),
        entryHeading = 342.9921,
        name = 'Taller de Rendimiento',
        display = vector4(-1154.8616, -2005.6747, 11.5648, 342.9921),
    },
    {
        id = 'performance_senora',
        shopType = 'performance',
        coords = vector3(1182.2902, 2650.6682, 36.1318),
        entryHeading = 317.0,
        name = 'Taller de Rendimiento',
        display = vector4(1175.3275, 2639.9341, 36.0645, 11.3386),
    },
    {
        id = 'visual_bennys',
        shopType = 'visual',
        coords = vector3(-205.9912, -1306.4044, 29.6278),
        entryHeading = 36.9921,
        name = 'Modificaciones Visuales',
        display = vector4(-211.2527, -1323.6791, 29.1897, 323.1496),
    },
    {
        id = 'performance_downtown',
        shopType = 'performance',
        coords = vector3(717.8505, -1088.2021, 20.6300),
        entryHeading = 93.5433,
        name = 'Taller de Rendimiento',
        display = vector4(730.9978, -1087.9648, 20.4784, 93.5433),
    },
    {
        id = 'visual_paleto',
        shopType = 'visual',
        coords = vector3(119.3934, 6618.1187, 30.1333),
        entryHeading = 223.9370,
        name = 'Modificaciones Visuales',
        display = vector4(110.4923, 6626.9404, 30.0828, 226.7717),
    },
    {
        id = 'performance_paleto',
        shopType = 'performance',
        coords = vector3(-196.2989, 6270.6855, 29.7964),
        entryHeading = 12.0,
        name = 'Taller de Rendimiento',
        display = vector4(730.9978, -1087.9648, 20.4784, 93.5433),
    },
    {
        id = 'visual_sandyshores',
        shopType = 'visual',
        coords = vector3(1778.8616, 3336.3296, 39.4176),
        entryHeading = 12.0,
        name = 'Modificaciones Visuales',
        display = vector4(110.4923, 6626.9404, 30.0828, 226.7717),
    }
}
