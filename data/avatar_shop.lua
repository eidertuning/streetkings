SKAvatarData = {}

SKAvatarData.ScenePositions = {
    vector3(430.0352, -800.1230, 28.4821),
    vector3(-1187.8945, -768.8571, 16.3165),
    vector3(-711.4945, -155.2747, 36.4015),
}

SKAvatarData.SceneHeading = 180.0

SKAvatarData.ClothingStores = {
    {
        id      = 'binco',
        name    = 'Binco',
        marker  = vector3(411.3188, -808.0818, 28.5714),
        scene   = vector3(430.0352, -800.1230, 28.4821),
        heading = 180.0,
        blip    = 73,
    },
    {
        id      = 'suburban',
        name    = 'Suburban',
        marker  = vector3(-1210.7142, -785.4849, 16.4043),
        scene   = vector3(-1187.8945, -768.8571, 16.3165),
        heading = 180.0,
        blip    = 73,
    },
    {
        id      = 'posonby',
        name    = 'Posonby',
        marker  = vector3(-722.8138, -161.3421, 36.3812),
        scene   = vector3(-711.4945, -155.2747, 36.4015),
        heading = 180.0,
        blip    = 73,
    },
    
}

SKAvatarData.Models = {
    male = 'mp_m_freemode_01',
    female = 'mp_f_freemode_01',
}

SKAvatarData.ClothingCategories = {
    { key = 'mask', kind = 'component', slot = 1, label = 'Masks', price = 120 },
    { key = 'torso', kind = 'component', slot = 3, label = 'Arms', price = 140 },
    { key = 'shirts', kind = 'component', slot = 8, label = 'Shirts', price = 130 },
    { key = 'tops', kind = 'component', slot = 11, label = 'Jackets', price = 160 },
    { key = 'legs', kind = 'component', slot = 4, label = 'Pants', price = 140 },
    { key = 'shoes', kind = 'component', slot = 6, label = 'Shoes', price = 130 },
    { key = 'bags', kind = 'component', slot = 5, label = 'Bags', price = 120 },
    { key = 'chains', kind = 'component', slot = 7, label = 'Chains', price = 110 },
    { key = 'armor', kind = 'component', slot = 9, label = 'Armor', price = 150 },
    { key = 'decals', kind = 'component', slot = 10, label = 'Decals', price = 110 },

    { key = 'hats', kind = 'prop', slot = 0, label = 'Hats', price = 110 },
    { key = 'glasses', kind = 'prop', slot = 1, label = 'Glasses', price = 110 },
    { key = 'ears', kind = 'prop', slot = 2, label = 'Ears', price = 90 },
    { key = 'watches', kind = 'prop', slot = 6, label = 'Watches', price = 100 },
    { key = 'bracelets', kind = 'prop', slot = 7, label = 'Bracelets', price = 90 },
}

SKAvatarData.ClothingCategoriesByKey = {}
SKAvatarData.ClothingCategoriesBySlot = {
    component = {},
    prop = {},
}

for _, category in ipairs(SKAvatarData.ClothingCategories) do
    SKAvatarData.ClothingCategoriesByKey[category.key] = category
    SKAvatarData.ClothingCategoriesBySlot[category.kind][category.slot] = category
end

SKAvatarData.DefaultWearables = {
    male = {
        model = SKAvatarData.Models.male,
        headBlend = {
            shapeFirst = 0,
            shapeSecond = 0,
            shapeThird = 0,
            skinFirst = 0,
            skinSecond = 0,
            skinThird = 0,
            shapeMix = 0.0,
            skinMix = 0.0,
            thirdMix = 0.0,
        },
        hair = {
            style = 0,
            color = 0,
            highlight = 0,
            texture = 0,
        },
        components = {
            { component_id = 0, drawable = 0, texture = 0 },
            { component_id = 1, drawable = 0, texture = 0 },
            { component_id = 2, drawable = 0, texture = 0 },
            { component_id = 3, drawable = 0, texture = 0 },
            { component_id = 4, drawable = 0, texture = 0 },
            { component_id = 5, drawable = 0, texture = 0 },
            { component_id = 6, drawable = 0, texture = 0 },
            { component_id = 7, drawable = 0, texture = 0 },
            { component_id = 8, drawable = 0, texture = 0 },
            { component_id = 9, drawable = 0, texture = 0 },
            { component_id = 10, drawable = 0, texture = 0 },
            { component_id = 11, drawable = 0, texture = 0 },
        },
        props = {
            { prop_id = 0, drawable = -1, texture = -1 },
            { prop_id = 1, drawable = -1, texture = -1 },
            { prop_id = 2, drawable = -1, texture = -1 },
            { prop_id = 6, drawable = -1, texture = -1 },
            { prop_id = 7, drawable = -1, texture = -1 },
        },
    },
    female = {
        model = SKAvatarData.Models.female,
        headBlend = {
            shapeFirst = 45,
            shapeSecond = 21,
            shapeThird = 0,
            skinFirst = 20,
            skinSecond = 15,
            skinThird = 0,
            shapeMix = 0.3,
            skinMix = 0.1,
            thirdMix = 0.0,
        },
        hair = {
            style = 0,
            color = 0,
            highlight = 0,
            texture = 0,
        },
        components = {
            { component_id = 0, drawable = 0, texture = 0 },
            { component_id = 1, drawable = 0, texture = 0 },
            { component_id = 2, drawable = 0, texture = 0 },
            { component_id = 3, drawable = 0, texture = 0 },
            { component_id = 4, drawable = 0, texture = 0 },
            { component_id = 5, drawable = 0, texture = 0 },
            { component_id = 6, drawable = 0, texture = 0 },
            { component_id = 7, drawable = 0, texture = 0 },
            { component_id = 8, drawable = 0, texture = 0 },
            { component_id = 9, drawable = 0, texture = 0 },
            { component_id = 10, drawable = 0, texture = 0 },
            { component_id = 11, drawable = 0, texture = 0 },
        },
        props = {
            { prop_id = 0, drawable = -1, texture = -1 },
            { prop_id = 1, drawable = -1, texture = -1 },
            { prop_id = 2, drawable = -1, texture = -1 },
            { prop_id = 6, drawable = -1, texture = -1 },
            { prop_id = 7, drawable = -1, texture = -1 },
        },
    },
}
