-- simulation/world/spatial_grid.lua
-- Uniform spatial partitioning grid for fast neighbor queries.
-- Entities register their position; queries return all entities
-- within a given radius using cell-based culling.

local SpatialGrid = {}
SpatialGrid.__index = SpatialGrid

function SpatialGrid.new(cellSize)
    local g = setmetatable({}, SpatialGrid)
    g.cellSize = cellSize or 8
    g._cells   = {}  -- "cx,cy" -> { entityId = true }
    return g
end

function SpatialGrid:_key(cx, cy)
    return cx .. "," .. cy
end

function SpatialGrid:_cellOf(x, y)
    return math.floor(x / self.cellSize), math.floor(y / self.cellSize)
end

function SpatialGrid:insert(id, x, y)
    local cx, cy = self:_cellOf(x, y)
    local key = self:_key(cx, cy)
    if not self._cells[key] then self._cells[key] = {} end
    self._cells[key][id] = true
end

function SpatialGrid:remove(id, x, y)
    local cx, cy = self:_cellOf(x, y)
    local key = self:_key(cx, cy)
    if self._cells[key] then
        self._cells[key][id] = nil
    end
end

function SpatialGrid:move(id, oldX, oldY, newX, newY)
    local ocx, ocy = self:_cellOf(oldX, oldY)
    local ncx, ncy = self:_cellOf(newX, newY)
    if ocx ~= ncx or ocy ~= ncy then
        self:remove(id, oldX, oldY)
        self:insert(id, newX, newY)
    end
end

function SpatialGrid:queryRadius(x, y, radius)
    local results = {}
    local r = math.ceil(radius / self.cellSize)
    local cx0, cy0 = self:_cellOf(x, y)
    for cy = cy0 - r, cy0 + r do
        for cx = cx0 - r, cx0 + r do
            local key = self:_key(cx, cy)
            local cell = self._cells[key]
            if cell then
                for id, _ in pairs(cell) do
                    results[#results + 1] = id
                end
            end
        end
    end
    return results
end

function SpatialGrid:queryRect(x0, y0, x1, y1)
    local results = {}
    local cx0, cy0 = self:_cellOf(x0, y0)
    local cx1, cy1 = self:_cellOf(x1, y1)
    for cy = cy0, cy1 do
        for cx = cx0, cx1 do
            local key = self:_key(cx, cy)
            local cell = self._cells[key]
            if cell then
                for id, _ in pairs(cell) do
                    results[#results + 1] = id
                end
            end
        end
    end
    return results
end

function SpatialGrid:clear()
    self._cells = {}
end

function SpatialGrid:entityCount()
    local n = 0
    for _, cell in pairs(self._cells) do
        for _ in pairs(cell) do n = n + 1 end
    end
    return n
end

return SpatialGrid
