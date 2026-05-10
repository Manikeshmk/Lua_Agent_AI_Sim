-- systems/formation.lua
-- Group formation system for coordinated movement and combat.
-- Supports line, circle, wedge, and square formations.

local Utils = require("engine.utils")

local Formation = {}

Formation.TYPES = {
    LINE   = "line",
    CIRCLE = "circle",
    WEDGE  = "wedge",
    SQUARE = "square",
}

-- ─── Calculate formation positions ─────────────────────────────────────

function Formation.getPositions(formationType, centerX, centerY, count, facing, spacing)
    spacing = spacing or 2.0
    facing  = facing or 0

    if formationType == Formation.TYPES.LINE then
        return Formation._line(centerX, centerY, count, facing, spacing)
    elseif formationType == Formation.TYPES.CIRCLE then
        return Formation._circle(centerX, centerY, count, spacing)
    elseif formationType == Formation.TYPES.WEDGE then
        return Formation._wedge(centerX, centerY, count, facing, spacing)
    elseif formationType == Formation.TYPES.SQUARE then
        return Formation._square(centerX, centerY, count, spacing)
    end
    return {}
end

function Formation._line(cx, cy, count, facing, spacing)
    local positions = {}
    local perpX = -math.sin(facing)
    local perpY =  math.cos(facing)
    local halfWidth = (count - 1) * spacing / 2

    for i = 0, count - 1 do
        local offset = i * spacing - halfWidth
        positions[#positions + 1] = {
            x = cx + perpX * offset,
            y = cy + perpY * offset,
        }
    end
    return positions
end

function Formation._circle(cx, cy, count, spacing)
    local positions = {}
    local radius = count * spacing / (2 * math.pi)
    radius = math.max(radius, spacing)

    for i = 0, count - 1 do
        local angle = (i / count) * math.pi * 2
        positions[#positions + 1] = {
            x = cx + math.cos(angle) * radius,
            y = cy + math.sin(angle) * radius,
        }
    end
    return positions
end

function Formation._wedge(cx, cy, count, facing, spacing)
    local positions = {}
    -- Leader at front
    positions[1] = { x = cx + math.cos(facing) * spacing, y = cy + math.sin(facing) * spacing }

    local perpX = -math.sin(facing)
    local perpY =  math.cos(facing)
    local fwdX  = math.cos(facing)
    local fwdY  = math.sin(facing)

    for i = 2, count do
        local row = math.ceil((i - 1) / 2)
        local side = ((i - 1) % 2 == 0) and 1 or -1
        positions[#positions + 1] = {
            x = cx - fwdX * row * spacing + perpX * side * row * spacing * 0.5,
            y = cy - fwdY * row * spacing + perpY * side * row * spacing * 0.5,
        }
    end
    return positions
end

function Formation._square(cx, cy, count, spacing)
    local positions = {}
    local side = math.ceil(math.sqrt(count))
    local halfSide = (side - 1) * spacing / 2

    local idx = 0
    for row = 0, side - 1 do
        for col = 0, side - 1 do
            idx = idx + 1
            if idx > count then break end
            positions[#positions + 1] = {
                x = cx + col * spacing - halfSide,
                y = cy + row * spacing - halfSide,
            }
        end
        if idx > count then break end
    end
    return positions
end

-- ─── Assign agents to formation slots ──────────────────────────────────

function Formation.assignToFormation(agentIds, formationType, centerX, centerY, facing, ecs, spacing)
    local positions = Formation.getPositions(formationType, centerX, centerY, #agentIds, facing, spacing)

    for i, agentId in ipairs(agentIds) do
        local pos = positions[i]
        if pos then
            local pf = ecs:getComponent(agentId, "Pathfinding")
            if pf then
                pf.target = { x = math.floor(pos.x), y = math.floor(pos.y) }
                pf.recompute = true
            end
        end
    end

    return positions
end

-- ─── Formation coherence check ─────────────────────────────────────────

function Formation.getCoherence(agentIds, ecs)
    if #agentIds < 2 then return 1.0 end

    -- Calculate center of mass
    local cx, cy = 0, 0
    local count = 0
    for _, id in ipairs(agentIds) do
        local pos = ecs:getComponent(id, "Position")
        if pos then
            cx = cx + pos.x
            cy = cy + pos.y
            count = count + 1
        end
    end
    if count == 0 then return 0 end
    cx, cy = cx / count, cy / count

    -- Average distance from center
    local avgDist = 0
    for _, id in ipairs(agentIds) do
        local pos = ecs:getComponent(id, "Position")
        if pos then
            avgDist = avgDist + Utils.distance(pos.x, pos.y, cx, cy)
        end
    end
    avgDist = avgDist / count

    -- Coherence: 1 = tight, 0 = scattered
    return math.max(0, 1 - avgDist / 20)
end

return Formation
