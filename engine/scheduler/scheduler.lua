-- engine/scheduler/scheduler.lua
-- Coroutine-based job scheduler.
-- Jobs have configurable priorities and per-tick budgets.
-- Supports one-shot tasks, repeating tasks, and coroutine tasks.

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    local s = setmetatable({}, Scheduler)
    s._jobs     = {}   -- name -> Job
    s._pending  = {}   -- list of one-shot coroutine tasks
    s._timer    = 0
    return s
end

-- Add a repeating job called every `interval` seconds of sim-time.
-- priority: lower = runs first (default 0)
function Scheduler:addJob(name, priority, fn, interval)
    self._jobs[name] = {
        name      = name,
        fn        = fn,
        priority  = priority or 0,
        interval  = interval or 0,
        timer     = 0,
        enabled   = true,
        calls     = 0,
        totalTime = 0,
    }
end

function Scheduler:removeJob(name)
    self._jobs[name] = nil
end

function Scheduler:enableJob(name, state)
    if self._jobs[name] then self._jobs[name].enabled = state end
end

-- Submit a one-shot coroutine task.
function Scheduler:submit(fn)
    local co = coroutine.create(fn)
    self._pending[#self._pending + 1] = co
end

function Scheduler:update(dt)
    self._timer = self._timer + dt

    -- Collect and sort active jobs
    local sorted = {}
    for _, job in pairs(self._jobs) do
        if job.enabled then sorted[#sorted + 1] = job end
    end
    table.sort(sorted, function(a, b) return a.priority < b.priority end)

    -- Run jobs whose interval has elapsed
    for _, job in ipairs(sorted) do
        job.timer = job.timer + dt
        local iv = job.interval
        if iv == 0 or job.timer >= iv then
            if iv > 0 then job.timer = job.timer - iv end
            local t0 = love and love.timer and love.timer.getTime() or os.clock()
            local ok, err = pcall(job.fn, dt)
            local t1 = love and love.timer and love.timer.getTime() or os.clock()
            job.totalTime = job.totalTime + (t1 - t0)
            job.calls     = job.calls + 1
            if not ok then
                print("[Scheduler] Job '" .. job.name .. "' error: " .. tostring(err))
            end
        end
    end

    -- Advance pending coroutines (one step each per frame)
    local stillPending = {}
    for _, co in ipairs(self._pending) do
        local ok, err = coroutine.resume(co, dt)
        if not ok then
            print("[Scheduler] Coroutine error: " .. tostring(err))
        elseif coroutine.status(co) ~= "dead" then
            stillPending[#stillPending + 1] = co
        end
    end
    self._pending = stillPending
end

function Scheduler:stats()
    local out = {}
    for name, job in pairs(self._jobs) do
        out[name] = {
            calls     = job.calls,
            avgMs     = job.calls > 0 and (job.totalTime / job.calls * 1000) or 0,
        }
    end
    return out
end

return Scheduler
