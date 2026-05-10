-- engine/ecs/world.lua
-- Core Entity-Component-System (ECS) world.
-- Entities are integer IDs. Components are plain Lua tables stored by type.
-- Systems are registered functions that iterate relevant archetypes.

local World = {}
World.__index = World

local function newSparseSet()
    return { dense = {}, sparse = {}, size = 0 }
end

local function sparseInsert(s, id)
    if s.sparse[id] then return end
    s.size = s.size + 1
    s.dense[s.size] = id
    s.sparse[id] = s.size
end

local function sparseRemove(s, id)
    local idx = s.sparse[id]
    if not idx then return end
    local last = s.dense[s.size]
    s.dense[idx] = last
    s.sparse[last] = idx
    s.dense[s.size] = nil
    s.sparse[id] = nil
    s.size = s.size - 1
end

function World.new()
    local w = setmetatable({}, World)
    w._nextId    = 1
    w._entities  = {}       -- id -> true
    w._compStore = {}       -- compType -> { [entityId] = compData }
    w._archetypes = {}      -- "A,B,C" -> SparseSet
    w._systems   = {}       -- list of { name, filter, fn, priority }
    w._toDestroy = {}
    w._tags      = {}       -- id -> { tagName = true }
    return w
end

function World:newEntity(...)
    local id = self._nextId
    self._nextId = id + 1
    self._entities[id] = true
    self._tags[id] = {}
    local tags = {...}
    for _, t in ipairs(tags) do
        self._tags[id][t] = true
    end
    return id
end

function World:destroyEntity(id)
    self._toDestroy[#self._toDestroy + 1] = id
end

function World:_flushDestroy()
    for _, id in ipairs(self._toDestroy) do
        self._entities[id] = nil
        self._tags[id] = nil
        for compType, store in pairs(self._compStore) do
            store[id] = nil
        end
        for _, arch in pairs(self._archetypes) do
            sparseRemove(arch, id)
        end
    end
    self._toDestroy = {}
end

function World:addComponent(id, compType, data)
    if not self._compStore[compType] then
        self._compStore[compType] = {}
    end
    self._compStore[compType][id] = data or {}
    self:_rebuildArchetype(id)
end

function World:removeComponent(id, compType)
    if self._compStore[compType] then
        self._compStore[compType][id] = nil
    end
    self:_rebuildArchetype(id)
end

function World:getComponent(id, compType)
    local store = self._compStore[compType]
    return store and store[id]
end

function World:hasComponent(id, compType)
    local store = self._compStore[compType]
    return store ~= nil and store[id] ~= nil
end

function World:_getEntityComponents(id)
    local list = {}
    for compType, store in pairs(self._compStore) do
        if store[id] then
            list[#list + 1] = compType
        end
    end
    table.sort(list)
    return list
end

function World:_rebuildArchetype(id)
    -- Remove from all archetypes first
    for _, arch in pairs(self._archetypes) do
        sparseRemove(arch, id)
    end
    -- Build key from current components
    local comps = self:_getEntityComponents(id)
    if #comps == 0 then return end
    local key = table.concat(comps, ",")
    if not self._archetypes[key] then
        self._archetypes[key] = newSparseSet()
    end
    sparseInsert(self._archetypes[key], id)
end

function World:registerSystem(name, filter, fn, priority)
    self._systems[#self._systems + 1] = {
        name     = name,
        filter   = filter,
        fn       = fn,
        priority = priority or 0,
    }
    table.sort(self._systems, function(a, b) return a.priority < b.priority end)
end

function World:query(...)
    local required = {...}
    local results = {}
    for _, arch in pairs(self._archetypes) do
        local matches = true
        for _, comp in ipairs(required) do
            -- simple check: does any entity in this archetype have it?
            -- better: check archetype key
        end
        _ = matches
    end
    -- Simpler iteration: direct component store intersection
    local first = required[1]
    local store  = self._compStore[first]
    if not store then return results end
    for id, _ in pairs(store) do
        local ok = true
        for i = 2, #required do
            local s2 = self._compStore[required[i]]
            if not s2 or not s2[id] then ok = false; break end
        end
        if ok and self._entities[id] then
            results[#results + 1] = id
        end
    end
    return results
end

function World:runSystems(dt)
    self:_flushDestroy()
    for _, sys in ipairs(self._systems) do
        local entities = self:query(table.unpack(sys.filter))
        for _, id in ipairs(entities) do
            sys.fn(id, self, dt)
        end
    end
end

function World:addTag(id, tag)
    if self._tags[id] then self._tags[id][tag] = true end
end

function World:hasTag(id, tag)
    return self._tags[id] and self._tags[id][tag] == true
end

function World:entityCount()
    local n = 0
    for _ in pairs(self._entities) do n = n + 1 end
    return n
end

return World
