-- Shared server state, helpers, database load and client sync.
local RSGCore = exports['rsg-core']:GetCoreObject()

POB = {
    Businesses = {},   -- [id] = business
    Ready = false,
    loadHooks = {},
}

---------------------------------------------------------------------
-- Generic helpers
---------------------------------------------------------------------
function POB.Core() return RSGCore end

function POB.Debug(...) if Config.Debug then print('[grumpy-pob]', ...) end end

function POB.Notify(src, msg, ntype, title)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title or locale('title'), description = msg, type = ntype or 'inform', duration = 5000,
    })
end

function POB.IsAdmin(src)
    return src and src > 0 and RSGCore.Functions.HasPermission(src, Config.AdminPermission) or false
end

function POB.Finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end

function POB.Money(n)
    n = tonumber(n)
    if not POB.Finite(n) then return nil end
    return math.floor(n * 100 + 0.5) / 100
end

function POB.Int(n, lo, hi)
    n = math.tointeger(tonumber(n))
    if not n or (lo and n < lo) or (hi and n > hi) then return nil end
    return n
end

function POB.Str(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[<>"`\\]', ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return nil end
    return v:sub(1, max or 60)
end

function POB.Vec(p) return p and vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) or nil end

function POB.Near(src, p, dist)
    if not p then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - POB.Vec(p)) <= (dist or Config.ServerDistance)
end

local cooldowns = {}
function POB.Cooldown(src, key, ms)
    local k = src .. ':' .. key
    local now = GetGameTimer()
    if cooldowns[k] and now < cooldowns[k] then return true end
    cooldowns[k] = now + (ms or 1000)
    return false
end

local locks = {}
function POB.Lock(key, fn)
    if locks[key] then return false end
    locks[key] = true
    local ok, a, b, c = pcall(fn)
    locks[key] = nil
    if not ok then print('^1[grumpy-pob] ' .. tostring(a) .. '^7') return false end
    return a, b, c
end

function POB.ShortName(charinfo)
    if type(charinfo) == 'string' then
        local ok, d = pcall(json.decode, charinfo)
        charinfo = ok and d or nil
    end
    if type(charinfo) ~= 'table' then return '?' end
    return ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '')
end

function POB.PlayerName(Player) return POB.ShortName(Player.PlayerData.charinfo) end

function POB.SrcByCid(cid)
    local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
    return P and P.PlayerData.source or nil
end

function POB.ItemLabel(name)
    local it = RSGCore.Shared.Items[name]
    return it and it.label or name
end

function POB.Today() return tonumber(os.date('%Y%m%d')) end

-- Waits until another resource reports it has loaded its data (export IsReady). Call from a thread.
function POB.WaitReady(res, timeoutMs)
    local waited = 0
    while waited < (timeoutMs or 60000) do
        if GetResourceState(res) == 'started' then
            local ok, ready = pcall(function() return exports[res]:IsReady() end)
            if ok and ready then return true end
            if not ok then return true end -- export missing (unpatched): don't block, the calls will log errors
        end
        Wait(500)
        waited = waited + 500
    end
    print(('^3[grumpy-pob] %s did not become ready in time^7'):format(res))
    return false
end

---------------------------------------------------------------------
-- Businesses
---------------------------------------------------------------------
function POB.Biz(id)
    id = math.tointeger(tonumber(id))
    return id and POB.Businesses[id] or nil
end

function POB.Type(biz) return biz and Config.Types[biz.type] or nil end

function POB.AccountId(biz) return 'biz:' .. biz.id end

-- Employment: held grade (any duty) and whether this is the active, on-duty job
function POB.Employment(src, biz)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not biz then return nil end
    local held, grade = exports['rsg-core']:HasPlayerJob(src, biz.job)
    if not held then return Player, nil, false end
    local job = Player.PlayerData.job or {}
    local onDuty = job.name == biz.job and job.onduty == true
    return Player, tonumber(grade) or 0, onDuty
end

function POB.HasPerm(grade, perm)
    if grade == nil then return false end
    if grade >= Config.OwnerGrade then return true end
    local need = Config.Permissions[perm]
    return need ~= nil and grade >= need
end

-- Returns Player, grade when src may do perm (optionally on duty), else nil (and notifies)
function POB.Require(src, biz, perm, needDuty)
    local Player, grade, onDuty = POB.Employment(src, biz)
    if not Player then return nil end
    if not biz.owner then POB.Notify(src, locale('biz_closed'), 'error') return nil end
    if not POB.HasPerm(grade, perm) then POB.Notify(src, locale('no_permission'), 'error') return nil end
    if needDuty and not onDuty then POB.Notify(src, locale('need_duty'), 'error') return nil end
    return Player, grade, onDuty
end

function POB.Perms(grade)
    local out = {}
    for perm in pairs(Config.Permissions) do out[perm] = POB.HasPerm(grade, perm) end
    return out
end

-- Item may be stocked in this business
function POB.ItemAllowed(biz, name)
    local t = POB.Type(biz)
    local item = RSGCore.Shared.Items[name]
    if not t or not t.shop or not item then return false end
    if POB.CustomItemOwner and POB.CustomItemOwner(name) == biz.id then return true end
    local s = t.stock or {}
    for _, n in ipairs(s.items or {}) do if n == name then return true end end
    for _, c in ipairs(s.categories or {}) do if item.category == c then return true end end
    return false
end

---------------------------------------------------------------------
-- Rows <-> objects
---------------------------------------------------------------------
local function decode(s, default)
    if type(s) ~= 'string' or s == '' then return default end
    local ok, d = pcall(json.decode, s)
    return ok and d or default
end

local function rowToBiz(row)
    local points = decode(row.points, {})
    points.craft = points.craft or {}
    points.stash = points.stash or {}
    local settings = decode(row.settings, {})
    settings.wages = settings.wages or {}
    settings.training = settings.training or {}
    return {
        id = row.id, type = row.type, label = row.label, price = tonumber(row.price) or 0,
        owner = row.owner_cid and { cid = row.owner_cid, name = row.owner_name or '?' } or nil,
        npcModel = row.npc_model, blip = decode(row.blip, { enabled = true }),
        points = points, settings = settings,
        shopId = row.shop_id, hotelId = row.hotel_id, rooms = row.rooms or 0,
        taxDue = row.tax_due, taxOwedSince = row.tax_owed_since,
        job = Config.JobPrefix .. row.id,
    }
end

function POB.SaveBiz(biz)
    MySQL.update.await([[UPDATE grumpy_pob_businesses SET type = ?, label = ?, price = ?, owner_cid = ?, owner_name = ?,
        npc_model = ?, blip = ?, points = ?, settings = ?, shop_id = ?, hotel_id = ?, rooms = ?, tax_due = ?, tax_owed_since = ?
        WHERE id = ?]], {
        biz.type, biz.label, biz.price, biz.owner and biz.owner.cid, biz.owner and biz.owner.name,
        biz.npcModel, json.encode(biz.blip), json.encode(biz.points), json.encode(biz.settings),
        biz.shopId, biz.hotelId, biz.rooms, biz.taxDue, biz.taxOwedSince, biz.id,
    })
end

function POB.InsertBiz(biz, createdBy)
    local id = MySQL.insert.await([[INSERT INTO grumpy_pob_businesses
        (type, label, price, npc_model, blip, points, settings, rooms, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        biz.type, biz.label, biz.price, biz.npcModel, json.encode(biz.blip), json.encode(biz.points),
        json.encode(biz.settings or {}), biz.rooms or 0, createdBy,
    })
    if not id then return nil end
    local row = MySQL.single.await('SELECT * FROM grumpy_pob_businesses WHERE id = ?', { id })
    local b = rowToBiz(row)
    POB.Businesses[id] = b
    return b
end

---------------------------------------------------------------------
-- Client sync (no secrets in here)
---------------------------------------------------------------------
function POB.Public(biz)
    local t = POB.Type(biz) or {}
    return {
        id = biz.id, type = biz.type, label = biz.label, owned = biz.owner ~= nil, price = biz.price,
        job = biz.job, npcModel = biz.npcModel, blip = biz.blip, points = biz.points,
        shop = t.shop == true, crafting = t.crafting == true, hotel = t.hotel ~= nil,
        stable = t.stable ~= nil, training = t.training == true and Config.Training.Enabled,
        shopId = biz.shopId, hotelId = biz.hotelId,
    }
end

function POB.PublicList()
    local list = {}
    for _, biz in pairs(POB.Businesses) do list[#list + 1] = POB.Public(biz) end
    return list
end

function POB.Broadcast() TriggerClientEvent('grumpy-pob:client:sync', -1, POB.PublicList()) end

RegisterNetEvent('grumpy-pob:server:requestSync', function()
    local src = source
    if POB.Cooldown(src, 'sync', 3000) then return end
    TriggerClientEvent('grumpy-pob:client:sync', src, POB.PublicList())
end)

---------------------------------------------------------------------
-- Load
---------------------------------------------------------------------
function POB.AfterLoad(fn) POB.loadHooks[#POB.loadHooks + 1] = fn end

local function createTables()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'install.sql')
    if not sql then return print('^1[grumpy-pob] install.sql missing^7') end
    for stmt in sql:gmatch('CREATE TABLE.-;') do MySQL.query.await(stmt) end
end

MySQL.ready(function()
    if Config.AutoDatabase then createTables() end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM grumpy_pob_businesses') or {}) do
        if Config.Types[row.type] then
            POB.Businesses[row.id] = rowToBiz(row)
        else
            print(('^3[grumpy-pob] business %d has unknown type "%s" (not loaded)^7'):format(row.id, row.type))
        end
    end
    POB.Ready = true
    for _, fn in ipairs(POB.loadHooks) do
        local ok, err = pcall(fn)
        if not ok then print('^1[grumpy-pob] load hook: ' .. tostring(err) .. '^7') end
    end
    POB.Broadcast()
    print(('^2[grumpy-pob] %d businesses loaded^7'):format(#POB.PublicList()))
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('GetBusinesses', function() return POB.PublicList() end)
exports('GetBusiness', function(id) local b = POB.Biz(id) return b and POB.Public(b) or nil end)
exports('GetBusinessByJob', function(job)
    for _, b in pairs(POB.Businesses) do if b.job == job then return POB.Public(b) end end
    return nil
end)
