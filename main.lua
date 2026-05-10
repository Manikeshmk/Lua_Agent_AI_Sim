-- main.lua
-- LuaAgentSim — LÖVE2D entry point
-- Bootstraps all engine subsystems and hands control to the simulation loop.

local SimConfig  = require("engine.config")
local EventBus   = require("engine.events.event_bus")
local Scheduler  = require("engine.scheduler.scheduler")
local ECS        = require("engine.ecs.world")
local Renderer   = require("engine.renderer.renderer")
local World      = require("simulation.world.world")
local AgentMgr   = require("agents.agent_manager")
local Economy    = require("simulation.economy.economy")
local Factions   = require("simulation.factions.factions")
local Weather    = require("simulation.weather.weather")
local Debugger   = require("tools.debugger.debugger")
local Profiler   = require("tools.profiler.profiler")
local SaveSystem = require("engine.save_system")
local ModLoader  = require("engine.mod_loader")

local sim = {
    ecs        = nil,
    world      = nil,
    agentMgr   = nil,
    renderer   = nil,
    scheduler  = nil,
    economy    = nil,
    factions   = nil,
    weather    = nil,
    debugger   = nil,
    profiler   = nil,
    running    = false,
    paused     = false,
    stepOnce   = false,
    tick       = 0,
    time       = 0,
}

function love.load()
    math.randomseed(SimConfig.SEED)

    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("LuaAgentSim v" .. SimConfig.VERSION)

    -- Core engine
    EventBus.init()
    sim.ecs       = ECS.new()
    sim.scheduler = Scheduler.new()
    sim.profiler  = Profiler.new()

    -- World
    sim.world = World.new(SimConfig.WORLD_WIDTH, SimConfig.WORLD_HEIGHT, SimConfig.SEED)
    sim.world:generate()

    -- Simulation subsystems
    sim.weather  = Weather.new(sim.world)
    sim.economy  = Economy.new(sim.world, sim.ecs)
    sim.factions = Factions.new(sim.ecs, EventBus)

    -- Agent manager
    sim.agentMgr = AgentMgr.new(sim.ecs, sim.world, EventBus, sim.scheduler)
    sim.agentMgr:spawnInitialPopulation(SimConfig.INITIAL_AGENTS)

    -- Renderer
    sim.renderer = Renderer.new(sim.world, sim.ecs, sim.agentMgr)

    -- Debug tools
    sim.debugger = Debugger.new(sim.ecs, sim.agentMgr, EventBus)

    -- Load mods
    ModLoader.loadAll("mods", {
        ecs      = sim.ecs,
        world    = sim.world,
        eventBus = EventBus,
        economy  = sim.economy,
        factions = sim.factions,
    })

    -- Register scheduled jobs
    sim.scheduler:addJob("world_update",   60,  function(dt) sim.world:update(dt) end)
    sim.scheduler:addJob("weather_update", 30,  function(dt) sim.weather:update(dt) end)
    sim.scheduler:addJob("economy_tick",   10,  function(dt) sim.economy:tick(dt) end)
    sim.scheduler:addJob("faction_tick",   5,   function(dt) sim.factions:tick(dt) end)
    sim.scheduler:addJob("agent_batch",    120, function(dt) sim.agentMgr:batchUpdate(dt) end)
    sim.scheduler:addJob("save_autosave",  1,   function(dt)
        if sim.tick % SimConfig.AUTOSAVE_INTERVAL == 0 and sim.tick > 0 then
            SaveSystem.save("autosave", sim)
        end
    end)

    sim.running = true
    EventBus.emit("sim:started", { tick = 0 })
end

function love.update(dt)
    if not sim.running then return end
    if sim.paused and not sim.stepOnce then return end

    sim.profiler:begin("frame")

    dt = math.min(dt, SimConfig.MAX_DT)
    sim.time = sim.time + dt
    sim.tick = sim.tick + 1

    sim.profiler:begin("scheduler")
    sim.scheduler:update(dt)
    sim.profiler:finish("scheduler")

    sim.profiler:begin("agents")
    sim.agentMgr:update(dt)
    sim.profiler:finish("agents")

    sim.profiler:begin("debugger")
    sim.debugger:update(dt)
    sim.profiler:finish("debugger")

    EventBus.flush()

    sim.profiler:finish("frame")
    sim.stepOnce = false
end

function love.draw()
    sim.profiler:begin("render")
    sim.renderer:draw(sim.time, sim.tick, sim.paused)
    sim.debugger:draw()
    sim.profiler:drawHUD()
    sim.profiler:finish("render")
end

function love.keypressed(key, scancode, isrepeat)
    -- Simulation controls
    if key == "space" then
        sim.paused = not sim.paused
    elseif key == "right" and sim.paused then
        sim.stepOnce = true
    elseif key == "f1" then
        sim.debugger:toggle()
    elseif key == "f2" then
        sim.renderer:toggleHeatmap()
    elseif key == "f3" then
        sim.renderer:toggleInfluenceMap()
    elseif key == "f4" then
        sim.renderer:toggleFactionOverlay()
    elseif key == "f5" then
        SaveSystem.save("quicksave", sim)
    elseif key == "f9" then
        SaveSystem.load("quicksave", sim)
    elseif key == "escape" then
        love.event.quit()
    end

    sim.renderer:keypressed(key)
    sim.debugger:keypressed(key)
end

function love.mousepressed(x, y, button)
    sim.renderer:mousepressed(x, y, button)
    sim.debugger:mousepressed(x, y, button)
end

function love.wheelmoved(x, y)
    sim.renderer:wheelmoved(x, y)
end

function love.mousemoved(x, y, dx, dy)
    sim.renderer:mousemoved(x, y, dx, dy)
end

function love.quit()
    SaveSystem.save("exit_save", sim)
    EventBus.emit("sim:shutdown", {})
    EventBus.flush()
    return false
end
