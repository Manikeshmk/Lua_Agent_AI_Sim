-- simulation/economy/crafting.lua
-- Crafting system: recipe validation, production, skill requirements.

local Recipes = require("data.recipes")
local Items   = require("data.items")

local Crafting = {}

-- ─── Check if agent can craft a recipe ─────────────────────────────────

function Crafting.canCraft(entityId, recipeName, ecs)
    local recipe = Recipes[recipeName]
    if not recipe then return false, "unknown recipe" end

    local inv    = ecs:getComponent(entityId, "Inventory")
    local skills = ecs:getComponent(entityId, "Skills")
    if not inv then return false, "no inventory" end

    -- Skill check
    if recipe.skill and skills then
        local skillLevel = skills[recipe.skill] or 0
        if skillLevel < (recipe.minLevel or 0) then
            return false, "skill too low"
        end
    end

    -- Ingredient check
    local available = {}
    for _, item in ipairs(inv.items) do
        available[item.type] = (available[item.type] or 0) + (item.qty or 1)
    end

    for inputType, inputQty in pairs(recipe.inputs) do
        if (available[inputType] or 0) < inputQty then
            return false, "missing " .. inputType
        end
    end

    -- Inventory space check
    local outputCount = 0
    for _, qty in pairs(recipe.output) do outputCount = outputCount + qty end
    if #inv.items + outputCount > inv.capacity then
        return false, "inventory full"
    end

    return true, nil
end

-- ─── Execute crafting ──────────────────────────────────────────────────

function Crafting.craft(entityId, recipeName, ecs)
    local canDo, reason = Crafting.canCraft(entityId, recipeName, ecs)
    if not canDo then return false, reason end

    local recipe = Recipes[recipeName]
    local inv    = ecs:getComponent(entityId, "Inventory")
    local skills = ecs:getComponent(entityId, "Skills")

    -- Consume inputs
    for inputType, inputQty in pairs(recipe.inputs) do
        local remaining = inputQty
        for i = #inv.items, 1, -1 do
            if inv.items[i].type == inputType and remaining > 0 then
                local take = math.min(inv.items[i].qty or 1, remaining)
                remaining = remaining - take
                inv.items[i].qty = (inv.items[i].qty or 1) - take
                if inv.items[i].qty <= 0 then
                    table.remove(inv.items, i)
                end
            end
        end
    end

    -- Produce outputs
    for outType, outQty in pairs(recipe.output) do
        inv.items[#inv.items + 1] = { type = outType, qty = outQty }
    end

    -- Gain skill XP
    if skills and recipe.skill then
        skills[recipe.skill] = (skills[recipe.skill] or 0) + 0.15
        if skills.exp then
            skills.exp[recipe.skill] = (skills.exp[recipe.skill] or 0) + 1
        end
    end

    return true, nil
end

-- ─── Get available recipes for an agent ────────────────────────────────

function Crafting.getAvailableRecipes(entityId, ecs)
    local available = {}
    for name, _ in pairs(Recipes) do
        local canDo, _ = Crafting.canCraft(entityId, name, ecs)
        if canDo then
            available[#available + 1] = name
        end
    end
    return available
end

-- ─── Get all recipe names ──────────────────────────────────────────────

function Crafting.getAllRecipes()
    local names = {}
    for name, _ in pairs(Recipes) do
        names[#names + 1] = name
    end
    return names
end

-- ─── Get recipe info ───────────────────────────────────────────────────

function Crafting.getRecipeInfo(name)
    return Recipes[name]
end

return Crafting
