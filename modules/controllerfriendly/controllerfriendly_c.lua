---@class SKControllerFriendlyActionInput
---@field control integer
---@field action string

---@class SKControllerFriendlyTracker
---@field idleTimeoutMs integer
---@field analogDeadzone number
---@field actionInputs SKControllerFriendlyActionInput[]
---@field lastPadInputAt integer
---@field stickNav table

---@class SKControllerFriendlyPollResult
---@field padIndex integer
---@field controllerEnabled boolean
---@field pressedActions string[]
---@field lookX number
---@field lookY number
---@field triggerLeft number
---@field triggerRight number
---@field hasAnalogInput boolean

SKControllerFriendly = {}

local PAD_INDICES = { 0, 1, 2 }

SKControllerFriendly.INPUT_CONTROLLER_LOOK_LR = 1
SKControllerFriendly.INPUT_CONTROLLER_LOOK_UD = 2
SKControllerFriendly.INPUT_CONTROLLER_MOVE_LR = 30
SKControllerFriendly.INPUT_CONTROLLER_MOVE_UD = 31
SKControllerFriendly.INPUT_CONTROLLER_TRIGGER_RIGHT = 71
SKControllerFriendly.INPUT_CONTROLLER_TRIGGER_LEFT = 72
SKControllerFriendly.DEFAULT_ANALOG_DEADZONE = 0.18
SKControllerFriendly.DEFAULT_STICK_NAV_DEADZONE = 0.5
SKControllerFriendly.DEFAULT_STICK_NAV_INITIAL_MS = 220
SKControllerFriendly.DEFAULT_STICK_NAV_REPEAT_MS = 120
SKControllerFriendly.DEFAULT_IDLE_TIMEOUT_MS = 10000
SKControllerFriendly.DEFAULT_ACTION_INPUTS = {
    { control = 172, action = 'up' },
    { control = 173, action = 'down' },
    { control = 174, action = 'left' },
    { control = 175, action = 'right' },
    { control = 176, action = 'accept' },
    { control = 177, action = 'back' },
    { control = 178, action = 'face_y' },
    { control = 179, action = 'face_x' },
    { control = 205, action = 'shoulder_left' },
    { control = 206, action = 'shoulder_right' },
}

local function newStickNavState()
    return { up = 0, down = 0, left = 0, right = 0 }
end

---@param options { idleTimeoutMs?: integer, analogDeadzone?: number, actionInputs?: SKControllerFriendlyActionInput[] }|nil
---@return SKControllerFriendlyTracker
function SKControllerFriendly.newTracker(options)
    local resolvedOptions = options or {}
    return {
        idleTimeoutMs = resolvedOptions.idleTimeoutMs or SKControllerFriendly.DEFAULT_IDLE_TIMEOUT_MS,
        analogDeadzone = resolvedOptions.analogDeadzone or SKControllerFriendly.DEFAULT_ANALOG_DEADZONE,
        actionInputs = resolvedOptions.actionInputs or SKControllerFriendly.DEFAULT_ACTION_INPUTS,
        lastPadInputAt = 0,
        stickNav = newStickNavState(),
    }
end

---@param tracker SKControllerFriendlyTracker
function SKControllerFriendly.resetTracker(tracker)
    tracker.lastPadInputAt = 0
    tracker.stickNav = newStickNavState()
end

---@param tracker SKControllerFriendlyTracker
---@param padIndex integer
---@return boolean
function SKControllerFriendly.hasRecentInput(tracker, padIndex)
    if SKInput.hasRecentPadInput(tracker.idleTimeoutMs, padIndex) then
        return true
    end

    if SKInput.isUsingKeyboard(padIndex) then
        return false
    end

    return (GetGameTimer() - tracker.lastPadInputAt) <= tracker.idleTimeoutMs
end

---@param nav table
---@param action string
---@param now integer
---@return boolean
local function stickNavShouldFire(nav, action, now)
    local lastFired = nav[action]
    if lastFired == 0 then
        return true
    end
    return (now - lastFired) >= SKControllerFriendly.DEFAULT_STICK_NAV_REPEAT_MS
end

---@param tracker SKControllerFriendlyTracker
---@param padIndex integer
---@return string[], number, number, number, number, boolean
local function readPadInput(tracker, padIndex)
    local pressedActions = {}

    for _, input in ipairs(tracker.actionInputs) do
        if IsDisabledControlJustPressed(padIndex, input.control) then
            pressedActions[#pressedActions + 1] = input.action
        end
    end

    local now = GetGameTimer()
    local nav = tracker.stickNav
    local dz = SKControllerFriendly.DEFAULT_STICK_NAV_DEADZONE
    local moveX = GetDisabledControlNormal(padIndex, SKControllerFriendly.INPUT_CONTROLLER_MOVE_LR)
    local moveY = GetDisabledControlNormal(padIndex, SKControllerFriendly.INPUT_CONTROLLER_MOVE_UD)

    local stickDirs = {
        { active = moveX > dz,  action = 'right' },
        { active = moveX < -dz, action = 'left' },
        { active = moveY < -dz, action = 'up' },
        { active = moveY > dz,  action = 'down' },
    }

    for _, sd in ipairs(stickDirs) do
        if sd.active then
            if stickNavShouldFire(nav, sd.action, now) then
                pressedActions[#pressedActions + 1] = sd.action
                nav[sd.action] = now
            end
        else
            nav[sd.action] = 0
        end
    end

    local lookX = GetDisabledControlNormal(padIndex, SKControllerFriendly.INPUT_CONTROLLER_LOOK_LR)
    local lookY = GetDisabledControlNormal(padIndex, SKControllerFriendly.INPUT_CONTROLLER_LOOK_UD)
    local triggerRight = GetDisabledControlNormal(padIndex, SKControllerFriendly.INPUT_CONTROLLER_TRIGGER_RIGHT)
    local triggerLeft = GetDisabledControlNormal(padIndex, SKControllerFriendly.INPUT_CONTROLLER_TRIGGER_LEFT)
    local hasAnalogInput = math.abs(lookX) >= tracker.analogDeadzone
        or math.abs(lookY) >= tracker.analogDeadzone
        or math.abs(moveX) >= dz
        or math.abs(moveY) >= dz
        or triggerLeft >= 0.01
        or triggerRight >= 0.01

    return pressedActions, lookX, lookY, triggerLeft, triggerRight, hasAnalogInput
end

---@param tracker SKControllerFriendlyTracker
---@return SKControllerFriendlyPollResult
function SKControllerFriendly.poll(tracker)
    local padIndex = SKInput.getActivePadIndex()
    local pressedActions = {}
    local lookX = 0.0
    local lookY = 0.0
    local triggerRight = 0.0
    local triggerLeft = 0.0
    local hasAnalogInput = false

    if not SKInput.isUsingKeyboard(padIndex) then
        pressedActions, lookX, lookY, triggerLeft, triggerRight, hasAnalogInput = readPadInput(tracker, padIndex)
    else
        for _, candidatePadIndex in ipairs(PAD_INDICES) do
            if not SKInput.isUsingKeyboard(candidatePadIndex) then
                local candidatePressedActions, candidateLookX, candidateLookY, candidateTriggerLeft, candidateTriggerRight, candidateHasAnalogInput = readPadInput(tracker, candidatePadIndex)
                if #candidatePressedActions > 0 or candidateHasAnalogInput then
                    padIndex = candidatePadIndex
                    pressedActions = candidatePressedActions
                    lookX = candidateLookX
                    lookY = candidateLookY
                    triggerLeft = candidateTriggerLeft
                    triggerRight = candidateTriggerRight
                    hasAnalogInput = candidateHasAnalogInput
                    break
                end
            end
        end
    end

    if #pressedActions > 0 or hasAnalogInput then
        tracker.lastPadInputAt = GetGameTimer()
    end

    return {
        padIndex = padIndex,
        controllerEnabled = SKControllerFriendly.hasRecentInput(tracker, padIndex),
        pressedActions = pressedActions,
        lookX = lookX,
        lookY = lookY,
        triggerLeft = triggerLeft,
        triggerRight = triggerRight,
        hasAnalogInput = hasAnalogInput,
    }
end