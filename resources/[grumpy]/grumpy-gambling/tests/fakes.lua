-- Fake FiveM natives and rsg-core for running the server money code in plain Lua 5.4 (tests only).
Fake = { events = {}, clientEvents = {}, players = {}, bySrc = {}, resourceState = {}, invoking = nil }

function locale(k, ...) return k end
json = { encode = function() return '{}' end, decode = function() return {} end }
function CreateThread() end
function SetTimeout() end
function Wait() end
function print() end -- keep test output quiet
function RegisterNetEvent(name, fn) if fn then Fake.events[name] = fn end end
function AddEventHandler(name, fn) Fake.events[name] = Fake.events[name] or fn end
function TriggerEvent() end
function TriggerClientEvent(name, src, ...) Fake.clientEvents[#Fake.clientEvents + 1] = { name = name, src = src, args = { ... } } end
function GetInvokingResource() return Fake.invoking end
function GetCurrentResourceName() return 'grumpy-gambling' end
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

local exportFns = {}
exports = setmetatable({}, {
    __call = function(_, name, fn) exportFns[name] = fn end,
    __index = function(_, res) return setmetatable({}, { __index = function(_, fname)
        return function(_, ...) if res == 'rsg-core' and fname == 'GetCoreObject' then return Fake.Core end end
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
