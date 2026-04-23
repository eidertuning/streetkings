SKPropertyInvite = {}

local activeInvite = nil
local inviteAccepted = false
local inviteWaypoint = nil
local inviteBlip = nil

---@param propertyId string
---@return boolean
function SKPropertyInvite.hasInvite(propertyId)
    return activeInvite ~= nil and inviteAccepted and activeInvite.propertyId == propertyId
end

---@return table|nil
function SKPropertyInvite.getActiveInvite()
    return activeInvite
end

local function clearMarkers()
    if inviteWaypoint then
        SKWaypoint.Remove(inviteWaypoint)
        inviteWaypoint = nil
    end

    if inviteBlip and DoesBlipExist(inviteBlip) then
        RemoveBlip(inviteBlip)
        inviteBlip = nil
    end
end

local function clearInvite()
    activeInvite = nil
    inviteAccepted = false
    clearMarkers()
end

local function createInviteMarkers()
    if not activeInvite then return end

    clearMarkers()

    inviteWaypoint = SKWaypoint.Create({
        coords     = activeInvite.exterior,
        text       = activeInvite.propertyName .. ' (Invite)',
        color      = '#3b82f6',
        icon       = 'house',
        showDist   = true,
        groundBeam = true,
        maxRender  = 500.0,
    })

    local ext = activeInvite.exterior
    inviteBlip = AddBlipForCoord(ext.x, ext.y, ext.z)
    SetBlipSprite(inviteBlip, 475)
    SetBlipColour(inviteBlip, 3)
    SetBlipScale(inviteBlip, 1.2)
    SetBlipAsShortRange(inviteBlip, false)
    SetBlipFlashes(inviteBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(activeInvite.propertyName .. ' (Invite)')
    EndTextCommandSetBlipName(inviteBlip)
end

---@param entry SKPropertyEntry
function SKPropertyInvite.enterFromInvite(entry)
    if not activeInvite or not inviteAccepted then return end

    local result = lib.callback.await('streetkings:property:acceptInvite', false)
    if not result.ok then
        SKNotify({ type = 'error', title = 'Invite no longer valid' })
        clearInvite()
        return
    end

    clearInvite()
    SKProperty.forceEnterById(result.propertyId)
end

---@param payload table
function SKPropertyInvite.handleMessageAction(payload)
    if payload.response == 'accept' then
        if SKC.GetGameState() ~= GameState.FREEROAM then
            SKNotify({ type = 'error', title = 'You can\'t accept invites right now' })
            return
        end

        if GetPlayerWantedLevel(PlayerId()) > 0 then
            SKNotify({ type = 'error', title = 'You can\'t accept invites with a wanted level' })
            return
        end

        clearInvite()

        activeInvite = {
            inviterName = payload.inviterName,
            propertyId = payload.propertyId,
            propertyName = payload.propertyName,
            exterior = vector3(payload.exterior.x, payload.exterior.y, payload.exterior.z),
        }
        inviteAccepted = true

        createInviteMarkers()
        SetNewWaypoint(payload.exterior.x, payload.exterior.y)
        SKNotify({
            type = 'success',
            title = payload.propertyName .. ' marked on your map',
            duration = 5000,
        })
    elseif payload.response == 'decline' then
        clearInvite()
        lib.callback.await('streetkings:property:declineInvite', false)
        SKNotify({ type = 'info', title = 'Invite declined' })
    end
end

RegisterNetEvent('streetkings:property:inviteExpired', function()
    if activeInvite then
        SKNotify({ type = 'warning', title = 'Property invite cancelled' })
        clearInvite()
    end
end)

-- Phone NUI callbacks for invite flow

RegisterNUICallback('phone:realestate:getOnlinePlayers', function(_, cb)
    local players = lib.callback.await('streetkings:property:getOnlinePlayers', false)
    cb(players or {})
end)

RegisterNUICallback('phone:realestate:sendInvite', function(data, cb)
    if type(data) ~= 'table' or not data.propertyId or not data.targetSource then
        cb({ ok = false, reason = 'invalid_params' })
        return
    end

    local result = lib.callback.await('streetkings:property:sendInvite', false, data.propertyId, data.targetSource)
    cb(result)

    if result.ok then
        SKNotify({ type = 'success', title = 'Invite Sent' })
    else
        SKNotify({ type = 'error', title = 'Failed to send invite' })
    end
end)