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
        body   = [[Welcome to Street Kings. Out here your real opponent is the clock - new track rotation drops every day. Post your times, stack the cash and the XP.

Put in the work, you climb. Slack off, you stay a nobody. Don't embarrass me.]],
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
        body   = [[One more thing - don't just cruise around with no plan.

Open your phone, check what's live, get your name on the boards. Cash keeps you moving, but rep is what carries out here.]],
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
        body   = [[Here's the part most rookies miss.

Pick a car you actually like. Learn how it moves. Drive it clean. A flashy run don't mean a thing if you can't repeat it when it matters.]],
    },
}