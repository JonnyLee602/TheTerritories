-- Business tables (DESIGN.md §9) with a fake grumpy-pob, rsg-inventory and rsg-gizmo: placement rules, the cashbox,
-- dealer play against the box, the rake share, settings, losing the business, repossession, seizure, abandonment.
-- Money is conserved after every step: pockets + stacks + pending + boxes (+ the government's take) never change
-- except by the ledger's mint/sink/rake lines.
local T, F = Test, FakeDB
math.randomseed(9)
local Biz, B = GG.Biz, Config.Business
Config.Npc.Enabled = false

---------------------------------------------------------------------
-- Fakes: grumpy-pob (one business, id 7, its clerk at 100,100), rsg-inventory, rsg-gizmo
---------------------------------------------------------------------
local pob = { owner = 'CID1', backroom = false, npc = { x = 100.0, y = 100.0, z = 0.0 }, gov = 0, govCalls = 0 }
local inv = {}   -- [src] = { [item] = n }
local full = {}
local prev = Fake.resource
Fake.resource = 'grumpy-pob'
exports('GetOwnedBusinesses', function(cid)
    if cid ~= pob.owner then return {} end
    return { { id = 7, label = 'The Saloon', type = 'saloon', npc = pob.npc, backroom = pob.backroom } }
end)
exports('IsOwner', function(id, cid) return id == 7 and pob.owner ~= nil and cid == pob.owner end)
exports('HasBackroom', function(id) return id == 7 and pob.backroom end)
exports('GetBusiness', function(id) if id == 7 then return { id = 7, owned = pob.owner ~= nil, points = { npc = pob.npc } } end end)
exports('AddGovMoney', function(amount) pob.gov = pob.gov + math.floor(amount * 100 + 0.5); pob.govCalls = pob.govCalls + 1; return true end)
exports('IsReady', function() return true end)
Fake.resource = 'rsg-inventory'
exports('CanAddItem', function(src) return not full[src] end)
exports('GetItemCount', function(src, item) return (inv[src] or {})[item] or 0 end)
exports('RemoveItem', function(src, item, n)
    local have = (inv[src] or {})[item] or 0
    if have < n then return false end
    inv[src][item] = have - n
    return true
end)
exports('AddItem', function(src, item, n)
    if full[src] then return false end
    inv[src] = inv[src] or {}
    inv[src][item] = (inv[src][item] or 0) + n
    return true
end)
Fake.resource = 'rsg-gizmo'
exports('IsPlacementValid', function() return true end)
Fake.resource = prev

local P1 = Fake.AddPlayer(1, 'CID1', 500, 200)   -- the owner
local P2 = Fake.AddPlayer(2, 'CID2', 500, 200)
local P3 = Fake.AddPlayer(3, 'CID3', 500, 200)
local INITIAL = 3 * (50000 + 20000)
inv[1] = { [B.Items.pvp] = 3, [B.Items.pvd] = 3 }

local function cents(d) return math.floor(d * 100 + 0.5) end
local function sumOf(tbl, field) local n = 0 for _, r in pairs(tbl) do n = n + r[field] end return n end
local function ledgerBy(kind) local n = 0 for _, e in ipairs(F.ledger) do if e.kind == kind then n = n + e.amount end end return n end
local function boxes() local n = 0 for _, v in pairs(F.cashboxes) do n = n + v end return n end
local function check(where)
    if next(GG.Hands.open) then return end
    local pockets = 0
    for _, P in pairs(Fake.players) do pockets = pockets + cents(P.PlayerData.money.cash) + cents(P.PlayerData.money.bloodmoney) end
    local stacks, pending = sumOf(F.stacks, 'amount'), sumOf(F.pending, 'amount')
    local destroyed = -(ledgerBy('rake') + ledgerBy('sink') + ledgerBy('npc_sink') + ledgerBy('box_sink') + ledgerBy('box_seized'))
    local created = ledgerBy('mint') + ledgerBy('npc_mint')
    local world = pockets + stacks + pending + boxes() + pob.gov + destroyed - created
    if world ~= INITIAL then error(('%s: money not conserved (%d vs %d)'):format(where, world, INITIAL)) end
    local led = 0 for _, e in ipairs(F.ledger) do led = led + e.amount end
    if led ~= stacks + boxes() then error(('%s: ledger %d ~= stacks %d + boxes %d'):format(where, led, stacks, boxes())) end
end
local function lastClient(name, src)
    for i = #Fake.clientEvents, 1, -1 do
        local e = Fake.clientEvents[i]
        if e.name == name and (not src or e.src == src) then return e end
    end
end
local function at(src, x, y) Fake.coords[src] = { x = x, y = y, z = 0.0 } end
local function bizTables(kind)
    local n = 0
    for _, t in pairs(GG.Tables.byId) do if t.source == 'business' and (not kind or t.kind == kind) then n = n + 1 end end
    return n
end
local function newest()
    local best
    for _, t in pairs(GG.Tables.byId) do if t.source == 'business' and (not best or t.id > best.id) then best = t end end
    return best
end
local function place(src, kind, x, y, currency)
    Fake.Net(src, 'grumpy-gambling:server:bizCreate', { kind = kind, businessId = 7, label = 'Table', currency = currency or 'cash',
        coords = { x = x, y = y, z = 0.0 }, heading = 90.0 })
end

---------------------------------------------------------------------
-- 1. Using the item: owner only, near the clerk
---------------------------------------------------------------------
at(1, 300, 300)
Fake.usable[B.Items.pvd](1)
T.ok(lastClient('grumpy-gambling:client:bizPlace', 1) == nil, 'too far from the clerk: no placing')
at(1, 105, 100)
Fake.usable[B.Items.pvd](1)
local ev = lastClient('grumpy-gambling:client:bizPlace', 1)
T.ok(ev and ev.args[1].businessId == 7 and #ev.args[1].currencies == 1, 'the owner near the clerk may place (cash only: no back room)')
at(2, 105, 100)
Fake.usable[B.Items.pvd](2)
T.ok(lastClient('grumpy-gambling:client:bizPlace', 2) == nil, 'a non-owner may not')

---------------------------------------------------------------------
-- 2. Saving: every rule again on the server; the item goes only once the table is saved
---------------------------------------------------------------------
place(1, 'pvd', 140, 100)
T.eq(bizTables(), 0, 'outside the business (40 m from the clerk) is refused')
place(2, 'pvd', 110, 100)
T.eq(bizTables(), 0, 'a non-owner is refused')
place(1, 'pvd', 110, 100, 'bloodmoney')
T.eq(bizTables(), 0, 'bloodmoney without the back room is refused')
place(1, 'pvd', 110, 100)
local dealer = newest()
T.ok(dealer and dealer.kind == 'pvd' and dealer.businessId == 7 and dealer.ownerCid == 'CID1', 'a dealer table is placed')
T.eq(inv[1][B.Items.pvd], 2, 'the item was used up')
place(1, 'pvd', 112, 100)
T.eq(bizTables('pvd'), 2, 'a second dealer table')
place(1, 'pvd', 114, 100)
T.eq(bizTables('pvd'), 2, 'the business limit (2) holds')
T.eq(inv[1][B.Items.pvd], 1, 'no item taken for a refused table')
inv[1][B.Items.pvp] = 0
place(1, 'pvp', 115, 100)
T.eq(bizTables('pvp'), 0, 'no item, no table')
inv[1][B.Items.pvp] = 2
pob.backroom = true
place(1, 'pvp', 115, 100, 'bloodmoney')
local backroom = newest()
T.eq(backroom.currency, 'bloodmoney', 'with the back room a bloodmoney table is allowed')
place(1, 'pvp', 117, 100)
local cards = newest()
T.eq(cards.kind, 'pvp', 'a cash card table')
local mine = lastClient('grumpy-gambling:client:myTables', 1)
T.eq(mine and #mine.args[1], 4, 'the owner is told which tables are theirs')
check('placed')

---------------------------------------------------------------------
-- 3. The cashbox: deposit, withdraw, cover rules
---------------------------------------------------------------------
T.eq(#GG.Tables.AllowedTiers(dealer), 0, 'an empty box offers no stakes')
T.eq(select(2, GG.Tables.Usable(dealer)), 'biz_table_unfunded', 'an unfunded dealer table is closed')
Fake.Net(1, 'grumpy-gambling:server:bizAction', dealer.id, 'deposit', 50)
T.eq(F.cashboxes[dealer.id], 5000, '$50 in the box')
T.eq(cents(P1.PlayerData.money.cash), 45000, 'from the owner\'s pocket')
local tiers = {}
for _, x in ipairs(GG.Tables.AllowedTiers(dealer)) do tiers[x.id] = true end
T.ok(tiers.low and not tiers.mid and not tiers.high, '$50 covers Low only (20 × $1 max bet)')
T.ok(GG.Tables.Usable(dealer), 'funded: open')
Fake.Net(1, 'grumpy-gambling:server:bizAction', dealer.id, 'withdraw', 80)
T.eq(F.cashboxes[dealer.id], 5000, 'can\'t take out more than is in the box')
Fake.Net(1, 'grumpy-gambling:server:bizAction', dealer.id, 'withdraw', 10)
T.eq(F.cashboxes[dealer.id], 4000, 'took $10 out')
at(2, 110, 100)
Fake.Net(2, 'grumpy-gambling:server:bizAction', dealer.id, 'withdraw', 10)
T.eq(F.cashboxes[dealer.id], 4000, 'only the owner can touch the box')
at(1, 300, 300)
Fake.Net(1, 'grumpy-gambling:server:bizAction', dealer.id, 'withdraw', 10)
T.eq(F.cashboxes[dealer.id], 4000, 'and only at the table')
at(1, 110, 100)
Fake.Net(1, 'grumpy-gambling:server:bizAction', dealer.id, 'deposit', 160)
T.eq(F.cashboxes[dealer.id], 20000, '$200 in the box')
check('box')

---------------------------------------------------------------------
-- 4. Dealer play against the box (the test High Card game), and the PVP rake share
---------------------------------------------------------------------
local function seatPlayer(t, src, game, tier)
    for i = 1, #t.seats do
        if not t.occupants[i] then
            t.occupants[i] = { src = src, cid = Fake.bySrc[src].PlayerData.citizenid, name = 'P' .. src, stack = 0 }
            GG.Seats.bySrc[src] = { id = t.id, seat = i }
            if t.state ~= 'active' then
                t.state, t.game, t.tier = 'active', game, tier
                TriggerEvent('grumpy-gambling:server:tableStarted', t.id, game, tier, t.currency)
            end
            GG.Tables.OnSeatTaken(t, i, src)
            Fake.Net(src, 'grumpy-gambling:server:buyIn', GG.Wallet.Limits(t).max / 100)
            return i
        end
    end
end
local function actAll(tid)
    for src, v in pairs(Fake.lastView) do
        local s = GG.Seats.bySrc[src]
        if s and s.id == tid and v.tableId == tid and v.private and v.private.actions and #v.private.actions > 0 then
            local a = v.private.actions[math.random(#v.private.actions)]
            local amount = a.amount
            if a.min and a.max then amount = a.min + math.random(0, (a.max - a.min) // (a.step or 1)) * (a.step or 1) end
            Fake.Net(src, 'grumpy-gambling:server:action', a.id, amount)
            return true
        end
    end
end
local function play(t, hands)
    local target, guard = #F.hands + hands, 0
    while #F.hands < target do
        guard = guard + 1
        if guard > 20000 then error('stalled at ' .. #F.hands) end
        if not actAll(t.id) then Fake.Advance(1000) end
        for seat, occ in pairs(t.occupants) do -- broke players buy back in between hands
            local lim = GG.Wallet.Limits(t)
            if occ.src and occ.stack < lim.step * 2 and not GG.Hands.InHand(t.id, seat) then -- too short to bet: top up
                Fake.Net(occ.src, 'grumpy-gambling:server:buyIn', (lim.max - occ.stack) / 100)
            end
        end
        check('play ' .. t.id)
    end
end

seatPlayer(dealer, 2, 'test_highcard', 'low')
seatPlayer(dealer, 3, 'test_highcard', 'low')
local before = F.cashboxes[dealer.id]
play(dealer, 40)
local st = GG.DB.BoxStats(dealer.id)
T.ok(st.hands >= 40, 'the box counts the hands')
T.eq(F.cashboxes[dealer.id] - before, st.house, 'the box moved by exactly the house result')
T.eq(ledgerBy('mint') + ledgerBy('sink'), 0, 'business dealer tables never create or destroy house money')
GG.Seats.Stand(2, nil); GG.Seats.Stand(3, nil)
check('after dealer play')

seatPlayer(cards, 2, 'test_showdown', 'low')
seatPlayer(cards, 3, 'test_showdown', 'low')
play(cards, 40)
local cs = GG.DB.BoxStats(cards.id)
T.ok(cs.rake > 0, 'the card table\'s box collected rake')
T.eq(F.cashboxes[cards.id] or 0, cs.rake, 'a card table box holds exactly its rake share')
local rakeSum = 0
for _, h in ipairs(F.hands) do if h.tableId == cards.id then rakeSum = rakeSum + h.rake end end
T.ok(math.abs(cs.rake * 2 - rakeSum) <= 40, ('about half the rake goes to the box (%d of %d)'):format(cs.rake, rakeSum))
GG.Seats.Stand(2, nil); GG.Seats.Stand(3, nil)
check('after card play')

---------------------------------------------------------------------
-- 5. Settings: stakes and NPCs
---------------------------------------------------------------------
at(1, 117, 100) -- at the card table
Fake.Net(1, 'grumpy-gambling:server:bizAction', cards.id, 'tiers', { mid = true })
local only = GG.Tables.AllowedTiers(cards)
T.ok(#only == 1 and only[1].id == 'mid', 'the owner can narrow the stakes')
Fake.Net(1, 'grumpy-gambling:server:bizAction', cards.id, 'tiers', {})
T.eq(#GG.Tables.AllowedTiers(cards), 1, 'but must leave one')
Fake.Net(1, 'grumpy-gambling:server:bizAction', cards.id, 'npcs', false)
T.eq(cards.settings.npcs, false, 'NPCs can be turned off')
Fake.Net(1, 'grumpy-gambling:server:bizAction', cards.id, 'toggle')
T.eq(cards.enabled, false, 'the owner can close the table')
Fake.Net(1, 'grumpy-gambling:server:bizAction', cards.id, 'toggle')

---------------------------------------------------------------------
-- 6. Losing the business (not tax): tables close, the owner can still empty and pack up
---------------------------------------------------------------------
seatPlayer(cards, 2, 'test_showdown', 'mid')
pob.owner = nil
TriggerEvent('grumpy-pob:server:ownerChanged', 7, 'CID1', nil, 'admin')
T.ok(cards.settings.orphaned ~= nil and dealer.settings.orphaned ~= nil, 'every table of the business closes')
T.eq(GG.Seats.bySrc[2], nil, 'players are stood up (and cashed out)')
T.eq(select(2, GG.Tables.Usable(cards)), 'biz_table_orphaned', 'nobody can sit')
at(1, 110, 100) -- at the dealer table
local boxBefore = F.cashboxes[dealer.id]
Fake.Net(1, 'grumpy-gambling:server:bizAction', dealer.id, 'deposit', 5)
T.eq(F.cashboxes[dealer.id], boxBefore, 'no deposits any more')
Fake.Net(1, 'grumpy-gambling:server:bizAction', dealer.id, 'withdraw', 1)
T.eq(F.cashboxes[dealer.id], boxBefore - 100, 'but the owner can still take money out')
check('orphaned')
-- buying the business back reopens them
pob.owner = 'CID1'
TriggerEvent('grumpy-pob:server:ownerChanged', 7, nil, 'CID1', 'bought')
T.eq(cards.settings.orphaned, nil, 'the placer owns the business again: tables reopen')

-- pack up: box to the pocket, item back
at(1, 117, 100)
local pocket = cents(P1.PlayerData.money.cash)
local cardsBox = F.cashboxes[cards.id] or 0
local items = inv[1][B.Items.pvp]
Fake.Net(1, 'grumpy-gambling:server:bizAction', cards.id, 'packup')
T.eq(GG.Tables.byId[cards.id], nil, 'the table is gone')
T.eq(cents(P1.PlayerData.money.cash), pocket + cardsBox, 'its box went to the owner\'s pocket')
T.eq(inv[1][B.Items.pvp], items + 1, 'and the item came back')
check('packed')

---------------------------------------------------------------------
-- 7. Repossession for unpaid tax: clean box to the government, dirty box destroyed, no item
---------------------------------------------------------------------
at(1, 115, 100) -- at the back-room table
Fake.Net(1, 'grumpy-gambling:server:bizAction', backroom.id, 'deposit', 20)
T.eq(F.cashboxes[backroom.id], 2000, '$20 of bloodmoney in the back-room box')
local dealerBox = F.cashboxes[dealer.id]
local itemsPvd = inv[1][B.Items.pvd]
pob.owner = nil
TriggerEvent('grumpy-pob:server:ownerChanged', 7, 'CID1', nil, 'tax')
T.eq(bizTables(), 0, 'every table of the business is taken')
T.eq(pob.gov, dealerBox, 'the clean box went to the government account')
T.eq(-ledgerBy('box_sink'), 2000, 'the dirty box was destroyed')
T.eq(inv[1][B.Items.pvd], itemsPvd, 'no items back')
check('repossessed')

---------------------------------------------------------------------
-- 8. Seizure, out of range, admin delete, abandonment while offline
---------------------------------------------------------------------
pob.owner = 'CID1'
at(1, 110, 100)
place(1, 'pvd', 110, 100, 'bloodmoney')
local dirty = newest()
Fake.Net(1, 'grumpy-gambling:server:bizAction', dirty.id, 'deposit', 30)
TriggerEvent('grumpy-pob:server:seized', 7, 3)
T.eq(F.cashboxes[dirty.id], 0, 'a law seizure empties the dirty box')
T.eq(-ledgerBy('box_seized'), 3000, 'and destroys it')
check('seized')

pob.npc = { x = 200.0, y = 100.0, z = 0.0 }
TriggerEvent('grumpy-pob:server:businessChanged', 7)
T.eq(select(2, GG.Tables.Usable(dirty)), 'biz_table_out_of_range', 'the clerk moved away: the table closes')
Fake.Net(1, 'grumpy-gambling:server:bizMove', dirty.id, { x = 150.0, y = 100.0, z = 0.0 }, 0.0)
T.eq(dirty.x, 110.0, 'it can\'t be moved outside the business')
at(1, 110, 100)
Fake.Net(1, 'grumpy-gambling:server:bizMove', dirty.id, { x = 190.0, y = 100.0, z = 0.0 }, 0.0)
T.ok(dirty.x == 190.0 and dirty.settings.outOfRange == nil, 'moving it back inside reopens it')
T.eq(select(2, GG.Tables.Usable(dirty)), 'biz_table_unfunded', '(still closed: the seized box is empty)')
pob.npc = { x = 100.0, y = 100.0, z = 0.0 }
TriggerEvent('grumpy-pob:server:businessChanged', 7)

place(1, 'pvp', 105, 100)
local adminDel = newest()
GG.Tables.Delete(adminDel)
T.eq(GG.Tables.byId[adminDel.id], nil, 'an admin delete packs the table up for its owner')

-- the owner loses the business and goes offline; days later the table is packed up for them
at(1, 190, 100)
Fake.Net(1, 'grumpy-gambling:server:bizAction', dirty.id, 'deposit', 12)
pob.owner = nil
TriggerEvent('grumpy-pob:server:ownerChanged', 7, 'CID1', nil, 'deleted')
Fake.Disconnect(1)
dirty.settings.orphaned = os.time() - (B.AbandonDays + 1) * 86400
Biz.PackUp(dirty, nil, 'abandoned')
T.eq(GG.Tables.byId[dirty.id], nil, 'an abandoned table is packed up')
local owedMoney, owedItems = 0, 0
for _, p in pairs(F.pending) do if p.cid == 'CID1' then owedMoney = owedMoney + p.amount end end
for _, r in pairs(F.items) do if r.cid == 'CID1' then owedItems = owedItems + r.amount end end
T.eq(owedMoney, 1200, 'its box is owed to the owner')
T.ok(owedItems >= 1, 'and its item')
check('abandoned')
Fake.Reconnect(1, 'CID1')
local had = inv[1][B.Items.pvd]
GG.Biz.GiveOwed(P1)
GG.Wallet.PayPending(P1)
T.eq(inv[1][B.Items.pvd], had + 1, 'the item is given at login')
T.eq(#GG.DB.PendingItems('CID1'), 0, 'nothing left owed')
check('end')
