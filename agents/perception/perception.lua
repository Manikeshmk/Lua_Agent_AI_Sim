-- agents/perception/perception.lua
-- Sensory system: determines what each agent can see/hear.
-- Uses spatial grid for efficient neighbor lookup.

local Config = require("engine.config")

local Perception = {}

function Perception.update(entityId, ecs, grid)
    local pos  = ecs:getComponent(entityId, "Position")
    local perc = ecs:getComponent(entityId, "Perception")
    if not pos or not perc then return end

    perc.visible = {}
    perc.heard   = {}

    if not grid then return end

    local nearby = grid:queryRadius(pos.x, pos.y, perc.radius)

    for _, nid in ipairs(nearby) do
        if nid ~= entityId then
            local npos = ecs:getComponent(nid, "Position")
            if npos then
                local dx = npos.x - pos.x
                local dy = npos.y - pos.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= perc.radius then
                    perc.visible[#perc.visible + 1] = {
                        id   = nid,
                        x    = npos.x,
                        y    = npos.y,
                        dist = dist,
                    }
                end
            end
        end
    end

    -- Sort by distance
    table.sort(perc.visible, function(a, b) return a.dist < b.dist end)
end

-- Query: find nearest visible entity with a given component
function Perception.findNearest(entityId, ecs, compType)
    local perc = ecs:getComponent(entityId, "Perception")
    if not perc then return nil end
    for _, v in ipairs(perc.visible) do
        if ecs:hasComponent(v.id, compType) then return v end
    end
    return nil
end

-- Query: count visible entities of a type
function Perception.countVisible(entityId, ecs, tag)
    local perc = ecs:getComponent(entityId, "Perception")
    if not perc then return 0 end
    local n = 0
    for _, v in ipairs(perc.visible) do
        if ecs:hasTag(v.id, tag) then n = n + 1 end
    end
    return n
end

-- Query: find all visible enemies (different faction)
function Perception.findEnemies(entityId, ecs)
    local perc = ecs:getComponent(entityId, "Perception")
    local myRel = ecs:getComponent(entityId, "Relationships")
    if not perc or not myRel then return {} end

    local enemies = {}
    for _, v in ipairs(perc.visible) do
        local theirRel = ecs:getComponent(v.id, "Relationships")
        if theirRel and theirRel.factionId and theirRel.factionId ~= myRel.factionId then
            enemies[#enemies + 1] = v
        end
    end
    return enemies
end

-- Build influence map contribution for this agent
function Perception.getInfluence(entityId, ecs, world)
    local pos = ecs:getComponent(entityId, "Position")
    local rel = ecs:getComponent(entityId, "Relationships")
    if not pos or not rel then return end

    local radius = 5
    local strength = 1.0
    for dy = -radius, radius do
        for dx = -radius, radius do
            local tx = math.floor(pos.x) + dx
            local ty = math.floor(pos.y) + dy
            if tx >= 0 and ty >= 0 and tx < world.width and ty < world.height then
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= radius then
                    local influence = strength * (1 - dist / radius)
                    local idx = ty * world.width + tx
                    world.influenceMap[idx] = (world.influenceMap[idx] or 0) + influence
                end
            end
        end
    end
end

return Perception
