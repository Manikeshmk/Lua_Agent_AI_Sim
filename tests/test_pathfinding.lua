-- tests/test_pathfinding.lua
-- Pathfinding-specific test suite.

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
print("  Pathfinding Tests")
print("══════════════════════════════════\n")

-- Create a mock world
local mockWorld = {
    width  = 32,
    height = 32,
    _tiles = {},
}

for y = 0, 31 do
    for x = 0, 31 do
        mockWorld._tiles[y * 32 + x] = {
            biome    = "plains",
            walkable = true,
        }
    end
end

-- Add a wall
for y = 5, 15 do
    mockWorld._tiles[y * 32 + 10] = { biome = "mountain", walkable = false }
end

function mockWorld:getTile(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then return nil end
    return self._tiles[y * self.width + x]
end

function mockWorld:isWalkable(x, y)
    local t = self:getTile(x, y)
    return t ~= nil and t.walkable
end

local Pathfinding = require("systems.pathfinding")

test("straight line path", function()
    local path = Pathfinding.findPath(mockWorld, 0, 0, 5, 0)
    assertTrue(#path > 0, "path should not be empty")
    -- Path should end at goal
    local last = path[#path]
    assertEqual(math.floor(last.x), 5)
    assertEqual(math.floor(last.y), 0)
end)

test("path around obstacle", function()
    local path = Pathfinding.findPath(mockWorld, 5, 10, 15, 10)
    assertTrue(#path > 0, "path should not be empty")
    -- Path should be longer than straight line (obstacle blocks at x=10)
    assertTrue(#path > 10, "path should go around the wall")
end)

test("unreachable destination", function()
    -- Block off an area completely
    for x = 0, 31 do
        mockWorld._tiles[20 * 32 + x] = { biome = "mountain", walkable = false }
    end
    local path = Pathfinding.findPath(mockWorld, 0, 0, 0, 25, 500)
    assertEqual(#path, 0, "should return empty path for unreachable goal")
    -- Restore
    for x = 0, 31 do
        mockWorld._tiles[20 * 32 + x] = { biome = "plains", walkable = true }
    end
end)

test("same start and end", function()
    local path = Pathfinding.findPath(mockWorld, 5, 5, 5, 5)
    assertTrue(#path >= 1, "should return at least start node")
end)

test("path respects max nodes", function()
    local path = Pathfinding.findPath(mockWorld, 0, 0, 30, 30, 10)
    -- With only 10 nodes budget, may not find full path
    -- This should not crash
    assertTrue(type(path) == "table")
end)

print(string.format("\n  Results: %d passed, %d failed\n", PASS, FAIL))
