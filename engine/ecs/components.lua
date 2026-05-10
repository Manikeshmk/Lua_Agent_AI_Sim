-- engine/ecs/components.lua
-- Component factory functions.
-- Each function returns a fresh component table with sensible defaults.

local Components = {}

function Components.Position(x, y)
    return { x = x or 0, y = y or 0 }
end

function Components.Velocity(vx, vy)
    return { vx = vx or 0, vy = vy or 0, speed = 1.5, maxSpeed = 4.0 }
end

function Components.Health(max)
    max = max or 100
    return { current = max, max = max, regen = 0.1, isDead = false }
end

function Components.Hunger()
    return { value = 100, max = 100, decayRate = 0.02, threshold = 30 }
end

function Components.Thirst()
    return { value = 100, max = 100, decayRate = 0.03, threshold = 25 }
end

function Components.Energy()
    return { value = 100, max = 100, decayRate = 0.01, regenRate = 0.05 }
end

function Components.Inventory(capacity)
    return {
        capacity = capacity or 20,
        items    = {},
        gold     = 0,
        weight   = 0,
        maxWeight = 50,
    }
end

function Components.Memory()
    return {
        events   = {},   -- ring buffer of MemoryEvent
        maxSize  = 64,
        knowledge = {},  -- entityId -> { lastSeen, pos, faction }
        writeHead = 1,
    }
end

function Components.Goals()
    return {
        current  = nil,  -- active goal string
        queue    = {},   -- priority queue of { goal, priority, args }
        blackboard = {}, -- shared BT blackboard
    }
end

function Components.Skills()
    return {
        combat    = 0,
        crafting  = 0,
        farming   = 0,
        trading   = 0,
        gathering = 0,
        social    = 0,
        exp       = {},  -- skillName -> xp points
    }
end

function Components.Relationships()
    return {
        friends  = {},   -- entityId -> affinity (-100..100)
        enemies  = {},
        factionId = nil,
        reputation = {}, -- factionId -> reputation score
    }
end

function Components.Emotion()
    return {
        happiness = 50,
        fear      = 0,
        anger     = 0,
        trust     = 50,
        surprise  = 0,
        mood      = "neutral",
    }
end

function Components.Perception()
    return {
        radius   = 12,
        fov      = math.pi * 1.5,  -- 270 degrees
        visible  = {},  -- list of entity IDs currently perceived
        heard    = {},  -- list of sound events
    }
end

function Components.Faction(factionId)
    return { id = factionId, role = "member", loyalty = 80 }
end

function Components.AI()
    return {
        type         = "human",    -- human | animal | vehicle | building
        state        = "idle",     -- FSM state
        btRoot       = nil,        -- behavior tree root node ref
        planQueue    = {},         -- GOAP action sequence
        utilScores   = {},         -- utility scores cache
        decisionTimer = 0,
        personality  = {           -- Big-5 personality traits (0..1)
            openness         = math.random(),
            conscientiousness = math.random(),
            extraversion     = math.random(),
            agreeableness    = math.random(),
            neuroticism      = math.random(),
        },
    }
end

function Components.Combat()
    return {
        damage    = 10,
        range     = 1.5,
        attackRate = 1.0,  -- attacks per second
        cooldown  = 0,
        armor     = 0,
        morale    = 100,
        inCombat  = false,
        target    = nil,
    }
end

function Components.Profession(profName)
    return {
        name      = profName or "peasant",
        level     = 1,
        xp        = 0,
        specializations = {},
    }
end

function Components.Building()
    return {
        type      = "hut",
        hp        = 200,
        maxHp     = 200,
        ownerId   = nil,
        factionId = nil,
        storage   = {},
        workers   = {},
        production = nil,
    }
end

function Components.Resource()
    return {
        type      = "wood",
        amount    = 100,
        maxAmount = 100,
        regenRate = 0,
        harvestTime = 2.0,
    }
end

function Components.Pathfinding()
    return {
        path       = {},
        pathIndex  = 1,
        target     = nil,
        recompute  = false,
        stuckTimer = 0,
    }
end

function Components.Renderable()
    return {
        sprite  = nil,
        color   = {1, 1, 1, 1},
        scale   = 1.0,
        visible = true,
        layer   = 1,
        glyph   = "@",
    }
end

return Components
