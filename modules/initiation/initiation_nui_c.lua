SKInitiation = SKInitiation or {}

SKInitiation.isConfirming = false
local confirmingModel = nil

---@return nil
function SKInitiation.open()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action  = 'streetkings:initiation',
        visible = true,
    })
end

---@return nil
function SKInitiation.close()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action  = 'streetkings:initiation',
        visible = false,
    })
    confirmingModel = nil
end

local function beginConfirm()
    local idx = SKInitiation.hoveredIndex
    if not idx then return false end
    SendNUIMessage({
        action      = 'streetkings:initiation',
        showConfirm = true,
    })
    confirmingModel           = idx
    SKInitiation.isConfirming = true
    SKInitiation.hoveredIndex = nil
    return true
end

RegisterNUICallback('initiationVehicleClick', function(_, cb)
    cb({ ok = beginConfirm() })
end)

AddEventHandler('streetkings:initiation:controllerSelect', function()
    beginConfirm()
end)

RegisterNUICallback('initiationConfirm', function(data, cb)
    cb({ ok = true })

    if not data.confirmed then
        confirmingModel           = nil
        SKInitiation.isConfirming = false
        SendNUIMessage({
            action      = 'streetkings:initiation',
            showConfirm = false,
        })
        SKInitiation.resetHover()
        return
    end

    if not confirmingModel then return end

    local starterVehicle = SKInitiation.STARTER_VEHICLES[confirmingModel]
    local modelName = starterVehicle.model
    local starterColors = SKInitiation.getStarterVehicleColors(confirmingModel)

    local result = lib.callback.await('streetkings:initiation:selectStarterVehicle', false, modelName, starterColors)
    if result and result.ok then
        SKC.SetGameState(GameState.TUTORIAL)
        return
    end

    confirmingModel = nil
    SKInitiation.isConfirming = false
    SendNUIMessage({
        action = 'streetkings:initiation',
        showConfirm = false,
    })
    SKInitiation.resetHover()
end)