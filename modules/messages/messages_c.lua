local hectorPhoneHintShown = false

RegisterNetEvent('streetkings:messages:newMessage', function(msg)
    SKSettings.playSelectedMessageNotificationSound()
    SendNUIMessage({ type = 'messages:newMessage', msg = msg })
    SetTimeout(7500, function()
        if type(msg) == 'table' and msg.sender == 'Hector' and not hectorPhoneHintShown then
            hectorPhoneHintShown = true
            local phoneKey = SKInput.isUsingKeyboard() and 'TAB' or 'DPAD UP'
            SendNUIMessage({
                type = 'missions:subtitle',
                speaker = '',
                body = _L('ui.messages.use_key_to_open_phone', { key = phoneKey }),
                duration = 5000,
            })
        end
    end)
end)

---@return boolean
local function canDeliverQueuedMessages()
    local state = SKC.GetGameState()
    local deliverable = state == GameState.FREEROAM or state == GameState.MULTIPLAYER_LOBBY or state == GameState.MISSION
    return deliverable and not SKPhone.isOpen()
end

CreateThread(function()
    while true do
        if canDeliverQueuedMessages() then
            lib.callback.await('streetkings:messages:deliverQueued', false)
            Wait(2500)
        else
            Wait(1000)
        end
    end
end)

RegisterNUICallback('phone:messages:getData', function(_, cb)
    local data = lib.callback.await('streetkings:messages:getData', false)
    cb(data)
end)

RegisterNUICallback('phone:messages:markRead', function(payload, cb)
    lib.callback.await('streetkings:messages:markRead', false, payload.sender)
    cb({})
end)

RegisterNUICallback('phone:messages:action', function(payload, cb)
    cb({})
    if type(payload) ~= 'table' or type(payload.kind) ~= 'string' then return end

    if payload.kind == 'joinLobby' and type(payload.lobbyId) == 'string' then
        SKMultiplayer.joinLobbyFromMessage(payload.lobbyId)
    end

    if payload.kind == 'propertyInvite' then
        SKPropertyInvite.handleMessageAction(payload)
    end
end)
