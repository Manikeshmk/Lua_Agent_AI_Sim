-- systems/communication.lua
-- Agent communication system: gossip, information spread, rumor propagation.
-- Agents share knowledge about resources, dangers, and social information.

local EventBus = require("engine.events.event_bus")
local Memory   = require("agents.memory.memory")

local Communication = {}

-- Message types
Communication.MSG_TYPES = {
    GREETING   = "greeting",
    TRADE_OFFER = "trade_offer",
    WARNING    = "warning",
    GOSSIP     = "gossip",
    HELP_REQ   = "help_request",
    INFO_SHARE = "info_share",
    THREAT     = "threat",
    ALLIANCE   = "alliance_proposal",
}

-- ─── Send a message between two agents ─────────────────────────────────

function Communication.send(senderId, receiverId, msgType, content, ecs)
    local senderPos = ecs:getComponent(senderId, "Position")
    local recvPos   = ecs:getComponent(receiverId, "Position")
    if not senderPos or not recvPos then return false end

    -- Range check: must be within talking distance (3 tiles)
    local dx = recvPos.x - senderPos.x
    local dy = recvPos.y - senderPos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 5 then return false end

    -- Process received message
    Communication._processMessage(receiverId, senderId, msgType, content, ecs)

    -- Record in sender's memory
    Memory.recordEvent(senderId, ecs, "communicated", {
        targetId = receiverId,
        detail = msgType,
        x = recvPos.x,
        y = recvPos.y,
    })

    -- Relationship impact
    local sRel = ecs:getComponent(senderId, "Relationships")
    local rRel = ecs:getComponent(receiverId, "Relationships")
    if sRel and rRel then
        -- Friendly messages build trust
        if msgType == Communication.MSG_TYPES.GREETING or
           msgType == Communication.MSG_TYPES.INFO_SHARE or
           msgType == Communication.MSG_TYPES.HELP_REQ then
            sRel.friends[receiverId] = (sRel.friends[receiverId] or 0) + 2
            rRel.friends[senderId]   = (rRel.friends[senderId] or 0) + 3
        elseif msgType == Communication.MSG_TYPES.THREAT then
            sRel.enemies[receiverId] = (sRel.enemies[receiverId] or 0) + 10
            rRel.enemies[senderId]   = (rRel.enemies[senderId] or 0) + 10
        end
    end

    EventBus.emit("comm:message_sent", {
        sender = senderId,
        receiver = receiverId,
        type = msgType,
    })

    return true
end

function Communication._processMessage(receiverId, senderId, msgType, content, ecs)
    local emotion = ecs:getComponent(receiverId, "Emotion")

    if msgType == Communication.MSG_TYPES.GREETING then
        if emotion then
            emotion.happiness = math.min(100, emotion.happiness + 5)
        end

    elseif msgType == Communication.MSG_TYPES.WARNING then
        if emotion then
            emotion.fear = math.min(100, emotion.fear + 15)
        end
        -- Remember the warning source
        if content and content.dangerX and content.dangerY then
            Memory.updateKnowledge(receiverId, ecs, content.dangerId or 0, {
                x = content.dangerX,
                y = content.dangerY,
                threat = true,
            })
        end

    elseif msgType == Communication.MSG_TYPES.GOSSIP then
        -- Spread knowledge about a third party
        if content and content.aboutId then
            local senderMem = ecs:getComponent(senderId, "Memory")
            if senderMem and senderMem.knowledge[content.aboutId] then
                local k = senderMem.knowledge[content.aboutId]
                Memory.updateKnowledge(receiverId, ecs, content.aboutId, {
                    x = k.lastX,
                    y = k.lastY,
                    faction = k.faction,
                })
            end
        end

    elseif msgType == Communication.MSG_TYPES.INFO_SHARE then
        -- Share resource location knowledge
        if content and content.resourceX and content.resourceY then
            Memory.recordEvent(receiverId, ecs, "heard_rumor", {
                detail = "resource_location",
                x = content.resourceX,
                y = content.resourceY,
            })
        end

    elseif msgType == Communication.MSG_TYPES.TRADE_OFFER then
        -- Handled by economy system
        EventBus.emit("comm:trade_offer", {
            from = senderId,
            to = receiverId,
            offer = content,
        })

    elseif msgType == Communication.MSG_TYPES.THREAT then
        if emotion then
            emotion.fear  = math.min(100, emotion.fear + 20)
            emotion.anger = math.min(100, emotion.anger + 25)
        end
    end
end

-- ─── Broadcast: shout to all agents in radius ─────────────────────────

function Communication.broadcast(senderId, msgType, content, ecs, grid, radius)
    radius = radius or 8
    local pos = ecs:getComponent(senderId, "Position")
    if not pos or not grid then return 0 end

    local nearby = grid:queryRadius(pos.x, pos.y, radius)
    local count = 0
    for _, nid in ipairs(nearby) do
        if nid ~= senderId then
            Communication._processMessage(nid, senderId, msgType, content, ecs)
            count = count + 1
        end
    end

    EventBus.emit("comm:broadcast", {
        sender = senderId,
        type = msgType,
        radius = radius,
        reached = count,
    })

    return count
end

-- ─── Gossip propagation (information spreading) ────────────────────────

function Communication.spreadGossip(entityId, ecs, grid)
    local pos = ecs:getComponent(entityId, "Position")
    local mem = ecs:getComponent(entityId, "Memory")
    if not pos or not mem or not grid then return end

    -- Pick a random known entity to gossip about
    local knownIds = {}
    for kid, _ in pairs(mem.knowledge) do knownIds[#knownIds + 1] = kid end
    if #knownIds == 0 then return end

    local aboutId = knownIds[math.random(#knownIds)]
    local nearby = grid:queryRadius(pos.x, pos.y, 4)
    for _, nid in ipairs(nearby) do
        if nid ~= entityId and math.random() < 0.3 then
            Communication.send(entityId, nid, Communication.MSG_TYPES.GOSSIP,
                { aboutId = aboutId }, ecs)
        end
    end
end

return Communication
