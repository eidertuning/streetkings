SKEventsConfig = {
    RATE_LIMIT_MS = 5000, -- Global event rate limit for rewards and such
    DAILY_PLAYLIST_SIZE = 18, -- Number of events in the daily playlist
    DAILY_GUARANTEED_DELIVERIES = 1, -- Number of guaranteed deliveries per day
    EARLY_BOARD_ENTRY_THRESHOLD = 50, -- The first x players to finish a race will be given early board bonus
    EARLY_BOARD_MIN_BEATEN = 1, -- The minimum number of players bean on the leaderboard to be eligible for early board bonus
    MULTIPLAYER_LOBBY_LIMIT = 5, -- The maximum number of multiplayer lobbies that can run concurrently
    MULTIPLAYER_MAX_PLAYERS = 20, -- The maximum number of players that can join a multiplayer lobby
    MULTIPLAYER_MIN_PLAYERS_TO_START = 2, -- The minimum number of players to start a multiplayer lobby
    MULTIPLAYER_LOBBY_EXPIRY_SECONDS = 30, -- The time in seconds for a multiplayer lobby to expire
    MULTIPLAYER_SETUP_TIMEOUT_OPTIONS = { 180, 300, 600 }, -- The timeout options for a multiplayer lobby
    MULTIPLAYER_SETUP_DEFAULTS = { -- The default setup options for a multiplayer lobby
        collision = true,
        nitrousEnabled = true,
        trafficDensityPct = 20,
        lobbyTimeoutSeconds = 180,
    },
    MULTIPLAYER_START_COUNTDOWN_SECONDS = 10, -- The time in seconds for the countdown to start before the race starts
    MULTIPLAYER_RACE_FINISH_GRACE_SECONDS = 60, -- The time in seconds for the race to finish after the first player crosses the finish line
    MULTIPLAYER_FORFEIT_COST = 1000, -- The cost for a player to forfeit a race
    MULTIPLAYER_BUCKET_BASE = 2000, -- The base value for the multiplayer bucket (can be ignored)
    MULTIPLAYER_GRID_LATERAL_SPACING = 4.0, -- The spacing for the multiplayer grid
    MULTIPLAYER_GRID_LONGITUDINAL_SPACING = 6.0, -- The spacing for the multiplayer grid
    MULTIPLAYER_POSITION_BROADCAST_INTERVAL_MS = 1000, -- The interval in milliseconds for broadcasting the position of the players
    MULTIPLAYER_REWARD_SCALING = { -- The reward scaling for a multiplayer lobby
        playerCountBonusPerExtra = 0.08, 
        playerCountBonusCap = 1.0,
        positionMultipliers = { 1.00, 0.80, 0.65, 0.55, 0.48, 0.42, 0.38, 0.34, 0.30, 0.28 },
        lastPlaceFloor = 0.22,
        forfeitMultiplier = 0.0,
    },
    MULTIPLAYER_MESSAGE_SENDER = 'StreetKings', -- The sender of the messages related to multiplayer events
    MULTIPLAYER_MESSAGE_AVATAR = 'streetkings',
    MESSAGE_SENDER = 'StreetKings', -- The sender of the messages related to singleplayer events
    MESSAGE_AVATAR = 'streetkings',
    SPEED_CAMERA_REWARD_CONFIG = {
        firstPlayerXp = 5,
        firstVehicleXp = 4,
        improvedPlayerXp = 2,
        improvedVehicleXp = 1,
    },
    STUNT_JUMP_REWARD_CONFIG = {
        firstPlayerXp = 2,
        firstVehicleXp = 2,
        improvedPlayerXp = 1,
        improvedVehicleXp = 1,
    },
    RAMPAGE_REWARD_CONFIG = {
        firstPlayerXp    = 40,
        firstVehicleXp   = 30,
        improvedPlayerXp = 12,
        improvedVehicleXp = 8,
    },
    DAILY_RACE_REWARD_SCALING = {
        checkpointWeightMeters = 140.0,
        minimumScale = 0.40,
        rewards = {
            base = { cash = 2000, playerXp = 30, vehicleXp = 22 },
            goalBonus = { cash = 400, playerXp = 7, vehicleXp = 6 },
            earlyBoardBonus = { cash = 350, playerXp = 4, vehicleXp = 6 },
            rankedBands = {
                { maxPercentile = 0.05, label = 'Top 5%', cash = 1200, playerXp = 14, vehicleXp = 11 },
                { maxPercentile = 0.10, label = 'Top 10%', cash = 900, playerXp = 10, vehicleXp = 8 },
                { maxPercentile = 0.25, label = 'Top 25%', cash = 600, playerXp = 7, vehicleXp = 5 },
                { maxPercentile = 0.50, label = 'Top 50%', cash = 250, playerXp = 3, vehicleXp = 2 },
                { maxPercentile = 1.00, label = 'Finish', cash = 75, playerXp = 1, vehicleXp = 1 },
            },
        },
    },
    DAILY_REWARD_CONFIG = {
        delivery = {
            base = { cash = 2200, playerXp = 28, vehicleXp = 21 },
            goalBonus = { cash = 450, playerXp = 8, vehicleXp = 6 },
            earlyBoardBonus = { cash = 350, playerXp = 4, vehicleXp = 6 },
            rankedBands = {
                { maxPercentile = 0.05, label = 'Top 5%', cash = 6000, playerXp = 66, vehicleXp = 52 },
                { maxPercentile = 0.10, label = 'Top 10%', cash = 4700, playerXp = 52, vehicleXp = 41 },
                { maxPercentile = 0.25, label = 'Top 25%', cash = 3200, playerXp = 35, vehicleXp = 27 },
                { maxPercentile = 0.50, label = 'Top 50%', cash = 1700, playerXp = 18, vehicleXp = 14 },
                { maxPercentile = 1.00, label = 'Finish', cash = 500, playerXp = 5, vehicleXp = 4 },
            },
        },
    },
}

SKEventsConfig.MODEL_CLASS_LOOKUP = {}

-- This can be ignored
CreateThread(function()
    for _, vehicle in ipairs(SKStarterVehicles) do
        SKEventsConfig.MODEL_CLASS_LOOKUP[vehicle.model] = vehicle.class
    end

    for _, vehicles in pairs(SKGameVehicles) do
        for _, vehicle in ipairs(vehicles) do
            SKEventsConfig.MODEL_CLASS_LOOKUP[vehicle.model] = vehicle.class
        end
    end
end)