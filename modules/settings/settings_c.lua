SKSettings = {}

local function awaitDebugToolsPermission()
    return lib.callback.await('phone:settings:hasPermission', false) == true
end
exports('awaitDebugToolsPermission', awaitDebugToolsPermission)

---@param cb fun(result: table)
---@return boolean
local function requireDebugToolsPermission(cb)
    if not awaitDebugToolsPermission() then
        SKNotify({ type = 'error', title = 'Not allowed' })
        cb({ ok = false, reason = 'not_authorized' })
        return false
    end
    return true
end

local GENERAL_DEFAULTS = {
    checkpointSound = '1',
    messageNotificationSound = '1',
    controllerGlyphStyle = 'xbox',
    mapWaypointMode = 'wholeRoute',
    speedometerStyle = 'analog',
    speedometerScale = '100',
    speedometerShakeEnabled = true,
    musicDisabled = false,
    nametagsEnabled = true,
    ownNametagEnabled = true,
    soundtrackEnabled = true,
    soundtrackNowPlayingUiEnabled = false,
    soundtrackNowPlayingUiAlwaysVisible = false,
}

local CHECKPOINT_SOUNDSET = 'sk_soundset'
local CHECKPOINT_SOUND_KVP = 'sk_general_checkpointSound'
local MESSAGE_NOTIFICATION_SOUND_KVP = 'sk_general_messageNotificationSound'
local CONTROLLER_GLYPH_STYLE_KVP = 'sk_general_controllerGlyphStyle'
local MAP_WAYPOINT_MODE_KVP = 'sk_general_mapWaypointMode'
local SPEEDOMETER_STYLE_KVP = 'sk_general_speedometerStyle'
local SPEEDOMETER_SCALE_KVP = 'sk_general_speedometerScale'
local SPEEDOMETER_SHAKE_ENABLED_KVP = 'sk_general_speedometerShakeEnabled'
local NAMETAGS_ENABLED_KVP = 'sk_general_nametagsEnabled'
local OWN_NAMETAG_ENABLED_KVP = 'sk_general_ownNametagEnabled'
local MUSIC_DISABLED_KVP = 'sk_general_musicDisabled'
local SOUNDTRACK_ENABLED_KVP = 'sk_general_soundtrackEnabled'
local SOUNDTRACK_NOW_PLAYING_UI_ENABLED_KVP = 'sk_general_soundtrackNowPlayingUiEnabled'
local SOUNDTRACK_NOW_PLAYING_UI_ALWAYS_VISIBLE_KVP = 'sk_general_soundtrackNowPlayingUiAlwaysVisible'
local CHECKPOINT_SOUNDS = {
    ['1'] = 'checkpoint1',
    ['2'] = 'checkpoint2',
    ['3'] = 'checkpoint3',
    ['4'] = 'checkpoint4',
}
local MESSAGE_NOTIFICATION_SOUNDS = {
    ['1'] = 'new_notification1',
    ['2'] = 'new_notification2',
    ['3'] = 'new_notification3',
    ['4'] = 'new_notification4',
}

local generalConfig = {}

-- Settings validation helpers
local function isValidCheckpointSound(value) return value == 'off' or value == '1' or value == '2' or value == '3' or value == '4' end
local function isValidMessageNotificationSound(value) return value == 'off' or value == '1' or value == '2' or value == '3' or value == '4' end
local function isValidControllerGlyphStyle(value) return value == 'xbox' or value == 'ps5' end
local function isValidMapWaypointMode(value) return value == 'wholeRoute' or value == 'nextCheckpoint' end
local function isValidSpeedometerStyle(value) return value == 'digital' or value == 'analog' end
local function isValidSpeedometerScale(value) return value == '100' or value == '125' or value == '150' end

---@param value string|nil
---@return boolean|nil
local function parseBooleanKvp(value)
    if value == 'true' then
        return true
    end
    if value == 'false' then
        return false
    end
    return nil
end

local function loadGeneralConfig()
    local checkpointSound = GetResourceKvpString(CHECKPOINT_SOUND_KVP)
    if isValidCheckpointSound(checkpointSound) then
        generalConfig.checkpointSound = checkpointSound
    else
        generalConfig.checkpointSound = GENERAL_DEFAULTS.checkpointSound
    end

    local messageNotificationSound = GetResourceKvpString(MESSAGE_NOTIFICATION_SOUND_KVP)
    if isValidMessageNotificationSound(messageNotificationSound) then
        generalConfig.messageNotificationSound = messageNotificationSound
    else
        generalConfig.messageNotificationSound = GENERAL_DEFAULTS.messageNotificationSound
    end

    local controllerGlyphStyle = GetResourceKvpString(CONTROLLER_GLYPH_STYLE_KVP)
    if isValidControllerGlyphStyle(controllerGlyphStyle) then
        generalConfig.controllerGlyphStyle = controllerGlyphStyle
    else
        generalConfig.controllerGlyphStyle = GENERAL_DEFAULTS.controllerGlyphStyle
    end

    local mapWaypointMode = GetResourceKvpString(MAP_WAYPOINT_MODE_KVP)
    if isValidMapWaypointMode(mapWaypointMode) then
        generalConfig.mapWaypointMode = mapWaypointMode
    else
        generalConfig.mapWaypointMode = GENERAL_DEFAULTS.mapWaypointMode
    end

    local speedometerStyle = GetResourceKvpString(SPEEDOMETER_STYLE_KVP)
    if isValidSpeedometerStyle(speedometerStyle) then
        generalConfig.speedometerStyle = speedometerStyle
    else
        generalConfig.speedometerStyle = GENERAL_DEFAULTS.speedometerStyle
    end

    local speedometerScale = GetResourceKvpString(SPEEDOMETER_SCALE_KVP)
    if isValidSpeedometerScale(speedometerScale) then
        generalConfig.speedometerScale = speedometerScale
    else
        generalConfig.speedometerScale = GENERAL_DEFAULTS.speedometerScale
    end

    local speedometerShakeEnabled = parseBooleanKvp(GetResourceKvpString(SPEEDOMETER_SHAKE_ENABLED_KVP))
    if speedometerShakeEnabled == nil then
        generalConfig.speedometerShakeEnabled = GENERAL_DEFAULTS.speedometerShakeEnabled
    else
        generalConfig.speedometerShakeEnabled = speedometerShakeEnabled
    end

    local nametagsEnabled = parseBooleanKvp(GetResourceKvpString(NAMETAGS_ENABLED_KVP))
    if nametagsEnabled == nil then
        generalConfig.nametagsEnabled = GENERAL_DEFAULTS.nametagsEnabled
    else
        generalConfig.nametagsEnabled = nametagsEnabled
    end

    local ownNametagEnabled = parseBooleanKvp(GetResourceKvpString(OWN_NAMETAG_ENABLED_KVP))
    if ownNametagEnabled == nil then
        generalConfig.ownNametagEnabled = GENERAL_DEFAULTS.ownNametagEnabled
    else
        generalConfig.ownNametagEnabled = ownNametagEnabled
    end

    local musicDisabled = parseBooleanKvp(GetResourceKvpString(MUSIC_DISABLED_KVP))
    if musicDisabled == nil then
        generalConfig.musicDisabled = GENERAL_DEFAULTS.musicDisabled
    else
        generalConfig.musicDisabled = musicDisabled
    end

    local soundtrackEnabled = parseBooleanKvp(GetResourceKvpString(SOUNDTRACK_ENABLED_KVP))
    if soundtrackEnabled == nil then
        generalConfig.soundtrackEnabled = GENERAL_DEFAULTS.soundtrackEnabled
    else
        generalConfig.soundtrackEnabled = soundtrackEnabled
    end

    local soundtrackNowPlayingUiEnabled = parseBooleanKvp(GetResourceKvpString(SOUNDTRACK_NOW_PLAYING_UI_ENABLED_KVP))
    if soundtrackNowPlayingUiEnabled == nil then
        generalConfig.soundtrackNowPlayingUiEnabled = GENERAL_DEFAULTS.soundtrackNowPlayingUiEnabled
    else
        generalConfig.soundtrackNowPlayingUiEnabled = soundtrackNowPlayingUiEnabled
    end

    local soundtrackNowPlayingUiAlwaysVisible = parseBooleanKvp(GetResourceKvpString(SOUNDTRACK_NOW_PLAYING_UI_ALWAYS_VISIBLE_KVP))
    if soundtrackNowPlayingUiAlwaysVisible == nil then
        generalConfig.soundtrackNowPlayingUiAlwaysVisible = GENERAL_DEFAULTS.soundtrackNowPlayingUiAlwaysVisible
    else
        generalConfig.soundtrackNowPlayingUiAlwaysVisible = soundtrackNowPlayingUiAlwaysVisible
    end
end

loadGeneralConfig()

local function pushGeneralConfigToNui()
    SendNUIMessage({
        type = 'settings:generalConfig',
        config = SKSettings.getGeneralConfig(),
    })
end

---@return { checkpointSound: string, messageNotificationSound: string, controllerGlyphStyle: string, mapWaypointMode: string, speedometerStyle: string, speedometerScale: string, speedometerShakeEnabled: boolean, nametagsEnabled: boolean, ownNametagEnabled: boolean, musicDisabled: boolean, soundtrackEnabled: boolean, soundtrackNowPlayingUiEnabled: boolean, soundtrackNowPlayingUiAlwaysVisible: boolean }
function SKSettings.getGeneralConfig()
    return {
        checkpointSound = generalConfig.checkpointSound,
        messageNotificationSound = generalConfig.messageNotificationSound,
        controllerGlyphStyle = generalConfig.controllerGlyphStyle,
        mapWaypointMode = generalConfig.mapWaypointMode,
        speedometerStyle = generalConfig.speedometerStyle,
        speedometerScale = generalConfig.speedometerScale,
        speedometerShakeEnabled = generalConfig.speedometerShakeEnabled,
        nametagsEnabled = generalConfig.nametagsEnabled,
        ownNametagEnabled = generalConfig.ownNametagEnabled,
        musicDisabled = generalConfig.musicDisabled,
        soundtrackEnabled = generalConfig.soundtrackEnabled,
        soundtrackNowPlayingUiEnabled = generalConfig.soundtrackNowPlayingUiEnabled,
        soundtrackNowPlayingUiAlwaysVisible = generalConfig.soundtrackNowPlayingUiAlwaysVisible,
    }
end

---@return boolean
function SKSettings.areNametagsEnabled() return generalConfig.nametagsEnabled end

---@return boolean
function SKSettings.isOwnNametagEnabled() return generalConfig.ownNametagEnabled ~= false end

---@return string
function SKSettings.getMapWaypointMode() return generalConfig.mapWaypointMode end

---@param value string
function SKSettings.playCheckpointSound(value)
    local soundName = CHECKPOINT_SOUNDS[value]
    if not soundName then
        return
    end

    PlaySoundFrontend(-1, soundName, CHECKPOINT_SOUNDSET, true)
end

function SKSettings.playSelectedCheckpointSound()
    SKSettings.playCheckpointSound(generalConfig.checkpointSound)
end

---@param value string
function SKSettings.playMessageNotificationSound(value)
    local soundName = MESSAGE_NOTIFICATION_SOUNDS[value]
    if not soundName then
        return
    end

    PlaySoundFrontend(-1, soundName, CHECKPOINT_SOUNDSET, true)
end

function SKSettings.playSelectedMessageNotificationSound()
    SKSettings.playMessageNotificationSound(generalConfig.messageNotificationSound)
end

---@param key string
---@param value string
---@return boolean
function SKSettings.setGeneralValue(key, value)
    if key == 'checkpointSound' then
        if not isValidCheckpointSound(value) then return false end

        generalConfig.checkpointSound = value
        SetResourceKvp(CHECKPOINT_SOUND_KVP, value)
        return true
    end

    if key == 'messageNotificationSound' then
        if not isValidMessageNotificationSound(value) then return false end

        generalConfig.messageNotificationSound = value
        SetResourceKvp(MESSAGE_NOTIFICATION_SOUND_KVP, value)
        return true
    end

    if key == 'controllerGlyphStyle' then
        if not isValidControllerGlyphStyle(value) then return false end

        generalConfig.controllerGlyphStyle = value
        SetResourceKvp(CONTROLLER_GLYPH_STYLE_KVP, value)
        return true
    end

    if key == 'mapWaypointMode' then
        if not isValidMapWaypointMode(value) then return false end

        generalConfig.mapWaypointMode = value
        SetResourceKvp(MAP_WAYPOINT_MODE_KVP, value)
        return true
    end

    if key == 'speedometerStyle' then
        if not isValidSpeedometerStyle(value) then return false end

        generalConfig.speedometerStyle = value
        SetResourceKvp(SPEEDOMETER_STYLE_KVP, value)
        return true
    end

    if key == 'speedometerScale' then
        if not isValidSpeedometerScale(value) then return false end

        generalConfig.speedometerScale = value
        SetResourceKvp(SPEEDOMETER_SCALE_KVP, value)
        return true
    end

    if key == 'speedometerShakeEnabled' then
        if type(value) ~= 'boolean' then return false end

        generalConfig.speedometerShakeEnabled = value
        SetResourceKvp(SPEEDOMETER_SHAKE_ENABLED_KVP, value and 'true' or 'false')
        return true
    end

    if key == 'nametagsEnabled' then
        if type(value) ~= 'boolean' then return false end

        generalConfig.nametagsEnabled = value
        SetResourceKvp(NAMETAGS_ENABLED_KVP, value and 'true' or 'false')
        return true
    end

    if key == 'ownNametagEnabled' then
        if type(value) ~= 'boolean' then return false end

        generalConfig.ownNametagEnabled = value
        SetResourceKvp(OWN_NAMETAG_ENABLED_KVP, value and 'true' or 'false')
        return true
    end

    if key == 'musicDisabled' then
        if type(value) ~= 'boolean' then return false end

        generalConfig.musicDisabled = value
        SetResourceKvp(MUSIC_DISABLED_KVP, value and 'true' or 'false')
        return true
    end

    if key == 'soundtrackEnabled' then
        if type(value) ~= 'boolean' then return false end

        generalConfig.soundtrackEnabled = value
        SetResourceKvp(SOUNDTRACK_ENABLED_KVP, value and 'true' or 'false')
        return true
    end

    if key == 'soundtrackNowPlayingUiEnabled' then
        if type(value) ~= 'boolean' then return false end

        generalConfig.soundtrackNowPlayingUiEnabled = value
        SetResourceKvp(SOUNDTRACK_NOW_PLAYING_UI_ENABLED_KVP, value and 'true' or 'false')
        return true
    end

    if key == 'soundtrackNowPlayingUiAlwaysVisible' then
        if type(value) ~= 'boolean' then return false end

        generalConfig.soundtrackNowPlayingUiAlwaysVisible = value
        SetResourceKvp(SOUNDTRACK_NOW_PLAYING_UI_ALWAYS_VISIBLE_KVP, value and 'true' or 'false')
        return true
    end

    return false
end

RegisterNUICallback('phone:settings:getGeneralConfig', function(_, cb)
    cb(SKSettings.getGeneralConfig())
end)

RegisterNUICallback('phone:settings:setGeneralValue', function(data, cb)
    local ok = SKSettings.setGeneralValue(data.key, data.value)
    if ok and data.key == 'checkpointSound' and data.preview then
        SKSettings.playCheckpointSound(data.value)
    end
    if ok and data.key == 'messageNotificationSound' and data.preview then
        SKSettings.playMessageNotificationSound(data.value)
    end
    if ok then
        pushGeneralConfigToNui()
    end
    cb(SKSettings.getGeneralConfig())
end)

CreateThread(function()
    Wait(1000)
    pushGeneralConfigToNui()
end)

RegisterNUICallback('phone:settings:isAdmin', function(_, cb)
    cb({ admin = lib.callback.await('phone:settings:isAdmin', false) })
end)

RegisterNUICallback('phone:settings:fixVehicle', function(_, cb)
    if not requireDebugToolsPermission(cb) then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleDirtLevel(veh, 0.0)
        SKNotify({ type = 'success', title = 'Vehicle Repaired' })
    else
        SKNotify({ type = 'warning', title = 'Not In Vehicle' })
    end
    cb({ ok = true })
end)

RegisterNUICallback('phone:settings:clearWanted', function(_, cb)
    if not requireDebugToolsPermission(cb) then return end
    ClearPlayerWantedLevel(PlayerId())
    SKPolice.resetPursuit()
    SKNotify({ type = 'success', title = 'Wanted Level Cleared' })
    cb({ ok = true })
end)

RegisterNUICallback('phone:settings:ditchCar', function(_, cb)
    if not requireDebugToolsPermission(cb) then return end
    local ok = SKFreeroam.debugDitchVehicle()
    if ok then
        SKNotify({ type = 'success', title = 'Vehicle Ditched' })
    else
        SKNotify({ type = 'warning', title = 'Not In Active Vehicle' })
    end
    cb({ ok = ok })
end)

RegisterNUICallback('phone:settings:warpWaypoint', function(_, cb)
    if not requireDebugToolsPermission(cb) then return end
    local ok, message = SKC.WarpToWaypoint()
    if not ok and message then
        SKNotify({ type = 'error', title = message })
    end
    cb({ ok = ok })
end)

RegisterNUICallback('phone:settings:grantCosmeticCurrency', function(_, cb)
    if not requireDebugToolsPermission(cb) then return end
    local result = lib.callback.await('phone:settings:grantCosmeticCurrency', false)
    if result and result.ok then
        SKNotify({ type = 'success', title = ('GearCoins +%d'):format(result.amount) })
        cb({ ok = true, amount = result.amount, balance = result.balance })
        return
    end

    SKNotify({ type = 'error', title = 'Grant Failed' })
    cb({ ok = false })
end)

---@param def table
---@return string
local function getEventTypeLabel(def)
    if def.type == EventType.DELIVERY then
        return 'DELIVERY'
    end
    if def.scheme == CheckpointScheme.CIRCUIT then
        return 'CIRCUIT'
    end
    return 'SPRINT'
end

---@return { id: string, name: string, label: string, eventType: string }[]
local function getEventOptions()
    local events = {}

    for id, def in pairs(SKEvents) do
        if type(def) ~= 'table' or type(def.start) ~= 'vector4' or type(def.name) ~= 'string' or type(def.id) ~= 'string' then
            goto continue
        end

        local eventType = getEventTypeLabel(def)
        events[#events + 1] = {
            id        = id,
            name      = def.name,
            label     = ('%s (%s)'):format(def.name, eventType),
            eventType = eventType,
        }

        ::continue::
    end

    table.sort(events, function(a, b)
        if a.eventType ~= b.eventType then
            return a.eventType < b.eventType
        end
        return a.name < b.name
    end)

    return events
end

---@param target vector4
local function teleportToTarget(target)
    SKPhone.close()
    CreateThread(function()
        Wait(500)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            SetEntityCoords(vehicle, target.x, target.y, target.z, false, false, false, false)
            SetEntityHeading(vehicle, target.w)
        else
            SetEntityCoords(ped, target.x, target.y, target.z, false, false, false, false)
            SetEntityHeading(ped, target.w)
        end
    end)
end

---@param shopTypeKey string
---@return vector4|nil
local function getShopTeleportTarget(shopTypeKey)
    return SKShopShared.getShopTeleportTarget(shopTypeKey)
end

RegisterNUICallback('phone:settings:getEventOptions', function(_, cb)
    if not awaitDebugToolsPermission() then
        cb({ events = {} })
        return
    end
    cb({ events = getEventOptions() })
end)

RegisterNUICallback('phone:settings:openVisualShop', function(_, cb)
    if not requireDebugToolsPermission(cb) then return end
    cb({ ok = true })
    teleportToTarget(getShopTeleportTarget('visual'))
end)

RegisterNUICallback('phone:settings:openPerformanceShop', function(_, cb)
    if not requireDebugToolsPermission(cb) then return end
    cb({ ok = true })
    teleportToTarget(getShopTeleportTarget('performance'))
end)

RegisterNUICallback('phone:settings:openTunerDealership', function(_, cb)
    if not requireDebugToolsPermission(cb) then return end
    cb({ ok = true })
    teleportToTarget(vector4(-53.7626, -1110.3956, 26.1458, 160.0))
end)

RegisterNUICallback('phone:settings:teleportToEvent', function(data, cb)
    if not requireDebugToolsPermission(cb) then return end
    local event = SKEvents[data.eventId]
    if type(event) ~= 'table' or type(event.start) ~= 'vector4' then
        SKNotify({ type = 'error', title = 'Event Not Found' })
        cb({ ok = false })
        return
    end

    cb({ ok = true })
    teleportToTarget(event.start)
end)

RegisterNUICallback('phone:settings:getLevelBounds', function(_, cb)
    cb(lib.callback.await('phone:settings:getLevelBounds', false))
end)

RegisterNUICallback('phone:settings:setVehicleLevel', function(data, cb)
    if not requireDebugToolsPermission(cb) then return end
    local result = lib.callback.await('phone:settings:setVehicleLevel', false, data.level)
    if result and result.ok then
        SKNotify({ type = 'success', title = ('Vehicle Lv. %d set'):format(data.level) })
    else
        SKNotify({ type = 'error', title = 'Set Level Failed' })
    end
    cb(result or { ok = false })
end)

RegisterNUICallback('phone:settings:setPlayerLevel', function(data, cb)
    if not requireDebugToolsPermission(cb) then return end
    local result = lib.callback.await('phone:settings:setPlayerLevel', false, data.level)
    if result and result.ok then
        SKNotify({ type = 'success', title = ('Driver Lv. %d set'):format(data.level) })
    else
        SKNotify({ type = 'error', title = 'Set Level Failed' })
    end
    cb(result or { ok = false })
end)

RegisterNUICallback('phone:settings:setDebugToggle', function(data, cb)
    if not requireDebugToolsPermission(cb) then return end
    if data.key == 'disablePolice' then
        SKPolice.setPoliceDisabled(data.value)
        SKNotify({
            type  = data.value and 'warning' or 'success',
            title = data.value and 'Police Disabled' or 'Police Enabled',
        })
    end
    cb({ ok = true })
end)

RegisterNUICallback('phone:settings:deleteSave', function(_, cb)
    local result = lib.callback.await('phone:settings:deleteSave', false)
    if result.ok then
        SKNotify({ type = 'success', title = 'Save Deleted' })
        cb({ ok = true })
        Wait(1500)
        SKC.SetGameState(GameState.MAIN_MENU)
    else
        SKNotify({ type = 'error', title = 'Delete Failed' })
        cb({ ok = false })
    end
end)
