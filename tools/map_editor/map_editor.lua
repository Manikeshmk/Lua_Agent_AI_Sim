-- tools/map_editor/map_editor.lua
-- Simple in-game map editor for placing tiles, resources, and buildings.

local MapEditor = {}
MapEditor.__index = MapEditor

function MapEditor.new(world, renderer)
    local e = setmetatable({}, MapEditor)
    e.world    = world
    e.renderer = renderer
    e.enabled  = false
    e.brush    = "biome"     -- biome | resource | building
    e.brushValue = "plains"
    e.brushSize  = 1
    return e
end

function MapEditor:toggle() self.enabled = not self.enabled end

function MapEditor:setBrush(brush, value)
    self.brush = brush
    self.brushValue = value
end

function MapEditor:paint(wx, wy)
    if not self.enabled then return end
    local r = self.brushSize
    for dy = -r, r do
        for dx = -r, r do
            local tx = math.floor(wx) + dx
            local ty = math.floor(wy) + dy
            local tile = self.world:getTile(tx, ty)
            if tile then
                if self.brush == "biome" then
                    tile.biome = self.brushValue
                    tile.walkable = self.brushValue ~= "ocean" and self.brushValue ~= "mountain"
                elseif self.brush == "resource" then
                    tile.resource = self.brushValue
                elseif self.brush == "building" then
                    tile.building = self.brushValue
                end
            end
        end
    end
end

function MapEditor:draw()
    if not self.enabled then return end
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 50, 180, 80)
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.print("Map Editor", 6, 54)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Brush: " .. self.brush, 6, 70)
    love.graphics.print("Value: " .. tostring(self.brushValue), 6, 84)
    love.graphics.print("Size: " .. self.brushSize, 6, 98)
    love.graphics.setColor(1, 1, 1)
end

return MapEditor
