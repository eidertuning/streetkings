local APP = {
    id = 'template_app',
    label = 'Template',
    icon = 'fa-puzzle-piece',
    glyph = 'T',
    color = '#7c3aed',
    category = 'tools',
    ui = 'html/index.html',
    description = 'Copy this resource to build a StreetKings tablet app.',
    version = '1.0.0',
    developer = 'StreetKings',
}

local function registerApp()
    local ok, reason = exports['streetkings']:RegisterTabletApp(APP)
    if not ok then
        print(('[tablet-template] register failed: %s'):format(reason or 'unknown'))
    end
end

RegisterNUICallback('templateEcho', function(data, cb)
    cb({
        ok = true,
        echo = data or {},
        resource = GetCurrentResourceName(),
        gameTimer = GetGameTimer(),
    })
end)

RegisterCommand('tabletTemplateOpen', function()
    exports['streetkings']:OpenTabletApp(APP.id, {
        openedFrom = 'tabletTemplateOpen',
    })
end, false)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        registerApp()
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        exports['streetkings']:UnregisterTabletApp(APP.id)
    end
end)
