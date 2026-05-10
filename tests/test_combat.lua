-- tests/test_combat.lua
-- Combat system test suite.

package.path = package.path .. ";../?.lua;../?/init.lua"

local PASS, FAIL = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then PASS = PASS + 1; io.write("  ✓ " .. name .. "\n")
    else FAIL = FAIL + 1; io.write("  ✗ " .. name .. ": " .. tostring(err) .. "\n") end
end

local function assertTrue(a, msg) if not a then error(msg or "assertion failed", 2) end end
local function assertEqual(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end

print("\n══════════════════════════════════")
print("  Combat Tests")
print("══════════════════════════════════\n")

-- We need to mock love and EventBus for combat tests
if not love then love = { timer = { getTime = os.clock } } end

local ECS = require("engine.ecs.world")
local Components = require("engine.ecs.components")
local EventBus = require("engine.events.event_bus")

-- Reset event bus for each test
local function setupCombatEntities()
    EventBus.init()
    local ecs = ECS.new()

    local attacker = ecs:newEntity("agent")
    ecs:addComponent(attacker, "Position", Components.Position(5, 5))
    ecs:addComponent(attacker, "Health",   Components.Health(100))
    ecs:addComponent(attacker, "Combat",   Components.Combat())
    ecs:addComponent(attacker, "Emotion",  Components.Emotion())
    ecs:addComponent(attacker, "Skills",   Components.Skills())
    ecs:addComponent(attacker, "Velocity", Components.Velocity())

    local defender = ecs:newEntity("agent")
    ecs:addComponent(defender, "Position", Components.Position(5, 6))
    ecs:addComponent(defender, "Health",   Components.Health(100))
    ecs:addComponent(defender, "Combat",   Components.Combat())
    ecs:addComponent(defender, "Emotion",  Components.Emotion())
    ecs:addComponent(defender, "Velocity", Components.Velocity())

    return ecs, attacker, defender
end

local Combat = require("systems.combat")

test("engage deals damage", function()
    local ecs, atk, def = setupCombatEntities()
    Combat.engage(atk, def, ecs)
    local defHp = ecs:getComponent(def, "Health")
    assertTrue(defHp.current < 100, "defender should take damage")
end)

test("engage sets combat state", function()
    local ecs, atk, def = setupCombatEntities()
    Combat.engage(atk, def, ecs)
    local atkC = ecs:getComponent(atk, "Combat")
    local defC = ecs:getComponent(def, "Combat")
    assertTrue(atkC.inCombat, "attacker should be in combat")
    assertTrue(defC.inCombat, "defender should be in combat")
end)

test("cooldown prevents rapid attacks", function()
    local ecs, atk, def = setupCombatEntities()
    Combat.engage(atk, def, ecs)
    local hpAfterFirst = ecs:getComponent(def, "Health").current
    Combat.engage(atk, def, ecs) -- should be on cooldown
    local hpAfterSecond = ecs:getComponent(def, "Health").current
    assertEqual(hpAfterFirst, hpAfterSecond, "second attack should be blocked by cooldown")
end)

test("out of range attack fails", function()
    local ecs, atk, def = setupCombatEntities()
    -- Move defender far away
    local defPos = ecs:getComponent(def, "Position")
    defPos.x = 100; defPos.y = 100
    Combat.engage(atk, def, ecs)
    local defHp = ecs:getComponent(def, "Health")
    assertEqual(defHp.current, 100, "out of range attack should do nothing")
end)

test("emotional impact on defender", function()
    local ecs, atk, def = setupCombatEntities()
    local defEmo = ecs:getComponent(def, "Emotion")
    local fearBefore = defEmo.fear
    Combat.engage(atk, def, ecs)
    assertTrue(defEmo.fear > fearBefore, "defender fear should increase")
end)

test("morale decrease on hit", function()
    local ecs, atk, def = setupCombatEntities()
    local defC = ecs:getComponent(def, "Combat")
    local moraleBefore = defC.morale
    Combat.engage(atk, def, ecs)
    assertTrue(defC.morale < moraleBefore, "defender morale should decrease")
end)

test("should fight decision", function()
    local ecs, atk, def = setupCombatEntities()
    local shouldFight = Combat.shouldFight(atk, ecs, def)
    assertTrue(shouldFight, "healthy agent should want to fight")

    -- Lower HP
    local atkHp = ecs:getComponent(atk, "Health")
    atkHp.current = 10
    shouldFight = Combat.shouldFight(atk, ecs, def)
    assertTrue(not shouldFight, "low HP agent should not want to fight")
end)

print(string.format("\n  Results: %d passed, %d failed\n", PASS, FAIL))
