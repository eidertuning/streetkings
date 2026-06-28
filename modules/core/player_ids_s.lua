SKPlayerIds = SKPlayerIds or {}

local dbReady = false
local cacheByLicense = {}
local cacheBySource = {}

local function ownerLicense(source)
    if type(source) ~= 'number' or source <= 0 then return nil end
    return GetPlayerIdentifierByType(source --[[@as string]], 'license')
end

local function getDisplayName(source)
    local name = GetPlayerName(source)
    if type(name) ~= 'string' or name == '' then return 'Unknown' end
    return name:sub(1, 128)
end

local function upsertPersistentId(source)
    if not dbReady then return nil end
    local license = ownerLicense(source)
    if not license then return nil end

    if cacheByLicense[license] then
        cacheBySource[source] = cacheByLicense[license]
        MySQL.update.await(
            'UPDATE streetkings_player_ids SET last_seen_at = CURRENT_TIMESTAMP(3), last_name = ? WHERE owner_identifier = ?',
            { getDisplayName(source), license }
        )
        return cacheByLicense[license]
    end

    MySQL.insert.await(
        'INSERT IGNORE INTO streetkings_player_ids (owner_identifier, first_name, last_name) VALUES (?, ?, ?)',
        { license, getDisplayName(source), getDisplayName(source) }
    )
    MySQL.update.await(
        'UPDATE streetkings_player_ids SET last_seen_at = CURRENT_TIMESTAMP(3), last_name = ? WHERE owner_identifier = ?',
        { getDisplayName(source), license }
    )

    local row = MySQL.single.await(
        'SELECT streetkings_id FROM streetkings_player_ids WHERE owner_identifier = ? LIMIT 1',
        { license }
    )
    local id = row and tonumber(row.streetkings_id) or nil
    if id then
        cacheByLicense[license] = id
        cacheBySource[source] = id
    end
    return id
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `streetkings_player_ids` (
            `streetkings_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `owner_identifier` VARCHAR(60) NOT NULL,
            `first_name` VARCHAR(128) NOT NULL DEFAULT 'Unknown',
            `last_name` VARCHAR(128) NOT NULL DEFAULT 'Unknown',
            `first_seen_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            `last_seen_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
            PRIMARY KEY (`streetkings_id`),
            UNIQUE KEY `uq_streetkings_player_owner` (`owner_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    dbReady = true
end)

AddEventHandler('playerJoining', function()
    local src = source --[[@as integer]]
    CreateThread(function()
        Wait(1000)
        upsertPersistentId(src)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    cacheBySource[src] = nil
end)

function SKPlayerIds.Get(source)
    local cached = cacheBySource[source]
    if cached then return cached end
    return upsertPersistentId(source)
end

function SKPlayerIds.GetIdentity(source)
    local skId = SKPlayerIds.Get(source)
    return {
        source = source,
        streetkingsId = skId,
        license = ownerLicense(source),
        name = GetPlayerName(source) or 'Unknown',
        discordId = SKDiscord and SKDiscord.GetDiscordId and SKDiscord.GetDiscordId(source) or nil,
        discordAvatarUrl = SKDiscord and SKDiscord.GetAvatarUrl and SKDiscord.GetAvatarUrl(source) or '',
    }
end

exports('GetStreetKingsId', SKPlayerIds.Get)
exports('GetPersistentPlayerId', SKPlayerIds.Get)
exports('GetPlayerIdentity', SKPlayerIds.GetIdentity)
