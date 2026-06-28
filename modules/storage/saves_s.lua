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

AddEventHandler('playerDropped', function(reason)
    local src = source --[[@as integer]]
    if SKLogs then
        SKLogs.Emit('playerDisconnected', {
            source = src,
            name = GetPlayerName(src) or 'Desconocido',
            alias = activeDocuments[src] and activeDocuments[src].profile and activeDocuments[src].profile.alias or nil,
            reason = reason,
        })
    end
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
    local slot = { slotIndex = row.slot_index, occupied = true, id = row.id, name = row.display_name, detail = row.updated_at }
    local ok, document = pcall(SKSaves.decodeDocument, row.document_json or '{}', row.schema_version or SKSaves.SCHEMA_VERSION)
    if ok and type(document) == 'table' then
        local profile = document.profile or {}
        local photoUrl = profile.photoUrl or profile.avatarUrl or profile.imageUrl
        if type(photoUrl) ~= 'string' then photoUrl = '' end
        slot.profile = {
            alias = profile.alias or row.display_name,
            photoUrl = photoUrl,
            level = document.progression and document.progression.level or 1,
            cash = document.economy and document.economy.cash or 0,
        }
    end
    return slot
end

---@param owner string
---@return SKSaveSlotDto[]
local function dbListSlots(owner)
    local rows = MySQL.query.await(
        'SELECT id, slot_index, display_name, updated_at, schema_version, document_json FROM player_saves WHERE owner_identifier = ? ORDER BY slot_index ASC',
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
    if SKLogs then
        SKLogs.Emit('saveSelected', {
            source = source,
            slotIndex = slotIndex,
            saveId = result.saveId,
            isNew = isNew,
        })
    end
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
-- ce_skadmin bridge v12 -------------------------------------------------------
-- Carga y modifica el save activo desde el propio core de StreetKings.
-- Esto evita depender solo del JSON SQL cuando el garaje/core tiene caché.

local function ceAdminNormalizeTarget(target)
    if type(target) == 'number' then
        return math.floor(target)
    end
    if type(target) == 'string' then
        return tonumber(target:match('%d+'))
    end
    return tonumber(target)
end

local function ceAdminNormalizeOwner(owner)
    if type(owner) ~= 'string' then return nil end
    owner = owner:gsub('%s+', '')
    if owner:sub(1, 8) == 'license:' or owner:sub(1, 9) == 'license2:' then
        return owner
    end
    return nil
end

local function ceAdminLoadLastSaveIntoMemory(target, ownerOverride)
    target = ceAdminNormalizeTarget(target)
    if not target or target <= 0 then
        return false, 'invalid_target:' .. tostring(target)
    end

    if SKSaves.hasActiveSave(target) then
        return true, 'already_active', SKSaves.getActiveSaveId(target)
    end

    if not dbReady then
        return false, SKSaves.Error.DB_NOT_READY
    end

    local owner = ceAdminNormalizeOwner(ownerOverride) or ownerLicense(target)
    if not owner then
        return false, SKSaves.Error.NO_LICENSE
    end

    local slot = dbGetLastPlayedSave(owner)

    if not slot or type(slot.id) ~= 'string' or slot.id == '' then
        local slots = dbListSlots(owner)
        for i = 1, #slots do
            if slots[i] and slots[i].occupied and type(slots[i].id) == 'string' and slots[i].id ~= '' then
                slot = slots[i]
                break
            end
        end
    end

    if not slot or type(slot.id) ~= 'string' or slot.id == '' then
        return false, 'no_save_slot'
    end

    local loaded = dbLoadSave(owner, slot.id)
    if not loaded or not loaded.ok or not loaded.document then
        return false, loaded and loaded.error or 'load_failed'
    end

    activeSaves[target] = slot.id
    activeDocuments[target] = loaded.document
    dbSetLastPlayedSave(owner, slot.id)

    TriggerEvent('streetkings:messages:trigger', target, 'saveSessionBound', {
        saveId = slot.id,
        slotIndex = slot.slotIndex,
        isNew = false,
        via = 'ce_skadmin',
    })

    return true, 'loaded', slot.id, slot.slotIndex
end

exports('AdminEnsureActiveSave', function(target, ownerOverride)
    return ceAdminLoadLastSaveIntoMemory(target, ownerOverride)
end)

local function ceAdminResolveActiveVehicle(document)
    if type(document) ~= 'table' or type(document.garage) ~= 'table' or type(document.garage.vehicles) ~= 'table' then
        return nil, nil, 'no_garage'
    end

    local activeId = document.garage.activeVehicleId
    if type(activeId) == 'string' and activeId ~= '' and document.garage.vehicles[activeId] then
        return activeId, document.garage.vehicles[activeId], nil
    end

    local bestId, bestEntry
    for vehicleId, entry in pairs(document.garage.vehicles) do
        if type(entry) == 'table' then
            if not bestEntry
                or (tonumber(entry.sortIndex) or 9999) < (tonumber(bestEntry.sortIndex) or 9999)
                or ((tonumber(entry.sortIndex) or 9999) == (tonumber(bestEntry.sortIndex) or 9999) and tostring(entry.displayName or '') < tostring(bestEntry.displayName or ''))
            then
                bestId, bestEntry = vehicleId, entry
            end
        end
    end

    if bestId then
        document.garage.activeVehicleId = bestId
        return bestId, bestEntry, nil
    end

    return nil, nil, 'no_vehicle'
end


exports('AdminAwardPlayerXp', function(target, amount, ownerOverride)
    target = ceAdminNormalizeTarget(target)
    amount = tonumber(amount)
    if not target or target <= 0 then return nil, 'invalid_target' end
    if not amount or amount <= 0 then return nil, 'invalid_amount' end

    local ensured, ensureReason = ceAdminLoadLastSaveIntoMemory(target, ownerOverride)
    if not ensured then return nil, ensureReason or 'ensure_failed' end

    local document = activeDocuments[target]
    local saveId = activeSaves[target]
    local owner = ceAdminNormalizeOwner(ownerOverride) or ownerLicense(target)
    if not document or not saveId or not owner then return nil, 'missing_active_document' end

    document.progression = type(document.progression) == 'table' and document.progression or {}
    local progression = document.progression
    local oldXp = tonumber(progression.playerXp) or 0
    local oldLevel = tonumber(progression.level) or 1
    local thresholds = (SKProgression and SKProgression.PLAYER_LEVEL_THRESHOLDS) or { [1] = 0 }
    local maxLevel = (SKProgression and SKProgression.PLAYER_MAX_LEVEL) or 50
    local maxXp = tonumber(thresholds[maxLevel]) or (oldXp + math.floor(amount))
    local newXp = math.min(oldXp + math.floor(amount), maxXp)

    local newLevel = oldLevel
    if SKProgression and SKProgression.getPlayerLevelFromXp then
        newLevel = SKProgression.getPlayerLevelFromXp(newXp)
    else
        for lvl = 1, maxLevel do
            local need = tonumber(thresholds[lvl])
            if need and newXp >= need then newLevel = lvl end
        end
    end

    progression.playerXp = newXp
    progression.level = newLevel
    document.progression = progression

    local written = dbWriteSave(owner, saveId, document)
    if not written or not written.ok then return nil, written and written.error or 'write_failed' end

    return {
        xpGained = newXp - oldXp,
        oldLevel = oldLevel,
        newLevel = newLevel,
        saveId = saveId,
        via = 'ce_skadmin_bridge',
    }
end)

exports('AdminAwardVehicleXp', function(target, amount, ownerOverride)
    target = ceAdminNormalizeTarget(target)
    amount = tonumber(amount)
    if not target or target <= 0 then
        return nil, 'invalid_target'
    end
    if not amount or amount <= 0 then
        return nil, 'invalid_amount'
    end

    local ensured, ensureReason = ceAdminLoadLastSaveIntoMemory(target, ownerOverride)
    if not ensured then
        return nil, ensureReason or 'ensure_failed'
    end

    local document = activeDocuments[target]
    local saveId = activeSaves[target]
    local owner = ceAdminNormalizeOwner(ownerOverride) or ownerLicense(target)
    if not document or not saveId or not owner then
        return nil, 'missing_active_document'
    end

    local vehicleId, entry, vehReason = ceAdminResolveActiveVehicle(document)
    if not vehicleId or not entry then
        return nil, vehReason or 'no_active_vehicle'
    end

    entry.data = type(entry.data) == 'table' and entry.data or {}

    -- Usa la progresión real del framework si está disponible.
    if not SKProgression or not SKProgression.ensureVehicleData then
        return nil, 'progression_not_ready'
    end

    local vehicleData = SKProgression.ensureVehicleData(entry.data)
    local oldXp = tonumber(vehicleData.xp) or 0
    local oldLevel = tonumber(vehicleData.level) or 1
    local thresholds = SKProgression.VEHICLE_LEVEL_THRESHOLDS or {}
    local maxLevel = SKProgression.VEHICLE_MAX_LEVEL or 10
    local maxXp = tonumber(thresholds[maxLevel]) or oldXp
    local newXp = math.min(oldXp + math.floor(amount), maxXp)

    if newXp <= oldXp then
        return {
            xpGained = 0,
            oldLevel = oldLevel,
            newLevel = oldLevel,
            unlocks = {},
            vehicleId = vehicleId,
            reason = 'already_max_or_no_gain',
        }
    end

    vehicleData.xp = newXp
    vehicleData.level = SKProgression.getVehicleLevelFromXp(newXp)
    vehicleData.unlocks = type(vehicleData.unlocks) == 'table' and vehicleData.unlocks or {}
    vehicleData.unlockSchedule = type(vehicleData.unlockSchedule) == 'table' and vehicleData.unlockSchedule or {}

    local unlocked = {}
    for _, unlock in ipairs(vehicleData.unlockSchedule) do
        if unlock.level <= vehicleData.level then
            if not vehicleData.unlocks[unlock.key] and unlock.level > oldLevel then
                unlocked[#unlocked + 1] = unlock
            end
            vehicleData.unlocks[unlock.key] = true
        end
    end

    entry.data = vehicleData
    document.garage.vehicles[vehicleId] = entry
    document.garage.activeVehicleId = vehicleId

    local written = dbWriteSave(owner, saveId, document)
    if not written or not written.ok then
        return nil, written and written.error or 'write_failed'
    end

    return {
        xpGained = newXp - oldXp,
        oldLevel = oldLevel,
        newLevel = vehicleData.level,
        unlocks = unlocked,
        vehicleId = vehicleId,
        saveId = saveId,
        via = 'ce_skadmin_bridge',
    }
end)

-- ce_skadmin garage bridge v13 -------------------------------------------------
local function ceAdminRandomColor()
    local colors = {
        { r = 220, g = 30, b = 30 }, { r = 220, g = 100, b = 20 }, { r = 210, g = 190, b = 20 },
        { r = 30, g = 180, b = 50 }, { r = 20, g = 120, b = 220 }, { r = 100, g = 30, b = 220 },
        { r = 210, g = 30, b = 140 }, { r = 220, g = 220, b = 220 }, { r = 25, g = 25, b = 25 },
        { r = 120, g = 120, b = 120 }, { r = 180, g = 140, b = 60 }, { r = 30, g = 180, b = 180 },
    }
    return colors[math.random(#colors)]
end

local function ceAdminCountGarageVehicles(document)
    local count = 0
    if document and document.garage and type(document.garage.vehicles) == 'table' then
        for _ in pairs(document.garage.vehicles) do count = count + 1 end
    end
    return count
end

local function ceAdminFindCatalogVehicle(model)
    model = tostring(model or ''):lower()
    if model == '' then return nil end
    if SKStarterVehicles then
        for _, v in ipairs(SKStarterVehicles) do
            if v.model == model then
                return { model = model, displayName = v.displayName, brand = v.brand, vehicleType = v.vehicleType or 'automobile', price = v.value or 0, class = v.class or 'STARTER', source = 'starter' }
            end
        end
    end
    if SKGameVehicles then
        for category, vehicles in pairs(SKGameVehicles) do
            for _, v in ipairs(vehicles) do
                if v.model == model then
                    local shared = SKVehicles and SKVehicles[model] or nil
                    return { model = model, displayName = shared and shared.name or model, brand = shared and shared.brand or '', vehicleType = shared and shared.type or 'automobile', price = v.price or 0, class = v.class or 'C', source = category }
                end
            end
        end
    end
    local shared = SKVehicles and SKVehicles[model] or nil
    if shared then
        return { model = model, displayName = shared.name or model, brand = shared.brand or '', vehicleType = shared.type or 'automobile', price = shared.price or 0, class = '', source = shared.category or 'custom' }
    end
    return nil
end

local function ceAdminSaveDocument(target, owner, saveId, document)
    activeDocuments[target] = document
    activeSaves[target] = saveId
    local written = dbWriteSave(owner, saveId, document)
    if not written or not written.ok then
        return false, written and written.error or 'write_failed'
    end
    return true
end

local function ceAdminGarageSetVehicleLevel(entry, targetLevel)
    if not SKProgression or not SKProgression.ensureVehicleData then return false, 'progression_not_ready' end
    targetLevel = math.max(1, math.min(math.floor(tonumber(targetLevel) or 1), SKProgression.VEHICLE_MAX_LEVEL or 10))
    entry.data = SKProgression.ensureVehicleData(type(entry.data) == 'table' and entry.data or {})
    local thresholds = SKProgression.VEHICLE_LEVEL_THRESHOLDS or { [1] = 0 }
    entry.data.xp = tonumber(thresholds[targetLevel]) or 0
    entry.data.level = targetLevel
    entry.data.unlocks = {}
    entry.data.unlockSchedule = type(entry.data.unlockSchedule) == 'table' and entry.data.unlockSchedule or {}
    for _, unlock in ipairs(entry.data.unlockSchedule) do
        if tonumber(unlock.level) and unlock.level <= targetLevel and unlock.key then
            entry.data.unlocks[unlock.key] = true
        end
    end
    return true, entry.data
end


local CE_ADMIN_PERFORMANCE_MOD_TYPES = { [11]=true, [12]=true, [13]=true, [15]=true, [18]=true, [22]=true, [51]=true }

local function ceAdminGetModKey(modType, modIndex)
    modType = tonumber(modType); modIndex = tonumber(modIndex)
    if not modType or not modIndex or modIndex < 0 then return nil end
    return tostring(modType) .. ':' .. tostring(modIndex)
end

local function ceAdminEnsureVehicleModData(entry)
    entry.data = SKProgression.ensureVehicleData(type(entry.data) == 'table' and entry.data or {})
    entry.data.mods = type(entry.data.mods) == 'table' and entry.data.mods or {}
    entry.data.unlocks = type(entry.data.unlocks) == 'table' and entry.data.unlocks or {}
    entry.data.availableMods = type(entry.data.availableMods) == 'table' and entry.data.availableMods or {}
    entry.data.unlockSchedule = type(entry.data.unlockSchedule) == 'table' and entry.data.unlockSchedule or {}
    return entry.data
end

local function ceAdminFindAvailableOption(vehicleData, modType, modIndex)
    modType = tonumber(modType); modIndex = tonumber(modIndex)
    if not modType or not modIndex then return nil end
    if modIndex == -1 then return { index = -1, name = 'Stock' } end
    for _, group in ipairs(vehicleData.availableMods or {}) do
        if tonumber(group.modType) == modType then
            for _, opt in ipairs(group.options or {}) do
                if tonumber(opt.index or opt.modIndex) == modIndex then return opt end
            end
        end
    end
    return nil
end


-- Importante: StreetKings vuelve a reconstruir unlocks desde el nivel del coche
-- al sincronizar availableMods. Si un admin desbloquea una pieza de nivel alto
-- pero el coche queda LV1, el core la borra pocos segundos después. Por eso
-- todo desbloqueo/aplicación admin sube también el nivel mínimo requerido.
local function ceAdminGetModRequiredLevel(vehicleData, modType, modIndex)
    modType = tonumber(modType); modIndex = tonumber(modIndex)
    if not modType or not modIndex or modIndex < 0 then return 1 end
    local opt = ceAdminFindAvailableOption(vehicleData, modType, modIndex)
    local key = (type(opt) == 'table' and opt.key) or ceAdminGetModKey(modType, modIndex)
    for _, unlock in ipairs(vehicleData.unlockSchedule or {}) do
        if (key and unlock.key == key)
            or (tonumber(unlock.modType) == modType and tonumber(unlock.modIndex) == modIndex)
        then
            return tonumber(unlock.level) or 1
        end
    end
    return 1
end

local function ceAdminRaiseVehicleToUnlockLevel(vehicleData, requiredLevel)
    requiredLevel = math.floor(tonumber(requiredLevel) or 1)
    if requiredLevel <= 1 then return end
    local maxLevel = tonumber(SKProgression.VEHICLE_MAX_LEVEL) or 10
    requiredLevel = math.max(1, math.min(requiredLevel, maxLevel))
    local currentLevel = tonumber(vehicleData.level) or 1
    if currentLevel < requiredLevel then
        vehicleData.level = requiredLevel
        local thresholds = SKProgression.VEHICLE_LEVEL_THRESHOLDS or {}
        vehicleData.xp = math.max(tonumber(vehicleData.xp) or 0, tonumber(thresholds[requiredLevel]) or 0)
    end
    vehicleData.unlocks = type(vehicleData.unlocks) == 'table' and vehicleData.unlocks or {}
    for _, unlock in ipairs(vehicleData.unlockSchedule or {}) do
        if unlock.key and tonumber(unlock.level) and unlock.level <= (tonumber(vehicleData.level) or requiredLevel) then
            vehicleData.unlocks[unlock.key] = true
        end
    end
end

local function ceAdminApplyVehicleMod(entry, modType, modIndex, forceUnlock)
    local vehicleData = ceAdminEnsureVehicleModData(entry)
    modType = tonumber(modType); modIndex = tonumber(modIndex)
    if not modType or not modIndex then return false, 'invalid_mod' end
    if modIndex ~= -1 and not ceAdminFindAvailableOption(vehicleData, modType, modIndex) then
        return false, 'mod_not_available'
    end
    if modIndex >= 0 then
        local opt = ceAdminFindAvailableOption(vehicleData, modType, modIndex)
        local key = (type(opt) == 'table' and opt.key) or ceAdminGetModKey(modType, modIndex)
        local requiredLevel = ceAdminGetModRequiredLevel(vehicleData, modType, modIndex)
        if forceUnlock then
            if key then vehicleData.unlocks[key] = true end
            ceAdminRaiseVehicleToUnlockLevel(vehicleData, requiredLevel)
        end
        if key and not vehicleData.unlocks[key] and not forceUnlock then return false, 'locked' end
        vehicleData.mods[tostring(modType)] = modIndex
    else
        vehicleData.mods[tostring(modType)] = -1
    end
    return true, vehicleData
end

local function ceAdminUnlockVehicleMod(entry, modType, modIndex)
    local vehicleData = ceAdminEnsureVehicleModData(entry)
    modType = tonumber(modType); modIndex = tonumber(modIndex)
    if not modType then return false, 'invalid_mod' end
    if modIndex and modIndex >= 0 then
        local opt = ceAdminFindAvailableOption(vehicleData, modType, modIndex)
        if not opt then return false, 'mod_not_available' end
        local key = opt.key or ceAdminGetModKey(modType, modIndex)
        if key then vehicleData.unlocks[key] = true end
        ceAdminRaiseVehicleToUnlockLevel(vehicleData, ceAdminGetModRequiredLevel(vehicleData, modType, modIndex))
        return true, vehicleData
    end
    local maxRequired = 1
    for _, group in ipairs(vehicleData.availableMods or {}) do
        if tonumber(group.modType) == modType then
            for _, opt in ipairs(group.options or {}) do
                local idx = tonumber(opt.index or opt.modIndex)
                local key = opt.key or ceAdminGetModKey(modType, idx)
                if key then vehicleData.unlocks[key] = true end
                maxRequired = math.max(maxRequired, ceAdminGetModRequiredLevel(vehicleData, modType, idx))
            end
        end
    end
    ceAdminRaiseVehicleToUnlockLevel(vehicleData, maxRequired)
    return true, vehicleData
end

local function ceAdminUnlockAllVehicleMods(entry)
    local vehicleData = ceAdminEnsureVehicleModData(entry)
    ceAdminRaiseVehicleToUnlockLevel(vehicleData, SKProgression.VEHICLE_MAX_LEVEL or 10)
    for _, unlock in ipairs(vehicleData.unlockSchedule or {}) do
        if unlock.key then vehicleData.unlocks[unlock.key] = true end
    end
    for _, group in ipairs(vehicleData.availableMods or {}) do
        for _, opt in ipairs(group.options or {}) do
            local idx = tonumber(opt.index or opt.modIndex)
            local key = opt.key or ceAdminGetModKey(group.modType, idx)
            if key then vehicleData.unlocks[key] = true end
        end
    end
    return true, vehicleData
end

local function ceAdminResetVehicleMods(entry)
    local vehicleData = ceAdminEnsureVehicleModData(entry)
    vehicleData.mods = {}
    return true, vehicleData
end

local function ceAdminMaxPerformance(entry)
    local vehicleData = ceAdminEnsureVehicleModData(entry)
    local maxRequired = 1
    for _, group in ipairs(vehicleData.availableMods or {}) do
        local modType = tonumber(group.modType)
        if modType and CE_ADMIN_PERFORMANCE_MOD_TYPES[modType] then
            local best = nil
            for _, opt in ipairs(group.options or {}) do
                local idx = tonumber(opt.index or opt.modIndex)
                if idx and idx >= 0 and (not best or idx > best.index) then
                    best = { index = idx, key = opt.key or ceAdminGetModKey(modType, idx) }
                end
            end
            if best then
                if best.key then vehicleData.unlocks[best.key] = true end
                maxRequired = math.max(maxRequired, ceAdminGetModRequiredLevel(vehicleData, modType, best.index))
                vehicleData.mods[tostring(modType)] = best.index
            end
        end
    end
    ceAdminRaiseVehicleToUnlockLevel(vehicleData, maxRequired)
    return true, vehicleData
end

exports('AdminGarageAction', function(target, action, payload, ownerOverride)
    target = ceAdminNormalizeTarget(target)
    payload = type(payload) == 'table' and payload or {}
    action = tostring(action or '')
    if not target or target <= 0 then return { ok = false, reason = 'invalid_target' } end

    local ensured, ensureReason, saveId = ceAdminLoadLastSaveIntoMemory(target, ownerOverride)
    if not ensured then return { ok = false, reason = ensureReason or 'ensure_failed' } end

    local document = activeDocuments[target]
    saveId = activeSaves[target] or saveId
    local owner = ceAdminNormalizeOwner(ownerOverride) or ownerLicense(target)
    if not document or not saveId or not owner then return { ok = false, reason = 'missing_active_document' } end

    document.garage = type(document.garage) == 'table' and document.garage or {}
    document.garage.vehicles = type(document.garage.vehicles) == 'table' and document.garage.vehicles or {}

    if action == 'addVehicle' then
        local model = tostring(payload.model or ''):lower()
        local catalog = ceAdminFindCatalogVehicle(model)
        if not catalog then return { ok = false, reason = 'invalid_model' } end
        local vehicleId = lib.string.random('........^-....^-....^-....^-............')
        local vehicleCount = ceAdminCountGarageVehicles(document)
        local vehicleData = SKProgression.newVehicleData(catalog.vehicleType or 'automobile')
        vehicleData.colors.primary = ceAdminRandomColor()
        vehicleData.colors.secondary = ceAdminRandomColor()
        document.garage.vehicles[vehicleId] = {
            id = vehicleId,
            modelName = model,
            displayName = catalog.displayName or model,
            sortIndex = vehicleCount,
            plate = SKVehiclePlate.generate(),
            data = vehicleData,
        }
        if type(document.garage.activeVehicleId) ~= 'string' or document.garage.activeVehicleId == '' then
            document.garage.activeVehicleId = vehicleId
        end
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        TriggerEvent('streetkings:messages:trigger', target, 'vehicleAcquired', { acquisitionSource = 'admin', vehicleId = vehicleId, modelName = model, isFirstVehicle = vehicleCount == 0 })
        return { ok = true, action = action, vehicleId = vehicleId, model = model, displayName = catalog.displayName }
    end

    local vehicleId = tostring(payload.vehicleId or '')
    if vehicleId == '' or type(document.garage.vehicles[vehicleId]) ~= 'table' then return { ok = false, reason = 'vehicle_not_found' } end
    local entry = document.garage.vehicles[vehicleId]

    if action == 'deleteVehicle' then
        local model = entry.modelName
        document.garage.vehicles[vehicleId] = nil
        if document.garage.activeVehicleId == vehicleId then
            document.garage.activeVehicleId = nil
            local bestId, bestEntry
            for id, e in pairs(document.garage.vehicles) do
                if not bestEntry or (tonumber(e.sortIndex) or 9999) < (tonumber(bestEntry.sortIndex) or 9999) then
                    bestId, bestEntry = id, e
                end
            end
            document.garage.activeVehicleId = bestId
        end
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId, model = model }
    elseif action == 'setActive' then
        document.garage.activeVehicleId = vehicleId
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId }
    elseif action == 'addVehicleXp' then
        local amount = tonumber(payload.amount) or 0
        if amount <= 0 then return { ok = false, reason = 'invalid_amount' } end
        entry.data = SKProgression.ensureVehicleData(type(entry.data) == 'table' and entry.data or {})
        local oldXp = tonumber(entry.data.xp) or 0
        local oldLevel = tonumber(entry.data.level) or 1
        local thresholds = SKProgression.VEHICLE_LEVEL_THRESHOLDS or {}
        local maxLevel = SKProgression.VEHICLE_MAX_LEVEL or 10
        local maxXp = tonumber(thresholds[maxLevel]) or oldXp
        local newXp = math.min(oldXp + math.floor(amount), maxXp)
        entry.data.xp = newXp
        entry.data.level = SKProgression.getVehicleLevelFromXp(newXp)
        entry.data.unlocks = type(entry.data.unlocks) == 'table' and entry.data.unlocks or {}
        entry.data.unlockSchedule = type(entry.data.unlockSchedule) == 'table' and entry.data.unlockSchedule or {}
        local unlocked = {}
        for _, unlock in ipairs(entry.data.unlockSchedule) do
            if unlock.key and unlock.level and unlock.level <= entry.data.level then
                if not entry.data.unlocks[unlock.key] and unlock.level > oldLevel then unlocked[#unlocked + 1] = unlock end
                entry.data.unlocks[unlock.key] = true
            end
        end
        document.garage.vehicles[vehicleId] = entry
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId, xpGained = newXp - oldXp, oldLevel = oldLevel, newLevel = entry.data.level, unlocks = unlocked }
    elseif action == 'setVehicleLevel' then
        local okLevel, dataOrReason = ceAdminGarageSetVehicleLevel(entry, payload.level)
        if not okLevel then return { ok = false, reason = dataOrReason } end
        document.garage.vehicles[vehicleId] = entry
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId, newLevel = entry.data.level, xp = entry.data.xp }
    elseif action == 'applyMod' then
        local okApply, reasonOrData = ceAdminApplyVehicleMod(entry, payload.modType, payload.modIndex, payload.forceUnlock == true)
        if not okApply then return { ok = false, reason = reasonOrData } end
        document.garage.vehicles[vehicleId] = entry
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId, modType = payload.modType, modIndex = payload.modIndex }
    elseif action == 'removeMod' then
        local okApply, reasonOrData = ceAdminApplyVehicleMod(entry, payload.modType, -1, true)
        if not okApply then return { ok = false, reason = reasonOrData } end
        document.garage.vehicles[vehicleId] = entry
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId, modType = payload.modType, modIndex = -1 }
    elseif action == 'unlockMod' then
        local okUnlock, reasonOrData = ceAdminUnlockVehicleMod(entry, payload.modType, payload.modIndex)
        if not okUnlock then return { ok = false, reason = reasonOrData } end
        document.garage.vehicles[vehicleId] = entry
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId, modType = payload.modType, modIndex = payload.modIndex }
    elseif action == 'unlockAllMods' then
        ceAdminUnlockAllVehicleMods(entry)
        document.garage.vehicles[vehicleId] = entry
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId }
    elseif action == 'resetMods' then
        ceAdminResetVehicleMods(entry)
        document.garage.vehicles[vehicleId] = entry
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId }
    elseif action == 'maxPerformance' then
        ceAdminMaxPerformance(entry)
        document.garage.vehicles[vehicleId] = entry
        local ok, writeReason = ceAdminSaveDocument(target, owner, saveId, document)
        if not ok then return { ok = false, reason = writeReason } end
        return { ok = true, action = action, vehicleId = vehicleId }
    end

    return { ok = false, reason = 'unknown_action' }
end)


-- ce_skadmin bridge: respawnea en vivo el vehículo activo para que, al usar
-- "Hacer activo" desde el panel admin, el jugador cambie de coche al momento.
exports('AdminRespawnActiveVehicle', function(target, ownerOverride)
    target = ceAdminNormalizeTarget(target)
    if not target or target <= 0 then return { ok = false, reason = 'invalid_target' } end

    local ensured, ensureReason = ceAdminLoadLastSaveIntoMemory(target, ownerOverride)
    if not ensured then return { ok = false, reason = ensureReason or 'ensure_failed' } end

    local document = activeDocuments[target]
    local owner = ceAdminNormalizeOwner(ownerOverride) or ownerLicense(target)
    if not document or not owner then return { ok = false, reason = 'missing_active_document' } end
    if type(document.garage) ~= 'table' or type(document.garage.vehicles) ~= 'table' then
        return { ok = false, reason = 'missing_garage' }
    end

    local vehicleId = document.garage.activeVehicleId
    if type(vehicleId) ~= 'string' or vehicleId == '' or not document.garage.vehicles[vehicleId] then
        return { ok = false, reason = 'no_active_vehicle' }
    end

    if not SKFreeroamServer or type(SKFreeroamServer.spawnPlayerVehicleInBucket) ~= 'function' then
        return { ok = false, reason = 'freeroam_bridge_missing' }
    end

    local ped = GetPlayerPed(target)
    if not ped or ped == 0 then return { ok = false, reason = 'no_ped' } end
    local coords = GetEntityCoords(ped)
    if not coords then return { ok = false, reason = 'no_coords' } end
    local heading = GetEntityHeading(ped) or 0.0
    local bucket = GetPlayerRoutingBucket(target) or 0

    -- Usa el spawner oficial del core: borra el asignado anterior, crea el nuevo activo
    -- con placa y tipo correcto, y después adoptamos el netId en freeroam.
    local netId = SKFreeroamServer.spawnPlayerVehicleInBucket(target, coords.x, coords.y, coords.z, heading, bucket)
    if type(netId) ~= 'number' then return { ok = false, reason = 'spawn_failed' } end

    if type(SKFreeroamServer.adoptAssignedVehicle) == 'function' then
        SKFreeroamServer.adoptAssignedVehicle(target, netId)
    end

    TriggerClientEvent('streetkings:admin:activeVehicleRespawned', target, netId)
    return { ok = true, netId = netId, vehicleId = vehicleId }
end)
