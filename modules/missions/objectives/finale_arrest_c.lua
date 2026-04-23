SKObjectives = SKObjectives or {}

local handler = {}

local function spawnCopCar(coords, heading)
    local vehHash = SK.LoadModel('police')
    if not vehHash then return nil, nil end
    local pedHash = SK.LoadModel('s_m_y_cop_01')
    if not pedHash then SK.UnloadModel(vehHash) return nil, nil end

    local veh = CreateVehicle(vehHash, coords.x, coords.y, coords.z, heading, false, false)
    SK.UnloadModel(vehHash)
    if veh == 0 then return nil, nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleSiren(veh, true)

    local ped = CreatePedInsideVehicle(veh, 4, pedHash, -1, false, false)
    SK.UnloadModel(pedHash)
    if ped == 0 then DeleteEntity(veh) return nil, nil end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanBeDraggedOut(ped, false)

    return veh, ped
end

local function deleteEntity(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

local function spawnCellPed(model, pos)
    local hash = SK.LoadModel(model)
    if not hash then return 0 end
    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z - 1.0, pos.w or 0.0, false, false)
    SK.UnloadModel(hash)
    if ped == 0 then return 0 end
    SetPedDefaultComponentVariation(ped)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)

    local found, groundZ = false, pos.z
    for _ = 1, 20 do
        found, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
        if found then break end
        Wait(50)
    end
    SetEntityCoords(ped, pos.x, pos.y, found and groundZ or pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.w or 0.0)
    FreezeEntityPosition(ped, true)

    return ped
end

local function playChatter(ped, durationMs)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    CreateThread(function()
        if not SK.LoadAnimDict('mp_facial') then return end
        PlayFacialAnim(ped, 'mic_chatter', 'mp_facial')
        Wait(durationMs or 3000)
        if DoesEntityExist(ped) then
            PlayFacialAnim(ped, 'mood_normal_1', 'facials@gen_male@variations@normal')
        end
        RemoveAnimDict('mp_facial')
    end)
end

local function showSubtitle(speaker, body, duration)
    SendNUIMessage({ type = 'missions:subtitle', speaker = speaker, body = body, duration = duration or 3500 })
end

local function disableControlsThisFrame()
    HideHudAndRadarThisFrame()
    DisableAllControlActions(0)
end

local function runAmbush(ctx, obj)
    local entities = {}
    SKPolice.setPoliceDisabled(true)

    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    ctx.playerVehicle = playerVeh
    if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
        FreezeEntityPosition(playerVeh, true)
        SetVehicleHandbrake(playerVeh, true)
    end

    Cinematic = true

    local trapPos = obj.trapCop
    local trapVeh, trapPed = spawnCopCar(vector3(trapPos.x, trapPos.y, trapPos.z), trapPos.w)
    if trapVeh then
        entities[#entities+1] = trapVeh
        entities[#entities+1] = trapPed
        TaskVehicleChase(trapPed, PlayerPedId())
        SetTaskVehicleChaseBehaviorFlag(trapPed, 32, true)
        SetTaskVehicleChaseIdealPursuitDistance(trapPed, 8.0)
    end

    if trapVeh and DoesEntityExist(trapVeh) then
        SKPolice.caughtSpeeding(trapVeh)
    end
    Cinematic = true

    local playerPos = GetEntityCoords(PlayerPedId())
    for _, c4 in ipairs(obj.extraCops or {}) do
        local veh, ped = spawnCopCar(vector3(c4.x, c4.y, c4.z), c4.w)
        if veh and ped then
            entities[#entities+1] = veh
            entities[#entities+1] = ped
            TaskVehicleDriveToCoordLongrange(ped, veh, playerPos.x, playerPos.y, playerPos.z, 30.0, 786603, 5.0)
        end
    end

    local boxTimer = GetGameTimer() + 4000
    while GetGameTimer() < boxTimer do
        disableControlsThisFrame()
        Wait(0)
    end

    DoScreenFadeOut(1500)
    Wait(2000)

    if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
        FreezeEntityPosition(playerVeh, false)
        SetVehicleHandbrake(playerVeh, false)
    end

    for _, ped in ipairs(SKGetawayRobbers or {}) do deleteEntity(ped) end
    SKGetawayRobbers = nil
    SKGetawayVehicle = nil
    for _, ent in ipairs(entities) do deleteEntity(ent) end
end

local function runInterrogation(ctx, obj)
    local cellPlayer = obj.cellPlayer
    local cellGabe   = obj.cellGabe
    local cellVargas = obj.cellVargas

    local playerVeh = ctx.playerVehicle
    if playerVeh and playerVeh ~= 0 and DoesEntityExist(playerVeh) then
        deleteEntity(playerVeh)
    end
    ctx.playerVehicle = nil

    SKC.SetGameState(GameState.FREEROAM)
    Wait(100)

    local player = PlayerPedId()
    ClearPedTasksImmediately(player)
    Wait(100)

    SetEntityCoords(player, cellPlayer.x, cellPlayer.y, cellPlayer.z, false, false, false, false)
    SetEntityHeading(player, cellPlayer.w)
    Wait(500)

    local found, groundZ = false, cellPlayer.z
    for _ = 1, 20 do
        found, groundZ = GetGroundZFor_3dCoord(cellPlayer.x, cellPlayer.y, cellPlayer.z + 2.0, false)
        if found then break end
        Wait(50)
    end
    if found then
        SetEntityCoords(player, cellPlayer.x, cellPlayer.y, groundZ, false, false, false, false)
    end
    SetEntityHeading(player, cellPlayer.w)
    FreezeEntityPosition(player, true)
    SetPlayerWantedLevel(PlayerId(), 0, false)
    SetPlayerWantedLevelNow(PlayerId(), false)

    Cinematic = true

    local gabePed = spawnCellPed('a_m_y_business_03', cellGabe)
    local vargasPed = spawnCellPed('s_m_y_cop_01', cellVargas)

    if vargasPed ~= 0 and SK.LoadAnimDict('anim@heists@heist_corona@single_team') then
        TaskPlayAnim(vargasPed, 'anim@heists@heist_corona@single_team', 'single_team_loop_boss', 4.0, -4.0, -1, 1, 0.0, false, false, false)
    end
    if gabePed ~= 0 and SK.LoadAnimDict('anim@amb@nightclub@lazlow@ig1_vip@') then
        TaskPlayAnim(gabePed, 'anim@amb@nightclub@lazlow@ig1_vip@', 'ig1_introcrowd_laz', 4.0, -4.0, -1, 1, 0.0, false, false, false)
    end

    Wait(500)

    local HEAD = 0.4

    local activeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(activeCam, 464.5, -994.3, 26.4)
    PointCamAtEntity(activeCam, player, 0.0, 0.0, HEAD, true)
    SetCamFov(activeCam, 50.0)
    SetCamActive(activeCam, true)
    RenderScriptCams(true, false, 0, true, true)
    DoScreenFadeIn(1500)
    Wait(1000)

    local varCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(varCam, 461.5, -994.2, 26.2)
    PointCamAtEntity(varCam, vargasPed, 0.0, 0.0, HEAD, true)
    SetCamFov(varCam, 28.0)
    SetCamActiveWithInterp(varCam, activeCam, 1500, true, true)
    Wait(1800)
    DestroyCam(activeCam, false)
    activeCam = varCam

    showSubtitle('Vargas', "End of the line, racer.", 3000)
    playChatter(vargasPed, 3000)
    Wait(3500)
    showSubtitle('Vargas', "Grand theft. Armed robbery. Criminal conspiracy. Three felonies, one night.", 4000)
    playChatter(vargasPed, 4000)
    Wait(4500)
    showSubtitle('Vargas', "Twenty years minimum. Unless you want to hear option B.", 3500)
    playChatter(vargasPed, 3500)
    Wait(4000)

    local plyCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(plyCam, 462.2, -994.3, 26.2)
    PointCamAtEntity(plyCam, player, 0.0, 0.0, HEAD, true)
    SetCamFov(plyCam, 30.0)
    SetCamActiveWithInterp(plyCam, activeCam, 1500, true, true)
    Wait(1800)
    DestroyCam(activeCam, false)
    activeCam = plyCam

    showSubtitle('You', "...Gabe?", 2500)
    Wait(3000)

    local gabCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(gabCam, 461.6, -994.5, 26.2)
    PointCamAtEntity(gabCam, gabePed, 0.0, 0.0, HEAD, true)
    SetCamFov(gabCam, 28.0)
    SetCamActiveWithInterp(gabCam, activeCam, 1500, true, true)
    Wait(1800)
    DestroyCam(activeCam, false)
    activeCam = gabCam

    showSubtitle('Gabe', "Detective Gabriel Reyes, LSPD Organized Crime Unit. It's been a long three weeks.", 4000)
    playChatter(gabePed, 4000)
    Wait(4500)
    showSubtitle('Gabe', "Every drop. Every plate. Every face. You handed it all to me.", 4000)
    playChatter(gabePed, 4000)
    Wait(4500)

    local varCam2 = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(varCam2, 461.4, -994.0, 26.2)
    PointCamAtEntity(varCam2, vargasPed, 0.0, 0.0, HEAD, true)
    SetCamFov(varCam2, 28.0)
    SetCamActiveWithInterp(varCam2, activeCam, 1500, true, true)
    Wait(1800)
    DestroyCam(activeCam, false)
    activeCam = varCam2

    showSubtitle('Vargas', "So here's the deal.", 2200)
    playChatter(vargasPed, 2200)
    Wait(2800)

    local gabCam2 = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(gabCam2, 461.7, -994.6, 26.2)
    PointCamAtEntity(gabCam2, gabePed, 0.0, 0.0, HEAD, true)
    SetCamFov(gabCam2, 28.0)
    SetCamActiveWithInterp(gabCam2, activeCam, 1500, true, true)
    Wait(1800)
    DestroyCam(activeCam, false)
    activeCam = gabCam2

    showSubtitle('Gabe', "You get back on the street. You keep driving. For Saint. For us.", 4000)
    playChatter(gabePed, 4000)
    Wait(4500)
    showSubtitle('Gabe', "You tell me everything. Every pickup, every drop, every name.", 4000)
    playChatter(gabePed, 4000)
    Wait(4500)
    showSubtitle('Gabe', "You cooperate, and in six months this all goes away. You don't... well. Vargas has a cell with your name on it.", 5000)
    playChatter(gabePed, 5000)
    Wait(5500)

    local varCam3 = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(varCam3, 461.6, -994.1, 26.2)
    PointCamAtEntity(varCam3, vargasPed, 0.0, 0.0, HEAD, true)
    SetCamFov(varCam3, 28.0)
    SetCamActiveWithInterp(varCam3, activeCam, 1500, true, true)
    Wait(1800)
    DestroyCam(activeCam, false)
    activeCam = varCam3

    showSubtitle('Vargas', "Choose now. Clock's ticking.", 3000)
    playChatter(vargasPed, 3000)
    Wait(3500)
    Wait(2000)

    DoScreenFadeOut(1500)
    Wait(1800)

    RenderScriptCams(false, false, 0, false, false)
    DestroyCam(activeCam, false)
    Cinematic = false

    SendNUIMessage({ type = 'toBeContinued', show = true })
    Wait(6000)
    SendNUIMessage({ type = 'toBeContinued', show = false })

    FreezeEntityPosition(player, false)
    deleteEntity(gabePed)
    deleteEntity(vargasPed)

    SKPolice.setPoliceDisabled(false)
    SetPlayerWantedLevel(PlayerId(), 0, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
    SKC.SetGameState(GameState.MISSION)
    Wait(100)
    lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'finale_arrest' })
    Wait(300)

    SendNUIMessage({ type = 'arrested', show = true })
    Wait(5000)
    DoScreenFadeOut(400)
    Wait(500)
    SendNUIMessage({ type = 'arrested', show = false })
    if SKPhone.isOpen() then SKPhone.close() end
    SKGarage.enterFromMenu()
end

function handler.start(ctx)
    local obj = ctx.objective
    ctx.active = true

    CreateThread(function()
        runAmbush(ctx, obj)
        if not ctx.active then return end
        runInterrogation(ctx, obj)
    end)

    return {
        remove = function()
            ctx.active = false
            Cinematic = false
            FreezeEntityPosition(PlayerPedId(), false)
            RenderScriptCams(false, false, 0, false, false)
            SKPolice.setPoliceDisabled(false)
        end,
    }
end

function handler.stop(ctx)
    ctx.active = false
    Cinematic = false
    FreezeEntityPosition(PlayerPedId(), false)
    RenderScriptCams(false, false, 0, false, false)
    SKPolice.setPoliceDisabled(false)
end

SKObjectives[ObjectiveType.FINALE_ARREST] = handler
