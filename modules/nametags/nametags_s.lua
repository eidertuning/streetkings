--- source -> display alias for every player currently in freeroam
---@type table<integer, string>
local freeroamNames = {}

---@param src integer
---@return string
local function getAlias(src)
    local alias = SKSaves.read(src, 'profile.alias')
    if type(alias) == 'string' and #alias > 0 then
        return alias
    end
    return GetPlayerName(src)
end

AddEventHandler('streetkings:freeroam:enter', function()
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then return end

    local alias = getAlias(src)
    freeroamNames[src] = alias

    TriggerClientEvent('streetkings:nametags:sync', src, freeroamNames)
    TriggerClientEvent('streetkings:nametags:playerJoined', -1, src, alias)
end)

AddEventHandler('streetkings:freeroam:exit', function()
    local src = source --[[@as integer]]
    if not freeroamNames[src] then return end
    freeroamNames[src] = nil
    TriggerClientEvent('streetkings:nametags:playerLeft', -1, src)
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    if not freeroamNames[src] then return end
    freeroamNames[src] = nil
    TriggerClientEvent('streetkings:nametags:playerLeft', -1, src)
end)

RegisterNetEvent('streetkings:nametags:requestSync', function()
    local src = source --[[@as integer]]
    TriggerClientEvent('streetkings:nametags:sync', src, freeroamNames)
end)