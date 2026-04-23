---@class EventTypeEnum
EventType = {
    RACE         = 'race',
    DELIVERY     = 'delivery',
    SPEED_CAMERA = 'speed_camera',
    STUNT_JUMP   = 'stunt_jump',
    RAMPAGE      = 'rampage',
}

---@class LeaderboardPeriodEnum
LeaderboardPeriod = {
    DAY   = 'day',
    WEEK  = 'week',
    MONTH = 'month',
    ALL   = 'all',
}

---@class RaceModeEnum
RaceMode = {
    SINGLEPLAYER = 'singleplayer',
    MULTIPLAYER  = 'multiplayer',
}

---@class CheckpointSchemeEnum
--- ordered      checkpoints must be hit in sequence 1..N
--- unordered    all checkpoints shown at once; hit any in any order
--- circuit      ordered, but the final checkpoint loops back to the start line
--- thereandback ordered to the endpoint, then the list reversed back to start
CheckpointScheme = {
    ORDERED      = 'ordered',
    UNORDERED    = 'unordered',
    CIRCUIT      = 'circuit',
    THEREANDBACK = 'thereandback',
}