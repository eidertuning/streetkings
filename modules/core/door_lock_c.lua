local LOCKED_DOORS = {
    { model = 0xFFFFFFFFDF325E57, coords = vector3(-355.0292, -135.1577, 41.9908) },
    { model = 0xFFFFFFFFDF325E57, coords = vector3(-1146.6943, -1991.9410, 16.1605) },
    { model = 0xFFFFFFFFCEF38A2C, coords = vector3(1182.3069, 2644.1672, 40.5074) },
    { model = 0xFFFFFFFFCEF38A2C, coords = vector3(1174.6556, 2644.1548, 40.5080) },
    { model = 0xFFFFFFFFE684E276, coords = vector3(-205.6828, -1310.6826, 34.9925) },
    { model = 0x101CE8F5, coords = vector3(723.1047, -1088.8312, 23.2802) },
    { model = 0xFFFFFFFFCEF38A2C, coords = vector3(108.8572, 6617.8696, 32.7158) },
    { model = 0xFFFFFFFFCEF38A2C, coords = vector3(114.3208, 6623.2261, 32.7171) },
}

for i, door in ipairs(LOCKED_DOORS) do
    AddDoorToSystem(i, door.model, door.coords.x, door.coords.y, door.coords.z, false, false, false)
    DoorSystemSetDoorState(i, 4, false, false)
    DoorSystemSetDoorState(i, 1, false, false)
end