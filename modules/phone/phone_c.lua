local CONFIG = {
    slideDirection = 'bottom', -- 'bottom' | 'left' | 'right'
}

local INPUT_PHONE_OPEN = 27
local INPUT_PHONE_OPEN_DPAD_UP = 172

local isOpen = false
local controllerModeEnabled = false
local controllerTracker = SKControllerFriendly.newTracker()

local PHONE_OPENABLE_GAME_STATES = {
    [GameState.FREEROAM] = true,
    [GameState.EVENT] = true,
    [GameState.MULTIPLAYER_LOBBY] = true,
    [GameState.MULTIPLAYER_EVENT] = true,
    [GameState.MISSION] = true,
    [GameState.PROPERTY] = true,
}

---@param gameState string
---@return boolean
local function canOpenPhoneFromController(gameState)
    if IsPauseMenuActive() then
        return false
    end
    return PHONE_OPENABLE_GAME_STATES[gameState] == true
end

SKPhone = {}

---@return boolean
function SKPhone.isOpen()
    return isOpen
end

---@param payload table|nil
function SKPhone.open(payload)
    if isOpen then return end
    isOpen = true
    payload = payload or {}
    local openedWithController = payload.controller == true
    SKControllerFriendly.resetTracker(controllerTracker)
    if openedWithController then
        controllerTracker.lastPadInputAt = GetGameTimer()
    end
    controllerModeEnabled = openedWithController
    payload.type = 'phone:open'
    payload.slideDirection = CONFIG.slideDirection
    SendNUIMessage(payload)
    SetNuiFocus(true, true)
end

function SKPhone.close()
    if not isOpen then return end
    isOpen = false
    controllerModeEnabled = false
    SKControllerFriendly.resetTracker(controllerTracker)
    SendNUIMessage({ type = 'phone:close' })
    SetNuiFocus(false, false)
end

---@param payload table|nil
function SKPhone.toggle(payload)
    if isOpen then
        SKPhone.close()
    else
        SKPhone.open(payload)
    end
end

---@param nextEnabled boolean
local function setControllerModeEnabled(nextEnabled)
    nextEnabled = nextEnabled == true
    if controllerModeEnabled == nextEnabled then
        return
    end

    controllerModeEnabled = nextEnabled
    SendNUIMessage({
        type = 'phone:controllerMode',
        enabled = nextEnabled,
    })
end

---@param controller boolean
local function togglePhoneForCurrentState(controller)
    local payload = controller and { controller = true } or nil
    local gameState = SKC.GetGameState()
    if gameState == GameState.FREEROAM or gameState == GameState.PROPERTY then
        SKPhone.toggle(payload)
        return
    end

    if gameState == GameState.MULTIPLAYER_LOBBY then
        local lobbyPhoneState = SKMultiplayer.getLobbyPhoneState()
        if lobbyPhoneState then
            payload = payload or {}
            payload.mode = 'event'
            payload.eventPhone = lobbyPhoneState
            SKPhone.toggle(payload)
            return
        end
    end

    if gameState == GameState.EVENT then
        local eventPhoneState = SKEvents.getPhoneState()
        if not eventPhoneState then return end
        payload = payload or {}
        payload.mode = 'event'
        payload.eventPhone = eventPhoneState
        SKPhone.toggle(payload)
        return
    end

    if gameState == GameState.MULTIPLAYER_EVENT and SKMultiplayer and SKMultiplayer.getPhoneState then
        local eventPhoneState = SKMultiplayer.getPhoneState()
        if not eventPhoneState then return end
        payload = payload or {}
        payload.mode = 'event'
        payload.eventPhone = eventPhoneState
        SKPhone.toggle(payload)
    end

    if gameState == GameState.MISSION then
        payload = payload or {}
        payload.mode = 'mission'
        payload.missionPhone = SKMissionsClient.getPhoneState and SKMissionsClient.getPhoneState() or nil
        SKPhone.toggle(payload)
    end
end

exports('IsPhoneOpen', SKPhone.isOpen)
exports('OpenPhone', SKPhone.open)
exports('ClosePhone', SKPhone.close)

RegisterNUICallback('phone:close', function(_, cb)
    SKPhone.close()
    cb({})
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isOpen = false
    controllerModeEnabled = false
    SendNUIMessage({ type = 'phone:close' })
    SetNuiFocus(false, false)
end)

AddEventHandler('streetkings:phone:toggle', function()
    togglePhoneForCurrentState(false)
end)

CreateThread(function()
    while true do
        if isOpen then
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)

            local controllerState = SKControllerFriendly.poll(controllerTracker)
            setControllerModeEnabled(controllerState.controllerEnabled)

            if controllerState.controllerEnabled then
                for _, action in ipairs(controllerState.pressedActions) do
                    SendNUIMessage({
                        type = 'phone:controllerInput',
                        action = action,
                    })
                end

                if controllerState.hasAnalogInput then
                    SendNUIMessage({
                        type = 'phone:controllerAnalog',
                        lookX = controllerState.lookX,
                        lookY = controllerState.lookY,
                    })
                end
            end

            Wait(0)
        else
            local gameState = SKC.GetGameState()
            local padIndex = SKInput.getActivePadIndex()
            setControllerModeEnabled(SKControllerFriendly.hasRecentInput(controllerTracker, padIndex))
            local canOpenPhone = canOpenPhoneFromController(gameState)
            if canOpenPhone
                and not SKInput.isUsingKeyboard(padIndex)
                and (
                    IsControlJustPressed(padIndex, INPUT_PHONE_OPEN)
                    or IsControlJustPressed(padIndex, INPUT_PHONE_OPEN_DPAD_UP)
                )
            then
                togglePhoneForCurrentState(true)
                Wait(200)
            else
                Wait(canOpenPhone and 0 or 100)
            end
        end
    end
end)
