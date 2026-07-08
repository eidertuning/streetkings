local RESOURCE = GetCurrentResourceName()
local requestLogs = {}
local frozenPlayers = {}
local activeSessions = {}
local worldStateCache = { h = nil, m = 0, s = 0, weather = 'unknown' }
local liveSessions = {}
local liveCounter = 0

local function nowMs()
    return os.time() * 1000
end

local function makeToken(src)
    local seed = ('%s:%s:%s:%s'):format(src, os.time(), math.random(100000, 999999), tostring(GetPlayerName(src) or ''))
    return seed:gsub('[^%w]', '') .. tostring(math.random(100000, 999999))
end

local function createSession(src, auth)
    local ttl = tonumber(Config.Security and Config.Security.SessionTtlMs) or 300000
    local token = makeToken(src)
    activeSessions[src] = { token = token, expiresAt = nowMs() + ttl, rank = auth and auth.rank or 'admin' }
    return token, ttl
end

local function verifySession(src, token)
    if not (Config.Security and Config.Security.RequireTabletSession) then return true end
    src = tonumber(src)
    if not src or src <= 0 then return false, 'invalid_source' end
    if not token or token == '' then return false, 'missing_session' end
    local session = activeSessions[src]
    if not session then return false, 'no_session' end
    if session.token ~= token then return false, 'bad_session' end
    if session.expiresAt < nowMs() then activeSessions[src] = nil; return false, 'session_expired' end
    session.expiresAt = nowMs() + (tonumber(Config.Security and Config.Security.SessionTtlMs) or 300000)
    return true
end

local function log(line, level)
    local entry = { time = os.date('%H:%M:%S'), level = level or 'info', text = tostring(line or '') }
    requestLogs[#requestLogs + 1] = entry
    if #requestLogs > 80 then table.remove(requestLogs, 1) end
    if Config.Debug then print(('[%s] %s'):format(RESOURCE, entry.text)) end
end

local function n(v) local x=tonumber(v); if not x or x~=x then return nil end; return x end
local function s(v,d) if v==nil then return d or '' end return tostring(v) end
local function validSrc(src) src=n(src); if not src or src<=0 then return nil end; if not GetPlayerName(src) then return nil end; return src end

local function safeExport(name, ...)
    local ok, r1, r2, r3 = pcall(function(...) return exports['streetkings'][name](...) end, ...)
    if not ok then log(('export %s failed: %s'):format(name, tostring(r1)), 'error'); return nil end
    return r1, r2, r3
end

local function ids(src)
    local out = {}; src=validSrc(src); if not src then return out end
    for i=0, GetNumPlayerIdentifiers(src)-1 do local id=GetPlayerIdentifier(src,i); if id then out[#out+1]=id end end
    return out
end
local function idByPrefix(src, prefix)
    for _,id in ipairs(ids(src)) do if id:sub(1,#prefix)==prefix then return id end end
end
local function license(src) return idByPrefix(src,'license:') or idByPrefix(src,'license2:') end
local function endpoint(src) local ok, ep=pcall(GetPlayerEndpoint, src); return ok and ep or nil end

local function rankDef(rank) return Config.Ranks[rank or ''] or Config.Ranks.support end
local function hasPerm(auth, perm)
    if not auth then return false end
    if auth.rank == 'owner' then return true end
    local def = rankDef(auth.rank)
    for _,p in ipairs(def.permissions or {}) do if p=='*' or p==perm then return true end end
    return false
end

local function findAuth(src)
    if src == 0 and Config.Auth.AllowConsole then return { rank='owner', label='Console', license='console', via='console' } end
    src=validSrc(src); if not src then return nil end
    if Config.Auth.EnableLicenseWhitelist then
        for _,id in ipairs(ids(src)) do
            local e = Config.LicenseAdmins[id]
            if e then return { rank=e.rank or e, label=e.label or GetPlayerName(src), license=id, via='license' } end
        end
    end
    if Config.Auth.EnableAce and IsPlayerAceAllowed(src, Config.Auth.AcePermission) then
        return { rank='admin', label=GetPlayerName(src), license=license(src), via='ace' }
    end
    return nil
end

local function canAct(adminSrc, target)
    local auth = findAuth(adminSrc); if not auth then return false, 'not_authorized' end
    target = validSrc(target); if not target then return false, 'invalid_target' end
    local tLic = license(target)
    if tLic and Config.ProtectedLicenses[tLic] and rankDef(auth.rank).power < 100 then return false, 'target_protected' end
    return true, nil, auth
end

local readPath
local function hasMySQL() return MySQL and MySQL.single and MySQL.update and Config.Database and Config.Database.EnableSqlFallback end
local function decodeSaveRow(row)
    if not row then return nil end
    local ok, doc = pcall(json.decode, row.document_json or '{}')
    row.document = ok and type(doc) == 'table' and doc or {}
    row.slot_index = tonumber(row.slot_index) or tonumber(row.slotIndex) or 0
    return row
end

local function sqlLatestSave(owner, saveId, slotIndex)
    if not hasMySQL() or not owner then return nil end
    local tableName = Config.Database.SaveTable
    local row
    if type(saveId) == 'string' and saveId ~= '' and saveId ~= '__active' then
        row = MySQL.single.await(('SELECT id, owner_identifier, slot_index, display_name, schema_version, document_json, updated_at, last_played_at FROM `%s` WHERE owner_identifier = ? AND id = ? LIMIT 1'):format(tableName), { owner, saveId })
    elseif tonumber(slotIndex) then
        row = MySQL.single.await(('SELECT id, owner_identifier, slot_index, display_name, schema_version, document_json, updated_at, last_played_at FROM `%s` WHERE owner_identifier = ? AND slot_index = ? LIMIT 1'):format(tableName), { owner, tonumber(slotIndex) })
    else
        local q = ('SELECT id, owner_identifier, slot_index, display_name, schema_version, document_json, updated_at, last_played_at FROM `%s` WHERE owner_identifier = ? ORDER BY %s LIMIT 1'):format(tableName, Config.Database.LatestSaveOrder)
        row = MySQL.single.await(q, { owner })
    end
    return decodeSaveRow(row)
end

local function sqlWriteSave(row)
    if not hasMySQL() or not row or not row.owner_identifier then return false end
    local encoded = json.encode(row.document or {})
    local schema = tonumber(row.schema_version) or 1
    local updated = 0
    if row.id then
        local q = ('UPDATE `%s` SET schema_version = ?, document_json = ?, updated_at = CURRENT_TIMESTAMP(3) WHERE owner_identifier = ? AND id = ?'):format(Config.Database.SaveTable)
        updated = MySQL.update.await(q, { schema, encoded, row.owner_identifier, row.id }) or 0
    else
        local q = ('UPDATE `%s` SET schema_version = ?, document_json = ?, updated_at = CURRENT_TIMESTAMP(3) WHERE owner_identifier = ? AND slot_index = ?'):format(Config.Database.SaveTable)
        updated = MySQL.update.await(q, { schema, encoded, row.owner_identifier, row.slot_index }) or 0
    end
    return updated > 0
end

local function sqlListSaves(owner)
    if not hasMySQL() or not owner then return {} end
    local rows = MySQL.query.await(('SELECT id, owner_identifier, slot_index, display_name, schema_version, document_json, updated_at, last_played_at FROM `%s` WHERE owner_identifier = ? ORDER BY slot_index ASC'):format(Config.Database.SaveTable), { owner }) or {}
    local out = {}
    for i = 1, #rows do
        local row = decodeSaveRow(rows[i])
        if row then
            local doc = row.document or {}
            local vehicles = readPath(doc, 'garage.vehicles') or {}
            local activeId = readPath(doc, 'garage.activeVehicleId')
            local count = 0
            for _ in pairs(vehicles) do count = count + 1 end
            local activeVehicle = activeId and vehicles[activeId] or nil
            out[#out + 1] = {
                id = row.id,
                slotIndex = row.slot_index,
                displayName = row.display_name or ('Slot ' .. tostring(row.slot_index)),
                cash = tonumber(readPath(doc, 'economy.cash') or 0) or 0,
                level = tonumber(readPath(doc, 'progression.level') or 1) or 1,
                playerXp = tonumber(readPath(doc, 'progression.playerXp') or 0) or 0,
                garageCount = count,
                activeVehicleId = activeId,
                activeVehicleName = activeVehicle and (activeVehicle.displayName or activeVehicle.modelName),
                updatedAt = row.updated_at,
                lastPlayedAt = row.last_played_at
            }
        end
    end
    return out
end
local function ensurePath(t, key)
    local cur=t
    local parts={}; for p in key:gmatch('[^%.]+') do parts[#parts+1]=p end
    for i=1,#parts-1 do local k=parts[i]; if type(cur[k])~='table' then cur[k]={} end; cur=cur[k] end
    return cur, parts[#parts]
end
function readPath(t, key)
    local cur=t; for p in key:gmatch('[^%.]+') do if type(cur)~='table' then return nil end; cur=cur[p] end; return cur
end
local function writePath(t, key, value) local cur,k=ensurePath(t,key); cur[k]=value end

local function vehicleImageSources(model)
    local list = {}
    model = tostring(model or ''):lower()
    if model == '' then return list end
    local cfg = Config.VehicleImages or {}
    if cfg.Enabled == false then return list end
    for _, tpl in ipairs(cfg.Sources or {}) do
        if type(tpl) == 'string' then
            local ok, path = pcall(string.format, tpl, model)
            list[#list + 1] = ok and path or tpl
        end
    end
    return list
end


local vehicleCatalogCache = nil
local function buildVehicleCatalog()
    if vehicleCatalogCache then return vehicleCatalogCache end
    local exported = safeExport('GetAllVehicleData')
    if type(exported) ~= 'table' then exported = {} end

    local dealerLabels = (Config.VehicleCatalog and Config.VehicleCatalog.DealerLabels) or {}
    local parsed = {}
    local order = {}
    local seen = {}

    local function addParsed(model, meta)
        model = tostring(model or ''):lower()
        if model == '' then return end
        meta = meta or {}
        if not parsed[model] then
            parsed[model] = meta
            order[#order + 1] = model
        else
            for k, v in pairs(meta) do if v ~= nil and v ~= '' then parsed[model][k] = v end end
        end
    end

    local raw = LoadResourceFile('streetkings', 'data/game_vehicles.lua') or ''
    local currentDealer = 'starter'
    local inGame = false
    for line in raw:gmatch('[^\r\n]+') do
        if line:find('SKGameVehicles%s*=%s*{') then inGame = true end
        if inGame then
            local dealer = line:match('^%s*([%w_]+)%s*=%s*{%s*$')
            if dealer and dealer ~= 'SKGameVehicles' then currentDealer = dealer end
        end
        local model = line:match("model%s*=%s*'([^']+)'")
        if model then
            local price = tonumber(line:match('price%s*=%s*(%d+)') or line:match('value%s*=%s*(%d+)') or 0) or 0
            local className = line:match("class%s*=%s*'([^']+)'") or (not inGame and 'STARTER' or 'C')
            local displayName = line:match("displayName%s*=%s*'([^']+)'") or line:match('%-%-%s*(.+)$')
            local brand = line:match("brand%s*=%s*'([^']*)'")
            local vehicleType = line:match("vehicleType%s*=%s*'([^']+)'")
            addParsed(model, {
                model = model,
                price = price,
                class = className,
                dealerType = inGame and currentDealer or 'starter',
                displayName = displayName,
                brand = brand,
                vehicleType = vehicleType,
            })
        end
    end

    local list = {}
    local function addVehicle(model, meta, fromExportOnly)
        model = tostring(model or ''):lower()
        if model == '' or seen[model] then return end
        seen[model] = true
        meta = meta or {}
        local v = exported[model] or exported[tostring(model)] or {}
        if type(v) ~= 'table' then v = {} end
        local dealerType = meta.dealerType or v.dealerType or v.dealer or v.category or (fromExportOnly and 'other' or 'streetkings')
        local className = meta.class or v.class or v.performanceClass or v.vehicleClass or 'C'
        local name = meta.displayName or v.displayName or v.name or model
        local brand = meta.brand or v.brand or ''
        list[#list + 1] = {
            model = model,
            name = name,
            displayName = name,
            brand = brand,
            price = tonumber(meta.price or v.price or v.value or 0) or 0,
            category = dealerType,
            dealerType = dealerType,
            dealerLabel = dealerLabels[dealerType] or dealerType or 'StreetKings',
            class = className,
            type = meta.vehicleType or v.vehicleType or v.type or 'automobile',
            hash = v.hash,
            imageSources = vehicleImageSources(model),
            source = fromExportOnly and 'GetAllVehicleData' or 'game_vehicles.lua'
        }
        list[#list].imageUrl = list[#list].imageSources and list[#list].imageSources[1] or nil
    end

    for _, model in ipairs(order) do addVehicle(model, parsed[model], false) end
    for key, v in pairs(exported) do
        if type(v) == 'table' then
            addVehicle(v.model or v.modelName or key, v, true)
        else
            addVehicle(key, {}, true)
        end
    end

    local classOrder = (Config.VehicleCatalog and Config.VehicleCatalog.ClassOrder) or { 'STARTER', 'C', 'B', 'A', 'S' }
    local classRank = {}; for i, c in ipairs(classOrder) do classRank[c] = i end
    local dealerOrder = (Config.VehicleCatalog and Config.VehicleCatalog.DealerOrder) or {}
    local dealerRank = {}; for i, c in ipairs(dealerOrder) do dealerRank[c] = i end
    table.sort(list, function(a, b)
        local ca, cb = classRank[a.class] or 99, classRank[b.class] or 99
        if ca ~= cb then return ca < cb end
        local da, db = dealerRank[a.dealerType] or 99, dealerRank[b.dealerType] or 99
        if da ~= db then return da < db end
        return tostring(a.name) < tostring(b.name)
    end)
    vehicleCatalogCache = list
    log(('vehicle catalog loaded: %s vehicles'):format(#list))
    return list
end

local VALID_ADMIN_WEATHER = {
    EXTRASUNNY=true, CLEAR=true, CLOUDS=true, SMOG=true, FOGGY=true, OVERCAST=true,
    RAIN=true, THUNDER=true, CLEARING=true, NEUTRAL=true, SNOW=true, BLIZZARD=true,
    SNOWLIGHT=true, XMAS=true, HALLOWEEN=true,
}

local function callStreetKingsEnvExport(name, ...)
    local args = { ... }
    local attempts = {}

    -- 1) FiveM documented style. This is the most reliable for server exports.
    if name == 'GetEnvironmentState' then
        attempts[#attempts + 1] = function() return exports['streetkings']:GetEnvironmentState() end
    elseif name == 'ForceEnvironmentSync' then
        attempts[#attempts + 1] = function() return exports['streetkings']:ForceEnvironmentSync(args[1]) end
    elseif name == 'SetTime' then
        attempts[#attempts + 1] = function() return exports['streetkings']:SetTime(args[1], args[2]) end
    elseif name == 'SetHour' then
        attempts[#attempts + 1] = function() return exports['streetkings']:SetHour(args[1], args[2]) end
    elseif name == 'SetWeather' then
        attempts[#attempts + 1] = function() return exports['streetkings']:SetWeather(args[1]) end
    elseif name == 'SetAutoWeather' then
        attempts[#attempts + 1] = function() return exports['streetkings']:SetAutoWeather(args[1]) end
    elseif name == 'SetWeatherFrozen' then
        attempts[#attempts + 1] = function() return exports['streetkings']:SetWeatherFrozen(args[1]) end
    elseif name == 'SetTimeFrozen' then
        attempts[#attempts + 1] = function() return exports['streetkings']:SetTimeFrozen(args[1]) end
    elseif name == 'AdminSetTime' then
        attempts[#attempts + 1] = function() return exports['streetkings']:AdminSetTime(args[1], args[2]) end
    elseif name == 'AdminSetWeather' then
        attempts[#attempts + 1] = function() return exports['streetkings']:AdminSetWeather(args[1]) end
    elseif name == 'AdminGetEnvironmentState' then
        attempts[#attempts + 1] = function() return exports['streetkings']:AdminGetEnvironmentState() end
    end

    -- 2) Dynamic fallback used by some builds.
    attempts[#attempts + 1] = function()
        local resourceExports = exports['streetkings']
        local fn = resourceExports and resourceExports[name]
        if type(fn) ~= 'function' then return nil, 'missing_export_' .. tostring(name) end
        return fn(table.unpack(args))
    end

    local lastReason = 'no_attempts'
    for _, attempt in ipairs(attempts) do
        local ok, r1, r2 = pcall(attempt)
        if ok then
            if r1 == true or type(r1) == 'table' then return true, r1 end
            if r1 == nil and (name == 'ForceEnvironmentSync' or name == 'SetAutoWeather' or name == 'SetWeatherFrozen' or name == 'SetTimeFrozen') then
                return true, r1
            end
            lastReason = tostring(r2 or r1 or 'false')
        else
            lastReason = tostring(r1)
        end
    end
    log(('environment export %s failed: %s'):format(name, lastReason), 'error')
    return false, lastReason
end

local function refreshWorldState()
    local ok, env = callStreetKingsEnvExport('GetEnvironmentState')
    if not ok or type(env) ~= 'table' then
        ok, env = callStreetKingsEnvExport('AdminGetEnvironmentState')
    end
    if type(env) ~= 'table' then env = GlobalState and GlobalState.streetkingsEnvironment or nil end
    if type(env) == 'table' then
        worldStateCache.h = tonumber(env.h or env.hour) or worldStateCache.h
        worldStateCache.m = tonumber(env.m or env.minute) or worldStateCache.m or 0
        worldStateCache.s = tonumber(env.s or env.second) or worldStateCache.s or 0
        worldStateCache.weather = tostring(env.weather or worldStateCache.weather or 'unknown')
        worldStateCache.prevWeather = env.prevWeather
        worldStateCache.autoWeather = env.autoWeather
        worldStateCache.timeFrozen = env.timeFrozen
        worldStateCache.weatherFrozen = env.weatherFrozen
    end
    return worldStateCache
end

local function forceEnvironmentSync()
    callStreetKingsEnvExport('ForceEnvironmentSync')
    refreshWorldState()
end

local function setOfficialTime(hour, minute)
    hour = tonumber(hour)
    minute = tonumber(minute) or 0
    if not hour or hour < 0 or hour > 23 then return false, 'invalid_hour' end
    hour = math.floor(hour)
    minute = math.max(0, math.min(59, math.floor(minute)))

    local ok, reason = callStreetKingsEnvExport('SetTime', hour, minute)
    if not ok then ok, reason = callStreetKingsEnvExport('SetHour', hour, minute) end
    if not ok then ok, reason = callStreetKingsEnvExport('AdminSetTime', hour, minute) end

    if ok then
        worldStateCache.h = hour
        worldStateCache.m = minute
        worldStateCache.s = 0
        forceEnvironmentSync()
        return true
    end
    return false, 'SetTime/SetHour/AdminSetTime: ' .. tostring(reason)
end

local function setOfficialWeather(weather)
    local w = tostring(weather or ''):upper():gsub('%s+', '')
    if w == '' or not VALID_ADMIN_WEATHER[w] then return false, 'invalid_weather_' .. tostring(weather) end

    -- Tu environment_s.lua usa autoWeather y weatherFrozen. Si no los fijamos,
    -- el clima automático puede volver a cambiar y parece que el botón falló.
    callStreetKingsEnvExport('SetAutoWeather', false)
    callStreetKingsEnvExport('SetWeatherFrozen', true)

    local ok, reason = callStreetKingsEnvExport('SetWeather', w)
    if not ok then ok, reason = callStreetKingsEnvExport('AdminSetWeather', w) end

    if ok then
        worldStateCache.weather = w
        worldStateCache.autoWeather = false
        worldStateCache.weatherFrozen = true
        forceEnvironmentSync()
        return true
    end
    return false, 'SetWeather/AdminSetWeather: ' .. tostring(reason)
end


-- Legacy screenshot capture removed. Live uses hidden WebGL + WebRTC only.

local function selectedSaveIsActive(target, saveId)
    if not saveId or saveId == '' then return false end
    local activeId = safeExport('GetActiveSaveId', target)
    return type(activeId) == 'string' and activeId ~= '' and activeId == saveId
end

local function liveModifyCash(target, amount, mode)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if amount <= 0 then return false, 'invalid_amount' end
    local cur = tonumber(safeExport('ReadSaveData', target, 'economy.cash') or safeExport('GetPlayerCash', target) or 0) or 0
    local newCash = mode == 'remove' and math.max(0, cur - amount) or (cur + amount)
    local wrote = safeExport('WriteSaveData', target, 'economy.cash', newCash) == true
    if not wrote then return false, 'write_save_failed' end
    safeExport('PersistSave', target)
    return true, nil, newCash
end

local function targetOwner(target, supplied)
    local own = type(supplied)=='string' and supplied or nil
    if own and (own:find('^license:') or own:find('^license2:')) then return own end
    return license(target)
end

local function sqlModifyCash(owner, amount, mode, saveId, slotIndex)
    local row = sqlLatestSave(owner, saveId, slotIndex); if not row then return false, 'no_sql_save' end
    local cur = tonumber(readPath(row.document, 'economy.cash') or 0) or 0
    amount = math.floor(math.abs(tonumber(amount) or 0)); if amount <= 0 then return false, 'invalid_amount' end
    if mode == 'remove' then cur = math.max(0, cur - amount) else cur = cur + amount end
    writePath(row.document, 'economy.cash', cur)
    if sqlWriteSave(row) then return true, nil, cur, { saveId = row.id, slotIndex = row.slot_index, displayName = row.display_name } end
    return false, 'sql_write_failed'
end

local function sqlAwardPlayerXp(owner, amount, saveId, slotIndex)
    local row = sqlLatestSave(owner, saveId, slotIndex); if not row then return false, 'no_sql_save' end
    amount = math.floor(math.abs(tonumber(amount) or 0)); if amount <= 0 then return false, 'invalid_amount' end
    local xp = tonumber(readPath(row.document, 'progression.playerXp') or 0) or 0
    xp = xp + amount
    local level = 1
    for i,v in pairs(Config.Progression.PlayerLevelThresholds) do if xp >= v and i > level then level = i end end
    writePath(row.document, 'progression.playerXp', xp); writePath(row.document, 'progression.level', level)
    if sqlWriteSave(row) then return true, nil, { xpGained=amount, newXp=xp, newLevel=level, saveId=row.id, slotIndex=row.slot_index, displayName=row.display_name } end
    return false, 'sql_write_failed'
end

local function vehicleLevelFromXp(xp)
    xp=tonumber(xp) or 0; local level=1
    for i,v in pairs(Config.Progression.VehicleLevelThresholds) do if xp >= v and i > level then level=i end end
    return level
end
local function sqlAwardVehicleXp(owner, amount, saveId, slotIndex)
    local row=sqlLatestSave(owner, saveId, slotIndex); if not row then return false,'no_sql_save' end
    amount=math.floor(math.abs(tonumber(amount) or 0)); if amount<=0 then return false,'invalid_amount' end
    local active=readPath(row.document,'garage.activeVehicleId')
    local vehicles=readPath(row.document,'garage.vehicles') or {}
    local entry=vehicles[active]
    if not entry then for id,v in pairs(vehicles) do active=id; entry=v; break end end
    if not entry then return false,'no_vehicle' end
    entry.data=entry.data or {}; local old=tonumber(entry.data.xp or 0) or 0
    local max=Config.Progression.VehicleLevelThresholds[Config.Progression.VehicleMaxLevel] or 987
    entry.data.xp=math.min(old + amount, max); entry.data.level=vehicleLevelFromXp(entry.data.xp)
    if sqlWriteSave(row) then return true,nil,{vehicleId=active,xpGained=entry.data.xp-old,newXp=entry.data.xp,newLevel=entry.data.level,saveId=row.id,slotIndex=row.slot_index,displayName=row.display_name} end
    return false,'sql_write_failed'
end

local function sqlOwnedVehicles(owner, saveId, slotIndex)
    local row=sqlLatestSave(owner, saveId, slotIndex); if not row then return {} end
    return readPath(row.document,'garage.vehicles') or {}
end
local function sqlSetActiveVehicle(owner, vehicleId, saveId, slotIndex)
    local row=sqlLatestSave(owner, saveId, slotIndex); if not row then return false,'no_sql_save' end
    local vehicles=readPath(row.document,'garage.vehicles') or {}; if not vehicles[vehicleId] then return false,'vehicle_not_found' end
    writePath(row.document,'garage.activeVehicleId',vehicleId)
    if sqlWriteSave(row) then return true end
    return false,'sql_write_failed'
end
local function makeVehicleId()
    local chars='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local out={}
    for i=1,5 do
        local s=''; for j=1,4 do local r=math.random(#chars); s=s..chars:sub(r,r) end; out[#out+1]=s
    end
    return table.concat(out,'-')
end
local function randomPlate()
    local chars='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'; local s=''
    for i=1,8 do local r=math.random(#chars); s=s..chars:sub(r,r) end
    return s
end
local function sqlAddVehicle(owner, veh, saveId, slotIndex)
    local row=sqlLatestSave(owner, saveId, slotIndex); if not row then return false,'no_sql_save' end
    veh = type(veh)=='table' and veh or {}
    local model = s(veh.model):lower(); if model=='' then return false,'invalid_model' end
    local id = makeVehicleId()
    local vehicles=readPath(row.document,'garage.vehicles') or {}; writePath(row.document,'garage.vehicles',vehicles)
    vehicles[id] = {
        id=id, modelName=model, displayName=veh.name or veh.displayName or model, plate=randomPlate(), sortIndex=999,
        data={ xp=0, level=1, vehicleType=veh.type or veh.vehicleType or 'automobile', mods={}, unlocks={}, unlockSchedule={}, availableMods={}, bestActivityScores={} }
    }
    if not readPath(row.document,'garage.activeVehicleId') then writePath(row.document,'garage.activeVehicleId',id) end
    if sqlWriteSave(row) then return true,nil,id end
    return false,'sql_write_failed'
end
local function sqlDeleteVehicle(owner, vehicleId, saveId, slotIndex)
    local row=sqlLatestSave(owner, saveId, slotIndex); if not row then return false,'no_sql_save' end
    local vehicles=readPath(row.document,'garage.vehicles') or {}; if not vehicles[vehicleId] then return false,'vehicle_not_found' end
    vehicles[vehicleId]=nil
    if readPath(row.document,'garage.activeVehicleId') == vehicleId then local nextId=nil; for id in pairs(vehicles) do nextId=id; break end; writePath(row.document,'garage.activeVehicleId', nextId) end
    if sqlWriteSave(row) then return true end
    return false,'sql_write_failed'
end

local function flattenVehicles(map, active)
    local arr={}
    for id,v in pairs(map or {}) do
        if type(v) == 'table' then
            local item = {}
            for k,val in pairs(v) do item[k]=val end
            item.id = item.id or id
            item.active = (id == active)
            item.modelName = item.modelName or item.model or ''
            item.imageSources = vehicleImageSources(item.modelName)
            arr[#arr+1]=item
        end
    end
    table.sort(arr, function(a,b) return tostring(a.displayName or a.modelName or a.id) < tostring(b.displayName or b.modelName or b.id) end)
    return arr
end

local function playerSnapshot(src)
    src=validSrc(src); if not src then return nil end
    local ped=GetPlayerPed(src); local coords = ped and ped~=0 and GetEntityCoords(ped) or vector3(0,0,0)
    local own=license(src)
    local activeSave = safeExport('HasActiveSave', src) == true
    local activeSaveId = safeExport('GetActiveSaveId', src)
    local state = safeExport('GetPlayerGameState', src) or 'unknown'
    local saves = sqlListSaves(own)
    local latest = sqlLatestSave(own)
    local cash = 0
    local level = 1
    local activeVehicle = nil
    local owned = {}

    if activeSave then
        cash = safeExport('GetPlayerCash', src) or 0
        level = safeExport('GetPlayerLevel', src) or 1
        activeVehicle = safeExport('GetActiveVehicle', src)
        owned = safeExport('GetOwnedVehicles', src) or {}
    elseif latest then
        local doc = latest.document or {}
        cash = tonumber(readPath(doc,'economy.cash') or 0) or 0
        level = tonumber(readPath(doc,'progression.level') or 1) or 1
        owned = readPath(doc,'garage.vehicles') or {}
        activeVehicle = owned[readPath(doc,'garage.activeVehicleId')] or activeVehicle
    end

    local count=0; for _ in pairs(owned or {}) do count=count+1 end
    local defaultSaveId = latest and latest.id or nil
    local defaultSlot = latest and latest.slot_index or nil
    return {
        id=src, name=GetPlayerName(src), ping=GetPlayerPing(src), license=own, endpoint=endpoint(src), identifiers=ids(src),
        state=state, activeSave=activeSave, activeSaveId=activeSaveId, saveStatus=activeSave and 'active' or 'sql-fallback',
        cash=cash, level=level, garageCount=count, activeVehicle=activeVehicle,
        defaultSaveId=defaultSaveId, defaultSlot=defaultSlot, characters=saves,
        coords={x=coords.x,y=coords.y,z=coords.z}, frozen=frozenPlayers[src] == true,
        health = ped and ped~=0 and GetEntityHealth(ped) or 0, armor = ped and ped~=0 and GetPedArmour(ped) or 0
    }
end

local function getData(adminSrc)
    local auth=findAuth(adminSrc); if not auth then return {ok=false,error='not_authorized'} end
    local players={}
    for _,sid in ipairs(GetPlayers()) do local p=playerSnapshot(tonumber(sid)); if p then players[#players+1]=p end end
    table.sort(players,function(a,b) return a.id < b.id end)
    local worldState = refreshWorldState()
    local catalog = buildVehicleCatalog()
    return { ok=true, auth=auth, self=playerSnapshot(adminSrc), players=players, defaults=Config.Defaults, world=Config.World, worldState=worldState, catalog=catalog, imageSources=(Config.VehicleImages and Config.VehicleImages.Sources or {}), logs=requestLogs, serverTime=os.date('%H:%M:%S'), capture={ enabled=false, resource='', liveIntervalMs=0, live=true } }
end


local function liveSessionId(admin, target)
    liveCounter = liveCounter + 1
    return ('live:%s:%s:%s:%s'):format(os.time(), tostring(admin), tostring(target), tostring(liveCounter))
end

local function liveIceConfig()
    return {
        iceServers = {
            { urls = 'stun:stun.l.google.com:19302' },
            { urls = 'stun:stun1.l.google.com:19302' },
            { urls = 'stun:stun2.l.google.com:19302' },
            { urls = 'stun:stun3.l.google.com:19302' },
            { urls = 'stun:stun4.l.google.com:19302' }
        },
        iceCandidatePoolSize = 6
    }
end

local function cleanupLiveSession(sessionId, reason)
    local sess = liveSessions[sessionId]
    if not sess then return end
    liveSessions[sessionId] = nil
    if sess.admin and GetPlayerName(sess.admin) then
        TriggerClientEvent('ce_skadmin:client:liveStop', sess.admin, sessionId, reason or 'closed')
    end
    if sess.target and GetPlayerName(sess.target) then
        TriggerClientEvent('ce_skadmin:client:liveStop', sess.target, sessionId, reason or 'closed')
    end
    log(('live cleanup session=%s reason=%s'):format(tostring(sessionId), tostring(reason or 'closed')))
end

local function liveStart(adminSrc, data)
    if not (Config.Live and Config.Live.Enabled ~= false) then return { ok=false, error='live_disabled' } end
    local target = validSrc(data and data.target)
    if not target then return { ok=false, error='Jugador no está conectado para la vista en vivo' } end
    if target == adminSrc then return { ok=false, error='Selecciona otro jugador. No puedes abrir Live sobre ti mismo.' } end
    local ok, reason, auth = canAct(adminSrc, target)
    if not ok then return { ok=false, error=reason or 'cannot_act' } end
    if not hasPerm(auth, 'capture.live') and not hasPerm(auth, 'capture.screen') then
        return { ok=false, error='Sin permiso: capture.live' }
    end

    local sessionId = liveSessionId(adminSrc, target)
    liveSessions[sessionId] = {
        id = sessionId,
        admin = adminSrc,
        target = target,
        createdAt = nowMs(),
        lastAt = nowMs(),
        signalsToAdmin = {},
        signalsToTarget = {},
        seq = 0,
        closed = false
    }

    local width = tonumber(Config.Live.Width) or 1280
    local height = tonumber(Config.Live.Height) or 720
    local fps = tonumber(Config.Live.FrameRate) or 24
    TriggerClientEvent('ce_skadmin:client:liveStart', target, {
        sessionId = sessionId,
        admin = adminSrc,
        width = width,
        height = height,
        fps = fps,
        iceConfig = liveIceConfig()
    })

    log(('live start admin=%s target=%s session=%s'):format(adminSrc, target, sessionId))
    return {
        ok = true,
        sessionId = sessionId,
        target = target,
        width = width,
        height = height,
        fps = fps,
        pollMs = tonumber(Config.Live.PollMs) or 250,
        iceConfig = liveIceConfig()
    }
end

local function liveSignalFromAdmin(adminSrc, data)
    data = type(data) == 'table' and data or {}
    local sessionId = tostring(data.sessionId or '')
    local sess = liveSessions[sessionId]
    if not sess then return { ok=false, error='live_session_missing' } end
    if sess.admin ~= adminSrc then return { ok=false, error='live_wrong_admin' } end
    if not GetPlayerName(sess.target) then cleanupLiveSession(sessionId, 'target_left'); return { ok=false, error='target_left' } end
    sess.lastAt = nowMs()
    local signal = type(data.signal) == 'table' and data.signal or {}
    TriggerClientEvent('ce_skadmin:client:liveSignal', sess.target, sessionId, signal)
    return { ok=true }
end

local function liveSignalFromTarget(targetSrc, sessionId, signal)
    sessionId = tostring(sessionId or '')
    local sess = liveSessions[sessionId]
    if not sess then return false, 'live_session_missing' end
    if sess.target ~= targetSrc then return false, 'live_wrong_target' end
    if not GetPlayerName(sess.admin) then cleanupLiveSession(sessionId, 'admin_left'); return false, 'admin_left' end
    sess.lastAt = nowMs()
    sess.seq = (sess.seq or 0) + 1
    sess.signalsToAdmin[#sess.signalsToAdmin + 1] = { id = sess.seq, signal = type(signal) == 'table' and signal or {} }
    if #sess.signalsToAdmin > 80 then table.remove(sess.signalsToAdmin, 1) end
    return true
end

local function livePoll(adminSrc, data)
    data = type(data) == 'table' and data or {}
    local sessionId = tostring(data.sessionId or '')
    local sess = liveSessions[sessionId]
    if not sess then return { ok=false, error='live_session_missing' } end
    if sess.admin ~= adminSrc then return { ok=false, error='live_wrong_admin' } end
    local maxSeconds = tonumber(Config.Live and Config.Live.MaxSeconds) or 300
    if (nowMs() - (sess.createdAt or nowMs())) > maxSeconds * 1000 then
        cleanupLiveSession(sessionId, 'timeout')
        return { ok=false, error='live_timeout' }
    end
    local after = tonumber(data.after or 0) or 0
    local out = {}
    for _, item in ipairs(sess.signalsToAdmin or {}) do
        if (tonumber(item.id) or 0) > after then out[#out + 1] = item end
    end
    return { ok=true, signals=out, serverTime=os.date('%H:%M:%S') }
end

local function liveStop(adminSrc, data)
    data = type(data) == 'table' and data or {}
    local sessionId = tostring(data.sessionId or '')
    local sess = liveSessions[sessionId]
    if not sess then return { ok=true, message='Live ya estaba cerrado' } end
    if sess.admin ~= adminSrc then return { ok=false, error='live_wrong_admin' } end
    cleanupLiveSession(sessionId, data.reason or 'stopped_by_admin')
    return { ok=true, message='Live detenido' }
end

local function clientResult(src, ok, message, payload)
    return { ok=ok==true, message=message or (ok and 'OK' or 'Error'), payload=payload }
end

local function targetSaveRef(data)
    data = type(data) == 'table' and data or {}
    local saveId = type(data.targetSaveId) == 'string' and data.targetSaveId or nil
    if saveId == '' or saveId == '__active' then saveId = nil end
    local slotIndex = tonumber(data.targetSlot)
    return saveId, slotIndex
end

local function doEconomy(admin, target, data, mode)
    local ok, reason = canAct(admin,target); if not ok then return clientResult(admin,false,reason) end
    local amount=math.floor(math.abs(tonumber(data.amount) or 0)); if amount<=0 then return clientResult(admin,false,'Cantidad inválida') end
    local own=targetOwner(target, data.targetLicense)
    local saveId, slotIndex = targetSaveRef(data)

    if saveId or slotIndex then
        if saveId and selectedSaveIsActive(target, saveId) then
            local liveOk, liveReason, total = liveModifyCash(target, amount, mode)
            if liveOk then
                log(('cash LIVE %s admin=%s target=%s save=%s amount=%s total=%s'):format(mode, admin, target, tostring(saveId), amount, tostring(total)))
                return clientResult(admin,true,'Cash actualizado en personaje cargado', {cash=total, mode='live', saveId=saveId})
            end
            log(('cash live failed target=%s save=%s reason=%s; trying db'):format(target, tostring(saveId), tostring(liveReason)), 'warn')
        end
        local sqlOk, sqlReason, total, meta = sqlModifyCash(own, amount, mode, saveId, slotIndex)
        if sqlOk then
            log(('cash DB %s admin=%s target=%s save=%s slot=%s amount=%s total=%s'):format(mode, admin, target, tostring(saveId), tostring(slotIndex), amount, tostring(total)))
            return clientResult(admin,true,('Cash actualizado en %s'):format(meta and meta.displayName or 'personaje'), {cash=total, mode='db', save=meta})
        end
        return clientResult(admin,false,'No se pudo cambiar cash en ese personaje: '..s(sqlReason or 'sin datos'))
    end

    local bridge = safeExport('AdminModifyCash', target, amount, mode, own)
    if bridge and bridge.ok then log(('cash bridge %s target=%s amount=%s total=%s'):format(mode,target,amount,tostring(bridge.cash or bridge.finalCash))); return clientResult(admin,true,'Cash actualizado',bridge) end
    local exOk = false
    if mode=='remove' then exOk = safeExport('RemovePlayerCash', target, amount) == true else exOk = safeExport('AddPlayerCash', target, amount) == true end
    if exOk then safeExport('PersistSave', target); return clientResult(admin,true,'Cash actualizado por personaje cargado', {cash=safeExport('GetPlayerCash',target), mode='live'}) end
    local sqlOk, sqlReason, total, meta = sqlModifyCash(own, amount, mode)
    if sqlOk then return clientResult(admin,true,'Cash guardado en último personaje', {cash=total, mode='db', save=meta}) end
    return clientResult(admin,false,'No se pudo cambiar cash: '..s(sqlReason or 'sin personaje'))
end

local function doXp(admin,target,data,kind)
    local ok, reason = canAct(admin,target); if not ok then return clientResult(admin,false,reason) end
    local amount=math.floor(math.abs(tonumber(data.amount) or 0)); if amount<=0 then return clientResult(admin,false,'XP inválida') end
    local own=targetOwner(target, data.targetLicense)
    local saveId, slotIndex = targetSaveRef(data)
    if kind=='player' then
        if saveId or slotIndex then
            if saveId and selectedSaveIsActive(target, saveId) then
                local res=safeExport('AwardPlayerXp',target,amount)
                if res then safeExport('PersistSave',target); return clientResult(admin,true,'XP jugador añadida al personaje cargado',res) end
                log(('AwardPlayerXp live failed target=%s save=%s; trying db'):format(target, tostring(saveId)), 'warn')
            end
            local sqlOk, sqlReason, payload = sqlAwardPlayerXp(own, amount, saveId, slotIndex); if sqlOk then return clientResult(admin,true,'XP jugador guardada en personaje',payload) end
            return clientResult(admin,false,'No se pudo dar XP a ese personaje: '..s(sqlReason))
        end
        local bridge=safeExport('AdminAwardPlayerXp', target, amount, own)
        if bridge and bridge.ok then return clientResult(admin,true,'XP jugador añadida',bridge) end
        local res=safeExport('AwardPlayerXp',target,amount); if res then safeExport('PersistSave',target); return clientResult(admin,true,'XP jugador añadida por personaje cargado',res) end
        local sqlOk, sqlReason, payload = sqlAwardPlayerXp(own, amount); if sqlOk then return clientResult(admin,true,'XP jugador guardada en último personaje',payload) end
        return clientResult(admin,false,'No se pudo dar XP jugador: '..s(sqlReason))
    else
        if saveId or slotIndex then
            if saveId and selectedSaveIsActive(target, saveId) then
                local res=safeExport('AwardVehicleXp',target,amount)
                if res then safeExport('PersistSave',target); return clientResult(admin,true,'XP vehículo añadida al coche activo cargado',res) end
                log(('AwardVehicleXp live failed target=%s save=%s; trying db'):format(target, tostring(saveId)), 'warn')
            end
            local sqlOk, sqlReason, payload = sqlAwardVehicleXp(own, amount, saveId, slotIndex); if sqlOk then return clientResult(admin,true,'XP vehículo guardada en personaje',payload) end
            return clientResult(admin,false,'No se pudo dar XP al coche de ese personaje: '..s(sqlReason))
        end
        local bridge=safeExport('AdminAwardVehicleXp', target, amount, own)
        if bridge and bridge.ok then return clientResult(admin,true,'XP vehículo añadida',bridge) end
        local res=safeExport('AwardVehicleXp',target,amount); if res then safeExport('PersistSave',target); return clientResult(admin,true,'XP vehículo añadida por personaje cargado',res) end
        local sqlOk, sqlReason, payload = sqlAwardVehicleXp(own, amount); if sqlOk then return clientResult(admin,true,'XP vehículo guardada en último personaje',payload) end
        return clientResult(admin,false,'No se pudo dar XP vehículo: '..s(sqlReason))
    end
end

local function doGarage(admin,target,data,action)
    local ok, reason = canAct(admin,target); if not ok then return clientResult(admin,false,reason) end
    local own=targetOwner(target,data.targetLicense)
    local saveId, slotIndex = targetSaveRef(data)
    if action=='setactive' then
        local vehicleId=s(data.vehicleId)
        if not (saveId or slotIndex) then
            local wrote=safeExport('WriteSaveData', target, 'garage.activeVehicleId', vehicleId)==true
            if wrote then safeExport('PersistSave',target); safeExport('AdminRespawnActiveVehicle', target, own); return clientResult(admin,true,'Vehículo activo cambiado') end
        end
        local sqlOk, sqlReason = sqlSetActiveVehicle(own,vehicleId,saveId,slotIndex); if sqlOk then safeExport('AdminRespawnActiveVehicle', target, own); return clientResult(admin,true,'Vehículo activo cambiado en personaje') end
        return clientResult(admin,false,'No se pudo activar: '..s(sqlReason))
    elseif action=='add' then
        local sqlOk, sqlReason, id = sqlAddVehicle(own,data.vehicle or data,saveId,slotIndex); if sqlOk then return clientResult(admin,true,'Vehículo agregado al personaje',{vehicleId=id}) end
        return clientResult(admin,false,'No se pudo agregar: '..s(sqlReason))
    elseif action=='delete' then
        local sqlOk, sqlReason = sqlDeleteVehicle(own,s(data.vehicleId),saveId,slotIndex); if sqlOk then return clientResult(admin,true,'Vehículo eliminado del personaje') end
        return clientResult(admin,false,'No se pudo borrar: '..s(sqlReason))
    end
    return clientResult(admin,false,'garage_action_unknown')
end

local function doAction(adminSrc, data)
    data = type(data)=='table' and data or {}; local action=s(data.action); local target=validSrc(data.target)
    local auth=findAuth(adminSrc); if not auth then return clientResult(adminSrc,false,'not_authorized') end
    local permMap={
        ['cash.add']='economy.add',['cash.remove']='economy.remove',['xp.player']='progression.playerxp',['xp.vehicle']='progression.vehiclexp',
        ['garage.setactive']='garage.setactive',['garage.add']='garage.add',['garage.delete']='garage.delete',
        ['player.goto']='player.goto',['player.bring']='player.bring',['player.spectate']='player.spectate',['player.freeze']='player.freeze',['player.revive']='player.revive',['player.heal']='player.heal',['player.armor']='player.armor',['player.kill']='player.kill',['player.kick']='player.kick',
        ['vehicle.repair']='vehicle.repair',['vehicle.clean']='vehicle.clean',['vehicle.flip']='vehicle.flip',['vehicle.warpwp']='vehicle.warpwp',['vehicle.speedometer']='vehicle.speedometer',['vehicle.soundtrack']='vehicle.soundtrack',['vehicle.cinematic']='vehicle.cinematic',['vehicle.exitlock']='vehicle.exitlock',
        ['world.time']='world.time',['world.weather']='world.weather',['phone.message']='phone.message',['phone.broadcast']='phone.broadcast',['phone.toggle']='phone.toggle'
    }
    if not hasPerm(auth, permMap[action] or action) then return clientResult(adminSrc,false,'Sin permiso: '..action) end
    if action=='cash.add' then return doEconomy(adminSrc,target,data,'add') end
    if action=='cash.remove' then return doEconomy(adminSrc,target,data,'remove') end
    if action=='xp.player' then return doXp(adminSrc,target,data,'player') end
    if action=='xp.vehicle' then return doXp(adminSrc,target,data,'vehicle') end
    if action=='garage.setactive' then return doGarage(adminSrc,target,data,'setactive') end
    if action=='garage.add' then return doGarage(adminSrc,target,data,'add') end
    if action=='garage.delete' then return doGarage(adminSrc,target,data,'delete') end
    if action=='world.time' then
        local ok, reason = setOfficialTime(data.hour, data.minute or 0)
        log(('world time set hour=%s ok=%s reason=%s by=%s'):format(tostring(data.hour), tostring(ok), tostring(reason), adminSrc))
        return clientResult(adminSrc, ok, ok and ('Hora aplicada: %02d:%02d'):format(tonumber(data.hour) or 0, tonumber(data.minute) or 0) or ('No se pudo aplicar hora: '..s(reason)))
    end
    if action=='world.weather' then
        local ok, reason = setOfficialWeather(data.weather)
        log(('world weather set weather=%s ok=%s reason=%s by=%s'):format(tostring(data.weather), tostring(ok), tostring(reason), adminSrc))
        return clientResult(adminSrc, ok, ok and ('Clima aplicado: '..s(data.weather):upper()) or ('No se pudo aplicar clima: '..s(reason)))
    end
    if action=='capture.screenshot' then
        return clientResult(adminSrc, false, 'Captura antigua desactivada. Usa la pestaña Live.')
    end
    if action=='phone.broadcast' then
        local sender = s(data.sender, Config.Defaults.phoneSender)
        local body = s(data.body, Config.Defaults.phoneMessage)
        local ok = safeExport('BroadcastPhoneMessage', sender, Config.Defaults.phoneAvatar, body, nil, {}) == true
        if ok then return clientResult(adminSrc, true, 'Mensaje enviado a todos por teléfono') end
        local count = 0
        for _, sid in ipairs(GetPlayers()) do
            local t = tonumber(sid)
            if t then
                TriggerClientEvent('ce_skadmin:client:adminDirectMessage', t, { sender = sender, body = body, broadcast = true })
                count = count + 1
            end
        end
        log(('phone broadcast fallback direct count=%s'):format(count))
        return clientResult(adminSrc, count > 0, ('Broadcast enviado como aviso directo a %s jugadores'):format(count))
    end
    if action=='phone.message' then
        local ok,reason=canAct(adminSrc,target); if not ok then return clientResult(adminSrc,false,reason) end
        local sender = s(data.sender, Config.Defaults.phoneSender)
        local body = s(data.body, Config.Defaults.phoneMessage)
        local sent = safeExport('SendPhoneMessage', target, sender, Config.Defaults.phoneAvatar, body) == true
        if sent then return clientResult(adminSrc, true, 'Mensaje enviado por teléfono') end
        -- Si StreetKings no tiene el personaje/save activo en memoria, el teléfono oficial rechaza el mensaje.
        -- Para admins lo enviamos igual como aviso directo en pantalla al jugador online.
        TriggerClientEvent('ce_skadmin:client:adminDirectMessage', target, { sender = sender, body = body, direct = true })
        log(('phone message fallback direct admin=%s target=%s'):format(adminSrc, target))
        return clientResult(adminSrc, true, 'El jugador no tiene personaje activo: enviado como aviso directo')
    end
    if action=='player.kick' then local ok,reason=canAct(adminSrc,target); if not ok then return clientResult(adminSrc,false,reason) end; DropPlayer(target, s(data.reason,Config.Defaults.kickReason)); return clientResult(adminSrc,true,'Jugador expulsado') end
    -- target-side or admin-side client actions
    local ok, reason = canAct(adminSrc, target); if not ok and action ~= 'vehicle.warpwp' then return clientResult(adminSrc,false,reason) end
    local runOnAdmin = { ['player.goto']=true, ['player.spectate']=true, ['vehicle.warpwp']=true }
    local dest = runOnAdmin[action] and adminSrc or target
    local payload = { action=action, target=target, admin=adminSrc, amount=data.amount, state=data.state, armor=data.armor }
    if action=='player.bring' then local ped=GetPlayerPed(adminSrc); local c=GetEntityCoords(ped); payload.coords={x=c.x,y=c.y,z=c.z,h=GetEntityHeading(ped)} end
    if action=='player.goto' then local ped=GetPlayerPed(target); local c=GetEntityCoords(ped); payload.coords={x=c.x,y=c.y,z=c.z,h=GetEntityHeading(ped)} end
    if action=='player.freeze' then frozenPlayers[target] = not frozenPlayers[target]; payload.state=frozenPlayers[target] end
    TriggerClientEvent('ce_skadmin:client:runTabletAction', dest, payload)
    return clientResult(adminSrc,true,'Acción enviada')
end


RegisterNetEvent('ce_skadmin:server:hiddenLiveSignal', function(sessionId, signal)
    local src = source
    local ok, reason = liveSignalFromTarget(src, sessionId, signal)
    if not ok then log(('hidden live signal rejected src=%s session=%s reason=%s'):format(src, tostring(sessionId), tostring(reason)), 'warn') end
end)

RegisterNetEvent('ce_skadmin:server:tabletRpc', function(reqId, event, data)
    local src = source
    data = type(data) == 'table' and data or {}
    local res

    if event == 'auth' then
        local a = findAuth(src)
        res = { ok = a ~= nil, auth = a }

    elseif event == 'openSession' then
        local a = findAuth(src)
        if not a then
            activeSessions[src] = nil
            res = { ok=false, error='not_authorized' }
        elseif data.appId ~= nil and data.appId ~= Config.App.id then
            activeSessions[src] = nil
            res = { ok=false, error='invalid_app_request' }
        else
            local token, ttl = createSession(src, a)
            log(('secure tablet session opened src=%s rank=%s'):format(src, tostring(a.rank)))
            res = { ok=true, token=token, ttlMs=ttl, auth=a }
        end

    else
        local sessionOk, sessionReason = verifySession(src, data._token)
        local a = findAuth(src)
        if not a then
            activeSessions[src] = nil
            res = { ok=false, error='not_authorized' }
        elseif not sessionOk then
            res = { ok=false, error=sessionReason or 'invalid_session' }
        elseif event == 'getData' then
            res = getData(src)
        elseif event == 'liveStart' then
            res = liveStart(src, data)
        elseif event == 'liveSignal' then
            res = liveSignalFromAdmin(src, data)
        elseif event == 'livePoll' then
            res = livePoll(src, data)
        elseif event == 'liveStop' then
            res = liveStop(src, data)
        elseif event == 'action' then
            res = doAction(src, data)
        elseif event == 'getTargetGarage' then
            local target = validSrc(data and data.target)
            if not target then
                res = { ok=false, error='invalid_target' }
            else
                local own = targetOwner(target, data and data.targetLicense)
                local saveId, slotIndex = targetSaveRef(data)
                local active
                local owned
                if not (saveId or slotIndex) then
                    active = safeExport('ReadSaveData', target, 'garage.activeVehicleId')
                    owned = safeExport('GetOwnedVehicles', target)
                end
                if not owned or not next(owned) then
                    owned = sqlOwnedVehicles(own, saveId, slotIndex)
                    local row = sqlLatestSave(own, saveId, slotIndex)
                    if row then active = readPath(row.document, 'garage.activeVehicleId') end
                end
                res = { ok=true, vehicles=flattenVehicles(owned, active), activeVehicleId=active, saveId=saveId, slotIndex=slotIndex }
            end
        else
            res = { ok=false, error='unknown_rpc' }
        end
    end

    TriggerClientEvent('ce_skadmin:client:tabletRpcResponse', src, reqId, res)
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeSessions[src] = nil
    for id, sess in pairs(liveSessions) do
        if sess.admin == src or sess.target == src then cleanupLiveSession(id, 'player_dropped') end
    end
end)

AddEventHandler('onResourceStart', function(res) if res==RESOURCE then math.randomseed(os.time()); log('admin tablet server v46 started') end end)
