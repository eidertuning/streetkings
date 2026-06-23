
SKGearbox = {}

local MODES = {
    beginner = {
        noClutchMult   = 1.0,
        withClutchMult = 1.0,
        stallThreshold = 0.0,
        stallTimer     = 1000,
    },
    expert = {
        noClutchMult   = 1.0,
        withClutchMult = 0.5,
        stallThreshold = 0.23,
        stallTimer     = 1000,
        requireClutch  = true,
    },
}

local ALLOWED_STATES = {
    [GameState.FREEROAM] = true,
    [GameState.EVENT] = true,
    [GameState.MULTIPLAYER_LOBBY] = true,
    [GameState.MULTIPLAYER_EVENT] = true,
}

local STALL_PRESSES_NEEDED = 20
local STALL_TIME_MS        = 5000
local STALL_RETRY_DELAY_MS = 3000
local STALL_INTERACTION_BLOCK_MS = 1000
local INPUT_VEH_HORN       = 86

local activeGearboxType = nil

local noClutchMult   = 1.0
local withClutchMult = 1.0
local stallThreshold = 0.0
local stallTimer     = 1000
local requireClutch  = false

local vehicle  = 0
local inVeh    = false
local active   = false

local clutchDown = false
local reqUp      = false
local reqDown    = false

local gear      = 1
local gearCount = 1
local shifting  = false
local shiftDir  = 0

local origForce   = 0.0
local origInertia = 0.0
local origMaxVel  = 0.0

local shiftTimeUp   = 0.0
local shiftTimeDown = 0.0

local shiftEndsAt, shiftDur     = 0, 0
local penaltyEndsAt, penaltyDur = 0, 0
local shiftPct, penaltyPct      = 0, 0

local stalled    = false
local restarted  = true
local limiter    = false
local modified   = false
local stallCount = 0
local stallInteractionBlockedUntil = 0

local setGearHash = GetHashKey('SET_VEHICLE_CURRENT_GEAR') & 0xFFFFFFFF

local function SetGear(veh, g)
    Citizen.InvokeNative(setGearHash, veh, g)
end

local function SetReducedRatio(veh, val)
    Citizen.InvokeNative(0x337EF33DA3DDB990, veh, val)
end

local function isAllowedClass(veh)
    local c = GetVehicleClass(veh)
    return c ~= 13 and c ~= 14 and c ~= 15 and c ~= 16 and c ~= 21
end

---@return boolean
local function isAllowedState()
    return ALLOWED_STATES[SKC.GetGameState()] == true
end

local function updateTimers()
    local now  = GetGameTimer()
    shiftPct   = (shiftEndsAt   > now and shiftDur   > 0) and (shiftEndsAt   - now) / shiftDur   or 0
    penaltyPct = (penaltyEndsAt > now and penaltyDur > 0) and (penaltyEndsAt - now) / penaltyDur or 0
end

local function startShift(ms)
    shiftDur    = ms
    shiftEndsAt = GetGameTimer() + ms
end

local function startPenalty(ms)
    penaltyDur    = ms
    penaltyEndsAt = GetGameTimer() + ms
end

local function playShiftAnim()
    local dict = 'veh@driveby@first_person@passenger_rear_right_handed@smg'
    local anim = 'outro_90r'
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    local ped = PlayerPedId()
    TaskPlayAnim(ped, dict, anim, 8.0, 1.0, 500, 48, 0, false, false, false)
    Wait(1000)
    StopAnimTask(ped, dict, anim, 1.0)
end

local function playShiftSound()
    PlaySoundFromEntity(-1, 'COLLECT_IN_BAG', vehicle, 'NIGEL_1D_SOUNDSET', false, 0)
end

lib.addKeybind({
    name        = 'sk_gears_upshift',
    description = 'Manual Gearbox: Shift Up',
    defaultKey  = 'UP',
    defaultMapper = 'KEYBOARD',
    secondaryKey = 'RRIGHT_INDEX',
    secondaryMapper = 'PAD_DIGITALBUTTONANY',
    onPressed   = function()
        if not active then return end
        if gear + 1 <= gearCount then
            CreateThread(playShiftAnim)
            reqUp = true
        end
    end,
})

lib.addKeybind({
    name        = 'sk_gears_downshift',
    description = 'Manual Gearbox: Shift Down',
    defaultKey  = 'DOWN',
    defaultMapper = 'KEYBOARD',
    secondaryKey = 'RUP_INDEX',
    secondaryMapper = 'PAD_DIGITALBUTTONANY',
    onPressed   = function()
        if not active then return end
        if gear - 2 >= -1 then
            CreateThread(playShiftAnim)
            reqDown = true
        end
    end,
})

lib.addKeybind({
    name        = 'sk_gears_clutch',
    description = 'Manual Gearbox: Clutch',
    defaultKey  = 'LSHIFT',
    defaultMapper = 'KEYBOARD',
    secondaryKey = 'L1_INDEX',
    secondaryMapper = 'PAD_DIGITALBUTTONANY',
    onPressed   = function() clutchDown = true  end,
    onReleased  = function() clutchDown = false end,
})

local stallGameActive = false
local stallGameToken  = 0

---@return boolean
local function isPauseMenuOpen()
    if SKPauseMenu and SKPauseMenu.isOpen and SKPauseMenu.isOpen() then
        return true
    end
    return IsPauseMenuActive()
end

---@param blocked boolean
local function setStallSoundtrackBlocked(blocked)
    if SKSoundtrack and SKSoundtrack.setBlocked then
        SKSoundtrack.setBlocked(blocked)
    end
end

---@param duration integer
---@param isKeyboard boolean
local function showStallPrompt(duration, isKeyboard)
    SendNUIMessage({
        type       = 'gearbox:stall:show',
        duration   = duration,
        isKeyboard = isKeyboard,
    })
end

local function doRestart()
    if GetIsVehicleEngineRunning(vehicle) or IsVehicleEngineStarting(vehicle) then return end
    if GetVehicleEngineHealth(vehicle) <= 0.0 then
        SetVehicleEngineHealth(vehicle, 300.0)
    end
    SetVehicleEngineOn(vehicle, true, true, false)
    stallInteractionBlockedUntil = GetGameTimer() + STALL_INTERACTION_BLOCK_MS
    gear       = 1
    SetGear(vehicle, 1)
    stallCount = 0
    stalled    = false
    restarted  = true
    setStallSoundtrackBlocked(false)
end

---@param targetVehicle integer
local function forceRestartAfterTransition(targetVehicle)
    if not stalled then return end -- Only restart if the vehicle is stalled
    stallGameToken  = stallGameToken + 1
    stallGameActive = false
    stallCount      = 0
    stalled         = false
    restarted       = true
    gear            = 1

    SendNUIMessage({ type = 'gearbox:stall:hide' })
    setStallSoundtrackBlocked(false)

    if targetVehicle == 0 or not DoesEntityExist(targetVehicle) then
        targetVehicle = vehicle
    end
    if targetVehicle == 0 or not DoesEntityExist(targetVehicle) then return end

    vehicle = targetVehicle
    if GetVehicleEngineHealth(vehicle) <= 0.0 then
        SetVehicleEngineHealth(vehicle, 300.0)
    end
    SetVehicleEngineOn(vehicle, true, true, false)
    stallInteractionBlockedUntil = GetGameTimer() + STALL_INTERACTION_BLOCK_MS
    SetGear(vehicle, 1)
end

local function startStallMinigame()
    if stallGameActive then return end
    stallGameActive = true
    stallGameToken  = stallGameToken + 1
    local token     = stallGameToken

    local isKb = SKInput.isUsingKeyboard()
    local promptVisible = not isPauseMenuOpen()
    if promptVisible then
        showStallPrompt(STALL_TIME_MS, isKb)
    end

    CreateThread(function()
        while token == stallGameToken and stalled do
            local presses   = 0
            local deadline  = GetGameTimer() + STALL_TIME_MS
            local lastWasKb = isKb

            while token == stallGameToken and stalled and GetGameTimer() < deadline do
                Wait(0)
                DisableControlAction(0, 14, true)
                DisableControlAction(0, INPUT_VEH_HORN, true)

                if isPauseMenuOpen() then
                    if promptVisible then
                        SendNUIMessage({ type = 'gearbox:stall:hide' })
                        promptVisible = false
                    end
                    deadline += math.floor(GetFrameTime() * 1000.0)
                else
                    if not promptVisible then
                        promptVisible = true
                        showStallPrompt(math.max(0, deadline - GetGameTimer()), SKInput.isUsingKeyboard())
                    end

                    local nowKb = SKInput.isUsingKeyboard()
                    if nowKb ~= lastWasKb then
                        lastWasKb = nowKb
                        SendNUIMessage({ type = 'gearbox:stall:input', isKeyboard = nowKb })
                    end

                    local control = SKInput.getInteractControl()
                    if IsControlJustPressed(0, control) then
                        presses = presses + 1
                        local pct = math.min(1.0, presses / STALL_PRESSES_NEEDED)
                        SendNUIMessage({ type = 'gearbox:stall:progress', pct = pct })

                        if presses >= STALL_PRESSES_NEEDED then
                            SendNUIMessage({ type = 'gearbox:stall:success' })
                            Wait(600)
                            SendNUIMessage({ type = 'gearbox:stall:hide' })
                            stallGameActive = false
                            stallCount = 0
                            doRestart()
                            return
                        end
                    end
                end
            end

            if token ~= stallGameToken or not stalled then return end

            if isPauseMenuOpen() then
                SendNUIMessage({ type = 'gearbox:stall:hide' })
                while token == stallGameToken and stalled and isPauseMenuOpen() do
                    Wait(100)
                end
                if token ~= stallGameToken or not stalled then return end
                promptVisible = true
                showStallPrompt(STALL_TIME_MS, SKInput.isUsingKeyboard())
            else
                SendNUIMessage({
                    type    = 'gearbox:stall:countdown',
                    seconds = math.floor(STALL_RETRY_DELAY_MS / 1000),
                })
            end
            Wait(STALL_RETRY_DELAY_MS)

            if token ~= stallGameToken or not stalled then return end

            promptVisible = not isPauseMenuOpen()
            if promptVisible then
                showStallPrompt(STALL_TIME_MS, SKInput.isUsingKeyboard())
            end
        end

        stallGameActive = false
    end)
end

local function doStall()
    if not GetIsVehicleEngineRunning(vehicle) or IsVehicleEngineStarting(vehicle) then return end
    SetVehicleEngineOn(vehicle, false, true, true)
    SetGear(vehicle, gear)
    stalled   = true
    restarted = false
    setStallSoundtrackBlocked(true)
    startStallMinigame()
end

local function shutdown()
    if vehicle ~= 0 then
        SetReducedRatio(vehicle, false)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce',      origForce)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel', origMaxVel)
    end
    stallGameToken  = stallGameToken + 1
    stallGameActive = false
    setStallSoundtrackBlocked(false)
    SendNUIMessage({ type = 'gearbox:stall:hide' })
    SendNUIMessage({ type = 'gearbox:badge', gearboxType = false })

    active        = false
    shifting      = false
    limiter       = false
    modified      = false
    stalled       = false
    restarted     = true
    stallCount    = 0
    requireClutch = false
    reqUp         = false
    reqDown       = false
    shiftEndsAt   = 0 ; shiftDur     = 0
    penaltyEndsAt = 0 ; penaltyDur   = 0
    shiftPct      = 0 ; penaltyPct   = 0
end

local UPSHIFT_BOOST_MULT = 1.18
local UPSHIFT_BOOST_MS   = 450

local runToken = 0

local function startLoop()
    runToken += 1
    local token = runToken

    CreateThread(function()
        local clutchReady   = false
        local clutchTimer   = 0
        local lastModTick   = 0
        local nativeGear    = 0
        local lastShiftUp   = false
        local boostEndsAt   = 0

        while token == runToken do
            if not active or vehicle == 0 then
                Wait(250)
                goto continue
            end

            if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
                shutdown()
                Wait(250)
                goto continue
            end

            Wait(0)

            local now     = GetGameTimer()
            local frameMs = math.max(GetFrameTime() * 1000.0, 1.0)
            local rpm     = GetVehicleCurrentRpm(vehicle)

            updateTimers()

            DisableControlAction(0, 363, true)
            DisableControlAction(0, 364, true)

            if reqUp then
                if requireClutch and not clutchDown then reqUp = false goto continue end
                local prev = gear
                if gear == -1 then
                    gear = 1
                elseif gear >= 1 and gear < gearCount then
                    gear = gear + 1
                end
                if gear ~= prev then
                    shiftDir     = shiftDir + (prev == -1 and 2 or 1)
                    lastShiftUp  = true
                    shifting     = true
                    local ms = clutchDown
                        and (shiftTimeUp * withClutchMult)
                        or  (shiftTimeUp * noClutchMult)
                    startShift(ms)
                    if not clutchDown then startPenalty(shiftTimeUp * noClutchMult) end
                end
                reqUp = false
            end

            if reqDown then
                if requireClutch and not clutchDown then reqDown = false goto continue end
                local prev = gear
                if gear == 1 then
                    gear = -1
                elseif gear >= 2 then
                    gear = gear - 1
                end
                if gear ~= prev then
                    shiftDir    = shiftDir - (prev == 1 and 2 or 1)
                    lastShiftUp = false
                    shifting    = true
                    local ms = clutchDown
                        and (shiftTimeDown * withClutchMult)
                        or  (shiftTimeDown * noClutchMult)
                    startShift(ms)
                    if not clutchDown then startPenalty(shiftTimeDown * noClutchMult) end
                end
                reqDown = false
            end

            if shifting and shiftPct == 0 and penaltyPct == 0 then
                playShiftSound()
                if lastShiftUp then
                    boostEndsAt = GetGameTimer() + UPSHIFT_BOOST_MS
                end
                shifting = false
                shiftDir = 0
            end

            nativeGear = GetVehicleCurrentGear(vehicle)

            if rpm >= 1.0 then
                limiter = true
            elseif rpm < 0.95 then
                limiter = false
            end
            -- if limiter and gear ~= 1 then
            --     DisableControlAction(0, gear == -1 and 72 or 71, true)
            -- end

            if not clutchReady then
                clutchTimer += 1
                if clutchTimer >= (500.0 / frameMs) then clutchReady = true end
            end

            if clutchReady then
                local clutchActive = shiftPct > 0 or penaltyPct > 0 or clutchDown
                if clutchActive then
                    local throttle = GetVehicleThrottleOffset(vehicle)
                    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', 0.0)
                    if not limiter then
                        if nativeGear == 0 then
                            if rpm < -throttle then
                                SetVehicleCurrentRpm(vehicle, rpm + (-throttle * origInertia * 0.02))
                            end
                        else
                            if rpm < throttle then
                                SetVehicleCurrentRpm(vehicle, rpm + (throttle * origInertia * 0.02))
                            end
                        end
                    end
                elseif not limiter then
                    local boost = (boostEndsAt > now) and UPSHIFT_BOOST_MULT or 1.0
                    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', origForce * boost)
                end

                if (now - lastModTick) >= 500 then
                    lastModTick = now
                    SetVehicleMod(vehicle, 11, GetVehicleMod(vehicle, 11), false)
                end
            end

            if not shifting then
                SetGear(vehicle, gear == -1 and 0 or gear)
            end

            local spd = GetEntitySpeedVector(vehicle, true)
            if gear == -1 then
                if spd.y > -2.0 then DisableControlAction(0, 71, true) end
            else
                if spd.y < 0.5  then DisableControlAction(0, 72, true) end
            end

            local clutchActive = shiftPct > 0 or penaltyPct > 0 or clutchDown
            if stallThreshold > 0 and nativeGear >= 2 and not stalled and not clutchActive then
                if rpm < stallThreshold then
                    stallCount += 1
                    if stallCount > (stallTimer / frameMs) then doStall() end
                else
                    stallCount = 0
                end
            elseif clutchActive then
                stallCount = 0
            end

            if stalled then
                if IsVehicleEngineStarting(vehicle) then
                    SetVehicleEngineOn(vehicle, false, true, true)
                end
                DisableControlAction(0, 14, true)
                SetGear(vehicle, gear == -1 and 0 or (gear == 0 and 1 or gear))
            end

            if GetIsVehicleEngineRunning(vehicle) then
                if stalled then
                    stallInteractionBlockedUntil = GetGameTimer() + STALL_INTERACTION_BLOCK_MS
                end
                stalled   = false
                restarted = true
            end

            if not shifting then
                if nativeGear == gearCount and not modified then
                    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel', origMaxVel * 0.888)
                    modified = true
                elseif nativeGear ~= gearCount and modified then
                    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel', origMaxVel)
                    modified = false
                end
            end

            ::continue::
        end
    end)
end

local function enableManual()
    if vehicle == 0 or not inVeh then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then return end
    if not isAllowedClass(vehicle) then return end
    if not activeGearboxType then return end

    local m = MODES[activeGearboxType] or MODES.beginner
    noClutchMult   = m.noClutchMult
    withClutchMult = m.withClutchMult
    stallThreshold = m.stallThreshold
    stallTimer     = m.stallTimer
    requireClutch  = m.requireClutch or false

    SetReducedRatio(vehicle, true)

    local upRate   = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleUpShift')
    local downRate = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleDownShift')
    gearCount      = GetVehicleHighGear(vehicle)
    shiftTimeUp    = (0.9 / upRate)   * 1000
    shiftTimeDown  = (0.9 / downRate) * 1000

    local transIdx = GetVehicleMod(vehicle, 13)
    if transIdx ~= -1 then
        local bonus = 1 + GetVehicleModModifierValue(vehicle, 13, transIdx) * 0.04
        if bonus > 1 then
            shiftTimeUp   = shiftTimeUp   - shiftTimeUp   / bonus
            shiftTimeDown = shiftTimeDown - shiftTimeDown / bonus
        end
    end

    gear       = 1
    stallCount = 0
    stalled    = false
    restarted  = true
    shifting   = false
    modified   = false
    limiter    = false
    active     = true

    SendNUIMessage({ type = 'gearbox:badge', gearboxType = activeGearboxType })
    startLoop()
end

lib.onCache('vehicle', function(veh)
    if veh and veh ~= 0 then
        vehicle     = veh
        inVeh       = true
        origForce   = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce')
        origInertia = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fDriveInertia')
        origMaxVel  = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
        if activeGearboxType ~= nil and isAllowedState() then
            enableManual()
        end
    else
        shutdown()
        inVeh   = false
        vehicle = 0
    end
end)

AddEventHandler('streetkings:gearbox:freeroamEnter', function()
    local gearboxType = lib.callback.await('streetkings:shop:getActiveVehicleGearbox', false)
    activeGearboxType = (gearboxType == 'beginner' or gearboxType == 'expert') and gearboxType or nil

    local cacheVeh = cache.vehicle
    if cacheVeh and cacheVeh ~= 0 and activeGearboxType ~= nil then
        vehicle     = cacheVeh
        inVeh       = true
        origForce   = GetVehicleHandlingFloat(cacheVeh, 'CHandlingData', 'fInitialDriveForce')
        origInertia = GetVehicleHandlingFloat(cacheVeh, 'CHandlingData', 'fDriveInertia')
        origMaxVel  = GetVehicleHandlingFloat(cacheVeh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
        enableManual()
    end
end)

---@param nextState string
AddEventHandler('streetkings:gearbox:freeroamExit', function(nextState)
    if nextState == GameState.EVENT or nextState == GameState.MULTIPLAYER_LOBBY or nextState == GameState.MULTIPLAYER_EVENT then
        return
    end

    shutdown()
    activeGearboxType = nil
end)

---@param targetVehicle integer
AddEventHandler('streetkings:gearbox:forceRestartAfterTransition', function(targetVehicle)
    forceRestartAfterTransition(targetVehicle)
end)

function SKGearbox.getType()
    return activeGearboxType
end

---@return boolean
function SKGearbox.isStallInteractionBlocked()
    return stalled or GetGameTimer() < stallInteractionBlockedUntil
end
