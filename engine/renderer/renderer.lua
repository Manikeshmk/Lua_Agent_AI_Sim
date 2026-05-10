-- engine/renderer/renderer.lua
-- LÖVE2D rendering pipeline.
-- Handles: camera transform, tile map, entity glyphs, overlays,
-- heatmaps, faction territory, AI debug overlays, and HUD.

local Config = require("engine.config")

local Renderer = {}
Renderer.__index = Renderer

-- Palette
local BIOME_COLORS = {
    ocean      = {0.10, 0.20, 0.55},
    beach      = {0.85, 0.82, 0.60},
    plains     = {0.50, 0.78, 0.35},
    forest     = {0.18, 0.52, 0.22},
    jungle     = {0.10, 0.42, 0.15},
    desert     = {0.90, 0.80, 0.40},
    tundra     = {0.80, 0.88, 0.95},
    mountain   = {0.55, 0.50, 0.45},
    snow       = {0.95, 0.97, 1.00},
    swamp      = {0.35, 0.42, 0.28},
    grassland  = {0.60, 0.85, 0.40},
}

local ENTITY_COLORS = {
    human    = {1.0, 0.85, 0.55},
    animal   = {0.70, 0.45, 0.20},
    building = {0.65, 0.65, 0.70},
    resource = {0.30, 0.85, 0.30},
}

function Renderer.new(world, ecs, agentMgr)
    local r = setmetatable({}, Renderer)
    r.world    = world
    r.ecs      = ecs
    r.agentMgr = agentMgr

    -- Camera state
    r.cam = { x = 0, y = 0, zoom = 1.0 }
    r.dragging  = false
    r.dragStart = { x = 0, y = 0 }

    -- Overlay toggles
    r.showHeatmap    = false
    r.showInfluence  = false
    r.showFactions   = false
    r.showGrid       = false
    r.showPaths      = false

    -- Heatmap canvas (regenerated each N frames)
    r.heatmapCanvas = nil
    r.heatDirty     = true
    r.heatTimer     = 0

    -- Selected entity
    r.selected = nil

    -- Font
    r.fontSmall  = love.graphics.newFont(10)
    r.fontMedium = love.graphics.newFont(13)
    local monoOk, monoFont = pcall(love.graphics.newFont, "data/fonts/mono.ttf", 11)
    r.fontMono   = monoOk and monoFont or r.fontSmall

    -- Faction colors (generated dynamically)
    r.factionColors = {}

    -- Tile canvas (static, rebuilt on world change)
    r.tileCanvas  = nil
    r.tilesDirty  = true

    return r
end

-- ─── Camera helpers ────────────────────────────────────────────────────

function Renderer:worldToScreen(wx, wy)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local ts = Config.TILE_SIZE * self.cam.zoom
    local sx = (wx - self.cam.x) * ts + sw / 2
    local sy = (wy - self.cam.y) * ts + sh / 2
    return sx, sy
end

function Renderer:screenToWorld(sx, sy)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local ts = Config.TILE_SIZE * self.cam.zoom
    local wx = (sx - sw / 2) / ts + self.cam.x
    local wy = (sy - sh / 2) / ts + self.cam.y
    return wx, wy
end

function Renderer:applyCamera()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local ts = Config.TILE_SIZE * self.cam.zoom
    love.graphics.translate(sw / 2, sh / 2)
    love.graphics.scale(ts, ts)
    love.graphics.translate(-self.cam.x, -self.cam.y)
end

-- ─── Draw entry point ──────────────────────────────────────────────────

function Renderer:draw(simTime, tick, paused)
    love.graphics.clear(0.05, 0.05, 0.08)

    love.graphics.push()
    self:applyCamera()

    self:_drawTiles()
    if self.showFactions   then self:_drawFactionOverlay()  end
    if self.showInfluence  then self:_drawInfluenceMap()    end
    if self.showHeatmap    then self:_drawHeatmap()         end
    if self.showGrid       then self:_drawGrid()            end
    self:_drawEntities()
    if self.showPaths      then self:_drawPaths()           end
    if self.selected       then self:_drawSelection()       end

    love.graphics.pop()

    self:_drawHUD(simTime, tick, paused)
    self:_drawMinimap()
end

-- ─── Tile rendering ────────────────────────────────────────────────────

function Renderer:_drawTiles()
    local world = self.world
    if not world then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local ts = Config.TILE_SIZE * self.cam.zoom

    -- Visible tile range
    local x0 = math.floor(self.cam.x - (sw / 2) / ts) - 1
    local y0 = math.floor(self.cam.y - (sh / 2) / ts) - 1
    local x1 = math.ceil(self.cam.x  + (sw / 2) / ts) + 1
    local y1 = math.ceil(self.cam.y  + (sh / 2) / ts) + 1

    x0 = math.max(0, x0)
    y0 = math.max(0, y0)
    x1 = math.min(world.width  - 1, x1)
    y1 = math.min(world.height - 1, y1)

    for ty = y0, y1 do
        for tx = x0, x1 do
            local tile  = world:getTile(tx, ty)
            if tile then
                local col = BIOME_COLORS[tile.biome] or {0.3, 0.3, 0.3}
                -- Shading: elevation darkens
                local shade = 0.6 + 0.4 * (tile.elevation or 0.5)
                love.graphics.setColor(col[1]*shade, col[2]*shade, col[3]*shade)
                love.graphics.rectangle("fill", tx, ty, 1, 1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- ─── Entity rendering ──────────────────────────────────────────────────

function Renderer:_drawEntities()
    if not self.ecs then return end
    local Comps = require("engine.ecs.components")
    local store = self.ecs._compStore

    local posStore = store["Position"]
    local aiStore  = store["AI"]
    local hpStore  = store["Health"]
    if not posStore then return end

    for id, pos in pairs(posStore) do
        if self.ecs._entities[id] then
            local ai = aiStore and aiStore[id]
            local col = ai and (ENTITY_COLORS[ai.type] or {1,1,1}) or {1,1,1}
            love.graphics.setColor(col[1], col[2], col[3], 0.9)

            local glyph = "@"
            if ai then
                if ai.type == "animal"   then glyph = "a"
                elseif ai.type == "building" then glyph = "#"
                elseif ai.type == "resource" then glyph = "r"
                end
            end

            -- Draw as a small filled circle (faster than text at high zoom)
            if self.cam.zoom >= 2.0 then
                love.graphics.setFont(self.fontSmall)
                love.graphics.print(glyph, pos.x - 0.3, pos.y - 0.4, 0, 1/Config.TILE_SIZE, 1/Config.TILE_SIZE)
            else
                love.graphics.circle("fill", pos.x + 0.5, pos.y + 0.5, 0.35)
            end

            -- Health bar
            if hpStore and hpStore[id] and self.cam.zoom >= 3.0 then
                local hp = hpStore[id]
                local ratio = hp.current / hp.max
                love.graphics.setColor(0.2, 0.8, 0.2, 0.7)
                love.graphics.rectangle("fill", pos.x, pos.y - 0.2, ratio, 0.12)
                love.graphics.setColor(0.8, 0.2, 0.2, 0.7)
                love.graphics.rectangle("fill", pos.x + ratio, pos.y - 0.2, 1 - ratio, 0.12)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- ─── Paths ─────────────────────────────────────────────────────────────

function Renderer:_drawPaths()
    local store = self.ecs._compStore
    local posStore = store["Position"]
    local pfStore  = store["Pathfinding"]
    if not posStore or not pfStore then return end

    love.graphics.setColor(0.9, 0.9, 0.2, 0.5)
    love.graphics.setLineWidth(0.1)
    for id, pf in pairs(pfStore) do
        if pf.path and #pf.path > 1 and posStore[id] then
            local p = posStore[id]
            love.graphics.line(p.x + 0.5, p.y + 0.5, pf.path[1].x + 0.5, pf.path[1].y + 0.5)
            for i = 1, #pf.path - 1 do
                love.graphics.line(
                    pf.path[i].x + 0.5, pf.path[i].y + 0.5,
                    pf.path[i+1].x + 0.5, pf.path[i+1].y + 0.5
                )
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- ─── Faction overlay ───────────────────────────────────────────────────

function Renderer:_drawFactionOverlay()
    local factions = self.world and self.world.factionMap
    if not factions then return end
    for ty = 0, self.world.height - 1 do
        for tx = 0, self.world.width - 1 do
            local fid = factions[ty * self.world.width + tx]
            if fid and fid > 0 then
                local col = self:_factionColor(fid)
                love.graphics.setColor(col[1], col[2], col[3], 0.25)
                love.graphics.rectangle("fill", tx, ty, 1, 1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function Renderer:_factionColor(id)
    if not self.factionColors[id] then
        math.randomseed(id * 1337)
        self.factionColors[id] = {math.random(), math.random(), math.random()}
    end
    return self.factionColors[id]
end

-- ─── Heatmap ───────────────────────────────────────────────────────────

function Renderer:_drawHeatmap()
    local agentMgr = self.agentMgr
    if not agentMgr then return end
    local density = agentMgr:getDensityMap()
    if not density then return end
    for ty = 0, self.world.height - 1 do
        for tx = 0, self.world.width - 1 do
            local v = (density[ty * self.world.width + tx] or 0) / 10
            v = math.min(v, 1)
            love.graphics.setColor(v, 0, 1 - v, 0.4)
            love.graphics.rectangle("fill", tx, ty, 1, 1)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- ─── Influence map ─────────────────────────────────────────────────────

function Renderer:_drawInfluenceMap()
    local im = self.world and self.world.influenceMap
    if not im then return end
    for ty = 0, self.world.height - 1 do
        for tx = 0, self.world.width - 1 do
            local v = im[ty * self.world.width + tx] or 0
            if v > 0 then
                love.graphics.setColor(0, v, 0, 0.3)
                love.graphics.rectangle("fill", tx, ty, 1, 1)
            elseif v < 0 then
                love.graphics.setColor(-v, 0, 0, 0.3)
                love.graphics.rectangle("fill", tx, ty, 1, 1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- ─── Grid ──────────────────────────────────────────────────────────────

function Renderer:_drawGrid()
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.setLineWidth(0.05)
    for x = 0, self.world.width do
        love.graphics.line(x, 0, x, self.world.height)
    end
    for y = 0, self.world.height do
        love.graphics.line(0, y, self.world.width, y)
    end
    love.graphics.setColor(1, 1, 1)
end

-- ─── Selection ─────────────────────────────────────────────────────────

function Renderer:_drawSelection()
    local pos = self.ecs:getComponent(self.selected, "Position")
    if not pos then return end
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.setLineWidth(0.08)
    love.graphics.rectangle("line", pos.x, pos.y, 1, 1)
    love.graphics.setColor(1, 1, 1)
end

-- ─── HUD ───────────────────────────────────────────────────────────────

function Renderer:_drawHUD(simTime, tick, paused)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 260, 56)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(self.fontMedium)

    local day   = math.floor(simTime / Config.DAY_LENGTH) + 1
    local hour  = math.floor((simTime % Config.DAY_LENGTH) / Config.DAY_LENGTH * 24)
    local agents = self.ecs:entityCount()
    local pauseStr = paused and " [PAUSED]" or ""

    love.graphics.print(
        string.format("Day %d  %02d:00  Tick %d%s", day, hour, tick, pauseStr), 6, 6)
    love.graphics.print(
        string.format("Entities: %d  Zoom: %.2f  FPS: %d", agents, self.cam.zoom,
            love.timer and love.timer.getFPS() or 0), 6, 26)

    -- Key hints
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(self.fontSmall)
    local hints = "SPACE=pause  →=step  F1=debug  F2=heat  F3=influence  F4=faction  F5=save  F9=load"
    love.graphics.print(hints, 4, love.graphics.getHeight() - 16)
    love.graphics.setColor(1, 1, 1)
end

-- ─── Minimap ───────────────────────────────────────────────────────────

function Renderer:_drawMinimap()
    if not self.world then return end
    local mw, mh = 160, 120
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local ox, oy = sw - mw - 8, sh - mh - 8

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", ox - 2, oy - 2, mw + 4, mh + 4)

    local scaleX = mw / self.world.width
    local scaleY = mh / self.world.height

    -- Sample world tiles (every 2nd tile for speed)
    for ty = 0, self.world.height - 1, 2 do
        for tx = 0, self.world.width - 1, 2 do
            local tile = self.world:getTile(tx, ty)
            if tile then
                local col = BIOME_COLORS[tile.biome] or {0.3,0.3,0.3}
                love.graphics.setColor(col[1], col[2], col[3])
                local px = ox + tx * scaleX
                local py = oy + ty * scaleY
                love.graphics.rectangle("fill", px, py, 2 * scaleX, 2 * scaleY)
            end
        end
    end

    -- Camera viewport rect
    local vs = Config.TILE_SIZE * self.cam.zoom
    local vw  = love.graphics.getWidth()  / vs * scaleX
    local vh  = love.graphics.getHeight() / vs * scaleY
    local vcx = ox + self.cam.x * scaleX - vw / 2
    local vcy = oy + self.cam.y * scaleY - vh / 2
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", vcx, vcy, vw, vh)
    love.graphics.setColor(1, 1, 1)
end

-- ─── Input ─────────────────────────────────────────────────────────────

function Renderer:keypressed(key)
    if key == "g" then self.showGrid    = not self.showGrid    end
    if key == "p" then self.showPaths   = not self.showPaths   end
end

function Renderer:mousepressed(x, y, button)
    if button == 2 then
        self.dragging  = true
        self.dragStart = { x = x, y = y, cx = self.cam.x, cy = self.cam.y }
    elseif button == 1 then
        self:_handleSelect(x, y)
    end
end

function Renderer:mousemoved(x, y, dx, dy)
    if self.dragging then
        local ts = Config.TILE_SIZE * self.cam.zoom
        self.cam.x = self.dragStart.cx - (x - self.dragStart.x) / ts
        self.cam.y = self.dragStart.cy - (y - self.dragStart.y) / ts
    end
end

function Renderer:wheelmoved(x, y)
    local step = Config.CAMERA_ZOOM_STEP
    self.cam.zoom = math.max(Config.CAMERA_ZOOM_MIN,
                    math.min(Config.CAMERA_ZOOM_MAX, self.cam.zoom + y * step))
end

function Renderer:_handleSelect(sx, sy)
    local wx, wy = self:screenToWorld(sx, sy)
    -- Find closest entity within 1 tile
    local best, bestDist = nil, 1.5
    local posStore = self.ecs._compStore["Position"]
    if posStore then
        for id, pos in pairs(posStore) do
            local d = math.sqrt((pos.x - wx)^2 + (pos.y - wy)^2)
            if d < bestDist then bestDist = d; best = id end
        end
    end
    self.selected = best
end

function Renderer:toggleHeatmap()    self.showHeatmap   = not self.showHeatmap   end
function Renderer:toggleInfluenceMap() self.showInfluence = not self.showInfluence end
function Renderer:toggleFactionOverlay() self.showFactions = not self.showFactions end

return Renderer
