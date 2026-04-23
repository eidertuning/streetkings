-- Objective: cutscene / dialog - plays a scripted scene and auto-advances
SKObjectives = SKObjectives or {}
SKMissionShared = SKMissionShared or {}

local function spawnOpponent(missionDef)
    local spawn = missionDef and missionDef.opponentSpawn
    if not spawn or not spawn.coords then return nil, nil end

    local vehHash = SK.LoadModel(spawn.vehicleModel or 'elegy', 8000)
    if not vehHash then return nil, nil end

    local pedHash = SK.LoadModel(spawn.pedModel or 'a_m_y_hipster_02', 8000)
    if not pedHash then
        SK.UnloadModel(vehHash)
        return nil, nil
    end

    local c = spawn.coords
    local veh = CreateVehicle(vehHash, c.x, c.y, c.z, c.w, true, false)
    SK.UnloadModel(vehHash)
    if veh == 0 then return nil, nil end

    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleDoorsLocked(veh, 2)
    SetEntityInvincible(veh, true)
    SetVehicleEngineOn(veh, true, true, false)

    local ped = CreatePed(4, pedHash, c.x, c.y, c.z, c.w, true, false)
    SK.UnloadModel(pedHash)
    if ped == 0 then
        DeleteEntity(veh)
        return nil, nil
    end
    SetPedDefaultComponentVariation(ped)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedIntoVehicle(ped, veh, -1)
    SetEntityInvincible(ped, true)

    return veh, ped
end

local function deleteNPC()
    if SKMissionShared.preSpawnedPed and DoesEntityExist(SKMissionShared.preSpawnedPed) then
        SetEntityAsMissionEntity(SKMissionShared.preSpawnedPed, false, true)
        DeleteEntity(SKMissionShared.preSpawnedPed)
    end
    if SKMissionShared.preSpawnedVeh and DoesEntityExist(SKMissionShared.preSpawnedVeh) then
        SetEntityAsMissionEntity(SKMissionShared.preSpawnedVeh, false, true)
        DeleteEntity(SKMissionShared.preSpawnedVeh)
    end
    SKMissionShared.preSpawnedVeh = nil
    SKMissionShared.preSpawnedPed = nil
end

local burnoutThread = nil

local function startBurnout(ped, veh)
    if not ped or not veh then return end
    burnoutThread = CreateThread(function()
        while DoesEntityExist(veh) and DoesEntityExist(ped) do
            TaskVehicleTempAction(ped, veh, 30, 3500)
            Wait(3000)
        end
    end)
end

local function stopBurnout()
    burnoutThread = nil
end

local function runScene(ctx)
    local obj = ctx.objective
    local cutsceneId = obj.cutsceneId
    local hasOpponent = obj.preSpawnOpponent and ctx.missionDef and ctx.missionDef.opponentSpawn

    local npcVeh = SKMissionShared.preSpawnedVeh
    local npcPed = SKMissionShared.preSpawnedPed

    if hasOpponent then
        if not npcVeh or not DoesEntityExist(npcVeh) then
            npcVeh, npcPed = spawnOpponent(ctx.missionDef)
            if npcVeh then
                SKMissionShared.preSpawnedVeh = npcVeh
                SKMissionShared.preSpawnedPed = npcPed
            end
        end

        if npcVeh and DoesEntityExist(npcVeh) then
            startBurnout(npcPed, npcVeh)
        end
    end

    if type(cutsceneId) == 'string' and cutsceneId ~= '' then
        SKCutscene.play(cutsceneId, { missionId = ctx.missionId })
    end

    stopBurnout()

    if hasOpponent then
        DoScreenFadeOut(300)
        Wait(350)

        deleteNPC()

        local newVeh, newPed = spawnOpponent(ctx.missionDef)
        if newVeh then
            FreezeEntityPosition(newVeh, true)
            SetVehicleHandbrake(newVeh, true)
            SKMissionShared.preSpawnedVeh = newVeh
            SKMissionShared.preSpawnedPed = newPed
        end

        DoScreenFadeIn(300)
        Wait(320)
    end

    local result = lib.callback.await('streetkings:missions:advanceObjective', false, { source = 'cutscene' })
    return result
end

local handler = {}

function handler.start(ctx)
    CreateThread(function()
        Wait(200)
        runScene(ctx)
    end)
    return nil
end

function handler.stop(ctx) end

SKObjectives[ObjectiveType.CUTSCENE] = handler
SKObjectives[ObjectiveType.DIALOG] = handler
