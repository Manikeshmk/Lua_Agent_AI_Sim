-- agents/agent_manager.lua
-- Central agent lifecycle manager.
-- Spawns, updates, and manages the full population of AI agents.

local Config     = require("engine.config")
local Components = require("engine.ecs.components")
local SpatialGrid = require("simulation.world.spatial_grid")
local BehaviorTree = require("agents.behavior_trees.bt_runner")
local UtilityAI   = require("agents.utility_ai.utility_ai")
local Perception   = require("agents.perception.perception")
local Memory       = require("agents.memory.memory")

local AgentManager = {}
AgentManager.__index = AgentManager

function AgentManager.new(ecs, world, eventBus, scheduler)
    local m = setmetatable({}, AgentManager)
    m.ecs       = ecs
    m.world     = world
    m.eventBus  = eventBus
    m.scheduler = scheduler
    m.grid      = SpatialGrid.new(Config.CHUNK_SIZE)
    m.agents    = {}    -- entityId -> true
    m.count     = 0
    m.batchIdx  = 1
    m.batchSize = 50
    m.densityMap = {}
    return m
end

-- ─── Spawning ──────────────────────────────────────────────────────────

function AgentManager:spawnInitialPopulation(n)
    n = math.min(n, Config.MAX_AGENTS)
    for i = 1, n do
        self:spawnAgent()
    end
    print("[AgentManager] Spawned " .. self.count .. " agents.")
end

function AgentManager:spawnAgent(x, y, agentType)
    if self.count >= Config.MAX_AGENTS then return nil end

    agentType = agentType or "human"

    -- Find walkable tile
    if not x or not y then
        local attempts = 0
        repeat
            x = math.random(0, self.world.width - 1)
            y = math.random(0, self.world.height - 1)
            attempts = attempts + 1
        until self.world:isWalkable(x, y) or attempts > 200
    end

    local id = self.ecs:newEntity("agent", agentType)

    self.ecs:addComponent(id, "Position",    Components.Position(x, y))
    self.ecs:addComponent(id, "Velocity",    Components.Velocity())
    self.ecs:addComponent(id, "Health",      Components.Health(100))
    self.ecs:addComponent(id, "Hunger",      Components.Hunger())
    self.ecs:addComponent(id, "Thirst",      Components.Thirst())
    self.ecs:addComponent(id, "Energy",      Components.Energy())
    self.ecs:addComponent(id, "Inventory",   Components.Inventory(20))
    self.ecs:addComponent(id, "Memory",      Components.Memory())
    self.ecs:addComponent(id, "Goals",       Components.Goals())
    self.ecs:addComponent(id, "Skills",      Components.Skills())
    self.ecs:addComponent(id, "Relationships", Components.Relationships())
    self.ecs:addComponent(id, "Emotion",     Components.Emotion())
    self.ecs:addComponent(id, "Perception",  Components.Perception())
    self.ecs:addComponent(id, "AI",          Components.AI())
    self.ecs:addComponent(id, "Combat",      Components.Combat())
    self.ecs:addComponent(id, "Profession",  Components.Profession())
    self.ecs:addComponent(id, "Pathfinding", Components.Pathfinding())
    self.ecs:addComponent(id, "Renderable",  Components.Renderable())

    local ai = self.ecs:getComponent(id, "AI")
    ai.type = agentType

    -- Assign a random faction
    local factionComp = self.ecs:getComponent(id, "Relationships")
    factionComp.factionId = math.random(1, 6)

    -- Register in spatial grid
    self.grid:insert(id, x, y)

    self.agents[id] = true
    self.count = self.count + 1

    return id
end

-- ─── Update ────────────────────────────────────────────────────────────

function AgentManager:update(dt)
    for id, _ in pairs(self.agents) do
        local hp = self.ecs:getComponent(id, "Health")
        if hp and hp.isDead then
            self:removeAgent(id)
        else
            self:_updateAgent(id, dt)
        end
    end
end

function AgentManager:batchUpdate(dt)
    -- Update agents in batches for throttled processing
    local ids = {}
    for id, _ in pairs(self.agents) do ids[#ids + 1] = id end
    local n = #ids
    if n == 0 then return end

    local startIdx = self.batchIdx
    local endIdx = math.min(startIdx + self.batchSize - 1, n)
    for i = startIdx, endIdx do
        self:_updateAgentAI(ids[i], dt)
    end
    self.batchIdx = endIdx >= n and 1 or endIdx + 1
end

function AgentManager:_updateAgent(id, dt)
    -- Needs decay
    local hunger = self.ecs:getComponent(id, "Hunger")
    local thirst = self.ecs:getComponent(id, "Thirst")
    local energy = self.ecs:getComponent(id, "Energy")
    local hp     = self.ecs:getComponent(id, "Health")

    if hunger then
        hunger.value = math.max(0, hunger.value - hunger.decayRate * dt)
        if hunger.value <= 0 then hp.current = hp.current - 0.5 * dt end
    end
    if thirst then
        thirst.value = math.max(0, thirst.value - thirst.decayRate * dt)
        if thirst.value <= 0 then hp.current = hp.current - 1.0 * dt end
    end
    if energy then
        energy.value = math.max(0, energy.value - energy.decayRate * dt)
    end

    -- Health regen
    if hp then
        if hp.current <= 0 then
            hp.isDead = true
            return
        end
        if hunger and hunger.value > 50 and thirst and thirst.value > 50 then
            hp.current = math.min(hp.max, hp.current + hp.regen * dt)
        end
    end

    -- Movement
    self:_applyMovement(id, dt)
end

function AgentManager:_updateAgentAI(id, dt)
    -- Perception
    Perception.update(id, self.ecs, self.grid)

    -- Memory
    Memory.update(id, self.ecs)

    -- AI Decision (Utility AI selects goal, BT executes behavior)
    local ai = self.ecs:getComponent(id, "AI")
    if not ai then return end

    ai.decisionTimer = ai.decisionTimer + dt
    if ai.decisionTimer >= 0.5 then
        ai.decisionTimer = 0
        UtilityAI.evaluate(id, self.ecs, self.world)
    end

    BehaviorTree.tick(id, self.ecs, self.world, self.grid, dt)
end

function AgentManager:_applyMovement(id, dt)
    local pos = self.ecs:getComponent(id, "Position")
    local vel = self.ecs:getComponent(id, "Velocity")
    local pf  = self.ecs:getComponent(id, "Pathfinding")
    if not pos or not vel then return end

    -- Follow path
    if pf and pf.path and pf.pathIndex and pf.pathIndex <= #pf.path then
        local target = pf.path[pf.pathIndex]
        local dx = target.x - pos.x
        local dy = target.y - pos.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < 0.3 then
            pf.pathIndex = pf.pathIndex + 1
        else
            local speed = vel.speed
            vel.vx = dx / dist * speed
            vel.vy = dy / dist * speed
        end
    else
        vel.vx = vel.vx * 0.9
        vel.vy = vel.vy * 0.9
    end

    local oldX, oldY = pos.x, pos.y
    local newX = pos.x + vel.vx * dt
    local newY = pos.y + vel.vy * dt

    -- Bounds + walkability
    newX = math.max(0, math.min(self.world.width - 1, newX))
    newY = math.max(0, math.min(self.world.height - 1, newY))
    if self.world:isWalkable(math.floor(newX), math.floor(newY)) then
        pos.x = newX
        pos.y = newY
        self.grid:move(id, oldX, oldY, newX, newY)
    end
end

-- ─── Removal ───────────────────────────────────────────────────────────

function AgentManager:removeAgent(id)
    if not self.agents[id] then return end
    local pos = self.ecs:getComponent(id, "Position")
    if pos then self.grid:remove(id, pos.x, pos.y) end
    self.ecs:destroyEntity(id)
    self.agents[id] = nil
    self.count = self.count - 1
end

-- ─── Queries ───────────────────────────────────────────────────────────

function AgentManager:getNearby(x, y, radius)
    return self.grid:queryRadius(x, y, radius)
end

function AgentManager:getAgentCount() return self.count end

function AgentManager:getDensityMap()
    -- Rebuild density map (agents per tile)
    local dm = {}
    for id, _ in pairs(self.agents) do
        local pos = self.ecs:getComponent(id, "Position")
        if pos then
            local idx = math.floor(pos.y) * self.world.width + math.floor(pos.x)
            dm[idx] = (dm[idx] or 0) + 1
        end
    end
    self.densityMap = dm
    return dm
end

-- ─── Snapshot ──────────────────────────────────────────────────────────

function AgentManager:snapshot()
    local data = {}
    for id, _ in pairs(self.agents) do
        data[id] = {
            pos    = self.ecs:getComponent(id, "Position"),
            hp     = self.ecs:getComponent(id, "Health"),
            hunger = self.ecs:getComponent(id, "Hunger"),
            ai     = self.ecs:getComponent(id, "AI"),
            inv    = self.ecs:getComponent(id, "Inventory"),
            skills = self.ecs:getComponent(id, "Skills"),
        }
    end
    return data
end

function AgentManager:restore(snap)
    -- Simplified restore — full impl would rebuild all agents
    print("[AgentManager] Restore from snapshot (simplified)")
end

return AgentManager
