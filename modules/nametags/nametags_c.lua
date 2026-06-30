---@class SKNametagsModule
SKNametags = {}

---@type table<integer, table>
local roster = {}
local active = false
local lastEmpty = true

local function maxDistance()
    local configured = SKConfig and SKConfig.Nametag and tonumber(SKConfig.Nametag.distance)
    return configured and configured > 0 and configured or 30.0
end

local function sendNametags(players)
    SendNUIMessage({
        type = 'streetkings:nametags:update',
        players = players or {},
    })
end

local function clearNametags()
    if not lastEmpty then
        sendNametags({})
        lastEmpty = true
    end
end

local function settingsEnabled()
    if not SKSettings or type(SKSettings.areNametagsEnabled) ~= 'function' then return true end
    return SKSettings.areNametagsEnabled()
end

local function ownNametagEnabled()
    if not SKSettings or type(SKSettings.isOwnNametagEnabled) ~= 'function' then return true end
    return SKSettings.isOwnNametagEnabled()
end

local function entryFromRoster(src, fallbackName)
    local entry = roster[src] or {}
    local nametag = entry.nametag or {}
    if type(nametag.alias) ~= 'string' or nametag.alias == '' then
        nametag.alias = entry.alias or fallbackName or 'Piloto'
    end
    if type(nametag.level) ~= 'number' then
        nametag.level = tonumber(entry.level) or 1
    end
    return entry, nametag
end

local function setEntry(src, entry)
    if type(src) ~= 'number' then src = tonumber(src) end
    if not src then return end
    if type(entry) ~= 'table' then
        roster[src] = nil
        return
    end
    entry.source = src
    roster[src] = entry
end

local function syncRoster(entries)
    roster = {}
    if type(entries) ~= 'table' then return end
    for src, entry in pairs(entries) do
        if type(entry) == 'table' then
            setEntry(tonumber(entry.source or src), entry)
        end
    end
end

--- Enable nametags for freeroam and request a fresh sync from the server.
function SKNametags.startFreeroam()
    active = true
    roster = {}
    lastEmpty = true
    TriggerServerEvent('streetkings:nametags:requestSync')
end

--- Disable nametags and clear the roster.
function SKNametags.stop()
    active = false
    roster = {}
    clearNametags()
end

---@param entries table[]
function SKNametags.setRoster(entries)
    syncRoster(entries)
    active = true
end

RegisterNetEvent('streetkings:nametags:sync', function(entries)
    syncRoster(entries)
end)

RegisterNetEvent('streetkings:nametags:playerJoined', function(src, entry)
    setEntry(src, entry)
end)

RegisterNetEvent('streetkings:nametags:playerUpdated', function(src, entry)
    setEntry(src, entry)
end)

RegisterNetEvent('streetkings:nametags:playerLeft', function(src)
    roster[tonumber(src)] = nil
end)

local function getNametagWorldPos(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        local coords = GetEntityCoords(vehicle)
        local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
        local height = (maxDim and minDim) and math.max(1.15, (maxDim.z - minDim.z) + 0.75) or 1.8
        return vector3(coords.x, coords.y, coords.z + height)
    end

    local head = GetPedBoneCoords(ped, 0x796E, 0.0, 0.0, 0.32)
    return vector3(head.x, head.y, head.z)
end

local function buildVisibleNametags()
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local myId = PlayerId()
    local camera = GetGameplayCamCoords()
    local players = {}
    local showOwn = ownNametagEnabled()

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= myId or showOwn then
            local ped = GetPlayerPed(playerId)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local pos = getNametagWorldPos(ped)
                local dist = #(myPos - pos)
                local clearLos = playerId == myId or HasEntityClearLosToEntity(myPed, ped, 17)
                local maxDist = maxDistance()
                if dist <= maxDist and clearLos then
                    local onScreen, sx, sy = World3dToScreen2d(pos.x, pos.y, pos.z)
                    if onScreen then
                        local src = GetPlayerServerId(playerId)
                        local _, nametag = entryFromRoster(src, GetPlayerName(playerId))
                        if nametag and (not nametag.display or nametag.display.enabled ~= false) then
                            local camDist = #(camera - pos)
                            local scale = math.max(0.74, math.min(1.05, 1.12 - (camDist / maxDist) * 0.42))
                            players[#players + 1] = {
                                source = src,
                                screenX = sx,
                                screenY = sy,
                                distance = dist,
                                scale = scale,
                                alias = nametag.alias,
                                level = nametag.level,
                                nametag = nametag,
                            }
                        end
                    end
                end
            end
        end
    end

    return players
end

RegisterCommand('sk_toggle_nametags', function()
    if not SKSettings or type(SKSettings.areNametagsEnabled) ~= 'function' then return end
    local enabled = not SKSettings.areNametagsEnabled()
    SKSettings.setGeneralValue('nametagsEnabled', enabled)
    clearNametags()
    SKNotify({ type = 'info', title = enabled and 'Nametags On' or 'Nametags Off' })
end)
RegisterKeyMapping('sk_toggle_nametags', 'Toggle player nametags', 'keyboard', 'F1')

CreateThread(function()
    while true do
        if not active or not settingsEnabled() then
            clearNametags()
            Wait(400)
        else
            local players = buildVisibleNametags()
            if #players == 0 then
                clearNametags()
            else
                sendNametags(players)
                lastEmpty = false
            end
            Wait(0)
        end
    end
end)
