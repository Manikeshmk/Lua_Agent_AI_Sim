-- engine/save_system.lua
-- Persistent save / load via Lua table serialization.
-- Snapshots the ECS state, world chunk data, agent memories,
-- economy state, and faction state into a single file.

local SaveSystem = {}

local Config = require("engine.config")

-- Simple recursive table serializer (no external deps).
local function serialize(val, indent)
    indent = indent or ""
    local t = type(val)
    if t == "number" then
        return tostring(val)
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local parts = {}
        local nextIndent = indent .. "  "
        -- array part
        local isArray = (#val > 0)
        if isArray then
            for _, v in ipairs(val) do
                parts[#parts + 1] = nextIndent .. serialize(v, nextIndent)
            end
        else
            for k, v in pairs(val) do
                local key
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key = k
                else
                    key = "[" .. serialize(k) .. "]"
                end
                parts[#parts + 1] = nextIndent .. key .. " = " .. serialize(v, nextIndent)
            end
        end
        if #parts == 0 then return "{}" end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    else
        return "nil"
    end
end

local function deserialize(str)
    local fn, err = load("return " .. str)
    if not fn then error("SaveSystem: deserialize error: " .. tostring(err)) end
    return fn()
end

function SaveSystem.save(name, sim)
    local path = Config.SAVE_DIR .. name .. ".lua"

    local snapshot = {
        version = Config.VERSION,
        tick    = sim.tick,
        time    = sim.time,
        seed    = Config.SEED,
        world   = sim.world and sim.world:snapshot() or {},
        agents  = sim.agentMgr and sim.agentMgr:snapshot() or {},
        economy = sim.economy and sim.economy:snapshot() or {},
        factions = sim.factions and sim.factions:snapshot() or {},
        weather  = sim.weather and sim.weather:snapshot() or {},
    }

    local ok, info = pcall(function()
        love.filesystem.createDirectory(Config.SAVE_DIR)
        local data = "-- LuaAgentSim save file\nreturn " .. serialize(snapshot)
        love.filesystem.write(path, data)
    end)

    if ok then
        print("[SaveSystem] Saved: " .. path)
    else
        print("[SaveSystem] Save failed: " .. tostring(info))
    end
end

function SaveSystem.load(name, sim)
    local path = Config.SAVE_DIR .. name .. ".lua"
    local data, err = love.filesystem.read(path)
    if not data then
        print("[SaveSystem] Load failed: " .. tostring(err))
        return false
    end

    local ok, snapshot = pcall(deserialize, data)
    if not ok then
        print("[SaveSystem] Deserialize failed: " .. tostring(snapshot))
        return false
    end

    sim.tick = snapshot.tick or 0
    sim.time = snapshot.time or 0
    if sim.world   and snapshot.world   then sim.world:restore(snapshot.world)     end
    if sim.agentMgr and snapshot.agents then sim.agentMgr:restore(snapshot.agents) end
    if sim.economy and snapshot.economy then sim.economy:restore(snapshot.economy) end
    if sim.factions and snapshot.factions then sim.factions:restore(snapshot.factions) end
    if sim.weather and snapshot.weather  then sim.weather:restore(snapshot.weather)  end

    print("[SaveSystem] Loaded: " .. path .. " (tick=" .. tostring(sim.tick) .. ")")
    return true
end

function SaveSystem.listSaves()
    local items = love.filesystem.getDirectoryItems(Config.SAVE_DIR)
    local saves = {}
    for _, f in ipairs(items or {}) do
        if f:match("%.lua$") then saves[#saves + 1] = f:gsub("%.lua$", "") end
    end
    return saves
end

return SaveSystem
