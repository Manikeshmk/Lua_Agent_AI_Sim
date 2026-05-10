-- simulation/economy/economy.lua
-- Dynamic economy simulation: markets, supply/demand, pricing, crafting.

local Economy = {}
Economy.__index = Economy

local ITEMS = {
    wood  = { basePrice = 5,  category = "raw" },
    stone = { basePrice = 8,  category = "raw" },
    iron  = { basePrice = 15, category = "raw" },
    food  = { basePrice = 3,  category = "consumable" },
    gold  = { basePrice = 50, category = "raw" },
    herbs = { basePrice = 7,  category = "raw" },
    water = { basePrice = 2,  category = "consumable" },
    tools = { basePrice = 25, category = "crafted" },
    weapons = { basePrice = 40, category = "crafted" },
    armor   = { basePrice = 35, category = "crafted" },
    potion  = { basePrice = 20, category = "crafted" },
    bread   = { basePrice = 4,  category = "crafted" },
    plank   = { basePrice = 10, category = "crafted" },
}

local RECIPES = {
    tools   = { inputs = { wood = 2, iron = 1 }, time = 5, skill = "crafting" },
    weapons = { inputs = { iron = 2, wood = 1 }, time = 8, skill = "crafting" },
    armor   = { inputs = { iron = 3 },           time = 10, skill = "crafting" },
    potion  = { inputs = { herbs = 2, water = 1 }, time = 3, skill = "crafting" },
    bread   = { inputs = { food = 2, water = 1 },  time = 2, skill = "farming" },
    plank   = { inputs = { wood = 3 },              time = 4, skill = "crafting" },
}

function Economy.new(world, ecs)
    local e = setmetatable({}, Economy)
    e.world = world
    e.ecs = ecs
    e.markets = {}          -- cityIndex -> Market
    e.globalSupply = {}     -- item -> total supply
    e.globalDemand = {}     -- item -> total demand
    e.priceHistory = {}     -- item -> list of prices
    e.tradeLog = {}
    e.time = 0

    -- Initialize global supply/demand
    for name, _ in pairs(ITEMS) do
        e.globalSupply[name] = 100
        e.globalDemand[name] = 100
        e.priceHistory[name] = { ITEMS[name].basePrice }
    end

    -- Create market per city
    if world.cities then
        for i, city in ipairs(world.cities) do
            e.markets[i] = {
                cityIndex = i,
                city = city,
                inventory = {},
                prices = {},
                tradeVolume = 0,
            }
            for name, item in pairs(ITEMS) do
                e.markets[i].inventory[name] = math.random(10, 50)
                e.markets[i].prices[name] = item.basePrice
            end
        end
    end
    return e
end

function Economy:tick(dt)
    self.time = self.time + dt
    self:_updatePrices()
    self:_decayDemand()
end

function Economy:_updatePrices()
    for _, market in pairs(self.markets) do
        for name, item in pairs(ITEMS) do
            local supply = market.inventory[name] or 1
            local demand = self.globalDemand[name] or 100
            local ratio = demand / math.max(supply, 1)
            local variance = 1.0 + (math.random() - 0.5) * 0.1
            market.prices[name] = math.max(1, math.floor(item.basePrice * ratio * variance))
        end
    end
    -- Record global prices
    for name, _ in pairs(ITEMS) do
        local avg = 0
        local count = 0
        for _, market in pairs(self.markets) do
            avg = avg + (market.prices[name] or 0)
            count = count + 1
        end
        if count > 0 then
            local history = self.priceHistory[name]
            history[#history + 1] = math.floor(avg / count)
            if #history > 200 then table.remove(history, 1) end
        end
    end
end

function Economy:_decayDemand()
    for name, _ in pairs(ITEMS) do
        self.globalDemand[name] = math.max(10, (self.globalDemand[name] or 100) * 0.999)
    end
end

function Economy:buy(marketIdx, item, qty, buyerId)
    local market = self.markets[marketIdx]
    if not market then return false, "no market" end
    local avail = market.inventory[item] or 0
    if avail < qty then return false, "insufficient stock" end
    local price = (market.prices[item] or 1) * qty
    market.inventory[item] = avail - qty
    market.tradeVolume = market.tradeVolume + price
    self.globalDemand[item] = (self.globalDemand[item] or 100) + qty * 2
    self.tradeLog[#self.tradeLog + 1] = { type = "buy", item = item, qty = qty, price = price, buyer = buyerId, market = marketIdx, time = self.time }
    return true, price
end

function Economy:sell(marketIdx, item, qty, sellerId)
    local market = self.markets[marketIdx]
    if not market then return false, "no market" end
    local price = math.floor((market.prices[item] or 1) * qty * 0.7)
    market.inventory[item] = (market.inventory[item] or 0) + qty
    market.tradeVolume = market.tradeVolume + price
    self.globalSupply[item] = (self.globalSupply[item] or 100) + qty
    self.tradeLog[#self.tradeLog + 1] = { type = "sell", item = item, qty = qty, price = price, seller = sellerId, market = marketIdx, time = self.time }
    return true, price
end

function Economy:canCraft(recipe)
    return RECIPES[recipe] ~= nil
end

function Economy:getRecipe(name)
    return RECIPES[name]
end

function Economy:getPrice(marketIdx, item)
    local market = self.markets[marketIdx]
    return market and market.prices[item] or (ITEMS[item] and ITEMS[item].basePrice) or 1
end

function Economy:getGlobalPrice(item)
    local history = self.priceHistory[item]
    return history and history[#history] or 1
end

function Economy:getNearestMarket(x, y)
    local best, bestDist = nil, math.huge
    for idx, market in pairs(self.markets) do
        local c = market.city
        local d = (c.x - x)^2 + (c.y - y)^2
        if d < bestDist then bestDist = d; best = idx end
    end
    return best
end

function Economy:snapshot()
    return { time = self.time, globalSupply = self.globalSupply, globalDemand = self.globalDemand, priceHistory = self.priceHistory }
end

function Economy:restore(snap)
    self.time = snap.time or 0
    self.globalSupply = snap.globalSupply or self.globalSupply
    self.globalDemand = snap.globalDemand or self.globalDemand
    self.priceHistory = snap.priceHistory or self.priceHistory
end

return Economy
