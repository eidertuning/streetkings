local dbReady = false
local cachedJumps = {}

local function tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `stunt_jumps` (
            `id` VARCHAR(64) PRIMARY KEY,
            `name` VARCHAR(128) NOT NULL,
            `data` JSON NOT NULL,
            `created_by` VARCHAR(64) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    local rows = MySQL.query.await('SELECT `id`, `name`, `data` FROM `stunt_jumps`')
    if rows then
        for _, row in ipairs(rows) do
            local ok, data = pcall(json.decode, row.data)
            if ok and data then
                data.id   = row.id
                data.name = row.name
                cachedJumps[row.id] = data
                SKStuntJumps[row.id] = data
            end
        end
    end

    dbReady = true
end)

lib.callback.register('streetkings:stunts:load', function()
    return cachedJumps
end)

lib.callback.register('streetkings:stunts:save', function(source, def)
    if not IsPlayerAceAllowed(source, 'command') then
        return { ok = false, reason = 'No permission' }
    end
    if not dbReady then
        return { ok = false, reason = 'Database not ready' }
    end
    if type(def) ~= 'table' or type(def.id) ~= 'string' or type(def.name) ~= 'string' then
        return { ok = false, reason = 'Invalid definition' }
    end

    local license = GetPlayerIdentifierByType(source, 'license') or ('player:' .. source)

    local data = {}
    for k, v in pairs(def) do
        if k ~= 'id' and k ~= 'name' then
            data[k] = v
        end
    end

    MySQL.query.await([[
        INSERT INTO `stunt_jumps` (`id`, `name`, `data`, `created_by`)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `data` = VALUES(`data`)
    ]], { def.id, def.name, json.encode(data), license })

    cachedJumps[def.id] = def
    SKStuntJumps[def.id] = def

    TriggerClientEvent('streetkings:stunts:sync', -1, def.id, def)
    return { ok = true }
end)

lib.callback.register('streetkings:stunts:delete', function(source, jumpId)
    if not IsPlayerAceAllowed(source, 'command') then
        return { ok = false, reason = 'No permission' }
    end
    if not dbReady then
        return { ok = false, reason = 'Database not ready' }
    end
    if type(jumpId) ~= 'string' then
        return { ok = false, reason = 'Invalid jump ID' }
    end

    MySQL.query.await('DELETE FROM `stunt_jumps` WHERE `id` = ?', { jumpId })
    cachedJumps[jumpId] = nil
    SKStuntJumps[jumpId] = nil

    TriggerClientEvent('streetkings:stunts:removed', -1, jumpId)
    return { ok = true }
end)