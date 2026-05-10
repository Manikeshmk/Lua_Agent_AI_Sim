-- agents/perception/influence_map.lua
-- Influence map system for tactical AI positioning.
-- Tracks areas of friend/enemy control, resource density, and danger.

local InfluenceMap = {}
InfluenceMap.__index = InfluenceMap

function InfluenceMap.new(width, height)
    local m = setmetatable({}, InfluenceMap)
    m.width   = width
    m.height  = height
    m.friendly = {}    -- flat array
    m.hostile  = {}
    m.resource = {}
    m.danger   = {}
    m.combined = {}

    local size = width * height
    for i = 0, size - 1 do
        m.friendly[i] = 0
        m.hostile[i]  = 0
        m.resource[i] = 0
        m.danger[i]   = 0
        m.combined[i] = 0
    end
    return m
end

function InfluenceMap:clear()
    local size = self.width * self.height
    for i = 0, size - 1 do
        self.friendly[i] = 0
        self.hostile[i]  = 0
        self.resource[i] = 0
        self.danger[i]   = 0
    end
end

-- Stamp a circular influence at a position
function InfluenceMap:stamp(layer, x, y, radius, strength)
    local r2 = radius * radius
    local x0 = math.max(0, math.floor(x - radius))
    local y0 = math.max(0, math.floor(y - radius))
    local x1 = math.min(self.width - 1, math.ceil(x + radius))
    local y1 = math.min(self.height - 1, math.ceil(y + radius))

    for ty = y0, y1 do
        for tx = x0, x1 do
            local dx = tx - x
            local dy = ty - y
            local d2 = dx*dx + dy*dy
            if d2 <= r2 then
                local falloff = 1 - math.sqrt(d2) / radius
                local idx = ty * self.width + tx
                layer[idx] = (layer[idx] or 0) + strength * falloff
            end
        end
    end
end

-- Build from agent positions
function InfluenceMap:buildFromAgents(ecs, myFactionId)
    self:clear()

    local posStore = ecs._compStore["Position"]
    local relStore = ecs._compStore["Relationships"]
    local combatStore = ecs._compStore["Combat"]
    if not posStore then return end

    for id, pos in pairs(posStore) do
        if ecs._entities[id] then
            local rel = relStore and relStore[id]
            local combat = combatStore and combatStore[id]

            if rel and rel.factionId then
                if rel.factionId == myFactionId then
                    self:stamp(self.friendly, pos.x, pos.y, 8, 1.0)
                else
                    self:stamp(self.hostile, pos.x, pos.y, 8, 1.0)
                end
            end

            if combat and combat.inCombat then
                self:stamp(self.danger, pos.x, pos.y, 10, 2.0)
            end
        end
    end

    self:_computeCombined()
end

-- Build resource layer from world
function InfluenceMap:buildResourceLayer(world)
    for _, res in ipairs(world.resources) do
        if res.amount > 0 then
            self:stamp(self.resource, res.x, res.y, 5, res.amount / 100)
        end
    end
end

function InfluenceMap:_computeCombined()
    local size = self.width * self.height
    for i = 0, size - 1 do
        self.combined[i] = self.friendly[i] - self.hostile[i] * 1.5 - self.danger[i] * 2 + self.resource[i] * 0.5
    end
end

-- Query influence at a point
function InfluenceMap:getAt(x, y, layer)
    local ix = math.floor(x)
    local iy = math.floor(y)
    if ix < 0 or iy < 0 or ix >= self.width or iy >= self.height then return 0 end
    local tbl = layer or self.combined
    return tbl[iy * self.width + ix] or 0
end

-- Find best tactical position within radius
function InfluenceMap:findBestPosition(cx, cy, radius, layer)
    layer = layer or self.combined
    local bestX, bestY = cx, cy
    local bestVal = -math.huge

    local x0 = math.max(0, math.floor(cx - radius))
    local y0 = math.max(0, math.floor(cy - radius))
    local x1 = math.min(self.width - 1, math.ceil(cx + radius))
    local y1 = math.min(self.height - 1, math.ceil(cy + radius))

    for ty = y0, y1 do
        for tx = x0, x1 do
            local idx = ty * self.width + tx
            local val = layer[idx] or 0
            if val > bestVal then
                bestVal = val
                bestX = tx
                bestY = ty
            end
        end
    end

    return bestX, bestY, bestVal
end

-- Find safest retreat position (highest friendly, lowest danger)
function InfluenceMap:findRetreatPosition(cx, cy, radius)
    local bestX, bestY = cx, cy
    local bestVal = -math.huge

    local x0 = math.max(0, math.floor(cx - radius))
    local y0 = math.max(0, math.floor(cy - radius))
    local x1 = math.min(self.width - 1, math.ceil(cx + radius))
    local y1 = math.min(self.height - 1, math.ceil(cy + radius))

    for ty = y0, y1 do
        for tx = x0, x1 do
            local idx = ty * self.width + tx
            local safety = (self.friendly[idx] or 0) * 2 - (self.danger[idx] or 0) * 3 - (self.hostile[idx] or 0)
            if safety > bestVal then
                bestVal = safety
                bestX = tx
                bestY = ty
            end
        end
    end

    return bestX, bestY
end

return InfluenceMap
