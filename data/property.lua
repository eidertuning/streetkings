SKProperty = {
    WARP_PRICE = 200, -- Price to warp to an owned property
    FREEROAM_MARKER_DISTANCE = 90.0, -- Distance to show the property marker
    FREEROAM_INTERACT_DISTANCE = 4.0, -- Distance to interact with the property
    INTERIOR_EXIT_DISTANCE = 2.25, -- Distance to exit the property interior (on foot)
}

local function v4(x, y, z, w)
    return vector4(x, y, z, w)
end

local function v3(x, y, z)
    return vector3(x, y, z)
end

local function v4z(x, y, z)
    return vector4(x, y, z, 0.0)
end

local function property(id, name, building, description, category, purchasePrice, exterior, interiorDoor, interiorIpl, wardrobe)
    return {
        id = id,
        name = name,
        building = building,
        description = description,
        category = category,
        purchasePrice = purchasePrice,
        exterior = exterior,
        interiorDoor = interiorDoor,
        interiorIpl = interiorIpl or '',
        wardrobe = wardrobe,
        mapLabel = ('%s - %s'):format(building, name),
        markerColorOwned = { 70, 200, 120, 150 },
        markerColorAvailable = { 255, 209, 71, 150 },
        blipColorOwned = 2,
        blipColorAvailable = 5,
        exteriorMarkerScale = v3(2.8, 2.8, 2.4),
        interiorMarkerScale = v3(1.25, 1.25, 1.15),
    }
end

local APARTMENT_INTERIORS = {
    DellPerroHeightsApt4 = {
        exit = v4(-1453.02, -539.5, 74.04, 35.33),
        wardrobe = v4(-1451.96, -540.78, 72.84, 120.89),
    },
    DellPerroHeightsApt7 = {
        exit = v4z(-1458.5, -520.89, 56.93),
    },
    ['4IntegrityWayApt28'] = {
        exit = v4(-30.58, -595.4, 80.03, 246.95),
        wardrobe = v4(-26.38, -598.14, 78.83, 343.69),
    },
    ['4IntegrityWayApt30'] = {
        exit = v4(-17.41, -588.17, 90.11, 338.23),
    },
    RichardMajesticApt2 = {
        exit = v4(-913.99, -365.81, 114.27, 115.17),
        wardrobe = v4(-910.85, -367.93, 113.07, 198.50),
    },
    TinselTowersApt42 = {
        exit = v4(-604.06, 58.99, 98.2, 91.45),
        wardrobe = v4(-594.6238, 55.8012, 96.9997, 180.7864),
    },
}

SKProperty.CATALOG = {
    property(
        'DellPerroHeightsApt4',
        'Apt 4',
        'Del Perro Heights Apt',
        'Experience serene ocean vistas in a peaceful, exclusive Del Perro Heights residence.',
        'apartment',
        25000,
        v4(-1415.0901, -529.1473, 29.8469, 215.4331),
        APARTMENT_INTERIORS.DellPerroHeightsApt4.exit,
        '',
        APARTMENT_INTERIORS.DellPerroHeightsApt4.wardrobe
    ),
    property(
        '4IntegrityWayApt28',
        'Apt 28',
        '4 Integrity Way Apt',
        'Settle into a vibrant, up-and-coming neighborhood where growth is just outside your window—perfect for those who love to be part of the city\'s evolution.',
        'apartment',
        25000,
        v4(-74.3604, -610.8923, 34.5817, 340.1575),
        APARTMENT_INTERIORS['4IntegrityWayApt28'].exit,
        '',
        APARTMENT_INTERIORS['4IntegrityWayApt28'].wardrobe
    ),
    property(
        'RichardMajesticApt2',
        'Apt 2',
        'Richard Majestic Apt',
        'Enjoy breathtaking luxury living just steps from the vibrant energy of the city in this prestigious Richard Majestic condo.',
        'apartment',
        25000,
        v4(-925.7538, -408.4484, 35.7949, 119.0551),
        APARTMENT_INTERIORS.RichardMajesticApt2.exit,
        '',
        APARTMENT_INTERIORS.RichardMajesticApt2.wardrobe
    ),
    property(
        'TinselTowersApt42',
        'Apt 42',
        'Tinsel Towers Apt',
        'Experience refined city living in a prestigious Tinsel Towers residence, offering contemporary comfort and sweeping skyline views in the heart of Los Santos.',
        'apartment',
        25000,
        v4(-625.1340, 56.7165, 42.0293, 90.7087),
        APARTMENT_INTERIORS.TinselTowersApt42.exit,
        '',
        APARTMENT_INTERIORS.TinselTowersApt42.wardrobe
    ),
}
