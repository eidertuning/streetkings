-- Cinematic vehicle warp — adapted from bbv-warp by BuddyNotFound
-- https://github.com/BuddyNotFound/bbv-warp (MIT License)

local warping = false

local function getCamBehindVehicle(vehicle)
    local pos = GetEntityCoords(vehicle)
    local fwd = GetEntityForwardVector(vehicle)
    return vector3(pos.x - fwd.x * 3, pos.y - fwd.y * 3, pos.z - fwd.z * 2), pos
end

function SKC.Warp(coords, heading)
    if warping then return end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
        if heading then SetEntityHeading(ped, heading) end
        return
    end
    warping = true
    Cinematic = true
    local gpCoord = GetGameplayCamCoord()
    local gpRot = GetGameplayCamRot(2)
    local gpFov = GetGameplayCamFov()
    local fromCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        gpCoord.x, gpCoord.y, gpCoord.z,
        gpRot.x, gpRot.y, gpRot.z,
        gpFov, false, 2)
    SetCamActive(fromCam, true)
    RenderScriptCams(true, false, 0, true, true)
    local camPos, vehPos = getCamBehindVehicle(vehicle)
    local toCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    SetCamCoord(toCam, camPos.x, camPos.y, camPos.z + 0.2)
    PointCamAtCoord(toCam, vehPos.x, vehPos.y, vehPos.z + 0.2)
    SetCamFov(toCam, gpFov - 20)
    SetCamActiveWithInterp(toCam, fromCam, 1500, true, true)
    Wait(1500)
    SetPedCoordsKeepVehicle(ped, coords.x, coords.y, coords.z)
    if heading then SetEntityHeading(ped, heading) end
    local newCamPos, newVehPos = getCamBehindVehicle(vehicle)
    SetCamCoord(toCam, newCamPos.x, newCamPos.y, newCamPos.z + 0.2)
    PointCamAtCoord(toCam, newVehPos.x, newVehPos.y, newVehPos.z + 0.2)
    Wait(1000)
    RenderScriptCams(false, true, 1500, false, false)
    Wait(1500)
    DestroyCam(fromCam, false)
    DestroyCam(toCam, false)
    Cinematic = false
    warping = false
end

function SKC.WarpToWaypoint()
    local blipMarker = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blipMarker) then
        return false, _L('lua.notify.no_waypoint_set')
    end

    local ped = PlayerPedId()
    local coords = GetBlipInfoIdCoord(blipMarker)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local oldCoords = GetEntityCoords(ped)

    local x, y = coords.x, coords.y
    local groundZ = 800.0
    local zStart = 900.0
    local found = false
    local target = vehicle > 0 and vehicle or ped

    FreezeEntityPosition(target, true)

    for i = zStart, 0, -25.0 do
        local z = i
        if (i % 2) ~= 0 then
            z = zStart - i
        end

        NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
        local curTime = GetGameTimer()
        while IsNetworkLoadingScene() do
            if GetGameTimer() - curTime > 1000 then
                break
            end
            Wait(0)
        end
        NewLoadSceneStop()
        SetPedCoordsKeepVehicle(ped, x, y, z)

        while not HasCollisionLoadedAroundEntity(ped) do
            RequestCollisionAtCoord(x, y, z)
            if GetGameTimer() - curTime > 1000 then
                break
            end
            Wait(0)
        end

        found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
        if found then
            Wait(0)
            SetPedCoordsKeepVehicle(ped, x, y, groundZ)
            break
        end
        Wait(0)
    end

    FreezeEntityPosition(target, false)

    if not found then
        SetPedCoordsKeepVehicle(ped, oldCoords.x, oldCoords.y, oldCoords.z - 1.0)
        return false, _L('lua.notify.waypoint_ground_failed')
    end

    SetPedCoordsKeepVehicle(ped, x, y, groundZ)
    return true, ''
end

exports('WarpPlayer', SKC.Warp)
exports('WarpToWaypoint', SKC.WarpToWaypoint)
