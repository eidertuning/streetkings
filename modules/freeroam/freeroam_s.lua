SKFreeroamServer = {}

local VEHICLE_CHECK_INTERVAL = 1000
local NON_FREEROAM_BUCKET_OFFSET = 1000
local PLAYER_VEHICLE_LOCK_STATE = 2
local HOSPITAL_BILL_AMOUNT = 1000

--- source -> true for every player currently in FREEROAM
---@type table<integer, true>
local freeroamPlayers = {}

--- source -> assigned vehicle net ID
---@type table<integer, integer>
local assignedNetIds = {}
local spawnInProgress = {}

---@param src integer
local function deleteAssignedVehicle(src)
    local assignedNetId = assignedNetIds[src]
    if not assignedNetId then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(assignedNetId)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end

    assignedNetIds[src] = nil
end

---@param src integer
---@return integer
local function getNonFreeroamBucket(src)
    return NON_FREEROAM_BUCKET_OFFSET + src
end

---@param src integer
local function syncPlayerRoutingBucket(src)
    local mpBucket = SKMultiplayerServer.getBucketForSource(src)
    if mpBucket ~= nil then
        SetPlayerRoutingBucket(src, mpBucket)
        return
    end

    if freeroamPlayers[src] then
        SetPlayerRoutingBucket(src, 0)
        return
    end

    local sharedBucket = SKPropertyInviteServer.getSharedBucket(src)
    if sharedBucket then
        SetPlayerRoutingBucket(src, sharedBucket)
        return
    end

    SetPlayerRoutingBucket(src, getNonFreeroamBucket(src))
end

local function syncFreeroamVehicleNetIds()
    local netIds = {}
    for src in pairs(freeroamPlayers) do
        local netId = assignedNetIds[src]
        if netId then
            netIds[#netIds + 1] = netId
        end
    end

    TriggerClientEvent('streetkings:freeroam:setNoCollisionVehicles', -1, netIds)
end

---@param src integer
function SKFreeroamServer.syncRoutingBucket(src)
    syncPlayerRoutingBucket(src)
end

---@param src integer
function SKFreeroamServer.deleteAssignedVehicle(src)
    deleteAssignedVehicle(src)
    if freeroamPlayers[src] then
        syncFreeroamVehicleNetIds()
    end
end

--- Detach the currently-assigned freeroam vehicle without deleting it
--- Transfers ownership of the entity to whichever system takes over
---@param src integer
---@return integer|nil netId
function SKFreeroamServer.detachAssignedVehicle(src)
    local netId = assignedNetIds[src]
    if not netId then return nil end
    assignedNetIds[src] = nil
    if freeroamPlayers[src] then
        syncFreeroamVehicleNetIds()
    end
    return netId
end

--- Move an existing (already-spawned) vehicle to a new routing bucket
---@param netId integer
---@param bucket integer
---@return boolean
function SKFreeroamServer.moveVehicleToBucket(netId, bucket)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    SetEntityRoutingBucket(veh, bucket)
    return true
end

--- Register an externally-spawned vehicle as the player's freeroam vehicle.
--- Used when another system (like multiplayer) hands an entity back
---@param src integer
---@param netId integer
function SKFreeroamServer.adoptAssignedVehicle(src, netId)
    assignedNetIds[src] = netId
    if freeroamPlayers[src] then
        syncFreeroamVehicleNetIds()
    end
end

--- Spawn the active garage vehicle for the given player in a specific bucket
--- Returns the spawned vehicle net id, or nil on failure
---@param src integer
---@param x number
---@param y number
---@param z number
---@param heading number
---@param bucket integer
---@return integer|nil
function SKFreeroamServer.spawnPlayerVehicleInBucket(src, x, y, z, heading, bucket)
    if spawnInProgress[src] then
        local waitUntil = GetGameTimer() + 3000
        while spawnInProgress[src] and GetGameTimer() < waitUntil do Wait(0) end
        return assignedNetIds[src]
    end
    spawnInProgress[src] = true

    local function finish(netId)
        spawnInProgress[src] = nil
        return netId
    end

    local document = SKSaves.getDocument(src)
    if not document then
        return finish(nil)
    end
    local garage = document.garage
    local entry  = garage.vehicles[garage.activeVehicleId]
    if not entry then
        return finish(nil)
    end
    local vehicleType = entry.data.vehicleType

    deleteAssignedVehicle(src)

    local veh = CreateVehicleServerSetter(entry.modelName, vehicleType, x, y, z, heading)
    local deadline = GetGameTimer() + 3000
    while (veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < deadline do Wait(0) end
    if veh == 0 or not DoesEntityExist(veh) then
        return finish(nil)
    end

    SetEntityOrphanMode(veh, 1)
    SetVehicleDoorsLocked(veh, PLAYER_VEHICLE_LOCK_STATE)
    SetVehicleNumberPlateText(veh, entry.plate)
    SetEntityRoutingBucket(veh, bucket)

    local netId = NetworkGetNetworkIdFromEntity(veh)
    assignedNetIds[src] = netId
    return finish(netId)
end

AddEventHandler('playerJoining', function()
    local src = source --[[@as integer]]
    syncPlayerRoutingBucket(src)
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    deleteAssignedVehicle(src)
    spawnInProgress[src] = nil
    freeroamPlayers[src] = nil
    syncFreeroamVehicleNetIds()
end)

RegisterNetEvent('streetkings:freeroam:enter', function()
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then
        return
    end
    if SKGameStateServer.get(src) ~= GameState.FREEROAM then
        return
    end
    freeroamPlayers[src] = true
    syncPlayerRoutingBucket(src)
    syncFreeroamVehicleNetIds()
end)

RegisterNetEvent('streetkings:freeroam:exit', function()
    local src = source --[[@as integer]]
    if not freeroamPlayers[src] then
        return
    end
    if SKGameStateServer.get(src) ~= GameState.FREEROAM then
        return
    end
    local pendingNext = SKGameStateServer.getPendingNext(src)
    if type(pendingNext) ~= 'string' then
        return
    end

    deleteAssignedVehicle(src)
    freeroamPlayers[src] = nil
    syncPlayerRoutingBucket(src)
    syncFreeroamVehicleNetIds()
end)

lib.callback.register('streetkings:freeroam:spawnVehicle', function(source, x, y, z, heading)
    if SKGameStateServer.get(source) ~= GameState.FREEROAM then
        return { ok = false, reason = 'invalid_state' }
    end
    local netId = SKFreeroamServer.spawnPlayerVehicleInBucket(source, x, y, z, heading, 0)
    if not netId then
        return { ok = false, reason = 'spawn_failed' }
    end
    syncFreeroamVehicleNetIds()
    return { ok = true, netId = netId }
end)

lib.callback.register('streetkings:freeroam:confirmHospitalBill', function(source)
    if not SKSaves.hasActiveSave(source) then
        return { ok = false }
    end

    local current = SKSaves.read(source, 'economy.cash')
    local deducted = math.min(current, HOSPITAL_BILL_AMOUNT)
    SKSaves.write(source, 'economy.cash', math.max(0, current - HOSPITAL_BILL_AMOUNT))
    SKStats.increment(source, 'totalCashSpent', deducted)

    return { ok = true }
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, veh in ipairs(GetAllVehicles()) do
        DeleteEntity(veh)
    end
    freeroamPlayers = {}
    assignedNetIds  = {}
    spawnInProgress = {}
    TriggerClientEvent('streetkings:freeroam:setNoCollisionVehicles', -1, {})
end)

CreateThread(function()
    for _, src in ipairs(GetPlayers()) do
        syncPlayerRoutingBucket(tonumber(src))
    end
end)

CreateThread(function()
    while true do
        Wait(VEHICLE_CHECK_INTERVAL)

        for src in pairs(freeroamPlayers) do
            local assigned = assignedNetIds[src]
            if assigned then
                local ped             = GetPlayerPed(src)
                local currentVehicle  = GetVehiclePedIsIn(ped, false)
                local assignedVehicle = NetworkGetEntityFromNetworkId(assigned)

                if assignedVehicle ~= 0 and DoesEntityExist(assignedVehicle) then
                    if not (SKHangoutZones and SKHangoutZones.isPlayerInZone and SKHangoutZones.isPlayerInZone(src)) then
                        SetVehicleDoorsLocked(assignedVehicle, PLAYER_VEHICLE_LOCK_STATE)
                    end
                end

                local isWrongVehicle = currentVehicle == 0
                    or NetworkGetNetworkIdFromEntity(currentVehicle) ~= assigned

                if isWrongVehicle and not (SKHangoutZones and SKHangoutZones.isPlayerInZone and SKHangoutZones.isPlayerInZone(src)) then
                    TriggerClientEvent('streetkings:freeroam:forceVehicle', src)
                end
            end
        end
    end
end)
