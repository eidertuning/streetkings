SKC.RegisterGameState(GameState.MAIN_MENU, {
    onEnter = function()
        SKMainMenu.enterScene()
        CreateThread(function()
            SKMainMenu.waitForNui()
            SKMainMenu.open()
            while not SKMainMenu.isCameraReady() do Wait(100) end
            DoScreenFadeIn(500)
        end)
    end,

    onExit = function()
        SKMainMenu.close()
        SKMainMenu.leaveScene()
    end,

    onTick = function()
        SKMainMenu.tickScene()
        HideHudAndRadarThisFrame()
        DisableAllControlActions(0)
        DisableAllControlActions(1)
        DisableAllControlActions(2)
    end,
})