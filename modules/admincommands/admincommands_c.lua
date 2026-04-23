RegisterNetEvent('streetkings:admin:teleport', function(x, y, z)
    SKC.Warp(vector3(x, y, z), GetEntityHeading(PlayerPedId()))
end)

RegisterNetEvent('streetkings:admin:teleportMarker', function()
    local ok, message = SKC.WarpToWaypoint()
    if not ok and message then
        SKNotify({ type = 'error', title = message })
    end
end)

RegisterNetEvent('streetkings:admin:logout', function()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    SKC.SetGameState(GameState.MAIN_MENU)
    DoScreenFadeIn(500)
end)

RegisterNetEvent('streetkings:admin:copyCoords', function(coords)
    lib.setClipboard(('vector3(%.4f, %.4f, %.4f)'):format(coords.x, coords.y, coords.z))
end)

RegisterNetEvent('streetkings:admin:copyCoords4', function(coords, heading)
    lib.setClipboard(('vector4(%.4f, %.4f, %.4f, %.4f)'):format(coords.x, coords.y, coords.z, heading))
end)