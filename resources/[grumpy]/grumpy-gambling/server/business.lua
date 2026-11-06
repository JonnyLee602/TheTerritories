-- Business (POB) tables (DESIGN.md §9). A grumpy-pob owner places a table in their business with an item. The table's
-- cashbox belongs to the placer and holds the table's money (cash or bloodmoney): the business share of the rake, and
-- at dealer tables the house's float (it pays players' wins and keeps their losses).
--
-- Losing the business (grumpy-pob:server:ownerChanged):
--   unpaid tax  -> the tables are repossessed: clean boxes go to the government account, dirty boxes are destroyed
--   any other   -> the tables close; the owner can still empty the box and pack up, or after AbandonDays it's done
--                  for them (money and item owed at their next login). Buying the business back reopens them.
-- A law seizure on the business (grumpy-pob:server:seized) destroys its dirty boxes.
--
-- Ledger (change in money the core holds): box_in +, box_out -, box_gov -, box_sink -, box_seized -.
local Biz = {}
GG.Biz = Biz
local B = Config.Business
local M = GG.M
local json = json

---------------------------------------------------------------------
-- grumpy-pob
---------------------------------------------------------------------
local function pobUp() return GetResourceState(B.PobResource) == 'started' end

local function pob(fn, ...)
    if not pobUp() then return nil end
    local args = table.pack(...)
    local ok, res = pcall(function() return exports[B.PobResource][fn](exports[B.PobResource], table.unpack(args, 1, args.n)) end)
    if not ok then print(('^1[grumpy-gambling] grumpy-pob %s: %s^7'):format(fn, tostring(res))) return nil end
    return res
end
Biz.Pob = pob

local function dist2(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function npcPoint(bizId)
    local b = pob('GetBusiness', bizId)
    return b and b.points and b.points.npc or nil, b
end

---------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------
function Biz.Tables(bizId)
    local list = {}
    for _, t in pairs(GG.Tables.byId) do if t.source == 'business' and t.businessId == bizId then list[#list + 1] = t end end
    return list
end

function Biz.Count(bizId, kind)
    local n = 0
    for _, t in ipairs(Biz.Tables(bizId)) do if t.kind == kind then n = n + 1 end end
    return n
end

function Biz.OwnedBy(cid)
    local list = {}
    for _, t in pairs(GG.Tables.byId) do if t.source == 'business' and t.ownerCid == cid then list[#list + 1] = t.id end end
    table.sort(list)
    return list
end

-- The owner's client needs to know which tables are theirs (the "Manage table" option)
function Biz.PushMine(src)
    local Player = src and GG.Core.Functions.GetPlayer(src)
    if Player then TriggerClientEvent('grumpy-gambling:client:myTables', src, Biz.OwnedBy(Player.PlayerData.citizenid)) end
end

local function pushMineCid(cid)
    local Player = GG.Core.Functions.GetPlayerByCitizenId(cid)
    if Player then Biz.PushMine(Player.PlayerData.source) end
end

-- A dealer table offers a tier only if its box can cover PvdCoverMaxBets of the tier's biggest bet; the owner may
-- narrow the tiers further (settings.tiers)
function Biz.TierAllowed(t, tierId, tier)
    local s = t.settings or {}
    if type(s.tiers) == 'table' and next(s.tiers) and not s.tiers[tierId] then return false end
    if t.kind == 'pvd' then
        local maxBet = M.ToCents(tier.bigBlind) * Config.Pvd.MaxBetMultiplier
        if GG.House.Balance(t) < maxBet * B.PvdCoverMaxBets then return false end
    end
    return true
end

---------------------------------------------------------------------
-- Placing a table (the items)
---------------------------------------------------------------------
-- The business the player owns whose NPC they're standing near
local function ownedHere(src, cid)
    local pos = GG.PlayerCoords(src)
    if not pos then return nil end
    local best, bestD
    for _, b in ipairs(pob('GetOwnedBusinesses', cid) or {}) do
        if b.npc then
            local d = dist2(pos, b.npc)
            if d <= B.MaxDistanceFromNpc + 5.0 and (not bestD or d < bestD) then best, bestD = b, d end
        end
    end
    return best
end

local function kindOfItem(name)
    for kind, item in pairs(B.Items) do if item == name then return kind end end
end

function Biz.StartPlace(src, kind)
    if not B.Enabled then return end
    local Player = GG.Core.Functions.GetPlayer(src)
    if not Player or GG.Cooldown(src, 'bizPlace', 2000) then return end
    if not pobUp() then return GG.Notify(src, locale('biz_no_pob'), 'error') end
    if GG.Seats.bySrc[src] then return GG.Notify(src, locale('already_seated'), 'error') end
    local cid = Player.PlayerData.citizenid
    local owned = pob('GetOwnedBusinesses', cid) or {}
    if #owned == 0 then return GG.Notify(src, locale('biz_not_owner'), 'error') end
    local b = ownedHere(src, cid)
    if not b then return GG.Notify(src, locale('biz_too_far_npc', math.floor(B.MaxDistanceFromNpc)), 'error') end
    if Biz.Count(b.id, kind) >= (B.MaxTables[kind] or 0) then
        return GG.Notify(src, locale('biz_max_tables', B.MaxTables[kind] or 0), 'error')
    end
    local currencies = { 'cash' }
    if not B.BackroomForBloodmoney or b.backroom then currencies[2] = 'bloodmoney' end
    TriggerClientEvent('grumpy-gambling:client:bizPlace', src, {
        kind = kind, model = B.Models[kind], businessId = b.id, business = b.label, npc = b.npc,
        maxDistance = B.MaxDistanceFromNpc, currencies = currencies, backroom = b.backroom == true,
        label = locale(kind == 'pvp' and 'biz_default_label_pvp' or 'biz_default_label_pvd', b.label),
    })
end

for kind, item in pairs(B.Items) do
    GG.Core.Functions.CreateUseableItem(item, function(source) Biz.StartPlace(source, kind) end)
end

RegisterNetEvent('grumpy-gambling:server:bizCreate', function(d)
    local src = source
    if not B.Enabled or GG.Cooldown(src, 'bizCreate', 2000) or type(d) ~= 'table' then return end
    local Player = GG.Core.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local kind = (d.kind == 'pvp' or d.kind == 'pvd') and d.kind or nil
    local item = kind and B.Items[kind]
    local model = kind and B.Models[kind]
    if not item or not model or not Models[model] or not Models[model].spawn then return end
    local bizId = GG.Int(d.businessId)
    if not bizId or not pob('IsOwner', bizId, cid) then return GG.Notify(src, locale('biz_not_owner'), 'error') end
    local label = GG.Str(d.label, 60) or locale(kind == 'pvp' and 'biz_default_label_pvp' or 'biz_default_label_pvd', '')
    local currency = d.currency == 'bloodmoney' and 'bloodmoney' or 'cash'
    if currency == 'bloodmoney' and B.BackroomForBloodmoney and not pob('HasBackroom', bizId) then
        return GG.Notify(src, locale('biz_need_backroom'), 'error')
    end
    if type(d.coords) ~= 'table' or not GG.Finite(d.coords.x) or not GG.Finite(d.coords.y) or not GG.Finite(d.coords.z)
        or not GG.Finite(tonumber(d.heading)) then return end
    local coords = vector3(d.coords.x + 0.0, d.coords.y + 0.0, d.coords.z + 0.0)
    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, Config.PlaceDistance) then return GG.Notify(src, locale('too_far'), 'error') end
    local npc = npcPoint(bizId)
    if not npc or dist2(coords, npc) > B.MaxDistanceFromNpc then
        return GG.Notify(src, locale('biz_too_far_npc', math.floor(B.MaxDistanceFromNpc)), 'error')
    end
    if Biz.Count(bizId, kind) >= (B.MaxTables[kind] or 0) then return GG.Notify(src, locale('biz_max_tables', B.MaxTables[kind] or 0), 'error') end
    if (exports['rsg-inventory']:GetItemCount(src, item) or 0) < 1 then return GG.Notify(src, locale('biz_no_item'), 'error') end

    local t = GG.Tables.Insert({
        label = label, kind = kind, source = 'business', model = model, bound = false,
        x = coords.x, y = coords.y, z = coords.z, h = Geo.Wrap(tonumber(d.heading)), currency = currency,
        businessId = bizId, ownerCid = cid, settings = { npcs = true },
    }, src)
    if not t then return GG.Notify(src, locale('admin_failed'), 'error') end
    -- the item goes only once the table is saved; if it can't be taken, the table goes again
    if not exports['rsg-inventory']:RemoveItem(src, item, 1, nil, 'grumpy-gambling:place') then
        t.packing = true
        GG.Tables.Delete(t)
        return GG.Notify(src, locale('biz_no_item'), 'error')
    end
    GG.Notify(src, locale(kind == 'pvd' and 'biz_placed_pvd' or 'biz_placed_pvp', t.label), 'success')
    print(('[grumpy-gambling] %s placed business table %d (%s, %s) in business %d'):format(cid, t.id, kind, currency, bizId))
    Biz.PushMine(src)
end)

---------------------------------------------------------------------
-- Cashbox money
---------------------------------------------------------------------
local function box(t) return GG.House.Balance(t) end

local function boxMove(t, deltaC, kind, cid, note)
    if deltaC == 0 then return true end
    if not GG.DB.CashboxAdjust(t.id, t.currency, deltaC) then return false end
    GG.House.boxes[t.id] = (GG.House.boxes[t.id] or 0) + deltaC
    GG.DB.Ledger({ kind = kind, tableId = t.id, cid = cid, currency = t.currency, amount = deltaC, note = note })
    return true
end

-- What the owner can take out now (open hands may have reserved cover)
function Biz.Withdrawable(t) return math.max(0, box(t) - GG.Hands.Reserved(t.id)) end

---------------------------------------------------------------------
-- Closing, packing up, repossession
---------------------------------------------------------------------
local function closeForPlay(t, reason)
    GG.Seats.StandAll(t, reason)
    if GG.Tables.RealCount(t) == 0 and t.state ~= 'empty' then GG.Tables.Reset(t, 'closed') end
end

local function removeTable(t)
    GG.DB.CashboxDelete(t.id)
    GG.House.boxes[t.id] = nil
    t.packing = true
    GG.Tables.Delete(t)
end

-- Box to the owner (now if online, else at login) and the item back. src = the owner standing there, or nil.
function Biz.PackUp(t, src, why)
    closeForPlay(t, 'biz_table_packed')
    if GG.Hands.ForTable(t.id) then return false, 'biz_hand_open' end
    local cid = t.ownerCid
    local bal = box(t)
    if bal > 0 then
        GG.DB.CashboxAdjust(t.id, t.currency, -bal)
        GG.Wallet.PayOrPend(cid, t.currency, bal, 'box_out', t.id)
    end
    local item = B.Items[t.kind]
    local given = false
    if src and item then
        given = exports['rsg-inventory']:AddItem(src, item, 1, nil, nil, 'grumpy-gambling:packup') == true
    end
    if item and not given then GG.DB.PendingItemAdd(cid, item, 1) end
    print(('[grumpy-gambling] business table %d packed up (%s): %s and the item to %s'):format(t.id, why or 'owner', M.Fmt(bal), cid))
    removeTable(t)
    pushMineCid(cid)
    return true, bal, given
end

-- Unpaid tax: the table is taken. Clean money goes to the government, dirty money is destroyed. No item back.
function Biz.Repossess(t)
    closeForPlay(t, 'biz_table_repossessed')
    local h = GG.Hands.ForTable(t.id)
    if h then GG.Hands.Cancel(h.id, 'repossessed') end
    local bal = box(t)
    if bal > 0 then
        GG.DB.CashboxAdjust(t.id, t.currency, -bal)
        if t.currency == 'cash' and pob('AddGovMoney', M.ToDollars(bal), locale('biz_gov_note', t.label)) == true then
            GG.DB.Ledger({ kind = 'box_gov', tableId = t.id, cid = t.ownerCid, currency = t.currency, amount = -bal })
        else
            GG.DB.Ledger({ kind = 'box_sink', tableId = t.id, cid = t.ownerCid, currency = t.currency, amount = -bal })
        end
    end
    local Player = GG.Core.Functions.GetPlayerByCitizenId(t.ownerCid)
    if Player then GG.Notify(Player.PlayerData.source, locale('biz_repossessed_owner', t.label), 'error') end
    print(('[grumpy-gambling] business table %d repossessed (%s %s)'):format(t.id, M.Fmt(bal), t.currency))
    local cid = t.ownerCid
    removeTable(t)
    pushMineCid(cid)
end

function Biz.SetOrphaned(t, on)
    t.settings = t.settings or {}
    if on and not t.settings.orphaned then
        t.settings.orphaned = os.time()
        closeForPlay(t, 'biz_table_orphaned')
        local Player = GG.Core.Functions.GetPlayerByCitizenId(t.ownerCid)
        if Player then GG.Notify(Player.PlayerData.source, locale('biz_orphaned_owner', t.label, B.AbandonDays), 'error') end
    elseif not on and t.settings.orphaned then
        t.settings.orphaned = nil
    else
        return
    end
    GG.Tables.SaveSettings(t)
    GG.Tables.Sync(t)
end

function Biz.CheckRange(bizId)
    local npc = npcPoint(bizId)
    for _, t in ipairs(Biz.Tables(bizId)) do
        local out = npc ~= nil and dist2(t, npc) > B.MaxDistanceFromNpc + 0.5
        if out ~= (t.settings.outOfRange == true) then
            t.settings.outOfRange = out or nil
            if out then closeForPlay(t, 'biz_table_out_of_range') end
            GG.Tables.SaveSettings(t)
            GG.Tables.Sync(t)
        end
    end
end

-- Brings every business table in line with grumpy-pob (on start, and when grumpy-pob starts)
function Biz.Reconcile()
    if not pobUp() then return end
    local seen = {}
    for _, t in pairs(GG.Tables.byId) do
        if t.source == 'business' then
            t.settings = t.settings or {}
            Biz.SetOrphaned(t, not pob('IsOwner', t.businessId, t.ownerCid))
            if t.businessId and not seen[t.businessId] then seen[t.businessId] = true; Biz.CheckRange(t.businessId) end
        end
    end
end

GG.AfterLoad(function()
    CreateThread(function()
        local waited = 0
        while not pobUp() and waited < 60000 do Wait(1000); waited = waited + 1000 end
        while pobUp() and not pob('IsReady') and waited < 120000 do Wait(1000); waited = waited + 1000 end
        Biz.Reconcile()
    end)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= B.PobResource or not GG.Ready then return end
    CreateThread(function()
        local waited = 0
        while not pob('IsReady') and waited < 120000 do Wait(1000); waited = waited + 1000 end
        Biz.Reconcile()
    end)
end)

AddEventHandler('grumpy-pob:server:ownerChanged', function(bizId, oldCid, newCid, reason)
    for _, t in ipairs(Biz.Tables(bizId)) do
        if newCid and newCid == t.ownerCid then
            Biz.SetOrphaned(t, false)         -- the placer owns the business again
        elseif oldCid == t.ownerCid or newCid then
            if reason == 'tax' then Biz.Repossess(t) else Biz.SetOrphaned(t, true) end
        end
    end
end)

AddEventHandler('grumpy-pob:server:businessChanged', function(bizId) Biz.CheckRange(bizId) end)

-- Law seized the business's laundered money: its dirty cashboxes go too (destroyed; the government account is clean)
function Biz.Seize(bizId, lawSrc)
    local total = 0
    for _, t in ipairs(Biz.Tables(bizId)) do
        if t.currency == 'bloodmoney' then
            local take = Biz.Withdrawable(t)
            if take > 0 and boxMove(t, -take, 'box_seized', t.ownerCid, lawSrc and GetPlayerName(lawSrc) or nil) then
                total = total + take
                local Player = GG.Core.Functions.GetPlayerByCitizenId(t.ownerCid)
                if Player then GG.Notify(Player.PlayerData.source, locale('biz_seized_owner', t.label, M.Fmt(take)), 'error') end
            end
        end
    end
    if total > 0 and lawSrc then GG.Notify(lawSrc, locale('biz_seized_law', M.Fmt(total)), 'success') end
    return total
end
AddEventHandler('grumpy-pob:server:seized', function(bizId, lawSrc) Biz.Seize(bizId, lawSrc) end)

-- Abandoned tables (owner lost the business and never came back) are packed up for them
CreateThread(function()
    while true do
        Wait(30 * 60000)
        if GG.Ready then
            local limit = os.time() - B.AbandonDays * 86400
            for _, t in pairs(GG.Tables.byId) do
                if t.source == 'business' and t.settings and t.settings.orphaned and t.settings.orphaned < limit then
                    Biz.PackUp(t, nil, 'abandoned')
                end
            end
        end
    end
end)

-- Items owed from a pack-up while offline
function Biz.GiveOwed(Player)
    local src = Player.PlayerData.source
    for _, r in ipairs(GG.DB.PendingItems(Player.PlayerData.citizenid)) do
        if exports['rsg-inventory']:AddItem(src, r.item, r.amount, nil, nil, 'grumpy-gambling:owed') then
            GG.DB.PendingItemDone(r.id)
            GG.Notify(src, locale('biz_item_returned'), 'success')
        end
    end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not GG.Ready or not Player then return end
    Biz.GiveOwed(Player)
    Biz.PushMine(Player.PlayerData.source)
end)

---------------------------------------------------------------------
-- The owner's panel
---------------------------------------------------------------------
-- Player and table when src is this table's owner standing at it (active = they still own the business)
local function ownerAt(src, tableId)
    local Player = GG.Core.Functions.GetPlayer(src)
    local t = GG.Tables.Get(tableId)
    if not Player or not t or t.source ~= 'business' or t.ownerCid ~= Player.PlayerData.citizenid then return nil end
    local pos = GG.PlayerCoords(src)
    if not pos or #(pos - vector3(t.x, t.y, t.z)) > B.ManageDistance + 2.0 then
        GG.Notify(src, locale('too_far'), 'error')
        return nil
    end
    return Player, t, not (t.settings and t.settings.orphaned)
end

function Biz.PanelData(t)
    local stats = GG.DB.BoxStats(t.id)
    local tiers = {}
    for id, tier in pairs(Config.Tiers) do
        if tier.choosable and (t.currency ~= 'bloodmoney' or tier.bloodmoney) then
            local cover = t.kind == 'pvd' and M.ToCents(tier.bigBlind) * Config.Pvd.MaxBetMultiplier * B.PvdCoverMaxBets or 0
            tiers[#tiers + 1] = { id = id, label = locale(tier.label), order = tier.order,
                on = not (type(t.settings.tiers) == 'table' and next(t.settings.tiers)) or t.settings.tiers[id] == true,
                cover = cover, covered = box(t) >= cover }
        end
    end
    table.sort(tiers, function(a, b) return a.order < b.order end)
    local usable, why = GG.Tables.Usable(t)
    return {
        id = t.id, label = t.label, kind = t.kind, currency = t.currency, box = box(t), withdrawable = Biz.Withdrawable(t),
        rake = stats.rake, house = stats.house, hands = stats.hands, open = t.enabled, usable = usable,
        status = usable and nil or locale(why), orphaned = t.settings.orphaned ~= nil, npcs = t.settings.npcs ~= false,
        tiers = tiers, seated = GG.Tables.RealCount(t), playing = t.state == 'active',
        abandonDays = B.AbandonDays,
    }
end

GG.Core.Functions.CreateCallback('grumpy-gambling:server:bizPanel', function(source, cb, tableId)
    local _, t = ownerAt(source, GG.Int(tableId))
    cb(t and Biz.PanelData(t) or nil)
end)

local function refreshPanel(src, t) TriggerClientEvent('grumpy-gambling:client:bizPanel', src, t and Biz.PanelData(t) or nil) end

RegisterNetEvent('grumpy-gambling:server:bizAction', function(tableId, action, value)
    local src = source
    if GG.Cooldown(src, 'bizAction', 750) or type(action) ~= 'string' then return end
    local Player, t, active = ownerAt(src, GG.Int(tableId))
    if not Player then return end
    local cid = Player.PlayerData.citizenid

    if action == 'deposit' or action == 'withdraw' then
        local amountC = M.ToCents(value)
        if not amountC or amountC <= 0 then return GG.Notify(src, locale('chips_bad_amount'), 'error') end
        if action == 'deposit' then
            if not active then return GG.Notify(src, locale('biz_table_orphaned'), 'error') end
            if not Player.Functions.RemoveMoney(t.currency, M.ToDollars(amountC), 'grumpy-gambling:box-deposit') then
                return GG.Notify(src, locale('chips_no_money'), 'error')
            end
            if not boxMove(t, amountC, 'box_in', cid) then
                Player.Functions.AddMoney(t.currency, M.ToDollars(amountC), 'grumpy-gambling:box-deposit-refund')
                return GG.Notify(src, locale('admin_failed'), 'error')
            end
            GG.Notify(src, locale('biz_deposited', M.Fmt(amountC)), 'success')
        else
            if amountC > Biz.Withdrawable(t) then return GG.Notify(src, locale('biz_box_short'), 'error') end
            if not boxMove(t, -amountC, 'box_out', cid) then return GG.Notify(src, locale('biz_box_short'), 'error') end
            if not Player.Functions.AddMoney(t.currency, M.ToDollars(amountC), 'grumpy-gambling:box-withdraw') then
                boxMove(t, amountC, 'box_in', cid, 'withdraw refused')
                return GG.Notify(src, locale('admin_failed'), 'error')
            end
            GG.Notify(src, locale('biz_withdrew', M.Fmt(amountC)), 'success')
        end
        if Config.Money.SavePlayer then Player.Functions.Save() end
    elseif action == 'toggle' then
        if not active then return GG.Notify(src, locale('biz_table_orphaned'), 'error') end
        t.enabled = not t.enabled
        if not t.enabled then closeForPlay(t, 'table_closed') end
        GG.Tables.SaveMeta(t)
        GG.Tables.Sync(t)
    elseif action == 'npcs' then
        t.settings.npcs = value == true
        GG.Tables.SaveSettings(t)
    elseif action == 'tiers' then
        if type(value) ~= 'table' then return end
        local tiers = {}
        for id, on in pairs(value) do if Config.Tiers[id] and Config.Tiers[id].choosable and on == true then tiers[id] = true end end
        if not next(tiers) then return GG.Notify(src, locale('biz_need_tier'), 'error') end
        t.settings.tiers = tiers
        GG.Tables.SaveSettings(t)
    elseif action == 'rename' then
        local label = GG.Str(value, 60)
        if not label then return end
        t.label = label
        GG.Tables.SaveMeta(t)
        GG.Tables.Sync(t)
    elseif action == 'packup' then
        if GG.Tables.RealCount(t) > 0 then return GG.Notify(src, locale('admin_table_busy'), 'error') end
        local ok, res, given = Biz.PackUp(t, src, 'owner')
        if not ok then return GG.Notify(src, locale(res), 'error') end
        GG.Notify(src, locale(given and 'biz_packed' or 'biz_packed_owed', M.Fmt(res)), 'success')
        return refreshPanel(src, nil)
    else
        return
    end
    refreshPanel(src, t)
end)

-- Move with rsg-gizmo (nobody seated, still in range of the NPC)
RegisterNetEvent('grumpy-gambling:server:bizMove', function(tableId, coords, heading)
    local src = source
    if GG.Cooldown(src, 'bizMove', 1500) then return end
    local Player, t, active = ownerAt(src, GG.Int(tableId))
    if not Player then return end
    if not active then return GG.Notify(src, locale('biz_table_orphaned'), 'error') end
    if GG.Tables.RealCount(t) > 0 or GG.Hands.ForTable(t.id) then return GG.Notify(src, locale('admin_table_busy'), 'error') end
    if type(coords) ~= 'table' or not GG.Finite(coords.x) or not GG.Finite(coords.y) or not GG.Finite(coords.z)
        or not GG.Finite(tonumber(heading)) then return end
    local c = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    if not exports['rsg-gizmo']:IsPlacementValid(src, c, Config.PlaceDistance) then return GG.Notify(src, locale('too_far'), 'error') end
    local npc = npcPoint(t.businessId)
    if not npc or dist2(c, npc) > B.MaxDistanceFromNpc then
        return GG.Notify(src, locale('biz_too_far_npc', math.floor(B.MaxDistanceFromNpc)), 'error')
    end
    t.x, t.y, t.z, t.h = c.x, c.y, c.z, Geo.Wrap(tonumber(heading))
    GG.Tables.SavePlacement(t)
    if t.settings.outOfRange then t.settings.outOfRange = nil; GG.Tables.SaveSettings(t) end
    GG.Tables.Sync(t)
    GG.Notify(src, locale('admin_moved'), 'success')
    refreshPanel(src, t)
end)

GG.Core.Functions.CreateCallback('grumpy-gambling:server:bizMine', function(source, cb)
    local Player = GG.Core.Functions.GetPlayer(source)
    cb(Player and Biz.OwnedBy(Player.PlayerData.citizenid) or {})
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
-- Dirty money in a business's tables (for law screens)
exports('GetBusinessCashboxes', function(bizId)
    local list = {}
    for _, t in ipairs(Biz.Tables(GG.Int(bizId) or -1)) do
        list[#list + 1] = { tableId = t.id, label = t.label, kind = t.kind, currency = t.currency, balance = box(t) }
    end
    return list
end)

-- For grumpy-pob's "Gambling" tab: per kind, the item, how many tables the business has placed and its limit
exports('GetTableLimits', function(bizId)
    bizId = GG.Int(bizId)
    if not bizId or not B.Enabled then return nil end
    local out = {}
    for kind, item in pairs(B.Items) do
        out[kind] = { item = item, placed = Biz.Count(bizId, kind), max = B.MaxTables[kind] or 0 }
    end
    return out
end)
