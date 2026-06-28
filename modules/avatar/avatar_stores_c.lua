local activePoints   = {}
local blips          = {}
local storeWaypoints = {}

local CLOTHING_BLIP_CATEGORY = 23
local blipCategoryRegistered = false

local function addBlip(store)
    if not blipCategoryRegistered then
        blipCategoryRegistered = true
        AddTextEntry(('BLIP_CAT_%d'):format(CLOTHING_BLIP_CATEGORY), 'Clothing Stores')
    end
    local blip = AddBlipForCoord(store.marker.x, store.marker.y, store.marker.z)
    SetBlipSprite(blip, store.blip)
    SetBlipScale(blip, 0.5)
    SetBlipColour(blip, 47)
    SetBlipAsShortRange(blip, false)
    SetBlipCategory(blip, CLOTHING_BLIP_CATEGORY)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(store.name)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function setupStorePoints(store)
    local wpId = SKWaypoint.Create({
        coords       = store.marker,
        text         = store.name,
        color        = '#ff476f',
        icon         = 'shirt',
        showDist     = true,
        groundBeam   = true,
        maxRender    = 250.0,
        interactable = true,
    })
    storeWaypoints[#storeWaypoints + 1] = wpId

    local promptKey = nil
    local innerPoint = lib.points.new({
        coords   = store.marker,
        distance = 5.0,

        onEnter = function()
            promptKey = SKInput.getInteractLabel()
            SendNUIMessage({ type = 'prompt:show', key = promptKey, text = _L('lua.prompts.enter', { name = store.name }) })
        end,

        onExit = function()
            promptKey = nil
            SendNUIMessage({ type = 'prompt:hide' })
        end,

        nearby = function(self)
            local nextPromptKey = SKInput.getInteractLabel()
            if nextPromptKey ~= promptKey then
                promptKey = nextPromptKey
                SendNUIMessage({ type = 'prompt:show', key = promptKey, text = _L('lua.prompts.enter', { name = store.name }) })
            end
            if SKInput.isInteractJustReleased() then
                SendNUIMessage({ type = 'prompt:hide' })
                local vehicle = SKFreeroam.getActiveVehicle()
                if vehicle then
                    local vpos = GetEntityCoords(vehicle)
                    SKFreeroam.setReturnPosition(vector4(vpos.x, vpos.y, vpos.z, GetEntityHeading(vehicle)))
                end
                SKAvatar.enterFromStore(store)
            end
        end,
    })

    activePoints[#activePoints + 1] = innerPoint
end

AddEventHandler('streetkings:avatar:freeroamEnter', function()
    for _, point in ipairs(activePoints) do point:remove() end
    activePoints = {}
    for id, blip in pairs(blips) do
        RemoveBlip(blip)
        blips[id] = nil
    end

    for _, store in ipairs(SKAvatarData.ClothingStores) do
        blips[store.id] = addBlip(store)
        setupStorePoints(store)
    end
end)

AddEventHandler('streetkings:avatar:freeroamExit', function()
    for _, point in ipairs(activePoints) do
        point:remove()
    end
    activePoints = {}

    for id, blip in pairs(blips) do
        RemoveBlip(blip)
        blips[id] = nil
    end

    for _, wpId in ipairs(storeWaypoints) do
        SKWaypoint.Remove(wpId)
    end
    storeWaypoints = {}
end)
