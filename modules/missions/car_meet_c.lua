local seated = {}

local function trySeatPed(ped)
    if not ped or ped == 0 or seated[ped] then return end
    if not DoesEntityExist(ped) then return end

    local state = Entity(ped).state
    if not state or state.skMeetRacer ~= true then return end

    local netId = state.skMeetRacerVeh
    if type(netId) ~= 'number' then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end

    local deadline = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(ped) do
        NetworkRequestControlOfEntity(ped)
        if GetGameTimer() > deadline then return end
        Wait(0)
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetPedDefaultComponentVariation(ped)
    SetPedIntoVehicle(ped, veh, -1)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedConfigFlag(ped, 281, true)

    if DoesEntityExist(veh) and NetworkHasControlOfEntity(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleEngineOn(veh, false, true, true)
        SetVehicleLights(veh, 2)
    end

    seated[ped] = true
end

AddStateBagChangeHandler('skMeetRacer', nil, function(bagName, _key, value, _reserved, _replicated)
    if value ~= true then return end
    local netId = bagName:match('entity:(%d+)')
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId))
    if not ent or ent == 0 then return end
    CreateThread(function()
        Wait(200)
        trySeatPed(ent)
    end)
end)

CreateThread(function()
    while true do
        Wait(3000)
        for ped in pairs(seated) do
            if not DoesEntityExist(ped) then
                seated[ped] = nil
            else
                -- Keep reasserting mission-entity ownership on anything we control,
                -- so engine population cannot silently delete these during the race.
                if NetworkHasControlOfEntity(ped) then
                    SetEntityAsMissionEntity(ped, true, true)
                end
                local veh = GetVehiclePedIsIn(ped, false)
                if veh and veh ~= 0 and DoesEntityExist(veh) and NetworkHasControlOfEntity(veh) then
                    SetEntityAsMissionEntity(veh, true, true)
                end
            end
        end
        for _, ped in ipairs(GetGamePool('CPed')) do
            if not seated[ped] then
                trySeatPed(ped)
            end
        end
    end
end)
