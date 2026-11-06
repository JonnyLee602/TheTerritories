-- Fake FiveM natives and rsg-core for running the server money code in plain Lua 5.4 (tests only).
Fake = { handlers = {}, clientEvents = {}, players = {}, bySrc = {}, resourceState = {}, invoking = nil,
    resource = 'grumpy-gambling', now = 0, timers = {}, lastView = {}, messages = {} }

function locale(k, ...) return k end
function IsDuplicityVersion() return 1 end -- the real server can return 1, not true
json = { encode = function() return '{}' end, decode = function() return {} end }
function CreateThread() end
function Wait() end
function print() end -- keep test output quiet

-- event bus: every handler of an event runs, in registration order
-- each handler and timer remembers the resource that registered it, and runs "inside" that resource
local function inResource(res, fn, ...)
    local prev = Fake.resource
    Fake.resource = res
    local r = table.pack(fn(...))
    Fake.resource = prev
    return table.unpack(r, 1, r.n)
end
local function on(name, fn)
    Fake.handlers[name] = Fake.handlers[name] or {}
    table.insert(Fake.handlers[name], { fn = fn, res = Fake.resource })
end
function RegisterNetEvent(name, fn) if fn then on(name, fn) end end
function AddEventHandler(name, fn) on(name, fn) end
function TriggerEvent(name, ...)
    for _, h in ipairs(Fake.handlers[name] or {}) do inResource(h.res, h.fn, ...) end
end
-- a client sends a net event
function Fake.Net(src, name, ...)
    local prev = source
    source = src
    for _, h in ipairs(Fake.handlers[name] or {}) do inResource(h.res, h.fn, ...) end
    source = prev
end
function TriggerClientEvent(name, src, ...)
    local args = { ... }
    Fake.clientEvents[#Fake.clientEvents + 1] = { name = name, src = src, args = args }
    if #Fake.clientEvents > 3000 then table.remove(Fake.clientEvents, 1) end
    if name == 'grumpy-gambling:client:view' then
        Fake.lastView[src] = { tableId = args[1], public = args[2], private = args[3], seat = args[4] }
    elseif name == 'grumpy-gambling:client:message' then
        Fake.messages[#Fake.messages + 1] = args[2]
    end
end

-- virtual clock for SetTimeout
function SetTimeout(ms, fn) Fake.timers[#Fake.timers + 1] = { at = Fake.now + ms, fn = fn, res = Fake.resource } end
function Fake.Advance(ms)
    local target = Fake.now + ms
    while true do
        local idx, best
        for i, t in ipairs(Fake.timers) do
            if t.at <= target and (not best or t.at < best.at) then idx, best = i, t end
        end
        if not idx then break end
        table.remove(Fake.timers, idx)
        Fake.now = best.at
        inResource(best.res, best.fn)
    end
    Fake.now = target
end

function GetInvokingResource() return Fake.invoking end
function GetCurrentResourceName() return Fake.resource end
function GetResourceState(r) return Fake.resourceState[r] or 'started' end
function GetPlayers()
    local list = {}
    for src in pairs(Fake.bySrc) do list[#list + 1] = tostring(src) end
    return list
end
function GetPlayerName(src) return 'player' .. tostring(src) end
function GetGameTimer() Fake.timer = (Fake.timer or 0) + 10000; return Fake.timer end
function GetPlayerPed() return 0 end
function vector3(x, y, z) return { x = x, y = y, z = z } end

-- exports: a resource registers with exports('Name', fn); another resource calls exports['res']:Name(...)
-- (GetInvokingResource() is the caller while the export runs)
local exportFns = {}
exports = setmetatable({}, {
    __call = function(_, name, fn) exportFns[name] = fn end,
    __index = function(_, res) return setmetatable({}, { __index = function(_, fname)
        return function(_, ...)
            if res == 'rsg-core' and fname == 'GetCoreObject' then return Fake.Core end
            local fn = exportFns[fname]
            if not fn then error('no export ' .. res .. ':' .. fname) end
            local prevInv, prevRes = Fake.invoking, Fake.resource
            Fake.invoking, Fake.resource = prevRes, res
            local r = table.pack(fn(...))
            Fake.invoking, Fake.resource = prevInv, prevRes
            return table.unpack(r, 1, r.n)
        end
    end }) end,
})
Fake.exports = exportFns

MySQL = { ready = function() end, query = setmetatable({}, { __call = function() end }), insert = function() end }

-- rsg-core players with a money table
local function newPlayer(src, cid, cash, blood)
    local P = { PlayerData = { source = src, citizenid = cid, money = { cash = cash, bloodmoney = blood or 0 },
        charinfo = { firstname = 'P', lastname = cid }, metadata = {} }, Functions = {}, saves = 0 }
    function P.Functions.AddMoney(t, a) if a < 0 then return false end P.PlayerData.money[t] = P.PlayerData.money[t] + a; return true end
    function P.Functions.RemoveMoney(t, a)
        if a < 0 or P.PlayerData.money[t] - a < -1e-9 then return false end
        P.PlayerData.money[t] = P.PlayerData.money[t] - a; return true
    end
    function P.Functions.GetMoney(t) return P.PlayerData.money[t] end
    function P.Functions.Save() P.saves = P.saves + 1 end
    return P
end

function Fake.AddPlayer(src, cid, cash, blood)
    local P = newPlayer(src, cid, cash, blood)
    Fake.players[cid] = P
    Fake.bySrc[src] = P
    return P
end

function Fake.Disconnect(src) Fake.bySrc[src] = nil end
function Fake.Reconnect(src, cid) Fake.bySrc[src] = Fake.players[cid]; Fake.players[cid].PlayerData.source = src end

Fake.Core = {
    Functions = {
        GetPlayer = function(src) return Fake.bySrc[src] end,
        GetPlayerByCitizenId = function(cid)
            local P = Fake.players[cid]
            if P and Fake.bySrc[P.PlayerData.source] == P then return P end
            return nil
        end,
        HasPermission = function() return false end,
        CreateCallback = function() end,
    },
    Commands = { Add = function() end },
}
