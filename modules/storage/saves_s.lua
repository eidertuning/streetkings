local dbReady = false
local activeSaves     = {} ---@type table<integer, string>
local activeDocuments = {} ---@type table<integer, SKSaveDocument>

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `player_saves` (
            `id` CHAR(36) NOT NULL,
            `owner_identifier` VARCHAR(60) NOT NULL,
            `slot_index` TINYINT UNSIGNED NOT NULL,
            `display_name` VARCHAR(128) NOT NULL DEFAULT 'Save',
            `schema_version` SMALLINT UNSIGNED NOT NULL,
            `document_json` LONGTEXT NOT NULL,
            `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
            `last_played_at` DATETIME(3) NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_owner_slot` (`owner_identifier`, `slot_index`),
            KEY `idx_owner` (`owner_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        ALTER TABLE `player_saves`
        ADD COLUMN IF NOT EXISTS `last_played_at` DATETIME(3) NULL DEFAULT NULL
    ]])
    dbReady = true
end)

AddEventHandler('playerDropped', function()
    local src = source --[[@as integer]]
    activeSaves[src]     = nil
    activeDocuments[src] = nil
end)

-- Path utilities ------------------------------------------------------------

---@param t table
---@param path string
---@return any
local function resolvePath(t, path)
    local node = t
    for part in path:gmatch('[^.]+') do
        if type(node) ~= 'table' then return nil end
        node = node[part]
    end
    return node
end

---@param t table
---@param path string
---@param value any
local function mutatePath(t, path, value)
    local parts = {}
    for part in path:gmatch('[^.]+') do
        parts[#parts + 1] = part
    end
    local node = t
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(node[part]) ~= 'table' then
            node[part] = {}
        end
        node = node[part]
    end
    node[parts[#parts]] = value
end

-- Internal DB helpers -------------------------------------------------------

---@param source integer
---@return string
local function ownerLicense(source)
    return GetPlayerIdentifierByType(source --[[@as string]], 'license')
end

---@param row table
---@return SKSaveSlotDto
local function rowToSlot(row)
    return { slotIndex = row.slot_index, occupied = true, id = row.id, name = row.display_name, detail = row.updated_at }
end

---@param owner string
---@return SKSaveSlotDto[]
local function dbListSlots(owner)
    local rows = MySQL.query.await(
        'SELECT id, slot_index, display_name, updated_at FROM player_saves WHERE owner_identifier = ? ORDER BY slot_index ASC',
        { owner }
    )
    local slots = SKSaves.emptySlots()
    for i = 1, #rows do
        local row = rows[i]
        if SKSaves.isValidSlot(row.slot_index) then
            slots[row.slot_index] = rowToSlot(row)
        end
    end
    return slots
end

---@param owner string
---@param slotIndex integer
---@param name string
---@return table
local function dbCreateSlot(owner, slotIndex, name)
    local existing = MySQL.single.await(
        'SELECT id FROM player_saves WHERE owner_identifier = ? AND slot_index = ?',
        { owner, slotIndex }
    )
    if existing then
        return { ok = false, error = SKSaves.Error.SLOT_OCCUPIED }
    end

    local saveId = lib.string.random('........^-....^-....^-....^-............')
    local ok = pcall(function()
        MySQL.query.await(
            'INSERT INTO player_saves (id, owner_identifier, slot_index, display_name, schema_version, document_json) VALUES (?, ?, ?, ?, ?, ?)',
            { saveId, owner, slotIndex, name, SKSaves.SCHEMA_VERSION, SKSaves.encodeDocument(SKSaves.newDocument()) }
        )
    end)
    if not ok then
        return { ok = false, error = SKSaves.Error.INSERT_FAILED }
    end

    return { ok = true, saveId = saveId }
end

---@param owner string
---@param slotIndex integer
---@param saveId string
---@return table
local function dbVerifySlot(owner, slotIndex, saveId)
    local row = MySQL.single.await(
        'SELECT id FROM player_saves WHERE owner_identifier = ? AND slot_index = ? AND id = ?',
        { owner, slotIndex, saveId }
    )
    if not row then
        return { ok = false, error = SKSaves.Error.SAVE_NOT_FOUND }
    end
    return { ok = true, saveId = saveId }
end

---@param owner string
---@param saveId string
---@return table
local function dbLoadSave(owner, saveId)
    local row = MySQL.single.await(
        'SELECT id, schema_version, document_json FROM player_saves WHERE owner_identifier = ? AND id = ?',
        { owner, saveId }
    )
    if not row then
        return { ok = false, error = SKSaves.Error.SAVE_NOT_FOUND }
    end
    local ok, document = pcall(SKSaves.decodeDocument, row.document_json, row.schema_version)
    if not ok then
        return { ok = false, error = SKSaves.Error.INVALID_DOCUMENT }
    end
    return { ok = true, saveId = row.id, document = document }
end

---@param owner string
---@param saveId string
local function dbSetLastPlayedSave(owner, saveId)
    MySQL.update.await(
        'UPDATE player_saves SET last_played_at = CURRENT_TIMESTAMP(3) WHERE owner_identifier = ? AND id = ?',
        { owner, saveId }
    )
end

---@param owner string
---@return SKSaveSlotDto|nil
local function dbGetLastPlayedSave(owner)
    local row = MySQL.single.await([[
        SELECT id, slot_index, display_name, updated_at
        FROM player_saves
        WHERE owner_identifier = ? AND last_played_at IS NOT NULL
        ORDER BY last_played_at DESC, updated_at DESC
        LIMIT 1
    ]], { owner })

    if not row then
        return nil
    end

    return rowToSlot(row)
end

---@param owner string
---@param saveId string
---@param document SKSaveDocument
---@return table
local function dbWriteSave(owner, saveId, document)
    local ok, encoded = pcall(SKSaves.encodeDocument, document)
    if not ok then
        return { ok = false, error = SKSaves.Error.INVALID_DOCUMENT }
    end
    local updated = MySQL.update.await(
        'UPDATE player_saves SET schema_version = ?, document_json = ? WHERE owner_identifier = ? AND id = ?',
        { SKSaves.SCHEMA_VERSION, encoded, owner, saveId }
    )
    if not updated or updated < 1 then
        return { ok = false, error = SKSaves.Error.SAVE_NOT_FOUND }
    end
    return { ok = true }
end

-- Public API ----------------------------------------------------------------

---@param source integer
---@return string|nil
function SKSaves.getActiveSaveId(source)
    return activeSaves[source]
end

---@param source integer
---@return boolean
function SKSaves.hasActiveSave(source)
    return activeSaves[source] ~= nil
end

---@param source integer
---@return SKSaveDocument|nil
function SKSaves.getDocument(source)
    return activeDocuments[source]
end

---@param source integer
---@param key string dot-separated path into SKSaveDocument for example 'economy.cash'
---@return any
function SKSaves.read(source, key)
    local document = activeDocuments[source]
    return resolvePath(document, key)
end

---@param source integer
---@param key string dot-separated path into SKSaveDocument for example 'economy.cash'
---@param value any
---@return boolean success
function SKSaves.write(source, key, value)
    local document = activeDocuments[source]
    local saveId   = activeSaves[source]
    local owner    = ownerLicense(source)

    local previous = resolvePath(document, key)
    mutatePath(document, key, value)

    local ok, encoded = pcall(SKSaves.encodeDocument, document)
    if not ok then
        mutatePath(document, key, previous)
        return false
    end

    local updated = MySQL.update.await(
        'UPDATE player_saves SET schema_version = ?, document_json = ? WHERE owner_identifier = ? AND id = ?',
        { SKSaves.SCHEMA_VERSION, encoded, owner, saveId }
    )
    if not updated or updated < 1 then
        mutatePath(document, key, previous)
        return false
    end

    return true
end

---@param source integer
---@return boolean
function SKSaves.persist(source)
    local document = activeDocuments[source]
    local saveId   = activeSaves[source]
    local owner    = ownerLicense(source)
    if not document or not saveId or not owner then return false end
    return dbWriteSave(owner, saveId, document).ok
end

---@param source integer
function SKSaves.clearActive(source)
    activeSaves[source]     = nil
    activeDocuments[source] = nil
end

-- Callbacks -----------------------------------------------------------------

lib.callback.register('streetkings:saves:list', function(source)
    if not dbReady then return { ok = false, error = SKSaves.Error.DB_NOT_READY } end
    local owner = ownerLicense(source)
    if not owner then return { ok = false, error = SKSaves.Error.NO_LICENSE } end
    return { ok = true, slots = dbListSlots(owner), slotsVersion = SKSaves.SLOTS_VERSION }
end)

lib.callback.register('streetkings:saves:select', function(source, slotIndex, isNew, saveId, saveName)
    if not dbReady then return { ok = false, error = SKSaves.Error.DB_NOT_READY } end
    local owner = ownerLicense(source)
    if not owner then return { ok = false, error = SKSaves.Error.NO_LICENSE } end
    if not SKSaves.isValidSlot(slotIndex) then return { ok = false, error = SKSaves.Error.INVALID_SLOT } end

    local result
    if isNew then
        result = dbCreateSlot(owner, slotIndex, saveName)
    else
        if type(saveId) ~= 'string' then return { ok = false, error = SKSaves.Error.SAVE_NOT_FOUND } end
        result = dbVerifySlot(owner, slotIndex, saveId)
    end

    if not result.ok then return result end

    activeSaves[source] = result.saveId

    if isNew then
        activeDocuments[source] = SKSaves.newDocument()
    else
        local loaded = dbLoadSave(owner, result.saveId)
        if not loaded.ok then return loaded end
        activeDocuments[source] = loaded.document
    end

    dbSetLastPlayedSave(owner, result.saveId)
    TriggerEvent('streetkings:messages:trigger', source, 'saveSessionBound', {
        saveId = result.saveId,
        slotIndex = slotIndex,
        isNew = isNew,
    })

    return result
end)

lib.callback.register('streetkings:saves:loadActive', function(source)
    if not dbReady then return { ok = false, error = SKSaves.Error.DB_NOT_READY } end
    local document = activeDocuments[source]
    if not document then return { ok = false, error = SKSaves.Error.NO_ACTIVE_DOCUMENT } end
    return { ok = true, saveId = activeSaves[source], document = document }
end)

lib.callback.register('streetkings:saves:delete', function(source, slotIndex, saveId)
    if not dbReady then return { ok = false, error = SKSaves.Error.DB_NOT_READY } end
    local owner = ownerLicense(source)
    if not owner then return { ok = false, error = SKSaves.Error.NO_LICENSE } end
    if not SKSaves.isValidSlot(slotIndex) then return { ok = false, error = SKSaves.Error.INVALID_SLOT } end
    if type(saveId) ~= 'string' then return { ok = false, error = SKSaves.Error.SAVE_NOT_FOUND } end

    local deleted = MySQL.update.await(
        'DELETE FROM player_saves WHERE owner_identifier = ? AND slot_index = ? AND id = ?',
        { owner, slotIndex, saveId }
    )
    if not deleted or deleted < 1 then return { ok = false, error = SKSaves.Error.SAVE_NOT_FOUND } end

    if activeSaves[source] == saveId then
        activeSaves[source]     = nil
        activeDocuments[source] = nil
    end

    return { ok = true }
end)

lib.callback.register('streetkings:saves:getLastPlayed', function(source)
    if not dbReady then return { ok = false, error = SKSaves.Error.DB_NOT_READY } end
    local owner = ownerLicense(source)
    if not owner then return { ok = false, error = SKSaves.Error.NO_LICENSE } end
    return {
        ok = true,
        save = dbGetLastPlayedSave(owner),
    }
end)

exports('HasActiveSave', SKSaves.hasActiveSave)
exports('ReadSaveData', function(source, path)
    if type(path) ~= 'string' or path == '' then return nil end
    if not SKSaves.hasActiveSave(source) then return nil end
    return SKSaves.read(source, path)
end)
exports('WriteSaveData', function(source, path, value)
    if type(path) ~= 'string' or path == '' then return false end
    if not SKSaves.hasActiveSave(source) then return false end
    return SKSaves.write(source, path, value)
end)
exports('PersistSave', function(source)
    if not SKSaves.hasActiveSave(source) then return false end
    SKSaves.persist(source)
    return true
end)

exports('GetPlayerCash', function(source)
    if not SKSaves.hasActiveSave(source) then return 0 end
    return SKSaves.read(source, 'economy.cash') or 0
end)

exports('AddPlayerCash', function(source, amount)
    if type(amount) ~= 'number' or amount <= 0 then return false end
    if not SKSaves.hasActiveSave(source) then return false end
    local cash = SKSaves.read(source, 'economy.cash') or 0
    return SKSaves.write(source, 'economy.cash', cash + amount)
end)

exports('RemovePlayerCash', function(source, amount)
    if type(amount) ~= 'number' or amount <= 0 then return false end
    if not SKSaves.hasActiveSave(source) then return false end
    local cash = SKSaves.read(source, 'economy.cash') or 0
    if cash < amount then return false end
    return SKSaves.write(source, 'economy.cash', cash - amount)
end)