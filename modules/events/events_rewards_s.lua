SKEventsRewards = {}

local raceRewardBounds = nil
local scaledRaceRewardConfigs = {}

---@param source integer
---@return string|nil
function SKEventsRewards.getActiveVehicleClass(source)
    local _, vehicleEntry = SKProgression.getActiveVehicleEntry(source)
    if not vehicleEntry then
        return nil
    end

    return SKEventsConfig.MODEL_CLASS_LOOKUP[vehicleEntry.modelName]
end

---@param source integer
---@return string, table
function SKEventsRewards.requireActiveVehicleEntry(source)
    local vehicleId, vehicleEntry = SKProgression.getActiveVehicleEntry(source)
    assert(vehicleId ~= nil and vehicleEntry ~= nil, 'streetkings: missing active vehicle')
    return vehicleId, vehicleEntry
end

---@param value number
---@return integer
local function roundRewardValue(value)
    return math.floor(value + 0.5)
end

---@param activity table
---@return number
local function measureRaceRewardMetric(activity)
    local route = SKEventRoute.buildPreviewRoute(activity)
    local distanceMeters = 0.0

    for i = 2, #route do
        distanceMeters = distanceMeters + #(route[i] - route[i - 1])
    end

    local checkpointCount = #route - 1
    return distanceMeters + checkpointCount * SKEventsConfig.DAILY_RACE_REWARD_SCALING.checkpointWeightMeters
end

---@return { minimumMetric: number, maximumMetric: number }
local function getRaceRewardBounds()
    if raceRewardBounds then
        return raceRewardBounds
    end

    local minimumMetric = math.huge
    local maximumMetric = 0.0
    local raceCount = 0

    for _, activity in pairs(SKEvents) do
        if type(activity) == 'table' and activity.type == EventType.RACE and type(activity.checkpoints) == 'table' then
            local metric = measureRaceRewardMetric(activity)
            minimumMetric = math.min(minimumMetric, metric)
            maximumMetric = math.max(maximumMetric, metric)
            raceCount = raceCount + 1
        end
    end

    assert(raceCount > 0, 'streetkings: missing race reward metrics')

    raceRewardBounds = {
        minimumMetric = minimumMetric,
        maximumMetric = maximumMetric,
    }

    return raceRewardBounds
end

---@param bundle table
---@param scale number
---@return table
local function scaleRewardBundle(bundle, scale)
    return {
        cash = roundRewardValue(bundle.cash * scale),
        playerXp = roundRewardValue(bundle.playerXp * scale),
        vehicleXp = roundRewardValue(bundle.vehicleXp * scale),
    }
end

---@param activity table
---@return number
local function getRaceRewardScale(activity)
    local bounds = getRaceRewardBounds()
    local metric = measureRaceRewardMetric(activity)
    local normalized = 1.0

    if bounds.maximumMetric > bounds.minimumMetric then
        normalized = (metric - bounds.minimumMetric) / (bounds.maximumMetric - bounds.minimumMetric)
    end

    normalized = math.max(0.0, math.min(1.0, normalized))

    local config = SKEventsConfig.DAILY_RACE_REWARD_SCALING
    return config.minimumScale + (1.0 - config.minimumScale) * normalized
end

---@param activity table
---@return table
local function getTimeTrialRewardConfig(activity)
    if activity.type == EventType.DELIVERY then
        return SKEventsConfig.DAILY_REWARD_CONFIG.delivery
    end

    local eventId = activity.id
    if scaledRaceRewardConfigs[eventId] then
        return scaledRaceRewardConfigs[eventId]
    end

    local scaling = SKEventsConfig.DAILY_RACE_REWARD_SCALING
    local rewards = scaling.rewards
    local scale = getRaceRewardScale(activity)
    local config = {
        base = scaleRewardBundle(rewards.base, scale),
        goalBonus = scaleRewardBundle(rewards.goalBonus, scale),
        earlyBoardBonus = scaleRewardBundle(rewards.earlyBoardBonus, scale),
        rankedBands = {},
    }

    for i, band in ipairs(rewards.rankedBands) do
        local scaledBand = scaleRewardBundle(band, scale)
        config.rankedBands[i] = {
            maxPercentile = band.maxPercentile,
            label = band.label,
            cash = scaledBand.cash,
            playerXp = scaledBand.playerXp,
            vehicleXp = scaledBand.vehicleXp,
        }
    end

    scaledRaceRewardConfigs[eventId] = config
    return config
end

---@param source integer
---@return table
function SKEventsRewards.buildRewardShell(source)
    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active document')
    local progression = document.progression
    local _, vehicleEntry = SKEventsRewards.requireActiveVehicleEntry(source)
    local vehicleData = vehicleEntry.data

    return {
        cash = { amount = 0 },
        cosmeticCurrency = { amount = 0 },
        player = {
            xpGained = 0,
            oldLevel = progression.level,
            newLevel = progression.level,
            levelUps = {},
        },
        vehicle = {
            xpGained = 0,
            oldLevel = vehicleData.level,
            newLevel = vehicleData.level,
            unlocks = {},
        },
        summary = '',
        awarded = false,
    }
end

---@param source integer
---@param eventId string
---@param scoreValue integer
---@param scoreType 'time'|'speed'|'points'
---@return boolean, boolean
function SKEventsRewards.recordActivityBest(source, eventId, scoreValue, scoreType)
    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active document')
    local progression = document.progression
    local _, vehicleEntry = SKEventsRewards.requireActiveVehicleEntry(source)
    local vehicleData = vehicleEntry.data
    local playerFirst, playerImproved = SKProgression.recordActivityBest(progression.bestActivityScores, eventId, scoreValue, scoreType)
    local vehicleFirst, vehicleImproved = SKProgression.recordActivityBest(vehicleData.bestActivityScores, eventId, scoreValue, scoreType)

    SKSaves.write(source, 'progression.bestActivityScores', progression.bestActivityScores)
    SKSaves.write(source, 'garage.vehicles.' .. document.garage.activeVehicleId .. '.data.bestActivityScores', vehicleData.bestActivityScores)

    return playerFirst, playerImproved or vehicleFirst or vehicleImproved
end

---@param rewardData table
---@param cashAmount integer
---@param playerReward table
---@param vehicleReward table
function SKEventsRewards.finalizeRewardSummary(rewardData, cashAmount, playerReward, vehicleReward)
    local parts = {}

    if cashAmount > 0 then
        parts[#parts + 1] = ('$%d'):format(cashAmount)
    end
    if playerReward.xpGained > 0 then
        parts[#parts + 1] = ('Player +%d XP'):format(playerReward.xpGained)
    end
    if vehicleReward.xpGained > 0 then
        parts[#parts + 1] = ('Vehicle +%d XP'):format(vehicleReward.xpGained)
    end
    if playerReward.cosmeticCurrencyAwarded > 0 then
        parts[#parts + 1] = ('GearCoins +%d'):format(playerReward.cosmeticCurrencyAwarded)
    end

    rewardData.summary = table.concat(parts, ' | ')
    rewardData.awarded = cashAmount > 0 or playerReward.xpGained > 0 or vehicleReward.xpGained > 0 or playerReward.cosmeticCurrencyAwarded > 0
end

---@param source integer
---@param cashAmount integer
---@param playerXp integer
---@param vehicleXp integer
---@return table
function SKEventsRewards.applyRewardPayout(source, cashAmount, playerXp, vehicleXp)
    local rewardData = SKEventsRewards.buildRewardShell(source)
    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active document')

    if cashAmount > 0 then
        document.economy.cash = document.economy.cash + cashAmount
        SKSaves.write(source, 'economy.cash', document.economy.cash)
        SKStats.increment(source, 'totalCashEarned', cashAmount)
    end

    local playerReward = SKProgression.awardPlayerXp(source, playerXp)
    local vehicleReward = SKProgression.awardVehicleXp(source, vehicleXp)
    local unlockMessage = SKProgression.buildVehicleUnlockMessage(vehicleReward)

    if #playerReward.levelUps > 0 then
        TriggerClientEvent('streetkings:progression:playerLevelUp', source, playerReward)
    end

    rewardData.cash.amount = cashAmount
    rewardData.cosmeticCurrency.amount = playerReward.cosmeticCurrencyAwarded
    rewardData.player = playerReward
    rewardData.vehicle = vehicleReward
    rewardData.unlockMessage = unlockMessage
    SKEventsRewards.finalizeRewardSummary(rewardData, cashAmount, playerReward, vehicleReward)

    return rewardData
end

---@param source integer
---@param eventId string
---@param scoreValue integer
---@return table
function SKEventsRewards.awardSpeedCameraXp(source, eventId, scoreValue)
    local rewardData = SKEventsRewards.buildRewardShell(source)
    local activity = assert(SKEventsQuery.getActivityContext(eventId))
    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active document')
    local _, vehicleEntry = SKEventsRewards.requireActiveVehicleEntry(source)
    local vehicleData = vehicleEntry.data
    local progression = document.progression
    local cfg = SKEventsConfig.SPEED_CAMERA_REWARD_CONFIG
    local playerFirst, playerImproved = SKProgression.recordActivityBest(progression.bestActivityScores, eventId, scoreValue, 'speed')
    local vehicleFirst, vehicleImproved = SKProgression.recordActivityBest(vehicleData.bestActivityScores, eventId, scoreValue, 'speed')

    SKSaves.write(source, 'progression.bestActivityScores', progression.bestActivityScores)
    SKSaves.write(source, 'garage.vehicles.' .. document.garage.activeVehicleId .. '.data.bestActivityScores', vehicleData.bestActivityScores)

    local overTarget = math.max(0, scoreValue - activity.triggerSpeedMph)
    local playerXp = 0
    local vehicleXp = 0

    if playerImproved then
        playerXp = (playerFirst and cfg.firstPlayerXp or cfg.improvedPlayerXp)
            + math.min(50, math.floor(overTarget * 1.25))
    end
    if vehicleImproved then
        vehicleXp = (vehicleFirst and cfg.firstVehicleXp or cfg.improvedVehicleXp)
            + math.min(35, math.floor(overTarget))
    end

    local payout = SKEventsRewards.applyRewardPayout(source, 0, playerXp, vehicleXp)
    payout.playerFirst = playerFirst

    return payout
end

---@param source integer
---@param eventId string
---@param scoreValue integer
---@return table
function SKEventsRewards.awardStuntJumpXp(source, eventId, scoreValue)
    local rewardData = SKEventsRewards.buildRewardShell(source)
    assert(SKEventsQuery.getActivityContext(eventId) ~= nil, 'streetkings: missing stunt jump')

    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active document')
    local _, vehicleEntry = SKEventsRewards.requireActiveVehicleEntry(source)
    local vehicleData = vehicleEntry.data
    local progression = document.progression
    local cfg = SKEventsConfig.STUNT_JUMP_REWARD_CONFIG

    local playerFirst, playerImproved = SKProgression.recordActivityBest(progression.bestActivityScores, eventId, scoreValue, 'points')
    local vehicleFirst, vehicleImproved = SKProgression.recordActivityBest(vehicleData.bestActivityScores, eventId, scoreValue, 'points')

    SKSaves.write(source, 'progression.bestActivityScores', progression.bestActivityScores)
    SKSaves.write(source, 'garage.vehicles.' .. document.garage.activeVehicleId .. '.data.bestActivityScores', vehicleData.bestActivityScores)

    local playerXp = 0
    local vehicleXp = 0

    if playerImproved then
        playerXp = playerFirst and cfg.firstPlayerXp or cfg.improvedPlayerXp
    end
    if vehicleImproved then
        vehicleXp = vehicleFirst and cfg.firstVehicleXp or cfg.improvedVehicleXp
    end

    local payout = SKEventsRewards.applyRewardPayout(source, 0, playerXp, vehicleXp)
    payout.playerFirst = playerFirst

    return payout
end

---@param source integer
---@param eventId string
---@param scoreValue integer
---@return table
function SKEventsRewards.awardRampageXp(source, eventId, scoreValue)
    assert(SKEventsQuery.getActivityContext(eventId) ~= nil, 'streetkings: missing rampage event')

    local document = assert(SKSaves.getDocument(source), 'streetkings: missing active document')
    local _, vehicleEntry = SKEventsRewards.requireActiveVehicleEntry(source)
    local vehicleData = vehicleEntry.data
    local progression = document.progression
    local cfg = SKEventsConfig.RAMPAGE_REWARD_CONFIG

    local playerFirst, playerImproved = SKProgression.recordActivityBest(progression.bestActivityScores, eventId, scoreValue, 'points')
    local vehicleFirst, vehicleImproved = SKProgression.recordActivityBest(vehicleData.bestActivityScores, eventId, scoreValue, 'points')

    SKSaves.write(source, 'progression.bestActivityScores', progression.bestActivityScores)
    SKSaves.write(source, 'garage.vehicles.' .. document.garage.activeVehicleId .. '.data.bestActivityScores', vehicleData.bestActivityScores)

    local playerXp  = 0
    local vehicleXp = 0

    if playerImproved then
        playerXp = playerFirst and cfg.firstPlayerXp or cfg.improvedPlayerXp
    end
    if vehicleImproved then
        vehicleXp = vehicleFirst and cfg.firstVehicleXp or cfg.improvedVehicleXp
    end

    local payout = SKEventsRewards.applyRewardPayout(source, 0, playerXp, vehicleXp)
    payout.playerFirst = playerFirst

    return payout
end

---@param activity table
---@param boardSize integer
---@param entriesBeaten integer
---@param percentile number
---@return table
function SKEventsRewards.buildRewardPreview(activity, boardSize, entriesBeaten, percentile)
    local cfgBase = SKEventsConfig
    local config = getTimeTrialRewardConfig(activity)
    local preview = {
        phase = boardSize < cfgBase.EARLY_BOARD_ENTRY_THRESHOLD and 'early' or 'ranked',
        label = '',
        detail = '',
        cash = config.base.cash,
        playerXp = config.base.playerXp,
        vehicleXp = config.base.vehicleXp,
        boardSize = boardSize,
        minEntriesBeaten = cfgBase.EARLY_BOARD_MIN_BEATEN,
    }

    if preview.phase == 'early' then
        preview.label = 'Early Board'
        preview.detail = ('Beat %d driver%s for the bonus. %d / %d class entries logged.'):format(
            cfgBase.EARLY_BOARD_MIN_BEATEN,
            cfgBase.EARLY_BOARD_MIN_BEATEN == 1 and '' or 's',
            boardSize,
            cfgBase.EARLY_BOARD_ENTRY_THRESHOLD
        )

        if entriesBeaten >= cfgBase.EARLY_BOARD_MIN_BEATEN then
            preview.cash = preview.cash + config.earlyBoardBonus.cash
            preview.playerXp = preview.playerXp + config.earlyBoardBonus.playerXp
            preview.vehicleXp = preview.vehicleXp + config.earlyBoardBonus.vehicleXp
        end

        return preview
    end

    preview.label = 'Ranked Board'

    for _, band in ipairs(config.rankedBands) do
        if percentile <= band.maxPercentile then
            preview.detail = band.label
            preview.cash = preview.cash + band.cash
            preview.playerXp = preview.playerXp + band.playerXp
            preview.vehicleXp = preview.vehicleXp + band.vehicleXp
            break
        end
    end

    return preview
end

---@param source integer
---@param eventId string
---@param rewardData table
---@param rewardContext table
function SKEventsRewards.notifyEventReward(source, eventId, rewardData, rewardContext)
    local cfg = SKEventsConfig
    local activity = SKEvents[eventId]
    if rewardContext.claimAwarded then
        local body = ([[%s paid out.

%s

%s]]):format(
            activity.name,
            rewardData.summary,
            rewardContext.summaryLine
        )
        SKMessages.enqueue(source, cfg.MESSAGE_SENDER, cfg.MESSAGE_AVATAR, body)
        if rewardData.unlockMessage ~= '' then
            SKMessages.enqueueUnlockMessage(source, rewardData.unlockMessage)
        end
        return
    end

    if rewardContext.alreadyClaimed then
        local body = ([[%s is on the board.

Daily rewards for this run are already claimed, but your time still counts.

%s]]):format(activity.name, rewardContext.summaryLine)
        SKMessages.enqueue(source, cfg.MESSAGE_SENDER, cfg.MESSAGE_AVATAR, body)
        if rewardData.unlockMessage ~= '' then
            SKMessages.enqueueUnlockMessage(source, rewardData.unlockMessage)
        end
    end
end

---@param source integer
---@param eventId string
---@param vehicleClass string
---@param scoreValue integer
---@param goalMet boolean
---@param claimAwarded boolean
---@param alreadyClaimed boolean
---@return table, table
function SKEventsRewards.awardTimeTrialRun(source, eventId, vehicleClass, scoreValue, goalMet, claimAwarded, alreadyClaimed)
    local activity = SKEvents[eventId]
    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    local rows = SKEventsQuery.fetchTimeTrialRows(eventId, vehicleClass, LeaderboardPeriod.ALL)
    local _, _, personalRank, personalPercentile = SKEventsQuery.buildTimeTrialLeaderboardData(rows, license, 10)
    local totalEntries = #rows
    local entriesBeaten = personalRank and (totalEntries - personalRank) or 0
    local preview = SKEventsRewards.buildRewardPreview(activity, totalEntries, entriesBeaten, personalPercentile or 1)
    local rewardData = SKEventsRewards.buildRewardShell(source)
    local rewardContext = {
        claimAwarded = claimAwarded,
        alreadyClaimed = alreadyClaimed,
        rank = personalRank or 0,
        totalEntries = totalEntries,
        percentile = personalPercentile or 1,
        phase = preview.phase,
        phaseLabel = preview.label,
        entriesBeaten = entriesBeaten,
        vehicleClass = vehicleClass,
        summaryLine = ('Class %s | #%d / %d | %s'):format(
            vehicleClass,
            personalRank or 0,
            totalEntries,
            preview.phase == 'early' and ('Beat %d'):format(entriesBeaten) or preview.detail
        ),
    }

    SKEventsRewards.recordActivityBest(source, eventId, scoreValue, 'time')

    if claimAwarded then
        local config = getTimeTrialRewardConfig(activity)
        local cashAmount = preview.cash
        local playerXp = preview.playerXp
        local vehicleXp = preview.vehicleXp

        if goalMet then
            cashAmount = cashAmount + config.goalBonus.cash
            playerXp = playerXp + config.goalBonus.playerXp
            vehicleXp = vehicleXp + config.goalBonus.vehicleXp
        end

        rewardData = SKEventsRewards.applyRewardPayout(source, cashAmount, playerXp, vehicleXp)
        rewardContext.summaryLine = rewardContext.summaryLine .. (goalMet and ' | Goal Met' or '')
    end

    if rewardData.summary ~= '' then
        rewardData.summary = rewardData.summary .. ' | ' .. rewardContext.summaryLine
    else
        rewardData.summary = rewardContext.summaryLine
    end
    rewardData.context = rewardContext
    rewardData.claimAwarded = claimAwarded
    rewardData.rewardClaimed = alreadyClaimed
    rewardData.daily = true
    rewardData.vehicleClass = vehicleClass
    rewardData.boardSize = totalEntries
    rewardData.rank = personalRank
    rewardData.percentile = personalPercentile

    return rewardData, rewardContext
end

---@param activity table
---@param vehicleClass string
---@param position integer
---@param totalPlayers integer
---@param forfeited boolean
---@return { cash: integer, playerXp: integer, vehicleXp: integer }
local function buildMultiplayerPayoutBundle(activity, vehicleClass, position, totalPlayers, forfeited)
    local cfg = SKEventsConfig.MULTIPLAYER_REWARD_SCALING
    local scaledConfig = getTimeTrialRewardConfig(activity)
    local base = scaledConfig.base

    local extras = math.max(0, (totalPlayers or 1) - 1)
    local countBonus = math.min(cfg.playerCountBonusCap, extras * cfg.playerCountBonusPerExtra)
    local multipliers = cfg.positionMultipliers
    local positionMult = multipliers[position] or cfg.lastPlaceFloor

    if forfeited then
        positionMult = cfg.forfeitMultiplier
    end

    local finalMult = positionMult * (1.0 + countBonus)
    return {
        cash = roundRewardValue(base.cash * finalMult),
        playerXp = roundRewardValue(base.playerXp * finalMult),
        vehicleXp = roundRewardValue(base.vehicleXp * finalMult),
    }
end

---@param source integer
---@param activity table
---@param vehicleClass string
---@param position integer
---@param totalPlayers integer
---@param forfeited boolean
---@return table
function SKEventsRewards.awardMultiplayerRace(source, activity, vehicleClass, position, totalPlayers, forfeited)
    local bundle = buildMultiplayerPayoutBundle(activity, vehicleClass, position, totalPlayers, forfeited)
    local rewardData = SKEventsRewards.applyRewardPayout(source, bundle.cash, bundle.playerXp, bundle.vehicleXp)

    rewardData.multiplayer = true
    rewardData.vehicleClass = vehicleClass
    rewardData.position = position
    rewardData.totalPlayers = totalPlayers
    rewardData.forfeited = forfeited == true

    if not forfeited then
        SKStats.increment(source, 'racesCompleted', 1)
        if position == 1 then
            SKStats.increment(source, 'racesWon', 1)
        end
    end

    return rewardData
end