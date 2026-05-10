-- agents/advanced/rl_hooks.lua
-- Reinforcement Learning integration hooks.
-- Exposes an OpenAI Gym-style interface for external RL agents.
-- Provides: reset(), step(action), observe(), reward().

local RLHooks = {}
RLHooks.__index = RLHooks

-- ─── Environment wrapper ───────────────────────────────────────────────

function RLHooks.new(ecs, world, agentMgr)
    local r = setmetatable({}, RLHooks)
    r.ecs      = ecs
    r.world    = world
    r.agentMgr = agentMgr
    r.controlled = {}  -- entityId -> true (agents under RL control)
    r.stepCount  = 0
    r.episodeReward = 0
    r.actionSpace = {
        "move_north", "move_south", "move_east", "move_west",
        "gather", "eat", "drink", "attack", "flee",
        "trade", "rest", "craft", "socialize", "explore",
    }
    r.observationShape = nil
    return r
end

-- ─── Control ───────────────────────────────────────────────────────────

function RLHooks:takeControl(entityId)
    self.controlled[entityId] = true
end

function RLHooks:releaseControl(entityId)
    self.controlled[entityId] = nil
end

-- ─── Observation ───────────────────────────────────────────────────────

function RLHooks:observe(entityId)
    local pos     = self.ecs:getComponent(entityId, "Position")
    local hp      = self.ecs:getComponent(entityId, "Health")
    local hunger  = self.ecs:getComponent(entityId, "Hunger")
    local thirst  = self.ecs:getComponent(entityId, "Thirst")
    local energy  = self.ecs:getComponent(entityId, "Energy")
    local inv     = self.ecs:getComponent(entityId, "Inventory")
    local combat  = self.ecs:getComponent(entityId, "Combat")
    local emotion = self.ecs:getComponent(entityId, "Emotion")
    local perc    = self.ecs:getComponent(entityId, "Perception")

    local obs = {
        -- Agent state (normalized 0..1)
        pos_x       = pos and pos.x / self.world.width or 0,
        pos_y       = pos and pos.y / self.world.height or 0,
        health      = hp and hp.current / hp.max or 0,
        hunger      = hunger and hunger.value / hunger.max or 0,
        thirst      = thirst and thirst.value / thirst.max or 0,
        energy      = energy and energy.value / energy.max or 0,
        gold        = inv and math.min(inv.gold / 100, 1) or 0,
        item_count  = inv and #inv.items / inv.capacity or 0,
        in_combat   = combat and combat.inCombat and 1 or 0,
        morale      = combat and combat.morale / 100 or 0,
        happiness   = emotion and emotion.happiness / 100 or 0,
        fear        = emotion and emotion.fear / 100 or 0,
        anger       = emotion and emotion.anger / 100 or 0,
        visible_count = perc and #perc.visible or 0,

        -- Local terrain
        tile_biome  = nil,
        tile_resource = nil,
    }

    if pos then
        local tile = self.world:getTile(math.floor(pos.x), math.floor(pos.y))
        if tile then
            obs.tile_biome    = tile.biome
            obs.tile_resource = tile.resource
        end
    end

    return obs
end

-- ─── Action execution ──────────────────────────────────────────────────

function RLHooks:step(entityId, actionIndex, dt)
    dt = dt or 0.016
    local action = self.actionSpace[actionIndex]
    if not action then return nil, 0, false end

    local pos = self.ecs:getComponent(entityId, "Position")
    local vel = self.ecs:getComponent(entityId, "Velocity")
    local hp  = self.ecs:getComponent(entityId, "Health")

    local reward = 0

    if action == "move_north" and pos and vel then
        vel.vy = -vel.speed
    elseif action == "move_south" and pos and vel then
        vel.vy = vel.speed
    elseif action == "move_east" and pos and vel then
        vel.vx = vel.speed
    elseif action == "move_west" and pos and vel then
        vel.vx = -vel.speed
    elseif action == "eat" then
        local hunger = self.ecs:getComponent(entityId, "Hunger")
        if hunger and hunger.value < 50 then
            hunger.value = math.min(hunger.max, hunger.value + 30)
            reward = reward + 5
        end
    elseif action == "drink" then
        local thirst = self.ecs:getComponent(entityId, "Thirst")
        if thirst and thirst.value < 50 then
            thirst.value = math.min(thirst.max, thirst.value + 40)
            reward = reward + 5
        end
    elseif action == "rest" then
        local energy = self.ecs:getComponent(entityId, "Energy")
        if energy then
            energy.value = math.min(energy.max, energy.value + 10)
            reward = reward + 1
        end
    elseif action == "gather" then
        reward = reward + 2
    elseif action == "attack" then
        reward = reward - 1  -- Attacking has a small cost
    elseif action == "flee" and vel then
        vel.vx = (math.random() - 0.5) * vel.maxSpeed * 2
        vel.vy = (math.random() - 0.5) * vel.maxSpeed * 2
    end

    -- Survival reward
    if hp and not hp.isDead then
        reward = reward + 0.1  -- Small reward for staying alive
    end

    -- Penalty for low needs
    local hunger = self.ecs:getComponent(entityId, "Hunger")
    local thirst = self.ecs:getComponent(entityId, "Thirst")
    if hunger and hunger.value < 10 then reward = reward - 2 end
    if thirst and thirst.value < 10 then reward = reward - 3 end

    self.stepCount = self.stepCount + 1
    self.episodeReward = self.episodeReward + reward

    local done = hp and hp.isDead or false
    local obs  = self:observe(entityId)

    return obs, reward, done
end

-- ─── Reset episode ─────────────────────────────────────────────────────

function RLHooks:reset(entityId)
    local hp     = self.ecs:getComponent(entityId, "Health")
    local hunger = self.ecs:getComponent(entityId, "Hunger")
    local thirst = self.ecs:getComponent(entityId, "Thirst")
    local energy = self.ecs:getComponent(entityId, "Energy")

    if hp then hp.current = hp.max; hp.isDead = false end
    if hunger then hunger.value = hunger.max end
    if thirst then thirst.value = thirst.max end
    if energy then energy.value = energy.max end

    self.stepCount = 0
    self.episodeReward = 0

    return self:observe(entityId)
end

-- ─── Info / stats ──────────────────────────────────────────────────────

function RLHooks:getActionSpace()
    return self.actionSpace
end

function RLHooks:getActionCount()
    return #self.actionSpace
end

function RLHooks:getEpisodeStats()
    return {
        steps  = self.stepCount,
        reward = self.episodeReward,
    }
end

return RLHooks
