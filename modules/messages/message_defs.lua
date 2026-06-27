---@class SKMessageTriggerDelayMinutes
---@field min number
---@field max number

---@class SKMessageTrigger
---@field kind string
---@field delayMinutes SKMessageTriggerDelayMinutes
---@field conditions table|nil

---@class SKMessageAction
---@field kind string
---@field lobbyId string|nil
---@field label string|nil

---@class SKMessageDef
---@field sender string
---@field avatar string
---@field once boolean
---@field body string
---@field trigger SKMessageTrigger|nil
---@field action SKMessageAction|nil

---@type table<string, SKMessageDef>
SKMessageDefs = {
    hector_welcome = {
        sender = 'Hector',
        avatar = 'hector',
        once   = true,
        trigger = {
            kind = 'saveSessionBound',
            delayMinutes = { min = 0.25, max = 0.25 },
            conditions = { isNew = true },
        },
        body   = _L('content.messages.hector_welcome'),
    },
    hector_welcome_followup_one = {
        sender = 'Hector',
        avatar = 'hector',
        once   = true,
        trigger = {
            kind = 'saveSessionBound',
            delayMinutes = { min = 2, max = 5 },
            conditions = { isNew = true },
        },
        body   = _L('content.messages.hector_welcome_followup_one'),
    },
    hector_welcome_followup_two = {
        sender = 'Hector',
        avatar = 'hector',
        once   = true,
        trigger = {
            kind = 'saveSessionBound',
            delayMinutes = { min = 7, max = 10 },
            conditions = { isNew = true },
        },
        body   = _L('content.messages.hector_welcome_followup_two'),
    },
}
