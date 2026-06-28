--- Always-on rampage world markers and blips (non-daily rampage events).

local RACE_BLIP_CAT_RAMPAGE = 17

local MARKER_INNER = 5.0

local rampagePoints = {}
local rampageWaypoints = {}
local rampageBlips = {}

---@type { registerBlipCategories: fun(), setBlipLegendGroup: fun(blip: integer, blipName: string, category: integer), onStartRampage: fun(eventId: string) }
local cfg = {}

SKEventsRampageMarkers = {}

local function clearRampagePoints()
    for _, p in ipairs(rampagePoints) do p:remove() end
    rampagePoints = {}
    for _, wpId in ipairs(rampageWaypoints) do
        SKWaypoint.Remove(wpId)
    end
    rampageWaypoints = {}
    for _, b in ipairs(rampageBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    rampageBlips = {}
end

local function setupRampagePoints()
    clearRampagePoints()
    cfg.registerBlipCategories()

    for eventId, def in pairs(SKEvents) do
        if type(def) == 'table' and def.type == EventType.RAMPAGE then
            local coords = vector3(def.start.x, def.start.y, def.start.z)

            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 378)
            SetBlipColour(blip, 1)
            SetBlipScale(blip, 0.5)
            SetBlipAsShortRange(blip, false)
            cfg.setBlipLegendGroup(blip, def.name, RACE_BLIP_CAT_RAMPAGE)
            rampageBlips[#rampageBlips + 1] = blip

            local wpId = SKWaypoint.Create({
                coords     = coords,
                text       = def.name,
                color      = '#FF4040',
                icon       = 'skull-crossbones',
                showDist   = true,
                groundBeam = true,
            })
            rampageWaypoints[#rampageWaypoints + 1] = wpId

            local promptKey = nil
            local personalBest = nil

            local function showRampagePrompt()
                promptKey = SKInput.getInteractLabel()
                SendNUIMessage({
                    type         = 'prompt:show',
                    layout       = 'event',
                    key          = promptKey,
                    text         = SKEventsFreeroamMarkers.buildPromptAction(nil, promptKey, def),
                    title        = def.name,
                    eventType    = 'Rampage',
                    personalBest = personalBest,
                })
            end

            local innerPoint = lib.points.new({
                coords   = coords,
                distance = MARKER_INNER,
                onEnter  = function()
                    showRampagePrompt()
                    CreateThread(function()
                        local pb = lib.callback.await('streetkings:events:getPersonalBest', false, eventId)
                        if #(GetEntityCoords(PlayerPedId()) - coords) > MARKER_INNER then return end
                        personalBest = pb
                        showRampagePrompt()
                    end)
                end,
                onExit   = function()
                    promptKey = nil
                    SendNUIMessage({ type = 'prompt:hide' })
                end,
                nearby   = function()
                    local nextPromptKey = SKInput.getInteractLabel()
                    if nextPromptKey ~= promptKey then
                        showRampagePrompt()
                    end
                    if SKInput.isInteractJustReleased() then
                        SendNUIMessage({ type = 'prompt:hide' })
                        cfg.onStartRampage(eventId)
                    end
                end,
            })
            rampagePoints[#rampagePoints + 1] = innerPoint
        end
    end
end

---@param c { registerBlipCategories: fun(), setBlipLegendGroup: fun(blip: integer, blipName: string, category: integer), onStartRampage: fun(eventId: string) }
function SKEventsRampageMarkers.init(c)
    cfg = c
end

function SKEventsRampageMarkers.setup()
    setupRampagePoints()
end

function SKEventsRampageMarkers.clear()
    clearRampagePoints()
end
