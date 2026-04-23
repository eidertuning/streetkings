SK = {}

---@param model string|number
---@param timeout? integer ms before giving up (default 5000)
---@return integer|nil hash
function SK.LoadModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end
    return hash
end

---@param model string|number
function SK.UnloadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    SetModelAsNoLongerNeeded(hash)
end

---@param dict string
---@param timeout? integer ms before giving up (default 3000)
---@return boolean
function SK.LoadAnimDict(dict, timeout)
    if type(dict) ~= 'string' or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeout or 3000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

---@param set string
---@param timeout? integer ms before giving up (default 3000)
---@return boolean
function SK.LoadAnimSet(set, timeout)
    if type(set) ~= 'string' or set == '' then return false end
    RequestAnimSet(set)
    local deadline = GetGameTimer() + (timeout or 3000)
    while not HasAnimSetLoaded(set) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

---@param asset string
---@param timeout? integer ms before giving up (default 3000)
---@return boolean
function SK.LoadPtfxAsset(asset, timeout)
    if type(asset) ~= 'string' or asset == '' then return false end
    RequestNamedPtfxAsset(asset)
    local deadline = GetGameTimer() + (timeout or 3000)
    while not HasNamedPtfxAssetLoaded(asset) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

---@param vehicle integer
---@return string
function SK.GetVehicleModelLabel(vehicle)
    if not vehicle or vehicle == 0 then return '' end
    local hash = GetEntityModel(vehicle)
    local gxt = GetDisplayNameFromVehicleModel(hash)
    if not gxt or gxt == '' or gxt == 'CARNOTFOUND' then return '' end
    local label = GetLabelText(gxt)
    if not label or label == 'NULL' then return gxt end
    return label
end

exports('LoadModel', SK.LoadModel)
exports('UnloadModel', SK.UnloadModel)
exports('LoadAnimDict', SK.LoadAnimDict)
exports('LoadAnimSet', SK.LoadAnimSet)
exports('LoadPtfxAsset', SK.LoadPtfxAsset)
exports('GetAllVehicleData', function() return SKVehicles end)
exports('GetVehicleData', function(model) return SKVehicles[model] end)