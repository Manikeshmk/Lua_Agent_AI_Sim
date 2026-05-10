-- simulation/world/chunk_loader.lua
-- Chunk loading/unloading manager.
-- Determines which chunks need to be active based on camera position
-- and active agent distribution. Supports deferred loading.

local Config = require("engine.config")

local ChunkLoader = {}
ChunkLoader.__index = ChunkLoader

function ChunkLoader.new(world)
    local c = setmetatable({}, ChunkLoader)
    c.world    = world
    c.size     = Config.CHUNK_SIZE
    c.active   = {}      -- "cx,cy" -> true
    c.loadQueue   = {}   -- list of {cx, cy} to load
    c.unloadQueue = {}   -- list of {cx, cy} to unload
    c.loadRadius  = 3    -- chunks around camera
    c.maxLoadsPerFrame = 2
    return c
end

function ChunkLoader:_key(cx, cy) return cx .. "," .. cy end

function ChunkLoader:update(cameraX, cameraY, dt)
    -- Determine camera chunk
    local ccx = math.floor(cameraX / self.size)
    local ccy = math.floor(cameraY / self.size)

    -- Mark chunks that should be active
    local needed = {}
    for dy = -self.loadRadius, self.loadRadius do
        for dx = -self.loadRadius, self.loadRadius do
            local cx = ccx + dx
            local cy = ccy + dy
            local key = self:_key(cx, cy)
            needed[key] = true
            if not self.active[key] then
                self.loadQueue[#self.loadQueue + 1] = { cx = cx, cy = cy, key = key }
            end
        end
    end

    -- Mark chunks to unload
    for key, _ in pairs(self.active) do
        if not needed[key] then
            self.unloadQueue[#self.unloadQueue + 1] = key
        end
    end

    -- Process loads
    local loaded = 0
    while #self.loadQueue > 0 and loaded < self.maxLoadsPerFrame do
        local chunk = table.remove(self.loadQueue, 1)
        self:_loadChunk(chunk.cx, chunk.cy)
        self.active[chunk.key] = true
        loaded = loaded + 1
    end

    -- Process unloads
    for _, key in ipairs(self.unloadQueue) do
        self.active[key] = nil
    end
    self.unloadQueue = {}
end

function ChunkLoader:_loadChunk(cx, cy)
    -- Chunk data is already in world.tiles; this marks the chunk as "active"
    -- In a full implementation, this would load from disk/generate on demand
    local key = self:_key(cx, cy)
    if self.world.chunks then
        self.world.chunks[key] = self.world.chunks[key] or { loaded = true, dirty = false }
        self.world.chunks[key].loaded = true
    end
end

function ChunkLoader:isChunkActive(cx, cy)
    return self.active[self:_key(cx, cy)] == true
end

function ChunkLoader:getActiveChunkCount()
    local n = 0
    for _ in pairs(self.active) do n = n + 1 end
    return n
end

function ChunkLoader:isTileInActiveChunk(x, y)
    local cx = math.floor(x / self.size)
    local cy = math.floor(y / self.size)
    return self:isChunkActive(cx, cy)
end

return ChunkLoader
