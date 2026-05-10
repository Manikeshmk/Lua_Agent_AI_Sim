-- agents/fsm/fsm.lua
-- Finite State Machine for agents.
-- States define enter/update/exit callbacks. Transitions are conditional.

local FSM = {}
FSM.__index = FSM

function FSM.new(name)
    local m = setmetatable({}, FSM)
    m.name    = name or "fsm"
    m.states  = {}
    m.current = nil
    m.previous = nil
    m.time    = 0
    return m
end

function FSM:addState(name, callbacks)
    self.states[name] = {
        name   = name,
        enter  = callbacks.enter  or function() end,
        update = callbacks.update or function() end,
        exit   = callbacks.exit   or function() end,
        transitions = {},
    }
end

function FSM:addTransition(fromState, toState, condition)
    local state = self.states[fromState]
    if state then
        state.transitions[#state.transitions + 1] = {
            target    = toState,
            condition = condition,
        }
    end
end

function FSM:setState(name, ctx)
    if self.current and self.states[self.current] then
        self.states[self.current].exit(ctx)
    end
    self.previous = self.current
    self.current  = name
    self.time     = 0
    if self.states[name] then
        self.states[name].enter(ctx)
    end
end

function FSM:update(dt, ctx)
    if not self.current then return end
    self.time = self.time + dt

    local state = self.states[self.current]
    if not state then return end

    -- Check transitions
    for _, trans in ipairs(state.transitions) do
        if trans.condition(ctx, self.time, dt) then
            self:setState(trans.target, ctx)
            return
        end
    end

    -- Update current state
    state.update(ctx, dt)
end

function FSM:getCurrentState()
    return self.current
end

function FSM:getTimeInState()
    return self.time
end

-- ─── Predefined agent FSM ──────────────────────────────────────────────

function FSM.createAgentFSM()
    local m = FSM.new("agent")

    m:addState("idle", {
        enter  = function(ctx) end,
        update = function(ctx, dt) end,
        exit   = function(ctx) end,
    })

    m:addState("foraging", {
        enter  = function(ctx) end,
        update = function(ctx, dt) end,
        exit   = function(ctx) end,
    })

    m:addState("combat", {
        enter  = function(ctx)
            local combat = ctx.ecs:getComponent(ctx.id, "Combat")
            if combat then combat.inCombat = true end
        end,
        update = function(ctx, dt) end,
        exit   = function(ctx)
            local combat = ctx.ecs:getComponent(ctx.id, "Combat")
            if combat then combat.inCombat = false; combat.target = nil end
        end,
    })

    m:addState("fleeing", {
        enter  = function(ctx)
            local vel = ctx.ecs:getComponent(ctx.id, "Velocity")
            if vel then
                vel.vx = (math.random() - 0.5) * vel.maxSpeed * 2
                vel.vy = (math.random() - 0.5) * vel.maxSpeed * 2
            end
        end,
        update = function(ctx, dt) end,
        exit   = function(ctx) end,
    })

    m:addState("resting", {
        update = function(ctx, dt)
            local energy = ctx.ecs:getComponent(ctx.id, "Energy")
            if energy then
                energy.value = math.min(energy.max, energy.value + energy.regenRate * dt * 5)
            end
        end,
    })

    m:addState("socializing", {
        update = function(ctx, dt)
            local emotion = ctx.ecs:getComponent(ctx.id, "Emotion")
            if emotion then emotion.happiness = math.min(100, emotion.happiness + 2 * dt) end
        end,
    })

    m:addState("trading", {
        enter = function(ctx) end,
        update = function(ctx, dt) end,
        exit = function(ctx) end,
    })

    m:addState("gathering", {
        update = function(ctx, dt) end,
    })

    -- Transitions
    m:addTransition("idle", "foraging", function(ctx)
        local hunger = ctx.ecs:getComponent(ctx.id, "Hunger")
        return hunger and hunger.value < hunger.threshold
    end)

    m:addTransition("idle", "fleeing", function(ctx)
        local hp = ctx.ecs:getComponent(ctx.id, "Health")
        local combat = ctx.ecs:getComponent(ctx.id, "Combat")
        return hp and combat and combat.inCombat and hp.current < hp.max * 0.3
    end)

    m:addTransition("idle", "resting", function(ctx)
        local energy = ctx.ecs:getComponent(ctx.id, "Energy")
        return energy and energy.value < 20
    end)

    m:addTransition("foraging", "idle", function(ctx)
        local hunger = ctx.ecs:getComponent(ctx.id, "Hunger")
        return hunger and hunger.value > 70
    end)

    m:addTransition("combat", "fleeing", function(ctx)
        local combat = ctx.ecs:getComponent(ctx.id, "Combat")
        return combat and combat.morale < 20
    end)

    m:addTransition("fleeing", "idle", function(ctx, time)
        return time > 5
    end)

    m:addTransition("resting", "idle", function(ctx)
        local energy = ctx.ecs:getComponent(ctx.id, "Energy")
        return energy and energy.value > 80
    end)

    m:setState("idle", {})
    return m
end

return FSM
