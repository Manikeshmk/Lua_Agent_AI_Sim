-- mods/example_mod.lua
-- Example mod demonstrating the plugin API.
-- Adds a custom "wanderlust" behavior and a new resource type.

local Mod = {}

Mod.name    = "Wanderlust"
Mod.version = "1.0.0"
Mod.author  = "Example"

function Mod.onLoad(api)
    print("[Mod:Wanderlust] Loaded!")

    -- Example: listen for events
    if api.eventBus then
        api.eventBus.on("sim:started", function(data)
            print("[Mod:Wanderlust] Simulation started, modifying exploration drive...")
        end)
    end
end

function Mod.onUnload(api)
    print("[Mod:Wanderlust] Unloaded.")
end

return Mod
