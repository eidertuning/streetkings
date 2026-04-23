---@param options { title: string, type: string, duration: integer, inCinematic: boolean? }
function SKNotify(options)
    CreateThread(function()
        if not options.inCinematic then
            while Cinematic do Wait(100) end
        end
        SendNUIMessage({
            type      = 'toast',
            title     = options.title,
            toastType = options.type or 'info',
            duration  = options.duration or 3000,
        })
    end)
end

exports('ShowNotification', SKNotify)