local MISSION_ID     = 'local_legend'

local function findMissionById(id)
    for _, chapter in ipairs(SKMissions.chapters or {}) do
        for _, mission in ipairs(chapter.missions or {}) do
            if mission.id == id then return mission end
        end
    end
end

local MISSION_DEF   = findMissionById(MISSION_ID)
local MEET_COORDS   = MISSION_DEF.startBlip.coords
local RACERS         = MISSION_DEF.carMeetRacers or {}
local OWNER_RADIUS   = 100.0
local TICK_MS        = 2000

local currentOwner = nil
local spawned = { vehicles = {}, peds = {} }

local exempt = {}
local EXEMPT_TTL_MS = 30000

local function clearSpawned()
    local keptVehicles, keptPeds = {}, {}
    for _, ent in ipairs(spawned.peds) do
        if exempt[ent] then
            keptPeds[#keptPeds + 1] = ent
        elseif DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    for _, ent in ipairs(spawned.vehicles) do
        if exempt[ent] then
            keptVehicles[#keptVehicles + 1] = ent
        elseif DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    spawned.vehicles = keptVehicles
    spawned.peds = keptPeds
end

local function releaseOwner()
    clearSpawned()
    if next(exempt) == nil then
        currentOwner = nil
    end
end

local function scheduleExemptCleanup()
    SetTimeout(EXEMPT_TTL_MS, function()
        for ent in pairs(exempt) do
            if DoesEntityExist(ent) then DeleteEntity(ent) end
        end
        exempt = {}
    end)
end

---@param missions table
---@return boolean
local function missionGateOpen(missions)
    if type(missions) ~= 'table' then return false end
    if missions.currentMissionId == MISSION_ID then
        return true
    end

    if missions.currentMissionId then return false end
    if missions.completed and missions.completed[MISSION_ID] then return false end
    if (missions.nextAvailableAt or 0) > os.time() then return false end

    local pending = SKMissionDefs and SKMissionDefs.getNext(missions)
    return pending ~= nil and pending.id == MISSION_ID
end

---@param src integer
---@return boolean
local function isEligible(src)
    if not src or not SKSaves or not SKSaves.hasActiveSave(src) then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end

    local missions = SKSaves.read(src, 'missions')
    if not missionGateOpen(missions) then return false end

    -- Once the mission is actually running the racers must persist regardless
    -- of how far the player drives during the race.
    if missions and missions.currentMissionId == MISSION_ID then
        return true
    end

    local pcoords = GetEntityCoords(ped)
    local dx = pcoords.x - MEET_COORDS.x
    local dy = pcoords.y - MEET_COORDS.y
    local dz = pcoords.z - MEET_COORDS.z
    return (dx * dx + dy * dy + dz * dz) <= (OWNER_RADIUS * OWNER_RADIUS)
end

local function pickOwner()
    for _, idStr in ipairs(GetPlayers()) do
        local src = tonumber(idStr)
        if src and isEligible(src) then return src end
    end
    return nil
end

local function spawnForOwner(src)
    if not currentOwner then return end

    for _, preset in ipairs(RACERS) do
        local c = preset.coords
        if not c then goto nextPreset end

        local vx, vy, vz, heading = c.x, c.y, c.z, c.w or 0.0

        local veh = CreateVehicleServerSetter(preset.vehicle, 'automobile', vx, vy, vz, heading)
        if veh ~= 0 and DoesEntityExist(veh) then
            SetEntityOrphanMode(veh, 2)
            SetVehicleDoorsLocked(veh, 2)
            Entity(veh).state:set('skMeetRacer', true, true)
            table.insert(spawned.vehicles, veh)

            local ped = CreatePed(4, preset.ped, vx, vy, vz + 1.0, heading, true, false)
            if ped ~= 0 and DoesEntityExist(ped) then
                SetEntityOrphanMode(ped, 2)
                SetPedIntoVehicle(ped, veh, -1)
                Entity(ped).state:set('skMeetRacer', true, true)
                Entity(ped).state:set('skMeetRacerVeh', NetworkGetNetworkIdFromEntity(veh), true)
                table.insert(spawned.peds, ped)
            end
        end

        ::nextPreset::
    end
end

CreateThread(function()
    while true do
        Wait(TICK_MS)

        if currentOwner then
            if not isEligible(currentOwner) then
                releaseOwner()
            end
        else
            local candidate = pickOwner()
            if candidate then
                currentOwner = candidate
                spawnForOwner(candidate)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    if currentOwner == src then
        releaseOwner()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for ent in pairs(exempt) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    exempt = {}
    releaseOwner()
end)

RegisterNetEvent('streetkings:meet:exemptChallenger', function(vehNetId, pedNetId)
    local src = source --[[@as integer]]
    if currentOwner ~= src then return end

    if type(vehNetId) == 'number' then
        local veh = NetworkGetEntityFromNetworkId(vehNetId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            exempt[veh] = true
            SetEntityOrphanMode(veh, 2)
        end
    end
    if type(pedNetId) == 'number' then
        local ped = NetworkGetEntityFromNetworkId(pedNetId)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            exempt[ped] = true
            SetEntityOrphanMode(ped, 2)
        end
    end
end)

AddEventHandler('streetkings:server:recordNpcRace', function(_src)
    if next(exempt) ~= nil then
        scheduleExemptCleanup()
    end
end)

RegisterNetEvent('streetkings:npcchallenge:cancel', function()
    if next(exempt) ~= nil then
        scheduleExemptCleanup()
    end
end)