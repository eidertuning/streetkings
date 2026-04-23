CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            TriggerEvent('streetkings:client:init')
            return
        end
    end
end)

AddEventHandler('streetkings:client:init', function()
    SendLoadingScreenMessage(json.encode({ action = 'streetkings:fadeOut' }))
    DoScreenFadeOut(0)
    SKMainMenu.enterScene()

    while not SKMainMenu.isCameraReady() do
        Wait(50)
    end

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    SKC.SetGameState(GameState.MAIN_MENU)
end)

CreateThread(function()
    -- one-time setup
    SetDitchPoliceModels(false)
    SetVehiclePopulationBudget(3)
    SetPedPopulationBudget(3)
    SetReduceVehicleModelBudget(false)
    SetReducePedModelBudget(false)
    SetAllVehicleGeneratorsActive(true)
    SetDispatchCopsForPlayer(PlayerId(), true)
    SetAudioFlag("OnlyAllowScriptTriggerPoliceScanner", false)
    RemoveScenarioBlockingAreas()
    SetScenarioGroupEnabled(`MP_POLICE`, true)
    for i = 1, 16 do
        BlockDispatchServiceResourceCreation(i, false)
    end

    while true do
        SetCreateRandomCops(true)
        for i = 1, 15 do
            EnableDispatchService(i, true)
        end

        SetVehicleModelIsSuppressed(`police`, false)
        SetVehicleModelIsSuppressed(`police2`, false)
        SetVehicleModelIsSuppressed(`police3`, false)
        SetVehicleModelIsSuppressed(`police4`, false)
        SetVehicleModelIsSuppressed(`sheriff`, false)
        SetVehicleModelIsSuppressed(`sheriff2`, false)
        SetVehicleModelIsSuppressed(`sheriff3`, false)
        Wait(2000)
    end
end)

CreateThread(function()
    local lastZone = -1
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local zone = GetZoneAtCoords(pos.x, pos.y, pos.z)
        if zone ~= lastZone then
            local schedule = GetZonePopschedule(zone)
            Citizen.InvokeNative(0x4f82f932d29836a2, schedule, "VEH_COPCAR_MP", 10)
            lastZone = zone
        end
        Wait(5000)
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        HideHudComponentThisFrame(6)
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(8)
        HideHudComponentThisFrame(9)
    end
end)

CreateThread(function()
    -- DJ tracks (iFruit Radio etc.)
    UpdateUnlockableDjRadioTracks(true)
    -- The Contract / Hip Hop New (Radio Los Santos)
    UnlockRadioStationTrackList("RADIO_03_HIPHOP_NEW", "RADIO_03_HIPHOP_NEW_DD_DJSOLO_POST_LAUNCH")
    UnlockRadioStationTrackList("RADIO_03_HIPHOP_NEW", "RADIO_03_HIPHOP_NEW_DD_MUSIC_POST_LAUNCH_UPDATE")
    -- Classic Hip Hop (West Coast Classics)
    UnlockRadioStationTrackList("RADIO_09_HIPHOP_OLD", "RADIO_09_HIPHOP_OLD_DJSOLO")
    UnlockRadioStationTrackList("RADIO_09_HIPHOP_OLD", "RADIO_09_HIPHOP_OLD_IDENTS")
    UnlockRadioStationTrackList("RADIO_09_HIPHOP_OLD", "RADIO_09_HIPHOP_OLD_MUSIC")
    UnlockRadioStationTrackList("RADIO_09_HIPHOP_OLD", "RADIO_09_HIPHOP_OLD_MUSIC_NEW")
    UnlockRadioStationTrackList("RADIO_09_HIPHOP_OLD", "RADIO_09_HIPHOP_OLD_DD_DJSOLO_POST_LAUNCH")
    UnlockRadioStationTrackList("RADIO_09_HIPHOP_OLD", "RADIO_09_HIPHOP_OLD_DD_MUSIC_POST_LAUNCH")
    UnlockRadioStationTrackList("RADIO_09_HIPHOP_OLD", "RADIO_09_HIPHOP_OLD_CORE_MUSIC")
    -- Mirror Park (Shine A Light unlock via SP mission FAM5_JIMMYTAKE)
    UnlockRadioStationTrackList("RADIO_16_SILVERLAKE", "MIRRORPARK_LOCKED")
    -- LS Car Meet / The Tuner audio player (USB mixes)
    UnlockRadioStationTrackList("RADIO_36_AUDIOPLAYER", "TUNER_AP_SILENCE_MUSIC")
    UnlockRadioStationTrackList("RADIO_36_AUDIOPLAYER", "TUNER_AP_MIX3_PARTC")
    UnlockRadioStationTrackList("RADIO_36_AUDIOPLAYER", "TUNER_AP_MIX3_PARTD")
    UnlockRadioStationTrackList("RADIO_36_AUDIOPLAYER", "FIXER_AP_LOWRIDERS_MIX")
end)

CreateThread(function()
    -- put this in a slow loop because sometimes it seems to get reset.
    while true do
        SetInstancePriorityHint(0)
        Wait(10000)
    end
end)

RegisterCommand('phone', function()
    TriggerEvent('streetkings:phone:toggle')
end)
RegisterKeyMapping('phone', 'Open Phone', 'keyboard', 'TAB')