-- systems/social.lua
-- Social simulation: relationship management, faction dynamics,
-- social hierarchy, reputation, and emergent group formation.

local EventBus = require("engine.events.event_bus")

local Social = {}

-- ─── Relationship management ───────────────────────────────────────────

function Social.getAffinity(entityA, entityB, ecs)
    local relA = ecs:getComponent(entityA, "Relationships")
    if not relA then return 0 end
    return (relA.friends[entityB] or 0) - (relA.enemies[entityB] or 0)
end

function Social.modifyAffinity(entityA, entityB, delta, ecs)
    local relA = ecs:getComponent(entityA, "Relationships")
    if not relA then return end
    if delta > 0 then
        relA.friends[entityB] = math.min(100, (relA.friends[entityB] or 0) + delta)
    else
        relA.enemies[entityB] = math.min(100, (relA.enemies[entityB] or 0) - delta)
    end
end

-- ─── Reputation system ─────────────────────────────────────────────────

function Social.getReputation(entityId, factionId, ecs)
    local rel = ecs:getComponent(entityId, "Relationships")
    if not rel or not rel.reputation then return 0 end
    return rel.reputation[factionId] or 0
end

function Social.modifyReputation(entityId, factionId, delta, ecs)
    local rel = ecs:getComponent(entityId, "Relationships")
    if not rel then return end
    if not rel.reputation then rel.reputation = {} end
    rel.reputation[factionId] = math.max(-100, math.min(100,
        (rel.reputation[factionId] or 0) + delta))
end

-- ─── Social hierarchy ──────────────────────────────────────────────────

function Social.calculateInfluence(entityId, ecs, grid)
    local pos = ecs:getComponent(entityId, "Position")
    local rel = ecs:getComponent(entityId, "Relationships")
    local skills = ecs:getComponent(entityId, "Skills")
    if not pos or not rel then return 0 end

    local influence = 0

    -- Friendship network size
    local friendCount = 0
    for _, affinity in pairs(rel.friends) do
        if affinity > 20 then friendCount = friendCount + 1 end
    end
    influence = influence + friendCount * 5

    -- Skill-based prestige
    if skills then
        for _, val in pairs(skills) do
            if type(val) == "number" then influence = influence + val * 0.5 end
        end
    end

    -- Wealth
    local inv = ecs:getComponent(entityId, "Inventory")
    if inv then influence = influence + inv.gold * 0.1 end

    -- Reputation average
    if rel.reputation then
        for _, rep in pairs(rel.reputation) do
            influence = influence + rep * 0.3
        end
    end

    return influence
end

-- ─── Group formation ───────────────────────────────────────────────────

function Social.findPotentialAllies(entityId, ecs, grid)
    local pos = ecs:getComponent(entityId, "Position")
    local rel = ecs:getComponent(entityId, "Relationships")
    if not pos or not rel or not grid then return {} end

    local allies = {}
    local nearby = grid:queryRadius(pos.x, pos.y, 15)

    for _, nid in ipairs(nearby) do
        if nid ~= entityId then
            local affinity = Social.getAffinity(entityId, nid, ecs)
            if affinity > 30 then
                allies[#allies + 1] = { id = nid, affinity = affinity }
            end
        end
    end

    table.sort(allies, function(a, b) return a.affinity > b.affinity end)
    return allies
end

-- ─── Faction join/leave decisions ──────────────────────────────────────

function Social.shouldJoinFaction(entityId, factionId, ecs, factions)
    local rel = ecs:getComponent(entityId, "Relationships")
    local ai  = ecs:getComponent(entityId, "AI")
    if not rel or not ai then return false end

    -- Already in this faction
    if rel.factionId == factionId then return false end

    local rep = Social.getReputation(entityId, factionId, ecs)
    local agreeableness = ai.personality and ai.personality.agreeableness or 0.5

    -- Higher agreeableness and reputation make joining more likely
    return rep > 20 and agreeableness > 0.4
end

function Social.shouldLeaveFaction(entityId, ecs, factions)
    local rel = ecs:getComponent(entityId, "Relationships")
    local ai  = ecs:getComponent(entityId, "AI")
    if not rel or not ai or not rel.factionId then return false end

    local rep = Social.getReputation(entityId, rel.factionId, ecs)
    local loyalty = ai.personality and (1 - ai.personality.neuroticism) or 0.5

    return rep < -30 and loyalty < 0.3
end

-- ─── Emotional state update ────────────────────────────────────────────

function Social.updateEmotions(entityId, ecs, dt)
    local emotion = ecs:getComponent(entityId, "Emotion")
    if not emotion then return end

    -- Emotional decay (return to baseline)
    emotion.fear     = emotion.fear     * (1 - 0.01 * dt)
    emotion.anger    = emotion.anger    * (1 - 0.01 * dt)
    emotion.surprise = emotion.surprise * (1 - 0.05 * dt)

    -- Happiness based on needs met
    local hunger = ecs:getComponent(entityId, "Hunger")
    local thirst = ecs:getComponent(entityId, "Thirst")
    local hp     = ecs:getComponent(entityId, "Health")

    local satisfaction = 50
    if hunger then satisfaction = satisfaction + (hunger.value / hunger.max - 0.5) * 20 end
    if thirst then satisfaction = satisfaction + (thirst.value / thirst.max - 0.5) * 20 end
    if hp     then satisfaction = satisfaction + (hp.current / hp.max - 0.5) * 20 end

    -- Social needs
    local rel = ecs:getComponent(entityId, "Relationships")
    if rel then
        local friendCount = 0
        for _, v in pairs(rel.friends) do
            if v > 10 then friendCount = friendCount + 1 end
        end
        satisfaction = satisfaction + math.min(friendCount * 3, 15)
    end

    emotion.happiness = emotion.happiness * 0.95 + satisfaction * 0.05

    -- Determine mood
    if emotion.happiness > 70 then emotion.mood = "happy"
    elseif emotion.happiness > 50 then emotion.mood = "content"
    elseif emotion.happiness > 30 then emotion.mood = "neutral"
    elseif emotion.fear > 50 then emotion.mood = "fearful"
    elseif emotion.anger > 50 then emotion.mood = "angry"
    else emotion.mood = "sad" end
end

-- ─── Social event processing ───────────────────────────────────────────

function Social.processInteraction(entityA, entityB, interactionType, ecs)
    if interactionType == "friendly_chat" then
        Social.modifyAffinity(entityA, entityB, 5, ecs)
        Social.modifyAffinity(entityB, entityA, 5, ecs)
        local emoA = ecs:getComponent(entityA, "Emotion")
        local emoB = ecs:getComponent(entityB, "Emotion")
        if emoA then emoA.happiness = math.min(100, emoA.happiness + 5) end
        if emoB then emoB.happiness = math.min(100, emoB.happiness + 3) end

    elseif interactionType == "trade" then
        Social.modifyAffinity(entityA, entityB, 3, ecs)
        Social.modifyAffinity(entityB, entityA, 3, ecs)
        -- Reputation boost with each other's faction
        local relA = ecs:getComponent(entityA, "Relationships")
        local relB = ecs:getComponent(entityB, "Relationships")
        if relA and relB and relB.factionId then
            Social.modifyReputation(entityA, relB.factionId, 2, ecs)
        end
        if relB and relA and relA.factionId then
            Social.modifyReputation(entityB, relA.factionId, 2, ecs)
        end

    elseif interactionType == "combat" then
        Social.modifyAffinity(entityA, entityB, -20, ecs)
        Social.modifyAffinity(entityB, entityA, -20, ecs)

    elseif interactionType == "help" then
        Social.modifyAffinity(entityA, entityB, 10, ecs)
        Social.modifyAffinity(entityB, entityA, 15, ecs)
    end

    EventBus.emit("social:interaction", {
        entityA = entityA,
        entityB = entityB,
        type = interactionType,
    })
end

return Social
