-- tools/debugger/debugger.lua
-- Live debugging overlay: entity inspector, AI decision viewer,
-- event timeline, memory visualization.

local Debugger = {}
Debugger.__index = Debugger

function Debugger.new(ecs, agentMgr, eventBus)
    local d = setmetatable({}, Debugger)
    d.ecs      = ecs
    d.agentMgr = agentMgr
    d.eventBus = eventBus
    d.enabled  = false
    d.selected = nil
    d.panel    = "inspector"  -- inspector | ai | memory | timeline | factions
    d.eventLog = {}
    d.maxEvents = 200
    d.scrollY   = 0

    -- Register event listener for logging
    if eventBus then
        eventBus.on("*", function(data)
            -- Catch-all won't work with current impl, so we do specific
        end)
        local channels = {
            "combat:hit", "combat:kill", "combat:retreat",
            "faction:war_declared", "faction:alliance_formed",
            "sim:started", "sim:shutdown",
        }
        for _, ch in ipairs(channels) do
            eventBus.on(ch, function(data)
                d:logEvent(ch, data)
            end)
        end
    end

    return d
end

function Debugger:toggle()
    self.enabled = not self.enabled
end

function Debugger:logEvent(channel, data)
    self.eventLog[#self.eventLog + 1] = {
        channel = channel,
        data    = data,
        time    = love and love.timer and love.timer.getTime() or 0,
    }
    if #self.eventLog > self.maxEvents then
        table.remove(self.eventLog, 1)
    end
end

function Debugger:update(dt)
    if not self.enabled then return end
end

function Debugger:draw()
    if not self.enabled then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local pw = 320  -- panel width

    -- Background panel
    love.graphics.setColor(0.08, 0.08, 0.12, 0.92)
    love.graphics.rectangle("fill", sw - pw, 0, pw, sh)

    -- Tab bar
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", sw - pw, 0, pw, 28)

    local tabs = { "inspector", "ai", "memory", "timeline", "factions" }
    local tabW = pw / #tabs
    for i, tab in ipairs(tabs) do
        local x = sw - pw + (i-1) * tabW
        if self.panel == tab then
            love.graphics.setColor(0.3, 0.5, 0.9)
            love.graphics.rectangle("fill", x, 0, tabW, 28)
        end
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(tab, x + 6, 6)
    end

    -- Panel content
    local x0 = sw - pw + 8
    local y0 = 36

    if self.panel == "inspector" then
        self:_drawInspector(x0, y0, pw - 16)
    elseif self.panel == "ai" then
        self:_drawAIPanel(x0, y0, pw - 16)
    elseif self.panel == "memory" then
        self:_drawMemoryPanel(x0, y0, pw - 16)
    elseif self.panel == "timeline" then
        self:_drawTimeline(x0, y0, pw - 16)
    elseif self.panel == "factions" then
        self:_drawFactionsPanel(x0, y0, pw - 16)
    end

    love.graphics.setColor(1, 1, 1)
end

function Debugger:_drawInspector(x, y, w)
    local id = self.selected
    if not id then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("Click an entity to inspect", x, y)
        return
    end

    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.print("Entity #" .. id, x, y)
    y = y + 20

    local compTypes = { "Position", "Health", "Hunger", "Thirst", "Energy",
        "AI", "Combat", "Emotion", "Profession", "Inventory", "Relationships" }

    for _, ct in ipairs(compTypes) do
        local comp = self.ecs:getComponent(id, ct)
        if comp then
            love.graphics.setColor(0.4, 0.8, 1.0)
            love.graphics.print(ct .. ":", x, y)
            y = y + 16
            love.graphics.setColor(0.8, 0.8, 0.8)
            for k, v in pairs(comp) do
                if type(v) ~= "table" and type(v) ~= "function" then
                    love.graphics.print("  " .. k .. " = " .. tostring(v), x, y)
                    y = y + 14
                    if y > love.graphics.getHeight() - 20 then return end
                end
            end
        end
    end
end

function Debugger:_drawAIPanel(x, y, w)
    local id = self.selected
    if not id then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("Select an agent to view AI state", x, y)
        return
    end

    local ai = self.ecs:getComponent(id, "AI")
    local goals = self.ecs:getComponent(id, "Goals")
    if not ai then return end

    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.print("AI State: " .. (ai.state or "?"), x, y)
    y = y + 20

    -- Utility scores
    love.graphics.setColor(0.4, 0.8, 1.0)
    love.graphics.print("Utility Scores:", x, y)
    y = y + 16

    if ai.utilScores then
        local sorted = {}
        for name, score in pairs(ai.utilScores) do
            sorted[#sorted + 1] = { name = name, score = score }
        end
        table.sort(sorted, function(a, b) return a.score > b.score end)

        for _, entry in ipairs(sorted) do
            local barW = entry.score * (w - 100)
            love.graphics.setColor(0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", x + 80, y, w - 100, 12)
            love.graphics.setColor(0.3, 0.7, 0.3)
            love.graphics.rectangle("fill", x + 80, y, barW, 12)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print(entry.name, x, y)
            love.graphics.print(string.format("%.2f", entry.score), x + 80 + w - 95, y)
            y = y + 16
        end
    end

    -- Personality
    y = y + 8
    love.graphics.setColor(0.4, 0.8, 1.0)
    love.graphics.print("Personality:", x, y)
    y = y + 16
    if ai.personality then
        for trait, val in pairs(ai.personality) do
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(string.format("  %s: %.2f", trait, val), x, y)
            y = y + 14
        end
    end
end

function Debugger:_drawMemoryPanel(x, y, w)
    local id = self.selected
    if not id then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("Select an agent to view memory", x, y)
        return
    end

    local mem = self.ecs:getComponent(id, "Memory")
    if not mem then return end

    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.print("Known entities: " .. (function()
        local n = 0; for _ in pairs(mem.knowledge) do n = n + 1 end; return n
    end)(), x, y)
    y = y + 20

    love.graphics.setColor(0.4, 0.8, 1.0)
    love.graphics.print("Recent Events:", x, y)
    y = y + 16

    for i = #mem.events, math.max(1, #mem.events - 15), -1 do
        local ev = mem.events[i]
        if ev then
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(string.format("[%s] at (%s,%s)",
                ev.type or "?",
                ev.x and string.format("%.0f", ev.x) or "?",
                ev.y and string.format("%.0f", ev.y) or "?"), x, y)
            y = y + 14
            if y > love.graphics.getHeight() - 20 then return end
        end
    end
end

function Debugger:_drawTimeline(x, y, w)
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.print("Event Timeline (" .. #self.eventLog .. " events)", x, y)
    y = y + 20

    for i = #self.eventLog, math.max(1, #self.eventLog - 25), -1 do
        local ev = self.eventLog[i]
        love.graphics.setColor(0.5, 0.8, 1.0)
        love.graphics.print(string.format("%.1f", ev.time), x, y)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(ev.channel, x + 50, y)
        y = y + 14
        if y > love.graphics.getHeight() - 20 then return end
    end
end

function Debugger:_drawFactionsPanel(x, y, w)
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.print("Factions", x, y)
    y = y + 20
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("(faction data shown here)", x, y)
end

-- ─── Input ─────────────────────────────────────────────────────────────

function Debugger:keypressed(key)
    if not self.enabled then return end
    if key == "tab" then
        local tabs = { "inspector", "ai", "memory", "timeline", "factions" }
        for i, t in ipairs(tabs) do
            if t == self.panel then
                self.panel = tabs[(i % #tabs) + 1]
                break
            end
        end
    end
end

function Debugger:mousepressed(x, y, button)
    if not self.enabled then return end
    local sw = love.graphics.getWidth()
    local pw = 320
    -- Tab clicks
    if y < 28 and x > sw - pw then
        local tabs = { "inspector", "ai", "memory", "timeline", "factions" }
        local tabW = pw / #tabs
        local idx = math.floor((x - (sw - pw)) / tabW) + 1
        if tabs[idx] then self.panel = tabs[idx] end
    end
end

function Debugger:setSelected(id)
    self.selected = id
end

return Debugger
