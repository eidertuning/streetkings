SKEventsLobby = {}

---@return table[]
function SKEventsLobby.listRaceLobbies()
    local cfg = SKEventsConfig
    local now = os.time()
    local list = {}

    for lobbyId, lobby in pairs(SKEventsServer.openRaceLobbies) do
        if lobby.phase == 'waiting' or lobby.phase == 'starting' then
            list[#list + 1] = {
                id = lobbyId,
                eventId = lobby.eventId,
                eventName = lobby.eventName,
                hostAlias = lobby.hostAlias,
                vehicleClass = lobby.vehicleClass,
                playerCount = #lobby.memberOrder,
                maxPlayers = cfg.MULTIPLAYER_MAX_PLAYERS,
                expiresAt = lobby.expiresAt,
                secondsRemaining = math.max(0, (lobby.expiresAt or 0) - now),
            }
        end
    end

    table.sort(list, function(a, b)
        if a.expiresAt ~= b.expiresAt then
            return a.expiresAt < b.expiresAt
        end
        return a.eventName < b.eventName
    end)

    return list
end

lib.callback.register('streetkings:events:listRaceLobbies', function()
    local cfg = SKEventsConfig
    return {
        entries = SKEventsLobby.listRaceLobbies(),
        limit = cfg.MULTIPLAYER_LOBBY_LIMIT,
        expirySeconds = cfg.MULTIPLAYER_LOBBY_EXPIRY_SECONDS,
        maxPlayers = cfg.MULTIPLAYER_MAX_PLAYERS,
        minPlayers = cfg.MULTIPLAYER_MIN_PLAYERS_TO_START,
    }
end)