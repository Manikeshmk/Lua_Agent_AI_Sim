# Architecture Overview

## System Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        main.lua (LÖVE2D)                       │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ Scheduler│  │ Event Bus │  │   ECS    │  │  Save System │ │
│  └────┬─────┘  └─────┬─────┘  └────┬─────┘  └──────────────┘ │
│       │              │              │                          │
│  ┌────┴──────────────┴──────────────┴─────────────────┐       │
│  │                 Simulation Layer                     │       │
│  │  ┌─────────┐  ┌─────────┐  ┌────────┐  ┌────────┐ │       │
│  │  │  World  │  │ Weather │  │Economy │  │Factions│ │       │
│  │  └─────────┘  └─────────┘  └────────┘  └────────┘ │       │
│  └─────────────────────┬──────────────────────────────┘       │
│                        │                                       │
│  ┌─────────────────────┴──────────────────────────────┐       │
│  │                   Agent Layer                       │       │
│  │  ┌──────────┐  ┌──────────┐  ┌──────┐  ┌────────┐ │       │
│  │  │ Behavior │  │ Utility  │  │ GOAP │  │ Memory │ │       │
│  │  │  Trees   │  │   AI     │  │      │  │        │ │       │
│  │  └──────────┘  └──────────┘  └──────┘  └────────┘ │       │
│  │  ┌────────────┐  ┌──────────────────────────────┐  │       │
│  │  │ Perception │  │  Spatial Grid (partitioning) │  │       │
│  │  └────────────┘  └──────────────────────────────┘  │       │
│  └────────────────────────────────────────────────────┘       │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐     │
│  │                  Systems Layer                        │     │
│  │  ┌───────────┐  ┌────────┐  ┌──────────┐  ┌───────┐ │     │
│  │  │Pathfinding│  │ Combat │  │ Movement │  │Reprod.│ │     │
│  │  └───────────┘  └────────┘  └──────────┘  └───────┘ │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐     │
│  │               Rendering & Tools                       │     │
│  │  ┌──────────┐  ┌──────────┐  ┌────────┐  ┌────────┐ │     │
│  │  │ Renderer │  │ Debugger │  │Profiler│  │  Mods  │ │     │
│  │  └──────────┘  └──────────┘  └────────┘  └────────┘ │     │
│  └──────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Scheduler** fires jobs at configured intervals
2. **World** updates tile state, resource regeneration
3. **Weather** advances day/night cycle and atmospheric conditions
4. **AgentManager** batch-updates AI agents:
   - **Perception** scans nearby entities via Spatial Grid
   - **Memory** records observations
   - **UtilityAI** scores possible actions
   - **BehaviorTree** executes the selected behavior
   - **GOAP** generates multi-step plans when needed
5. **Systems** process movement, combat, pathfinding
6. **Economy** ticks market prices based on supply/demand
7. **Factions** drift diplomatic relations
8. **EventBus** flushes deferred events
9. **Renderer** draws everything with LÖVE2D
10. **Debugger/Profiler** overlays diagnostic information

## Key Design Decisions

- **ECS over OOP**: Entities are integers, components are plain tables. This enables cache-friendly iteration and easy serialization.
- **Event-driven decoupling**: Subsystems communicate via EventBus, not direct references.
- **Batched AI updates**: Only a subset of agents runs full AI evaluation each frame, spreading CPU cost across frames.
- **Spatial partitioning**: Uniform grid enables O(1) neighbor queries instead of O(n²) brute force.
- **Pure Lua noise**: Simplex-like noise implemented in pure Lua for portability (no C dependencies).
