---@param result table
local function notifyGarageTowFailure(result)
    if result.reason == 'insufficient_funds' then
        SKNotify({ type = 'error', title = _L('lua.notify.need_more_cash') })
        return
    end

    SKNotify({ type = 'error', title = _L('lua.notify.tow_failed') })
end

RegisterNUICallback('phone:towing:lastGarage', function(_, cb)
    local gs = SKC.GetGameState()
    if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then
        cb({ ok = false, reason = 'invalid_state' })
        return
    end

    local result = lib.callback.await('streetkings:garage:requestTowToLastGarage', false, SKGarage.getDefaultId())
    cb(result)

    if not result.ok then
        notifyGarageTowFailure(result)
        return
    end

    if not SKGarage.getLocationById(result.garageId) then
        SKNotify({ type = 'error', title = _L('lua.notify.garage_unavailable') })
        return
    end

    if SKPhone.isOpen() then
        SKPhone.close()
    end

    if not SKGarage.enterById(result.garageId, false) then
        SKNotify({ type = 'error', title = _L('lua.notify.garage_unavailable') })
        return
    end
end)

RegisterNUICallback('phone:towing:recover', function(_, cb)
    local gs = SKC.GetGameState()
    if gs ~= GameState.FREEROAM and gs ~= GameState.MISSION then
        cb({ ok = false, reason = 'invalid_state' })
        return
    end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local found, roadPos, roadHeading = GetClosestVehicleNodeWithHeading(pos.x, pos.y, pos.z, 0, 3.0, 0)
    if not found then
        cb({ ok = false, reason = 'no_road' })
        SKNotify({ type = 'error', title = _L('lua.notify.no_road_found') })
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    cb({ ok = true })
    if SKPhone.isOpen() then
        SKPhone.close()
    end

    CreateThread(function()
        Wait(250)
        SKC.Warp(roadPos, roadHeading)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            SetVehicleOnGroundProperly(vehicle)
        end
    end)
end)
