---@class SKRaceChooserModule
SKRaceChooser = {}

---@class SKMultiplayerSetupOptions
---@field laps integer
---@field collision boolean
---@field lobbyTimeoutSeconds integer

local activeResolve = nil
local activeSetupState = nil
local controlBlockerGeneration = 0

local KEYBOARD_CONFIRM = 38
local KEYBOARD_ESCAPE = 322
local KEYBOARD_LEFT = 34
local KEYBOARD_RIGHT = 35

---@param controlGen integer
local function runControlBlocker(controlGen)
    CreateThread(function()
        while controlGen == controlBlockerGeneration do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            Wait(0)
        end
    end)
end

local function waitForCloseInputRelease()
    local stableFrames = 0

    while stableFrames < 2 do
        local anyHeld = false
        local padIndex = SKInput.getActivePadIndex()
        local interactControl = SKInput.getInteractControl(padIndex)

        local function held(control)
            return IsControlPressed(padIndex, control) or IsDisabledControlPressed(padIndex, control)
        end

        if held(KEYBOARD_CONFIRM) or held(KEYBOARD_ESCAPE) or held(interactControl) then
            anyHeld = true
        end

        if not anyHeld then
            for _, input in ipairs(SKControllerFriendly.DEFAULT_ACTION_INPUTS) do
                if held(input.control) then
                    anyHeld = true
                    break
                end
            end
        end

        stableFrames = anyHeld and 0 or (stableFrames + 1)
        Wait(0)
    end
end

---@param value any
local function resolve(value)
    if not activeResolve then return end
    local r = activeResolve
    activeResolve = nil
    activeSetupState = nil
    controlBlockerGeneration = controlBlockerGeneration + 1
    SendNUIMessage({ type = 'raceChooser:hide' })
    SendNUIMessage({ type = 'multiplayerSetup:hide' })
    SetNuiFocus(false, false)
    r(value)
end

---@param def table
---@param state table|nil
---@return string
local function subtitleForDef(def, state)
    local classBit = state and state.vehicleClass and state.vehicleClass ~= '' and (' — ' .. state.vehicleClass .. ' Class') or ''
    return ('Choose how to run %s%s'):format(def.name, classBit)
end

---@param def table
---@return string[]
local function buildSetupFocusKeys(def)
    if def.scheme == CheckpointScheme.CIRCUIT then
        return { 'laps', 'collision', 'lobbyTimeoutSeconds', 'confirm', 'cancel' }
    end
    return { 'collision', 'lobbyTimeoutSeconds', 'confirm', 'cancel' }
end

---@param def table
---@param options table|nil
---@return SKMultiplayerSetupOptions
local function normalizeSetupOptions(def, options)
    local defaults = SKEventsConfig.MULTIPLAYER_SETUP_DEFAULTS or {}
    local allowedTimeouts = SKEventsConfig.MULTIPLAYER_SETUP_TIMEOUT_OPTIONS or { 180, 300, 600 }

    local laps = type(options) == 'table' and tonumber(options.laps) or tonumber(defaults.laps) or 1
    if def.scheme ~= CheckpointScheme.CIRCUIT then
        laps = 1
    end
    laps = math.min(5, math.max(1, math.floor(laps)))

    local collision = defaults.collision ~= false
    if type(options) == 'table' and type(options.collision) == 'boolean' then
        collision = options.collision
    end

    local timeout = type(options) == 'table' and tonumber(options.lobbyTimeoutSeconds) or tonumber(defaults.lobbyTimeoutSeconds) or 180
    timeout = math.floor(timeout)
    local timeoutValid = false
    for _, candidate in ipairs(allowedTimeouts) do
        if timeout == candidate then
            timeoutValid = true
            break
        end
    end
    if not timeoutValid then
        timeout = allowedTimeouts[1]
    end

    return {
        laps = laps,
        collision = collision,
        lobbyTimeoutSeconds = timeout,
    }
end

---@param focusIndex integer
local function setSetupFocus(focusIndex)
    if not activeSetupState then return end
    local count = #activeSetupState.focusKeys
    if count == 0 then return end
    if focusIndex < 1 then
        focusIndex = count
    elseif focusIndex > count then
        focusIndex = 1
    end
    activeSetupState.focusIndex = focusIndex
end

local function pushSetupState()
    if not activeSetupState then return end
    SendNUIMessage({
        type = 'multiplayerSetup:update',
        title = activeSetupState.def.name,
        sub = subtitleForDef(activeSetupState.def, activeSetupState.state),
        kicker = 'Multiplayer Setup',
        showLaps = activeSetupState.def.scheme == CheckpointScheme.CIRCUIT,
        focusKey = activeSetupState.focusKeys[activeSetupState.focusIndex],
        laps = activeSetupState.options.laps,
        collision = activeSetupState.options.collision,
        lobbyTimeoutSeconds = activeSetupState.options.lobbyTimeoutSeconds,
    })
end

---@param key string
---@param delta integer
local function adjustSetupOption(key, delta)
    if not activeSetupState then return end

    if key == 'laps' then
        if activeSetupState.def.scheme ~= CheckpointScheme.CIRCUIT then
            activeSetupState.options.laps = 1
            return
        end
        local nextLaps = activeSetupState.options.laps + delta
        if nextLaps < 1 then nextLaps = 5 end
        if nextLaps > 5 then nextLaps = 1 end
        activeSetupState.options.laps = nextLaps
        return
    end

    if key == 'collision' then
        activeSetupState.options.collision = not activeSetupState.options.collision
        return
    end

    if key == 'lobbyTimeoutSeconds' then
        local allowedTimeouts = SKEventsConfig.MULTIPLAYER_SETUP_TIMEOUT_OPTIONS or { 180, 300, 600 }
        local currentIndex = 1
        for i, value in ipairs(allowedTimeouts) do
            if value == activeSetupState.options.lobbyTimeoutSeconds then
                currentIndex = i
                break
            end
        end
        local nextIndex = currentIndex + delta
        if nextIndex < 1 then nextIndex = #allowedTimeouts end
        if nextIndex > #allowedTimeouts then nextIndex = 1 end
        activeSetupState.options.lobbyTimeoutSeconds = allowedTimeouts[nextIndex]
    end
end

RegisterNUICallback('raceChooser:confirm', function(data, cb)
    cb({})
    local choice = type(data) == 'table' and data.choice or nil
    if choice ~= 'singleplayer' and choice ~= 'multiplayer' then return end
    resolve(choice)
end)

RegisterNUICallback('raceChooser:cancel', function(_, cb)
    cb({})
    resolve(nil)
end)

RegisterNUICallback('multiplayerSetup:setFocus', function(data, cb)
    cb({})
    if not activeSetupState or type(data) ~= 'table' or type(data.key) ~= 'string' then return end
    for i, key in ipairs(activeSetupState.focusKeys) do
        if key == data.key then
            setSetupFocus(i)
            pushSetupState()
            return
        end
    end
end)

RegisterNUICallback('multiplayerSetup:adjust', function(data, cb)
    cb({})
    if not activeSetupState or type(data) ~= 'table' or type(data.key) ~= 'string' then return end
    adjustSetupOption(data.key, tonumber(data.delta) and math.floor(tonumber(data.delta)) or 1)
    pushSetupState()
end)

RegisterNUICallback('multiplayerSetup:confirm', function(_, cb)
    cb({})
    if not activeSetupState then return end
    resolve(activeSetupState.options)
end)

RegisterNUICallback('multiplayerSetup:cancel', function(_, cb)
    cb({})
    resolve(nil)
end)

---@param def table
---@param state table|nil
---@return 'singleplayer'|'multiplayer'|nil, SKMultiplayerSetupOptions|nil
function SKRaceChooser.prompt(def, state)
    if activeResolve then return nil, nil end

    local waitingResult = nil
    local finished = false
    activeResolve = function(choice)
        waitingResult = choice
        finished = true
    end

    SendNUIMessage({
        type = 'raceChooser:show',
        title = def.name,
        sub = subtitleForDef(def, state),
        kicker = 'Race',
        choice = 'singleplayer',
        maxPlayers = SKEventsConfig.MULTIPLAYER_MAX_PLAYERS,
    })
    SetNuiFocus(true, true)

    controlBlockerGeneration = controlBlockerGeneration + 1
    runControlBlocker(controlBlockerGeneration)

    local tracker = SKControllerFriendly.newTracker()
    local currentChoice = 'singleplayer'
    local lastRaceChoice = currentChoice

    while not finished do
        Wait(0)

        local result = SKControllerFriendly.poll(tracker)
        for _, action in ipairs(result.pressedActions) do
            if action == 'left' then
                currentChoice = 'singleplayer'
                lastRaceChoice = currentChoice
                SendNUIMessage({ type = 'raceChooser:setChoice', choice = currentChoice })
            elseif action == 'right' then
                currentChoice = 'multiplayer'
                lastRaceChoice = currentChoice
                SendNUIMessage({ type = 'raceChooser:setChoice', choice = currentChoice })
            elseif action == 'down' then
                currentChoice = 'cancel'
                SendNUIMessage({ type = 'raceChooser:setChoice', choice = currentChoice })
            elseif action == 'up' then
                currentChoice = lastRaceChoice
                SendNUIMessage({ type = 'raceChooser:setChoice', choice = currentChoice })
            elseif action == 'accept' then
                resolve(currentChoice ~= 'cancel' and currentChoice or nil)
            elseif action == 'back' then
                resolve(nil)
            end
        end

        if IsDisabledControlJustPressed(0, KEYBOARD_LEFT) then
            currentChoice = 'singleplayer'
            lastRaceChoice = currentChoice
            SendNUIMessage({ type = 'raceChooser:setChoice', choice = currentChoice })
        elseif IsDisabledControlJustPressed(0, KEYBOARD_RIGHT) then
            currentChoice = 'multiplayer'
            lastRaceChoice = currentChoice
            SendNUIMessage({ type = 'raceChooser:setChoice', choice = currentChoice })
        elseif IsDisabledControlJustPressed(0, KEYBOARD_CONFIRM) then
            resolve(currentChoice ~= 'cancel' and currentChoice or nil)
        elseif IsDisabledControlJustPressed(0, KEYBOARD_ESCAPE) then
            resolve(nil)
        end
    end

    waitForCloseInputRelease()

    local choice = waitingResult
    if choice ~= 'multiplayer' then
        return choice, nil
    end

    finished = false
    waitingResult = nil
    activeResolve = function(options)
        waitingResult = options
        finished = true
    end
    activeSetupState = {
        def = def,
        state = state,
        focusKeys = buildSetupFocusKeys(def),
        focusIndex = 1,
        options = normalizeSetupOptions(def, nil),
    }

    SendNUIMessage({
        type = 'multiplayerSetup:show',
        title = def.name,
        sub = subtitleForDef(def, state),
        kicker = 'Multiplayer Setup',
        showLaps = def.scheme == CheckpointScheme.CIRCUIT,
        focusKey = activeSetupState.focusKeys[1],
        laps = activeSetupState.options.laps,
        collision = activeSetupState.options.collision,
        lobbyTimeoutSeconds = activeSetupState.options.lobbyTimeoutSeconds,
    })
    SetNuiFocus(true, true)

    controlBlockerGeneration = controlBlockerGeneration + 1
    runControlBlocker(controlBlockerGeneration)

    tracker = SKControllerFriendly.newTracker()

    while not finished do
        Wait(0)
        if not activeSetupState then break end

        local focusKey = activeSetupState.focusKeys[activeSetupState.focusIndex]
        local result = SKControllerFriendly.poll(tracker)
        for _, action in ipairs(result.pressedActions) do
            if action == 'up' then
                setSetupFocus(activeSetupState.focusIndex - 1)
                pushSetupState()
            elseif action == 'down' then
                setSetupFocus(activeSetupState.focusIndex + 1)
                pushSetupState()
            elseif action == 'left' then
                adjustSetupOption(focusKey, -1)
                pushSetupState()
            elseif action == 'right' then
                adjustSetupOption(focusKey, 1)
                pushSetupState()
            elseif action == 'accept' then
                if focusKey == 'confirm' then
                    resolve(activeSetupState.options)
                elseif focusKey == 'cancel' then
                    resolve(nil)
                else
                    adjustSetupOption(focusKey, 1)
                    pushSetupState()
                end
            elseif action == 'back' then
                resolve(nil)
            end
        end

        focusKey = activeSetupState and activeSetupState.focusKeys[activeSetupState.focusIndex] or nil
        if focusKey and IsDisabledControlJustPressed(0, KEYBOARD_LEFT) then
            adjustSetupOption(focusKey, -1)
            pushSetupState()
        elseif focusKey and IsDisabledControlJustPressed(0, KEYBOARD_RIGHT) then
            adjustSetupOption(focusKey, 1)
            pushSetupState()
        elseif IsDisabledControlJustPressed(0, KEYBOARD_CONFIRM) then
            if focusKey == 'confirm' then
                resolve(activeSetupState.options)
            elseif focusKey == 'cancel' then
                resolve(nil)
            elseif focusKey then
                adjustSetupOption(focusKey, 1)
                pushSetupState()
            end
        elseif IsDisabledControlJustPressed(0, KEYBOARD_ESCAPE) then
            resolve(nil)
        end
    end

    waitForCloseInputRelease()

    if waitingResult == nil then
        return nil, nil
    end

    return 'multiplayer', normalizeSetupOptions(def, waitingResult)
end