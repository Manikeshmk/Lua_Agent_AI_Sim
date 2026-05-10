-- agents/utility_ai/utility_ai.lua
-- Utility-based AI decision system.
-- Scores a set of possible actions using response curves,
-- then selects the highest-scoring action as the agent's current goal.

local UtilityAI = {}

-- ─── Response curves ───────────────────────────────────────────────────

local function linear(x) return math.max(0, math.min(1, x)) end
local function quadratic(x) x = linear(x); return x * x end
local function inverseLerp(x) return 1 - linear(x) end
local function logistic(x, k, mid) return 1 / (1 + math.exp(-k * (x - mid))) end

-- ─── Action definitions ────────────────────────────────────────────────

local ACTIONS = {
    {
        name = "eat",
        score = function(id, ecs, world)
            local h = ecs:getComponent(id, "Hunger")
            if not h then return 0 end
            return inverseLerp(h.value / h.max) * 1.2
        end,
    },
    {
        name = "drink",
        score = function(id, ecs, world)
            local t = ecs:getComponent(id, "Thirst")
            if not t then return 0 end
            return inverseLerp(t.value / t.max) * 1.3
        end,
    },
    {
        name = "rest",
        score = function(id, ecs, world)
            local e = ecs:getComponent(id, "Energy")
            if not e then return 0 end
            return inverseLerp(e.value / e.max) * 0.8
        end,
    },
    {
        name = "flee",
        score = function(id, ecs, world)
            local hp = ecs:getComponent(id, "Health")
            local combat = ecs:getComponent(id, "Combat")
            if not hp then return 0 end
            local hpRatio = hp.current / hp.max
            local inDanger = combat and combat.inCombat and hpRatio < 0.4
            return inDanger and 1.5 or 0
        end,
    },
    {
        name = "fight",
        score = function(id, ecs, world)
            local combat = ecs:getComponent(id, "Combat")
            local hp = ecs:getComponent(id, "Health")
            local emotion = ecs:getComponent(id, "Emotion")
            if not combat or not hp then return 0 end
            local hpRatio = hp.current / hp.max
            local anger = emotion and emotion.anger / 100 or 0
            if combat.inCombat and hpRatio > 0.4 then
                return 0.7 + anger * 0.3
            end
            return anger * 0.3
        end,
    },
    {
        name = "gather",
        score = function(id, ecs, world)
            local inv = ecs:getComponent(id, "Inventory")
            local hunger = ecs:getComponent(id, "Hunger")
            if not inv then return 0 end
            local fullness = #inv.items / inv.capacity
            local needFood = hunger and hunger.value > hunger.threshold
            return (1 - fullness) * 0.5 * (needFood and 0.3 or 1.0)
        end,
    },
    {
        name = "trade",
        score = function(id, ecs, world)
            local inv = ecs:getComponent(id, "Inventory")
            local skills = ecs:getComponent(id, "Skills")
            if not inv then return 0 end
            local fullness = #inv.items / inv.capacity
            local tradingSkill = skills and skills.trading or 0
            return fullness * 0.4 + tradingSkill * 0.01
        end,
    },
    {
        name = "socialize",
        score = function(id, ecs, world)
            local emotion = ecs:getComponent(id, "Emotion")
            local ai = ecs:getComponent(id, "AI")
            if not emotion or not ai then return 0 end
            local loneliness = inverseLerp(emotion.happiness / 100)
            local extraversion = ai.personality and ai.personality.extraversion or 0.5
            return loneliness * 0.6 * extraversion
        end,
    },
    {
        name = "explore",
        score = function(id, ecs, world)
            local ai = ecs:getComponent(id, "AI")
            local openness = ai and ai.personality and ai.personality.openness or 0.5
            return 0.2 + openness * 0.2
        end,
    },
    {
        name = "craft",
        score = function(id, ecs, world)
            local inv = ecs:getComponent(id, "Inventory")
            local skills = ecs:getComponent(id, "Skills")
            if not inv or not skills then return 0 end
            local hasRaw = false
            for _, item in ipairs(inv.items) do
                if item.type == "wood" or item.type == "iron" or item.type == "herbs" then
                    hasRaw = true; break
                end
            end
            return hasRaw and (0.3 + skills.crafting * 0.02) or 0
        end,
    },
}

-- ─── Evaluate ──────────────────────────────────────────────────────────

function UtilityAI.evaluate(entityId, ecs, world)
    local ai = ecs:getComponent(entityId, "AI")
    local goals = ecs:getComponent(entityId, "Goals")
    if not ai or not goals then return end

    local bestAction = nil
    local bestScore  = -1
    ai.utilScores = {}

    for _, action in ipairs(ACTIONS) do
        local score = action.score(entityId, ecs, world)
        ai.utilScores[action.name] = score
        if score > bestScore then
            bestScore  = score
            bestAction = action.name
        end
    end

    if bestAction then
        goals.current = bestAction
        ai.state = bestAction
    end
end

function UtilityAI.getActions()
    return ACTIONS
end

return UtilityAI
