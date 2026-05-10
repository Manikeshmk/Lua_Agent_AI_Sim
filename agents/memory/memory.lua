-- agents/memory/memory.lua
-- Agent memory system.
-- Ring-buffer event log and knowledge base about known entities/locations.

local Memory = {}

local EVENT_TYPES = {
    "saw_agent", "saw_resource", "was_attacked", "attacked",
    "traded", "ate", "drank", "rested", "built", "died_nearby",
    "heard_rumor", "explored", "joined_faction", "left_faction",
}

-- ─── Event recording ───────────────────────────────────────────────────

function Memory.recordEvent(entityId, ecs, eventType, data)
    local mem = ecs:getComponent(entityId, "Memory")
    if not mem then return end

    local event = {
        type = eventType,
        tick = data and data.tick or 0,
        x    = data and data.x,
        y    = data and data.y,
        targetId = data and data.targetId,
        detail   = data and data.detail,
    }

    -- Ring buffer write
    mem.events[mem.writeHead] = event
    mem.writeHead = (mem.writeHead % mem.maxSize) + 1
end

-- ─── Knowledge update ──────────────────────────────────────────────────

function Memory.updateKnowledge(entityId, ecs, targetId, info)
    local mem = ecs:getComponent(entityId, "Memory")
    if not mem then return end

    mem.knowledge[targetId] = mem.knowledge[targetId] or {}
    local k = mem.knowledge[targetId]
    if info.x then k.lastX = info.x end
    if info.y then k.lastY = info.y end
    if info.faction then k.faction = info.faction end
    if info.threat then k.threat = info.threat end
    k.lastSeen = info.tick or 0
end

-- ─── Automatic update from perception ──────────────────────────────────

function Memory.update(entityId, ecs)
    local perc = ecs:getComponent(entityId, "Perception")
    local mem  = ecs:getComponent(entityId, "Memory")
    if not perc or not mem then return end

    for _, v in ipairs(perc.visible) do
        Memory.updateKnowledge(entityId, ecs, v.id, {
            x = v.x, y = v.y, tick = 0,
        })
    end
end

-- ─── Queries ───────────────────────────────────────────────────────────

function Memory.getRecentEvents(entityId, ecs, count)
    local mem = ecs:getComponent(entityId, "Memory")
    if not mem then return {} end

    count = count or 10
    local results = {}
    local idx = mem.writeHead - 1
    for i = 1, math.min(count, mem.maxSize) do
        if idx < 1 then idx = mem.maxSize end
        if mem.events[idx] then results[#results + 1] = mem.events[idx] end
        idx = idx - 1
    end
    return results
end

function Memory.knows(entityId, ecs, targetId)
    local mem = ecs:getComponent(entityId, "Memory")
    return mem and mem.knowledge[targetId] ~= nil
end

function Memory.getKnowledge(entityId, ecs, targetId)
    local mem = ecs:getComponent(entityId, "Memory")
    return mem and mem.knowledge[targetId]
end

function Memory.forgetOld(entityId, ecs, ageTicks)
    local mem = ecs:getComponent(entityId, "Memory")
    if not mem then return end
    local cutoff = (ageTicks or 1000)
    for targetId, k in pairs(mem.knowledge) do
        if k.lastSeen and k.lastSeen < cutoff then
            mem.knowledge[targetId] = nil
        end
    end
end

return Memory
