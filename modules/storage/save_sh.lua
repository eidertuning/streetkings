---@class SKSaveSlotDto
---@field slotIndex integer
---@field occupied boolean
---@field id string
---@field name string
---@field detail string

---@class SKLastPlayedSaveDto
---@field save SKSaveSlotDto|nil

---@class SKSaveProfileDocument
---@field alias string

---@class SKSaveProgressionDocument
---@field level integer
---@field playerXp integer
---@field bestActivityScores table<string, integer>
---@field tutorialCompleted boolean
---@field tutorialPhoneSent boolean

---@class SKSaveEconomyDocument
---@field cash integer

---@class SKSaveStatsDocument
---@field totalMilesDriven number
---@field topSpeedMph number
---@field totalCashEarned integer
---@field totalCashSpent integer
---@field racesCompleted integer
---@field racesWon integer
---@field npcChallengesWon integer
---@field rampagesCompleted integer
---@field stuntJumpsCompleted integer
---@field speedCameraFlashes integer
---@field policeBusts integer
---@field policeEscapes integer
---@field totalRepairs integer
---@field clothingPurchased integer

---@class SKSavePropertiesDocument
---@field owned table<string, boolean>

---@class SKSaveEventStateDocument
---@field dayKey string
---@field claimedRewards table<string, boolean>
---@field lastSeenPlaylist string

---@class SKGarageVehicleSaveDocument
---@field id string
---@field modelName string
---@field displayName string
---@field sortIndex integer
---@field plate string
---@field data table

---@class SKGarageSaveDocument
---@field activeVehicleId string
---@field vehicles table<string, SKGarageVehicleSaveDocument>

---@class SKSaveMissionsDocument
---@field chapter integer
---@field chapterMissionIndex integer
---@field currentMissionId string|nil
---@field currentObjectiveIndex integer
---@field completed table<string, integer>
---@field nextAvailableAt integer
---@field lastCompletedAt integer
---@field flags table<string, any>

---@class SKSaveDocument
---@field profile SKSaveProfileDocument
---@field progression SKSaveProgressionDocument
---@field garage SKGarageSaveDocument
---@field economy SKSaveEconomyDocument
---@field stats SKSaveStatsDocument
---@field properties SKSavePropertiesDocument
---@field missions SKSaveMissionsDocument
---@field world { state: table }
---@field meta { data: { events: SKSaveEventStateDocument } }

SKSaves = {
    SLOT_COUNT = 3,
    SLOTS_VERSION = 2,
    SCHEMA_VERSION = 6,
    Error = {
        DB_NOT_READY = 'db_not_ready',
        NO_LICENSE = 'no_license',
        INVALID_SLOT = 'invalid_slot',
        SLOT_OCCUPIED = 'slot_occupied',
        SAVE_NOT_FOUND = 'save_not_found',
        NO_ACTIVE_SAVE = 'no_active_save',
        NO_ACTIVE_DOCUMENT = 'no_active_document',
        INSERT_FAILED = 'insert_failed',
        INVALID_DOCUMENT = 'invalid_document',
        INVALID_KEY = 'invalid_key',
    },
}

---@param slotIndex integer
---@return boolean
function SKSaves.isValidSlot(slotIndex)
    return type(slotIndex) == 'number' and slotIndex >= 1 and slotIndex <= SKSaves.SLOT_COUNT
end

---@param slotIndex integer
---@return SKSaveSlotDto
function SKSaves.emptySlot(slotIndex)
    return { slotIndex = slotIndex, occupied = false, id = '', name = '', detail = '' }
end

---@return SKSaveSlotDto[]
function SKSaves.emptySlots()
    local slots = {}
    for i = 1, SKSaves.SLOT_COUNT do
        slots[i] = SKSaves.emptySlot(i)
    end
    return slots
end

---@return SKSaveStatsDocument
function SKSaves.defaultStats()
    return {
        totalMilesDriven    = 0.0,
        topSpeedMph         = 0.0,
        totalCashEarned     = 0,
        totalCashSpent      = 0,
        racesCompleted      = 0,
        racesWon            = 0,
        npcChallengesWon    = 0,
        rampagesCompleted   = 0,
        stuntJumpsCompleted = 0,
        speedCameraFlashes  = 0,
        policeBusts         = 0,
        policeEscapes       = 0,
        totalRepairs        = 0,
        clothingPurchased   = 0,
    }
end

---@return SKSaveMissionsDocument
function SKSaves.defaultMissions()
    return {
        chapter = 0,
        chapterMissionIndex = 0,
        currentMissionId = nil,
        currentObjectiveIndex = 0,
        completed = {},
        nextAvailableAt = 0,
        lastCompletedAt = 0,
        flags = {},
    }
end

---@return SKSaveDocument
function SKSaves.newDocument()
    return {
        profile = { alias = '' },
        progression = { level = 1, playerXp = 0, bestActivityScores = {}, tutorialCompleted = false },
        garage = { activeVehicleId = '', vehicles = {} },
        economy = { cash = 5000 },
        stats = SKSaves.defaultStats(),
        properties = { owned = {} },
        missions = SKSaves.defaultMissions(),
        world = { state = {} },
        meta = {
            data = {
                events = {
                    dayKey = '',
                    claimedRewards = {},
                    lastSeenPlaylist = '',
                },
            },
        },
    }
end

---@param value any
---@param name string
local function requireNonNegativeInt(value, name)
    if type(value) ~= 'number' or value < 0 or value % 1 ~= 0 then
        error(('streetkings: invalid save field "%s"'):format(name))
    end
end

---@param value any
---@return boolean
local function isValidVehicleNeons(value)
    if type(value) ~= 'table' or value.enabled ~= true then
        return false
    end
    if type(value.color) ~= 'table'
        or type(value.color.r) ~= 'number'
        or type(value.color.g) ~= 'number'
        or type(value.color.b) ~= 'number'
    then
        return false
    end
    if type(value.sides) ~= 'table'
        or type(value.sides.front) ~= 'boolean'
        or type(value.sides.back) ~= 'boolean'
        or type(value.sides.left) ~= 'boolean'
        or type(value.sides.right) ~= 'boolean'
    then
        return false
    end

    return true
end

---@param vehicleData table
---@return table
local function normalizeVehicleData(vehicleData)
    if type(vehicleData.xp) ~= 'number' or vehicleData.xp < 0 or vehicleData.xp % 1 ~= 0 then
        vehicleData.xp = 0
    end
    if type(vehicleData.level) ~= 'number' or vehicleData.level < 1 or vehicleData.level % 1 ~= 0 then
        vehicleData.level = 1
    end
    if type(vehicleData.availableMods) ~= 'table' then
        vehicleData.availableMods = {}
    end
    if type(vehicleData.unlockSchedule) ~= 'table' then
        vehicleData.unlockSchedule = {}
    end
    if type(vehicleData.unlocks) ~= 'table' then
        vehicleData.unlocks = {}
    end
    if type(vehicleData.bestActivityScores) ~= 'table' then
        vehicleData.bestActivityScores = {}
    end
    if type(vehicleData.mods) ~= 'table' then
        vehicleData.mods = {}
    end
    if type(vehicleData.colors) ~= 'table' then
        vehicleData.colors = {}
    end
    if vehicleData.neons ~= nil and not isValidVehicleNeons(vehicleData.neons) then
        vehicleData.neons = nil
    end
    return vehicleData
end

---@param document table
---@return table
local function normalizeDocument(document)
    if type(document.progression) ~= 'table' then
        document.progression = {}
    end
    if type(document.progression.playerXp) ~= 'number' then
        document.progression.playerXp = document.progression.rep or 0
    end
    document.progression.rep = nil
    if type(document.progression.bestActivityScores) ~= 'table' then
        document.progression.bestActivityScores = {}
    end

    if type(document.garage) == 'table' and type(document.garage.vehicles) == 'table' then
        for _, vehicle in pairs(document.garage.vehicles) do
            if type(vehicle) == 'table' and type(vehicle.data) == 'table' then
                normalizeVehicleData(vehicle.data)
                if type(vehicle.plate) ~= 'string' then
                    vehicle.plate = SKVehiclePlate.generate()
                end
            end
        end
    end

    if type(document.economy) == 'table' then
        document.economy.bank = nil
    end

    if type(document.stats) ~= 'table' then
        document.stats = SKSaves.defaultStats()
    else
        local defaults = SKSaves.defaultStats()
        for k, v in pairs(defaults) do
            if document.stats[k] == nil then
                document.stats[k] = v
            end
        end
    end

    if type(document.meta) ~= 'table' then
        document.meta = {}
    end
    if type(document.properties) ~= 'table' then
        document.properties = {}
    end
    if type(document.properties.owned) ~= 'table' then
        document.properties.owned = {}
    end

    if type(document.missions) ~= 'table' then
        document.missions = SKSaves.defaultMissions()
    else
        local defaults = SKSaves.defaultMissions()
        for k, v in pairs(defaults) do
            if document.missions[k] == nil then
                document.missions[k] = v
            end
        end
        if type(document.missions.completed) ~= 'table' then
            document.missions.completed = {}
        end
        if type(document.missions.flags) ~= 'table' then
            document.missions.flags = {}
        end
    end
    if type(document.meta.data) ~= 'table' then
        document.meta.data = {}
    end
    if type(document.meta.data.events) ~= 'table' then
        document.meta.data.events = {}
    end
    if type(document.meta.data.events.dayKey) ~= 'string' then
        document.meta.data.events.dayKey = ''
    end
    if type(document.meta.data.events.claimedRewards) ~= 'table' then
        document.meta.data.events.claimedRewards = {}
    end
    if type(document.meta.data.events.lastSeenPlaylist) ~= 'string' then
        document.meta.data.events.lastSeenPlaylist = ''
    end

    return document
end

---@param document table
---@return SKSaveDocument
function SKSaves.validateDocument(document)
    normalizeDocument(document)
    assert(type(document) == 'table', 'streetkings: invalid save document')
    assert(type(document.profile) == 'table' and type(document.profile.alias) == 'string', 'streetkings: invalid save document profile')
    assert(type(document.progression) == 'table', 'streetkings: invalid save document progression')
    requireNonNegativeInt(document.progression.level, 'progression.level')
    requireNonNegativeInt(document.progression.playerXp, 'progression.playerXp')
    assert(type(document.progression.bestActivityScores) == 'table', 'streetkings: invalid save document progression.bestActivityScores')
    assert(type(document.garage) == 'table' and type(document.garage.activeVehicleId) == 'string' and type(document.garage.vehicles) == 'table', 'streetkings: invalid save document garage')
    for vehicleId, v in pairs(document.garage.vehicles) do
        assert(type(vehicleId) == 'string' and vehicleId ~= '' and type(v) == 'table' and v.id == vehicleId and type(v.modelName) == 'string' and type(v.displayName) == 'string' and type(v.plate) == 'string' and type(v.data) == 'table', 'streetkings: invalid save document vehicle')
        requireNonNegativeInt(v.sortIndex, 'garage.vehicle.sortIndex')
        requireNonNegativeInt(v.data.xp, 'garage.vehicle.data.xp')
        requireNonNegativeInt(v.data.level, 'garage.vehicle.data.level')
        assert(type(v.data.availableMods) == 'table', 'streetkings: invalid save document vehicle.availableMods')
        assert(type(v.data.unlockSchedule) == 'table', 'streetkings: invalid save document vehicle.unlockSchedule')
        assert(type(v.data.unlocks) == 'table', 'streetkings: invalid save document vehicle.unlocks')
        assert(type(v.data.bestActivityScores) == 'table', 'streetkings: invalid save document vehicle.bestActivityScores')
        assert(type(v.data.mods) == 'table', 'streetkings: invalid save document vehicle.mods')
        assert(type(v.data.colors) == 'table', 'streetkings: invalid save document vehicle.colors')
        assert(v.data.neons == nil or isValidVehicleNeons(v.data.neons), 'streetkings: invalid save document vehicle.neons')
    end
    assert(type(document.economy) == 'table', 'streetkings: invalid save document economy')
    requireNonNegativeInt(document.economy.cash, 'economy.cash')
    assert(type(document.stats) == 'table', 'streetkings: invalid save document stats')
    assert(type(document.properties) == 'table' and type(document.properties.owned) == 'table', 'streetkings: invalid save document properties')
    for propertyId, owned in pairs(document.properties.owned) do
        assert(type(propertyId) == 'string' and propertyId ~= '' and type(owned) == 'boolean', 'streetkings: invalid save document owned property')
    end
    assert(type(document.world) == 'table' and type(document.world.state) == 'table', 'streetkings: invalid save document world')
    assert(type(document.meta) == 'table' and type(document.meta.data) == 'table', 'streetkings: invalid save document meta')
    assert(type(document.missions) == 'table', 'streetkings: invalid save document missions')
    requireNonNegativeInt(document.missions.chapter, 'missions.chapter')
    requireNonNegativeInt(document.missions.chapterMissionIndex, 'missions.chapterMissionIndex')
    requireNonNegativeInt(document.missions.currentObjectiveIndex, 'missions.currentObjectiveIndex')
    requireNonNegativeInt(document.missions.nextAvailableAt, 'missions.nextAvailableAt')
    requireNonNegativeInt(document.missions.lastCompletedAt, 'missions.lastCompletedAt')
    assert(type(document.missions.completed) == 'table', 'streetkings: invalid save document missions.completed')
    assert(type(document.missions.flags) == 'table', 'streetkings: invalid save document missions.flags')
    return document
end

---@param document SKSaveDocument
---@return string
function SKSaves.encodeDocument(document)
    return json.encode(SKSaves.validateDocument(document))
end

---@param raw string
---@param version integer
---@return SKSaveDocument
function SKSaves.decodeDocument(raw, version)
    assert(version >= 1 and version <= SKSaves.SCHEMA_VERSION, ('streetkings: unsupported save schema version %s'):format(version))
    local document = json.decode(raw)
    if version < SKSaves.SCHEMA_VERSION then
        normalizeDocument(document)
    end
    return SKSaves.validateDocument(document)
end