-- Objective: completeEvent (server-driven advance via event submission hook)
SKObjectives = SKObjectives or {}

local handler = {}

handler.requiresFreeroam = true

function handler.start(ctx)
    SendNUIMessage({
        type = 'missions:objectiveHint',
        text = _L('lua.prompts.enter_race_phone'),
    })
    return {
        remove = function()
            SendNUIMessage({ type = 'missions:objectiveHint', text = nil })
        end,
    }
end

function handler.stop(ctx)
    SendNUIMessage({ type = 'missions:objectiveHint', text = nil })
end

SKObjectives[ObjectiveType.COMPLETE_EVENT] = handler
