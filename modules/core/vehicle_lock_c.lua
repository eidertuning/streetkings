SKVehicleLock = {}

local allowLeave = false

function SKVehicleLock.tick(vehicle, onFootPermitted)
    if allowLeave then return end
    if onFootPermitted() then return end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        for i=0, 2 do
            DisableControlAction(i, 75, true)
            DisableControlAction(i, 12, true)
            DisableControlAction(i, 13, true)
            DisableControlAction(i, 14, true)  -- INPUT_SELECT_NEXT_WEAPON
            DisableControlAction(i, 15, true)  -- INPUT_SELECT_PREV_WEAPON
            DisableControlAction(i, 16, true)  -- INPUT_SELECT_WEAPON_ALTERNATE
            DisableControlAction(i, 17, true)  -- INPUT_SELECT_WEAPON_SECONDARY
            DisableControlAction(i, 37, true)  -- INPUT_SELECT_WEAPON (Tab)
            DisableControlAction(i, 53, true)
            DisableControlAction(i, 54, true)
            DisableControlAction(i, 56, true)
            DisableControlAction(i, 99, true)
            DisableControlAction(i, 100, true)
            DisableControlAction(i, 115, true)
            DisableControlAction(i, 116, true)
            DisableControlAction(i, 157, true)
            DisableControlAction(i, 158, true)
            DisableControlAction(i, 159, true)
            DisableControlAction(i, 160, true)
            DisableControlAction(i, 161, true)
            DisableControlAction(i, 162, true)
            DisableControlAction(i, 163, true)
            DisableControlAction(i, 164, true)
            DisableControlAction(i, 165, true)
            DisableControlAction(i, 192, true)
            DisableControlAction(i, 204, true)
            DisableControlAction(i, 211, true)
            DisableControlAction(i, 261, true)
            DisableControlAction(i, 262, true)
        end
    else
        if vehicle and DoesEntityExist(vehicle) then
            TaskWarpPedIntoVehicle(ped, vehicle, -1)
        end
    end
end

function SKVehicleLock.isLeaveAllowed()
    return allowLeave
end

exports('AllowLeaveVehicle', function(on)
    if type(on) ~= 'boolean' then return false end
    allowLeave = on
    return true
end)