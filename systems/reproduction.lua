-- systems/reproduction.lua
-- Agent reproduction system: trait inheritance, mutation, population control.

local Components = require("engine.ecs.components")

local Reproduction = {}

function Reproduction.canReproduce(entityId, ecs)
    local hp     = ecs:getComponent(entityId, "Health")
    local hunger = ecs:getComponent(entityId, "Hunger")
    local energy = ecs:getComponent(entityId, "Energy")
    if not hp or not hunger or not energy then return false end
    return hp.current > hp.max * 0.8
       and hunger.value > 60
       and energy.value > 70
end

function Reproduction.reproduce(parentA, parentB, ecs, world, agentMgr)
    if not Reproduction.canReproduce(parentA, ecs) then return nil end
    if parentB and not Reproduction.canReproduce(parentB, ecs) then return nil end

    local posA = ecs:getComponent(parentA, "Position")
    if not posA then return nil end

    -- Spawn near parent
    local cx = posA.x + (math.random() - 0.5) * 3
    local cy = posA.y + (math.random() - 0.5) * 3
    cx = math.max(0, math.min(world.width - 1, cx))
    cy = math.max(0, math.min(world.height - 1, cy))

    local childId = agentMgr:spawnAgent(cx, cy, "human")
    if not childId then return nil end

    -- Inherit traits with mutation
    local aiA = ecs:getComponent(parentA, "AI")
    local aiChild = ecs:getComponent(childId, "AI")
    if aiA and aiChild and aiA.personality then
        for trait, val in pairs(aiA.personality) do
            local mutation = (math.random() - 0.5) * 0.2
            aiChild.personality[trait] = math.max(0, math.min(1, val + mutation))
        end
    end

    -- Inherit skills (partial)
    local skillsA = ecs:getComponent(parentA, "Skills")
    local skillsC = ecs:getComponent(childId, "Skills")
    if skillsA and skillsC then
        for skill, val in pairs(skillsA) do
            if type(val) == "number" then
                skillsC[skill] = math.floor(val * 0.3)
            end
        end
    end

    -- Inherit faction
    local relA = ecs:getComponent(parentA, "Relationships")
    local relC = ecs:getComponent(childId, "Relationships")
    if relA and relC then
        relC.factionId = relA.factionId
    end

    -- Energy cost
    local energyA = ecs:getComponent(parentA, "Energy")
    if energyA then energyA.value = energyA.value - 30 end

    return childId
end

return Reproduction
