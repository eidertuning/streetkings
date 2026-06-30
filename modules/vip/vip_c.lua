local VIP_STUDIO_APP = {
    id = 'vipstudio',
    label = 'VIP Studio',
    icon = 'fa-crown',
    glyph = 'VIP',
    color = '#ffd147',
    category = 'system',
    ui = 'html/apps/vipstudio/index.html',
    description = 'Personaliza tu nametag VIP y etiquetas de admin.',
    version = '1.0.0',
    developer = 'Five Horizon',
}

local function registerVipStudioApp()
    pcall(function()
        exports[GetCurrentResourceName()]:RegisterTabletApp(VIP_STUDIO_APP)
    end)
end

RegisterNUICallback('skVipStudioGet', function(_, cb)
    local result = lib.callback.await('streetkings:vip:getStudioData', false)
    cb(result or { ok = false, error = 'vip_unavailable' })
end)

RegisterNUICallback('skVipStudioSave', function(data, cb)
    local result = lib.callback.await('streetkings:vip:saveTagConfig', false, {
        config = data and data.config or {},
    })
    cb(result or { ok = false, error = 'vip_save_failed' })
end)

RegisterNUICallback('skVipStudioReset', function(_, cb)
    local result = lib.callback.await('streetkings:vip:resetTagConfig', false)
    cb(result or { ok = false, error = 'vip_reset_failed' })
end)

RegisterNUICallback('skVipStudioRefresh', function(_, cb)
    local result = lib.callback.await('streetkings:vip:refresh', false)
    cb(result or { ok = false, error = 'vip_refresh_failed' })
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        registerVipStudioApp()
    end
end)

CreateThread(function()
    Wait(750)
    registerVipStudioApp()
end)
