SKEventPreview = {}

local CHECKPOINT_SIZE = 12.0
local CHECKPOINT_ALPHA = 55
local CHECKPOINT_RENDER_Z_OFFSET = 1.0

local BLIP_SPRITE_CP = 1
local BLIP_SPRITE_FINISH = 38
local BLIP_COLOUR_RACE = 66
local BLIP_SCALE_CURRENT = 1.05
local BLIP_SCALE_NEXT = 0.72
local BLIP_SCALE_FINISH = 1.1
local BLIP_SCALE_UNORDERED = 0.95

---@param point vector3
---@return number
local function getRenderZ(point)
    return point.z - CHECKPOINT_RENDER_Z_OFFSET
end

---@param handle integer|nil
---@param blip integer|nil
---@param nextBlip integer|nil
function SKEventPreview.clearCheckpoint(handle, blip, nextBlip)
    if handle then
        DeleteCheckpoint(handle)
    end
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    if nextBlip and DoesBlipExist(nextBlip) then
        RemoveBlip(nextBlip)
    end
end

---@param blip integer
local function applyRaceBlipCommon(blip)
    SetBlipColour(blip, BLIP_COLOUR_RACE)
    SetBlipAsShortRange(blip, false)
    SetBlipHighDetail(blip, true)
    SetBlipDisplay(blip, 4)
end

---@param current vector3
---@param nextCp vector3|nil
---@param isLast boolean
---@param useRoute boolean|nil
---@return integer checkpointHandle
---@return integer primaryBlip
---@return integer|nil nextBlip
function SKEventPreview.createCheckpoint(current, nextCp, isLast, useRoute)
    local currentZ = getRenderZ(current)
    local nx, ny, nz = current.x, current.y, currentZ
    if nextCp then
        nx, ny, nz = nextCp.x, nextCp.y, getRenderZ(nextCp)
    end

    local checkpointHandle = CreateCheckpoint(
        isLast and 4 or 0,
        current.x, current.y, currentZ,
        nx, ny, nz,
        CHECKPOINT_SIZE,
        255, 210, 0, CHECKPOINT_ALPHA,
        0
    )

    local primaryBlip = AddBlipForCoord(current.x, current.y, current.z)
    if isLast then
        SetBlipSprite(primaryBlip, BLIP_SPRITE_FINISH)
        SetBlipScale(primaryBlip, BLIP_SCALE_FINISH)
    else
        SetBlipSprite(primaryBlip, BLIP_SPRITE_CP)
        SetBlipScale(primaryBlip, BLIP_SCALE_CURRENT)
    end
    applyRaceBlipCommon(primaryBlip)

    if useRoute ~= false then
        SetBlipRoute(primaryBlip, true)
        SetBlipRouteColour(primaryBlip, BLIP_COLOUR_RACE)
    end

    local nextBlip = nil
    if not isLast and nextCp then
        nextBlip = AddBlipForCoord(nextCp.x, nextCp.y, nextCp.z)
        SetBlipSprite(nextBlip, BLIP_SPRITE_CP)
        SetBlipScale(nextBlip, BLIP_SCALE_NEXT)
        applyRaceBlipCommon(nextBlip)
    end

    return checkpointHandle, primaryBlip, nextBlip
end

---@param current vector3
---@param useRoute boolean|nil
---@return integer checkpointHandle
---@return integer blipHandle
function SKEventPreview.createStaticCheckpoint(current, useRoute)
    local currentZ = getRenderZ(current)
    local checkpointHandle = CreateCheckpoint(
        1,
        current.x, current.y, currentZ,
        current.x, current.y, currentZ,
        CHECKPOINT_SIZE,
        255, 210, 0, CHECKPOINT_ALPHA,
        0
    )

    local blipHandle = AddBlipForCoord(current.x, current.y, current.z)
    SetBlipSprite(blipHandle, BLIP_SPRITE_CP)
    SetBlipScale(blipHandle, BLIP_SCALE_CURRENT)
    applyRaceBlipCommon(blipHandle)

    if useRoute ~= false then
        SetBlipRoute(blipHandle, true)
        SetBlipRouteColour(blipHandle, BLIP_COLOUR_RACE)
    end

    return checkpointHandle, blipHandle
end

---@param checkpoints vector3[]
---@param authoredIndices integer[]|nil  parallel 1-based indices; last authored index uses finish sprite
---@param authoredTotal integer|nil
---@return integer[] checkpointHandles
---@return integer[] blipHandles
function SKEventPreview.showAllCheckpoints(checkpoints, authoredIndices, authoredTotal)
    local checkpointHandles = {}
    local blipHandles = {}

    for i, checkpoint in ipairs(checkpoints) do
        local checkpointZ = getRenderZ(checkpoint)
        local checkpointHandle = CreateCheckpoint(
            1,
            checkpoint.x, checkpoint.y, checkpointZ,
            checkpoint.x, checkpoint.y, checkpointZ,
            CHECKPOINT_SIZE,
            255, 210, 0, CHECKPOINT_ALPHA,
            0
        )
        checkpointHandles[#checkpointHandles + 1] = checkpointHandle

        local blipHandle = AddBlipForCoord(checkpoint.x, checkpoint.y, checkpoint.z)
        local isFinish = authoredIndices and authoredTotal
            and authoredIndices[i] == authoredTotal
        if isFinish then
            SetBlipSprite(blipHandle, BLIP_SPRITE_FINISH)
            SetBlipScale(blipHandle, BLIP_SCALE_FINISH)
        else
            SetBlipSprite(blipHandle, BLIP_SPRITE_CP)
            SetBlipScale(blipHandle, BLIP_SCALE_UNORDERED)
        end
        applyRaceBlipCommon(blipHandle)
        blipHandles[#blipHandles + 1] = blipHandle
    end

    return checkpointHandles, blipHandles
end

---@param checkpointHandles integer[]
---@param blipHandles integer[]
function SKEventPreview.clearCheckpointSet(checkpointHandles, blipHandles)
    for _, checkpointHandle in ipairs(checkpointHandles) do
        if checkpointHandle then
            DeleteCheckpoint(checkpointHandle)
        end
    end

    for _, blipHandle in ipairs(blipHandles) do
        if blipHandle and DoesBlipExist(blipHandle) then
            RemoveBlip(blipHandle)
        end
    end
end

---@param checkpoints vector3[]
function SKEventPreview.renderGpsTrack(checkpoints)
    ClearGpsMultiRoute()
    StartGpsMultiRoute(6, false, true)

    for _, checkpoint in ipairs(checkpoints) do
        AddPointToGpsMultiRoute(checkpoint.x, checkpoint.y, checkpoint.z)
    end

    SetGpsMultiRouteRender(true)
end

function SKEventPreview.clearGpsTrack()
    ClearGpsMultiRoute()
end