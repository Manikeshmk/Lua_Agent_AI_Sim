-- simulation/factions/factions.lua
-- Faction politics, territory, diplomacy, and hierarchy.

local Factions = {}
Factions.__index = Factions

local RELATION = { WAR = -100, HOSTILE = -50, NEUTRAL = 0, FRIENDLY = 50, ALLIED = 100 }

function Factions.new(ecs, eventBus)
    local f = setmetatable({}, Factions)
    f.ecs = ecs
    f.eventBus = eventBus
    f.factions = {}   -- id -> Faction
    f.nextId = 1
    f.relations = {}  -- "a,b" -> score
    f.time = 0

    -- Seed starter factions
    local names = { "Iron Wolves", "Sun Keepers", "Shadow Pact", "River Folk", "Storm Claws", "Emerald Court" }
    for _, name in ipairs(names) do f:createFaction(name) end
    return f
end

function Factions:createFaction(name)
    local id = self.nextId
    self.nextId = id + 1
    self.factions[id] = {
        id = id,
        name = name,
        leader = nil,
        members = {},
        territory = {},
        gold = math.random(100, 500),
        strength = 0,
        ideology = { aggression = math.random(), trade = math.random(), expansion = math.random() },
    }
    -- Set default neutral relations with all existing
    for otherId, _ in pairs(self.factions) do
        if otherId ~= id then
            self:setRelation(id, otherId, RELATION.NEUTRAL)
        end
    end
    return id
end

function Factions:getFaction(id) return self.factions[id] end

function Factions:_relKey(a, b)
    if a > b then a, b = b, a end
    return a .. "," .. b
end

function Factions:getRelation(a, b)
    return self.relations[self:_relKey(a, b)] or 0
end

function Factions:setRelation(a, b, value)
    self.relations[self:_relKey(a, b)] = math.max(-100, math.min(100, value))
end

function Factions:modRelation(a, b, delta)
    local cur = self:getRelation(a, b)
    self:setRelation(a, b, cur + delta)
end

function Factions:areAllied(a, b) return self:getRelation(a, b) >= RELATION.ALLIED end
function Factions:areHostile(a, b) return self:getRelation(a, b) <= RELATION.HOSTILE end
function Factions:atWar(a, b) return self:getRelation(a, b) <= RELATION.WAR end

function Factions:declareWar(a, b)
    self:setRelation(a, b, RELATION.WAR)
    if self.eventBus then
        self.eventBus.emit("faction:war_declared", { attacker = a, defender = b })
    end
end

function Factions:formAlliance(a, b)
    self:setRelation(a, b, RELATION.ALLIED)
    if self.eventBus then
        self.eventBus.emit("faction:alliance_formed", { factions = {a, b} })
    end
end

function Factions:addMember(factionId, entityId)
    local fac = self.factions[factionId]
    if fac then fac.members[entityId] = true end
end

function Factions:removeMember(factionId, entityId)
    local fac = self.factions[factionId]
    if fac then fac.members[entityId] = nil end
end

function Factions:getMemberCount(factionId)
    local fac = self.factions[factionId]
    if not fac then return 0 end
    local n = 0
    for _ in pairs(fac.members) do n = n + 1 end
    return n
end

function Factions:tick(dt)
    self.time = self.time + dt
    -- Relation drift: slowly move toward neutral
    for key, val in pairs(self.relations) do
        if val > 0 then self.relations[key] = val - 0.01 * dt
        elseif val < 0 then self.relations[key] = val + 0.01 * dt end
    end
    -- Update faction strength
    for id, fac in pairs(self.factions) do
        fac.strength = self:getMemberCount(id)
    end
end

function Factions:getAllFactions()
    local list = {}
    for _, fac in pairs(self.factions) do list[#list + 1] = fac end
    return list
end

function Factions:snapshot()
    return { factions = self.factions, relations = self.relations, nextId = self.nextId, time = self.time }
end

function Factions:restore(snap)
    self.factions = snap.factions or self.factions
    self.relations = snap.relations or self.relations
    self.nextId = snap.nextId or self.nextId
    self.time = snap.time or 0
end

return Factions
