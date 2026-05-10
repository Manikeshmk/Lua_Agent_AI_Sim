-- engine/network/network.lua
-- Optional ENet-based networking layer.
-- Provides a dedicated simulation server and remote client observer mode.
-- Falls back gracefully if ENet is not available.

local Network = {}
Network.__index = Network

local hasENet = pcall(require, "enet")
local enet    = hasENet and require("enet") or nil

local PROTOCOL_VERSION = 1
local DEFAULT_PORT     = 12345
local MAX_PEERS        = 32

-- Message type constants
Network.MSG = {
    HANDSHAKE   = 0,
    WORLD_CHUNK = 1,
    ENTITY_SYNC = 2,
    CHAT        = 3,
    COMMAND     = 4,
    PING        = 5,
}

function Network.newServer(port)
    if not enet then
        print("[Network] ENet not available — networking disabled.")
        return nil
    end
    local srv = setmetatable({}, Network)
    srv._host  = enet.host_create("*:" .. (port or DEFAULT_PORT), MAX_PEERS)
    srv._peers = {}
    srv._mode  = "server"
    srv._queue = {}
    print("[Network] Server started on port " .. (port or DEFAULT_PORT))
    return srv
end

function Network.newClient(host, port)
    if not enet then return nil end
    local cli = setmetatable({}, Network)
    cli._host   = enet.host_create()
    cli._peer   = cli._host:connect(host .. ":" .. (port or DEFAULT_PORT))
    cli._mode   = "client"
    cli._queue  = {}
    print("[Network] Connecting to " .. host .. ":" .. (port or DEFAULT_PORT))
    return cli
end

function Network:update(dt)
    if not self._host then return end
    local event = self._host:service(0)
    while event do
        if event.type == "connect" then
            self:_onConnect(event.peer)
        elseif event.type == "disconnect" then
            self:_onDisconnect(event.peer)
        elseif event.type == "receive" then
            self:_onReceive(event.peer, event.data)
        end
        event = self._host:service(0)
    end
end

function Network:_onConnect(peer)
    print("[Network] Peer connected: " .. tostring(peer))
    if self._mode == "server" then
        self._peers[#self._peers + 1] = peer
        -- Send handshake
        self:_send(peer, Network.MSG.HANDSHAKE, { version = PROTOCOL_VERSION })
    end
end

function Network:_onDisconnect(peer)
    print("[Network] Peer disconnected: " .. tostring(peer))
    for i = #self._peers, 1, -1 do
        if self._peers[i] == peer then table.remove(self._peers, i) end
    end
end

function Network:_onReceive(peer, data)
    local ok, msg = pcall(load("return " .. data))
    if ok and msg then
        self._queue[#self._queue + 1] = { peer = peer, msg = msg }
    end
end

function Network:_send(peer, msgType, payload)
    local data = "{ type=" .. msgType .. ", payload=" .. self:_serialize(payload) .. " }"
    peer:send(data, 0, "reliable")
end

function Network:broadcast(msgType, payload)
    local data = "{ type=" .. msgType .. ", payload=" .. self:_serialize(payload) .. " }"
    for _, peer in ipairs(self._peers) do
        peer:send(data, 0, "reliable")
    end
end

function Network:_serialize(t)
    if type(t) ~= "table" then return tostring(t) end
    local parts = {}
    for k, v in pairs(t) do
        local key = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
        parts[#parts + 1] = key .. "=" .. self:_serialize(v)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function Network:pollMessages()
    local q = self._queue
    self._queue = {}
    return q
end

function Network:peerCount()
    return #(self._peers or {})
end

function Network:disconnect()
    if self._host then self._host:destroy() end
end

return Network
