-- tests/test_economy.lua
-- Economy system test suite.

package.path = package.path .. ";../?.lua;../?/init.lua"

local PASS, FAIL = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then PASS = PASS + 1; io.write("  ✓ " .. name .. "\n")
    else FAIL = FAIL + 1; io.write("  ✗ " .. name .. ": " .. tostring(err) .. "\n") end
end

local function assertTrue(a, msg)
    if not a then error(msg or "assertion failed", 2) end
end

local function assertEqual(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end
end

print("\n══════════════════════════════════")
print("  Economy Tests")
print("══════════════════════════════════\n")

-- Mock world with cities
local mockWorld = {
    width  = 64,
    height = 64,
    cities = {
        { x = 10, y = 10, name = "TestCity1", population = 10 },
        { x = 50, y = 50, name = "TestCity2", population = 15 },
    },
    resources = {},
}

local ECS = require("engine.ecs.world")
local Economy = require("simulation.economy.economy")

test("economy creation", function()
    local ecs = ECS.new()
    local eco = Economy.new(mockWorld, ecs)
    assertTrue(eco ~= nil)
    assertTrue(eco.markets[1] ~= nil, "should have at least one market")
    assertTrue(eco.markets[2] ~= nil, "should have two markets")
end)

test("get price", function()
    local ecs = ECS.new()
    local eco = Economy.new(mockWorld, ecs)
    local price = eco:getPrice(1, "food")
    assertTrue(price > 0, "food price should be positive")
end)

test("buy from market", function()
    local ecs = ECS.new()
    local eco = Economy.new(mockWorld, ecs)
    local initialStock = eco.markets[1].inventory["food"] or 0
    local ok, cost = eco:buy(1, "food", 1, 999)
    assertTrue(ok, "should be able to buy food")
    assertTrue(cost > 0, "cost should be positive")
    local newStock = eco.markets[1].inventory["food"] or 0
    assertEqual(newStock, initialStock - 1, "stock should decrease")
end)

test("sell to market", function()
    local ecs = ECS.new()
    local eco = Economy.new(mockWorld, ecs)
    local initialStock = eco.markets[1].inventory["wood"] or 0
    local ok, gold = eco:sell(1, "wood", 5, 999)
    assertTrue(ok, "should be able to sell wood")
    assertTrue(gold > 0, "should receive gold")
    local newStock = eco.markets[1].inventory["wood"] or 0
    assertEqual(newStock, initialStock + 5, "stock should increase")
end)

test("buy insufficient stock fails", function()
    local ecs = ECS.new()
    local eco = Economy.new(mockWorld, ecs)
    eco.markets[1].inventory["gold"] = 0
    local ok, reason = eco:buy(1, "gold", 100, 999)
    assertTrue(not ok, "should fail with no stock")
end)

test("nearest market", function()
    local ecs = ECS.new()
    local eco = Economy.new(mockWorld, ecs)
    local idx = eco:getNearestMarket(12, 12)
    assertEqual(idx, 1, "should return nearest market (city at 10,10)")
    local idx2 = eco:getNearestMarket(48, 48)
    assertEqual(idx2, 2, "should return nearest market (city at 50,50)")
end)

test("economy tick updates prices", function()
    local ecs = ECS.new()
    local eco = Economy.new(mockWorld, ecs)
    local priceBefore = eco:getPrice(1, "food")
    -- Create high demand
    eco.globalDemand["food"] = 500
    eco:tick(1.0)
    local priceAfter = eco:getPrice(1, "food")
    assertTrue(priceAfter >= priceBefore, "price should rise with demand")
end)

test("snapshot and restore", function()
    local ecs = ECS.new()
    local eco = Economy.new(mockWorld, ecs)
    eco.time = 100
    eco.globalDemand["food"] = 999
    local snap = eco:snapshot()
    assertTrue(snap.time == 100)
    assertEqual(snap.globalDemand["food"], 999)
end)

print(string.format("\n  Results: %d passed, %d failed\n", PASS, FAIL))
