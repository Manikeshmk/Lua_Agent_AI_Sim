-- tools/profiler/profiler.lua
-- Frame-level performance profiler with HUD overlay.

local Profiler = {}
Profiler.__index = Profiler

function Profiler.new()
    local p = setmetatable({}, Profiler)
    p._sections = {}   -- name -> { startTime, totalTime, calls, history }
    p._showHUD  = true
    p._frameHistory = {}
    p._maxHistory = 120
    return p
end

function Profiler:begin(name)
    if not self._sections[name] then
        self._sections[name] = { start = 0, total = 0, calls = 0, history = {}, avg = 0 }
    end
    self._sections[name].start = love.timer.getTime()
end

function Profiler:finish(name)
    local s = self._sections[name]
    if not s then return end
    local elapsed = love.timer.getTime() - s.start
    s.total = s.total + elapsed
    s.calls = s.calls + 1

    s.history[#s.history + 1] = elapsed * 1000
    if #s.history > self._maxHistory then table.remove(s.history, 1) end

    -- Running average
    local sum = 0
    for _, v in ipairs(s.history) do sum = sum + v end
    s.avg = sum / #s.history
end

function Profiler:drawHUD()
    if not self._showHUD then return end

    local y = 60
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, y - 4, 220, 16 * (self:_sectionCount() + 1) + 8)

    love.graphics.setColor(0.9, 0.9, 0.3)
    love.graphics.print("Profiler", 6, y)
    y = y + 16

    local sorted = {}
    for name, s in pairs(self._sections) do
        sorted[#sorted + 1] = { name = name, avg = s.avg }
    end
    table.sort(sorted, function(a, b) return a.avg > b.avg end)

    for _, entry in ipairs(sorted) do
        local col = entry.avg > 2 and {1, 0.3, 0.3} or entry.avg > 1 and {1, 0.8, 0.3} or {0.5, 0.9, 0.5}
        love.graphics.setColor(col[1], col[2], col[3])
        love.graphics.print(string.format("%-14s %6.2f ms", entry.name, entry.avg), 6, y)
        y = y + 14
    end

    love.graphics.setColor(1, 1, 1)
end

function Profiler:toggleHUD()
    self._showHUD = not self._showHUD
end

function Profiler:_sectionCount()
    local n = 0
    for _ in pairs(self._sections) do n = n + 1 end
    return n
end

function Profiler:getStats()
    local stats = {}
    for name, s in pairs(self._sections) do
        stats[name] = { avgMs = s.avg, totalMs = s.total * 1000, calls = s.calls }
    end
    return stats
end

function Profiler:reset()
    self._sections = {}
end

return Profiler
