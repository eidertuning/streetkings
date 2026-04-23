SKAvatar = SKAvatar or {}

local CAM_DIST = 1.65
local CAM_DIST_MIN = 1.2
local CAM_DIST_MAX = 3.4
local CAM_ANGLE_H_DEFAULT = (SKAvatarData.SceneHeading + 180.0) % 360.0
local CAM_ANGLE_V_DEFAULT = 10.0
local CAM_HEIGHT_MIN = -0.75
local CAM_HEIGHT_MAX = 0.35
local CAM_HEIGHT_DEFAULT = 0.13

local avatarCam = nil
local camDist = CAM_DIST
local camAngleH = CAM_ANGLE_H_DEFAULT
local camAngleV = CAM_ANGLE_V_DEFAULT
local camHeight = CAM_HEIGHT_DEFAULT
local avatarScene = nil
local spotlightEnabled = false
local wardrobeMode = false
---@type SKAvatarAccountDocument|nil
local accountState = nil

local enteredFromFreeroam = false
local pendingScene = nil
---@type table|nil Tracks the appearance currently displayed on the ped so heavy setters
local lastAppliedAppearance = nil

---@param a any
---@param b any
---@return boolean
local function tableEq(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do
        if not tableEq(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

---@return integer|nil
local function playerPed()
    return PlayerPedId()
end

---@param value number
---@return number
local function tofloat(value)
    return value + 0.0
end

---@return vector4
local function currentAvatarScene()
    return assert(avatarScene, 'streetkings: missing avatar scene')
end

---@return vector4
local function chooseAvatarScene()
    if pendingScene then
        local s = pendingScene
        return vector4(s.pos.x, s.pos.y, s.pos.z, s.heading)
    end
    local pos = SKAvatarData.ScenePositions[math.random(1, #SKAvatarData.ScenePositions)]
    return vector4(pos.x, pos.y, pos.z, SKAvatarData.SceneHeading)
end

---@param sceneHeading number
---@return number
local function defaultCameraAngleH(sceneHeading)
    return (sceneHeading + 180.0) % 360.0
end

---@param ped integer
---@return boolean
local function isFreemodeModel(ped)
    local model = GetEntityModel(ped)
    return model == `mp_m_freemode_01` or model == `mp_f_freemode_01`
end

---@param model string|integer
---@return integer
local function setPlayerModel(model)
    model = SK.LoadModel(model)
    if not model then return nil end

    SetPlayerModel(PlayerId(), model)
    Wait(150)
    SK.UnloadModel(model)

    local ped = assert(playerPed(), 'streetkings: missing player ped')
    if isFreemodeModel(ped) then
        SetPedDefaultComponentVariation(ped)
        if model == `mp_m_freemode_01` then
            SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
        elseif model == `mp_f_freemode_01` then
            SetPedHeadBlendData(ped, 45, 21, 0, 20, 15, 0, 0.3, 0.1, 0.0, false)
        end
    end

    return ped
end

---@param ped integer
---@param headBlend table
local function setPedHeadBlend(ped, headBlend)
    if not headBlend or not isFreemodeModel(ped) then
        return
    end

    SetPedHeadBlendData(
        ped,
        headBlend.shapeFirst,
        headBlend.shapeSecond,
        headBlend.shapeThird,
        headBlend.skinFirst,
        headBlend.skinSecond,
        headBlend.skinThird,
        tofloat(headBlend.shapeMix),
        tofloat(headBlend.skinMix),
        tofloat(headBlend.thirdMix),
        false
    )
end

---@param ped integer
---@param faceFeatures table
local function setPedFaceFeatures(ped, faceFeatures)
    if not faceFeatures then
        return
    end

    for index, key in ipairs(SKAvatarShared.FACE_FEATURES) do
        SetPedFaceFeature(ped, index - 1, tofloat(faceFeatures[key]))
    end
end

---@param ped integer
---@param headOverlays table
local function setPedHeadOverlays(ped, headOverlays)
    if not headOverlays then
        return
    end

    for index, key in ipairs(SKAvatarShared.HEAD_OVERLAYS) do
        local overlay = headOverlays[key]
        local colorType = (key == 'blush' or key == 'lipstick' or key == 'makeUp') and 2 or 1
        SetPedHeadOverlay(ped, index - 1, overlay.style, tofloat(overlay.opacity))
        SetPedHeadOverlayColor(ped, index - 1, colorType, overlay.color, overlay.secondColor)
    end
end

---@param ped integer
---@param prop table
local function setPedProp(ped, prop)
    if prop.drawable == -1 then
        ClearPedProp(ped, prop.prop_id)
        return
    end
    SetPedPropIndex(ped, prop.prop_id, prop.drawable, prop.texture, false)
end

---@param ped integer
---@param eyeColor integer
local function setPedEyeColor(ped, eyeColor)
    SetPedEyeColor(ped, eyeColor)
end

---@param ped integer
---@param appearance table
local function applyAppearanceToPed(ped, appearance)
    local prev = lastAppliedAppearance

    for _, comp in ipairs(appearance.components) do
        local skip = false
        if prev then
            local p = SKAvatarShared.getComponentEntry(prev.components, comp.component_id)
            if p and p.drawable == comp.drawable and p.texture == comp.texture then
                skip = true
            end
        end
        if not skip then
            SetPedComponentVariation(ped, comp.component_id, comp.drawable, comp.texture, 0)
        end
    end

    for _, prop in ipairs(appearance.props) do
        local skip = false
        if prev then
            local p = SKAvatarShared.getPropEntry(prev.props, prop.prop_id)
            if p and p.drawable == prop.drawable and p.texture == prop.texture then
                skip = true
            end
        end
        if not skip then
            setPedProp(ped, prop)
        end
    end

    if not prev or not tableEq(prev.headBlend, appearance.headBlend) then
        setPedHeadBlend(ped, appearance.headBlend)
    end
    if not prev or not tableEq(prev.faceFeatures, appearance.faceFeatures) then
        setPedFaceFeatures(ped, appearance.faceFeatures)
    end
    if not prev or not tableEq(prev.headOverlays, appearance.headOverlays) then
        setPedHeadOverlays(ped, appearance.headOverlays)
    end

    if not prev
        or prev.hair.color ~= appearance.hair.color
        or prev.hair.highlight ~= appearance.hair.highlight
    then
        SetPedHairColor(ped, appearance.hair.color, appearance.hair.highlight)
    end

    if not prev or prev.eyeColor ~= appearance.eyeColor then
        setPedEyeColor(ped, appearance.eyeColor)
    end

    lastAppliedAppearance = SKAvatarShared.clone(appearance)
end

---@param appearance table
local function applyPlayerAppearance(appearance)
    local ped = playerPed()
    if GetEntityModel(ped) ~= joaat(appearance.model) then
        lastAppliedAppearance = nil
        ped = setPlayerModel(appearance.model)
    end
    applyAppearanceToPed(ped, appearance)
end

---@return SKAvatarAccountDocument
local function activeAccount()
    return assert(accountState, 'streetkings: avatar account state not loaded')
end

---@return SKAvatarAppearanceDocument
local function activeAppearance()
    local account = activeAccount()
    return account.appearances[account.activeGender]
end

---@param kind string
---@return table[]
local function categoryList(kind)
    local categories = {}
    for _, category in ipairs(SKAvatarData.ClothingCategories) do
        if category.kind == kind then
            categories[#categories + 1] = category
        end
    end
    return categories
end

---@param category table
---@param drawable integer
---@return integer
local function textureCountFor(category, drawable)
    local ped = playerPed()
    if category.kind == 'component' then
        return GetNumberOfPedTextureVariations(ped, category.slot, drawable)
    end
    if drawable == -1 then
        return 0
    end
    return GetNumberOfPedPropTextureVariations(ped, category.slot, drawable)
end

---@param category table
---@return integer
local function drawableCountFor(category)
    local ped = playerPed()
    if category.kind == 'component' then
        return GetNumberOfPedDrawableVariations(ped, category.slot)
    end
    return GetNumberOfPedPropDrawableVariations(ped, category.slot)
end

---@param category table
---@return table
local function categoryState(category)
    local account = activeAccount()
    local appearance = activeAppearance()
    local owned = account.ownedClothing[account.activeGender][category.key]
    local entry
    if category.kind == 'component' then
        entry = assert(SKAvatarShared.getComponentEntry(appearance.components, category.slot), 'streetkings: missing component entry')
    else
        entry = assert(SKAvatarShared.getPropEntry(appearance.props, category.slot), 'streetkings: missing prop entry')
    end

    local drawableCount = drawableCountFor(category)
    local textureCount = textureCountFor(category, entry.drawable)
    return {
        key = category.key,
        kind = category.kind,
        slot = category.slot,
        label = category.label,
        price = category.price,
        drawable = entry.drawable,
        texture = entry.texture,
        drawableCount = drawableCount,
        textureCount = textureCount,
        owned = SKAvatarShared.isVariationAutoOwned(category.key, entry.drawable)
            or owned[SKAvatarShared.variationToken(entry.drawable, entry.texture)] == true,
    }
end

---@return table
local function buildNuiState()
    local account = activeAccount()
    local appearance = activeAppearance()
    local overlays = {}
    for _, key in ipairs(SKAvatarShared.HEAD_OVERLAYS) do
        overlays[#overlays + 1] = {
            key = key,
            label = key,
            style = appearance.headOverlays[key].style,
            opacity = appearance.headOverlays[key].opacity,
            styleCount = GetNumHeadOverlayValues(({ ['blemishes'] = 0, ['beard'] = 1, ['eyebrows'] = 2, ['ageing'] = 3, ['makeUp'] = 4, ['blush'] = 5, ['complexion'] = 6, ['sunDamage'] = 7, ['lipstick'] = 8, ['moleAndFreckles'] = 9, ['chestHair'] = 10, ['bodyBlemishes'] = 11 })[key]),
        }
    end

    local clothingCategories = {}
    for _, category in ipairs(categoryList('component')) do
        clothingCategories[#clothingCategories + 1] = categoryState(category)
    end

    local propCategories = {}
    for _, category in ipairs(categoryList('prop')) do
        propCategories[#propCategories + 1] = categoryState(category)
    end

    return {
        mode = wardrobeMode and 'wardrobe' or 'full',
        activeGender = account.activeGender,
        cosmeticCurrency = account.cosmetic_currency,
        appearance = SKAvatarShared.clone(appearance),
        faceFeatures = SKAvatarShared.clone(SKAvatarShared.FACE_FEATURES),
        headOverlays = overlays,
        eyeColorCount = #SKAvatarShared.EYE_COLORS,
        hairColorCount = GetNumHairColors(),
        hairStyleCount = GetNumberOfPedDrawableVariations(playerPed(), 2),
        hairTextureCount = GetNumberOfPedTextureVariations(playerPed(), 2, appearance.hair.style),
        camera = {
            height = camHeight,
            minHeight = CAM_HEIGHT_MIN,
            maxHeight = CAM_HEIGHT_MAX,
            zoom = camDist,
            minZoom = CAM_DIST_MIN,
            maxZoom = CAM_DIST_MAX,
        },
        clothingCategories = clothingCategories,
        propCategories = propCategories,
    }
end

---@param messageType string
local function syncNui(messageType)
    SendNUIMessage({
        type = messageType,
        state = buildNuiState(),
    })
end

local function playPurchaseSound()
    local soundId = GetSoundId()
    PlaySoundFrontend(soundId, 'purchase1', 'sk_soundset', true)
    SetVariableOnSound(soundId, 'volume', 0.2)
    ReleaseSoundId(soundId)
end

---@return boolean
local function loadAccount()
    local result = lib.callback.await('streetkings:avatar:getState', false)
    if not result or not result.ok then
        return false
    end
    accountState = result.account
    return true
end

---@return boolean
function SKAvatar.applyActiveAppearance()
    local result = lib.callback.await('streetkings:avatar:getActiveAppearance', false)
    if not result or not result.ok then
        return false
    end
    accountState = result.account
    applyPlayerAppearance(result.appearance)
    return true
end

---@return nil
function SKAvatar.enterFromMainMenu()
    SKC.SetGameState(GameState.AVATAR)
end

---@param store table
function SKAvatar.enterFromStore(store)
    pendingScene = { pos = store.scene, heading = store.heading }
    enteredFromFreeroam = true
    SKC.SetGameState(GameState.AVATAR)
end

---@param scene vector4  x,y,z,heading
function SKAvatar.enterFromWardrobe(scene)
    pendingScene = { pos = vector3(scene.x, scene.y, scene.z), heading = scene.w }
    wardrobeMode = true
    SKC.SetGameState(GameState.AVATAR)
end

---@param stateId integer
---@return boolean
function SKAvatar.isAvatarState(stateId)
    return stateId == GameState.AVATAR
end

---@param category table
---@param drawable integer
---@param texture integer
---@return integer, integer, integer, boolean
local function normalizePreviewSelection(category, drawable, texture)
    local account = activeAccount()
    local count = drawableCountFor(category)
    local normalizedDrawable
    if category.kind == 'prop' then
        normalizedDrawable = math.max(-1, math.min(count - 1, drawable))
    else
        normalizedDrawable = math.max(0, math.min(count - 1, drawable))
    end

    local maxTextures = textureCountFor(category, normalizedDrawable)
    local normalizedTexture
    if normalizedDrawable == -1 then
        normalizedTexture = -1
    else
        normalizedTexture = math.max(0, math.min(math.max(maxTextures - 1, 0), texture))
    end

    local owned = SKAvatarShared.isVariationAutoOwned(category.key, normalizedDrawable)
        or account.ownedClothing[account.activeGender][category.key][SKAvatarShared.variationToken(normalizedDrawable, normalizedTexture)] == true
    return normalizedDrawable, normalizedTexture, maxTextures, owned
end

---@param category table
---@param drawable integer
---@param texture integer
---@return table
local function previewVariation(category, drawable, texture)
    local normalizedDrawable, normalizedTexture, maxTextures, owned = normalizePreviewSelection(category, drawable, texture)
    local ped = playerPed()
    if category.kind == 'component' then
        SetPedComponentVariation(ped, category.slot, normalizedDrawable, normalizedTexture, 0)
        if category.slot == 2 then
            local appearance = activeAppearance()
            SetPedHairColor(ped, appearance.hair.color, appearance.hair.highlight)
        end
    else
        if normalizedDrawable == -1 then
            ClearPedProp(ped, category.slot)
        else
            SetPedPropIndex(ped, category.slot, normalizedDrawable, normalizedTexture, false)
        end
    end
    return {
        ok = true,
        drawable = normalizedDrawable,
        texture = normalizedTexture,
        textureCount = maxTextures,
        owned = owned,
        price = category.price,
    }
end

---@param categoryKey string
---@return table
local function resetCategoryPreview(categoryKey)
    local category = SKAvatarShared.getCategoryByKey(categoryKey)
    if not category then
        return { ok = false, error = 'invalid_category' }
    end
    local appearance = activeAppearance()
    local savedDrawable, savedTexture
    if category.kind == 'component' then
        local entry = SKAvatarShared.getComponentEntry(appearance.components, category.slot)
---@diagnostic disable-next-line: need-check-nil
        savedDrawable = entry.drawable
---@diagnostic disable-next-line: need-check-nil
        savedTexture  = entry.texture
    else
        local entry = SKAvatarShared.getPropEntry(appearance.props, category.slot)
---@diagnostic disable-next-line: need-check-nil
        savedDrawable = entry.drawable
---@diagnostic disable-next-line: need-check-nil
        savedTexture  = entry.texture
    end
    return previewVariation(category, savedDrawable, savedTexture)
end

---@return nil
local function updateCamera()
    if not avatarCam then
        return
    end

    local ped = playerPed()
    local pos = GetEntityCoords(ped)
    local radH = math.rad(camAngleH)
    local radV = math.rad(camAngleV)
    local focusZ = pos.z + camHeight
    local cx = pos.x + camDist * math.cos(radV) * math.sin(radH)
    local cy = pos.y - camDist * math.cos(radV) * math.cos(radH)
    local cz = focusZ + 0.15 + camDist * math.sin(radV)
    SetCamCoord(avatarCam, cx, cy, cz)
    PointCamAtCoord(avatarCam, pos.x, pos.y, focusZ)
end

SKC.RegisterGameState(GameState.AVATAR, {
    onEnter = function()
        CreateThread(function()
            DoScreenFadeOut(0)
            if not loadAccount() then
                SKC.SetGameState(GameState.MAIN_MENU)
                return
            end

            avatarScene = chooseAvatarScene()
            local scene = currentAvatarScene()
            applyPlayerAppearance(activeAppearance())

            local ped = playerPed()
            SetEntityCoords(ped, scene.x, scene.y, scene.z, false, false, false, false)
            SetEntityHeading(ped, scene.w)
            FreezeEntityPosition(ped, true)
            SetEntityVisible(ped, true, false)
            ClearPedTasksImmediately(ped)

            RequestCollisionAtCoord(scene.x, scene.y, scene.z)
            while not HasCollisionLoadedAroundEntity(ped) do Wait(100) end

            if wardrobeMode then
                SetEntityCoordsNoOffset(ped, scene.x, scene.y, scene.z, false, false, false)
                avatarScene = vector4(scene.x, scene.y, scene.z, scene.w)
            end

            camAngleH = defaultCameraAngleH(scene.w)
            camAngleV = CAM_ANGLE_V_DEFAULT
            camDist = CAM_DIST
            camHeight = CAM_HEIGHT_DEFAULT
            avatarCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            updateCamera()
            SetCamActive(avatarCam, true)
            RenderScriptCams(true, false, 0, true, true)

            SetNuiFocus(true, true)
            syncNui('avatar:open')
            DoScreenFadeIn(500)
        end)
    end,

    onExit = function()
        if accountState then
            applyPlayerAppearance(activeAppearance())
        end

        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'avatar:close' })

        if avatarCam then
            DestroyCam(avatarCam, false)
            avatarCam = nil
        end
        RenderScriptCams(false, false, 0, true, true)

        FreezeEntityPosition(playerPed(), false)
        avatarScene = nil
        enteredFromFreeroam = false
        wardrobeMode = false
        pendingScene = nil
        spotlightEnabled = false
        lastAppliedAppearance = nil
    end,

    onTick = function()
        updateCamera()
        HideHudAndRadarThisFrame()
        DisableAllControlActions(0)

        if spotlightEnabled then
            local ped = playerPed()
            local pos = GetEntityCoords(ped)
            local radH = math.rad(camAngleH)
            local frontX = pos.x + 2.5 * math.sin(radH)
            local frontY = pos.y - 2.5 * math.cos(radH)
            local frontZ = pos.z + 1.8
            local dirX = pos.x - frontX
            local dirY = pos.y - frontY
            local dirZ = (pos.z + 0.3) - frontZ
            local len = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
            DrawSpotLight(frontX, frontY, frontZ, dirX / len, dirY / len, dirZ / len, 255, 245, 230, 4.0, 12.0, 4.0, 28.0, 12.0)
            DrawSpotLight(pos.x, pos.y, pos.z + 3.5, 0.0, 0.0, -1.0, 255, 250, 240, 3.0, 5.0, 2.0, 35.0, 18.0)
        end
    end,

    tickWait = 0,
})

RegisterNUICallback('avatar:cameraRotate', function(data, cb)
    camAngleH = (camAngleH - data.dx * 0.3) % 360
    camAngleV = math.max(-12.0, math.min(28.0, camAngleV + data.dy * 0.3))
    cb({})
end)

RegisterNUICallback('avatar:toggleSpotlight', function(data, cb)
    spotlightEnabled = data.enabled == true
    cb({})
end)

RegisterNUICallback('avatar:setCameraHeight', function(data, cb)
    camHeight = math.max(CAM_HEIGHT_MIN, math.min(CAM_HEIGHT_MAX, tonumber(data.height) or CAM_HEIGHT_DEFAULT))
    updateCamera()
    cb({ ok = true, state = buildNuiState() })
end)

RegisterNUICallback('avatar:cameraZoom', function(data, cb)
    camDist = math.max(CAM_DIST_MIN, math.min(CAM_DIST_MAX, camDist + (tonumber(data.delta) or 0.0)))
    updateCamera()
    cb({ ok = true, state = buildNuiState() })
end)

RegisterNUICallback('avatar:setGender', function(data, cb)
    local result = lib.callback.await('streetkings:avatar:setGender', false, data.gender)
    if not result.ok then
        cb(result)
        return
    end

    accountState = result.account
    applyPlayerAppearance(activeAppearance())
    local scene = currentAvatarScene()
    local ped = playerPed()
    SetEntityCoords(ped, scene.x, scene.y, scene.z, false, false, false, false)
    SetEntityHeading(ped, scene.w)
    FreezeEntityPosition(ped, true)
    syncNui('avatar:sync')
    cb({ ok = true, state = buildNuiState() })
end)

RegisterNUICallback('avatar:updateAppearance', function(data, cb)
    local result = lib.callback.await('streetkings:avatar:saveAppearance', false, data.appearance)
    if not result.ok then
        cb(result)
        return
    end

    accountState = result.account
    applyPlayerAppearance(activeAppearance())
    syncNui('avatar:sync')
    cb({ ok = true, state = buildNuiState() })
end)

RegisterNUICallback('avatar:equipOwnedVariation', function(data, cb)
    local result = lib.callback.await('streetkings:avatar:equipOwnedVariation', false, data.categoryKey, data.drawable, data.texture)
    if not result.ok then
        cb(result)
        return
    end

    accountState = result.account
    applyPlayerAppearance(activeAppearance())
    syncNui('avatar:sync')
    cb({ ok = true, state = buildNuiState() })
end)

RegisterNUICallback('avatar:purchaseClothing', function(data, cb)
    local result = lib.callback.await('streetkings:avatar:purchaseClothing', false, data.categoryKey, data.drawable, data.texture)
    if not result.ok then
        cb(result)
        return
    end

    accountState = result.account
    applyPlayerAppearance(activeAppearance())
    syncNui('avatar:sync')
    if result.purchased then
        playPurchaseSound()
    end
    cb({ ok = true, state = buildNuiState(), purchased = result.purchased })
end)

RegisterNUICallback('avatar:previewVariation', function(data, cb)
    local category = SKAvatarShared.getCategoryByKey(data.categoryKey)
    if not category then
        cb({ ok = false, error = 'invalid_category' })
        return
    end

    cb(previewVariation(category, data.drawable, data.texture))
end)

RegisterNUICallback('avatar:resetCategoryPreview', function(data, cb)
    cb(resetCategoryPreview(data.categoryKey))
end)

RegisterNUICallback('avatar:purchaseCart', function(data, cb)
    local result = lib.callback.await('streetkings:avatar:purchaseCart', false, data.items)
    if not result.ok then
        cb(result)
        return
    end

    accountState = result.account
    applyPlayerAppearance(activeAppearance())
    syncNui('avatar:sync')
    if result.purchasedCount and result.purchasedCount > 0 then
        playPurchaseSound()
    end
    cb({ ok = true, state = buildNuiState(), purchasedCount = result.purchasedCount })
end)

RegisterNUICallback('avatar:exit', function(_, cb)
    cb({})
    if wardrobeMode then
        SKC.SetGameState(GameState.PROPERTY)
    elseif enteredFromFreeroam then
        SKC.SetGameState(GameState.FREEROAM)
    else
        SKC.SetGameState(GameState.MAIN_MENU)
    end
end)