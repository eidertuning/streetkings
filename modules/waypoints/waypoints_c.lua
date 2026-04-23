SKWaypoint = SKWaypoint or {}

local waypoints    = {}
local nextId       = 1
local duiPool      = {}
local camCoords, playerCoords

local mapWaypointId    = nil
local lastWaypointPos  = nil
local wasWaypointActive = false

local guideState = {
    activeWpId   = nil,
    points       = {},
    arrows       = {},
    routeLength  = 0.0,
    lastUpdate   = 0,
}

local JUNCTION_FLAG = 128

local duiUrl = ('nui://%s/html/waypoints/index.html'):format(GetCurrentResourceName())
local duiIdx = 0

local function createDuiEntry()
    local idx = duiIdx
    duiIdx = duiIdx + 1
    local dictName = 'sk_wp_' .. idx
    local txtName  = 'wp_tex_' .. idx
    local handle   = CreateDui(duiUrl, SKWaypointConfig.PanelWidth, SKWaypointConfig.PanelHeight)
    local txd      = CreateRuntimeTxd(dictName)
    CreateRuntimeTextureFromDuiHandle(txd, txtName, GetDuiHandle(handle))
    return { handle = handle, dictName = dictName, txtName = txtName, inUse = false }
end

local function acquireDui()
    for i = #duiPool, 1, -1 do
        local entry = duiPool[i]
        if not entry.inUse then
            entry.inUse = true
            return entry
        end
    end
    local entry = createDuiEntry()
    entry.inUse = true
    duiPool[#duiPool + 1] = entry
    return entry
end

local function releaseDui(entry)
    if entry then
        entry.inUse = false
        SendDuiMessage(entry.handle, json.encode({ action = 'reset' }))
    end
end

CreateThread(function()
    local poolSize = SKWaypointConfig.PreAllocPool or 5
    for i = 1, poolSize do
        duiPool[#duiPool + 1] = createDuiEntry()
        Wait(50)
    end
end)

local function dist3d(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function distSq(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

local sqrt = math.sqrt
local floor = math.floor
local max = math.max
local min = math.min

local function renderQuad(wp, cx, cy, cz)
    local dui = wp.dui
    if not dui then return false end

    local px, py = wp.coords.x, wp.coords.y
    local cfg = SKWaypointConfig.Defaults
    local maxR = wp.maxRender or cfg.maxRender
    local fadeS = wp.fadeStart or cfg.fadeStart

    local dx, dy, dz = cx - px, cy - py, cz - (wp.groundZ or (wp.coords.z - 2.0))
    local dSq = dx * dx + dy * dy + dz * dz
    if dSq > maxR * maxR then return false end

    local camDist = sqrt(dSq)

    local alpha = 255
    if camDist > fadeS then
        alpha = floor(255 * (1.0 - ((camDist - fadeS) / (maxR - fadeS))))
    end
    if alpha <= 0 then return false end

    local baseSize = (wp.size or cfg.size) * 4.0
    local size = baseSize * max(0.1, camDist / 20.0)

    local unclamped = size * 2.0
    local quadH = max(0.5, min(120.0, unclamped))
    local quadW = size * (quadH / unclamped)

    local fx, fy = cx - px, cy - py
    local fLen = sqrt(fx * fx + fy * fy)
    if fLen < 0.0001 then return false end
    local invF = 1.0 / fLen
    fx, fy = fx * invF, fy * invF

    local rx, ry = -fy, fx
    local halfW = quadW * 0.5
    local rhx, rhy = rx * halfW, ry * halfW

    local gz = wp.groundZ or (wp.coords.z - 2.0)

    local tlx, tly, tlz = px - rhx, py - rhy, gz + quadH
    local trx, try, trz = px + rhx, py + rhy, gz + quadH
    local blx, bly, blz = px - rhx, py - rhy, gz
    local brx, bry, brz = px + rhx, py + rhy, gz

    local dict = dui.dictName
    local txt  = dui.txtName

    DrawTexturedPoly(
        tlx, tly, tlz,
        blx, bly, blz,
        brx, bry, brz,
        255, 255, 255, alpha,
        dict, txt,
        0.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        1.0, 1.0, 0.0
    )

    DrawTexturedPoly(
        tlx, tly, tlz,
        brx, bry, brz,
        trx, try, trz,
        255, 255, 255, alpha,
        dict, txt,
        0.0, 0.0, 0.0,
        1.0, 1.0, 0.0,
        1.0, 0.0, 0.0
    )

    return true
end

local function pushToDui(wp)
    if not wp.dui then return end
    local cfg = SKWaypointConfig.Defaults
    SendDuiMessage(wp.dui.handle, json.encode({
        action   = 'configure',
        text     = wp.text or cfg.text,
        color    = wp.color or cfg.color,
        icon     = wp.icon or cfg.icon,
        imageUrl = wp.imageUrl or cfg.imageUrl,
        hasCountdown  = wp.countdownEnd ~= nil,
        countdownTotal = wp.countdown,
    }))
end

local INTERACT_RANGE = 5.0

local function pushDistance(wp, dist)
    if not wp.dui then return end
    local msg = {
        action   = 'distance',
        value    = math.floor(dist),
    }
    if wp.interactable and dist <= INTERACT_RANGE then
        msg.interact = true
        msg.interactKey = SKInput and SKInput.getInteractLabel and SKInput.getInteractLabel() or 'E'
    end
    if wp.countdownEnd then
        local remaining = (wp.countdownEnd - GetGameTimer()) / 1000
        msg.countdown = math.max(0, remaining)
    end
    SendDuiMessage(wp.dui.handle, json.encode(msg))
end

local function vecLen2D(v)
    return v.x * v.x + v.y * v.y
end

local function vecNorm2D(v)
    local mag = sqrt(v.x * v.x + v.y * v.y)
    if mag < 0.0001 then return vector3(0.0, 0.0, 0.0) end
    return vector3(v.x / mag, v.y / mag, 0.0)
end

local function cubicBezier(p0, p1, p2, p3, t)
    local omt = 1.0 - t
    local omt2 = omt * omt
    local omt3 = omt2 * omt
    local t2 = t * t
    local t3 = t2 * t
    return (p0 * omt3) + (p1 * (3.0 * omt2 * t)) + (p2 * (3.0 * omt * t2)) + (p3 * t3)
end

local function getPointDirection(points, fromIdx, toIdx)
    if fromIdx < 1 or toIdx < 1 or fromIdx > #points or toIdx > #points then
        return vector3(0.0, 0.0, 0.0)
    end
    local dir = vecNorm2D(points[toIdx].pos - points[fromIdx].pos)
    if vecLen2D(dir) < 0.0001 then return vector3(0.0, 0.0, 0.0) end
    return dir
end

local function isJunctionNode(pos)
    if type(GetVehicleNodeProperties) ~= 'function' then return false end
    local ok, _, flags = GetVehicleNodeProperties(pos.x, pos.y, pos.z)
    if not ok then return false end
    return ((flags or 0) & JUNCTION_FLAG) ~= 0
end

local function smoothRouteJunctions(points)
    local gcfg = SKWaypointConfig.GuideLines
    if not gcfg.smoothJunctions or #points < 4 then return points end

    local padding = gcfg.junctionPadding
    for i = 1, #points do
        if points[i].junction then
            for j = max(1, i - padding), min(#points, i + padding) do
                points[j].junctionZone = true
            end
        end
    end

    local smoothed = {}
    for i = 1, #points do
        smoothed[i] = { pos = vector3(points[i].pos.x, points[i].pos.y, points[i].pos.z), junction = points[i].junction, junctionZone = points[i].junctionZone }
    end

    local idx = 1
    while idx <= #smoothed do
        if not smoothed[idx].junctionZone then
            idx = idx + 1
        else
            local zStart = idx
            while idx <= #smoothed and smoothed[idx].junctionZone do
                idx = idx + 1
            end
            local zEnd = idx - 1
            local pre = zStart - 1
            local post = zEnd + 1

            if pre >= 1 and post <= #smoothed then
                local startPos = smoothed[pre].pos
                local endPos = smoothed[post].pos
                local span = zEnd - zStart + 1
                local chord = endPos - startPos
                local chordLen = sqrt(vecLen2D(chord))

                if chordLen > 0.01 then
                    local entryDir = getPointDirection(smoothed, max(1, pre - 1), pre)
                    local exitDir = getPointDirection(smoothed, post, min(#smoothed, post + 1))
                    local handle = min(chordLen * gcfg.curveStrength, gcfg.curveMaxHandle)
                    local c1 = startPos + (entryDir * handle)
                    local c2 = endPos - (exitDir * handle)

                    for pi = zStart, zEnd do
                        local t = (pi - zStart + 1) / (span + 1)
                        smoothed[pi].pos = cubicBezier(startPos, c1, c2, endPos, t)
                    end
                end
            end
        end
    end

    return smoothed
end

local function sampleGpsRoute()
    local gcfg = SKWaypointConfig.GuideLines

    if type(GetPosAlongGpsTypeRoute) ~= 'function' then return nil end
    if not GetGpsBlipRouteFound() then
        local ok, _ = GetPosAlongGpsTypeRoute(true, 0.0, 0)
        if not ok then return nil end
    end

    local targetLen = GetGpsBlipRouteLength()
    if targetLen <= 0 then
        targetLen = gcfg.maxDistance
    else
        targetLen = min(targetLen, gcfg.maxDistance)
    end

    local points = {}
    local distance = 0.0
    local slotTypes = { 0, 1, 2 }

    for _, slot in ipairs(slotTypes) do
        points = {}
        distance = 0.0
        while distance <= targetLen do
            local ok, pos = GetPosAlongGpsTypeRoute(true, distance, slot)
            if not ok or not pos then break end

            local basePos = vector3(pos.x, pos.y, pos.z)
            local point = {
                pos = vector3(basePos.x, basePos.y, basePos.z + gcfg.routeHeight),
                junction = isJunctionNode(basePos),
                junctionZone = false,
            }

            if #points == 0 then
                points[#points + 1] = point
            else
                local delta = point.pos - points[#points].pos
                if vecLen2D(delta) + (delta.z * delta.z) > 0.25 then
                    points[#points + 1] = point
                end
            end

            distance = distance + gcfg.sampleStep
        end

        if #points >= 2 then break end
    end

    if #points < 2 then return nil end

    points = smoothRouteJunctions(points)
    return points, targetLen
end

local function rebuildGuideRoute()
    if not guideState.activeWpId then
        guideState.points = {}
        guideState.arrows = {}
        guideState.routeLength = 0.0
        return
    end
    local wp = waypoints[guideState.activeWpId]
    if not wp or not wp.guideLines then
        guideState.activeWpId = nil
        guideState.points = {}
        guideState.arrows = {}
        guideState.routeLength = 0.0
        return
    end

    local points, routeLen = sampleGpsRoute()
    if not points then return end

    local gcfg = SKWaypointConfig.GuideLines
    local newArrows = {}
    local spacingCount = math.max(1, floor(gcfg.arrowSpacing / gcfg.sampleStep))
    local aLen = gcfg.arrowLength
    local aWid = gcfg.arrowWidth

    for i = 2, #points - 1, spacingCount do
        local prev = points[i - 1].pos
        local curr = points[i].pos
        local next = points[i + 1].pos
        local fx, fy = next.x - prev.x, next.y - prev.y
        local fmag = sqrt(fx * fx + fy * fy)
        if fmag > 0.0001 then
            fx, fy = fx / fmag, fy / fmag
            local sx, sy = -fy, fx
            local tipX, tipY = curr.x + fx * aLen, curr.y + fy * aLen
            local tailX, tailY = curr.x - fx * (aLen * 0.55), curr.y - fy * (aLen * 0.55)
            newArrows[#newArrows + 1] = {
                tailX + sx * aWid, tailY + sy * aWid, curr.z,
                tipX, tipY, curr.z,
                tailX - sx * aWid, tailY - sy * aWid, curr.z,
                curr.x, curr.y,
            }
        end
    end

    guideState.points = points
    guideState.arrows = newArrows
    guideState.routeLength = routeLen
end

local function drawGuideRoute()
    local arrows = guideState.arrows
    if #arrows < 1 then return end

    local gcfg = SKWaypointConfig.GuideLines
    local ac = gcfg.arrowColor
    local ar, ag, ab, aa = ac.r, ac.g, ac.b, ac.a
    local rangeSq = gcfg.drawRange * gcfg.drawRange
    local px, py = playerCoords.x, playerCoords.y
    local DL = DrawLine

    for i = 1, #arrows do
        local a = arrows[i]
        local dx, dy = a[10] - px, a[11] - py
        if (dx * dx + dy * dy) <= rangeSq then
            DL(a[1], a[2], a[3], a[4], a[5], a[6], ar, ag, ab, aa)
            DL(a[7], a[8], a[9], a[4], a[5], a[6], ar, ag, ab, aa)
        end
    end
end

local function setGuideActive(wpId)
    guideState.activeWpId = wpId
    guideState.points = {}
    guideState.arrows = {}
    guideState.routeLength = 0.0
    guideState.lastUpdate = 0
end

local function clearGuideLines()
    guideState.activeWpId = nil
    guideState.points = {}
    guideState.arrows = {}
    guideState.routeLength = 0.0
end

function SKWaypoint.Create(data)
    if not data or not data.coords then
        return 0
    end

    local id = nextId
    nextId = nextId + 1

    local wp = {
        id           = id,
        coords       = data.coords,
        text         = data.text,
        color        = data.color,
        icon         = data.icon,
        imageUrl     = data.imageUrl,
        size         = data.size,
        maxRender    = data.maxRender,
        fadeStart    = data.fadeStart,
        showDist     = data.showDist,
        groundBeam   = data.groundBeam,
        beamHeight   = data.beamHeight,
        groundZ      = data.groundZ,
        removeAt     = data.removeAt,
        onRemove     = data.onRemove,
        countdown    = data.countdown,
        countdownEnd = data.countdown and (GetGameTimer() + data.countdown * 1000) or nil,
        guideLines   = data.guideLines,
        interactable = data.interactable,
        active       = true,
        rendering    = false,
        dui          = nil,
        lastDistTick = 0,
    }

    waypoints[id] = wp

    if wp.guideLines then
        setGuideActive(id)
    end

    return id
end

function SKWaypoint.Remove(id)
    local wp = waypoints[id]
    if not wp then return end
    if wp.dui then releaseDui(wp.dui) end
    if guideState.activeWpId == id then
        clearGuideLines()
    end
    if boostedWpId == id then
        boostedWpId = nil
        boostedOrigMaxRender = nil
        boostedOrigFadeStart = nil
    end
    waypoints[id] = nil
    if wp.onRemove then
        wp.onRemove(id, wp.coords)
    end
end

function SKWaypoint.RemoveAll()
    clearGuideLines()
    for id, wp in pairs(waypoints) do
        if wp.dui then releaseDui(wp.dui) end
        if wp.onRemove then
            wp.onRemove(id, wp.coords)
        end
    end
    waypoints = {}
    mapWaypointId = nil
    lastWaypointPos = nil
    boostedWpId = nil
    boostedOrigMaxRender = nil
    boostedOrigFadeStart = nil
end

function SKWaypoint.Update(id, data)
    local wp = waypoints[id]
    if not wp or not data then return end
    for k, v in pairs(data) do
        wp[k] = v
    end
    if wp.dui then
        pushToDui(wp)
        wp.duiConfigTicks = 8
    end
end

function SKWaypoint.Get(id)
    return waypoints[id]
end

function SKWaypoint.GetAll()
    return waypoints
end

RegisterNetEvent('streetkings:waypoints:client:create', function(data)
    local id = SKWaypoint.Create(data)
    if data._serverId then
        TriggerServerEvent('streetkings:waypoints:server:ack', data._serverId, id)
    end
end)

RegisterNetEvent('streetkings:waypoints:client:remove', function(id)
    SKWaypoint.Remove(id)
end)

RegisterNetEvent('streetkings:waypoints:client:removeAll', function()
    SKWaypoint.RemoveAll()
end)

RegisterNetEvent('streetkings:waypoints:client:update', function(id, data)
    SKWaypoint.Update(id, data)
end)

local NEARBY_RADIUS_SQ = 15.0 * 15.0

local boostedWpId        = nil
local boostedOrigMaxRender = nil
local boostedOrigFadeStart = nil

local function findNearbyWaypoint(pos)
    local bestId, bestDsq = nil, NEARBY_RADIUS_SQ
    for id, wp in pairs(waypoints) do
        if id ~= mapWaypointId and wp.active then
            local dx, dy = wp.coords.x - pos.x, wp.coords.y - pos.y
            local dsq = dx * dx + dy * dy
            if dsq < bestDsq then
                bestId = id
                bestDsq = dsq
            end
        end
    end
    return bestId
end

local function unboostWaypoint()
    if not boostedWpId then return end
    local wp = waypoints[boostedWpId]
    if wp then
        wp.maxRender = boostedOrigMaxRender
        wp.fadeStart = boostedOrigFadeStart
    end
    boostedWpId = nil
    boostedOrigMaxRender = nil
    boostedOrigFadeStart = nil
end

local function getWaypointCoords()
    if not IsWaypointActive() then return nil end

    local waypointBlip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypointBlip) then return nil end

    local pos = GetBlipInfoIdCoord(waypointBlip)

    local found, groundZ = false, pos.z
    for height = 800.0, 0.0, -50.0 do
        RequestCollisionAtCoord(pos.x, pos.y, height)
        Wait(0)
    end

    for zTest = 1000.0, 0.0, -25.0 do
        local success, z = GetGroundZFor_3dCoord(pos.x, pos.y, zTest, false)
        if success then
            groundZ = z
            found = true
            break
        end
    end

    if not found then groundZ = 0.0 end

    return vector3(pos.x, pos.y, groundZ + 2.0), groundZ
end

CreateThread(function()
    if not SKWaypointConfig.ReplaceMapWaypoint then return end

    Wait(1000)

    while true do
        local wpActive = IsWaypointActive()

        if wpActive then
            local pos, groundZ = getWaypointCoords()

            if pos then
                local posChanged = not lastWaypointPos
                    or math.abs(pos.x - lastWaypointPos.x) > 5.0
                    or math.abs(pos.y - lastWaypointPos.y) > 5.0

                if posChanged then
                    if mapWaypointId then
                        SKWaypoint.Remove(mapWaypointId)
                        mapWaypointId = nil
                    end
                    unboostWaypoint()

                    local nearbyId = findNearbyWaypoint(pos)
                    if nearbyId then
                        local wp = waypoints[nearbyId]
                        boostedWpId = nearbyId
                        boostedOrigMaxRender = wp.maxRender or SKWaypointConfig.Defaults.maxRender
                        boostedOrigFadeStart = wp.fadeStart or SKWaypointConfig.Defaults.fadeStart
                        wp.maxRender = SKWaypointConfig.MapWaypoint.maxRender
                        wp.fadeStart = SKWaypointConfig.MapWaypoint.fadeStart
                    else
                        local cfg = SKWaypointConfig.MapWaypoint
                        mapWaypointId = SKWaypoint.Create({
                            coords     = pos,
                            text       = cfg.text,
                            color      = cfg.color,
                            icon       = cfg.icon,
                            imageUrl   = cfg.imageUrl,
                            size       = cfg.size,
                            maxRender  = cfg.maxRender,
                            fadeStart  = cfg.fadeStart,
                            showDist   = cfg.showDist,
                            groundBeam = cfg.groundBeam,
                            beamHeight = cfg.beamHeight,
                            guideLines = cfg.guideLines,
                            groundZ    = groundZ,
                        })
                    end

                    lastWaypointPos = pos
                end
            end
        end

        if not wpActive and lastWaypointPos and (mapWaypointId or boostedWpId) then
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local dx = pCoords.x - lastWaypointPos.x
            local dy = pCoords.y - lastWaypointPos.y
            local flatDist = math.sqrt(dx * dx + dy * dy)

            local shouldRemove = false

            if wasWaypointActive and flatDist > 80.0 then
                shouldRemove = true
            elseif flatDist < 8.0 then
                shouldRemove = true
            end

            if shouldRemove then
                if mapWaypointId then
                    SKWaypoint.Remove(mapWaypointId)
                    mapWaypointId = nil
                end
                unboostWaypoint()
                lastWaypointPos = nil
            end
        end

        wasWaypointActive = wpActive

        Wait(350)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        playerCoords = GetEntityCoords(ped)
        camCoords = GetGameplayCamCoord()

        local now = GetGameTimer()

        local duisAcquired = 0
        local maxAcquirePerTick = 2

        for id, wp in pairs(waypoints) do
            if wp.active then
                local dSq = distSq(camCoords, wp.coords)
                local maxR = wp.maxRender or SKWaypointConfig.Defaults.maxRender
                local inRange = dSq <= (maxR * maxR)

                if wp.removeAt then
                    local pDistSq = distSq(playerCoords, wp.coords)
                    if pDistSq <= (wp.removeAt * wp.removeAt) then
                        SKWaypoint.Remove(id)
                        goto continue
                    end
                end

                if wp.countdownEnd and now >= wp.countdownEnd then
                    SKWaypoint.Remove(id)
                    goto continue
                end

                if inRange and not wp.rendering then
                    if duisAcquired < maxAcquirePerTick then
                        wp.dui = acquireDui()
                        wp.rendering = true
                        wp.duiConfigTicks = 8
                        pushToDui(wp)
                        duisAcquired = duisAcquired + 1
                    end
                elseif not inRange and wp.rendering then
                    releaseDui(wp.dui)
                    wp.dui = nil
                    wp.rendering = false
                end

                if wp.rendering and (wp.showDist ~= false) then
                    if now - wp.lastDistTick >= SKWaypointConfig.DistanceRefreshRate then
                        wp.lastDistTick = now
                        pushDistance(wp, dist3d(playerCoords, wp.coords))
                    end
                end

                if wp.rendering and wp.duiConfigTicks and wp.duiConfigTicks > 0 then
                    wp.duiConfigTicks = wp.duiConfigTicks - 1
                    pushToDui(wp)
                end
            end
            ::continue::
        end

        Wait(SKWaypointConfig.TickRate)
    end
end)

CreateThread(function()
    while true do
        local hasAny = false
        local hasGuide = guideState.activeWpId ~= nil and #guideState.arrows >= 1
        local cam = GetFinalRenderedCamCoord()
        local cx, cy, cz = cam.x, cam.y, cam.z
        for _, wp in pairs(waypoints) do
            if wp.rendering then
                hasAny = true
                renderQuad(wp, cx, cy, cz)
            end
        end
        if hasGuide then
            local gcfg = SKWaypointConfig.GuideLines
            if gcfg.drawOnFoot or IsPedInAnyVehicle(PlayerPedId(), false) then
                hasAny = true
                drawGuideRoute()
            end
        end
        Wait(hasAny and 0 or 500)
    end
end)

CreateThread(function()
    while true do
        if guideState.activeWpId then
            local now = GetGameTimer()
            local wp = waypoints[guideState.activeWpId]
            local destChanged = false
            if wp then
                local blip = GetFirstBlipInfoId(8)
                if blip and blip ~= 0 and DoesBlipExist(blip) then
                    local bc = GetBlipInfoIdCoord(blip)
                    if bc then
                        local pts = guideState.points
                        if #pts < 2 then
                            destChanged = true
                        else
                            local lp = pts[#pts].pos
                            local ddx, ddy = bc.x - lp.x, bc.y - lp.y
                            if (ddx * ddx + ddy * ddy) > 1.0 then
                                destChanged = true
                            end
                        end
                    end
                end
            end
            if destChanged then
                guideState.lastUpdate = now
                rebuildGuideRoute()
            elseif now - guideState.lastUpdate >= SKWaypointConfig.GuideLines.updateInterval then
                guideState.lastUpdate = now
                rebuildGuideRoute()
            end
        end
        Wait(250)
    end
end)

exports('CreateWaypoint', SKWaypoint.Create)
exports('RemoveWaypoint', SKWaypoint.Remove)
exports('RemoveAllWaypoints', SKWaypoint.RemoveAll)

CreateThread(function()
    ReplaceHudColourWithRgba(142, 255, 210, 0, 255)
end)