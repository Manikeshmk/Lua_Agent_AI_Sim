-- systems/combat.lua
-- Combat system: melee/ranged, morale, flanking, formations.

local EventBus = require("engine.events.event_bus")

local Combat = {}

-- ─── Engage ────────────────────────────────────────────────────────────

function Combat.engage(attackerId, defenderId, ecs)
    local atkCombat = ecs:getComponent(attackerId, "Combat")
    local defCombat = ecs:getComponent(defenderId, "Combat")
    local atkPos    = ecs:getComponent(attackerId, "Position")
    local defPos    = ecs:getComponent(defenderId, "Position")
    local atkHp     = ecs:getComponent(attackerId, "Health")
    local defHp     = ecs:getComponent(defenderId, "Health")

    if not atkCombat or not defCombat or not atkHp or not defHp then return end
    if defHp.isDead then return end

    -- Range check
    if atkPos and defPos then
        local dx = defPos.x - atkPos.x
        local dy = defPos.y - atkPos.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > atkCombat.range then return end
    end

    -- Cooldown
    if atkCombat.cooldown > 0 then return end
    atkCombat.cooldown = 1.0 / atkCombat.attackRate

    -- Calculate damage
    local baseDmg = atkCombat.damage
    local armor   = defCombat.armor
    local skills  = ecs:getComponent(attackerId, "Skills")
    local skillBonus = skills and skills.combat * 0.5 or 0
    local finalDmg = math.max(1, baseDmg + skillBonus - armor)

    -- Critical hit chance (5%)
    if math.random() < 0.05 then finalDmg = finalDmg * 2 end

    -- Flanking bonus: if attacker is behind defender
    if atkPos and defPos then
        local angle = math.atan2(defPos.y - atkPos.y, defPos.x - atkPos.x)
        -- Simplified: 20% bonus if from behind
        if math.random() < 0.2 then finalDmg = finalDmg * 1.3 end
    end

    -- Apply damage
    defHp.current = defHp.current - finalDmg

    -- Morale impact
    defCombat.morale = math.max(0, defCombat.morale - 5)
    atkCombat.morale = math.min(100, atkCombat.morale + 2)

    -- Mark combat state
    atkCombat.inCombat = true
    defCombat.inCombat = true
    atkCombat.target = defenderId
    defCombat.target = attackerId

    -- Emotional impact
    local defEmo = ecs:getComponent(defenderId, "Emotion")
    local atkEmo = ecs:getComponent(attackerId, "Emotion")
    if defEmo then
        defEmo.fear  = math.min(100, defEmo.fear + 10)
        defEmo.anger = math.min(100, defEmo.anger + 15)
    end
    if atkEmo then
        atkEmo.anger = math.min(100, atkEmo.anger + 5)
    end

    -- Death check
    if defHp.current <= 0 then
        defHp.isDead = true
        defCombat.inCombat = false
        atkCombat.inCombat = false
        atkCombat.target = nil
        EventBus.emit("combat:kill", { attacker = attackerId, defender = defenderId })

        -- XP gain
        if skills then skills.combat = skills.combat + 1 end
    end

    EventBus.emit("combat:hit", {
        attacker = attackerId,
        defender = defenderId,
        damage   = finalDmg,
        defenderHp = defHp.current,
    })
end

-- ─── Update cooldowns ──────────────────────────────────────────────────

function Combat.update(entityId, ecs, dt)
    local combat = ecs:getComponent(entityId, "Combat")
    if not combat then return end

    combat.cooldown = math.max(0, combat.cooldown - dt)

    -- Morale recovery out of combat
    if not combat.inCombat then
        combat.morale = math.min(100, combat.morale + 1 * dt)
    end

    -- Retreat at low morale
    if combat.morale < 20 and combat.inCombat then
        combat.inCombat = false
        combat.target = nil
        local vel = ecs:getComponent(entityId, "Velocity")
        if vel then
            vel.vx = (math.random() - 0.5) * vel.maxSpeed
            vel.vy = (math.random() - 0.5) * vel.maxSpeed
        end
        EventBus.emit("combat:retreat", { entity = entityId, morale = combat.morale })
    end
end

-- ─── Should fight? (tactical decision) ─────────────────────────────────

function Combat.shouldFight(entityId, ecs, targetId)
    local myHp     = ecs:getComponent(entityId, "Health")
    local myCombat = ecs:getComponent(entityId, "Combat")
    local theirHp  = ecs:getComponent(targetId, "Health")

    if not myHp or not myCombat or not theirHp then return false end

    -- Don't fight if low HP or low morale
    if myHp.current < myHp.max * 0.3 then return false end
    if myCombat.morale < 30 then return false end

    -- Fight if we're stronger
    local myPower   = myCombat.damage * (myHp.current / myHp.max)
    local theirPower = 10  -- estimate
    return myPower > theirPower * 0.5
end

return Combat
