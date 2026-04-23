---@class SKNametagsModule
SKNametags = {}

--- source id > display name for every visible player
---@type table<integer, string>
local names  = {}
local active = false

local MAX_DIST = 80.0

--- Enable nametags for freeroam and request a fresh name sync from the server.
function SKNametags.startFreeroam()
    active = true
    names  = {}
    TriggerServerEvent('streetkings:nametags:requestSync')
end

--- Disable nametags and clear the name table.
function SKNametags.stop()
    active = false
    names  = {}
end

---@param roster { source: integer, alias: string }[]
function SKNametags.setRoster(roster)
    names = {}
    for _, entry in ipairs(roster) do
        names[entry.source] = entry.alias
    end
    active = true
end

RegisterNetEvent('streetkings:nametags:sync', function(nameMap)
    names = nameMap
end)

RegisterNetEvent('streetkings:nametags:playerJoined', function(src, alias)
    names[src] = alias
end)

RegisterNetEvent('streetkings:nametags:playerLeft', function(src)
    names[src] = nil
end)

---@param position vector3
---@param name string
local function drawNametag(position, name)
    local onScreen, sx, sy = World3dToScreen2d(position.x, position.y, position.z + 1.5)
    if not onScreen then return end

    local dist  = #(GetGameplayCamCoords() - position)
    local scale = (1 / dist) * 2 * (1 / GetGameplayCamFov()) * 100

    SetTextScale(0.0, 1.0 * scale)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(name)
    DrawText(sx, sy)
end

RegisterCommand('sk_toggle_nametags', function()
    local enabled = not SKSettings.areNametagsEnabled()
    SKSettings.setGeneralValue('nametagsEnabled', enabled)
    SKNotify({ type = 'info', title = enabled and 'Nametags On' or 'Nametags Off' })
end)
RegisterKeyMapping('sk_toggle_nametags', 'Toggle player nametags', 'keyboard', 'F1')

CreateThread(function()
    while true do
        if not active or not SKSettings.areNametagsEnabled() then
            Wait(500)
        else
            local myPed = PlayerPedId()
            local myPos = GetEntityCoords(myPed)
            local myId  = PlayerId()

            for _, playerId in ipairs(GetActivePlayers()) do
                if playerId ~= myId then
                    local ped     = GetPlayerPed(playerId)
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    if vehicle ~= 0 then
                        local vehPos = GetEntityCoords(vehicle)
                        if #(myPos - vehPos) < MAX_DIST then
                            local src  = GetPlayerServerId(playerId)
                            local name = names[src] or GetPlayerName(playerId)
                            drawNametag(vehPos, name)
                        end
                    end
                end
            end

            Wait(0)
        end
    end
end)