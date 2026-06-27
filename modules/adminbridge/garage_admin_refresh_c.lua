-- Bridge opcional para StreetKings.
-- Este archivo debe cargarse dentro del recurso streetkings para que ce_skadmin pueda refrescar
-- el NUI real del garaje después de cambiar XP de vehículo desde SQL/admin.

RegisterNetEvent('streetkings:garage:adminRefresh', function(payload)
    if type(payload) ~= 'table' then return end
    if not SKC or not SKC.GetGameState or not GameState then return end
    if SKC.GetGameState() ~= GameState.GARAGE then return end
    payload.type = 'garage:adminRefresh'
    SendNUIMessage(payload)
end)
