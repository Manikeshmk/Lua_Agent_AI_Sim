-- data/items.lua
-- Item definitions: properties, categories, and stacking rules.

local Items = {
    -- Raw materials
    wood  = { name = "Wood",   category = "raw",        weight = 2,  stackable = true,  maxStack = 50 },
    stone = { name = "Stone",  category = "raw",        weight = 4,  stackable = true,  maxStack = 30 },
    iron  = { name = "Iron",   category = "raw",        weight = 5,  stackable = true,  maxStack = 20 },
    gold  = { name = "Gold",   category = "raw",        weight = 3,  stackable = true,  maxStack = 100 },
    herbs = { name = "Herbs",  category = "raw",        weight = 0.5, stackable = true, maxStack = 40 },
    water = { name = "Water",  category = "consumable", weight = 1,  stackable = true,  maxStack = 10 },

    -- Consumables
    food   = { name = "Food",   category = "consumable", weight = 1,  stackable = true,  maxStack = 20,
               effects = { hunger = 30 } },
    bread  = { name = "Bread",  category = "consumable", weight = 0.5, stackable = true, maxStack = 15,
               effects = { hunger = 40 } },
    potion = { name = "Potion", category = "consumable", weight = 0.3, stackable = true, maxStack = 10,
               effects = { health = 30 } },

    -- Crafted goods
    tools   = { name = "Tools",   category = "equipment", weight = 3,  stackable = false, maxStack = 1,
                bonuses = { gathering = 2, farming = 2 } },
    weapons = { name = "Weapons", category = "equipment", weight = 4,  stackable = false, maxStack = 1,
                bonuses = { combat = 5, damage = 8 } },
    armor   = { name = "Armor",   category = "equipment", weight = 6,  stackable = false, maxStack = 1,
                bonuses = { armor = 5 } },
    plank   = { name = "Plank",   category = "material",  weight = 3,  stackable = true,  maxStack = 20 },
}

return Items
