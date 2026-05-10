-- systems/economy_system.lua
-- ECS system that drives agent economic behaviors: trading, crafting,
-- profession specialization, and market interaction.

local Economy = require("simulation.economy.economy")

local EconomySystem = {}

-- ─── Agent trade decision ──────────────────────────────────────────────

function EconomySystem.attemptTrade(entityId, ecs, world, economy)
    local pos = ecs:getComponent(entityId, "Position")
    local inv = ecs:getComponent(entityId, "Inventory")
    if not pos or not inv then return false end

    -- Find nearest market
    local marketIdx = economy:getNearestMarket(pos.x, pos.y)
    if not marketIdx then return false end

    local market = economy.markets[marketIdx]
    local city = market.city
    local dist = math.sqrt((pos.x - city.x)^2 + (pos.y - city.y)^2)
    if dist > 10 then return false end  -- Must be near the market

    -- Sell excess resources
    local sold = false
    for i = #inv.items, 1, -1 do
        local item = inv.items[i]
        if item and item.type then
            local price = economy:getPrice(marketIdx, item.type)
            if price and price > 0 then
                local ok, gold = economy:sell(marketIdx, item.type, item.qty or 1, entityId)
                if ok then
                    inv.gold = inv.gold + gold
                    table.remove(inv.items, i)
                    sold = true
                end
            end
        end
    end

    -- Buy needed items
    local hunger = ecs:getComponent(entityId, "Hunger")
    if hunger and hunger.value < 50 and inv.gold >= 5 then
        local foodPrice = economy:getPrice(marketIdx, "food")
        if foodPrice and inv.gold >= foodPrice then
            local ok, cost = economy:buy(marketIdx, "food", 1, entityId)
            if ok then
                inv.gold = inv.gold - cost
                inv.items[#inv.items + 1] = { type = "food", qty = 1 }
            end
        end
    end

    return sold
end

-- ─── Crafting ──────────────────────────────────────────────────────────

function EconomySystem.attemptCraft(entityId, ecs, economy, recipeName)
    local inv    = ecs:getComponent(entityId, "Inventory")
    local skills = ecs:getComponent(entityId, "Skills")
    if not inv or not skills then return false end

    local recipe = economy:getRecipe(recipeName)
    if not recipe then return false end

    -- Check skill level
    local skillLevel = skills[recipe.skill] or 0
    if recipe.minLevel and skillLevel < recipe.minLevel then return false end

    -- Check required inputs
    local available = {}
    for _, item in ipairs(inv.items) do
        available[item.type] = (available[item.type] or 0) + (item.qty or 1)
    end

    for inputType, inputQty in pairs(recipe.inputs) do
        if (available[inputType] or 0) < inputQty then return false end
    end

    -- Consume inputs
    for inputType, inputQty in pairs(recipe.inputs) do
        local remaining = inputQty
        for i = #inv.items, 1, -1 do
            if inv.items[i].type == inputType and remaining > 0 then
                local take = math.min(inv.items[i].qty or 1, remaining)
                remaining = remaining - take
                inv.items[i].qty = (inv.items[i].qty or 1) - take
                if inv.items[i].qty <= 0 then table.remove(inv.items, i) end
            end
        end
    end

    -- Produce output
    for outType, outQty in pairs(recipe.output) do
        inv.items[#inv.items + 1] = { type = outType, qty = outQty }
    end

    -- Gain XP
    if skills.exp then
        skills.exp[recipe.skill] = (skills.exp[recipe.skill] or 0) + 1
    end
    skills[recipe.skill] = (skills[recipe.skill] or 0) + 0.1

    return true
end

-- ─── Profession specialization ─────────────────────────────────────────

function EconomySystem.updateProfession(entityId, ecs)
    local skills = ecs:getComponent(entityId, "Skills")
    local prof   = ecs:getComponent(entityId, "Profession")
    if not skills or not prof then return end

    -- Find highest skill
    local bestSkill, bestVal = "peasant", 0
    local skillNames = { "combat", "crafting", "farming", "trading", "gathering", "social" }
    for _, name in ipairs(skillNames) do
        local val = skills[name] or 0
        if val > bestVal then bestVal = val; bestSkill = name end
    end

    -- Map skill to profession
    local profMap = {
        combat    = "warrior",
        crafting  = "blacksmith",
        farming   = "farmer",
        trading   = "merchant",
        gathering = "gatherer",
        social    = "diplomat",
    }

    if bestVal >= 3 then
        prof.name = profMap[bestSkill] or "peasant"
        prof.level = math.floor(bestVal / 3) + 1
    end
end

return EconomySystem
