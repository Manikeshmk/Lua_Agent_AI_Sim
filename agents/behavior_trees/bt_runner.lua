-- agents/behavior_trees/bt_runner.lua
-- Behavior tree tick evaluator.
-- Traverses the tree each tick, respecting RUNNING state.

local BT = require("agents.behavior_trees.bt_nodes")
local AgentBehaviors = require("agents.behavior_trees.agent_behaviors")

local BTRunner = {}

function BTRunner.tick(entityId, ecs, world, grid, dt)
    local ai = ecs:getComponent(entityId, "AI")
    if not ai then return end

    -- Build or retrieve tree
    if not ai.btRoot then
        ai.btRoot = AgentBehaviors.buildTree(entityId, ecs)
    end

    local ctx = {
        id    = entityId,
        ecs   = ecs,
        world = world,
        grid  = grid,
        dt    = dt,
        bb    = ecs:getComponent(entityId, "Goals") and ecs:getComponent(entityId, "Goals").blackboard or {},
    }

    BTRunner._eval(ai.btRoot, ctx)
end

function BTRunner._eval(node, ctx)
    local t = node.type
    if t == "action" then
        return node.fn(ctx)
    elseif t == "condition" then
        return node.fn(ctx) and BT.SUCCESS or BT.FAILURE
    elseif t == "sequence" then
        return BTRunner._sequence(node, ctx)
    elseif t == "selector" then
        return BTRunner._selector(node, ctx)
    elseif t == "parallel" then
        return BTRunner._parallel(node, ctx)
    elseif t == "inverter" then
        local r = BTRunner._eval(node.child, ctx)
        if r == BT.SUCCESS then return BT.FAILURE
        elseif r == BT.FAILURE then return BT.SUCCESS
        else return BT.RUNNING end
    elseif t == "repeater" then
        node.current = (node.current or 0) + 1
        if node.current > node.count then node.current = 0; return BT.SUCCESS end
        return BTRunner._eval(node.child, ctx)
    elseif t == "succeeder" then
        BTRunner._eval(node.child, ctx)
        return BT.SUCCESS
    elseif t == "until_fail" then
        local r = BTRunner._eval(node.child, ctx)
        return r == BT.FAILURE and BT.SUCCESS or BT.RUNNING
    elseif t == "cooldown" then
        local now = ctx.ecs:getComponent(ctx.id, "AI") and ctx.ecs:getComponent(ctx.id, "AI").decisionTimer or 0
        if now - (node.lastRun or -math.huge) < node.duration then return BT.FAILURE end
        node.lastRun = now
        return BTRunner._eval(node.child, ctx)
    end
    return BT.FAILURE
end

function BTRunner._sequence(node, ctx)
    local startIdx = 1
    if node.runningChild then startIdx = node.runningChild; node.runningChild = nil end
    for i = startIdx, #node.children do
        local r = BTRunner._eval(node.children[i], ctx)
        if r == BT.FAILURE then return BT.FAILURE end
        if r == BT.RUNNING then node.runningChild = i; return BT.RUNNING end
    end
    return BT.SUCCESS
end

function BTRunner._selector(node, ctx)
    local startIdx = 1
    if node.runningChild then startIdx = node.runningChild; node.runningChild = nil end
    for i = startIdx, #node.children do
        local r = BTRunner._eval(node.children[i], ctx)
        if r == BT.SUCCESS then return BT.SUCCESS end
        if r == BT.RUNNING then node.runningChild = i; return BT.RUNNING end
    end
    return BT.FAILURE
end

function BTRunner._parallel(node, ctx)
    local successes = 0
    local anyRunning = false
    for _, child in ipairs(node.children) do
        local r = BTRunner._eval(child, ctx)
        if r == BT.SUCCESS then successes = successes + 1 end
        if r == BT.RUNNING then anyRunning = true end
    end
    if successes >= node.threshold then return BT.SUCCESS end
    if anyRunning then return BT.RUNNING end
    return BT.FAILURE
end

return BTRunner
