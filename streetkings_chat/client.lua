local Config = SKChatConfig or {}
local isOpen = false

local function coreResource()
    return Config.CoreResource or 'streetkings'
end

local function currentState()
    local resource = coreResource()
    if GetResourceState(resource) ~= 'started' then return nil end
    local ok, state = pcall(function()
        return exports[resource]:GetGameState()
    end)
    return ok and state or nil
end

local function canUseChat()
    if IsPauseMenuActive() then return false end
    return currentState() == (Config.AllowedState or 'freeroam')
end

local function setOpen(nextOpen)
    if nextOpen and not canUseChat() then
        SendNUIMessage({ type = 'skchat:denied' })
        return
    end

    isOpen = nextOpen == true
    SetNuiFocus(isOpen, isOpen)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = isOpen and 'skchat:open' or 'skchat:close' })
end

RegisterCommand(Config.OpenCommand or 'skchat', function()
    setOpen(true)
end, false)

RegisterKeyMapping(Config.OpenCommand or 'skchat', 'Abrir chat StreetKings', 'keyboard', Config.DefaultKey or 'T')

RegisterNUICallback('skchat:submit', function(data, cb)
    local message = data and data.message or ''
    setOpen(false)
    if type(message) == 'string' and message:gsub('%s+', '') ~= '' then
        TriggerServerEvent('skchat:submit', message)
    end
    cb({ ok = true })
end)

RegisterNUICallback('skchat:close', function(_, cb)
    setOpen(false)
    cb({ ok = true })
end)

RegisterNetEvent('skchat:push', function(payload)
    SendNUIMessage({ type = 'skchat:message', message = payload })
end)

RegisterNetEvent('skchat:system', function(text)
    SendNUIMessage({
        type = 'skchat:message',
        message = {
            scope = 'system',
            author = 'Sistema',
            tag = 'SYS',
            text = tostring(text or ''),
            timestamp = GetGameTimer(),
        },
    })
end)

CreateThread(function()
    while true do
        if isOpen and not canUseChat() then
            setOpen(false)
        end
        Wait(isOpen and 250 or 1000)
    end
end)
