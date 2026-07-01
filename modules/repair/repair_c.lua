local REPAIR_COOLDOWN = 5000

local COLOR_READY    = '#00ff88'
local COLOR_COOLDOWN = '#ff3333'

local repairPoints    = {}
local repairBlips     = {}
local repairWaypoints = {}

local canRepair  = true
local hasLeft    = true
local cooldownAt = 0

local function setAllWaypointColor(color)
    for _, wpId in ipairs(repairWaypoints) do
        SKWaypoint.Update(wpId, { color = color })
    end
end

local function clearPoints()
    for _, p in ipairs(repairPoints) do p:remove() end
    repairPoints = {}
    for _, b in ipairs(repairBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    repairBlips = {}
    for _, wpId in ipairs(repairWaypoints) do
        SKWaypoint.Remove(wpId)
    end
    repairWaypoints = {}
end

local function setupPoints()
    clearPoints()

    for _, station in ipairs(SKRepairStations) do
        local coords = station.coords
        local radius = station.radius

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 402)
        SetBlipColour(blip, 2)
        SetBlipScale(blip, 0.5)
        SetBlipAsShortRange(blip, true)
        repairBlips[#repairBlips + 1] = blip

        local wpId = SKWaypoint.Create({
            coords       = coords,
            text         = 'Repair',
            color        = COLOR_READY,
            icon         = 'wrench',
            showDist     = true,
            groundBeam   = true,
            maxRender    = 250.0,
            interactable = false,
        })
        repairWaypoints[#repairWaypoints + 1] = wpId

        repairPoints[#repairPoints + 1] = lib.points.new({
            coords   = coords,
            distance = radius - 10.0,
            onEnter  = function()
                if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
                if not canRepair or not hasLeft then return end

                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                SetVehicleFixed(veh)
                SetVehicleDeformationFixed(veh)
                SetVehicleEngineHealth(veh, 1000.0)
                SetVehiclePetrolTankHealth(veh, 1000.0)
                SetVehicleDirtLevel(veh, 0.0)

                canRepair  = false
                hasLeft    = false
                cooldownAt = GetGameTimer()
                setAllWaypointColor(COLOR_COOLDOWN)

                TriggerServerEvent('streetkings:stats:repair')
                SKNotify({ title = _L('lua.notify.vehicle_repaired'), type = 'success' })

                CreateThread(function()
                    Wait(REPAIR_COOLDOWN)
                    if hasLeft then
                        canRepair = true
                        setAllWaypointColor(COLOR_READY)
                    end
                end)
            end,
            onExit = function()
                hasLeft = true
                if GetGameTimer() - cooldownAt >= REPAIR_COOLDOWN then
                    canRepair = true
                    setAllWaypointColor(COLOR_READY)
                end
            end,
        })
    end
end

AddEventHandler('streetkings:repair:freeroamEnter', setupPoints)
AddEventHandler('streetkings:repair:freeroamExit',  clearPoints)
