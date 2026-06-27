--- Daily playlist freeroam world markers, blips, and prompts

local RACE_BLIP_CAT_SPRINT      = 12
local RACE_BLIP_CAT_CIRCUIT     = 13
local RACE_BLIP_CAT_DELIVERY    = 14
local RACE_BLIP_CAT_RAMPAGE     = 17

local freeroamPoints = {}
local freeroamWaypoints = {}
local freeroamBlips = {}
local freeroamBlipByEventId = {}
local dailyEventStateById = {}

local MARKER_INNER = 5.0
local CHOOSER_REOPEN_COOLDOWN_MS = 300

---@type { setBlipLegendGroup: fun(blip: integer, blipName: string, category: integer), onStartDaily: fun(eventId: string, vehicleClass: string), onStartMultiplayer: fun(eventId: string, setupOptions: table|nil) }
local cfg = {}

SKEventsFreeroamMarkers = {}

---@param def table
---@return string blipName
---@return integer category
local function freeroamLegendForDef(def)
    if def.type == EventType.DELIVERY then
        return def.name, RACE_BLIP_CAT_DELIVERY
    end
    if def.type == EventType.RAMPAGE then
        return def.name, RACE_BLIP_CAT_RAMPAGE
    end
    if def.scheme == CheckpointScheme.CIRCUIT then
        return def.name, RACE_BLIP_CAT_CIRCUIT
    end
    return def.name, RACE_BLIP_CAT_SPRINT
end

---@param def table
---@return integer
local function freeroamBlipColorForDef(def)
    if def.type == EventType.DELIVERY then
        return 47
    end
    if def.type == EventType.RAMPAGE then
        return 1
    end
    if def.scheme == CheckpointScheme.CIRCUIT then
        return 38
    end
    return 66
end

---@param def table
---@return string
local function waypointColorForDef(def)
    if def.type == EventType.DELIVERY then
        return '#00D474'
    end
    if def.type == EventType.RAMPAGE then
        return '#FF4040'
    end
    if def.scheme == CheckpointScheme.CIRCUIT then
        return '#66CCFF'
    end
    return '#FFD700'
end

---@param def table
---@return string
local function waypointIconForDef(def)
    if def.type == EventType.DELIVERY then
        return 'box'
    end
    if def.type == EventType.RAMPAGE then
        return 'skull-crossbones'
    end
    return 'flag-checkered'
end

---@param blip integer
---@param state table
local function syncDailyEventBlipState(blip, state)
    ShowTickOnBlip(blip, state.rewardClaimed == true)
end

---@param def table
---@param state table|nil
---@return string
function SKEventsFreeroamMarkers.eventPromptType(def, state)
    if def.type == EventType.DELIVERY then
        return 'Delivery'
    elseif def.type == EventType.RAMPAGE then
        return 'Rampage'
    elseif def.scheme == CheckpointScheme.CIRCUIT then
        return 'Circuit'
    end
    return 'Sprint'
end

---@param state table|nil
---@param key string
---@param def table|nil
---@return string
function SKEventsFreeroamMarkers.buildPromptAction(state, key, def)
    local action
    if def and def.type == EventType.RAMPAGE then
        action = _L('ui.events.press_to_start_rampage', { key = key })
    elseif def and def.type == EventType.DELIVERY then
        action = _L('ui.events.press_to_start', { key = key })
    else
        action = _L('ui.events.press_to_race', { key = key })
    end
    if not state then
        return action
    end
    if state.rewardAvailable then
        return action .. ' - ' .. _L('ui.events.reward_ready')
    end
    if state.rewardClaimed then
        return action .. ' - ' .. _L('ui.events.reward_claimed')
    end
    return action
end

---@param def table
---@param state table|nil
---@return boolean
local function eventSupportsMultiplayer(def, state)
    return def.type == EventType.RACE
end

---@param eventId string
---@param def table
---@param state table|nil
---@param onResolved fun(choice: 'singleplayer'|'multiplayer'|nil)|nil
local function onMarkerInteract(eventId, def, state, onResolved)
    if not eventSupportsMultiplayer(def, state) then
        cfg.onStartDaily(eventId, state and state.vehicleClass or '')
        return
    end

    CreateThread(function()
        local choice, setupOptions = SKRaceChooser.prompt(def, state)
        if choice == 'singleplayer' then
            cfg.onStartDaily(eventId, state and state.vehicleClass or '')
        elseif choice == 'multiplayer' then
            cfg.onStartMultiplayer(eventId, setupOptions)
        end
        if onResolved then
            onResolved(choice)
        end
    end)
end

---@param c { setBlipLegendGroup: fun(blip: integer, blipName: string, category: integer), onStartDaily: fun(eventId: string, vehicleClass: string), onStartMultiplayer: fun(eventId: string, setupOptions: table|nil) }
function SKEventsFreeroamMarkers.init(c)
    cfg = c
end

local function clearFreeroamPoints()
    for _, p in ipairs(freeroamPoints) do p:remove() end
    freeroamPoints = {}
    for _, wpId in ipairs(freeroamWaypoints) do
        SKWaypoint.Remove(wpId)
    end
    freeroamWaypoints = {}
    for _, b in ipairs(freeroamBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    freeroamBlips = {}
    freeroamBlipByEventId = {}
end

local function setupFreeroamPoints()
    clearFreeroamPoints()
    dailyEventStateById = {}

    local playlist = lib.callback.await('streetkings:events:getDailyPlaylist', false) or { entries = {} }

    for _, featured in ipairs(playlist.entries or {}) do
        local id = featured.id
        local def = SKEvents[id]
        if not def then
            goto continue
        end

        dailyEventStateById[id] = featured
        local coords = vector3(def.start.x, def.start.y, def.start.z)

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 315)
        SetBlipColour(blip, freeroamBlipColorForDef(def))
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)
        local legendName, legendCat = freeroamLegendForDef(def)
        cfg.setBlipLegendGroup(blip, legendName, legendCat)
        syncDailyEventBlipState(blip, featured)
        freeroamBlips[#freeroamBlips + 1] = blip
        freeroamBlipByEventId[id] = blip

        local wpId = SKWaypoint.Create({
            coords     = coords,
            text       = def.name,
            color      = waypointColorForDef(def),
            icon       = waypointIconForDef(def),
            showDist   = true,
            groundBeam = true,
        })
        freeroamWaypoints[#freeroamWaypoints + 1] = wpId

        local promptKey = nil
        local eventState = featured
        local chooserCooldownUntil = 0

        local function showEventPrompt()
            promptKey = SKInput.getInteractLabel()
            SendNUIMessage({
                type         = 'prompt:show',
                layout       = 'event',
                key          = promptKey,
                text         = SKEventsFreeroamMarkers.buildPromptAction(eventState, promptKey, def),
                title        = def.name,
                eventType    = SKEventsFreeroamMarkers.eventPromptType(def, eventState),
                vehicleClass = eventState and eventState.vehicleClass ~= '' and eventState.vehicleClass or nil,
                personalBest = eventState and eventState.personalBest or nil,
            })
        end

        local innerPoint = lib.points.new({
            coords   = coords,
            distance = MARKER_INNER,
            onEnter  = function()
                showEventPrompt()
                CreateThread(function()
                    local state = lib.callback.await('streetkings:events:getDailyEventState', false, id)
                    if #(GetEntityCoords(PlayerPedId()) - coords) > MARKER_INNER then return end
                    eventState = state or eventState
                    dailyEventStateById[id] = eventState
                    syncDailyEventBlipState(freeroamBlipByEventId[id], eventState)
                    showEventPrompt()
                end)
            end,
            onExit   = function()
                promptKey = nil
                chooserCooldownUntil = 0
                SendNUIMessage({ type = 'prompt:hide' })
            end,
            nearby   = function()
                local nextPromptKey = SKInput.getInteractLabel()
                if nextPromptKey ~= promptKey then
                    showEventPrompt()
                end
                if GetGameTimer() < chooserCooldownUntil then
                    return
                end

                if SKGearbox.isStallInteractionBlocked() then
                    return
                end

                if SKInput.isInteractJustReleased() then
                    chooserCooldownUntil = GetGameTimer() + 300000
                    SendNUIMessage({ type = 'prompt:hide' })
                    onMarkerInteract(id, def, eventState, function(choice)
                        chooserCooldownUntil = GetGameTimer() + CHOOSER_REOPEN_COOLDOWN_MS
                        if choice == nil then
                            showEventPrompt()
                        end
                    end)
                end
            end,
        })
        freeroamPoints[#freeroamPoints + 1] = innerPoint

        ::continue::
    end
end

---@param eventId string
---@return table|nil
function SKEvents.getDailyEventState(eventId) return dailyEventStateById[eventId] end

function SKEventsFreeroamMarkers.setup()
    setupFreeroamPoints()
end

function SKEventsFreeroamMarkers.clear()
    clearFreeroamPoints()
end
