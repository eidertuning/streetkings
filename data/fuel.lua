SKFuelConfig = {
    enabled = true,

    defaults = {
        fuelLevel = 100.0,
        condition = 100.0,
    },

    consumption = {
        tickMs = 1000,
        saveIntervalMs = 15000,
        saveDelta = 0.35,
        idlePerSecond = 0.006,
        rpmPerSecond = 0.026,
        speedPerMeterPerSecond = 0.0014,
        lowFuelThreshold = 12.0,
        emptyEngineHealth = 120.0,
        byClass = {
            STARTER = 0.92,
            C = 1.0,
            B = 1.08,
            A = 1.18,
            S = 1.32,
            DEFAULT = 1.0,
        },
        byGtaClass = {
            [0] = 1.0,  -- Compacts
            [1] = 1.04, -- Sedans
            [2] = 1.22, -- SUVs
            [3] = 1.06, -- Coupes
            [4] = 1.18, -- Muscle
            [5] = 1.14, -- Sports Classics
            [6] = 1.18, -- Sports
            [7] = 1.34, -- Super
            [8] = 0.72, -- Motorcycles
            [9] = 1.26, -- Off-road
            [10] = 1.38, -- Industrial
            [11] = 1.42, -- Utility
            [12] = 1.18, -- Vans
            [18] = 1.12, -- Emergency
            DEFAULT = 1.0,
        },
    },

    station = {
        refuelVehicle = true,
        repairVehicle = true,
        washVehicle = true,
        fuelPricePerPercent = 12,
    },

    tablet = {
        enabled = true,
        priceMultiplier = 2.0,
    },
}
