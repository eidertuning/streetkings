lib.callback.register('streetkings:tutorial:complete', function(source)
    local document = SKSaves.getDocument(source)
    if not document then return { ok = false } end
    if document.progression.tutorialCompleted then return { ok = false } end

    document.progression.tutorialCompleted = true
    SKSaves.write(source, 'progression.tutorialCompleted', true)

    -- Seed Chapter 1. Mission 1 unlocks 1 minute after the tutorial wraps.
    if SKSaves.defaultMissions then
        local missions = document.missions
        if type(missions) ~= 'table' then
            missions = SKSaves.defaultMissions()
            document.missions = missions
        end
        if (missions.chapter or 0) == 0 then
            missions.chapter = 1
            missions.chapterMissionIndex = 0
            missions.nextAvailableAt = os.time() + 60
            SKSaves.write(source, 'missions', missions)
        end
    end

    local cfg = TutorialConfig.REWARDS
    local cashAmount = cfg.cash
    local playerXp   = cfg.playerXp
    local vehicleXp  = cfg.vehicleXp

    if cashAmount > 0 then
        document.economy.cash = document.economy.cash + cashAmount
        SKSaves.write(source, 'economy.cash', document.economy.cash)
    end

    local playerReward  = SKProgression.awardPlayerXp(source, playerXp)
    local vehicleReward = SKProgression.awardVehicleXp(source, vehicleXp)

    if #playerReward.levelUps > 0 then
        TriggerClientEvent('streetkings:progression:playerLevelUp', source, playerReward)
    end

    local parts = {}
    if cashAmount > 0 then parts[#parts + 1] = ('$%d'):format(cashAmount) end
    if playerReward.xpGained > 0 then parts[#parts + 1] = ('Player +%d XP'):format(playerReward.xpGained) end
    if vehicleReward.xpGained > 0 then parts[#parts + 1] = ('Vehicle +%d XP'):format(vehicleReward.xpGained) end
    if playerReward.cosmeticCurrencyAwarded > 0 then parts[#parts + 1] = ('GearCoins +%d'):format(playerReward.cosmeticCurrencyAwarded) end

    SKMissionsServer.initializeForPlayer(source)

    return {
        ok      = true,
        summary = table.concat(parts, ' | '),
        reward  = {
            cash    = { amount = cashAmount },
            cosmeticCurrency = { amount = playerReward.cosmeticCurrencyAwarded },
            player  = playerReward,
            vehicle = vehicleReward,
        },
    }
end)

lib.callback.register('streetkings:tutorial:skip', function(source)
    return true
end)

AddEventHandler('streetkings:freeroam:enter', function()
    local src = source --[[@as integer]]
    if not SKSaves.hasActiveSave(src) then return end
    local document = SKSaves.getDocument(src)
    if not document or not document.progression then return end
    if not document.progression.tutorialCompleted then return end
    if document.progression.tutorialPhoneSent then return end

    document.progression.tutorialPhoneSent = true
    SKSaves.write(src, 'progression.tutorialPhoneSent', true)

    SKMessages.enqueue(src, 'Hector', 'hector', TutorialConfig.HECTOR_PHONE, 0)
end)

lib.callback.register('streetkings:tutorial:getVehicleModel', function(source)
    local document = SKSaves.getDocument(source)
    if not document then return nil end
    local activeId = document.garage.activeVehicleId
    if not activeId or activeId == '' then return nil end
    local entry = document.garage.vehicles[activeId]
    if not entry then return nil end
    local colors = entry.data and entry.data.colors or nil
    return {
        modelName = entry.modelName,
        colors    = colors,
    }
end)