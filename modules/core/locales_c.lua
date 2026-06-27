local function sendNuiLocale()
    if not SKLocale or not SKLocale.getUiTranslations then return end
    local payload = SKLocale.getUiTranslations()
    payload.type = 'locales:set'
    SendNUIMessage(payload)
end

RegisterNUICallback('locales:get', function(_, cb)
    cb(SKLocale.getUiTranslations())
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(500, sendNuiLocale)
end)

RegisterNetEvent('streetkings:locales:refresh', sendNuiLocale)
