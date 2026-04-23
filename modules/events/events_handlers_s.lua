AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    SKEventsServer.lastSubmit[src] = nil
    SKEventsServer.mpVehicleNetIdBySource[src] = nil
end)

AddEventHandler('streetkings:server:recordNpcRace', function(source, isWin, vehicleModel)
    if not SKEventsServer.dbReady then return end
    if not source or not SKSaves.hasActiveSave(source) then return end

    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license then return end

    local savedAlias = SKSaves.read(source, 'profile.alias')
    local alias = (savedAlias ~= '' and savedAlias) or GetPlayerName(source) or 'Unknown'
    local eventId = isWin and 'npc_street_wins' or 'npc_street_losses'
    local model = (type(vehicleModel) == 'string' and #vehicleModel <= 64) and vehicleModel or ''

    MySQL.insert.await(
        'INSERT INTO `event_leaderboards` (`license`, `alias`, `event_id`, `vehicle_class`, `score_value`, `vehicle_model`) VALUES (?, ?, ?, ?, ?, ?)',
        { license, alias, eventId, '', 1, model }
    )
end)

AddEventHandler('streetkings:freeroam:enter', function()
    local source = source --[[@as integer]]
    if not SKSaves.hasActiveSave(source) then
        return
    end

    SKEventsDaily.maybeSendDailyPlaylistMessage(source, SKEventsDaily.buildDailyPlaylistPayload(source))
end)