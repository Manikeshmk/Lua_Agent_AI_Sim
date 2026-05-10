-- engine/utils.lua
-- Common utility functions used across the engine.

local Utils = {}

-- ─── Math ──────────────────────────────────────────────────────────────

function Utils.clamp(val, lo, hi)
    return math.max(lo, math.min(hi, val))
end

function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.inverseLerp(a, b, val)
    if a == b then return 0 end
    return (val - a) / (b - a)
end

function Utils.smoothstep(edge0, edge1, x)
    x = Utils.clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return x * x * (3 - 2 * x)
end

function Utils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx*dx + dy*dy)
end

function Utils.distanceSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx*dx + dy*dy
end

function Utils.normalize(x, y)
    local len = math.sqrt(x*x + y*y)
    if len == 0 then return 0, 0 end
    return x / len, y / len
end

function Utils.angleBetween(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

function Utils.randomInRange(lo, hi)
    return lo + math.random() * (hi - lo)
end

function Utils.randomSign()
    return math.random() < 0.5 and -1 or 1
end

-- ─── Table helpers ─────────────────────────────────────────────────────

function Utils.shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

function Utils.deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[Utils.deepCopy(k)] = Utils.deepCopy(v)
    end
    return setmetatable(copy, getmetatable(t))
end

function Utils.tableLength(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function Utils.tableContains(t, val)
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

function Utils.tableKeys(t)
    local keys = {}
    for k, _ in pairs(t) do keys[#keys + 1] = k end
    return keys
end

function Utils.tableShuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function Utils.weightedRandom(weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local r = math.random() * total
    local cumulative = 0
    for i, w in ipairs(weights) do
        cumulative = cumulative + w
        if r <= cumulative then return i end
    end
    return #weights
end

-- ─── String helpers ────────────────────────────────────────────────────

function Utils.split(str, sep)
    sep = sep or ","
    local parts = {}
    for part in str:gmatch("[^" .. sep .. "]+") do
        parts[#parts + 1] = part
    end
    return parts
end

function Utils.trim(str)
    return str:match("^%s*(.-)%s*$")
end

function Utils.startsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

-- ─── Color helpers ─────────────────────────────────────────────────────

function Utils.hsvToRgb(h, s, v)
    if s == 0 then return v, v, v end
    h = h * 6
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

-- ─── Time formatting ──────────────────────────────────────────────────

function Utils.formatTime(seconds)
    local hours   = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs    = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

function Utils.formatNumber(n)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then return string.format("%.1fK", n / 1000)
    else return tostring(math.floor(n)) end
end

return Utils
