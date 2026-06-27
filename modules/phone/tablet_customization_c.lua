RegisterNUICallback('phone:tablet:getConfig', function(_, cb)
    local result = lib.callback.await('streetkings:tablet:getConfig', false)
    cb(result or { ok = false, error = 'config_unavailable' })
end)

RegisterNUICallback('phone:tablet:setConfig', function(data, cb)
    local result = lib.callback.await('streetkings:tablet:setConfig', false, data or {})
    cb(result or { ok = false, error = 'config_save_failed' })
end)

RegisterNUICallback('phone:tablet:setLayout', function(data, cb)
    local result = lib.callback.await('streetkings:tablet:setLayout', false, data or {})
    cb(result or { ok = false, error = 'layout_save_failed' })
end)

RegisterNUICallback('phone:tablet:setAppOverride', function(data, cb)
    local result = lib.callback.await('streetkings:tablet:setAppOverride', false, data or {})
    cb(result or { ok = false, error = 'app_override_save_failed' })
end)
