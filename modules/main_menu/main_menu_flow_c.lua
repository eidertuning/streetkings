SKMainMenu = SKMainMenu or {}

local isTransitioning = false

---@param slotIndex integer
---@param isNew boolean
---@param saveId string|nil
---@param saveName string|nil
---@return table
function SKMainMenu.pickSave(slotIndex, isNew, saveId, saveName)
    if isTransitioning then
        return { ok = false, error = 'already_transitioning' }
    end

    local result = lib.callback.await('streetkings:saves:select', false, slotIndex, isNew, saveId, saveName)
    if not result or not result.ok then
        return { ok = false, error = result and result.error or nil }
    end

    isTransitioning = true

    CreateThread(function()
        DoScreenFadeOut(500)
        Wait(500)

        local document = lib.callback.await('streetkings:saves:loadActive', false)
        if not document or not document.ok then
            isTransitioning = false
            DoScreenFadeIn(500)
            SKC.SetGameState(GameState.MAIN_MENU)
            return
        end

        local garage = document.document.garage

        if garage.activeVehicleId == '' and next(garage.vehicles) == nil then
            isTransitioning = false
            SKC.SetGameState(GameState.INITIATION)
        else
            isTransitioning = false
            SKGarage.enterFromMenu()
        end
    end)

    return { ok = true, saveId = result.saveId }
end

---@return table
function SKMainMenu.requestSaves()
    local data = lib.callback.await('streetkings:saves:list', false)
    if not data or not data.ok then
        return {
            ok = false,
            error = data and data.error or nil,
            slots = SKSaves.emptySlots(),
            slotsVersion = SKSaves.SLOTS_VERSION,
            saveSlotCount = SKSaves.SLOT_COUNT,
        }
    end

    return {
        ok = true,
        slots = data.slots,
        slotsVersion = data.slotsVersion,
        saveSlotCount = SKSaves.SLOT_COUNT,
    }
end

---@return table
function SKMainMenu.requestLastPlayed()
    local data = lib.callback.await('streetkings:saves:getLastPlayed', false)
    if not data or not data.ok then
        return {
            ok = false,
            error = data and data.error or nil,
        }
    end

    return {
        ok = true,
        save = data.save,
    }
end

---@param slotIndex integer
---@param saveId string
---@return table
function SKMainMenu.deleteSave(slotIndex, saveId)
    local result = lib.callback.await('streetkings:saves:delete', false, slotIndex, saveId)
    if not result or not result.ok then
        return { ok = false, error = result and result.error or nil }
    end
    return { ok = true }
end