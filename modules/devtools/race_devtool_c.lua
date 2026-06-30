local DEVTOOLS_CONVAR = 'streetkings_enableDevtools'
if GetConvar(DEVTOOLS_CONVAR, 'false') ~= 'true' then
    return
end

Citizen.Trace(('[streetkings] race editor enabled (%s)\n'):format(DEVTOOLS_CONVAR))

local DEFAULT_EVENT_ID = 'track_sprint_editor'
local DEFAULT_EVENT_NAME = 'Editor Race'
local SCHEME_ORDER = {
    CheckpointScheme.ORDERED,
    CheckpointScheme.CIRCUIT,
    CheckpointScheme.THEREANDBACK,
    CheckpointScheme.UNORDERED,
}

local editorEnabled = false
local raycastHit = nil
local lastPreviewCheckpoint = nil
local lastPreviewBlip = nil
local lastPreviewBlipNext = nil
local previewRoute = {}

local draft = {
    id = DEFAULT_EVENT_ID,
    name = DEFAULT_EVENT_NAME,
    scheme = CheckpointScheme.ORDERED,
    start = nil,
    checkpoints = {},
}

---@param title string
---@param notifyType string
---@return nil
local function notify(title, notifyType)
    SKNotify({
        title = title,
        type = notifyType,
        duration = 2500,
    })
end

local function canUseRaceEditor()
    local resource = GetCurrentResourceName()
    return exports[resource]:HasCachedPermission('racing.create_event')
        or exports[resource]:HasCachedPermission('racing.manage')
        or exports[resource]:HasCachedPermission('debug')
        or exports[resource]:HasCachedPermission('framework.inspect')
end

local function requireRaceEditor()
    if canUseRaceEditor() then return true end
    notify('No permission', 'error')
    return false
end

---@return integer
local function getStartEntity()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        return vehicle
    end
    return ped
end

---@return vector4
local function captureStart()
    local entity = getStartEntity()
    local coords = GetEntityCoords(entity)
    return vector4(coords.x, coords.y, coords.z, GetEntityHeading(entity))
end

---@return table
local function buildDraftDefinition()
    return {
        id = draft.id,
        name = draft.name,
        type = EventType.RACE,
        mode = RaceMode.SINGLEPLAYER,
        scheme = draft.scheme,
        goalTime = nil,
        start = draft.start,
        checkpoints = draft.checkpoints,
    }
end

---@return nil
local function clearPreviewHandles()
    SKEventPreview.clearCheckpoint(lastPreviewCheckpoint, lastPreviewBlip, lastPreviewBlipNext)
    lastPreviewCheckpoint = nil
    lastPreviewBlip = nil
    lastPreviewBlipNext = nil
    SKEventPreview.clearGpsTrack()
    previewRoute = {}
end

---@return nil
local function refreshPreview()
    clearPreviewHandles()

    if not editorEnabled or not draft.start then
        return
    end

    local definition = buildDraftDefinition()
    previewRoute = SKEventRoute.buildPreviewRoute(definition)
    if #previewRoute > 1 then
        SKEventPreview.renderGpsTrack(previewRoute)
    end

    if #draft.checkpoints == 0 then
        return
    end

    if draft.scheme == CheckpointScheme.UNORDERED then
        lastPreviewCheckpoint, lastPreviewBlip = SKEventPreview.createStaticCheckpoint(
            draft.checkpoints[#draft.checkpoints],
            false
        )
        return
    end

    local expandedCheckpoints = SKEventRoute.buildCheckpointList(definition)
    local authoredIndex = #draft.checkpoints
    local current = expandedCheckpoints[authoredIndex]
    local nextCheckpoint = expandedCheckpoints[authoredIndex + 1]
    local isLast = authoredIndex == #expandedCheckpoints
    lastPreviewCheckpoint, lastPreviewBlip, lastPreviewBlipNext =
        SKEventPreview.createCheckpoint(current, nextCheckpoint, isLast, false)
end

---@return vector3|nil
local function getPlacementOrigin()
    if #draft.checkpoints > 0 then
        return draft.checkpoints[#draft.checkpoints]
    end
    if not draft.start then
        return nil
    end
    return SKEventRoute.toVector3(draft.start)
end

---@param coords vector3
---@return string
local function formatExportVec3(coords)
    return ('vec3(%.4f, %.4f, %.4f)'):format(coords.x, coords.y, coords.z)
end

---@param coords vector4
---@return string
local function formatExportVec4(coords)
    return ('vector4(%.4f, %.4f, %.4f, %.4f)'):format(coords.x, coords.y, coords.z, coords.w)
end

---@param scheme string
---@return string
local function formatSchemeExport(scheme)
    if scheme == CheckpointScheme.CIRCUIT then
        return 'CheckpointScheme.CIRCUIT'
    end
    if scheme == CheckpointScheme.THEREANDBACK then
        return 'CheckpointScheme.THEREANDBACK'
    end
    if scheme == CheckpointScheme.UNORDERED then
        return 'CheckpointScheme.UNORDERED'
    end
    return 'CheckpointScheme.ORDERED'
end

---@return string
local function buildEventExport()
    local lines = {
        '    {',
        ("        id          = '%s',"):format(draft.id),
        ('        name        = "%s",'):format(draft.name),
        '        type        = EventType.RACE,',
        '        mode        = RaceMode.SINGLEPLAYER,',
        ('        scheme      = %s,'):format(formatSchemeExport(draft.scheme)),
        '        goalTime    = nil,',
        ('        start       = %s,'):format(formatExportVec4(draft.start)),
        '        checkpoints = {',
    }

    for index, checkpoint in ipairs(draft.checkpoints) do
        local suffix = index < #draft.checkpoints and ',' or ''
        lines[#lines + 1] = ('            %s%s'):format(formatExportVec3(checkpoint), suffix)
    end

    lines[#lines + 1] = '        },'
    lines[#lines + 1] = '    },'
    return table.concat(lines, '\n')
end

---@return nil
local function copyDraft()
    if not draft.start then
        notify('No Start Position Set', 'error')
        return
    end
    if #draft.checkpoints == 0 then
        notify('No Checkpoints To Copy', 'error')
        return
    end

    lib.setClipboard(buildEventExport())
    notify(('Copied %d Checkpoints'):format(#draft.checkpoints), 'success')
end

---@return integer|nil
local function getSchemeIndex()
    for index, scheme in ipairs(SCHEME_ORDER) do
        if scheme == draft.scheme then
            return index
        end
    end
    return nil
end

---@param scheme string
---@return nil
local function setScheme(scheme)
    draft.scheme = scheme
    refreshPreview()
    notify(('Scheme: %s'):format(string.upper(scheme)), 'success')
end

---@return nil
local function cycleScheme()
    local currentIndex = getSchemeIndex() or 1
    local nextIndex = currentIndex + 1
    if nextIndex > #SCHEME_ORDER then
        nextIndex = 1
    end
    setScheme(SCHEME_ORDER[nextIndex])
end

---@return nil
local function setStartFromPlayer()
    draft.start = captureStart()
    refreshPreview()
    notify('Race Start Updated', 'success')
end

---@param checkpoint vector3
---@return nil
local function addCheckpoint(checkpoint)
    draft.checkpoints[#draft.checkpoints + 1] = checkpoint
    refreshPreview()
    notify(('Checkpoint %d Added'):format(#draft.checkpoints), 'success')
end

---@return nil
local function placeCheckpointAtRaycast()
    if not editorEnabled then
        notify('Editor Mode Is Off', 'error')
        return
    end
    if not raycastHit then
        notify('No Valid Surface Detected', 'error')
        return
    end

    addCheckpoint(vec3(raycastHit.x, raycastHit.y, raycastHit.z))
end

---@return nil
local function moveLastCheckpoint()
    if not editorEnabled then
        notify('Editor Mode Is Off', 'error')
        return
    end
    if #draft.checkpoints == 0 then
        notify('No Checkpoint To Move', 'error')
        return
    end
    if not raycastHit then
        notify('No Valid Surface Detected', 'error')
        return
    end

    draft.checkpoints[#draft.checkpoints] = vec3(raycastHit.x, raycastHit.y, raycastHit.z)
    refreshPreview()
    notify('Last Checkpoint Moved', 'success')
end

---@return nil
local function popCheckpoint()
    if #draft.checkpoints == 0 then
        notify('No Checkpoints To Remove', 'error')
        return
    end

    table.remove(draft.checkpoints, #draft.checkpoints)
    refreshPreview()
    notify(('Removed Last Checkpoint (%d Remaining)'):format(#draft.checkpoints), 'warning')
end

---@return nil
local function clearCheckpointStack()
    if #draft.checkpoints == 0 then
        notify('Checkpoint Stack Already Empty', 'warning')
        return
    end

    draft.checkpoints = {}
    refreshPreview()
    notify('Checkpoint Stack Cleared', 'warning')
end

---@return nil
local function stopEditor()
    if not editorEnabled then
        return
    end

    editorEnabled = false
    raycastHit = nil
    SKRaceEditorFreecam.stop()
    clearPreviewHandles()
    notify('Race Editor Disabled', 'warning')
end

---@return nil
local function startEditor()
    if editorEnabled then
        return
    end

    if not draft.start then
        draft.start = captureStart()
    end

    editorEnabled = true
    SKRaceEditorFreecam.start()
    refreshPreview()
    notify('Race Editor Enabled', 'success')

    CreateThread(function()
        while editorEnabled do
            raycastHit = SKRaceEditorFreecam.raycast()
            Wait(16)
        end
    end)
end

---@return nil
local function toggleEditor()
    if editorEnabled then
        stopEditor()
        return
    end
    startEditor()
end

---@param text string
---@param x number
---@param y number
---@param scale number
---@param r integer
---@param g integer
---@param b integer
---@return nil
local function drawTextLine(text, x, y, scale, r, g, b)
    SetTextFont(0)
    SetTextProportional(true)
    SetTextScale(0.0, scale)
    SetTextColour(r, g, b, 255)
    SetTextDropshadow(0, 0, 0, 0, 200)
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(text)
    DrawText(x, y)
end

---@param coords vector3
---@param text string
---@return nil
local function drawWorldLabel(coords, text)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)
    if not onScreen then
        return
    end

    SetTextScale(0.28, 0.28)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 220)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(screenX, screenY)
end

---@param coords vector3
---@param size number
---@param r integer
---@param g integer
---@param b integer
---@param a integer
---@return nil
local function drawSphereMarker(coords, size, r, g, b, a)
    DrawMarker(
        28,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        size, size, size,
        r, g, b, a,
        false, true, 2, false, nil, nil, false
    )
end

---@param coords vector3
---@param r integer
---@param g integer
---@param b integer
---@param a integer
---@return nil
local function drawCheckpointMarker(coords, r, g, b, a)
    DrawMarker(
        1,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        3.0, 3.0, 1.5,
        r, g, b, a,
        false, true, 2, false, nil, nil, false
    )
end

---@return nil
local function drawOverlay()
    local lines = {
        'RACE EDITOR MODE',
        ('Scheme   %s'):format(string.upper(draft.scheme)),
        ('Count    %d'):format(#draft.checkpoints),
        ('Start    %s'):format(draft.start and ('%.2f, %.2f, %.2f'):format(draft.start.x, draft.start.y, draft.start.z) or 'unset'),
        ('Hit      %s'):format(raycastHit and ('%.2f, %.2f, %.2f'):format(raycastHit.x, raycastHit.y, raycastHit.z) or 'none'),
        'WASD Move  Q/E Height  Alt Slow  Shift Fast',
        'LMB Place  R Move Last  Backspace Undo',
        'Delete Clear  Space Scheme  Enter Copy',
        'Esc Exit  /racestart Set Start',
    }

    local centerX = 0.17
    local topY = 0.06
    local boxWidth = 0.34
    local boxHeight = 0.030 * #lines + 0.012
    DrawRect(centerX, topY + boxHeight * 0.5 - 0.010, boxWidth, boxHeight, 0, 0, 0, 175)

    for index, line in ipairs(lines) do
        local textY = topY + (index - 1) * 0.024
        local scale = index == 1 and 0.34 or 0.28
        local r, g, b = 220, 220, 220
        if index == 1 then
            r, g, b = 255, 210, 71
        end
        drawTextLine(line, centerX - 0.155, textY, scale, r, g, b)
    end
end

---@return nil
local function drawWorldPreview()
    if draft.start then
        local startPoint = SKEventRoute.toVector3(draft.start)
        drawCheckpointMarker(startPoint, 82, 167, 255, 110)
        drawSphereMarker(startPoint, 1.0, 82, 167, 255, 180)
        drawWorldLabel(startPoint, 'START')
    end

    for index, checkpoint in ipairs(draft.checkpoints) do
        if index < #draft.checkpoints then
            drawCheckpointMarker(checkpoint, 255, 210, 0, 120)
        end
        drawWorldLabel(checkpoint, tostring(index))
    end

    for index = 2, #previewRoute do
        local previous = previewRoute[index - 1]
        local current = previewRoute[index]
        DrawLine(previous.x, previous.y, previous.z, current.x, current.y, current.z, 255, 210, 0, 200)
    end

    if raycastHit then
        drawSphereMarker(raycastHit, 1.0, 52, 152, 219, 220)
        local placementOrigin = getPlacementOrigin()
        if placementOrigin then
            DrawLine(
                placementOrigin.x, placementOrigin.y, placementOrigin.z,
                raycastHit.x, raycastHit.y, raycastHit.z,
                52, 152, 219, 220
            )
        end
    end
end

---@return nil
local function handleEditorControls()
    if IsDisabledControlJustPressed(0, 24) then
        placeCheckpointAtRaycast()
        return
    end
    if IsDisabledControlJustPressed(0, 140) then
        moveLastCheckpoint()
        return
    end
    if IsDisabledControlJustPressed(0, 177) then
        popCheckpoint()
        return
    end
    if IsDisabledControlJustPressed(0, 179) then
        clearCheckpointStack()
        return
    end
    if IsDisabledControlJustPressed(0, 22) then
        cycleScheme()
        return
    end
    if IsDisabledControlJustPressed(0, 191) then
        copyDraft()
        return
    end
    if IsDisabledControlJustPressed(0, 200) then
        stopEditor()
    end
end

RegisterCommand('raceedit', function()
    if not requireRaceEditor() then return end
    toggleEditor()
end)

RegisterCommand('racecp', function()
    if not requireRaceEditor() then return end
    placeCheckpointAtRaycast()
end)

RegisterCommand('racemove', function()
    if not requireRaceEditor() then return end
    moveLastCheckpoint()
end)

RegisterCommand('racecopy', function()
    if not requireRaceEditor() then return end
    copyDraft()
end)

RegisterCommand('raceclear', function()
    if not requireRaceEditor() then return end
    clearCheckpointStack()
end)

RegisterCommand('racepop', function()
    if not requireRaceEditor() then return end
    popCheckpoint()
end)

RegisterCommand('racestart', function()
    if not requireRaceEditor() then return end
    setStartFromPlayer()
end)

RegisterCommand('racescheme', function(_, args)
    if not requireRaceEditor() then return end
    local value = args[1]
    if not value or value == '' then
        cycleScheme()
        return
    end

    value = string.lower(value)
    if value ~= CheckpointScheme.ORDERED
        and value ~= CheckpointScheme.CIRCUIT
        and value ~= CheckpointScheme.THEREANDBACK
        and value ~= CheckpointScheme.UNORDERED then
        notify('Invalid Scheme', 'error')
        return
    end

    setScheme(value)
end)

RegisterKeyMapping('raceedit', 'Race Editor Toggle', 'keyboard', 'F6')
RegisterKeyMapping('racecp', 'Race Editor Place Checkpoint', 'keyboard', 'F7')
RegisterKeyMapping('racecopy', 'Race Editor Copy Event', 'keyboard', 'F9')
RegisterKeyMapping('raceclear', 'Race Editor Clear Checkpoints', 'keyboard', 'F10')
RegisterKeyMapping('racescheme', 'Race Editor Cycle Scheme', 'keyboard', 'F11')
RegisterKeyMapping('racepop', 'Race Editor Remove Last Checkpoint', 'keyboard', 'F12')

CreateThread(function()
    while true do
        if editorEnabled then
            handleEditorControls()
            drawOverlay()
            drawWorldPreview()
            Wait(0)
        else
            Wait(500)
        end
    end
end)
