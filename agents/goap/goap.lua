-- agents/goap/goap.lua
-- Goal-Oriented Action Planning (GOAP) planner.
-- Agents define world-state predicates, goals, and actions with
-- preconditions and effects. The planner finds the cheapest action
-- sequence from current state to a goal state using A*.

local GOAP = {}

-- ─── World state ───────────────────────────────────────────────────────

function GOAP.newState(tbl)
    return tbl or {}
end

function GOAP.stateMatches(state, condition)
    for k, v in pairs(condition) do
        if state[k] ~= v then return false end
    end
    return true
end

function GOAP.applyEffects(state, effects)
    local newState = {}
    for k, v in pairs(state) do newState[k] = v end
    for k, v in pairs(effects) do newState[k] = v end
    return newState
end

-- ─── Action definition ─────────────────────────────────────────────────

function GOAP.newAction(name, cost, preconditions, effects)
    return {
        name          = name,
        cost          = cost or 1,
        preconditions = preconditions or {},
        effects       = effects or {},
    }
end

-- ─── Planner (backward-chaining A*) ────────────────────────────────────

function GOAP.plan(currentState, goalState, actions, maxDepth)
    maxDepth = maxDepth or 10

    -- Node: { state, action (nil for start), parent, cost, depth }
    local openList = {}
    local closedSet = {}

    local function stateKey(s)
        local parts = {}
        for k, v in pairs(s) do parts[#parts + 1] = k .. "=" .. tostring(v) end
        table.sort(parts)
        return table.concat(parts, ",")
    end

    -- Start from goal, work backwards
    local startNode = { state = goalState, action = nil, parent = nil, cost = 0, depth = 0 }
    openList[#openList + 1] = startNode

    while #openList > 0 do
        -- Pick lowest cost
        table.sort(openList, function(a, b) return a.cost < b.cost end)
        local current = table.remove(openList, 1)
        local key = stateKey(current.state)

        if closedSet[key] then goto continue end
        closedSet[key] = true

        -- Check if current state is satisfied by agent's actual state
        if GOAP.stateMatches(currentState, current.state) then
            -- Reconstruct plan
            local plan = {}
            local node = current
            while node and node.action do
                table.insert(plan, 1, node.action)
                node = node.parent
            end
            return plan
        end

        if current.depth >= maxDepth then goto continue end

        -- Expand: find actions whose effects contribute to unsatisfied predicates
        for _, action in ipairs(actions) do
            local contributes = false
            for k, v in pairs(action.effects) do
                if current.state[k] == v then contributes = true; break end
            end
            if contributes then
                -- New state: remove satisfied predicates, add preconditions
                local newState = {}
                for k, v in pairs(current.state) do
                    local effectSatisfies = action.effects[k] == v
                    if not effectSatisfies then newState[k] = v end
                end
                for k, v in pairs(action.preconditions) do
                    newState[k] = v
                end
                local newNode = {
                    state  = newState,
                    action = action,
                    parent = current,
                    cost   = current.cost + action.cost,
                    depth  = current.depth + 1,
                }
                openList[#openList + 1] = newNode
            end
        end

        ::continue::
    end

    return nil  -- No plan found
end

-- ─── Predefined actions for agents ─────────────────────────────────────

GOAP.AGENT_ACTIONS = {
    GOAP.newAction("find_food",    2, { nearFood = true },          { hasFood = true }),
    GOAP.newAction("eat_food",     1, { hasFood = true },           { isHungry = false }),
    GOAP.newAction("find_water",   2, { nearWater = true },         { hasWater = true }),
    GOAP.newAction("drink_water",  1, { hasWater = true },          { isThirsty = false }),
    GOAP.newAction("gather_wood",  3, { nearWood = true },          { hasWood = true }),
    GOAP.newAction("build_shelter",5, { hasWood = true },           { hasShelter = true }),
    GOAP.newAction("craft_tool",   4, { hasWood = true, hasIron = true }, { hasTool = true }),
    GOAP.newAction("mine_iron",    4, { nearIron = true },          { hasIron = true }),
    GOAP.newAction("trade",        3, { atMarket = true },          { hasGold = true }),
    GOAP.newAction("rest",         2, {},                           { isRested = true }),
    GOAP.newAction("fight",        3, { enemyNearby = true, hasTool = true }, { enemyDefeated = true }),
    GOAP.newAction("explore",      2, {},                           { areaExplored = true }),
}

return GOAP
