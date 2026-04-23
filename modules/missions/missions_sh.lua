-- Missions framework shared types

MissionStatus = {
    LOCKED    = 'locked',
    COOLDOWN  = 'cooldown',
    AVAILABLE = 'available',
    ACTIVE    = 'active',
    COMPLETED = 'completed',
    FINISHED  = 'finished',
}

ObjectiveType = {
    VISIT_LOCATION   = 'visitLocation',
    COMPLETE_EVENT   = 'completeEvent',
    PICKUP_PACKAGE   = 'pickupPackage',
    DELIVER_PACKAGE  = 'deliverPackage',
    TAIL_NPC         = 'tailNpc',
    DIALOG           = 'dialog',
    ESCAPE           = 'escape',
    CUTSCENE         = 'cutscene',
    NPC_CHALLENGE    = 'npcChallenge',
    SCRIPTED_RACE    = 'scriptedRace',
    GETAWAY_PICKUP   = 'getawayPickup',
    GETAWAY_RIDE     = 'getawayRide',
    STOP_VEHICLE     = 'stopVehicle',
    CHASE_VEHICLE    = 'chaseVehicle',
    FINALE_ARREST    = 'finaleArrest',
}

SKMissionsShared = {}

---@param objective table
---@return string
function SKMissionsShared.typeOf(objective)
    return objective and objective.type or ''
end

---@param min integer
---@param max integer
---@return integer
function SKMissionsShared.rollCooldown(min, max)
    if type(min) ~= 'number' or type(max) ~= 'number' then return 0 end
    if min < 0 then min = 0 end
    if max < min then max = min end
    return math.random(min, max)
end