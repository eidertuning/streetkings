SKDealershipConfig = {
    CLASS_ORDER = { 'C', 'B', 'A', 'S' },
    DEALER_TYPES = {
        tuner     = { label = 'Coches Tuners' },
        sportscar = { label = 'Coches Deportivos' },
        muscle    = { label = 'Coches Muscle' },
        offroad   = { label = 'Todo Terreno' },
    },
    LOCATIONS = {
        {
            id             = 'dealer_tuner',
            dealerType     = 'tuner',
            coords         = vector3(-53.7626, -1110.3956, 26.1458),
            displayCoords  = vector3(-41.5912, -1099.4769, 26.1289),
            displayHeading = 0.0,
            exitHeading    = 160.0,
            name           = 'Coches Tuners',
        },
        {
            id            = 'dealer_sportscar',
            dealerType    = 'sportscar',
            coords        = vector3(-809.2352, -227.9604, 35.4410),
            displayCoords = vector3(-83.9077, -820.9846, 221.3004),
            displayHeading = 221.1024,
            exitHeading    = 221.1024,
            name = 'Coches Deportivos',
        },
        {
            id            = 'dealer_muscle',
            dealerType    = 'muscle',
            coords        = vector3(-67.1077, -1826.6505, 25.2468),
            displayCoords = vector3(978.4615, -3002.0703, -40.3099),
            displayHeading = 90.0,
            exitHeading    = 238.0,
            name = 'Coches Muscle',
        },
        {
            id             = 'dealer_offroad',
            dealerType     = 'offroad',
            coords         = vector3(1242.2241, 2703.6133, 36.3004),
            displayCoords  = vector4(1223.7363, 2708.2549, 36.3004, 178.5827),
            displayHeading = 180.0,
            exitHeading    = 218.2677,
            name = 'Todo Terreno',
        }
    },
}
