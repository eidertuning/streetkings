SKMainMenu = SKMainMenu or {}

local MAIN_MENU_RESOURCE_VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)

local menuNuiOpen = false
local nuiReady    = false
local controllerModeEnabled = false
local controllerTracker = SKControllerFriendly.newTracker()

---@param nextEnabled boolean
local function setControllerModeEnabled(nextEnabled)
    nextEnabled = nextEnabled == true
    if controllerModeEnabled == nextEnabled then
        return
    end

    controllerModeEnabled = nextEnabled
    SendNUIMessage({
        type = 'mainMenu:controllerMode',
        enabled = nextEnabled,
    })
end

---@return nil
function SKMainMenu.open()
    if menuNuiOpen then
        return
    end

    menuNuiOpen = true
    SKControllerFriendly.resetTracker(controllerTracker)
    setControllerModeEnabled(false)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'streetkings:mainMenu',
        visible = true,
        version = MAIN_MENU_RESOURCE_VERSION,
        saveSlotCount = SKSaves.SLOT_COUNT,
        slotsVersion = SKSaves.SLOTS_VERSION,
    })
end

---@return nil
function SKMainMenu.close()
    if not menuNuiOpen then
        return
    end

    menuNuiOpen = false
    SKControllerFriendly.resetTracker(controllerTracker)
    setControllerModeEnabled(false)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'streetkings:mainMenu',
        visible = false,
    })
end

RegisterNUICallback('mainMenuReady', function(_, cb)
    nuiReady = true
    cb({ ok = true })
end)

---@return nil
function SKMainMenu.waitForNui()
    while not nuiReady do Wait(50) end
end

RegisterNUICallback('mainMenuRequestSaves', function(_, cb)
    cb(SKMainMenu.requestSaves())
end)

RegisterNUICallback('mainMenuRequestLastPlayed', function(_, cb)
    cb(SKMainMenu.requestLastPlayed())
end)

RegisterNUICallback('mainMenuSavePick', function(data, cb)
    if type(data) ~= 'table' then
        cb({ ok = false })
        return
    end

    cb(SKMainMenu.pickSave(data.slotIndex, data.isNew, data.saveId, data.saveName))
end)

RegisterNUICallback('mainMenuSaveDelete', function(data, cb)
    if type(data) ~= 'table' then
        cb({ ok = false })
        return
    end

    cb(SKMainMenu.deleteSave(data.slotIndex, data.saveId))
end)

RegisterNUICallback('mainMenuCustomizeAvatar', function(_, cb)
    cb({ ok = true })
    SKAvatar.enterFromMainMenu()
end)

RegisterNUICallback('mainMenuExitGame', function(_, cb)
    cb({ ok = true })
    TriggerServerEvent('streetkings:pausemenu:exitGame')
end)

CreateThread(function()
    while true do
        if menuNuiOpen then
            local controllerState = SKControllerFriendly.poll(controllerTracker)
            setControllerModeEnabled(controllerState.controllerEnabled)

            if controllerState.controllerEnabled then
                for _, action in ipairs(controllerState.pressedActions) do
                    SendNUIMessage({
                        type = 'mainMenu:controllerInput',
                        action = action,
                    })
                end

                if controllerState.hasAnalogInput then
                    SendNUIMessage({
                        type = 'mainMenu:controllerAnalog',
                        lookX = controllerState.lookX,
                        lookY = controllerState.lookY,
                    })
                end
            end

            Wait(0)
        else
            Wait(100)
        end
    end
end)
