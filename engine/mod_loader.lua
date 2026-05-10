-- engine/mod_loader.lua
-- Hot-reload capable Lua mod system.
-- Mods are single .lua files dropped into the mods/ directory.
-- Each mod must return a table with: name, version, onLoad(api).

local ModLoader = {}

local _loadedMods = {}
local _api        = nil

function ModLoader.loadAll(dir, api)
    _api = api
    _loadedMods = {}

    local items = love.filesystem.getDirectoryItems(dir)
    if not items then
        print("[ModLoader] No mods directory found.")
        return
    end

    table.sort(items)
    for _, filename in ipairs(items) do
        if filename:match("%.lua$") then
            ModLoader._loadFile(dir .. "/" .. filename)
        end
    end
end

function ModLoader._loadFile(path)
    local chunk, err = love.filesystem.load(path)
    if not chunk then
        print("[ModLoader] Failed to load: " .. path .. " — " .. tostring(err))
        return
    end

    local ok, mod = pcall(chunk)
    if not ok then
        print("[ModLoader] Execution error in: " .. path .. " — " .. tostring(mod))
        return
    end

    if type(mod) ~= "table" then
        print("[ModLoader] Mod must return a table: " .. path)
        return
    end

    if type(mod.onLoad) == "function" then
        local ok2, err2 = pcall(mod.onLoad, _api)
        if not ok2 then
            print("[ModLoader] onLoad error in " .. (mod.name or path) .. ": " .. tostring(err2))
            return
        end
    end

    _loadedMods[#_loadedMods + 1] = {
        name    = mod.name    or path,
        version = mod.version or "?",
        path    = path,
        mod     = mod,
    }
    print("[ModLoader] Loaded mod: " .. (mod.name or path) .. " v" .. (mod.version or "?"))
end

-- Hot-reload a specific mod by path.
function ModLoader.reload(path)
    -- Unload existing
    for i = #_loadedMods, 1, -1 do
        if _loadedMods[i].path == path then
            local mod = _loadedMods[i].mod
            if type(mod.onUnload) == "function" then pcall(mod.onUnload, _api) end
            table.remove(_loadedMods, i)
        end
    end
    ModLoader._loadFile(path)
end

function ModLoader.reloadAll()
    local paths = {}
    for _, m in ipairs(_loadedMods) do paths[#paths + 1] = m.path end
    for _, m in ipairs(_loadedMods) do
        if type(m.mod.onUnload) == "function" then pcall(m.mod.onUnload, _api) end
    end
    _loadedMods = {}
    for _, p in ipairs(paths) do ModLoader._loadFile(p) end
end

function ModLoader.list()
    return _loadedMods
end

return ModLoader
