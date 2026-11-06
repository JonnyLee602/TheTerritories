-- Stacks (DESIGN.md §7.2): buy-in and top-up from pocket money, cash-out on standing up, payouts to players who
-- weren't online, and recovery after a restart. Amounts are integer cents.
local Wallet = {}
GG.Wallet = Wallet
local M = GG.M

local function getPlayerByCid(cid) return GG.Core.Functions.GetPlayerByCitizenId(cid) end

local function save(Player)
    if Config.Money.SavePlayer and Player and Player.Functions.Save then pcall(Player.Functions.Save) end
end

function Wallet.Limits(t)
    local tier = t.tier and Config.Tiers[t.tier]
    if not tier then return nil end
    local bb = M.ToCents(tier.bigBlind)
    return {
        min = tier.buyInMin * bb, max = tier.buyInMax * bb,
        step = Config.Money.BuyInStep == 'smallBlind' and M.ToCents(tier.smallBlind) or 1,
        bigBlind = bb,
    }
end

-- Chips a seated player can still take away (their stack minus what's in an open hand)
function Wallet.Available(t, seat, occ)
    return occ.stack - GG.Hands.Contributed(t.id, seat)
end

-- Pays a player now if they're online, otherwise next time they log in
function Wallet.PayOrPend(cid, currency, amountC, kind, tableId, handId)
    if amountC <= 0 then return end
    local Player = getPlayerByCid(cid)
    if Player and Player.Functions.AddMoney(currency, M.ToDollars(amountC), 'grumpy-gambling:' .. kind) then
        save(Player)
        GG.DB.Ledger({ kind = kind, tableId = tableId, handId = handId, cid = cid, currency = currency, amount = -amountC })
        return true
    end
    GG.DB.PendingAdd(cid, currency, amountC)
    GG.DB.Ledger({ kind = 'pending', tableId = tableId, handId = handId, cid = cid, currency = currency, amount = -amountC, note = kind })
    return false
end

---------------------------------------------------------------------
-- Buy-in / top-up
---------------------------------------------------------------------
function Wallet.Offer(src, t, occ)
    local lim = Wallet.Limits(t)
    if not lim or t.state ~= 'active' then return end
    local Player = GG.Core.Functions.GetPlayer(src)
    if not Player then return end
    local s = GG.Seats.bySrc[src]
    TriggerClientEvent('grumpy-gambling:client:chips', src, {
        tableId = t.id, label = t.label, currency = t.currency, tier = t.tier,
        stack = occ.stack, available = s and Wallet.Available(t, s.seat, occ) or occ.stack,
        min = lim.min, max = lim.max, step = lim.step,
        pocket = M.ToCents(Player.PlayerData.money[t.currency] or 0) or 0,
        inHand = s and GG.Hands.InHand(t.id, s.seat) or false,
    })
end

function Wallet.BuyIn(src, amountC)
    local Player = GG.Core.Functions.GetPlayer(src)
    local s = GG.Seats.bySrc[src]
    local t = s and GG.Tables.Get(s.id)
    local occ = t and t.occupants[s.seat]
    if not Player or not occ or occ.src ~= src then return false, 'not_seated' end
    if t.state ~= 'active' then return false, 'table_not_started' end
    local lim = Wallet.Limits(t)
    if not M.IsCents(amountC) or amountC <= 0 then return false, 'chips_bad_amount' end
    if GG.Hands.InHand(t.id, s.seat) then return false, 'chips_in_hand' end
    local newStack = occ.stack + amountC
    if newStack < lim.min or newStack > lim.max then return false, 'chips_out_of_range' end
    local ok = Player.Functions.RemoveMoney(t.currency, M.ToDollars(amountC), 'grumpy-gambling:buyin')
    if not ok then return false, 'chips_no_money' end
    -- anything still owed to this character is paid out first, so their one stack row is this table's
    Wallet.PayPending(Player)
    GG.DB.StackSet(occ.cid, t.id, t.currency, newStack)
    save(Player)
    GG.DB.Ledger({ kind = occ.stack > 0 and 'topup' or 'buyin', tableId = t.id, cid = occ.cid, currency = t.currency, amount = amountC })
    local first = occ.stack == 0
    if first then occ.markAt = os.time() end
    occ.stack = newStack
    if first then GG.Tables.Sync(t) end -- a chip stack appears in front of the seat
    if GG.Play then GG.Play.Cue(t, s.seat, 'buyin'); GG.Play.Resend(t, s.seat) end
    return true, newStack
end

---------------------------------------------------------------------
-- Cash-out (standing up, dropping, table closing)
---------------------------------------------------------------------
-- dropped: the player is gone, so the money waits for their next login
function Wallet.CashOut(t, seat, occ, dropped)
    if occ.markAt then
        GG.Rake.RecordSeconds(t, os.time() - occ.markAt)
        occ.markAt = nil
    end
    local amount = Wallet.Available(t, seat, occ)
    occ.stack = 0
    GG.DB.StackDelete(occ.cid)
    if amount <= 0 then return 0 end
    if dropped then
        GG.DB.PendingAdd(occ.cid, t.currency, amount)
        GG.DB.Ledger({ kind = 'pending', tableId = t.id, cid = occ.cid, currency = t.currency, amount = -amount, note = 'dropped' })
    else
        Wallet.PayOrPend(occ.cid, t.currency, amount, 'cashout', t.id)
    end
    return amount
end

---------------------------------------------------------------------
-- Payouts owed (login) and recovery (resource start)
---------------------------------------------------------------------
function Wallet.PayPending(Player)
    local cid = Player.PlayerData.citizenid
    local paid = {}
    for _, p in ipairs(GG.DB.PendingTake(cid)) do
        if p.amount > 0 and Player.Functions.AddMoney(p.currency, M.ToDollars(p.amount), 'grumpy-gambling:pending') then
            GG.DB.Ledger({ kind = 'paid_pending', cid = cid, currency = p.currency, amount = 0, note = M.Fmt(p.amount) })
            paid[#paid + 1] = p
        elseif p.amount > 0 then
            GG.DB.PendingAdd(cid, p.currency, p.amount) -- AddMoney refused: keep it owed
        end
    end
    if #paid > 0 then
        save(Player)
        for _, p in ipairs(paid) do
            GG.Notify(Player.PlayerData.source, locale('chips_pending_paid', M.Fmt(p.amount), locale('currency_' .. p.currency)), 'success')
        end
    end
    return paid
end

-- On start nobody is seated, so every stack row left behind (restart or crash) is money owed back
function Wallet.Recover()
    local n, total = 0, 0
    for _, r in ipairs(GG.DB.StacksAll()) do
        GG.DB.StackDelete(r.cid)
        if r.amount > 0 and GG.Npc.IsNpcCid(r.cid) then
            -- an NPC's chips from the last run: nobody to pay, destroyed
            GG.DB.Ledger({ kind = 'npc_sink', tableId = r.tableId, cid = r.cid, currency = r.currency, amount = -r.amount })
        elseif r.amount > 0 then
            GG.DB.PendingAdd(r.cid, r.currency, r.amount)
            GG.DB.Ledger({ kind = 'recovered', tableId = r.tableId, cid = r.cid, currency = r.currency, amount = -r.amount })
            n, total = n + 1, total + r.amount
        end
    end
    if n > 0 then print(('[grumpy-gambling] %d stacks (%s) left from the last run are owed back to their players'):format(n, M.Fmt(total))) end
    -- players already online get theirs now
    for _, src in ipairs(GetPlayers()) do
        local Player = GG.Core.Functions.GetPlayer(tonumber(src))
        if Player then Wallet.PayPending(Player) end
    end
end
GG.AfterLoad(Wallet.Recover)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if GG.Ready and Player then Wallet.PayPending(Player) end
end)

---------------------------------------------------------------------
-- Net events
---------------------------------------------------------------------
RegisterNetEvent('grumpy-gambling:server:buyIn', function(dollars)
    local src = source
    if GG.Cooldown(src, 'buyIn', 1500) then return end
    local amountC = M.ToCents(dollars)
    local ok, res = Wallet.BuyIn(src, amountC)
    if not ok then return GG.Notify(src, locale(res), 'error') end
    GG.Notify(src, locale('chips_bought', M.Fmt(amountC), M.Fmt(res)), 'success')
    TriggerClientEvent('grumpy-gambling:client:chipsClosed', src)
    local s = GG.Seats.bySrc[src]
    local t = s and GG.Tables.Get(s.id)
    if t then TriggerEvent('grumpy-gambling:server:stackChanged', t.id, t.game, s.seat, src, res) end
end)

RegisterNetEvent('grumpy-gambling:server:requestChips', function()
    local src = source
    if GG.Cooldown(src, 'requestChips', 1000) then return end
    local s = GG.Seats.bySrc[src]
    local t = s and GG.Tables.Get(s.id)
    local occ = t and t.occupants[s.seat]
    if occ and occ.src == src then Wallet.Offer(src, t, occ) end
end)
