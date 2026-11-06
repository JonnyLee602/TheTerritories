-- Server core: shared helpers, database setup and load order.
local RSGCore = exports['rsg-core']:GetCoreObject()

GG = {
    Core = RSGCore,
    Ready = false,
    loadHooks = {},
}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
function GG.Notify(src, msg, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = msg, type = ntype or 'inform', duration = 5000 })
end

function GG.IsAdmin(src)
    return src and src > 0 and RSGCore.Functions.HasPermission(src, Config.AdminPermission) or false
end

function GG.Finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end

function GG.Int(n, lo, hi)
    n = math.tointeger(tonumber(n))
    if not n or (lo and n < lo) or (hi and n > hi) then return nil end
    return n
end

function GG.Str(s, maxLen)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return nil end
    return s:sub(1, maxLen or 60)
end

local cooldowns = {}
-- true = still cooling down (reject the request)
function GG.Cooldown(src, key, ms)
    local now = GetGameTimer()
    cooldowns[src] = cooldowns[src] or {}
    local last = cooldowns[src][key]
    if last and now - last < ms then return true end
    cooldowns[src][key] = now
    return false
end

function GG.PlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function GG.CharName(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local ci = Player and Player.PlayerData.charinfo
    if ci and ci.firstname then return (('%s %s'):format(ci.firstname, ci.lastname or ''):gsub('%s+$', '')) end
    return GetPlayerName(src) or '?'
end

function GG.Debug(...)
    if Config.Debug then print('[grumpy-gambling]', ...) end
end

function GG.AfterLoad(fn) GG.loadHooks[#GG.loadHooks + 1] = fn end

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)

---------------------------------------------------------------------
-- Database + load
---------------------------------------------------------------------
local function createTables()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'install.sql')
    if not sql then return print('^1[grumpy-gambling] install.sql missing^7') end
    for stmt in sql:gmatch('CREATE TABLE.-;') do MySQL.query.await(stmt) end
end

MySQL.ready(function()
    if Config.AutoDatabase then createTables() end
    for _, fn in ipairs(GG.loadHooks) do
        local ok, err = pcall(fn)
        if not ok then print('^1[grumpy-gambling] load hook: ' .. tostring(err) .. '^7') end
    end
    GG.Ready = true
    TriggerEvent('grumpy-gambling:server:ready')
    TriggerClientEvent('grumpy-gambling:client:sync', -1, GG.Tables.PublicAll())
    print(('^2[grumpy-gambling] %d tables loaded^7'):format(GG.Tables.Count()))
end)

exports('IsReady', function() return GG.Ready end)
