local DEVTOOLS_CONVAR = 'streetkings_enableDevtools'
if GetConvar(DEVTOOLS_CONVAR, 'false') ~= 'true' then
    return
end

local buildMode      = false
local rampMode       = false
local rampTarget     = 'a'
local testMode       = false
local editingJumpId  = nil
local editingJumpName = nil

local RAMP_MODELS = {
    'stt_prop_ramp_jump_s',
    'stt_prop_ramp_jump_m',
    'stt_prop_ramp_jump_l',
    'stt_prop_ramp_jump_xl',
    'stt_prop_ramp_jump_xxl',
    'lts_prop_lts_ramp_01',
    'lts_prop_lts_ramp_02',
    'lts_prop_lts_ramp_03',
    'prop_mp_ramp_01_tu',
    'prop_mp_ramp_02_tu',
    'prop_mp_ramp_03_tu',
}

local rampModelIndex  = 1
local currentHeading  = 0.0
local zoneRadius      = 12.0
local sessionMarker   = nil

local stuntDef = {
    zoneA     = nil,
    zoneARamp = nil,
    zoneB     = nil,
    zoneBRamp = nil,
}

local previewProp      = nil
local previewModelName = nil
local placedPreviews   = {}
local raycastHit       = nil
local devInputResult   = false

local debugZoneA = nil
local debugZoneB = nil

local devConfirmResult = nil

RegisterNUICallback('stuntdev:confirmResult', function(data, cb)
    cb('ok')
    devConfirmResult = data.choice
end)

local function showConfirmDialog(eyebrow, title, body)
    devConfirmResult = nil
    SendNUIMessage({ type = 'stuntdev:confirm', show = true, eyebrow = eyebrow, title = title, body = body })
    SetNuiFocus(true, true)
    while devConfirmResult == nil do Wait(50) end
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'stuntdev:confirm', show = false })
    return devConfirmResult == 'yes'
end

RegisterNUICallback('stuntdev:inputResult', function(data, cb)
    cb('ok')
    devInputResult = data.value
end)

local function showInputDialog(eyebrow, title, placeholder, defaultValue)
    devInputResult = false
    SendNUIMessage({ type = 'stuntdev:input', show = true, eyebrow = eyebrow, title = title, placeholder = placeholder, defaultValue = defaultValue or '' })
    SetNuiFocus(true, true)
    while devInputResult == false do Wait(50) end
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'stuntdev:input', show = false })
    return devInputResult
end

local function notify(title, nType)
    SKNotify({ title = title, type = nType, duration = 2500, inCinematic = true })
end

local function deletePreviewProp()
    if previewProp then
        if DoesEntityExist(previewProp) then DeleteEntity(previewProp) end
        previewProp = nil
        previewModelName = nil
    end
end

local function clearPlacedPreviews()
    for i = 1, #placedPreviews do
        if DoesEntityExist(placedPreviews[i]) then DeleteEntity(placedPreviews[i]) end
    end
    placedPreviews = {}
end

local function createPreviewProp(model, pos, heading)
    deletePreviewProp()
    local hash = SK.LoadModel(model)
    if not hash then return end
    previewProp = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(previewProp, heading)
    PlaceObjectOnGroundProperly(previewProp)
    FreezeEntityPosition(previewProp, true)
    SetEntityAlpha(previewProp, 150, false)
    SetEntityCollision(previewProp, false, false)
    previewModelName = model
end

local function updatePreviewProp(model, pos, heading)
    if not previewProp or not DoesEntityExist(previewProp) or previewModelName ~= model then
        createPreviewProp(model, pos, heading)
        return
    end
    SetEntityCoordsNoOffset(previewProp, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(previewProp, heading)
    PlaceObjectOnGroundProperly(previewProp)
end

local function spawnPlacedPreview(model, pos, heading)
    local hash = SK.LoadModel(model)
    if not hash then return nil end
    local obj = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(obj, heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAlpha(obj, 200, false)
    SetEntityCollision(obj, false, false)
    placedPreviews[#placedPreviews + 1] = obj
    return obj
end

local function rebuildPlacedPreviews()
    clearPlacedPreviews()
    if stuntDef.zoneARamp then
        spawnPlacedPreview(stuntDef.zoneARamp.model, stuntDef.zoneARamp.coords, stuntDef.zoneARamp.heading)
    end
    if stuntDef.zoneBRamp then
        spawnPlacedPreview(stuntDef.zoneBRamp.model, stuntDef.zoneBRamp.coords, stuntDef.zoneBRamp.heading)
    end
end

local function removeDebugZones()
    if debugZoneA then debugZoneA:remove() debugZoneA = nil end
    if debugZoneB then debugZoneB:remove() debugZoneB = nil end
end

local function createDebugZone(zoneDef, colour)
    if not zoneDef then return nil end
    return lib.zones.sphere({
        coords      = zoneDef.center,
        radius      = zoneDef.radius,
        debug       = true,
        debugColour = colour,
    })
end

local function refreshDebugZones()
    removeDebugZones()
    debugZoneA = createDebugZone(stuntDef.zoneA, { 0, 255, 100, 70 })
    debugZoneB = createDebugZone(stuntDef.zoneB, { 100, 100, 255, 70 })
end

local function slugify(name)
    return 'stunt_' .. name:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
end

local function buildZoneExportLine(key, z, rampDef)
    local fv3 = function(v) return ('vector3(%.4f, %.4f, %.4f)'):format(v.x, v.y, v.z) end
    local parts = { ('center = %s'):format(fv3(z.center)), ('radius = %.1f'):format(z.radius) }
    if rampDef then
        parts[#parts + 1] = ("ramp = { model = '%s', coords = %s, heading = %.1f }"):format(
            rampDef.model, fv3(rampDef.coords), rampDef.heading)
    end
    return ('    %s = { %s },'):format(key, table.concat(parts, ', '))
end

local function buildExport()
    local lines = { '{' }
    if stuntDef.zoneA then
        lines[#lines + 1] = buildZoneExportLine('zoneA', stuntDef.zoneA, stuntDef.zoneARamp)
    end
    if stuntDef.zoneB then
        lines[#lines + 1] = buildZoneExportLine('zoneB', stuntDef.zoneB, stuntDef.zoneBRamp)
    end
    lines[#lines + 1] = '}'
    return table.concat(lines, '\n')
end

local function buildDefForSave(id, name)
    local function buildZone(z, ramp)
        return { center = z.center, radius = z.radius, ramp = ramp }
    end
    return {
        id    = id,
        name  = name,
        zoneA = buildZone(stuntDef.zoneA, stuntDef.zoneARamp),
        zoneB = buildZone(stuntDef.zoneB, stuntDef.zoneBRamp),
    }
end

local function resetDef()
    stuntDef = { zoneA = nil, zoneARamp = nil, zoneB = nil, zoneBRamp = nil }
    clearPlacedPreviews()
    deletePreviewProp()
    removeDebugZones()
    rampMode = false
    rampTarget = 'a'
    zoneRadius = 12.0
    currentHeading = 0.0
    rampModelIndex = 1
    sessionMarker = nil
    editingJumpId = nil
    editingJumpName = nil
end

local function undoLast()
    local order = { 'zoneBRamp', 'zoneB', 'zoneARamp', 'zoneA' }
    for _, key in ipairs(order) do
        if stuntDef[key] then
            stuntDef[key] = nil
            rebuildPlacedPreviews()
            refreshDebugZones()
            notify(('Undid %s'):format(key), 'warning')
            return
        end
    end
    notify('Nothing to undo', 'warning')
end

local function saveToDB(name)
    if not stuntDef.zoneA or not stuntDef.zoneB then
        notify('Need both zones before saving', 'error')
        return
    end
    local id = editingJumpId or slugify(name)
    local def = buildDefForSave(id, name)
    local result = lib.callback.await('streetkings:stunts:save', false, def)
    if result and result.ok then
        notify(('Saved "%s"'):format(name), 'success')
    else
        notify(('Save failed: %s'):format(result and result.reason or 'unknown'), 'error')
    end
end

local function exportToClipboard()
    if not stuntDef.zoneA and not stuntDef.zoneB then
        notify('Nothing to export', 'error')
        return
    end
    lib.setClipboard(buildExport())
    notify('Exported to clipboard', 'success')
end

-- NUI helpers

local function sendPanelUpdate()
    SendNUIMessage({
        type           = 'stuntdev:update',
        rampMode       = rampMode,
        rampTarget     = rampTarget,
        rampModel      = RAMP_MODELS[rampModelIndex],
        heading        = currentHeading,
        radius         = zoneRadius,
        hasZoneA       = stuntDef.zoneA ~= nil,
        hasZoneB       = stuntDef.zoneB ~= nil,
        hasSessionMark = sessionMarker ~= nil,
        editingId      = editingJumpId,
        editingName    = editingJumpName,
        placed         = {
            zoneA     = stuntDef.zoneA ~= nil,
            zoneARamp = stuntDef.zoneARamp ~= nil,
            zoneB     = stuntDef.zoneB ~= nil,
            zoneBRamp = stuntDef.zoneBRamp ~= nil,
        },
    })
end

local function hidePanelNUI()
    SendNUIMessage({ type = 'stuntdev:hide' })
end

local function drawPreviewZone(center, r, g, b, a)
    DrawMarker(1, center.x, center.y, center.z, 0, 0, 0, 0, 0, 0,
        zoneRadius * 2, zoneRadius * 2, 0.5, r, g, b, a, false, true, 2, false, nil, nil, false)
end

local function drawConnectionLine()
    if stuntDef.zoneA and stuntDef.zoneB then
        local ac, bc = stuntDef.zoneA.center, stuntDef.zoneB.center
        DrawLine(ac.x, ac.y, ac.z + 0.3, bc.x, bc.y, bc.z + 0.3, 255, 210, 0, 200)
    end
end

local function drawSessionMarker()
    if not sessionMarker then return end
    local c = sessionMarker.coords
    DrawMarker(2, c.x, c.y, c.z + 1.5, 0, 0, 0, 180.0, 0, 0,
        0.4, 0.4, 0.4, 255, 210, 0, 200, true, true, 2, true, nil, nil, false)
end

local CTRL_LMB       = 24
local CTRL_SCROLL_DN = 14
local CTRL_SCROLL_UP = 15
local CTRL_G         = 47
local CTRL_R         = 45
local CTRL_1         = 157
local CTRL_2         = 158
local CTRL_BACKSPACE = 177
local CTRL_DELETE    = 179
local CTRL_ENTER     = 191
local CTRL_ESC       = 200
local CTRL_T         = 0
local CTRL_M         = 0


local EXTRA_CONTROLS = { CTRL_LMB, CTRL_SCROLL_DN, CTRL_SCROLL_UP, CTRL_G, CTRL_R, CTRL_1, CTRL_2, CTRL_BACKSPACE, CTRL_DELETE, CTRL_ENTER, CTRL_ESC }

local function makeZoneDef(pos)
    return { center = pos, radius = zoneRadius }
end

local function handleZoneModeInput()
    if IsDisabledControlJustPressed(0, CTRL_SCROLL_DN) then
        zoneRadius = math.max(2.0, zoneRadius - 1.0)
    elseif IsDisabledControlJustPressed(0, CTRL_SCROLL_UP) then
        zoneRadius = math.min(50.0, zoneRadius + 1.0)
    end

    if raycastHit then
        local r, g, b = 0, 255, 100
        if stuntDef.zoneA and not stuntDef.zoneB then r, g, b = 100, 100, 255 end
        drawPreviewZone(raycastHit, r, g, b, 50)
    end

    if IsDisabledControlJustPressed(0, CTRL_LMB) and raycastHit then
        local pos = vec3(raycastHit.x, raycastHit.y, raycastHit.z)
        if not stuntDef.zoneA then
            stuntDef.zoneA = makeZoneDef(pos)
            notify('Zone A placed', 'success')
        elseif not stuntDef.zoneB then
            stuntDef.zoneB = makeZoneDef(pos)
            notify('Zone B placed', 'success')
        else
            stuntDef.zoneA = stuntDef.zoneB
            stuntDef.zoneARamp = stuntDef.zoneBRamp
            stuntDef.zoneB = makeZoneDef(pos)
            stuntDef.zoneBRamp = nil
            rebuildPlacedPreviews()
            notify('Zones shifted, new Zone B placed', 'success')
        end
        refreshDebugZones()
    end
end

local function handleRampModeInput()
    if IsDisabledControlJustPressed(0, CTRL_SCROLL_DN) then
        currentHeading = (currentHeading - 5.0) % 360.0
    elseif IsDisabledControlJustPressed(0, CTRL_SCROLL_UP) then
        currentHeading = (currentHeading + 5.0) % 360.0
    end

    if IsDisabledControlJustPressed(0, CTRL_G) then
        rampModelIndex = (rampModelIndex % #RAMP_MODELS) + 1
        deletePreviewProp()
        notify(RAMP_MODELS[rampModelIndex], 'inform')
    end

    if IsDisabledControlJustPressed(0, CTRL_1) then
        rampTarget = 'a'
        notify('Ramp target: Zone A', 'inform')
    elseif IsDisabledControlJustPressed(0, CTRL_2) then
        rampTarget = 'b'
        notify('Ramp target: Zone B', 'inform')
    end

    if raycastHit then
        updatePreviewProp(RAMP_MODELS[rampModelIndex], raycastHit, currentHeading)
    end

    if IsDisabledControlJustPressed(0, CTRL_LMB) and raycastHit then
        local pos = vec3(raycastHit.x, raycastHit.y, raycastHit.z)
        local rampDef = { model = RAMP_MODELS[rampModelIndex], coords = pos, heading = currentHeading }
        if rampTarget == 'a' then
            stuntDef.zoneARamp = rampDef
            notify('Ramp A placed', 'success')
        else
            stuntDef.zoneBRamp = rampDef
            notify('Ramp B placed', 'success')
        end
        rebuildPlacedPreviews()
    end
end

-- Test jump mode
local function enterTestMode()
    if not stuntDef.zoneA or not stuntDef.zoneB then
        notify('Place both zones before testing', 'error')
        return
    end

    deletePreviewProp()
    hidePanelNUI()
    SKRaceEditorFreecam.stop()
    Cinematic = false

    local tempId = '_test_session'
    local tempName = 'Test Session'
    local tempDef = buildDefForSave(tempId, tempName)

    exports[GetCurrentResourceName()]:SetupTestJump(tempId, tempDef)

    local spawnPos = sessionMarker and sessionMarker.coords or stuntDef.zoneA.center
    local spawnHdg = sessionMarker and sessionMarker.heading or 0.0

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        SetEntityCoordsNoOffset(veh, spawnPos.x, spawnPos.y, spawnPos.z + 1.0, false, false, false)
        SetEntityHeading(veh, spawnHdg)
        SetVehicleOnGroundProperly(veh)
    else
        SetEntityCoordsNoOffset(ped, spawnPos.x, spawnPos.y, spawnPos.z + 1.0, false, false, false)
        SetEntityHeading(ped, spawnHdg)
    end

    testMode = true
    notify('Test mode -- press Esc to return', 'inform')

    local CTRL_PGDN = 208
    local CTRL_PGUP = 207

    CreateThread(function()
        while testMode do
            DisableControlAction(0, CTRL_ESC, true)
            DisableControlAction(0, CTRL_PGDN, true)
            DisableControlAction(0, CTRL_PGUP, true)

            if IsDisabledControlJustPressed(0, CTRL_ESC) then
                testMode = false
            end

            if IsDisabledControlJustPressed(0, CTRL_PGDN) then
                local p = PlayerPedId()
                local v = GetVehiclePedIsIn(p, false)
                local pos = GetEntityCoords(v ~= 0 and v or p)
                local hdg = GetEntityHeading(v ~= 0 and v or p)
                sessionMarker = { coords = vec3(pos.x, pos.y, pos.z), heading = hdg }
                notify('Spawn marker placed', 'success')
            end

            if IsDisabledControlJustPressed(0, CTRL_PGUP) and sessionMarker then
                local p = PlayerPedId()
                local v = GetVehiclePedIsIn(p, false)
                local sp = sessionMarker.coords
                if v ~= 0 then
                    SetEntityCoordsNoOffset(v, sp.x, sp.y, sp.z + 1.0, false, false, false)
                    SetEntityHeading(v, sessionMarker.heading)
                    SetVehicleOnGroundProperly(v)
                else
                    SetEntityCoordsNoOffset(p, sp.x, sp.y, sp.z + 1.0, false, false, false)
                    SetEntityHeading(p, sessionMarker.heading)
                end
                notify('Returned to marker', 'inform')
            end

            Wait(0)
        end

        exports[GetCurrentResourceName()]:TeardownTestJump(tempId)

        Cinematic = true
        SKRaceEditorFreecam.start()

        notify('Returned to creator', 'inform')
    end)
end

-- Edit nearest jump
local function findNearestJump()
    if not SKStuntJumps then return nil end
    local myPos = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, 200.0
    for id, def in pairs(SKStuntJumps) do
        if def.zoneA and def.zoneA.center then
            local c = type(def.zoneA.center) == 'vector3' and def.zoneA.center
                or vector3(def.zoneA.center.x, def.zoneA.center.y, def.zoneA.center.z)
            local d = #(myPos - c)
            if d < bestDist then
                bestDist = d
                best = { id = id, def = def, dist = d }
            end
        end
    end
    return best
end

local function loadZoneFromDef(z)
    if not z then return nil end
    local c = { center = z.center, radius = z.radius or 10.0 }
    if z.shape == 'box' and z.size then
        local sz = type(z.size) == 'vector3' and z.size
            or vec3(tonumber(z.size.x or z.size[1]) or 24.0, tonumber(z.size.y or z.size[2]) or 24.0, tonumber(z.size.z or z.size[3]) or 4.0)
        c.radius = math.max(sz.x, sz.y) * 0.5
    end
    return c
end

local function loadDefFromSaved(def)
    stuntDef = { zoneA = nil, zoneARamp = nil, zoneB = nil, zoneBRamp = nil }

    if def.zoneA then
        stuntDef.zoneA = loadZoneFromDef(def.zoneA)
        if def.zoneA.ramp then
            stuntDef.zoneARamp = {
                model   = def.zoneA.ramp.model,
                coords  = def.zoneA.ramp.coords,
                heading = def.zoneA.ramp.heading or 0.0,
            }
        end
        zoneRadius = stuntDef.zoneA.radius or 12.0
    end

    if def.zoneB then
        stuntDef.zoneB = loadZoneFromDef(def.zoneB)
        if def.zoneB.ramp then
            stuntDef.zoneBRamp = {
                model   = def.zoneB.ramp.model,
                coords  = def.zoneB.ramp.coords,
                heading = def.zoneB.ramp.heading or 0.0,
            }
        end
    end

    rebuildPlacedPreviews()
    refreshDebugZones()
end

-- T key via command binding
RegisterCommand('+stuntdev_test', function()
    if not buildMode or testMode then return end
    enterTestMode()
end, false)
RegisterKeyMapping('+stuntdev_test', 'Stunt Dev Test Jump', 'keyboard', 't')

-- M key via command binding
RegisterCommand('+stuntdev_marker', function()
    if not buildMode or testMode then return end
    if raycastHit then
        local camRot = GetGameplayCamRot(2)
        sessionMarker = { coords = vec3(raycastHit.x, raycastHit.y, raycastHit.z), heading = camRot.z }
        notify('Session marker placed', 'success')
    else
        notify('No surface hit', 'error')
    end
end, false)
RegisterKeyMapping('+stuntdev_marker', 'Stunt Dev Place Session Marker', 'keyboard', 'm')

local function startBuildThread()
    CreateThread(function()
        Cinematic = true
        SKRaceEditorFreecam.start()

        CreateThread(function()
            while buildMode do
                raycastHit = SKRaceEditorFreecam.raycast()
                Wait(16)
            end
        end)

        while buildMode do
            Wait(0)

            if testMode then goto continue end
            if not SKRaceEditorFreecam.isEnabled() then break end

            for _, ctrl in ipairs(EXTRA_CONTROLS) do
                EnableControlAction(0, ctrl, true)
            end

            drawConnectionLine()
            drawSessionMarker()

            if rampMode then
                handleRampModeInput()
            else
                if previewProp then deletePreviewProp() end
                handleZoneModeInput()
            end

            sendPanelUpdate()

            if IsDisabledControlJustPressed(0, CTRL_R) then
                rampMode = not rampMode
                if rampMode then
                    notify('Switched to Ramp Mode', 'inform')
                else
                    deletePreviewProp()
                    notify('Switched to Zone Mode', 'inform')
                end
            end

            if IsDisabledControlJustPressed(0, CTRL_BACKSPACE) then
                undoLast()
            end

            if IsDisabledControlJustPressed(0, CTRL_DELETE) then
                if rampMode then
                    if rampTarget == 'a' and stuntDef.zoneARamp then
                        stuntDef.zoneARamp = nil
                        rebuildPlacedPreviews()
                        notify('Ramp A deleted', 'warning')
                    elseif rampTarget == 'b' and stuntDef.zoneBRamp then
                        stuntDef.zoneBRamp = nil
                        rebuildPlacedPreviews()
                        notify('Ramp B deleted', 'warning')
                    else
                        notify('No ramp to delete', 'warning')
                    end
                else
                    resetDef()
                    notify('All placements cleared', 'warning')
                end
            end

            if IsDisabledControlJustPressed(0, CTRL_ENTER) then
                if not stuntDef.zoneA or not stuntDef.zoneB then
                    notify('Place both zones before saving', 'error')
                else
                    local name = showInputDialog('Save', 'Name this stunt jump', 'Enter a name...', editingJumpName or '')
                    if name and name ~= '' then
                        saveToDB(name)
                        buildMode = false
                    else
                        notify('Save cancelled', 'warning')
                    end
                end
            end

            if IsDisabledControlJustPressed(0, CTRL_ESC) then
                buildMode = false
                notify('Stunt Dev Tool closed', 'warning')
                break
            end

            ::continue::
        end

        deletePreviewProp()
        clearPlacedPreviews()
        removeDebugZones()
        hidePanelNUI()
        SKRaceEditorFreecam.stop()
        Cinematic = false
        raycastHit = nil
        testMode = false
        editingJumpId = nil
        editingJumpName = nil
    end)
end

RegisterCommand('+stuntdev_export', function()
    if buildMode then exportToClipboard() end
end, false)
RegisterKeyMapping('+stuntdev_export', 'Stunt Dev Export to Clipboard', 'keyboard', 'F9')

RegisterCommand('+stuntdev_clear', function()
    if buildMode then
        resetDef()
        notify('All placements cleared', 'warning')
    end
end, false)
RegisterKeyMapping('+stuntdev_clear', 'Stunt Dev Clear All', 'keyboard', 'F10')

RegisterCommand('+stuntdev_undo', function()
    if buildMode then undoLast() end
end, false)
RegisterKeyMapping('+stuntdev_undo', 'Stunt Dev Undo Last', 'keyboard', 'F12')

RegisterCommand('stuntdev', function()
    if buildMode then
        buildMode = false
        notify('Stunt Dev Tool closed', 'warning')
        return
    end
    buildMode = true
    rampMode = false
    rampTarget = 'a'
    editingJumpId = nil
    editingJumpName = nil
    notify('Stunt Jump Creator opened', 'success')
    startBuildThread()
end, true)

RegisterCommand('stuntedit', function()
    if buildMode then
        notify('Already in build mode', 'error')
        return
    end
    local nearest = findNearestJump()
    if not nearest then
        notify('No stunt jump within 200m', 'error')
        return
    end

    editingJumpId = nearest.id
    editingJumpName = nearest.def.name or nearest.id
    exports[GetCurrentResourceName()]:TeardownTestJump(nearest.id)
    loadDefFromSaved(nearest.def)

    buildMode = true
    rampMode = false
    rampTarget = 'a'
    notify(('Editing "%s" (%.0fm away)'):format(editingJumpName, nearest.dist), 'success')
    startBuildThread()
end, true)

RegisterCommand('stuntdelete', function()
    local nearest = findNearestJump()
    if not nearest then
        notify('No stunt jump within 200m', 'error')
        return
    end

    local jumpName = nearest.def.name or nearest.id
    local confirmed = showConfirmDialog('Delete', 'Are you sure?', 'Delete Stunt Jump: ' .. jumpName)
    if not confirmed then
        notify('Delete cancelled', 'warning')
        return
    end

    local result = lib.callback.await('streetkings:stunts:delete', false, nearest.id)
    if result and result.ok then
        notify(('Deleted "%s"'):format(jumpName), 'success')
    else
        notify(('Delete failed: %s'):format(result and result.reason or 'unknown'), 'error')
    end
end, true)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        buildMode = false
        testMode = false
        deletePreviewProp()
        clearPlacedPreviews()
        removeDebugZones()
        hidePanelNUI()
        if SKRaceEditorFreecam and SKRaceEditorFreecam.isEnabled() then
            SKRaceEditorFreecam.stop()
        end
        SetNuiFocus(false, false)
    end
end)
