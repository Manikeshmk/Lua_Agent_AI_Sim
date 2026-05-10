-- data/recipes.lua
-- Crafting recipe definitions.

local Recipes = {
    tools = {
        name   = "Tools",
        inputs = { wood = 2, iron = 1 },
        output = { tools = 1 },
        time   = 5.0,       -- seconds of sim time
        skill  = "crafting",
        minLevel = 0,
    },
    weapons = {
        name   = "Weapons",
        inputs = { iron = 2, wood = 1 },
        output = { weapons = 1 },
        time   = 8.0,
        skill  = "crafting",
        minLevel = 2,
    },
    armor = {
        name   = "Armor",
        inputs = { iron = 3 },
        output = { armor = 1 },
        time   = 10.0,
        skill  = "crafting",
        minLevel = 3,
    },
    potion = {
        name   = "Potion",
        inputs = { herbs = 2, water = 1 },
        output = { potion = 1 },
        time   = 3.0,
        skill  = "crafting",
        minLevel = 1,
    },
    bread = {
        name   = "Bread",
        inputs = { food = 2, water = 1 },
        output = { bread = 2 },
        time   = 2.0,
        skill  = "farming",
        minLevel = 0,
    },
    plank = {
        name   = "Plank",
        inputs = { wood = 3 },
        output = { plank = 2 },
        time   = 4.0,
        skill  = "crafting",
        minLevel = 0,
    },
}

return Recipes
