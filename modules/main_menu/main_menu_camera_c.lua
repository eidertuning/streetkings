SKMainMenu = SKMainMenu or {}

local ROAM_POSITIONS = {
    vec3( 178.33,  -185.00,  54.17),
    vec3(-278.82,  -954.21,  31.22),
    vec3( 372.96,  -659.52,  28.70),
    vec3(-710.40,  -909.87,  19.22),
    vec3( 801.19, -1178.35,  26.37),
    vec3(-118.25,  -805.91,  31.42),
    vec3( 230.20,  -889.24,  30.49),
    vec3(-567.11,  -722.39,  33.19),
    vec3( 127.85,   -242.37, 54.55),
    vec3(-1379.77,  -592.45, 30.32),
}

local MENU_CAM_CYCLE_MS = 18000
local MENU_CAM_FADE_MS = 700
local MENU_CAM_NEARBY_RADIUS = 125.0
local MENU_CAM_MIN_SPEED_MS = 1.5
local MENU_CAM_TIMESCALE_SPEED_MS = 8.0
local MENU_CAM_TIMESCALE_RELEASE_MS = 6.0
local MENU_CAM_TIMESCALE_SLOW = 0.2
local MENU_CAM_TIMESCALE_NORMAL = 1.0
local MENU_CAM_BOOTSTRAP_RETRY_MS = 500
local MENU_CAM_BOOTSTRAP_SETTLE_MS = 3500
local MENU_CAM_BOOTSTRAP_ATTEMPTS_PER_POSITION = 8

local chaseCam = nil
local chaseVehicle = nil
local mainMenuTimeSlowMo = false
local sceneGeneration = 0

local HOOD_CAM_BONES = { 'bonnet' }

---@param generation integer
---@return boolean
local function isMainMenuSceneActive(generation)
    return generation == sceneGeneration
end

---@return nil
local function destroyChaseCamera()
    if chaseCam then
        SetCamUseShallowDofMode(chaseCam, false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(chaseCam, false)
        chaseCam = nil
    end
    chaseVehicle = nil
    mainMenuTimeSlowMo = false
    SetTimeScale(MENU_CAM_TIMESCALE_NORMAL)
end

---@param vehicle integer
---@return boolean
local function isMovingNpcDrivenVehicle(vehicle)
    if GetPedInVehicleSeat(vehicle, -1) == 0 then
        return false
    end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if IsPedAPlayer(driver) then
        return false
    end

    return GetEntitySpeed(vehicle) > MENU_CAM_MIN_SPEED_MS
end

---@param excludeVehicle integer|nil
---@return integer[]
local function collectNpcDriverVehicles(excludeVehicle)
    local pool = GetGamePool('CVehicle')
    local candidates = {}

    for i = 1, #pool do
        local vehicle = pool[i]
        if excludeVehicle and vehicle == excludeVehicle then
        elseif isMovingNpcDrivenVehicle(vehicle) then
            candidates[#candidates + 1] = vehicle
        end
    end

    return candidates
end

---@param origin vector3
---@param maxDist number
---@param excludeVehicle integer|nil
---@return integer[]
local function collectNearbyNpcDriverVehicles(origin, maxDist, excludeVehicle)
    local pool = GetGamePool('CVehicle')
    local candidates = {}

    for i = 1, #pool do
        local vehicle = pool[i]
        if excludeVehicle and vehicle == excludeVehicle then
        elseif isMovingNpcDrivenVehicle(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            if #(vehicleCoords - origin) <= maxDist then
                candidates[#candidates + 1] = vehicle
            end
        end
    end

    return candidates
end

---@param seed vector3
---@return vector3
local function getRoamTrafficNode(seed)
    local found, roadPos = GetClosestVehicleNodeWithHeading(seed.x, seed.y, seed.z, 0, 3.0, 0)
    if found then
        return vector3(roadPos.x, roadPos.y, roadPos.z)
    end

    return seed
end

---@param vehicle integer
---@return integer
local function getMenuCamVehicleBoneIndex(vehicle)
    for i = 1, #HOOD_CAM_BONES do
        local idx = GetEntityBoneIndexByName(vehicle, HOOD_CAM_BONES[i])
        if idx ~= -1 then
            return idx
        end
    end

    return -1
end

---@param vehicle integer
---@return boolean
local function attachToTrafficVehicle(vehicle)
    local boneIndex = getMenuCamVehicleBoneIndex(vehicle)
    if boneIndex == -1 then
        return false
    end

    DetachEntity(cache.ped, true, true)
    AttachEntityToEntity(cache.ped, vehicle, 0, 0, 0, -20.0, 0, 0, 0, false, false, false, false, 20, true)

    destroyChaseCamera()

    local camera = CreateCamera('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(camera, true)
    RenderScriptCams(true, false, 0, true, true)
    AttachCamToVehicleBone(
        camera,
        vehicle,
        boneIndex,
        true,
        0.0,
        0.0,
        0.0,
        0.0,
        0.38,
        0.30,
        false
    )
    SetCamUseShallowDofMode(camera, true)
    SetCamNearDof(camera, 4.0)
    SetCamFarDof(camera, 22.0)
    SetCamDofStrength(camera, 0.5)

    chaseCam = camera
    chaseVehicle = vehicle

    return true
end

---@param candidates integer[]
---@return boolean
local function tryAttachFromCandidates(candidates)
    local candidateCount = #candidates
    if candidateCount == 0 then
        return false
    end

    local start = math.random(candidateCount)
    for offset = 0, candidateCount - 1 do
        local vehicle = candidates[((start + offset - 1) % candidateCount) + 1]
        if attachToTrafficVehicle(vehicle) then
            return true
        end
    end

    return false
end

---@return boolean
local function tryPickRandomTrafficShot()
    return tryAttachFromCandidates(collectNpcDriverVehicles(nil))
end

---@param excludeVehicle integer|nil
---@return boolean
local function tryPickTrafficShotPreferNearby(excludeVehicle)
    local origin = GetEntityCoords(cache.ped)
    local candidates = collectNearbyNpcDriverVehicles(origin, MENU_CAM_NEARBY_RADIUS, excludeVehicle)

    if #candidates == 0 then
        candidates = collectNpcDriverVehicles(excludeVehicle)
    end

    if #candidates == 0 then
        candidates = collectNpcDriverVehicles(nil)
    end

    return tryAttachFromCandidates(candidates)
end

---@param generation integer
---@return nil
local function startCameraBootstrap(generation)
    CreateThread(function()
        local attemptsAtPosition = 0
        while isMainMenuSceneActive(generation) do
            if chaseVehicle and DoesEntityExist(chaseVehicle) then
                return
            end

            if tryPickTrafficShotPreferNearby(nil) then
                return
            end

            attemptsAtPosition = attemptsAtPosition + 1
            if attemptsAtPosition >= MENU_CAM_BOOTSTRAP_ATTEMPTS_PER_POSITION then
                local pos = getRoamTrafficNode(ROAM_POSITIONS[math.random(#ROAM_POSITIONS)])
                SetEntityCoords(cache.ped, pos.x, pos.y, pos.z, false, false, false, false)
                attemptsAtPosition = 0
                Wait(MENU_CAM_BOOTSTRAP_SETTLE_MS)
            else
                Wait(MENU_CAM_BOOTSTRAP_RETRY_MS)
            end
        end
    end)
end

---@param generation integer
---@return nil
local function startCameraCycle(generation)
    CreateThread(function()
        while isMainMenuSceneActive(generation) do
            Wait(MENU_CAM_CYCLE_MS)

            if not isMainMenuSceneActive(generation) then
                return
            end

            if not chaseVehicle or not DoesEntityExist(chaseVehicle) then
                destroyChaseCamera()
                tryPickRandomTrafficShot()
            else
                local previousVehicle = chaseVehicle

                DoScreenFadeOut(MENU_CAM_FADE_MS)
                while isMainMenuSceneActive(generation) and not IsScreenFadedOut() do
                    Wait(0)
                end

                if not isMainMenuSceneActive(generation) then
                    DoScreenFadeIn(0)
                    return
                end

                destroyChaseCamera()
                DetachEntity(cache.ped, true, true)

                if not tryPickTrafficShotPreferNearby(previousVehicle) then
                    tryPickRandomTrafficShot()
                end

                DoScreenFadeIn(MENU_CAM_FADE_MS)
            end
        end
    end)
end

---@return boolean
function SKMainMenu.isCameraReady()
    return chaseCam ~= nil
end

---@return nil
function SKMainMenu.enterScene()
    sceneGeneration = sceneGeneration + 1
    local generation = sceneGeneration

    if not chaseCam then
        destroyChaseCamera()
        DetachEntity(cache.ped, true, true)
        if not tryPickRandomTrafficShot() then
            startCameraBootstrap(generation)
        end
    end

    startCameraCycle(generation)
end

---@return nil
function SKMainMenu.leaveScene()
    sceneGeneration = sceneGeneration + 1
    destroyChaseCamera()
    DetachEntity(cache.ped, true, true)
end

---@return nil
function SKMainMenu.tickScene()
    if chaseVehicle and not DoesEntityExist(chaseVehicle) then
        destroyChaseCamera()
    end

    if chaseVehicle and DoesEntityExist(chaseVehicle) then
        local speed = GetEntitySpeed(chaseVehicle)
        if mainMenuTimeSlowMo then
            if speed < MENU_CAM_TIMESCALE_RELEASE_MS then
                mainMenuTimeSlowMo = false
            end
        elseif speed > MENU_CAM_TIMESCALE_SPEED_MS then
            mainMenuTimeSlowMo = true
        end

        if mainMenuTimeSlowMo then
            SetTimeScale(MENU_CAM_TIMESCALE_SLOW)
        else
            SetTimeScale(MENU_CAM_TIMESCALE_NORMAL)
        end
    end

    if chaseCam and chaseVehicle then
        local aim = GetOffsetFromEntityInWorldCoords(chaseVehicle, 0.0, 8.0, 0.35)
        PointCamAtCoord(chaseCam, aim.x, aim.y, aim.z)
        SetUseHiDof()
    end
end