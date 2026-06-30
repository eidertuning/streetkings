if SKConfig.DisablePauseMenu then return end

SKPauseMenu = SKPauseMenu or {}

local menuOpen    = false
local menuOpening = false
local cineCam  = nil
local controllerTracker = SKControllerFriendly.newTracker()
local controllerModeEnabled = false

local STORE_URL = 'https://streetkings.com/store'

---@return boolean
function SKPauseMenu.isOpen()
    return menuOpen or menuOpening
end

local shots = {
    { radius = 3.6, baseHeight = 1.2, heightAmp = 0.0,  fov = 55.0, speed = 0.016, lookZ = 0.5, startAngle = 160.0, duration = 8000  },
    { radius = 4.2, baseHeight = 1.8, heightAmp = 0.15, fov = 48.0, speed = 0.012, lookZ = 0.4, startAngle = 30.0,  duration = 9000  },
    { radius = 3.0, baseHeight = 1.0, heightAmp = 0.0,  fov = 42.0, speed = 0.018, lookZ = 0.6, startAngle = 250.0, duration = 7000  },
    { radius = 5.0, baseHeight = 2.2, heightAmp = 0.2,  fov = 52.0, speed = 0.010, lookZ = 0.3, startAngle = 110.0, duration = 10000 },
    { radius = 3.4, baseHeight = 1.5, heightAmp = 0.1,  fov = 45.0, speed = 0.014, lookZ = 0.5, startAngle = 310.0, duration = 8000  },
}

local function startCinematicCam()
    local ped     = PlayerPedId()
    local pos     = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    Cinematic = true
    cineCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local shot  = shots[1]
    local angle = heading + shot.startAngle
    local rad   = math.rad(angle)

    SetCamFov(cineCam, shot.fov)
    SetCamCoord(cineCam, pos.x + shot.radius * math.cos(rad), pos.y + shot.radius * math.sin(rad), pos.z + shot.baseHeight)
    PointCamAtCoord(cineCam, pos.x, pos.y, pos.z + shot.lookZ)
    SetCamActive(cineCam, true)
    RenderScriptCams(true, true, 1200, true, true)

    CreateThread(function()
        local shotIdx  = 1
        local shotStart = GetGameTimer()
        local s = shots[shotIdx]
        angle = heading + s.startAngle

        while menuOpen and cineCam do
            Wait(0)
            local now     = GetGameTimer()
            local elapsed = now - shotStart

            if elapsed >= s.duration then
                shotIdx    = (shotIdx % #shots) + 1
                s          = shots[shotIdx]
                shotStart  = now
                elapsed    = 0
                angle      = GetEntityHeading(PlayerPedId()) + s.startAngle
                SetCamFov(cineCam, s.fov)
            end

            angle     = angle + s.speed
            rad       = math.rad(angle)
            local height = s.baseHeight + s.heightAmp * math.sin((elapsed / s.duration) * math.pi * 2)
            local p   = GetEntityCoords(PlayerPedId())
            SetCamCoord(cineCam, p.x + s.radius * math.cos(rad), p.y + s.radius * math.sin(rad), p.z + height)
            PointCamAtCoord(cineCam, p.x, p.y, p.z + s.lookZ)
        end
    end)
end

local function stopCinematicCam()
    if cineCam then
        local cam = cineCam
        cineCam = nil
        RenderScriptCams(false, true, 600, true, true)
        Wait(650)
        if DoesCamExist(cam) then
            DestroyCam(cam, false)
        end
    end
end

local function setControllerModeEnabled(nextEnabled)
    nextEnabled = nextEnabled == true
    if controllerModeEnabled == nextEnabled then return end
    controllerModeEnabled = nextEnabled
    SendNUIMessage({ type = 'pausemenu:controllerMode', enabled = nextEnabled })
end

local function openMenu()
    if menuOpen or menuOpening then return end
    menuOpening = true

    local ped        = PlayerPedId()
    local pos        = GetEntityCoords(ped)
    local streetHash = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local stats      = lib.callback.await('streetkings:stats:getData', false)
    local profile    = lib.callback.await('streetkings:pausemenu:getProfile', false)
    local env        = GlobalState and GlobalState.streetkingsEnvironment or nil

    SKControllerFriendly.resetTracker(controllerTracker)
    setControllerModeEnabled(false)

    SendNUIMessage({
        type       = 'pausemenu:open',
        playerName = GetPlayerName(PlayerId()),
        profile    = profile or {},
        street     = GetStreetNameFromHashKey(streetHash),
        zone       = GetLabelText(GetNameOfZone(pos.x, pos.y, pos.z)),
        gameTime   = string.format('%02d:%02d', GetClockHours(), GetClockMinutes()),
        weather     = env and env.weather or 'CLEAR',
        serverName  = profile and profile.serverName or 'Five Horizon',
        playersOnline = #GetActivePlayers(),
        level        = stats and stats.level or 1,
        maxLevel     = stats and stats.maxLevel or 50,
        nextLevel    = stats and stats.nextLevel or nil,
        playerXp     = stats and stats.playerXp or 0,
        xpInLevel    = stats and stats.xpInLevel or 0,
        xpNeeded     = stats and stats.xpNeeded or 1,
        xpRemainingToNext = stats and stats.xpRemainingToNext or 0,
        cash         = stats and stats.cash  or 0,
        milesDriven  = stats and stats.stats and stats.stats.totalMilesDriven or 0,
        racesWon     = stats and stats.stats and stats.stats.racesWon or 0,
        vehiclesOwned = stats and stats.vehiclesOwned or 0,
        propertiesOwned = stats and stats.propertiesOwned or 0,
        storeUrl     = STORE_URL,
    })

    SetNuiFocus(true, true)
    menuOpen = true
    menuOpening = false
    startCinematicCam()
end

local function closeMenu()
    menuOpen = false
    SKControllerFriendly.resetTracker(controllerTracker)
    setControllerModeEnabled(false)
    CreateThread(stopCinematicCam)
    TriggerScreenblurFadeOut(150)
    SetNuiFocus(false, false)
end

CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 199, true)
        DisableControlAction(0, 200, true)
        DisableControlAction(1, 199, true)
        DisableControlAction(1, 200, true)
        if IsPauseMenuActive() then
            SetPauseMenuActive(false)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if not menuOpen and not menuOpening and SKC.GetGameState() ~= GameState.MAIN_MENU then
            local padIndex = SKInput.getActivePadIndex()
            if not SKInput.isUsingKeyboard(padIndex) then
                if IsDisabledControlJustPressed(padIndex, 199) or IsDisabledControlJustPressed(padIndex, 200) then
                    openMenu()
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        if menuOpen then
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)

            local state = SKControllerFriendly.poll(controllerTracker)
            setControllerModeEnabled(state.controllerEnabled)

            if state.controllerEnabled then
                for _, action in ipairs(state.pressedActions) do
                    SendNUIMessage({ type = 'pausemenu:controllerInput', action = action })
                end
            end

            Wait(0)
        else
            Wait(100)
        end
    end
end)

lib.addKeybind({
    name        = 'sk_pausemenu',
    description = 'Toggle Pause Menu',
    defaultKey  = 'ESCAPE',
    onPressed   = function()
        if not menuOpen and SKC.GetGameState() ~= GameState.MAIN_MENU then
            openMenu()
        end
    end,
})

RegisterNUICallback('pausemenu:close', function(_, cb)
    closeMenu()
    Cinematic = false
    cb('ok')
end)

RegisterNUICallback('pausemenu:settings', function(_, cb)
    closeMenu()
    ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_LANDING_MENU'), 0, -1)
    Cinematic = false
    cb('ok')
end)

RegisterNUICallback('pausemenu:map', function(_, cb)
    menuOpen = false
    if cineCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cineCam, false)
        cineCam = nil
    end
    TriggerScreenblurFadeOut(0)
    SetNuiFocus(false, false)
    ActivateFrontendMenu('FE_MENU_VERSION_MP_PAUSE', true, -1)
    while not IsPauseMenuActive() do Wait(0) end
    PauseMenuceptionGoDeeper(0)
    PauseMenuceptionTheKick()
    Cinematic = false
    cb('ok')
end)

RegisterNUICallback('pausemenu:mainmenu', function(_, cb)
    closeMenu()
    Cinematic = false
    CreateThread(function()
        DoScreenFadeOut(300)
        Wait(300)
        SKC.SetGameState(GameState.MAIN_MENU)
    end)
    cb('ok')
end)

RegisterNUICallback('pausemenu:exitgame', function(_, cb)
    TriggerServerEvent('streetkings:pausemenu:exitGame')
    closeMenu()
    Cinematic = false
    cb('ok')
end)
