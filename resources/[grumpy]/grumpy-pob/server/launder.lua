-- Back room laundering (owner only) and law audits (books warrants, inspection, seizure).
-- The real records live in grumpy_pob_launder. The business ledger only shows "Private sale" lines, so staff
-- who can read the ledger never see what the owner is doing.
local RSGCore = POB.Core()
local Acc = POB.Acc
local L, A = Config.Laundering, Config.Audit

local Launder = {}
POB.Launder = Launder

local INCOME_KINDS = { 'sale', 'rent', 'training' }

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function refresh(src) TriggerClientEvent('grumpy-pob:client:refresh', src, 'manager') end

---------------------------------------------------------------------
-- Back room state
---------------------------------------------------------------------
function Launder.TypeAllows(biz)
    local t = POB.Type(biz)
    return L.Enabled and t ~= nil and t.launder == true
end

-- Bought by the CURRENT owner (a new owner has to buy their own)
function Launder.HasBackroom(biz)
    local br = biz.settings and biz.settings.backroom
    return Launder.TypeAllows(biz) and biz.owner ~= nil and type(br) == 'table' and br.cid == biz.owner.cid
end

-- The real owner standing at the desk (not just someone with the owner grade)
local function ownerAt(src, biz)
    local Player, grade = POB.Employment(src, biz)
    if not Player or not biz.owner or grade ~= Config.OwnerGrade then return nil end
    if Player.PlayerData.citizenid ~= biz.owner.cid then return nil end
    if not POB.Near(src, biz.points.manager) then POB.Notify(src, locale('too_far'), 'error') return nil end
    return Player
end

local function legitIncome(biz, since)
    return tonumber(MySQL.scalar.await(
        ('SELECT COALESCE(SUM(amount), 0) FROM grumpy_pob_ledger WHERE account = ? AND ts >= ? AND kind IN (%s) AND amount > 0')
            :format(table.concat({ '?', '?', '?' }, ',')),
        { POB.AccountId(biz), since, INCOME_KINDS[1], INCOME_KINDS[2], INCOME_KINDS[3] })) or 0
end

local function washedSince(biz, since)
    return tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(dirty), 0) FROM grumpy_pob_launder WHERE business_id = ? AND ts >= ?',
        { biz.id, since })) or 0
end

-- allowance, left (both dirty $) for the current window
function Launder.Allowance(biz)
    local since = os.time() - L.WindowDays * 86400
    local allowance = math.max(L.Floor, round2(legitIncome(biz, since) * L.SalesShare))
    return allowance, math.max(0, round2(allowance - washedSince(biz, since)))
end

local function records(biz, days, limit)
    local rows = MySQL.query.await('SELECT ts, dirty, clean, name, seized FROM grumpy_pob_launder WHERE business_id = ? AND ts >= ? ORDER BY id DESC LIMIT ?',
        { biz.id, os.time() - days * 86400, limit or 100 }) or {}
    for _, r in ipairs(rows) do r.dirty, r.clean, r.seized = tonumber(r.dirty), tonumber(r.clean), r.seized == 1 or r.seized == true end
    return rows
end

-- Manager screen data for the owner (nil for everyone else)
function Launder.ManagerData(src, biz, Player)
    if not Launder.TypeAllows(biz) or not biz.owner or Player.PlayerData.citizenid ~= biz.owner.cid then return nil end
    local d = { owned = Launder.HasBackroom(biz), price = L.Price, cut = L.ServerCut, min = L.MinAmount, windowDays = L.WindowDays }
    if d.owned then
        d.allowance, d.left = Launder.Allowance(biz)
        d.dirty = Player.PlayerData.money.bloodmoney or 0
        d.rows = records(biz, math.max(L.WindowDays, A.LookbackDays), 50)
    end
    return d
end

---------------------------------------------------------------------
-- Buy the back room
---------------------------------------------------------------------
RegisterNetEvent('grumpy-pob:server:buyBackroom', function(id)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'backroom', 3000) then return end
    POB.Lock('money:' .. biz.id, function()
        local Player = ownerAt(src, biz)
        if not Player then return POB.Notify(src, locale('no_permission'), 'error') end
        if not Launder.TypeAllows(biz) then return POB.Notify(src, locale('backroom_not_allowed'), 'error') end
        if Launder.HasBackroom(biz) then return end
        local who = Acc.Who(Player)
        if not Acc.Transfer(POB.AccountId(biz), Acc.GOV, L.Price, 'renovation', who, locale('ledger_renovation')) then
            return POB.Notify(src, locale('not_enough_funds'), 'error')
        end
        biz.settings.backroom = { cid = Player.PlayerData.citizenid, at = os.time() }
        POB.SaveBiz(biz)
        POB.Notify(src, locale('backroom_bought', L.Price), 'success')
        print(('[grumpy-pob] %s bought a back room for business %d "%s"'):format(who.name, biz.id, biz.label))
    end)
    refresh(src)
end)

---------------------------------------------------------------------
-- Tips to the law
---------------------------------------------------------------------
local function lawOnDuty()
    local out = {}
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        local job = P.PlayerData.job or {}
        if A.JobTypes[job.type] and job.onduty then out[#out + 1] = P.PlayerData.source end
    end
    return out
end

local function maybeTip(biz, dirty)
    local T = L.Tip
    if not T or not T.Enabled then return end
    local chance = math.min(T.MaxChance, T.ChancePer100 * dirty / 100)
    if math.random() * 100 >= chance then return end
    local p = biz.points.manager or biz.points.npc
    if not p then return end
    SetTimeout(math.random(T.Delay[1], T.Delay[2]) * 1000, function()
        local coords = POB.Vec(p)
        local text = locale('launder_tip', biz.label)
        for _, s in ipairs(lawOnDuty()) do
            if GetResourceState('rsg-lawman') == 'started' then
                TriggerClientEvent('rsg-lawman:client:lawmanAlert', s, coords, text)
            else
                POB.Notify(s, text, 'inform', locale('law_title'))
            end
        end
        POB.Debug('laundering tip sent for business', biz.id)
    end)
end

---------------------------------------------------------------------
-- Wash dirty money (owner only)
---------------------------------------------------------------------
RegisterNetEvent('grumpy-pob:server:launder', function(id, amount)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'launder', 2000) then return end
    POB.Lock('money:' .. biz.id, function()
        local Player = ownerAt(src, biz)
        if not Player then return POB.Notify(src, locale('no_permission'), 'error') end
        if not Launder.HasBackroom(biz) then return POB.Notify(src, locale('backroom_none'), 'error') end
        amount = POB.Money(tonumber(amount))
        if not amount or amount < L.MinAmount or amount > Config.MaxTransfer then return POB.Notify(src, locale('invalid_amount'), 'error') end
        if (Player.PlayerData.money.bloodmoney or 0) < amount then return POB.Notify(src, locale('launder_no_dirty'), 'error') end
        local _, left = Launder.Allowance(biz)
        if amount > left then
            return POB.Notify(src, left > 0 and locale('launder_limit', left) or locale('launder_limit_none'), 'error')
        end
        local clean = round2(amount * (1 - L.ServerCut / 100))
        if clean < 0.01 then return POB.Notify(src, locale('invalid_amount'), 'error') end

        if not Player.Functions.RemoveMoney('bloodmoney', amount, 'grumpy-pob:launder') then
            return POB.Notify(src, locale('launder_no_dirty'), 'error')
        end
        -- staff see an anonymous "Private sale"; the real record is kept apart
        if not Acc.Add(POB.AccountId(biz), clean, 'private', nil, nil) then
            Player.Functions.AddMoney('bloodmoney', amount, 'grumpy-pob:launder-refund')
            return POB.Notify(src, locale('invalid_amount'), 'error')
        end
        MySQL.insert.await('INSERT INTO grumpy_pob_launder (business_id, ts, dirty, clean, citizenid, name) VALUES (?, ?, ?, ?, ?, ?)',
            { biz.id, os.time(), amount, clean, Player.PlayerData.citizenid, POB.PlayerName(Player) })
        POB.Notify(src, locale('laundered', amount, clean), 'success')
        print(('[grumpy-pob] %s laundered $%.2f -> $%.2f at business %d'):format(POB.PlayerName(Player), amount, clean, biz.id))
        maybeTip(biz, amount)
    end)
    refresh(src)
end)

---------------------------------------------------------------------
-- Law: books warrants
---------------------------------------------------------------------
local function isLaw(Player)
    local job = Player.PlayerData.job or {}
    if not A.JobTypes[job.type] then return false end
    if A.RequireOnDuty and not job.onduty then return false end
    return true
end

local function canIssue(Player)
    if not A.Enabled or not isLaw(Player) then return false end
    local job = Player.PlayerData.job or {}
    return (job.grade and tonumber(job.grade.level) or 0) >= A.MinGrade
end

-- A valid warrant for this business AND its current owner (a new owner needs a new warrant)
local function hasWarrant(src, biz)
    if not A.Enabled or not biz.owner then return false end
    local ok, items = pcall(function() return exports['rsg-inventory']:GetItemsByName(src, A.Item) end)
    if not ok or type(items) ~= 'table' then return false end
    local now = os.time()
    for _, it in ipairs(items) do
        local i = it.info
        if type(i) == 'table' and i.business == biz.id and i.owner == biz.owner.cid and (tonumber(i.expires) or 0) > now then
            return true
        end
    end
    return false
end

local function notifyOwner(biz, key)
    if not A.NotifyOwner or not biz.owner then return end
    local s = POB.SrcByCid(biz.owner.cid)
    if s then POB.Notify(s, locale(key, biz.label), 'error') end
end

RegisterNetEvent('grumpy-pob:server:issueBooksWarrant', function(id)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'warrant', A.Cooldown * 1000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not canIssue(Player) then return POB.Notify(src, locale('no_permission'), 'error') end
    if not biz.owner then return POB.Notify(src, locale('warrant_no_owner'), 'error') end
    if not POB.Near(src, biz.points.manager) then return POB.Notify(src, locale('too_far'), 'error') end
    if not exports['rsg-inventory']:CanAddItem(src, A.Item, 1) then return POB.Notify(src, locale('inventory_full'), 'error') end

    local expires = os.time() + A.Minutes * 60
    local info = {
        business = biz.id, owner = biz.owner.cid, expires = expires, label = biz.label, suspect = biz.owner.name,
        issuer = POB.PlayerName(Player),
        description = locale('warrant_description', biz.label, biz.owner.name, os.date('%Y-%m-%d %H:%M', expires)),
    }
    if not exports['rsg-inventory']:AddItem(src, A.Item, 1, info, nil, 'grumpy-pob:books-warrant') then
        return POB.Notify(src, locale('inventory_full'), 'error')
    end
    POB.Notify(src, locale('warrant_issued', biz.label, A.Minutes), 'success')
    print(('[grumpy-pob] %s (%s) issued a books warrant for business %d "%s" (owner %s)'):format(
        GetPlayerName(src), Player.PlayerData.citizenid, biz.id, biz.label, biz.owner.cid))
end)

if A.Enabled then
    RSGCore.Functions.CreateUseableItem(A.Item, function(source, item)
        local i = item and item.info
        if type(i) ~= 'table' or not i.business then return POB.Notify(source, locale('warrant_blank'), 'error') end
        local left = (tonumber(i.expires) or 0) - os.time()
        if left <= 0 then return POB.Notify(source, locale('warrant_expired', i.label or '?'), 'error') end
        POB.Notify(source, locale('warrant_info', i.label or '?', i.suspect or '?', math.ceil(left / 60)), 'inform')
    end)
end

---------------------------------------------------------------------
-- Law: inspect and seize
---------------------------------------------------------------------
local function auditAccess(src, biz)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not A.Enabled or not isLaw(Player) then return nil, 'no_permission' end
    if not biz.owner then return nil, 'warrant_no_owner' end
    if not POB.Near(src, biz.points.manager) then return nil, 'too_far' end
    if not hasWarrant(src, biz) then return nil, 'warrant_needed' end
    return Player
end

local function auditData(biz)
    local rows = records(biz, A.LookbackDays, 200)
    local open = 0
    for _, r in ipairs(rows) do if not r.seized then open = open + r.clean end end
    return {
        id = biz.id, label = biz.label, owner = biz.owner.name, backroom = Launder.HasBackroom(biz),
        lookbackDays = A.LookbackDays, rows = rows, openTotal = round2(open),
        balance = Acc.Balance(POB.AccountId(biz)), canSeize = A.AllowSeize and open > 0,
    }
end

RSGCore.Functions.CreateCallback('grumpy-pob:server:audit', function(source, cb, id)
    local biz = POB.Biz(id)
    if not biz then return cb(nil) end
    local Player, err = auditAccess(source, biz)
    if not Player then POB.Notify(source, locale(err), 'error') return cb(nil) end
    notifyOwner(biz, 'audit_owner_inspected')
    print(('[grumpy-pob] %s inspected the books of business %d "%s"'):format(GetPlayerName(source), biz.id, biz.label))
    cb(auditData(biz))
end)

RegisterNetEvent('grumpy-pob:server:seize', function(id)
    local src = source
    local biz = POB.Biz(id)
    if not biz or not A.AllowSeize or POB.Cooldown(src, 'seize', 3000) then return end
    POB.Lock('money:' .. biz.id, function()
        local Player, err = auditAccess(src, biz)
        if not Player then return POB.Notify(src, locale(err), 'error') end
        local since = os.time() - A.LookbackDays * 86400
        local open = round2(tonumber(MySQL.scalar.await(
            'SELECT COALESCE(SUM(clean), 0) FROM grumpy_pob_launder WHERE business_id = ? AND ts >= ? AND seized = 0', { biz.id, since })) or 0)
        if open <= 0 then return POB.Notify(src, locale('seize_nothing'), 'error') end
        local take = round2(math.min(open, Acc.Balance(POB.AccountId(biz))))
        if take > 0 and not Acc.Transfer(POB.AccountId(biz), Acc.GOV, take, 'seized', Acc.Who(Player), locale('ledger_seized', POB.PlayerName(Player))) then
            return POB.Notify(src, locale('seize_failed'), 'error')
        end
        MySQL.update.await('UPDATE grumpy_pob_launder SET seized = 1 WHERE business_id = ? AND ts >= ? AND seized = 0', { biz.id, since })
        POB.Notify(src, locale(take < open and 'seized_partial' or 'seized', take, open), 'success')
        notifyOwner(biz, 'audit_owner_seized')
        TriggerEvent('grumpy-pob:server:seized', biz.id, src)
        print(('[grumpy-pob] %s seized $%.2f (of $%.2f laundered) from business %d "%s"'):format(GetPlayerName(src), take, open, biz.id, biz.label))
    end)
    TriggerClientEvent('grumpy-pob:client:auditRefresh', src, id)
end)

---------------------------------------------------------------------
-- Housekeeping
---------------------------------------------------------------------
POB.AfterLoad(function()
    MySQL.update.await('DELETE FROM grumpy_pob_launder WHERE ts < ?', { os.time() - L.KeepDays * 86400 })
end)
