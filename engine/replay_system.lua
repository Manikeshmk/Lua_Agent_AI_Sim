-- engine/replay_system.lua
-- Deterministic replay: records all simulation events and agent actions
-- for frame-perfect playback, debugging, and experiment reproducibility.

local Config = require("engine.config")

local ReplaySystem = {}
ReplaySystem.__index = ReplaySystem

function ReplaySystem.new()
    local r = setmetatable({}, ReplaySystem)
    r.recording  = false
    r.playing    = false
    r.frames     = {}
    r.frameIndex = 0
    r.seed       = Config.SEED
    r.metadata   = {
        version = Config.VERSION,
        seed    = Config.SEED,
        date    = os.date("%Y-%m-%d %H:%M:%S"),
    }
    return r
end

-- ─── Recording ─────────────────────────────────────────────────────────

function ReplaySystem:startRecording()
    self.recording = true
    self.playing   = false
    self.frames    = {}
    self.frameIndex = 0
    self.metadata.date = os.date("%Y-%m-%d %H:%M:%S")
    print("[Replay] Recording started.")
end

function ReplaySystem:stopRecording()
    self.recording = false
    print("[Replay] Recording stopped. " .. #self.frames .. " frames captured.")
end

function ReplaySystem:recordFrame(tick, events, agentActions)
    if not self.recording then return end
    self.frames[#self.frames + 1] = {
        tick    = tick,
        events  = events or {},
        actions = agentActions or {},
    }
end

-- ─── Playback ──────────────────────────────────────────────────────────

function ReplaySystem:startPlayback()
    if #self.frames == 0 then
        print("[Replay] No frames to play.")
        return false
    end
    self.playing    = true
    self.recording  = false
    self.frameIndex = 1
    print("[Replay] Playback started. " .. #self.frames .. " frames.")
    return true
end

function ReplaySystem:stopPlayback()
    self.playing = false
    print("[Replay] Playback stopped at frame " .. self.frameIndex)
end

function ReplaySystem:getNextFrame()
    if not self.playing then return nil end
    if self.frameIndex > #self.frames then
        self:stopPlayback()
        return nil
    end
    local frame = self.frames[self.frameIndex]
    self.frameIndex = self.frameIndex + 1
    return frame
end

function ReplaySystem:seekToFrame(idx)
    self.frameIndex = math.max(1, math.min(#self.frames, idx))
end

function ReplaySystem:getProgress()
    if #self.frames == 0 then return 0 end
    return self.frameIndex / #self.frames
end

-- ─── Save / Load replay ───────────────────────────────────────────────

function ReplaySystem:save(name)
    local path = Config.SAVE_DIR .. "replay_" .. name .. ".lua"
    local data = {
        metadata = self.metadata,
        frames   = self.frames,
    }
    -- Use simple serialization
    local parts = { "return {\n  metadata = {\n" }
    for k, v in pairs(data.metadata) do
        parts[#parts + 1] = string.format("    %s = %q,\n", k, tostring(v))
    end
    parts[#parts + 1] = "  },\n  frameCount = " .. #data.frames .. ",\n"
    parts[#parts + 1] = "  -- Frame data omitted for size; use binary format for full replays\n"
    parts[#parts + 1] = "}\n"

    local ok, err = pcall(function()
        love.filesystem.createDirectory(Config.SAVE_DIR)
        love.filesystem.write(path, table.concat(parts))
    end)

    if ok then
        print("[Replay] Saved to " .. path)
    else
        print("[Replay] Save failed: " .. tostring(err))
    end
end

function ReplaySystem:getFrameCount()
    return #self.frames
end

function ReplaySystem:isRecording()
    return self.recording
end

function ReplaySystem:isPlaying()
    return self.playing
end

return ReplaySystem
