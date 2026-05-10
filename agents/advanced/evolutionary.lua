-- agents/advanced/evolutionary.lua
-- Evolutionary algorithm hooks for agent trait evolution.
-- Tracks fitness, performs selection, crossover, and mutation.

local Evolutionary = {}

-- ─── Fitness calculation ───────────────────────────────────────────────

function Evolutionary.calculateFitness(entityId, ecs)
    local hp     = ecs:getComponent(entityId, "Health")
    local inv    = ecs:getComponent(entityId, "Inventory")
    local skills = ecs:getComponent(entityId, "Skills")
    local rel    = ecs:getComponent(entityId, "Relationships")

    local fitness = 0

    -- Survival
    if hp then fitness = fitness + (hp.current / hp.max) * 30 end

    -- Wealth
    if inv then fitness = fitness + inv.gold * 0.5 + #inv.items * 2 end

    -- Skills
    if skills then
        for _, val in pairs(skills) do
            if type(val) == "number" then fitness = fitness + val * 3 end
        end
    end

    -- Social network
    if rel then
        local friends = 0
        for _, v in pairs(rel.friends) do
            if v > 10 then friends = friends + 1 end
        end
        fitness = fitness + friends * 5
    end

    return fitness
end

-- ─── Selection (tournament) ────────────────────────────────────────────

function Evolutionary.tournamentSelect(population, fitnesses, tournamentSize)
    tournamentSize = tournamentSize or 3
    local best = nil
    local bestFitness = -math.huge

    for i = 1, tournamentSize do
        local idx = math.random(#population)
        if fitnesses[idx] > bestFitness then
            bestFitness = fitnesses[idx]
            best = population[idx]
        end
    end

    return best
end

-- ─── Crossover (personality traits) ────────────────────────────────────

function Evolutionary.crossover(parentA, parentB, ecs)
    local aiA = ecs:getComponent(parentA, "AI")
    local aiB = ecs:getComponent(parentB, "AI")
    if not aiA or not aiB then return nil end
    if not aiA.personality or not aiB.personality then return nil end

    local childTraits = {}
    for trait, valA in pairs(aiA.personality) do
        local valB = aiB.personality[trait] or valA
        -- Uniform crossover
        if math.random() < 0.5 then
            childTraits[trait] = valA
        else
            childTraits[trait] = valB
        end
    end

    return childTraits
end

-- ─── Mutation ──────────────────────────────────────────────────────────

function Evolutionary.mutate(traits, mutationRate, mutationStrength)
    mutationRate     = mutationRate or 0.1
    mutationStrength = mutationStrength or 0.2

    local mutated = {}
    for trait, val in pairs(traits) do
        if math.random() < mutationRate then
            val = val + (math.random() - 0.5) * mutationStrength * 2
            val = math.max(0, math.min(1, val))
        end
        mutated[trait] = val
    end
    return mutated
end

-- ─── Generational tracking ────────────────────────────────────────────

local _generations = {}
local _generationCount = 0

function Evolutionary.newGeneration(agents, fitnesses)
    _generationCount = _generationCount + 1
    local stats = {
        gen      = _generationCount,
        count    = #agents,
        avgFit   = 0,
        maxFit   = -math.huge,
        minFit   = math.huge,
    }

    local sum = 0
    for _, f in ipairs(fitnesses) do
        sum = sum + f
        if f > stats.maxFit then stats.maxFit = f end
        if f < stats.minFit then stats.minFit = f end
    end
    stats.avgFit = #fitnesses > 0 and sum / #fitnesses or 0

    _generations[#_generations + 1] = stats
    return stats
end

function Evolutionary.getGenerationHistory()
    return _generations
end

function Evolutionary.getGenerationCount()
    return _generationCount
end

-- ─── Swarm intelligence primitives ─────────────────────────────────────

function Evolutionary.flockingForce(entityId, ecs, grid, radius)
    local pos = ecs:getComponent(entityId, "Position")
    local vel = ecs:getComponent(entityId, "Velocity")
    local rel = ecs:getComponent(entityId, "Relationships")
    if not pos or not vel or not grid then return 0, 0 end

    local nearby = grid:queryRadius(pos.x, pos.y, radius or 8)
    local cohesionX, cohesionY = 0, 0
    local separationX, separationY = 0, 0
    local alignX, alignY = 0, 0
    local count = 0

    for _, nid in ipairs(nearby) do
        if nid ~= entityId then
            local npos = ecs:getComponent(nid, "Position")
            local nvel = ecs:getComponent(nid, "Velocity")
            local nrel = ecs:getComponent(nid, "Relationships")
            if npos then
                -- Only flock with same faction
                local sameFaction = rel and nrel and rel.factionId == nrel.factionId
                if sameFaction then
                    local dx = npos.x - pos.x
                    local dy = npos.y - pos.y
                    local dist = math.sqrt(dx*dx + dy*dy)

                    -- Cohesion
                    cohesionX = cohesionX + npos.x
                    cohesionY = cohesionY + npos.y

                    -- Separation
                    if dist > 0 and dist < 2 then
                        separationX = separationX - dx / dist
                        separationY = separationY - dy / dist
                    end

                    -- Alignment
                    if nvel then
                        alignX = alignX + nvel.vx
                        alignY = alignY + nvel.vy
                    end

                    count = count + 1
                end
            end
        end
    end

    if count == 0 then return 0, 0 end

    cohesionX = cohesionX / count - pos.x
    cohesionY = cohesionY / count - pos.y
    alignX    = alignX / count
    alignY    = alignY / count

    local fx = cohesionX * 0.3 + separationX * 0.5 + alignX * 0.2
    local fy = cohesionY * 0.3 + separationY * 0.5 + alignY * 0.2

    return fx, fy
end

return Evolutionary
