SKEventRoute = {}

---@param point vector3|vector4
---@return vector3
function SKEventRoute.toVector3(point)
    return vector3(point.x, point.y, point.z)
end

---@param def table
---@return vector3[]
function SKEventRoute.buildCheckpointList(def)
    if def.type == EventType.DELIVERY then
        return { def.destination }
    end

    local checkpoints = {}
    for _, checkpoint in ipairs(def.checkpoints) do
        checkpoints[#checkpoints + 1] = checkpoint
    end

    if def.scheme == CheckpointScheme.THEREANDBACK then
        for i = #def.checkpoints - 1, 1, -1 do
            checkpoints[#checkpoints + 1] = def.checkpoints[i]
        end
        checkpoints[#checkpoints + 1] = SKEventRoute.toVector3(def.start)
    elseif def.scheme == CheckpointScheme.CIRCUIT then
        checkpoints[#checkpoints + 1] = SKEventRoute.toVector3(def.start)
    end

    return checkpoints
end

---@param def table
---@return vector3[]
function SKEventRoute.buildPreviewRoute(def)
    local route = { SKEventRoute.toVector3(def.start) }

    if def.type == EventType.DELIVERY then
        route[#route + 1] = def.destination
        return route
    end

    local checkpoints = SKEventRoute.buildCheckpointList(def)
    for _, checkpoint in ipairs(checkpoints) do
        route[#route + 1] = checkpoint
    end

    return route
end