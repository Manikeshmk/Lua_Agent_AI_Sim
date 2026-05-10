# Modding API Reference

LuaAgentSim is designed from the ground up to be extensible via Lua mods.

## Creating a Mod

1. Create a `.lua` file in the `mods/` directory
2. Return a table with `name`, `version`, and lifecycle callbacks
3. The engine auto-loads all mods at startup

### Minimal Mod Template

```lua
local Mod = {}
Mod.name    = "MyMod"
Mod.version = "1.0.0"
Mod.author  = "Your Name"

function Mod.onLoad(api)
    -- Called when the mod is loaded
    -- api contains references to engine subsystems
end

function Mod.onUnload(api)
    -- Called when the mod is unloaded (hot-reload)
end

return Mod
```

## API Object

The `api` table passed to `onLoad` contains:

| Key | Type | Description |
|---|---|---|
| `api.ecs` | ECS World | Entity-Component-System world |
| `api.world` | World | Simulation world (tiles, resources, cities) |
| `api.eventBus` | EventBus | Event publish/subscribe system |
| `api.economy` | Economy | Market and trading system |
| `api.factions` | Factions | Faction diplomacy system |

## ECS API

### Entities

```lua
local id = api.ecs:newEntity("tag1", "tag2")
api.ecs:destroyEntity(id)
api.ecs:hasTag(id, "tag1")  -- true
```

### Components

```lua
local Components = require("engine.ecs.components")

api.ecs:addComponent(id, "Position", Components.Position(10, 20))
api.ecs:addComponent(id, "Health",   Components.Health(100))

local pos = api.ecs:getComponent(id, "Position")
pos.x = 50

api.ecs:hasComponent(id, "Health")   -- true
api.ecs:removeComponent(id, "Health")
```

### Queries

```lua
-- Find all entities with both Position and Health
local entities = api.ecs:query("Position", "Health")
for _, id in ipairs(entities) do
    local hp = api.ecs:getComponent(id, "Health")
    print("Entity " .. id .. " has " .. hp.current .. " HP")
end
```

## Event System

### Listening

```lua
api.eventBus.on("combat:kill", function(data)
    print("Entity " .. data.attacker .. " killed " .. data.defender)
end)
```

### Emitting

```lua
api.eventBus.emit("my_mod:custom_event", {
    message = "Something happened!",
    value   = 42,
})
```

### Built-in Event Channels

| Channel | Data Fields | Description |
|---|---|---|
| `sim:started` | tick | Simulation started |
| `sim:shutdown` | — | Simulation shutting down |
| `combat:hit` | attacker, defender, damage | Attack landed |
| `combat:kill` | attacker, defender | Entity killed |
| `combat:retreat` | entity, morale | Entity retreating |
| `faction:war_declared` | attacker, defender | War declared |
| `faction:alliance_formed` | factions | Alliance formed |
| `comm:message_sent` | sender, receiver, type | Communication |
| `social:interaction` | entityA, entityB, type | Social event |

## World API

```lua
local tile = api.world:getTile(x, y)
-- tile.biome, tile.elevation, tile.moisture, tile.resource, tile.walkable

api.world:isWalkable(x, y)

local resources = api.world:findNearestResource(x, y, "wood", 30)
local city = api.world:findNearestCity(x, y)
local tiles = api.world:getTilesInRadius(x, y, 10)
```

## Economy API

```lua
local marketIdx = api.economy:getNearestMarket(x, y)
local price = api.economy:getPrice(marketIdx, "iron")
local ok, cost = api.economy:buy(marketIdx, "food", 5, buyerEntityId)
local ok, gold = api.economy:sell(marketIdx, "wood", 10, sellerEntityId)
```

## Hot Reload

Mods support hot-reload at runtime. The engine calls `onUnload(api)` before
reloading, then `onLoad(api)` with fresh state. Clean up any event listeners
in `onUnload` to avoid duplicates.

## Example: Custom Behavior Mod

```lua
local Mod = {}
Mod.name    = "AggressiveAgents"
Mod.version = "1.0"

function Mod.onLoad(api)
    api.eventBus.on("sim:started", function()
        -- Make all agents more aggressive
        local agents = api.ecs:query("AI", "Emotion")
        for _, id in ipairs(agents) do
            local emotion = api.ecs:getComponent(id, "Emotion")
            local ai = api.ecs:getComponent(id, "AI")
            if emotion then emotion.anger = 80 end
            if ai and ai.personality then
                ai.personality.agreeableness = 0.1
            end
        end
    end)
end

return Mod
```
