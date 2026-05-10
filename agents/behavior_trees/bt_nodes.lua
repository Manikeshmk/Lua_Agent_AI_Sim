-- agents/behavior_trees/bt_nodes.lua
-- Behavior tree node definitions.
-- Supports: Sequence, Selector, Parallel, Decorator, Condition, Action.

local BT = {}

BT.SUCCESS = "success"
BT.FAILURE = "failure"
BT.RUNNING = "running"

-- ─── Leaf: Action ──────────────────────────────────────────────────────

function BT.Action(name, fn)
    return { type = "action", name = name, fn = fn }
end

-- ─── Leaf: Condition ───────────────────────────────────────────────────

function BT.Condition(name, fn)
    return { type = "condition", name = name, fn = fn }
end

-- ─── Composite: Sequence (AND — all must succeed) ──────────────────────

function BT.Sequence(name, children)
    return { type = "sequence", name = name, children = children, runningChild = nil }
end

-- ─── Composite: Selector (OR — first success wins) ─────────────────────

function BT.Selector(name, children)
    return { type = "selector", name = name, children = children, runningChild = nil }
end

-- ─── Composite: Parallel (run all, succeed if threshold met) ───────────

function BT.Parallel(name, children, successThreshold)
    return { type = "parallel", name = name, children = children, threshold = successThreshold or #children }
end

-- ─── Decorator: Inverter ───────────────────────────────────────────────

function BT.Inverter(name, child)
    return { type = "inverter", name = name, child = child }
end

-- ─── Decorator: Repeater ───────────────────────────────────────────────

function BT.Repeater(name, child, count)
    return { type = "repeater", name = name, child = child, count = count or math.huge, current = 0 }
end

-- ─── Decorator: Succeeder (always return success) ──────────────────────

function BT.Succeeder(name, child)
    return { type = "succeeder", name = name, child = child }
end

-- ─── Decorator: UntilFail ──────────────────────────────────────────────

function BT.UntilFail(name, child)
    return { type = "until_fail", name = name, child = child }
end

-- ─── Decorator: Cooldown ───────────────────────────────────────────────

function BT.Cooldown(name, child, duration)
    return { type = "cooldown", name = name, child = child, duration = duration, lastRun = -math.huge }
end

return BT
