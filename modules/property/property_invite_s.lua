local INVITE_EXPIRY_SECONDS = 120
local NON_FREEROAM_BUCKET_OFFSET = 1000

SKPropertyInviteServer = {}

---@class SKPropertyInviteData
---@field inviterSource integer
---@field inviterName string
---@field propertyId string
---@field propertyName string
---@field exterior vector4
---@field sentAt integer

---@type table<integer, SKPropertyInviteData>
local activeInvites = {}

---@type table<integer, integer>
local sharedBucketGuests = {}

---@param src integer
---@return integer|nil
function SKPropertyInviteServer.getSharedBucket(src)
    local hostSrc = sharedBucketGuests[src]
    if hostSrc then
        return NON_FREEROAM_BUCKET_OFFSET + hostSrc
    end
    return nil
end

---@param source integer
---@return string
local function getPlayerName(source)
    return GetPlayerName(source) or ('Player ' .. source)
end

lib.callback.register('streetkings:property:getOnlinePlayers', function(source)
    local players = {}

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and src ~= source and SKSaves.hasActiveSave(src) then
            players[#players + 1] = {
                id = src,
                name = getPlayerName(src),
            }
        end
    end

    return players
end)

lib.callback.register('streetkings:property:sendInvite', function(source, propertyId, targetSource)
    local document = SKSaves.getDocument(source)
    if not document then
        return { ok = false, reason = 'no_save' }
    end

    if not document.properties.owned[propertyId] then
        return { ok = false, reason = 'not_owned' }
    end

    local entry = SKProperty.getById(propertyId)
    if not entry then
        return { ok = false, reason = 'not_found' }
    end

    targetSource = tonumber(targetSource)
    if not targetSource or targetSource == source then
        return { ok = false, reason = 'invalid_target' }
    end

    if not SKSaves.hasActiveSave(targetSource) then
        return { ok = false, reason = 'target_offline' }
    end

    local inviterName = getPlayerName(source)

    local sentAt = os.time()

    activeInvites[targetSource] = {
        inviterSource = source,
        inviterName = inviterName,
        propertyId = propertyId,
        propertyName = entry.name,
        exterior = entry.exterior,
        sentAt = sentAt,
    }

    SKMessages.enqueue(targetSource, inviterName, 'property', 'Join me at ' .. entry.name .. '!', nil, {
        kind = 'propertyInvite',
        propertyId = propertyId,
        inviterName = inviterName,
        propertyName = entry.name,
        exterior = {
            x = entry.exterior.x,
            y = entry.exterior.y,
            z = entry.exterior.z,
        },
        expiresAt = sentAt + INVITE_EXPIRY_SECONDS,
    })

    return { ok = true }
end)

lib.callback.register('streetkings:property:acceptInvite', function(source)
    local invite = activeInvites[source]
    if not invite then
        return { ok = false, reason = 'no_invite' }
    end

    if os.time() - invite.sentAt > INVITE_EXPIRY_SECONDS then
        activeInvites[source] = nil
        return { ok = false, reason = 'expired' }
    end

    if not SKSaves.hasActiveSave(invite.inviterSource) then
        activeInvites[source] = nil
        return { ok = false, reason = 'inviter_offline' }
    end

    local propertyId = invite.propertyId
    local inviterSource = invite.inviterSource
    activeInvites[source] = nil

    sharedBucketGuests[source] = inviterSource

    return {
        ok = true,
        propertyId = propertyId,
    }
end)

lib.callback.register('streetkings:property:declineInvite', function(source)
    activeInvites[source] = nil
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    activeInvites[src] = nil
    sharedBucketGuests[src] = nil

    for guestSrc, hostSrc in pairs(sharedBucketGuests) do
        if hostSrc == src then
            sharedBucketGuests[guestSrc] = nil
            SKFreeroamServer.syncRoutingBucket(guestSrc)
        end
    end

    for targetSrc, invite in pairs(activeInvites) do
        if invite.inviterSource == src then
            activeInvites[targetSrc] = nil
            TriggerClientEvent('streetkings:property:inviteExpired', targetSrc)
        end
    end
end)

AddEventHandler('streetkings:freeroam:enter', function()
    local src = source --[[@as integer]]
    if sharedBucketGuests[src] then
        sharedBucketGuests[src] = nil
    end
end)