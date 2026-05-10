-- engine/events/event_bus.lua
-- A synchronous, priority-aware event bus with deferred flushing.
-- Listeners register on named channels; events are queued then dispatched
-- in bulk at the end of each frame to avoid mid-frame side-effects.

local EventBus = {}

local _listeners = {}   -- channel -> list of { fn, priority, once }
local _queue     = {}   -- deferred events: { channel, data }
local _paused    = false

function EventBus.init()
    _listeners = {}
    _queue     = {}
    _paused    = false
end

-- Register a persistent listener on a channel.
function EventBus.on(channel, fn, priority)
    if not _listeners[channel] then _listeners[channel] = {} end
    local entry = { fn = fn, priority = priority or 0, once = false }
    table.insert(_listeners[channel], entry)
    table.sort(_listeners[channel], function(a, b) return a.priority > b.priority end)
    return entry  -- return handle for removal
end

-- Register a one-shot listener.
function EventBus.once(channel, fn, priority)
    if not _listeners[channel] then _listeners[channel] = {} end
    local entry = { fn = fn, priority = priority or 0, once = true }
    table.insert(_listeners[channel], entry)
    table.sort(_listeners[channel], function(a, b) return a.priority > b.priority end)
    return entry
end

-- Remove a listener by the handle returned from on/once.
function EventBus.off(channel, handle)
    local list = _listeners[channel]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == handle then table.remove(list, i); return end
    end
end

-- Queue an event for deferred dispatch.
function EventBus.emit(channel, data)
    _queue[#_queue + 1] = { channel = channel, data = data or {} }
end

-- Dispatch an event immediately (bypasses queue).
function EventBus.emitNow(channel, data)
    local list = _listeners[channel]
    if not list then return end
    local toRemove = {}
    for i, entry in ipairs(list) do
        entry.fn(data or {})
        if entry.once then toRemove[#toRemove + 1] = i end
    end
    for i = #toRemove, 1, -1 do table.remove(list, toRemove[i]) end
end

-- Flush all queued events (call once per frame, after update).
function EventBus.flush()
    if _paused then return end
    local q = _queue
    _queue = {}
    for _, ev in ipairs(q) do
        EventBus.emitNow(ev.channel, ev.data)
    end
end

function EventBus.pause()  _paused = true  end
function EventBus.resume() _paused = false end

function EventBus.clearAll()
    _listeners = {}
    _queue     = {}
end

function EventBus.listenerCount(channel)
    local list = _listeners[channel]
    return list and #list or 0
end

return EventBus
