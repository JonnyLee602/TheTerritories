-- Business + government accounts. Every change is one conditional UPDATE (no read-then-write races)
-- followed by a ledger row.
local RSGCore = POB.Core()

local Acc = {}
POB.Acc = Acc
Acc.GOV = 'gov'

function Acc.Ensure(account)
    MySQL.insert.await('INSERT IGNORE INTO grumpy_pob_accounts (account, balance) VALUES (?, 0)', { account })
end

function Acc.Balance(account)
    return tonumber(MySQL.scalar.await('SELECT balance FROM grumpy_pob_accounts WHERE account = ?', { account })) or 0
end

local function log(account, kind, amount, who, note)
    MySQL.insert('INSERT INTO grumpy_pob_ledger (account, ts, kind, amount, balance, who_cid, who_name, note) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        account, os.time(), kind, amount, Acc.Balance(account), who and who.cid, who and who.name, note and tostring(note):sub(1, 255),
    })
end
Acc.Log = log

function Acc.Add(account, amount, kind, who, note)
    amount = POB.Money(amount)
    if not amount or amount <= 0 then return false end
    Acc.Ensure(account)
    MySQL.update.await('UPDATE grumpy_pob_accounts SET balance = balance + ? WHERE account = ?', { amount, account })
    log(account, kind, amount, who, note)
    return true
end

function Acc.Remove(account, amount, kind, who, note)
    amount = POB.Money(amount)
    if not amount or amount <= 0 then return false end
    local changed = MySQL.update.await('UPDATE grumpy_pob_accounts SET balance = balance - ? WHERE account = ? AND balance >= ?', { amount, account, amount })
    if not changed or changed < 1 then return false end
    log(account, kind, -amount, who, note)
    return true
end

function Acc.Transfer(from, to, amount, kind, who, note)
    if not Acc.Remove(from, amount, kind, who, note) then return false end
    Acc.Add(to, amount, kind, who, note)
    return true
end

-- Moves the whole balance (repossession)
function Acc.Drain(from, to, kind, note)
    local bal = Acc.Balance(from)
    if bal <= 0 then return 0 end
    if Acc.Transfer(from, to, bal, kind, nil, note) then return bal end
    return 0
end

function Acc.Ledger(account, page)
    page = POB.Int(page, 0, 10000) or 0
    local rows = MySQL.query.await('SELECT ts, kind, amount, balance, who_name, note FROM grumpy_pob_ledger WHERE account = ? ORDER BY id DESC LIMIT ? OFFSET ?',
        { account, Config.LedgerPageSize, page * Config.LedgerPageSize }) or {}
    for _, r in ipairs(rows) do r.amount = tonumber(r.amount); r.balance = tonumber(r.balance) end
    return rows
end

local function who(Player) return Player and { cid = Player.PlayerData.citizenid, name = POB.PlayerName(Player) } or nil end
Acc.Who = who

---------------------------------------------------------------------
-- Cash in / out for a player (used by business and government screens)
---------------------------------------------------------------------
function Acc.DepositCash(Player, account, amount, kind, note)
    amount = POB.Money(amount)
    if not amount or amount <= 0 or amount > Config.MaxTransfer then return false, 'invalid_amount' end
    if (Player.PlayerData.money.cash or 0) < amount then return false, 'not_enough_cash' end
    if not Player.Functions.RemoveMoney('cash', amount, 'grumpy-pob:' .. kind) then return false, 'not_enough_cash' end
    Acc.Add(account, amount, kind, who(Player), note)
    return true
end

function Acc.WithdrawCash(Player, account, amount, kind, note)
    amount = POB.Money(amount)
    if not amount or amount <= 0 or amount > Config.MaxTransfer then return false, 'invalid_amount' end
    if not Acc.Remove(account, amount, kind, who(Player), note) then return false, 'not_enough_funds' end
    if not Player.Functions.AddMoney('cash', amount, 'grumpy-pob:' .. kind) then
        Acc.Add(account, amount, 'refund', who(Player), 'withdraw refund')
        return false, 'not_enough_funds'
    end
    return true
end

---------------------------------------------------------------------
-- Government account (admins + Config.Government.Jobs)
---------------------------------------------------------------------
local function govAllowed(src)
    if POB.IsAdmin(src) then return true end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    for job, minGrade in pairs(Config.Government.Jobs) do
        local held, grade = exports['rsg-core']:HasPlayerJob(src, job)
        if held and (grade or 0) >= minGrade then
            if not Config.Government.RequireDuty then return true end
            local j = Player.PlayerData.job or {}
            if j.name == job and j.onduty then return true end
        end
    end
    return false
end
POB.GovAllowed = govAllowed

RSGCore.Functions.CreateCallback('grumpy-pob:server:govData', function(source, cb, page)
    if not govAllowed(source) then return cb(nil) end
    cb({ balance = Acc.Balance(Acc.GOV), ledger = Acc.Ledger(Acc.GOV, page) })
end)

RegisterNetEvent('grumpy-pob:server:govMoney', function(action, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not govAllowed(src) or POB.Cooldown(src, 'gov', 1500) then return end
    local ok, err
    if action == 'deposit' then
        ok, err = Acc.DepositCash(Player, Acc.GOV, amount, 'deposit')
    elseif action == 'withdraw' then
        ok, err = Acc.WithdrawCash(Player, Acc.GOV, amount, 'withdraw')
    else return end
    if not ok then return POB.Notify(src, locale(err), 'error') end
    POB.Notify(src, locale(action == 'deposit' and 'deposited' or 'withdrew', POB.Money(amount)), 'success')
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'gov')
end)

RSGCore.Commands.Add(Config.Government.Command, locale('cmd_gov'), {}, false, function(source)
    if not govAllowed(source) then return POB.Notify(source, locale('no_permission'), 'error') end
    TriggerClientEvent('grumpy-pob:client:openGov', source)
end)

POB.AfterLoad(function() Acc.Ensure(Acc.GOV) end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('GetGovBalance', function() return Acc.Balance(Acc.GOV) end)
exports('AddGovMoney', function(amount, note)
    return Acc.Add(Acc.GOV, amount, 'export', { name = GetInvokingResource() }, note)
end)
exports('RemoveGovMoney', function(amount, note)
    return Acc.Remove(Acc.GOV, amount, 'export', { name = GetInvokingResource() }, note)
end)
exports('GetBusinessBalance', function(id)
    local biz = POB.Biz(id)
    return biz and Acc.Balance(POB.AccountId(biz)) or nil
end)
exports('AddBusinessMoney', function(id, amount, note)
    local biz = POB.Biz(id)
    return biz and Acc.Add(POB.AccountId(biz), amount, 'export', { name = GetInvokingResource() }, note) or false
end)
