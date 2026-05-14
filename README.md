# LuaAgentSim — Multi-Agent AI Simulation Engine

<p align="center">
  <a href="https://www.lua.org/"><img src="https://img.shields.io/badge/language-Lua%205.4%20%2F%20LuaJIT-blue?logo=lua" alt="Lua"/></a>
  <a href="https://love2d.org/"><img src="https://img.shields.io/badge/renderer-LÖVE2D%2011.x-ff69b4?logo=love2d" alt="LÖVE2D"/></a>
  <a href="https://www.sqlite.org/"><img src="https://img.shields.io/badge/storage-SQLite-green?logo=sqlite" alt="SQLite"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-yellow" alt="MIT License"/></a>
</p>

> A research-grade, fully Lua-driven emergent AI civilization simulator.  
> Inspired by Dwarf Fortress, RimWorld, OpenAI Gym, and StarCraft AI environments.

---

## Overview

**LuaAgentSim** is a modular, large-scale multi-agent simulation engine where thousands of autonomous AI agents inhabit a persistent procedurally-generated world. Agents perceive their environment, plan goals, form relationships, trade, fight, and evolve — producing rich emergent behavior with no scripted outcomes.

The engine is designed as both a **playable simulation** and a **research experimentation platform**, supporting reinforcement learning hooks, evolutionary algorithms, and swarm intelligence experiments.

---

## Feature Highlights

| Domain | Features |
|---|---|
| **World** | Procedural terrain, biomes, weather, day/night, resource veins, cities |
| **ECS** | Modular Entity-Component-System with 20+ component types |
| **AI** | FSM, Behavior Trees, Utility AI, GOAP planning |
| **Pathfinding** | A* with influence maps and tactical positioning |
| **Economy** | Supply/demand markets, crafting, profession specialization |
| **Social** | Factions, alliances, reputation, emotional states, gossip |
| **Combat** | Melee, ranged, formations, morale, flanking |
| **Rendering** | LÖVE2D zoomable map, heatmaps, AI overlays, profiler |
| **Persistence** | SQLite save/load, replay system, deterministic playback |
| **Modding** | Hot-reload Lua mods, plugin API, custom agent behaviors |
| **Networking** | ENet multiplayer observation (optional) |

---

## Architecture

```
LuaAgentSim/
├── main.lua                  # LÖVE2D entry point
├── conf.lua                  # LÖVE2D configuration
├── engine/
│   ├── ecs/                  # Entity-Component-System core
│   ├── events/               # Event bus
│   ├── scheduler/            # Coroutine job scheduler
│   ├── renderer/             # LÖVE2D rendering pipeline
│   └── network/              # ENet networking layer
├── simulation/
│   ├── world/                # World generation & chunk system
│   ├── weather/              # Weather & day/night cycle
│   ├── economy/              # Markets, crafting, supply/demand
│   └── factions/             # Faction politics & territory
├── agents/
│   ├── behavior_trees/       # BT nodes and runner
│   ├── utility_ai/           # Utility scoring system
│   ├── goap/                 # Goal-Oriented Action Planning
│   ├── memory/               # Agent memory & knowledge base
│   └── perception/           # Sensory system & influence maps
├── systems/
│   ├── movement.lua
│   ├── combat.lua
│   ├── pathfinding.lua
│   └── reproduction.lua
├── tools/
│   ├── debugger/             # Live inspector & decision viewer
│   ├── profiler/             # Performance profiler
│   └── map_editor/           # Map editor tool
├── mods/                     # External Lua mods directory
├── data/
│   ├── biomes.lua
│   ├── items.lua
│   └── recipes.lua
├── tests/                    # Unit tests (busted framework)
└── docs/                     # Documentation
```

---

## Quick Start

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| LÖVE2D | 11.4+ | [love2d.org](https://love2d.org/) |
| LuaJIT | 2.1+ | Bundled with LÖVE2D |
| SQLite | 3.x | Via `lsqlite3` LuaRocks module |

### Run

```bash
# Clone
git clone https://github.com/Manikeshmk/Lua.git
cd Lua

# Launch with LÖVE2D
love .

# Or run tests
cd tests
lua run_tests.lua
```

---

## Development Phases

- [x] **Phase 1** — ECS core, world generation, basic rendering, foundational agents
- [x] **Phase 2** — Utility AI, behavior trees, A* pathfinding
- [x] **Phase 3** — Economy, factions, combat system
- [ ] **Phase 4** — Advanced AI (RL hooks, evolutionary algorithms), networking
- [ ] **Phase 5** — Modding API, live tools, research features

---

## Performance Targets

| Scale | Status |
|---|---|
| 500 active agents | ✅ Stable |
| 2,000 active agents | ✅ Stable with spatial partitioning |
| 10,000+ agents | 🚧 In progress (chunk-based scheduling) |

---

## Modding

Drop a `.lua` file in `mods/` to extend the engine:

```lua
-- mods/my_mod.lua
local Mod = {}

Mod.name = "MyMod"
Mod.version = "1.0"

function Mod.onLoad(api)
    api.registerBehavior("wander_fast", function(agent, dt)
        agent.speed = agent.speed * 2
    end)
end

return Mod
```

---

## Research Features

- **RL Hooks** — Expose agent state/action/reward interfaces compatible with OpenAI Gym-style loops
- **Evolutionary Algorithms** — Agent trait mutation, fitness selection, generational tracking
- **Swarm Intelligence** — Ant-colony and flocking primitives built into the perception system
- **Deterministic Replay** — Seed-based world regeneration and event-log replay for experiment reproducibility

---

## License

MIT — see [LICENSE](LICENSE).

---

## Contributing

Pull requests welcome. See [CONTRIBUTING.md](docs/CONTRIBUTING.md).
