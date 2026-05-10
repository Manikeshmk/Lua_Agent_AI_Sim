-- simulation/world/world.lua
-- Procedural world generator and chunk-based tile manager.
-- Generates terrain using layered simplex-like noise, assigns biomes,
-- distributes resources, and manages chunk loading/unloading.

local Config = require("engine.config")

local World = {}
World.__index = World

-- ─── Noise helpers (pure Lua simplex approximation) ────────────────────

local GRAD3 = {
    {1,1,0},{-1,1,0},{1,-1,0},{-1,-1,0},
    {1,0,1},{-1,0,1},{1,0,-1},{-1,0,-1},
    {0,1,1},{0,-1,1},{0,1,-1},{0,-1,-1},
}

local _perm = {}
local function _initPerm(seed)
    local rng = seed or 42
    local p = {}
    for i = 0, 255 do p[i] = i end
    for i = 255, 1, -1 do
        rng = (rng * 16807) % 2147483647
        local j = rng % (i + 1)
        p[i], p[j] = p[j], p[i]
    end
    for i = 0, 511 do _perm[i] = p[i % 256] end
end

local function _dot2(g, x, y) return g[1]*x + g[2]*y end

local floor = math.floor
local F2 = 0.5 * (math.sqrt(3) - 1)
local G2 = (3 - math.sqrt(3)) / 6

local function noise2d(x, y)
    local s = (x + y) * F2
    local i, j = floor(x + s), floor(y + s)
    local t = (i + j) * G2
    local X0, Y0 = i - t, j - t
    local x0, y0 = x - X0, y - Y0

    local i1, j1
    if x0 > y0 then i1, j1 = 1, 0 else i1, j1 = 0, 1 end

    local x1 = x0 - i1 + G2
    local y1 = y0 - j1 + G2
    local x2 = x0 - 1 + 2*G2
    local y2 = y0 - 1 + 2*G2

    local ii = i % 256
    local jj = j % 256

    local n0, n1, n2 = 0, 0, 0

    local t0 = 0.5 - x0*x0 - y0*y0
    if t0 >= 0 then
        t0 = t0 * t0
        local gi0 = _perm[ii + _perm[jj]] % 12
        n0 = t0 * t0 * _dot2(GRAD3[gi0 + 1], x0, y0)
    end

    local t1 = 0.5 - x1*x1 - y1*y1
    if t1 >= 0 then
        t1 = t1 * t1
        local gi1 = _perm[ii + i1 + _perm[jj + j1]] % 12
        n1 = t1 * t1 * _dot2(GRAD3[gi1 + 1], x1, y1)
    end

    local t2 = 0.5 - x2*x2 - y2*y2
    if t2 >= 0 then
        t2 = t2 * t2
        local gi2 = _perm[ii + 1 + _perm[jj + 1]] % 12
        n2 = t2 * t2 * _dot2(GRAD3[gi2 + 1], x2, y2)
    end

    return 70 * (n0 + n1 + n2)
end

-- Fractal Brownian Motion
local function fbm(x, y, octaves, lacunarity, gain)
    octaves     = octaves or 6
    lacunarity  = lacunarity or 2.0
    gain        = gain or 0.5
    local amp, freq, sum = 1, 1, 0
    for _ = 1, octaves do
        sum  = sum + amp * noise2d(x * freq, y * freq)
        amp  = amp * gain
        freq = freq * lacunarity
    end
    return sum
end

-- ─── World constructor ─────────────────────────────────────────────────

function World.new(w, h, seed)
    local world = setmetatable({}, World)
    world.width  = w or Config.WORLD_WIDTH
    world.height = h or Config.WORLD_HEIGHT
    world.seed   = seed or Config.SEED
    world.tiles  = {}        -- flat array [y * width + x]
    world.chunks = {}        -- chunkKey -> { loaded, dirty }
    world.chunkSize = Config.CHUNK_SIZE
    world.resources = {}     -- list of resource spawn points
    world.cities    = {}     -- list of city locations
    world.factionMap   = {}  -- flat: tileIndex -> factionId
    world.influenceMap = {}  -- flat: tileIndex -> float
    world.time = 0
    _initPerm(seed)
    return world
end

-- ─── Generation ────────────────────────────────────────────────────────

function World:generate()
    print("[World] Generating " .. self.width .. "x" .. self.height .. " world (seed=" .. self.seed .. ")...")
    local t0 = os.clock()

    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local idx = y * self.width + x
            local tile = self:_generateTile(x, y)
            self.tiles[idx] = tile
            self.factionMap[idx]   = 0
            self.influenceMap[idx] = 0
        end
    end

    self:_placeResources()
    self:_placeCities()

    -- Mark all chunks as loaded
    local cw = math.ceil(self.width  / self.chunkSize)
    local ch = math.ceil(self.height / self.chunkSize)
    for cy = 0, ch - 1 do
        for cx = 0, cw - 1 do
            local key = cx .. "," .. cy
            self.chunks[key] = { loaded = true, dirty = false }
        end
    end

    local elapsed = os.clock() - t0
    print(string.format("[World] Generated in %.2f seconds.", elapsed))
end

function World:_generateTile(x, y)
    local nx = x / self.width
    local ny = y / self.height

    -- Elevation: multiple octaves
    local elevation = (fbm(nx * 4, ny * 4, 6, 2.0, 0.5) + 1) / 2

    -- Moisture
    local moisture = (fbm(nx * 3 + 100, ny * 3 + 100, 4, 2.0, 0.5) + 1) / 2

    -- Temperature (latitude-based + noise)
    local latFactor = 1.0 - math.abs(ny - 0.5) * 2
    local tempNoise = (noise2d(nx * 2 + 200, ny * 2 + 200) + 1) / 2
    local temperature = latFactor * 0.7 + tempNoise * 0.3

    -- Biome assignment
    local biome = self:_classifyBiome(elevation, moisture, temperature)

    return {
        x           = x,
        y           = y,
        elevation   = elevation,
        moisture    = moisture,
        temperature = temperature,
        biome       = biome,
        resource    = nil,
        building    = nil,
        walkable    = biome ~= "ocean" and biome ~= "mountain",
        fertility   = moisture * temperature,
    }
end

function World:_classifyBiome(e, m, t)
    if e < 0.25 then return "ocean"    end
    if e < 0.30 then return "beach"    end
    if e > 0.80 then
        if t < 0.25 then return "snow" end
        return "mountain"
    end
    if t < 0.20 then return "tundra"   end
    if t < 0.35 then
        if m > 0.5 then return "swamp" end
        return "tundra"
    end
    if m < 0.25 then return "desert"   end
    if m < 0.50 then
        if t > 0.65 then return "grassland" end
        return "plains"
    end
    if t > 0.70 then return "jungle" end
    return "forest"
end

-- ─── Resource placement ────────────────────────────────────────────────

local RESOURCE_TYPES = {
    { name = "wood",   biomes = { forest = 0.15, jungle = 0.12 } },
    { name = "stone",  biomes = { mountain = 0.20, plains = 0.05 } },
    { name = "iron",   biomes = { mountain = 0.10, tundra = 0.06 } },
    { name = "food",   biomes = { plains = 0.12, grassland = 0.15, forest = 0.05 } },
    { name = "gold",   biomes = { mountain = 0.03, desert = 0.02 } },
    { name = "water",  biomes = { swamp = 0.15, beach = 0.10 } },
    { name = "herbs",  biomes = { jungle = 0.10, forest = 0.08, swamp = 0.06 } },
}

function World:_placeResources()
    self.resources = {}
    for _, rDef in ipairs(RESOURCE_TYPES) do
        for y = 0, self.height - 1 do
            for x = 0, self.width - 1 do
                local tile = self:getTile(x, y)
                if tile then
                    local chance = rDef.biomes[tile.biome] or 0
                    if chance > 0 and math.random() < chance then
                        tile.resource = rDef.name
                        self.resources[#self.resources + 1] = {
                            x = x, y = y, type = rDef.name,
                            amount = math.random(20, 100),
                        }
                    end
                end
            end
        end
    end
    print("[World] Placed " .. #self.resources .. " resource deposits.")
end

-- ─── City placement ────────────────────────────────────────────────────

function World:_placeCities()
    self.cities = {}
    local numCities = math.floor(self.width * self.height / 2000) + 3
    local attempts = 0
    while #self.cities < numCities and attempts < numCities * 100 do
        attempts = attempts + 1
        local cx = math.random(10, self.width  - 10)
        local cy = math.random(10, self.height - 10)
        local tile = self:getTile(cx, cy)
        if tile and tile.walkable and tile.fertility > 0.3 then
            -- Check min distance from existing cities
            local tooClose = false
            for _, c in ipairs(self.cities) do
                local d = math.sqrt((cx - c.x)^2 + (cy - c.y)^2)
                if d < 20 then tooClose = true; break end
            end
            if not tooClose then
                self.cities[#self.cities + 1] = {
                    x = cx, y = cy,
                    name = "City_" .. #self.cities + 1,
                    population = math.random(5, 20),
                    factionId  = nil,
                }
            end
        end
    end
    print("[World] Placed " .. #self.cities .. " cities.")
end

-- ─── Tile access ───────────────────────────────────────────────────────

function World:getTile(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then return nil end
    return self.tiles[y * self.width + x]
end

function World:setTile(x, y, tile)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then return end
    self.tiles[y * self.width + x] = tile
end

function World:isWalkable(x, y)
    local t = self:getTile(x, y)
    return t ~= nil and t.walkable
end

-- ─── Chunk management ──────────────────────────────────────────────────

function World:getChunkKey(x, y)
    return math.floor(x / self.chunkSize) .. "," .. math.floor(y / self.chunkSize)
end

function World:isChunkLoaded(cx, cy)
    local key = cx .. "," .. cy
    return self.chunks[key] and self.chunks[key].loaded
end

-- ─── Spatial queries ───────────────────────────────────────────────────

function World:getTilesInRadius(cx, cy, radius)
    local result = {}
    local r2 = radius * radius
    local x0 = math.max(0, math.floor(cx - radius))
    local y0 = math.max(0, math.floor(cy - radius))
    local x1 = math.min(self.width  - 1, math.ceil(cx + radius))
    local y1 = math.min(self.height - 1, math.ceil(cy + radius))
    for y = y0, y1 do
        for x = x0, x1 do
            if (x - cx)^2 + (y - cy)^2 <= r2 then
                local t = self:getTile(x, y)
                if t then result[#result + 1] = t end
            end
        end
    end
    return result
end

function World:findNearestResource(cx, cy, resType, maxDist)
    local best, bestDist = nil, (maxDist or 50)^2
    for _, r in ipairs(self.resources) do
        if r.type == resType and r.amount > 0 then
            local d2 = (r.x - cx)^2 + (r.y - cy)^2
            if d2 < bestDist then bestDist = d2; best = r end
        end
    end
    return best
end

function World:findNearestCity(cx, cy)
    local best, bestDist = nil, math.huge
    for _, c in ipairs(self.cities) do
        local d2 = (c.x - cx)^2 + (c.y - cy)^2
        if d2 < bestDist then bestDist = d2; best = c end
    end
    return best
end

-- ─── Update (called by scheduler) ─────────────────────────────────────

function World:update(dt)
    self.time = self.time + dt
end

-- ─── Snapshot for save/load ────────────────────────────────────────────

function World:snapshot()
    return {
        width     = self.width,
        height    = self.height,
        seed      = self.seed,
        time      = self.time,
        cities    = self.cities,
        resources = self.resources,
    }
end

function World:restore(snap)
    if snap.seed and snap.seed ~= self.seed then
        self.seed = snap.seed
        _initPerm(self.seed)
        self:generate()
    end
    self.time      = snap.time or 0
    self.cities    = snap.cities or self.cities
    self.resources = snap.resources or self.resources
end

return World
