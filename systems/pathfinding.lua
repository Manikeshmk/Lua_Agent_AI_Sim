-- systems/pathfinding.lua
-- A* pathfinding on the tile grid.
-- Uses a binary-heap open list for performance.

local Config = require("engine.config")

local Pathfinding = {}

-- ─── Binary min-heap ───────────────────────────────────────────────────

local function heapNew() return { data = {}, size = 0 } end

local function heapPush(h, node)
    h.size = h.size + 1
    h.data[h.size] = node
    local i = h.size
    while i > 1 do
        local p = math.floor(i / 2)
        if h.data[p].f <= h.data[i].f then break end
        h.data[p], h.data[i] = h.data[i], h.data[p]
        i = p
    end
end

local function heapPop(h)
    if h.size == 0 then return nil end
    local top = h.data[1]
    h.data[1] = h.data[h.size]
    h.data[h.size] = nil
    h.size = h.size - 1
    local i = 1
    while true do
        local smallest = i
        local l, r = 2*i, 2*i+1
        if l <= h.size and h.data[l].f < h.data[smallest].f then smallest = l end
        if r <= h.size and h.data[r].f < h.data[smallest].f then smallest = r end
        if smallest == i then break end
        h.data[i], h.data[smallest] = h.data[smallest], h.data[i]
        i = smallest
    end
    return top
end

-- ─── A* ────────────────────────────────────────────────────────────────

local DIRS = {
    { 0, -1, 1 }, { 0, 1, 1 }, { -1, 0, 1 }, { 1, 0, 1 },
    { -1, -1, 1.414 }, { 1, -1, 1.414 }, { -1, 1, 1.414 }, { 1, 1, 1.414 },
}

function Pathfinding.findPath(world, sx, sy, gx, gy, maxNodes)
    maxNodes = maxNodes or Config.PATHFIND_MAX_NODES

    if not world:isWalkable(gx, gy) then return {} end

    local function key(x, y) return y * 65536 + x end
    local function heuristic(x, y) return math.abs(x - gx) + math.abs(y - gy) end

    local open   = heapNew()
    local closed = {}
    local gScore = {}
    local parent = {}
    local nodesExpanded = 0

    local sk = key(sx, sy)
    gScore[sk] = 0
    heapPush(open, { x = sx, y = sy, f = heuristic(sx, sy), k = sk })

    while open.size > 0 and nodesExpanded < maxNodes do
        local current = heapPop(open)
        local ck = current.k

        if closed[ck] then goto continue end
        closed[ck] = true
        nodesExpanded = nodesExpanded + 1

        -- Reached goal?
        if current.x == gx and current.y == gy then
            -- Reconstruct path
            local path = {}
            local pk = ck
            while pk do
                local py = math.floor(pk / 65536)
                local px = pk - py * 65536
                table.insert(path, 1, { x = px + 0.5, y = py + 0.5 })
                pk = parent[pk]
            end
            return path
        end

        local cg = gScore[ck]
        for _, dir in ipairs(DIRS) do
            local nx, ny = current.x + dir[1], current.y + dir[2]
            if world:isWalkable(nx, ny) then
                local nk = key(nx, ny)
                if not closed[nk] then
                    local tile = world:getTile(nx, ny)
                    local moveCost = dir[3]
                    -- Terrain cost modifier
                    if tile then
                        if tile.biome == "swamp" then moveCost = moveCost * 2
                        elseif tile.biome == "forest" then moveCost = moveCost * 1.3
                        elseif tile.biome == "jungle" then moveCost = moveCost * 1.5
                        elseif tile.biome == "desert" then moveCost = moveCost * 1.2 end
                    end
                    local newG = cg + moveCost
                    if not gScore[nk] or newG < gScore[nk] then
                        gScore[nk] = newG
                        parent[nk] = ck
                        local f = newG + heuristic(nx, ny)
                        heapPush(open, { x = nx, y = ny, f = f, k = nk })
                    end
                end
            end
        end

        ::continue::
    end

    return {}  -- No path found
end

-- ─── Convenience: find path and assign to entity ───────────────────────

function Pathfinding.assignPath(entityId, ecs, world, gx, gy)
    local pos = ecs:getComponent(entityId, "Position")
    local pf  = ecs:getComponent(entityId, "Pathfinding")
    if not pos or not pf then return false end

    local path = Pathfinding.findPath(world, math.floor(pos.x), math.floor(pos.y), gx, gy)
    pf.path = path
    pf.pathIndex = 1
    pf.recompute = false
    pf.target = { x = gx, y = gy }
    return #path > 0
end

return Pathfinding
