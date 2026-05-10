-- engine/config.lua
-- Central configuration constants for the simulation engine.

local Config = {}

Config.VERSION         = "0.1.0"
Config.SEED            = 42

-- World dimensions (in tiles)
Config.WORLD_WIDTH     = 256
Config.WORLD_HEIGHT    = 256
Config.CHUNK_SIZE      = 16

-- Simulation timing
Config.MAX_DT          = 0.05   -- cap delta-time at 20 fps equivalent
Config.SIM_SPEED       = 1.0    -- simulation speed multiplier
Config.AUTOSAVE_INTERVAL = 18000 -- ticks between autosaves (~5 min at 60tps)

-- Agent population
Config.INITIAL_AGENTS  = 200
Config.MAX_AGENTS      = 5000

-- Rendering
Config.TILE_SIZE       = 8      -- pixels per tile at zoom=1
Config.CAMERA_ZOOM_MIN = 0.25
Config.CAMERA_ZOOM_MAX = 8.0
Config.CAMERA_ZOOM_STEP = 0.1

-- AI tuning
Config.AGENT_PERCEPTION_RADIUS = 12   -- tiles
Config.AGENT_MEMORY_SIZE       = 64   -- max remembered events
Config.PATHFIND_MAX_NODES      = 2048
Config.BT_UPDATE_BUDGET        = 0.002 -- seconds per frame for BT evaluation

-- Economy
Config.BASE_PRICE_VARIANCE = 0.15
Config.MARKET_TICK_INTERVAL = 60  -- seconds of sim-time

-- Day/Night cycle (in seconds of sim-time)
Config.DAY_LENGTH      = 600

-- Save directory
Config.SAVE_DIR        = "saves/"

return Config
