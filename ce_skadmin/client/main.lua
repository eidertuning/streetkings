local APP = Config.App
local registered = false
local pending = {}
local reqCounter = 0
local sessionToken = nil
local sessionExpiresAt = 0
local localStates = { speedometer=true, soundtrack=true, cinematic=false, exitlock=false, spectating=false, frozen=false }
local imageSourceCache = {}
local vehicleCatalogCache = nil

local function nowMs()
    return GetGameTimer()
end

local function rpc(event, data, timeout)
    reqCounter = reqCounter + 1
    local id = ('%s:%s'):format(GetGameTimer(), reqCounter)
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('ce_skadmin:server:tabletRpc', id, event, data or {})
    SetTimeout(timeout or 8000, function()
        if pending[id] then pending[id] = nil; p:resolve({ ok=false, error='timeout' }) end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('ce_skadmin:client:tabletRpcResponse', function(id, response)
    local p = pending[id]
    if p then pending[id] = nil; p:resolve(response or {ok=false,error='empty'}) end
end)

local function notify(msg, kind, desc)
    local title = tostring(msg or '')
    local body = desc and tostring(desc) or nil
    local ok = pcall(function()
        exports['streetkings']:ShowNotification({ title=title, description=body, type=kind or 'info', duration=4500, inCinematic=true })
    end)
    if not ok then
        pcall(function()
            BeginTextCommandThefeedPost('STRING')
            AddTextComponentSubstringPlayerName(body and (title .. ' - ' .. body) or title)
            EndTextCommandThefeedPostTicker(false, false)
        end)
    end
end

local function unregisterApp()
    if registered then
        pcall(function() exports['streetkings']:UnregisterTabletApp(APP.id) end)
        registered = false
        print(('[ce_skadmin] tablet app unregistered: %s'):format(APP.id))
    end
end

local function checkAuth()
    return rpc('auth', {}, 5000)
end

local function safeRegister()
    local auth = checkAuth()
    if not auth or not auth.ok then
        unregisterApp()
        return false
    end
    if registered then return true end
    local ok, resultOrReason = pcall(function() return exports['streetkings']:RegisterTabletApp(APP) end)
    if ok and resultOrReason ~= false then
        registered = true
        print(('[ce_skadmin] secure tablet app registered for admin: %s'):format(APP.id))
        return true
    end
    print(('[ce_skadmin] tablet app register failed: %s'):format(tostring(resultOrReason)))
    return false
end

RegisterCommand(Config.Command, function()
    local auth = checkAuth()
    if not auth or not auth.ok then
        notify('No tienes permiso para Admin.', 'error')
        unregisterApp()
        return
    end

    safeRegister()

    if Config.Security and Config.Security.AllowCommandOpen == false then
        notify('Abre Admin desde el icono de la tablet.', 'info')
        return
    end

    exports['streetkings']:OpenTabletApp(APP.id, { tab='dashboard', fromCommand=true })
end, false)
RegisterKeyMapping(Config.Command, 'Abrir StreetKings Admin Tablet', 'keyboard', Config.OpenKey or 'F10')

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then
        SetTimeout(1500, safeRegister)
        CreateThread(function()
            while true do
                Wait(30000)
                local auth = checkAuth()
                if auth and auth.ok then
                    if not registered then safeRegister() end
                else
                    sessionToken = nil
                    sessionExpiresAt = 0
                    unregisterApp()
                end
            end
        end)
    end
end)
AddEventHandler('onClientResourceStop', function(res)
    if res == GetCurrentResourceName() then unregisterApp() end
end)

local function jgVehicleStudioImages(model)
    local out = {}
    model = tostring(model or ''):lower()
    if model == '' then return out end
    local cfg = Config.VehicleImages or {}
    if cfg.Enabled == false or cfg.UseJgVehicleStudioExport == false then return out end
    local resource = cfg.JgResource or 'jg-vehiclestudio'

    local ok1, image = pcall(function()
        if cfg.DefaultImageSet and cfg.DefaultImageSet ~= '' then
            return exports[resource]:getImage(model, cfg.DefaultImageSet)
        end
        return exports[resource]:getImage(model)
    end)
    if ok1 and type(image) == 'string' and image ~= '' then
        out[#out + 1] = image
    end

    local ok2, images = pcall(function()
        return exports[resource]:getImages(model)
    end)
    if ok2 then
        if type(images) == 'table' then
            for _, value in pairs(images) do
                if type(value) == 'string' and value ~= '' then
                    out[#out + 1] = value
                elseif type(value) == 'table' then
                    local url = value.url or value.image or value.src
                    if type(url) == 'string' and url ~= '' then out[#out + 1] = url end
                end
            end
        elseif type(images) == 'string' and images ~= '' then
            out[#out + 1] = images
        end
    end

    local seen, unique = {}, {}
    for _, url in ipairs(out) do
        if not seen[url] then seen[url] = true; unique[#unique + 1] = url end
    end
    return unique
end

local function buildImageSources(model)
    local out = {}
    model = tostring(model or ''):lower()
    if model == '' then return out end
    if imageSourceCache[model] then return imageSourceCache[model] end
    local cfg = Config.VehicleImages or {}
    if cfg.Enabled == false then return out end

    for _, url in ipairs(jgVehicleStudioImages(model)) do out[#out + 1] = url end

    for _, tpl in ipairs(cfg.Sources or {}) do
        if type(tpl) == 'string' then
            local ok, path = pcall(string.format, tpl, model)
            out[#out+1] = ok and path or tpl
        end
    end

    local seen, unique = {}, {}
    for _, url in ipairs(out) do
        if type(url) == 'string' and url ~= '' and not seen[url] then
            seen[url] = true
            unique[#unique + 1] = url
        end
    end
    imageSourceCache[model] = unique
    return unique
end

local function parseStreetKingsGameVehicles()
    local raw = ''
    if LoadResourceFile then raw = LoadResourceFile('streetkings', 'data/game_vehicles.lua') or '' end
    local byModel = {}
    local order = {}
    local currentDealer = nil
    local inside = false

    local function push(model, price, className, dealerType, displayName, brand, vehicleType)
        model = tostring(model or ''):lower()
        if model == '' or byModel[model] then return end
        byModel[model] = {
            model = model,
            price = tonumber(price) or 0,
            class = tostring(className or 'C'),
            dealerType = dealerType or 'streetkings',
            displayName = displayName,
            brand = brand,
            vehicleType = vehicleType
        }
        order[#order + 1] = model
    end

    -- Starter cars are not inside SKGameVehicles but still belong to StreetKings progression.
    for line in raw:gmatch('[^\r\n]+') do
        local m = line:match("model%s*=%s*'([^']+)'")
        if line:find('SKStarterVehicles') then inside = false end
        if m and line:find('displayName') and line:find('value') then
            local display = line:match("displayName%s*=%s*'([^']+)'")
            local brand = line:match("brand%s*=%s*'([^']*)'")
            local vtype = line:match("vehicleType%s*=%s*'([^']+)'")
            local value = line:match('value%s*=%s*(%d+)')
            local className = line:match("class%s*=%s*'([^']+)'") or 'STARTER'
            push(m, value, className, 'starter', display, brand, vtype)
        end
    end

    inside = false
    for line in raw:gmatch('[^\r\n]+') do
        if line:find('SKGameVehicles%s*=%s*{') then inside = true end
        if inside then
            local dealer = line:match('^%s*([%w_]+)%s*=%s*{%s*$')
            if dealer and dealer ~= 'SKGameVehicles' then currentDealer = dealer end
            local model = line:match("model%s*=%s*'([^']+)'")
            if currentDealer and model then
                local price = line:match('price%s*=%s*(%d+)')
                local className = line:match("class%s*=%s*'([^']+)'") or 'C'
                local commentName = line:match('%-%-%s*(.+)$')
                push(model, price, className, currentDealer, commentName)
            end
        end
    end
    return byModel, order
end

local function vehicleCatalog()
    if vehicleCatalogCache then return vehicleCatalogCache end
    local ok, data = pcall(function() return exports['streetkings']:GetAllVehicleData() end)
    local skByModel, skOrder = parseStreetKingsGameVehicles()
    local list = {}
    local dealerLabels = Config.VehicleCatalog and Config.VehicleCatalog.DealerLabels or {}

    local function enrich(model, meta)
        model = tostring(model or ''):lower()
        local v = ok and type(data) == 'table' and data[model] or nil
        local name = meta.displayName or (v and (v.name or v.displayName)) or model
        local brand = meta.brand or (v and v.brand) or ''
        list[#list + 1] = {
            model = model,
            name = name,
            displayName = name,
            brand = brand,
            price = meta.price or (v and (v.price or v.value)) or 0,
            category = meta.dealerType or (v and v.category) or 'streetkings',
            dealerType = meta.dealerType or 'streetkings',
            dealerLabel = dealerLabels[meta.dealerType or ''] or meta.dealerType or 'StreetKings',
            class = meta.class or (v and v.class) or 'C',
            type = meta.vehicleType or (v and (v.type or v.vehicleType)) or 'automobile',
            hash = v and v.hash or nil,
            imageSources = buildImageSources(model)
        }
        list[#list].imageUrl = list[#list].imageSources and list[#list].imageSources[1] or nil
    end

    for _, model in ipairs(skOrder) do enrich(model, skByModel[model]) end

    -- Fallback / merge: GetAllVehicleData may be a map or an array depending on build.
    if ok and type(data) == 'table' then
        local added = {}
        for _, row in ipairs(list) do added[tostring(row.model or ''):lower()] = true end
        for key, v in pairs(data) do
            if type(v) == 'table' then
                local model = tostring(v.model or v.modelName or key or ''):lower()
                if model ~= '' and not added[model] then
                    local dealerType = tostring(v.dealerType or v.dealer or v.category or 'other')
                    list[#list + 1] = {
                        model = model,
                        name = v.name or v.displayName or model,
                        displayName = v.name or v.displayName or model,
                        brand = v.brand or '',
                        price = v.price or v.value or 0,
                        category = dealerType,
                        dealerType = dealerType,
                        dealerLabel = dealerLabels[dealerType] or dealerType,
                        class = v.class or v.performanceClass or v.vehicleClass or 'OTHER',
                        type = v.type or v.vehicleType or 'automobile',
                        hash = v.hash,
                        imageSources = buildImageSources(model)
                    }
                    list[#list].imageUrl = list[#list].imageSources and list[#list].imageSources[1] or nil
                    added[model] = true
                end
            end
        end
    end

    local classOrder = Config.VehicleCatalog and Config.VehicleCatalog.ClassOrder or { 'STARTER', 'C', 'B', 'A', 'S' }
    local classRank = {}; for i, c in ipairs(classOrder) do classRank[c] = i end
    local dealerOrder = Config.VehicleCatalog and Config.VehicleCatalog.DealerOrder or {}
    local dealerRank = {}; for i, c in ipairs(dealerOrder) do dealerRank[c] = i end

    table.sort(list, function(a, b)
        local ca, cb = classRank[a.class] or 99, classRank[b.class] or 99
        if ca ~= cb then return ca < cb end
        local da, db = dealerRank[a.dealerType] or 99, dealerRank[b.dealerType] or 99
        if da ~= db then return da < db end
        return tostring(a.name) < tostring(b.name)
    end)

    vehicleCatalogCache = list
    return list
end


local function mergeCatalogWithLocal(serverCatalog)
    local localCatalog = vehicleCatalog()
    local byModel = {}
    local out = {}

    local function addOrMerge(row, preferServer)
        if type(row) ~= 'table' then return end
        local model = tostring(row.model or row.modelName or ''):lower()
        if model == '' then return end
        local existing = byModel[model]
        if not existing then
            local copy = {}
            for k, v in pairs(row) do copy[k] = v end
            copy.model = model
            byModel[model] = copy
            out[#out + 1] = copy
            existing = copy
        else
            for k, v in pairs(row) do
                if v ~= nil and v ~= '' and (preferServer or existing[k] == nil or existing[k] == '') then
                    existing[k] = v
                end
            end
        end

        local imgs = {}
        local function pushImages(src)
            if type(src) == 'string' and src ~= '' then imgs[#imgs + 1] = src end
            if type(src) == 'table' then
                for _, url in ipairs(src) do if type(url) == 'string' and url ~= '' then imgs[#imgs + 1] = url end end
            end
        end
        pushImages(existing.imageUrl)
        pushImages(existing.imageSources)
        pushImages(row.imageUrl)
        pushImages(row.imageSources)
        pushImages(buildImageSources(model))
        local seen, unique = {}, {}
        for _, url in ipairs(imgs) do
            if not seen[url] then seen[url] = true; unique[#unique + 1] = url end
        end
        existing.imageSources = unique
        existing.imageUrl = unique[1]
    end

    for _, row in ipairs(serverCatalog or {}) do addOrMerge(row, true) end
    for _, row in ipairs(localCatalog or {}) do addOrMerge(row, false) end
    return out
end

local function tokenPayload(data)
    data = type(data)=='table' and data or {}
    data._token = sessionToken
    return data
end

local function openLocalSession(route)
    local auth = checkAuth()
    if not auth or not auth.ok then
        sessionToken = nil
        sessionExpiresAt = 0
        unregisterApp()
        return { ok=false, error='not_authorized' }
    end
    if not registered then safeRegister() end
    local res = rpc('openSession', { appId = APP.id, fromTabletFrame = true, route = route or {} }, 5000)
    if res and res.ok and res.token then
        sessionToken = res.token
        sessionExpiresAt = nowMs() + tonumber(res.ttlMs or (Config.Security and Config.Security.SessionTtlMs) or 300000)
        return res
    end
    sessionToken = nil
    sessionExpiresAt = 0
    return res or { ok=false, error='session_failed' }
end

local function ensureLocalSession(cb)
    if not sessionToken or sessionExpiresAt <= nowMs() then
        local res = openLocalSession({ refresh = true })
        if not res or not res.ok then
            cb(res or { ok=false, error='no_admin_tablet_session' })
            return false
        end
    end
    return true
end

RegisterNUICallback('skAdminBoot', function(data, cb)
    data = type(data) == 'table' and data or {}

    -- The HTML already hides itself when it is not inside the tablet iframe.
    -- Server still checks admin permission and all later calls need a session token.
    local res = openLocalSession(data.route or {})
    if res and res.ok then
        cb({ ok=true, token=sessionToken, ttlMs=res.ttlMs, auth=res.auth })
    else
        cb(res or {ok=false,error='session_failed'})
    end
end)

RegisterNUICallback('skAdminGetData', function(data, cb)
    if not ensureLocalSession(cb) then return end
    local res = rpc('getData', tokenPayload(data), 9000)
    if res and res.ok then
        res.catalog = mergeCatalogWithLocal(res.catalog or {})
        res.localStates = localStates
    end
    cb(res or {ok=false,error='no_response'})
end)
RegisterNUICallback('skAdminAction', function(data, cb)
    if not ensureLocalSession(cb) then return end
    local res = rpc('action', tokenPayload(data), 12000)
    cb(res or {ok=false,error='no_response'})
end)
RegisterNUICallback('skAdminGarage', function(data, cb)
    if not ensureLocalSession(cb) then return end
    local res = rpc('getTargetGarage', tokenPayload(data), 9000)
    cb(res or {ok=false,error='no_response'})
end)

local function getPlayerVehicleSafe()
    local veh
    local ok, skVeh = pcall(function() return exports['streetkings']:GetPlayerVehicle() end)
    if ok and skVeh and skVeh ~= 0 and DoesEntityExist(skVeh) then veh=skVeh end
    if not veh then
        local ped=PlayerPedId(); if IsPedInAnyVehicle(ped,false) then local v=GetVehiclePedIsIn(ped,false); if v and v~=0 and DoesEntityExist(v) then veh=v end end
    end
    return veh
end
local function teleportTo(coords)
    if type(coords)~='table' then return end
    local x,y,z,h=tonumber(coords.x),tonumber(coords.y),tonumber(coords.z),tonumber(coords.h) or 0.0
    if not x or not y or not z then return end
    local ok=pcall(function() exports['streetkings']:WarpPlayer(vector3(x,y,z),h) end)
    if not ok then SetEntityCoordsNoOffset(PlayerPedId(),x,y,z+0.3,false,false,false); SetEntityHeading(PlayerPedId(),h) end
end
local function setSpectate(target)
    target=tonumber(target); if not target then return end
    if localStates.spectating then NetworkSetInSpectatorMode(false, PlayerPedId()); localStates.spectating=false; notify('Spectate OFF','info'); return end
    local player=GetPlayerFromServerId(target); if player==-1 or not NetworkIsPlayerActive(player) then notify('Jugador no disponible para spectate','error'); return end
    local ped=GetPlayerPed(player); if not ped or ped==0 or not DoesEntityExist(ped) then notify('Ped no disponible','error'); return end
    NetworkSetInSpectatorMode(true,ped); localStates.spectating=true; notify('Spectate ON','success')
end
local function runVehicleAction(action)
    if action=='vehicle.warpwp' then local ok,a,b=pcall(function() return exports['streetkings']:WarpToWaypoint() end); notify((ok and a) and 'Warp al waypoint OK' or tostring(b or 'No se pudo warp'), (ok and a) and 'success' or 'error'); return end
    if action=='vehicle.speedometer' then localStates.speedometer=not localStates.speedometer; pcall(function() exports['streetkings']:SetSpeedometerEnabled(localStates.speedometer) end); notify('Velocímetro '..(localStates.speedometer and 'ON' or 'OFF'),'success'); return end
    if action=='vehicle.soundtrack' then localStates.soundtrack=not localStates.soundtrack; pcall(function() exports['streetkings']:SetSoundtrackEnabled(localStates.soundtrack) end); notify('Música '..(localStates.soundtrack and 'ON' or 'OFF'),'success'); return end
    if action=='vehicle.cinematic' then localStates.cinematic=not localStates.cinematic; pcall(function() exports['streetkings']:SetCinematicMode(localStates.cinematic) end); notify('Cine '..(localStates.cinematic and 'ON' or 'OFF'),'success'); return end
    if action=='vehicle.exitlock' then localStates.exitlock=not localStates.exitlock; pcall(function() exports['streetkings']:AllowLeaveVehicle(localStates.exitlock) end); notify(localStates.exitlock and 'Salir vehículo permitido' or 'Bloqueo restaurado','success'); return end
    local veh=getPlayerVehicleSafe(); if not veh then notify('Sin vehículo local','error'); return end
    if action=='vehicle.repair' then SetVehicleFixed(veh); SetVehicleDeformationFixed(veh); SetVehicleEngineHealth(veh,1000.0); SetVehicleDirtLevel(veh,0.0); notify('Vehículo reparado','success') end
    if action=='vehicle.clean' then SetVehicleDirtLevel(veh,0.0); WashDecalsFromVehicle(veh,1.0); notify('Vehículo limpio','success') end
    if action=='vehicle.flip' then local c=GetEntityCoords(veh); SetEntityCoordsNoOffset(veh,c.x,c.y,c.z+0.8,false,false,false); SetEntityRotation(veh,0,0,GetEntityHeading(veh),2,true); SetVehicleOnGroundProperly(veh); notify('Vehículo volteado','success') end
end



-- WebRTC live spectator bridge -------------------------------------------------
RegisterNetEvent('ce_skadmin:client:liveStart', function(payload)
    payload = type(payload) == 'table' and payload or {}
    SendNUIMessage({
        type = 'ceSkAdminLiveStart',
        sessionId = payload.sessionId,
        admin = payload.admin,
        width = payload.width,
        height = payload.height,
        fps = payload.fps,
        iceConfig = payload.iceConfig
    })
end)

RegisterNetEvent('ce_skadmin:client:liveSignal', function(sessionId, signal)
    SendNUIMessage({
        type = 'ceSkAdminLiveSignal',
        sessionId = sessionId,
        signal = signal or {}
    })
end)

RegisterNetEvent('ce_skadmin:client:liveStop', function(sessionId, reason)
    SendNUIMessage({
        type = 'ceSkAdminLiveStop',
        sessionId = sessionId,
        reason = reason or 'stopped'
    })
end)

RegisterNUICallback('skAdminLiveStart', function(data, cb)
    if not ensureLocalSession(cb) then return end
    local res = rpc('liveStart', tokenPayload(data), 9000)
    cb(res or { ok=false, error='no_response' })
end)

RegisterNUICallback('skAdminLiveSignal', function(data, cb)
    if not ensureLocalSession(cb) then return end
    local res = rpc('liveSignal', tokenPayload(data), 9000)
    cb(res or { ok=false, error='no_response' })
end)

RegisterNUICallback('skAdminLivePoll', function(data, cb)
    if not ensureLocalSession(cb) then return end
    local res = rpc('livePoll', tokenPayload(data), 9000)
    cb(res or { ok=false, error='no_response' })
end)

RegisterNUICallback('skAdminLiveStop', function(data, cb)
    if not ensureLocalSession(cb) then return end
    local res = rpc('liveStop', tokenPayload(data), 9000)
    cb(res or { ok=false, error='no_response' })
end)

RegisterNUICallback('skAdminHiddenLiveSignal', function(data, cb)
    data = type(data) == 'table' and data or {}
    TriggerServerEvent('ce_skadmin:server:hiddenLiveSignal', tostring(data.sessionId or ''), data.signal or {})
    cb({ ok=true })
end)

-- Legacy screenshot capture removed. Live uses hidden WebGL + WebRTC only.

RegisterNetEvent('ce_skadmin:client:adminDirectMessage', function(data)
    data = type(data) == 'table' and data or {}
    local sender = tostring(data.sender or 'Admin')
    local body = tostring(data.body or '')
    if body == '' then return end
    notify(sender, 'info', body)
    pcall(function()
        TriggerEvent('chat:addMessage', { color = {255, 204, 45}, multiline = true, args = { sender, body } })
    end)
end)

RegisterNetEvent('ce_skadmin:client:runTabletAction', function(data)
    data = type(data)=='table' and data or {}; local action=tostring(data.action or '')
    if action=='player.goto' or action=='player.bring' then teleportTo(data.coords)
    elseif action=='player.spectate' then setSpectate(data.target)
    elseif action=='player.freeze' then localStates.frozen=data.state==true; local ped=PlayerPedId(); FreezeEntityPosition(ped,localStates.frozen); local veh=getPlayerVehicleSafe(); if veh then FreezeEntityPosition(veh,localStates.frozen) end; notify(localStates.frozen and 'Congelado' or 'Descongelado', localStates.frozen and 'error' or 'success')
    elseif action=='player.revive' then local ped=PlayerPedId(); local c=GetEntityCoords(ped); if IsEntityDead(ped) then NetworkResurrectLocalPlayer(c.x,c.y,c.z,GetEntityHeading(ped),true,false) end; SetEntityHealth(PlayerPedId(),200); notify('Revivido','success')
    elseif action=='player.heal' then SetEntityHealth(PlayerPedId(),200); notify('Curado','success')
    elseif action=='player.armor' then SetPedArmour(PlayerPedId(), tonumber(data.armor or data.amount) or Config.Defaults.armor); notify('Chaleco aplicado','success')
    elseif action=='player.kill' then SetEntityHealth(PlayerPedId(),0)
    elseif action:find('^vehicle%.') then runVehicleAction(action)
    elseif action=='phone.toggle' then local open=false; pcall(function() open=exports['streetkings']:IsPhoneOpen() end); if open then pcall(function() exports['streetkings']:ClosePhone() end) else pcall(function() exports['streetkings']:OpenPhone({from='admin'}) end) end
    end
end)
