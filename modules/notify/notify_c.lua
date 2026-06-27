---@param options { title: string, type: string, duration: integer, inCinematic: boolean? }
function SKNotify(options)
    options = type(options) == 'table' and options or {}
    CreateThread(function()
        if not options.inCinematic then
            while Cinematic do Wait(100) end
        end
        SendNUIMessage({
            type = 'phone:systemNotification',
            title = options.title or 'Sistema',
            body = options.body or options.description or options.title or '',
            notificationType = options.type or 'info',
            duration = options.duration or 4500,
        })
    end)
end

RegisterNetEvent('streetkings:notify', function(options)
    if type(options) ~= 'table' then return end
    SKNotify(options)
end)

exports('ShowNotification', SKNotify)
