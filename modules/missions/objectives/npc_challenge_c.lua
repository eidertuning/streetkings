-- Objective: npcChallenge (advance on any win/lose result from street challenge)
SKObjectives = SKObjectives or {}

local handler = {}

local activeListener = nil

local function removeListener()
    if activeListener then
        RemoveEventHandler(activeListener)
        activeListener = nil
    end
end

function handler.start(ctx)
    local hint = (ctx and ctx.objective and ctx.objective.label)
        or 'Burnout next to a racer to challenge them'

    SendNUIMessage({ type = 'missions:objectiveHint', text = hint })

    removeListener()
    activeListener = AddEventHandler('streetkings:npcchallenge:finished', function(_payload)
        removeListener()
        SendNUIMessage({ type = 'missions:objectiveHint', text = nil })
        -- Server-side advance is driven by streetkings:server:recordNpcRace
    end)

    return {
        remove = function()
            removeListener()
            SendNUIMessage({ type = 'missions:objectiveHint', text = nil })
        end,
    }
end

function handler.stop(_ctx)
    removeListener()
    SendNUIMessage({ type = 'missions:objectiveHint', text = nil })
end

SKObjectives[ObjectiveType.NPC_CHALLENGE] = handler
