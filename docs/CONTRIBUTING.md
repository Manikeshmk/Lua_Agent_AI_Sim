# Contributing to LuaAgentSim

Thank you for considering contributing!

## Getting Started

1. **Fork** the repository and clone locally
2. Install [LÖVE2D 11.4+](https://love2d.org/)
3. Run: `love .` from the project root
4. Run tests: `cd tests && lua run_tests.lua`

## Code Standards

- All simulation logic in **Lua** — no C/C++ unless for performance-critical native modules
- Follow existing naming conventions (snake_case for files, PascalCase for modules)
- Every new system should fire/listen to events via `EventBus`
- New components go in `engine/ecs/components.lua`
- New AI behaviors go in `agents/behavior_trees/agent_behaviors.lua`
- Data files (items, biomes, recipes) go in `data/`

## Pull Request Process

1. Create a feature branch from `main`
2. Write or update tests in `tests/`
3. Ensure `lua tests/run_tests.lua` passes
4. Submit a PR with a clear description of changes

## Creating Mods

Drop `.lua` files in `mods/` — see `mods/example_mod.lua` for the API.

## Reporting Issues

Use GitHub Issues. Include:
- Steps to reproduce
- Expected vs actual behavior
- LÖVE2D / Lua version
- OS and hardware info
