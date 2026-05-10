-- agents/behavior_trees/agent_behaviors.lua
-- Concrete behavior trees for different agent archetypes.
-- Combines BT nodes into full decision trees.

local BT = require("agents.behavior_trees.bt_nodes")
local Pathfinding = require("systems.pathfinding")

local Behaviors = {}

function Behaviors.buildTree(entityId, ecs)
    local ai = ecs:getComponent(entityId, "AI")
    local agentType = ai and ai.type or "human"

    if agentType == "animal" then
        return Behaviors._animalTree()
    else
        return Behaviors._humanTree()
    end
end

-- ─── Human behavior tree ───────────────────────────────────────────────

function Behaviors._humanTree()
    return BT.Selector("root", {
        -- Priority 1: Survive
        BT.Sequence("survive", {
            BT.Condition("is_starving", function(ctx)
                local h = ctx.ecs:getComponent(ctx.id, "Hunger")
                return h and h.value < h.threshold
            end),
            BT.Action("find_food", function(ctx)
                local pos = ctx.ecs:getComponent(ctx.id, "Position")
                if not pos then return BT.FAILURE end
                local res = ctx.world:findNearestResource(pos.x, pos.y, "food", 30)
                if res then
                    ctx.bb.targetX = res.x
                    ctx.bb.targetY = res.y
                    ctx.bb.targetType = "food"
                    return BT.SUCCESS
                end
                return BT.FAILURE
            end),
            BT.Action("move_to_food", function(ctx)
                return Behaviors._moveToTarget(ctx)
            end),
            BT.Action("eat", function(ctx)
                local hunger = ctx.ecs:getComponent(ctx.id, "Hunger")
                if hunger then hunger.value = math.min(hunger.max, hunger.value + 40) end
                return BT.SUCCESS
            end),
        }),

        -- Priority 2: Drink
        BT.Sequence("drink", {
            BT.Condition("is_thirsty", function(ctx)
                local t = ctx.ecs:getComponent(ctx.id, "Thirst")
                return t and t.value < t.threshold
            end),
            BT.Action("find_water", function(ctx)
                local pos = ctx.ecs:getComponent(ctx.id, "Position")
                if not pos then return BT.FAILURE end
                local res = ctx.world:findNearestResource(pos.x, pos.y, "water", 30)
                if res then
                    ctx.bb.targetX = res.x
                    ctx.bb.targetY = res.y
                    return BT.SUCCESS
                end
                return BT.FAILURE
            end),
            BT.Action("move_to_water", function(ctx)
                return Behaviors._moveToTarget(ctx)
            end),
            BT.Action("drink_water", function(ctx)
                local thirst = ctx.ecs:getComponent(ctx.id, "Thirst")
                if thirst then thirst.value = math.min(thirst.max, thirst.value + 50) end
                return BT.SUCCESS
            end),
        }),

        -- Priority 3: Flee from danger
        BT.Sequence("flee", {
            BT.Condition("in_danger", function(ctx)
                local combat = ctx.ecs:getComponent(ctx.id, "Combat")
                local hp = ctx.ecs:getComponent(ctx.id, "Health")
                return (combat and combat.inCombat) and (hp and hp.current < hp.max * 0.3)
            end),
            BT.Action("run_away", function(ctx)
                local pos = ctx.ecs:getComponent(ctx.id, "Position")
                local vel = ctx.ecs:getComponent(ctx.id, "Velocity")
                if pos and vel then
                    vel.vx = (math.random() - 0.5) * vel.maxSpeed
                    vel.vy = (math.random() - 0.5) * vel.maxSpeed
                end
                return BT.SUCCESS
            end),
        }),

        -- Priority 4: Gather resources
        BT.Sequence("gather", {
            BT.Condition("needs_resources", function(ctx)
                local inv = ctx.ecs:getComponent(ctx.id, "Inventory")
                return inv and #inv.items < inv.capacity * 0.5
            end),
            BT.Action("find_resource", function(ctx)
                local pos = ctx.ecs:getComponent(ctx.id, "Position")
                if not pos then return BT.FAILURE end
                local types = {"wood", "stone", "iron", "herbs"}
                local res = ctx.world:findNearestResource(pos.x, pos.y, types[math.random(#types)], 40)
                if res then
                    ctx.bb.targetX = res.x
                    ctx.bb.targetY = res.y
                    ctx.bb.targetType = res.type
                    return BT.SUCCESS
                end
                return BT.FAILURE
            end),
            BT.Action("move_to_resource", function(ctx)
                return Behaviors._moveToTarget(ctx)
            end),
            BT.Action("harvest", function(ctx)
                local inv = ctx.ecs:getComponent(ctx.id, "Inventory")
                if inv and ctx.bb.targetType then
                    inv.items[#inv.items + 1] = { type = ctx.bb.targetType, qty = 1 }
                end
                return BT.SUCCESS
            end),
        }),

        -- Priority 5: Socialize
        BT.Sequence("socialize", {
            BT.Condition("wants_social", function(ctx)
                local emotion = ctx.ecs:getComponent(ctx.id, "Emotion")
                return emotion and emotion.happiness < 40
            end),
            BT.Action("find_nearby_agent", function(ctx)
                local pos = ctx.ecs:getComponent(ctx.id, "Position")
                if not pos or not ctx.grid then return BT.FAILURE end
                local nearby = ctx.grid:queryRadius(pos.x, pos.y, 10)
                for _, nid in ipairs(nearby) do
                    if nid ~= ctx.id then
                        local npos = ctx.ecs:getComponent(nid, "Position")
                        if npos then
                            ctx.bb.socialTarget = nid
                            ctx.bb.targetX = npos.x
                            ctx.bb.targetY = npos.y
                            return BT.SUCCESS
                        end
                    end
                end
                return BT.FAILURE
            end),
            BT.Action("move_to_agent", function(ctx)
                return Behaviors._moveToTarget(ctx)
            end),
            BT.Action("chat", function(ctx)
                local emotion = ctx.ecs:getComponent(ctx.id, "Emotion")
                if emotion then emotion.happiness = math.min(100, emotion.happiness + 15) end
                local rel = ctx.ecs:getComponent(ctx.id, "Relationships")
                if rel and ctx.bb.socialTarget then
                    rel.friends[ctx.bb.socialTarget] = (rel.friends[ctx.bb.socialTarget] or 0) + 5
                end
                return BT.SUCCESS
            end),
        }),

        -- Priority 6: Explore (wander)
        BT.Action("wander", function(ctx)
            local pos = ctx.ecs:getComponent(ctx.id, "Position")
            if not pos then return BT.FAILURE end
            ctx.bb.targetX = pos.x + (math.random() - 0.5) * 20
            ctx.bb.targetY = pos.y + (math.random() - 0.5) * 20
            ctx.bb.targetX = math.max(0, math.min(ctx.world.width - 1, ctx.bb.targetX))
            ctx.bb.targetY = math.max(0, math.min(ctx.world.height - 1, ctx.bb.targetY))
            Behaviors._moveToTarget(ctx)
            return BT.SUCCESS
        end),
    })
end

-- ─── Animal behavior tree ──────────────────────────────────────────────

function Behaviors._animalTree()
    return BT.Selector("animal_root", {
        BT.Sequence("flee_predator", {
            BT.Condition("threat_nearby", function(ctx) return false end),
            BT.Action("flee", function(ctx) return BT.SUCCESS end),
        }),
        BT.Sequence("forage", {
            BT.Condition("hungry", function(ctx)
                local h = ctx.ecs:getComponent(ctx.id, "Hunger")
                return h and h.value < 50
            end),
            BT.Action("find_food", function(ctx)
                local pos = ctx.ecs:getComponent(ctx.id, "Position")
                if not pos then return BT.FAILURE end
                ctx.bb.targetX = pos.x + (math.random() - 0.5) * 10
                ctx.bb.targetY = pos.y + (math.random() - 0.5) * 10
                return BT.SUCCESS
            end),
            BT.Action("eat", function(ctx)
                local h = ctx.ecs:getComponent(ctx.id, "Hunger")
                if h then h.value = math.min(h.max, h.value + 30) end
                return BT.SUCCESS
            end),
        }),
        BT.Action("idle_wander", function(ctx)
            local pos = ctx.ecs:getComponent(ctx.id, "Position")
            local vel = ctx.ecs:getComponent(ctx.id, "Velocity")
            if pos and vel then
                vel.vx = (math.random() - 0.5) * 1
                vel.vy = (math.random() - 0.5) * 1
            end
            return BT.SUCCESS
        end),
    })
end

-- ─── Helper: navigate toward blackboard target ─────────────────────────

function Behaviors._moveToTarget(ctx)
    local pos = ctx.ecs:getComponent(ctx.id, "Position")
    local pf  = ctx.ecs:getComponent(ctx.id, "Pathfinding")
    if not pos or not ctx.bb.targetX then return BT.FAILURE end

    local tx = math.floor(ctx.bb.targetX)
    local ty = math.floor(ctx.bb.targetY)
    local dx = tx - pos.x
    local dy = ty - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist < 1.5 then return BT.SUCCESS end

    -- Request pathfinding if no path or stale
    if pf and (not pf.path or #pf.path == 0 or pf.recompute) then
        local path = Pathfinding.findPath(ctx.world, math.floor(pos.x), math.floor(pos.y), tx, ty)
        pf.path = path
        pf.pathIndex = 1
        pf.recompute = false
    end

    return BT.RUNNING
end

return Behaviors
