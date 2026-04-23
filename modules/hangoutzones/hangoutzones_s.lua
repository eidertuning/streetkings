SKHangoutZones = SKHangoutZones or {}

local playersInZone = {}

--- Returns true if the given server id is inside any hangout zone
---@param src integer
---@return boolean
function SKHangoutZones.isPlayerInZone(src)
    return playersInZone[src] ~= nil
end

RegisterNetEvent('streetkings:hangoutzones:enterZone', function(zoneId)
    local src = source
    if not zoneId or type(zoneId) ~= 'string' then return end
    playersInZone[src] = zoneId
end)

RegisterNetEvent('streetkings:hangoutzones:exitZone', function()
    local src = source
    playersInZone[src] = nil
end)

AddEventHandler('playerDropped', function()
    playersInZone[source] = nil
end)

--- Get the number of players in a specific zone
---@param zoneId string
---@return number
lib.callback.register('streetkings:hangoutzones:getZonePopulation', function(source, zoneId)
    local count = 0
    for _, id in pairs(playersInZone) do
        if id == zoneId then count = count + 1 end
    end
    return count
end)

exports('IsPlayerInHangoutZone', SKHangoutZones.isPlayerInZone)