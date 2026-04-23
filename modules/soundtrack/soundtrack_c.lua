SKSoundtrack = SKSoundtrack or {}

local DEFAULT_SOUNDTRACK_DATA_FILE_PATH = 'modules/soundtrack/soundtrack.dat'
local GARAGE_SOUNDTRACK_DATA_FILE_PATH = 'modules/soundtrack/soundtrack_garage.dat'
local SKIP_KEY_COMMAND = 'soundtrack_skip'
local PLAYER_UPDATE_INTERVAL_MS = 100
local TRACK_END_SKIP_BUFFER_MS = 1500
local TRACK_SWITCH_GRACE_MS = 2000
local NOW_PLAYING_AUTO_HIDE_MS = 5000
local RADIO_DISABLED_CONTROLS = {
    81,
    82,
    83,
    84,
    85,
}

local INPUT_CONTROLLER_FACE_X = 179

local STATIC_EMITTERS_FILE_PATH = 'modules/soundtrack/staticemitters.json'

local STATIONS = {
    class_rock = 'RADIO_01_CLASS_ROCK',
    pop = 'RADIO_02_POP',
    punk = 'RADIO_04_PUNK',
    hiphop_new = 'RADIO_03_HIPHOP_NEW',
    country = 'RADIO_06_COUNTRY',
    dance_01 = 'RADIO_07_DANCE_01',
    mexican = 'RADIO_08_MEXICAN',
    hiphop_old = 'RADIO_09_HIPHOP_OLD',
    reggae = 'RADIO_12_REGGAE',
    motown = 'RADIO_15_MOTOWN',
    silverlake = 'RADIO_16_SILVERLAKE',
    ['90s_rock'] = 'RADIO_18_90S_ROCK',
    funk = 'RADIO_17_FUNK',
}

local LOCKED_STATIONS = {
    'RADIO_05_TALK_01',
    'RADIO_11_TALK_02',
}

local AUDIO_PREFIXES = {
    class_rock = { 'radio_01_class_rock_' },
    pop = { 'radio_02_pop_' },
    punk = { 'radio_04_punk_' },
    hiphop_new = {
        'dlc_security_music_radio_03_hiphop_new_',
        'radio_03_hiphop_new_',
    },
    country = { 'radio_06_country_' },
    dance_01 = { 'radio_07_dance_01_' },
    mexican = { 'radio_08_mexican_' },
    hiphop_old = {
        'dlc_security_music_radio_09_hiphop_old_',
        'radio_09_hiphop_old_',
    },
    reggae = { 'radio_12_reggae_' },
    motown = { 'radio_15_motown_' },
    silverlake = { 'radio_16_silverlake_' },
    ['90s_rock'] = { 'radio_18_90s_rock_' },
    funk = { 'radio_17_funk_' },
}

local NAME_TO_KEY = {}
for stationKey, radioName in pairs(STATIONS) do
    NAME_TO_KEY[radioName] = stationKey
end

---@class SKSoundtrackTrack
---@field stationKey string
---@field radioName string
---@field audioId string
---@field durationMs integer
---@field title string

---@param filePath string
---@return string
local function loadRawTracks(filePath)
    local rawTracks = LoadResourceFile(GetCurrentResourceName(), filePath)
    if not rawTracks then
        error(('SKSoundtrack: failed to load %s'):format(filePath))
    end

    return rawTracks
end

---@param stationKey string
---@param audioId string
---@return string
local function trackKeyFromAudio(stationKey, audioId)
    for _, prefix in ipairs(AUDIO_PREFIXES[stationKey]) do
        if audioId:sub(1, #prefix) == prefix then
            return audioId:sub(#prefix + 1)
        end
    end

    error(('SKSoundtrack: audio id %q has no prefix for station %q'):format(audioId, stationKey))
end

---@param filePath string
---@return table<string, table<string, string>>, table<string, integer>, table<string, string>, table<string, SKSoundtrackTrack>, string[]
local function buildTracks(filePath)
    local tracks = {}
    local durationByTrack = {}
    local titleByTrack = {}
    local trackByKey = {}
    local trackKeys = {}
    local rawTracks = loadRawTracks(filePath)

    for line in rawTracks:gmatch('[^\r\n]+') do
        local radioName, audioId, durationStr, title = line:match('^(%S+)%s+(%S+)%s+(%d+)%s*(.*)$')
        if radioName and audioId and durationStr then
            local stationKey = NAME_TO_KEY[radioName]
            local trackKey = trackKeyFromAudio(stationKey, audioId)
            local durationMs = tonumber(durationStr)

            title = title:match('^%s*(.-)%s*$')
            if title == '' then
                title = trackKey
            end

            tracks[stationKey] = tracks[stationKey] or {}

            if tracks[stationKey][trackKey] and tracks[stationKey][trackKey] ~= audioId then
                error(('SKSoundtrack: duplicate track key %q on %q'):format(trackKey, stationKey))
            end

            tracks[stationKey][trackKey] = audioId
            durationByTrack[trackKey] = durationMs
            titleByTrack[trackKey] = title
            trackByKey[trackKey] = {
                stationKey = stationKey,
                radioName = radioName,
                audioId = audioId,
                durationMs = durationMs,
                title = title,
            }
            trackKeys[#trackKeys + 1] = trackKey
        end
    end

    return tracks, durationByTrack, titleByTrack, trackByKey, trackKeys
end

---@param tracks table<string, table<string, string>>
---@return table<string, string>
local function buildStationByTrack(tracks)
    local stationByTrack = {}

    for stationKey, stationTracks in pairs(tracks) do
        for trackKey in pairs(stationTracks) do
            local otherStationKey = stationByTrack[trackKey]
            if otherStationKey then
                error(('SKSoundtrack: track key %q is on %q and %q'):format(trackKey, otherStationKey, stationKey))
            end

            stationByTrack[trackKey] = stationKey
        end
    end

    return stationByTrack
end

---@param trackByKey table<string, SKSoundtrackTrack>
---@return table<integer, string>
local function buildHashToTrackKey(trackByKey)
    local hashToTrackKey = {}

    for trackKey, track in pairs(trackByKey) do
        hashToTrackKey[GetHashKey(track.audioId)] = trackKey
    end

    return hashToTrackKey
end

---@class SKSoundtrackDataset
---@field tracks table<string, table<string, string>>
---@field durationByTrack table<string, integer>
---@field titleByTrack table<string, string>
---@field trackByKey table<string, SKSoundtrackTrack>
---@field trackKeys string[]
---@field stationByTrack table<string, string>
---@field hashToTrackKey table<integer, string>

---@param filePath string
---@return SKSoundtrackDataset
local function buildDataset(filePath)
    local tracks, durationByTrack, titleByTrack, trackByKey, trackKeys = buildTracks(filePath)

    return {
        tracks = tracks,
        durationByTrack = durationByTrack,
        titleByTrack = titleByTrack,
        trackByKey = trackByKey,
        trackKeys = trackKeys,
        stationByTrack = buildStationByTrack(tracks),
        hashToTrackKey = buildHashToTrackKey(trackByKey),
    }
end

local DEFAULT_SOUNDTRACK_DATA = buildDataset(DEFAULT_SOUNDTRACK_DATA_FILE_PATH)
local GARAGE_SOUNDTRACK_DATA = buildDataset(GARAGE_SOUNDTRACK_DATA_FILE_PATH)
local activeDatasetKey = nil

local shuffleBag = {}
local currentTrackKey = nil
local currentVehicle = 0
local lastPlayedTrackKey = nil
local skipRequested = false
local trackSwitchedAtMs = 0
local musicDisabled = false
local soundtrackEnabled = true
local soundtrackBlocked = false
local nowPlayingUiEnabled = true
local nowPlayingUiAlwaysVisible = false
local nowPlayingUiVisibleUntilMs = 0
local playerUiVisible = false

local NOW_PLAYING_ALLOWED_STATES = {
    [GameState.FREEROAM] = true,
    [GameState.EVENT] = true,
    [GameState.MISSION] = true,
    [GameState.GARAGE] = true,
    [GameState.MULTIPLAYER_LOBBY] = true,
    [GameState.MULTIPLAYER_EVENT] = true,
}

---@return string|nil
local function getCurrentGameState()
    local getState = SKC and SKC.GetGameState or nil
    if not getState then
        return nil
    end

    return getState()
end

---@return boolean
local function isGarageState()
    return getCurrentGameState() == GameState.GARAGE
end

---@return string
local function getActiveDatasetKey()
    if isGarageState() then
        return 'garage'
    end

    return 'default'
end

---@return SKSoundtrackDataset
local function getActiveDataset()
    local datasetKey = getActiveDatasetKey()
    if activeDatasetKey ~= datasetKey then
        activeDatasetKey = datasetKey
        shuffleBag = {}
        currentTrackKey = nil
        lastPlayedTrackKey = nil
        skipRequested = false
    end

    if datasetKey == 'garage' then
        return GARAGE_SOUNDTRACK_DATA
    end

    return DEFAULT_SOUNDTRACK_DATA
end

---@param playbackMs integer
---@return integer
local function clampPlaybackMs(playbackMs)
    if playbackMs < 0 then
        return 0
    end

    return playbackMs
end

---@param trackKey string
---@return SKSoundtrackTrack
local function resolveTrack(trackKey)
    local track = getActiveDataset().trackByKey[trackKey]
    if not track then
        error(('SKSoundtrack: unknown track key %q'):format(trackKey))
    end

    return track
end

---@return boolean, boolean, boolean, boolean
local function getToggleState()
    ---@type { musicDisabled: boolean, soundtrackEnabled: boolean, soundtrackNowPlayingUiEnabled: boolean, soundtrackNowPlayingUiAlwaysVisible: boolean }|nil
    local config = SKSettings and SKSettings.getGeneralConfig and SKSettings.getGeneralConfig() or nil
    if not config then
        return true, true, false, false
    end

    if config.musicDisabled == true then
        return false, false, false, true
    end

    return config.soundtrackEnabled ~= false, config.soundtrackNowPlayingUiEnabled ~= false, config.soundtrackNowPlayingUiAlwaysVisible == true, false
end

---@return boolean
local function canShowNowPlayingUi()
    if not nowPlayingUiEnabled then
        return false
    end

    local state = getCurrentGameState()
    if not state then
        return true
    end

    return NOW_PLAYING_ALLOWED_STATES[state] == true
end

---@return boolean
local function shouldKeepNowPlayingUiVisible()
    if isGarageState() then
        return true
    end

    if nowPlayingUiAlwaysVisible then
        return true
    end

    return GetGameTimer() <= nowPlayingUiVisibleUntilMs
end

---@return nil
local function refreshNowPlayingUiVisibilityWindow()
    nowPlayingUiVisibleUntilMs = GetGameTimer() + NOW_PLAYING_AUTO_HIDE_MS
end

---@return nil
local function sendPlayerHidden()
    if not playerUiVisible then
        return
    end

    playerUiVisible = false
    SendNUIMessage({
        type = 'soundtrack:player',
        visible = false,
        garage = isGarageState(),
    })
end

---@param trackKey string
---@param playbackMs integer
---@return nil
local function sendPlayerState(trackKey, playbackMs)
    if not canShowNowPlayingUi() then
        sendPlayerHidden()
        return
    end

    if not shouldKeepNowPlayingUiVisible() then
        sendPlayerHidden()
        return
    end

    local track = resolveTrack(trackKey)

    playerUiVisible = true
    SendNUIMessage({
        type = 'soundtrack:player',
        visible = true,
        garage = isGarageState(),
        title = track.title,
        currentMs = playbackMs,
        durationMs = track.durationMs,
    })
end

---@return nil
local function refillShuffleBag()
    local dataset = getActiveDataset()

    shuffleBag = {}

    for i = 1, #dataset.trackKeys do
        shuffleBag[i] = dataset.trackKeys[i]
    end

    for i = #shuffleBag, 2, -1 do
        local j = math.random(i)
        shuffleBag[i], shuffleBag[j] = shuffleBag[j], shuffleBag[i]
    end

    if lastPlayedTrackKey and #shuffleBag > 1 and shuffleBag[#shuffleBag] == lastPlayedTrackKey then
        shuffleBag[#shuffleBag], shuffleBag[1] = shuffleBag[1], shuffleBag[#shuffleBag]
    end
end

---@return string
local function popNextTrackKey()
    if #shuffleBag == 0 then
        refillShuffleBag()
    end

    local trackKey = table.remove(shuffleBag)
    if not trackKey then
        error('SKSoundtrack: shuffle bag is empty')
    end

    return trackKey
end

---@param trackKey string
---@return nil
local function removeTrackFromShuffleBag(trackKey)
    for i = #shuffleBag, 1, -1 do
        if shuffleBag[i] == trackKey then
            table.remove(shuffleBag, i)
            return
        end
    end
end

---@param vehicle integer
---@param trackKey string
---@return nil
local function applyTrack(vehicle, trackKey)
    local track = resolveTrack(trackKey)

    currentVehicle = vehicle
    currentTrackKey = trackKey
    lastPlayedTrackKey = trackKey
    skipRequested = false
    trackSwitchedAtMs = GetGameTimer()

    removeTrackFromShuffleBag(trackKey)
    refreshNowPlayingUiVisibilityWindow()

    SetVehicleRadioEnabled(vehicle, true)
    SetVehRadioStation(vehicle, track.radioName)
    SetRadioToStationName(track.radioName)
    SetInitialPlayerStation(track.radioName)
    FreezeRadioStation(track.radioName)
    SetRadioAutoUnfreeze(false)
    SetRadioTrack(track.radioName, track.audioId)
    UnfreezeRadioStation(track.radioName)
    SetRadioAutoUnfreeze(true)

    sendPlayerState(trackKey, 0)
end

---@param vehicle integer
---@return nil
local function playNextTrack(vehicle)
    applyTrack(vehicle, popNextTrackKey())
end

---@return integer
local function getCurrentManagedVehicle()
    return GetVehiclePedIsIn(PlayerPedId(), false)
end

---@param vehicle integer
---@return nil
local function resetVehicleState(vehicle)
    currentVehicle = vehicle
    currentTrackKey = nil
    skipRequested = false
    nowPlayingUiVisibleUntilMs = 0
    sendPlayerHidden()
end

---@return integer|nil, string|nil
local function getCurrentManagedPlayback()
    if not currentTrackKey then
        return nil, nil
    end

    local track = getActiveDataset().trackByKey[currentTrackKey]
    if not track then
        return nil, nil
    end

    local playbackMs = clampPlaybackMs(GetCurrentRadioTrackPlaybackTime(track.radioName))
    local soundHash = GetCurrentTrackSoundName(track.radioName)
    local resolvedTrackKey = getActiveDataset().hashToTrackKey[soundHash]

    return playbackMs, resolvedTrackKey
end

---@param vehicle integer
---@return nil
local function updateManagedTrack(vehicle)
    getActiveDataset()

    if currentVehicle ~= vehicle or not currentTrackKey then
        playNextTrack(vehicle)
        return
    end

    local playbackMs, resolvedTrackKey = getCurrentManagedPlayback()
    if not playbackMs then
        playNextTrack(vehicle)
        return
    end

    if resolvedTrackKey and resolvedTrackKey ~= currentTrackKey then
        if getActiveDataset().trackByKey[resolvedTrackKey]
            and (GetGameTimer() - trackSwitchedAtMs) > TRACK_SWITCH_GRACE_MS
        then
            currentTrackKey = resolvedTrackKey
            refreshNowPlayingUiVisibilityWindow()
        end
    end

    local track = resolveTrack(currentTrackKey)
    local trackEndMs = math.max(0, track.durationMs - TRACK_END_SKIP_BUFFER_MS)
    if skipRequested or playbackMs >= trackEndMs then
        playNextTrack(vehicle)
        return
    end

    if GetPlayerRadioStationName() ~= track.radioName then
        applyTrack(vehicle, currentTrackKey)
        return
    end

    sendPlayerState(currentTrackKey, playbackMs)
end

SKSoundtrack.STATION = STATIONS
SKSoundtrack.TRACKS = DEFAULT_SOUNDTRACK_DATA.tracks
SKSoundtrack.STATION_BY_TRACK = DEFAULT_SOUNDTRACK_DATA.stationByTrack
SKSoundtrack.TRACK_DURATION_MS = DEFAULT_SOUNDTRACK_DATA.durationByTrack
SKSoundtrack.TRACK_TITLE = DEFAULT_SOUNDTRACK_DATA.titleByTrack
SKSoundtrack.TRACK_BY_KEY = DEFAULT_SOUNDTRACK_DATA.trackByKey
SKSoundtrack.TRACK_KEYS = DEFAULT_SOUNDTRACK_DATA.trackKeys
SKSoundtrack.HASH_TO_TRACK_KEY = DEFAULT_SOUNDTRACK_DATA.hashToTrackKey
SKSoundtrack.GARAGE_TRACKS = GARAGE_SOUNDTRACK_DATA.tracks
SKSoundtrack.GARAGE_STATION_BY_TRACK = GARAGE_SOUNDTRACK_DATA.stationByTrack
SKSoundtrack.GARAGE_TRACK_DURATION_MS = GARAGE_SOUNDTRACK_DATA.durationByTrack
SKSoundtrack.GARAGE_TRACK_TITLE = GARAGE_SOUNDTRACK_DATA.titleByTrack
SKSoundtrack.GARAGE_TRACK_BY_KEY = GARAGE_SOUNDTRACK_DATA.trackByKey
SKSoundtrack.GARAGE_TRACK_KEYS = GARAGE_SOUNDTRACK_DATA.trackKeys
SKSoundtrack.GARAGE_HASH_TO_TRACK_KEY = GARAGE_SOUNDTRACK_DATA.hashToTrackKey

---@return nil
function SKSoundtrack.ApplyRadioDefaults()
    soundtrackEnabled, nowPlayingUiEnabled, nowPlayingUiAlwaysVisible, musicDisabled = getToggleState()

    for _, radioName in pairs(STATIONS) do
        SetRadioStationMusicOnly(radioName, soundtrackEnabled)
    end

    for _, radioName in ipairs(LOCKED_STATIONS) do
        LockRadioStation(radioName, soundtrackEnabled)
    end

    if not nowPlayingUiEnabled then
        sendPlayerHidden()
    end
end

---@param blocked boolean
function SKSoundtrack.setBlocked(blocked)
    soundtrackBlocked = blocked
    if blocked then
        local vehicle = getCurrentManagedVehicle()
        if vehicle ~= 0 then
            SetVehicleRadioEnabled(vehicle, false)
            SetVehRadioStation(vehicle, 'OFF')
        end
        resetVehicleState(0)
    end
end

---@param trackKey string
function SKSoundtrack.SetRadioTrackByKey(trackKey)
    local vehicle = getCurrentManagedVehicle()
    if vehicle == 0 then
        error('SKSoundtrack: no active vehicle')
    end

    applyTrack(vehicle, trackKey)
end

---@param stationKey string
---@param trackKey string
function SKSoundtrack.SetRadioTrack(stationKey, trackKey)
    local resolvedStationKey = getActiveDataset().stationByTrack[trackKey]
    if resolvedStationKey ~= stationKey then
        error(('SKSoundtrack: track key %q is not on %q'):format(trackKey, stationKey))
    end

    SKSoundtrack.SetRadioTrackByKey(trackKey)
end

---@param stationKey string
---@param trackKey string
---@return string
function SKSoundtrack.GetTrackAudioId(stationKey, trackKey)
    local resolvedStationKey = getActiveDataset().stationByTrack[trackKey]
    if resolvedStationKey ~= stationKey then
        error(('SKSoundtrack: track key %q is not on %q'):format(trackKey, stationKey))
    end

    return resolveTrack(trackKey).audioId
end

---@param stationKey string
---@param trackKey string
---@return integer
function SKSoundtrack.GetTrackHash(stationKey, trackKey)
    return GetHashKey(SKSoundtrack.GetTrackAudioId(stationKey, trackKey))
end

---@param trackKey string
---@return integer
function SKSoundtrack.GetTrackDurationMs(trackKey)
    return resolveTrack(trackKey).durationMs
end

---@param trackKey string
---@return string
function SKSoundtrack.GetTrackTitle(trackKey)
    return resolveTrack(trackKey).title
end

---@return string|nil
function SKSoundtrack.GetCurrentTrackKey()
    return currentTrackKey
end

---@return nil
function SKSoundtrack.SkipCurrentTrack()
    if currentVehicle == 0 or not currentTrackKey then
        return
    end

    skipRequested = true
end

exports('GetCurrentTrack', function()
    if not currentTrackKey then return nil end
    local track = getActiveDataset().trackByKey[currentTrackKey]
    if not track then return nil end
    return { key = currentTrackKey, title = track.title, stationKey = track.stationKey, durationMs = track.durationMs }
end)
exports('SetSoundtrackEnabled', function(on)
    if type(on) ~= 'boolean' then return false end
    soundtrackEnabled = on
    SKSoundtrack.ApplyRadioDefaults()
    return true
end)

RegisterCommand(SKIP_KEY_COMMAND, function()
    if not soundtrackEnabled then
        return
    end
    SKSoundtrack.SkipCurrentTrack()
end)
RegisterKeyMapping(SKIP_KEY_COMMAND, 'Skip current soundtrack track', 'keyboard', 'Q')

CreateThread(function()
    while true do
        if not soundtrackEnabled then
            Wait(100)
        elseif SKPhone.isOpen() then
            Wait(50)
        else
            local padIndex = SKInput.getActivePadIndex()
            if SKInput.isUsingKeyboard(padIndex) then
                Wait(50)
            elseif IsDisabledControlJustPressed(padIndex, INPUT_CONTROLLER_FACE_X)
                or IsControlJustPressed(padIndex, INPUT_CONTROLLER_FACE_X)
            then
                SKSoundtrack.SkipCurrentTrack()
                Wait(250)
            else
                Wait(0)
            end
        end
    end
end)

CreateThread(function()
    while true do
        local vehicle = getCurrentManagedVehicle()
        if soundtrackEnabled and not soundtrackBlocked and vehicle ~= 0 then
            for i = 1, #RADIO_DISABLED_CONTROLS do
                DisableControlAction(0, RADIO_DISABLED_CONTROLS[i], true)
                DisableControlAction(1, RADIO_DISABLED_CONTROLS[i], true)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    Wait(1000)
    SKSoundtrack.ApplyRadioDefaults()
    sendPlayerHidden()

    while true do
        Wait(PLAYER_UPDATE_INTERVAL_MS)

        local lastSoundtrackEnabled = soundtrackEnabled
        local lastNowPlayingUiEnabled = nowPlayingUiEnabled
        local lastNowPlayingUiAlwaysVisible = nowPlayingUiAlwaysVisible
        local lastMusicDisabled = musicDisabled
        soundtrackEnabled, nowPlayingUiEnabled, nowPlayingUiAlwaysVisible, musicDisabled = getToggleState()

        if soundtrackEnabled ~= lastSoundtrackEnabled or nowPlayingUiEnabled ~= lastNowPlayingUiEnabled or nowPlayingUiAlwaysVisible ~= lastNowPlayingUiAlwaysVisible or musicDisabled ~= lastMusicDisabled then
            SKSoundtrack.ApplyRadioDefaults()
        end

        if musicDisabled then
            local vehicle = getCurrentManagedVehicle()
            if vehicle ~= 0 then
                SetVehicleRadioEnabled(vehicle, false)
                SetVehRadioStation(vehicle, 'OFF')
            end
            if currentVehicle ~= 0 or currentTrackKey then
                resetVehicleState(0)
            end
        elseif soundtrackEnabled and not soundtrackBlocked then
            local vehicle = getCurrentManagedVehicle()
            if vehicle == 0 then
                if currentVehicle ~= 0 or currentTrackKey then
                    resetVehicleState(0)
                end
            else
                updateManagedTrack(vehicle)
            end
        elseif not soundtrackEnabled then
            if currentVehicle ~= 0 or currentTrackKey then
                resetVehicleState(0)
            elseif not nowPlayingUiEnabled then
                sendPlayerHidden()
            end
        end
    end
end)

---@return string[]
local function loadStaticEmitterNames()
    local rawEmitters = LoadResourceFile(GetCurrentResourceName(), STATIC_EMITTERS_FILE_PATH)
    if not rawEmitters then
        error(('SKSoundtrack: failed to load %s'):format(STATIC_EMITTERS_FILE_PATH))
    end

    local decoded = json.decode(rawEmitters)
    if type(decoded) ~= 'table' then
        error(('SKSoundtrack: invalid emitter data in %s'):format(STATIC_EMITTERS_FILE_PATH))
    end

    local emitters = {}
    for i = 1, #decoded do
        local emitter = decoded[i]
        if type(emitter) == 'table' and type(emitter.Name) == 'string' and emitter.Name ~= '' then
            emitters[#emitters + 1] = emitter.Name
        end
    end

    return emitters
end

CreateThread(function()
    Wait(500)
    local emitters = loadStaticEmitterNames()
    for i = 1, #emitters do
        SetStaticEmitterEnabled(emitters[i], false)
    end
end)