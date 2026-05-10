-- tests/run_tests.lua
-- Lightweight test runner (no external dependencies).
-- Usage: lua tests/run_tests.lua

local PASS = 0
local FAIL = 0
local ERRORS = {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        PASS = PASS + 1
        io.write("  ✓ " .. name .. "\n")
    else
        FAIL = FAIL + 1
        ERRORS[#ERRORS + 1] = { name = name, err = err }
        io.write("  ✗ " .. name .. ": " .. tostring(err) .. "\n")
    end
end

local function assertEqual(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end
end

local function assertTrue(a, msg)
    if not a then error((msg or "assertion failed"), 2) end
end

local function assertNotNil(a, msg)
    if a == nil then error((msg or "expected non-nil"), 2) end
end

-- ─── Add project root to path ──────────────────────────────────────────
package.path = package.path .. ";../?.lua;../?/init.lua"

print("═══════════════════════════════════════════")
print("  LuaAgentSim — Test Suite")
print("═══════════════════════════════════════════\n")

-- ─── ECS Tests ─────────────────────────────────────────────────────────
print("ECS World:")

local ECS = require("engine.ecs.world")

test("create world", function()
    local w = ECS.new()
    assertNotNil(w)
    assertEqual(w:entityCount(), 0)
end)

test("create entity", function()
    local w = ECS.new()
    local id = w:newEntity()
    assertEqual(id, 1)
    assertEqual(w:entityCount(), 1)
end)

test("add/get component", function()
    local w = ECS.new()
    local id = w:newEntity()
    w:addComponent(id, "Position", { x = 10, y = 20 })
    local pos = w:getComponent(id, "Position")
    assertNotNil(pos)
    assertEqual(pos.x, 10)
    assertEqual(pos.y, 20)
end)

test("has component", function()
    local w = ECS.new()
    local id = w:newEntity()
    w:addComponent(id, "Health", { current = 100, max = 100 })
    assertTrue(w:hasComponent(id, "Health"))
    assertTrue(not w:hasComponent(id, "Position"))
end)

test("remove component", function()
    local w = ECS.new()
    local id = w:newEntity()
    w:addComponent(id, "Health", { current = 100 })
    w:removeComponent(id, "Health")
    assertTrue(not w:hasComponent(id, "Health"))
end)

test("query entities", function()
    local w = ECS.new()
    local id1 = w:newEntity()
    local id2 = w:newEntity()
    w:addComponent(id1, "Position", { x = 0, y = 0 })
    w:addComponent(id1, "Health", { current = 100 })
    w:addComponent(id2, "Position", { x = 5, y = 5 })
    local results = w:query("Position", "Health")
    assertEqual(#results, 1)
    assertEqual(results[1], id1)
end)

test("destroy entity", function()
    local w = ECS.new()
    local id = w:newEntity()
    w:addComponent(id, "Position", { x = 0, y = 0 })
    w:destroyEntity(id)
    w:_flushDestroy()
    assertEqual(w:entityCount(), 0)
end)

test("tags", function()
    local w = ECS.new()
    local id = w:newEntity("agent", "human")
    assertTrue(w:hasTag(id, "agent"))
    assertTrue(w:hasTag(id, "human"))
    assertTrue(not w:hasTag(id, "animal"))
end)

-- ─── Components Tests ──────────────────────────────────────────────────
print("\nComponents:")
local Components = require("engine.ecs.components")

test("Position defaults", function()
    local p = Components.Position()
    assertEqual(p.x, 0)
    assertEqual(p.y, 0)
end)

test("Health defaults", function()
    local h = Components.Health(50)
    assertEqual(h.current, 50)
    assertEqual(h.max, 50)
end)

test("Inventory defaults", function()
    local inv = Components.Inventory(30)
    assertEqual(inv.capacity, 30)
    assertEqual(#inv.items, 0)
end)

test("AI personality generation", function()
    local ai = Components.AI()
    assertNotNil(ai.personality)
    assertTrue(ai.personality.openness >= 0 and ai.personality.openness <= 1)
end)

-- ─── Event Bus Tests ───────────────────────────────────────────────────
print("\nEvent Bus:")
local EventBus = require("engine.events.event_bus")

test("init and emit", function()
    EventBus.init()
    local received = false
    EventBus.on("test", function(data) received = true end)
    EventBus.emit("test", {})
    EventBus.flush()
    assertTrue(received)
end)

test("once listener fires once", function()
    EventBus.init()
    local count = 0
    EventBus.once("test_once", function() count = count + 1 end)
    EventBus.emit("test_once", {})
    EventBus.flush()
    EventBus.emit("test_once", {})
    EventBus.flush()
    assertEqual(count, 1)
end)

test("off removes listener", function()
    EventBus.init()
    local count = 0
    local handle = EventBus.on("test_off", function() count = count + 1 end)
    EventBus.off("test_off", handle)
    EventBus.emit("test_off", {})
    EventBus.flush()
    assertEqual(count, 0)
end)

-- ─── GOAP Tests ────────────────────────────────────────────────────────
print("\nGOAP:")
local GOAP = require("agents.goap.goap")

test("state matches", function()
    local state = { isHungry = true, hasFood = false }
    assertTrue(GOAP.stateMatches(state, { isHungry = true }))
    assertTrue(not GOAP.stateMatches(state, { isHungry = false }))
end)

test("apply effects", function()
    local state = { isHungry = true }
    local newState = GOAP.applyEffects(state, { isHungry = false, hasFood = true })
    assertEqual(newState.isHungry, false)
    assertEqual(newState.hasFood, true)
end)

test("simple plan", function()
    local current = { nearFood = true, hasFood = false, isHungry = true }
    local goal    = { isHungry = false }
    local actions = {
        GOAP.newAction("get_food", 2, { nearFood = true }, { hasFood = true }),
        GOAP.newAction("eat",      1, { hasFood = true },  { isHungry = false }),
    }
    local plan = GOAP.plan(current, goal, actions)
    assertNotNil(plan)
    assertTrue(#plan >= 1)
end)

-- ─── Scheduler Tests ──────────────────────────────────────────────────
print("\nScheduler:")
local Scheduler = require("engine.scheduler.scheduler")

test("add and run job", function()
    local s = Scheduler.new()
    local ran = false
    s:addJob("test_job", 0, function(dt) ran = true end)
    -- Mock love.timer if needed
    if not love then
        love = { timer = { getTime = os.clock } }
    end
    s:update(0.016)
    assertTrue(ran)
end)

test("disable job", function()
    local s = Scheduler.new()
    local count = 0
    s:addJob("test_disable", 0, function(dt) count = count + 1 end)
    s:enableJob("test_disable", false)
    s:update(0.016)
    assertEqual(count, 0)
end)

-- ─── Spatial Grid Tests ───────────────────────────────────────────────
print("\nSpatial Grid:")
local SpatialGrid = require("simulation.world.spatial_grid")

test("insert and query", function()
    local g = SpatialGrid.new(8)
    g:insert(1, 5, 5)
    g:insert(2, 6, 6)
    g:insert(3, 100, 100)
    local results = g:queryRadius(5, 5, 10)
    assertTrue(#results >= 2)
end)

test("move entity", function()
    local g = SpatialGrid.new(8)
    g:insert(1, 0, 0)
    g:move(1, 0, 0, 50, 50)
    local near = g:queryRadius(0, 0, 5)
    local found = false
    for _, id in ipairs(near) do if id == 1 then found = true end end
    assertTrue(not found)
end)

-- ─── Summary ───────────────────────────────────────────────────────────
print("\n═══════════════════════════════════════════")
print(string.format("  Results: %d passed, %d failed", PASS, FAIL))
print("═══════════════════════════════════════════")

if #ERRORS > 0 then
    print("\nFailures:")
    for _, e in ipairs(ERRORS) do
        print("  • " .. e.name .. ": " .. e.err)
    end
end

os.exit(FAIL > 0 and 1 or 0)
