RSGCore = exports['rsg-core']:GetCoreObject()

-- shared server state for robbery.lua, shoplift.lua and admin.lua
GR = {
    Stores = {},   -- [npcId] = { id, label, model, coords = vector3, h, enabled, shelves = { vector3 }, safe = table|nil, items = {} }
}

function GR.Notify(src, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = description, type = nType or 'inform', duration = 6000 })
end

function GR.Dist(src, coords)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords)
end

function GR.IsAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

function GR.Rep(src, action)
    if action and GetResourceState('grumpy-reputation') == 'started' then
        exports['grumpy-reputation']:Action(src, action)
    end
end

-- by citizenid, always queued: applied on that character's next login (used when the robber is gone)
function GR.RepCid(citizenid, action)
    if action and citizenid and GetResourceState('grumpy-reputation') == 'started' then
        exports['grumpy-reputation']:ActionByCitizenId(citizenid, action, 1, true)
    end
end

function GR.IsLaw(Player)
    local job = Player and Player.PlayerData.job
    return job and job.type == 'leo' and job.onduty or false
end

-- grumpy-law handles witnesses, reports and heat when it's running
function GR.Law() return GetResourceState('grumpy-law') == 'started' end

function GR.LawOnDuty()
    local n = 0
    for _, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if GR.IsLaw(Player) then n = n + 1 end
    end
    return n
end

-- alert on-duty law through rsg-lawman's own client alert (blip + notify), sent from the server
function GR.AlertLaw(coords, text)
    for _, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if GR.IsLaw(Player) then
            if GetResourceState('rsg-lawman') == 'started' then
                TriggerClientEvent('rsg-lawman:client:lawmanAlert', Player.PlayerData.source, coords, text)
            else
                GR.Notify(Player.PlayerData.source, text, 'warning')
            end
        end
    end
end

-- online posse mates (incl. src) from grumpy-groups, else just src
function GR.Posse(src)
    if GetResourceState('grumpy-groups') ~= 'started' then return { src } end
    local members = exports['grumpy-groups']:GetMembers(src, 'posse')
    return #members > 0 and members or { src }
end

-----------------------------------------------------------------------
-- database
-----------------------------------------------------------------------
local function decode(s, fallback)
    if type(s) ~= 'string' or s == '' then return fallback end
    local ok, v = pcall(json.decode, s)
    return ok and v or fallback
end

local function toVec(p) return vector3(tonumber(p.x) or 0.0, tonumber(p.y) or 0.0, tonumber(p.z) or 0.0) end

function GR.Save(id)
    local s = GR.Stores[id]
    if not s then return end
    local shelves = {}
    for _, v in ipairs(s.shelves) do shelves[#shelves + 1] = { x = v.x, y = v.y, z = v.z } end
    MySQL.prepare.await(
        'INSERT INTO grumpy_robbery_stores (npc_id, enabled, shelves, safe) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE enabled = VALUES(enabled), shelves = VALUES(shelves), safe = VALUES(safe)',
        { id, s.enabled and 1 or 0, json.encode(shelves), s.safe and json.encode(s.safe) or nil })
end

-- what clients need (no item lists)
function GR.PublicStores()
    local out = {}
    for id, s in pairs(GR.Stores) do
        local shelves = {}
        for _, v in ipairs(s.shelves) do shelves[#shelves + 1] = { x = v.x, y = v.y, z = v.z } end
        out[#out + 1] = {
            id = id, label = s.label, model = s.model, x = s.coords.x, y = s.coords.y, z = s.coords.z, h = s.h,
            enabled = s.enabled, shelves = shelves, safe = s.safe,
        }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

function GR.Sync(target)
    TriggerClientEvent('grumpy-robbery:client:stores', target or -1, GR.PublicStores())
end

function GR.LoadStores()
    local ok, rows = pcall(MySQL.query.await,
        "SELECT id, name, shop_label, model, x, y, z, h FROM rsg_shops_npcs WHERE store_kind = 'npc' AND model IS NOT NULL")
    if not ok or not rows then
        print('^1[grumpy-robbery] could not read rsg_shops_npcs (is rsg-stores installed?)^7')
        return
    end
    local saved = {}
    for _, r in ipairs(MySQL.query.await('SELECT npc_id, enabled, shelves, safe FROM grumpy_robbery_stores') or {}) do
        saved[r.npc_id] = r
    end

    local items = {}
    for _, r in ipairs(MySQL.query.await('SELECT npc_id, item_name, price, stock FROM rsg_shops_items') or {}) do
        items[r.npc_id] = items[r.npc_id] or {}
        items[r.npc_id][#items[r.npc_id] + 1] = { name = r.item_name, price = tonumber(r.price) or 0, stock = r.stock }
    end

    local fresh = {}
    for _, r in ipairs(rows) do
        local s = saved[r.id]
        local shelves = {}
        for i, p in ipairs(decode(s and s.shelves, {})) do
            if i <= Config.Shoplift.MaxShelves then shelves[#shelves + 1] = toVec(p) end
        end
        fresh[r.id] = {
            id = r.id,
            label = (r.shop_label and r.shop_label ~= '' and r.shop_label) or r.name or ('Store ' .. r.id),
            model = r.model,
            coords = vector3(r.x + 0.0, r.y + 0.0, r.z + 0.0), h = r.h + 0.0,
            enabled = s == nil and Config.Robbery.DefaultEnabled or (s and tonumber(s.enabled) == 1),
            shelves = shelves,
            safe = decode(s and s.safe, nil),
            items = items[r.id] or {},
        }
    end
    GR.Stores = fresh
    GR.Sync()
end

MySQL.ready(function()
    if Config.AutoDatabase then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `grumpy_robbery_stores` (
                `npc_id` INT NOT NULL,
                `enabled` TINYINT(1) NOT NULL DEFAULT 1,
                `shelves` LONGTEXT NULL,
                `safe` LONGTEXT NULL,
                PRIMARY KEY (`npc_id`)
            )
        ]])
    end
    GR.LoadStores()
    while true do
        Wait(Config.StoreRefresh * 1000)
        GR.LoadStores()
    end
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if Player then GR.Sync(Player.PlayerData.source) end
end)

local lastRequest = {}
RegisterNetEvent('grumpy-robbery:server:requestStores', function()
    local src, now = source, GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 10000 then return end
    lastRequest[src] = now
    GR.Sync(src)
end)

AddEventHandler('playerDropped', function() lastRequest[source] = nil end)
