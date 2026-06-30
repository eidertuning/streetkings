--- source -> roster entry for every player currently in freeroam
---@type table<integer, table>
local freeroamRoster = {}

---@param src integer
---@return string
local function getAlias(src)
    local alias = SKSaves.read(src, 'profile.alias')
    if type(alias) == 'string' and #alias > 0 then
        return alias
    end
    return GetPlayerName(src) or 'Piloto'
end

---@param src integer
---@return table|nil
local function buildRosterEntry(src)
    if not SKSaves.hasActiveSave(src) then return nil end

    local nametag = SKVip and SKVip.GetEffectiveNametag and SKVip.GetEffectiveNametag(src) or nil
    local level = SKSaves.read(src, 'progression.level') or 1
    return {
        source = src,
        alias = nametag and nametag.alias or getAlias(src),
        level = nametag and nametag.level or level,
        nametag = nametag,
    }
end

---@return table[]
local function rosterList()
    local list = {}
    for _, entry in pairs(freeroamRoster) do
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        return (a.source or 0) < (b.source or 0)
    end)
    return list
end

---@param src integer
local function broadcastRosterUpdate(src)
    local entry = buildRosterEntry(src)
    if not entry then return end
    freeroamRoster[src] = entry
    TriggerClientEvent('streetkings:nametags:playerUpdated', -1, src, entry)
end

AddEventHandler('streetkings:freeroam:enter', function()
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then return end

    if SKVip and SKVip.Refresh then
        SKVip.Refresh(src, false)
    end

    local entry = buildRosterEntry(src)
    if not entry then return end
    freeroamRoster[src] = entry

    TriggerClientEvent('streetkings:nametags:sync', src, rosterList())
    TriggerClientEvent('streetkings:nametags:playerJoined', -1, src, entry)
end)

AddEventHandler('streetkings:freeroam:exit', function()
    local src = source --[[@as integer]]
    if not freeroamRoster[src] then return end
    freeroamRoster[src] = nil
    TriggerClientEvent('streetkings:nametags:playerLeft', -1, src)
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    if not freeroamRoster[src] then return end
    freeroamRoster[src] = nil
    TriggerClientEvent('streetkings:nametags:playerLeft', -1, src)
end)

AddEventHandler('streetkings:vip:updated', function(src)
    if freeroamRoster[src] then
        broadcastRosterUpdate(src)
    end
end)

AddEventHandler('streetkings:vip:tagUpdated', function(src)
    if freeroamRoster[src] then
        broadcastRosterUpdate(src)
    end
end)

RegisterNetEvent('streetkings:nametags:requestSync', function()
    local src = source --[[@as integer]]
    if SKSaves.hasActiveSave(src) and freeroamRoster[src] then
        broadcastRosterUpdate(src)
    end
    TriggerClientEvent('streetkings:nametags:sync', src, rosterList())
end)
