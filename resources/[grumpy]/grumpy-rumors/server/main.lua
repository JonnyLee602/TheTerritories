RSGCore = exports['rsg-core']:GetCoreObject()

local ITEM = Config.Item.name
local JobTypes = {}        -- [type] = { start, canStart, available, resource }
local RumorCooldown = {}   -- [rumorId] = os.time() it can be handed out again
local AskCooldown = {}     -- [citizenid] = { [informantId] = os.time() it can be asked again }
local actCooldown = {}     -- [src] = GetGameTimer()

local RumorsById, InformantsById = {}, {}
for _, r in ipairs(Config.Rumors) do RumorsById[r.id] = r end
for _, i in ipairs(Config.Informants) do InformantsById[i.id] = i end

local function notify(src, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = description, type = nType or 'inform', duration = 6000 })
end

local function hasValue(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

local function tierOf(src)
    return exports['grumpy-reputation']:GetTier(src) or 'neutral'
end

local function groupsRunning() return GetResourceState('grumpy-groups') == 'started' end

-----------------------------------------------------------------------
-- item: register with rsg-core if items.lua doesn't have it
-----------------------------------------------------------------------
CreateThread(function()
    if RSGCore.Shared.Items[ITEM] then return end
    local def = {
        name = ITEM, label = Config.Item.label, weight = Config.Item.weight, type = 'item', image = Config.Item.image,
        unique = true, useable = true, shouldClose = true, description = Config.Item.description, category = 'documents',
    }
    local ok = pcall(function() exports['rsg-core']:AddItem(ITEM, def) end)
    if not ok then print(('^1[grumpy-rumors] could not register item %s, add it to rsg-core/shared/items.lua^7'):format(ITEM)) end
end)

-----------------------------------------------------------------------
-- job types (registered by job resources)
-----------------------------------------------------------------------
---@param name string
---@param def function|table  start fn, or { start = fn, canStart = fn?, available = fn? }
local function RegisterJobType(name, def)
    if type(name) ~= 'string' then return false end
    if type(def) == 'function' or (type(def) == 'table' and rawget(def, '__cfx_functionReference')) then def = { start = def } end
    if type(def) ~= 'table' or not def.start then return false end
    JobTypes[name] = { start = def.start, canStart = def.canStart, available = def.available, resource = GetInvokingResource() or GetCurrentResourceName() }
    if Config.Debug then print(('[grumpy-rumors] job type "%s" registered by %s'):format(name, JobTypes[name].resource)) end
    return true
end

AddEventHandler('onResourceStop', function(res)
    for name, jt in pairs(JobTypes) do
        if jt.resource == res and res ~= GetCurrentResourceName() then JobTypes[name] = nil end
    end
end)

Rumors = { RegisterJobType = RegisterJobType }

-----------------------------------------------------------------------
-- notes
-----------------------------------------------------------------------
local function noteData(item)
    local r = item and type(item.info) == 'table' and item.info.rumor
    return type(r) == 'table' and r or nil
end

local function playerNotes(src)
    local out = {}
    for _, it in ipairs(exports['rsg-inventory']:GetItemsByName(src, ITEM) or {}) do
        out[#out + 1] = it
    end
    return out
end

local function holdsRumor(src, rumorId)
    for _, it in ipairs(playerNotes(src)) do
        local d = noteData(it)
        if d and d.id == rumorId then return true end
    end
    return false
end

local function makeInfo(rumor, Player)
    local expires = os.time() + rumor.lifetime
    return {
        [locale('info_rumor')] = locale(rumor.title),
        [locale('info_good_until')] = os.date(locale('date_format'), expires),
        rumor = {
            id = rumor.id,
            serial = ('%x%06x'):format(os.time(), math.random(0, 0xFFFFFF)),
            expires = expires,
            issuedTo = Player.PlayerData.citizenid,
        },
    }
end

local function jobReady(rumor)
    if not rumor.job then return true end
    local jt = JobTypes[rumor.job.type]
    if not jt then return false end
    if jt.available then
        local ok, res = pcall(jt.available, rumor.job.args or {})
        return ok and res ~= false
    end
    return true
end

local function qualifies(src, rumor, tier, categories, now)
    if categories and not hasValue(categories, rumor.category) then return false end
    if not hasValue(rumor.tiers, tier) then return false end
    if (RumorCooldown[rumor.id] or 0) > now then return false end
    if not jobReady(rumor) then return false end
    if holdsRumor(src, rumor.id) then return false end
    return true
end

local function pickRumor(src, categories)
    local tier, now, pool, total = tierOf(src), os.time(), {}, 0
    for _, r in ipairs(Config.Rumors) do
        if qualifies(src, r, tier, categories, now) then
            pool[#pool + 1] = r
            total = total + (r.weight or 1)
        end
    end
    if total <= 0 then return nil end
    local roll = math.random() * total
    for _, r in ipairs(pool) do
        roll = roll - (r.weight or 1)
        if roll <= 0 then return r end
    end
    return pool[#pool]
end

---Give a rumor note. Returns true on success. Does not charge money.
local function giveNote(src, rumor)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not rumor then return false end
    if not exports['rsg-inventory']:CanAddItem(src, ITEM, 1) then return false, 'inventory_full' end
    local ok = exports['rsg-inventory']:AddItem(src, ITEM, 1, makeInfo(rumor, Player), nil, 'grumpy-rumors:' .. rumor.id)
    return ok and true or false, ok and nil or 'inventory_full'
end

-----------------------------------------------------------------------
-- asking for a rumor (informants, and traders through the Ask export)
-----------------------------------------------------------------------
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

-- the whole price comes from the first money type in the list the player can cover
local function charge(Player, price, payWith, reason)
    for _, mt in ipairs(payWith) do
        if (tonumber(Player.PlayerData.money[mt]) or 0) >= price and Player.Functions.RemoveMoney(mt, price, reason) then return mt end
    end
end

---@param o table { key, categories, price, payWith?, cooldown?, reason?, noMoney? } (checked by the caller: distance etc.)
local function askFor(src, o)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local now = os.time()
    local cid = Player.PlayerData.citizenid
    AskCooldown[cid] = AskCooldown[cid] or {}
    if (AskCooldown[cid][o.key] or 0) > now then notify(src, locale('ask_too_soon'), 'error') return false end
    if #playerNotes(src) >= Config.MaxNotes then notify(src, locale('too_many_notes'), 'error') return false end

    local rumor = pickRumor(src, o.categories)
    if not rumor then
        -- nothing for this player: nothing is charged
        AskCooldown[cid][o.key] = now + Config.NothingCooldown
        notify(src, locale('nothing_' .. (o.categories[1] or 'any')), 'inform')
        return false
    end

    if not exports['rsg-inventory']:CanAddItem(src, ITEM, 1) then notify(src, locale('inventory_full'), 'error') return false end
    local price = math.max(0, round2(tonumber(o.price) or 0))
    local paidWith
    if price > 0 then
        paidWith = charge(Player, price, o.payWith or { 'cash' }, o.reason or 'grumpy-rumors-tip')
        if not paidWith then notify(src, locale(o.noMoney or 'no_cash', ('%.2f'):format(price)), 'error') return false end
    end

    if not giveNote(src, rumor) then
        if paidWith then Player.Functions.AddMoney(paidWith, price, 'grumpy-rumors-refund') end
        notify(src, locale('inventory_full'), 'error')
        return false
    end
    AskCooldown[cid][o.key] = now + (tonumber(o.cooldown) or 0)
    if paidWith then
        notify(src, locale('got_rumor_paid', ('%.2f'):format(price), locale(rumor.title)), 'success')
    else
        notify(src, locale('got_rumor', locale(rumor.title)), 'success')
    end
    return true, rumor.id
end

RegisterNetEvent('grumpy-rumors:server:ask', function(informantId)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    if (actCooldown[src] or 0) > GetGameTimer() then return end
    actCooldown[src] = GetGameTimer() + 2000

    local inf = InformantsById[informantId]
    if not inf or not inf.enabled then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - inf.coords.xyz) > Config.AskDistance + 1.0 then return end
    askFor(src, { key = 'informant:' .. inf.id, categories = inf.categories, price = inf.price, cooldown = inf.cooldown })
end)

-----------------------------------------------------------------------
-- read a note (use the item)
-----------------------------------------------------------------------
local function removeExpired(src, item)
    exports['rsg-inventory']:RemoveItem(src, ITEM, 1, item.slot, 'grumpy-rumors-expired')
    notify(src, locale('note_faded'), 'inform')
end

local function groupPreview(src, rumor)
    local job = rumor.job
    if not job or job.group == 'solo' or not groupsRunning() then return 0, nil end
    local members, kind = exports['grumpy-groups']:GetMembers(src, job.group or 'auto', { radius = job.radius })
    return math.max(0, #members - 1), kind
end

RSGCore.Functions.CreateUseableItem(ITEM, function(source, item)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    local d = noteData(item)
    local rumor = d and RumorsById[d.id]
    if not rumor then return notify(src, locale('note_blank'), 'error') end
    local left = (tonumber(d.expires) or 0) - os.time()
    if left <= 0 then return removeExpired(src, item) end

    local others, kind = groupPreview(src, rumor)
    TriggerClientEvent('grumpy-rumors:client:read', src, {
        slot = item.slot, serial = d.serial,
        title = locale(rumor.title), text = locale(rumor.text),
        remaining = left,
        canAct = rumor.job ~= nil,
        group = rumor.job and (others > 0 and locale('group_' .. kind, others) or locale('group_solo')) or nil,
    })
end)

-----------------------------------------------------------------------
-- act on a note
-----------------------------------------------------------------------
RegisterNetEvent('grumpy-rumors:server:act', function(slot, serial)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    slot = tonumber(slot)
    if not Player or not slot or type(serial) ~= 'string' then return end
    if (actCooldown[src] or 0) > GetGameTimer() then return end
    actCooldown[src] = GetGameTimer() + 2000

    local item = exports['rsg-inventory']:GetItemBySlot(src, slot)
    local d = item and item.name == ITEM and noteData(item)
    if not d or d.serial ~= serial then return notify(src, locale('note_missing'), 'error') end
    local rumor = RumorsById[d.id]
    if not rumor or not rumor.job then return end
    if (tonumber(d.expires) or 0) <= os.time() then return removeExpired(src, item) end
    if not hasValue(rumor.tiers, tierOf(src)) then return notify(src, locale('not_your_kind'), 'error') end

    local job = rumor.job
    local jt = JobTypes[job.type]
    if not jt then return notify(src, locale('job_unavailable'), 'error') end
    local args = job.args or {}

    local members, kind, groupId = { src }, nil, nil
    if job.group ~= 'solo' and groupsRunning() then
        members, kind, groupId = exports['grumpy-groups']:GetMembers(src, job.group or 'auto', { radius = job.radius })
    end
    local ctx = { rumorId = rumor.id, kind = kind, groupId = groupId, reader = src }

    if jt.canStart then
        local ok, okRes, why = pcall(jt.canStart, src, args, members, ctx)
        if not ok or okRes == false then return notify(src, (ok and why) or locale('job_unavailable'), 'error') end
    end

    -- the note is spent before the job starts; it's handed back if the job fails to start
    if not exports['rsg-inventory']:RemoveItem(src, ITEM, 1, slot, 'grumpy-rumors-acted') then return end
    local ok, started = pcall(jt.start, src, args, members, ctx)
    if not ok or started == false then
        if not ok then print(('^1[grumpy-rumors] job type "%s" errored: %s^7'):format(job.type, tostring(started))) end
        exports['rsg-inventory']:AddItem(src, ITEM, 1, item.info, nil, 'grumpy-rumors-refund')
        return notify(src, locale('job_unavailable'), 'error')
    end

    if (rumor.cooldown or 0) > 0 then RumorCooldown[rumor.id] = os.time() + rumor.cooldown end
    notify(src, locale('acted'), 'success')
    local name = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    for _, id in ipairs(members) do
        if id ~= src then notify(id, locale('shared_with_you', name), 'inform') end
    end
    TriggerEvent('grumpy-rumors:server:acted', src, rumor.id, members, ctx)
end)

-----------------------------------------------------------------------
-- expired note sweep (pockets only; notes in stashes are checked when read)
-----------------------------------------------------------------------
local function sweep(src)
    local now, removed = os.time(), 0
    for _, it in ipairs(playerNotes(src)) do
        local d = noteData(it)
        if not d or (tonumber(d.expires) or 0) <= now then
            if exports['rsg-inventory']:RemoveItem(src, ITEM, 1, it.slot, 'grumpy-rumors-expired') then removed = removed + 1 end
        end
    end
    if removed > 0 then notify(src, locale('notes_faded', removed), 'inform') end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData.source
    if src then SetTimeout(5000, function() if RSGCore.Functions.GetPlayer(src) then sweep(src) end end) end
end)

CreateThread(function()
    while true do
        Wait(Config.SweepInterval * 1000)
        for _, src in ipairs(RSGCore.Functions.GetPlayers()) do sweep(src) end
    end
end)

AddEventHandler('playerDropped', function() actCooldown[source] = nil end)

-----------------------------------------------------------------------
-- exports
-----------------------------------------------------------------------
exports('RegisterJobType', RegisterJobType)
exports('GiveRumor', function(src, rumorId)
    local rumor = RumorsById[rumorId]
    if not rumor then return false end
    return (giveNote(src, rumor))
end)
exports('GetRumor', function(id) return RumorsById[id] end)
exports('CountNotes', function(src) return #playerNotes(src) end)

-- For other resources (grumpy-trader) that have already checked the player is at their NPC.
-- opts = { key = 'trader:<id>', categories = { 'legal' }, price = 0, payWith = { 'cash' }, cooldown = 1800,
--          reason = 'money reason', noMoney = 'locale key' }. Returns ok, rumorId.
exports('Ask', function(src, opts)
    src = tonumber(src)
    if not src or type(opts) ~= 'table' or type(opts.key) ~= 'string' or type(opts.categories) ~= 'table' then return false end
    if (actCooldown[src] or 0) > GetGameTimer() then return false end
    actCooldown[src] = GetGameTimer() + 2000
    local payWith = {}
    for _, mt in ipairs(type(opts.payWith) == 'table' and opts.payWith or { 'cash' }) do
        if type(mt) == 'string' then payWith[#payWith + 1] = mt end
    end
    return askFor(src, {
        key = opts.key, categories = opts.categories, price = tonumber(opts.price) or 0, payWith = payWith,
        cooldown = tonumber(opts.cooldown) or 0, reason = type(opts.reason) == 'string' and opts.reason or nil,
        noMoney = type(opts.noMoney) == 'string' and opts.noMoney or nil,
    })
end)
