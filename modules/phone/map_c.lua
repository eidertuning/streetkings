---@class SKPhoneMapPoint
---@field x number
---@field y number
---@field z number

local TYPE_ORDER = {
    CIRCUIT = 1,
    SPRINT = 2,
    DELIVERY = 3,
}

---@param point vector3|vector4
---@return SKPhoneMapPoint
local function toPoint(point)
    return {
        x = point.x,
        y = point.y,
        z = point.z,
    }
end

---@param def table
---@return string
local function getEventTypeLabel(def)
    if def.type == EventType.DELIVERY then
        return 'DELIVERY'
    end
    if def.scheme == CheckpointScheme.CIRCUIT then
        return 'CIRCUIT'
    end
    return 'SPRINT'
end

---@param def table
---@return string
local function getSchemeLabel(def)
    if def.type == EventType.DELIVERY then
        return 'DIRECT'
    end
    if def.scheme == CheckpointScheme.CIRCUIT then
        return 'LOOP'
    end
    if def.scheme == CheckpointScheme.THEREANDBACK then
        return 'OUT AND BACK'
    end
    if def.scheme == CheckpointScheme.UNORDERED then
        return 'FREE ORDER'
    end
    return 'POINT TO POINT'
end

---@param def table
---@return string
local function getRouteDescription(def)
    if def.type == EventType.DELIVERY then
        return 'Drive from the event start to the delivery point.'
    end
    if def.scheme == CheckpointScheme.CIRCUIT then
        return 'Complete the route and cross back over the starting line to finish.'
    end
    if def.scheme == CheckpointScheme.THEREANDBACK then
        return 'Drive to the far checkpoint, then retrace the route back to the start.'
    end
    if def.scheme == CheckpointScheme.UNORDERED then
        return 'Hit each checkpoint in any order, then finish the event.'
    end
    return 'Follow the route from start to finish in checkpoint order.'
end

---@param def table
---@return string
local function getRouteColor(def)
    if def.type == EventType.DELIVERY then
        return '#4ade80'
    end
    if def.scheme == CheckpointScheme.CIRCUIT then
        return '#52a7ff'
    end
    return '#ff006a'
end

---@return table[]
local function buildPhoneMapEvents()
    local events = {}

    for id, def in pairs(SKEvents) do
        if type(def) ~= 'table' or type(def.start) ~= 'vector4' or type(def.name) ~= 'string' or type(def.id) ~= 'string' then
            goto continue
        end

        if def.type ~= EventType.DELIVERY and type(def.checkpoints) ~= 'table' then
            goto continue
        end

        local typeLabel = getEventTypeLabel(def)
        local route = {}
        for _, point in ipairs(SKEventRoute.buildPreviewRoute(def)) do
            route[#route + 1] = toPoint(point)
        end

        events[#events + 1] = {
            id = id,
            name = def.name,
            typeLabel = typeLabel,
            schemeLabel = getSchemeLabel(def),
            routeDescription = getRouteDescription(def),
            start = toPoint(def.start),
            route = route,
            stopCount = #route - 1,
            goalTime = def.goalTime,
            routeColor = getRouteColor(def),
            typeOrder = TYPE_ORDER[typeLabel] or 99,
            isDaily = SKEvents.getDailyEventState(id) ~= nil,
        }

        ::continue::
    end

    table.sort(events, function(a, b)
        if a.typeOrder ~= b.typeOrder then
            return a.typeOrder < b.typeOrder
        end
        return a.name < b.name
    end)

    return events
end

RegisterNUICallback('phone:map:getData', function(_, cb)
    cb({
        events = buildPhoneMapEvents(),
        mapStyles = { 'satellite', 'regular', 'atlas' },
    })
end)

RegisterNUICallback('phone:map:teleportToEventStart', function(data, cb)
    if not lib.callback.await('phone:settings:hasPermission', false) then
        cb({ ok = false })
        return
    end

    local eventId = data and data.eventId
    if type(eventId) ~= 'string' or eventId == '' then
        cb({ ok = false })
        return
    end

    local def = SKEvents[eventId]
    if not def then
        cb({ ok = false })
        return
    end

    local target = def.start

    cb({ ok = true })
    SKPhone.close()
    CreateThread(function()
        Wait(500)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            SetEntityCoords(vehicle, target.x, target.y, target.z, false, false, false, false)
            SetEntityHeading(vehicle, target.w)
        else
            SetEntityCoords(ped, target.x, target.y, target.z, false, false, false, false)
            SetEntityHeading(ped, target.w)
        end
    end)
end)

RegisterNUICallback('phone:map:setWaypoint', function(data, cb)
    local eventId = data and data.eventId
    if type(eventId) ~= 'string' or eventId == '' then
        cb({ ok = false })
        return
    end

    local def = SKEvents[eventId]
    if not def then
        cb({ ok = false })
        return
    end

    SetNewWaypoint(def.start.x, def.start.y)
    SKNotify({ type = 'success', title = _L('lua.notify.event_marked') })
    cb({ ok = true })
end)
