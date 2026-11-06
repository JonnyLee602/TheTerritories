-- Integration test: wallet, hands, rake, house and seats running for real against fake rsg-core players and an
-- in-memory database. After every step, money must be conserved.
local T, M, F = Test, GG.M, FakeDB
math.randomseed(7)

---------------------------------------------------------------------
-- world
---------------------------------------------------------------------
GG.Registry.Register({ id = 'tpoker', label = 'Test Poker', kind = 'pvp', minSeats = 2, maxSeats = 6 }, 'testres')
GG.Registry.Register({ id = 'tjack', label = 'Test Jack', kind = 'pvd', minSeats = 1, maxSeats = 4, maxPayout = 2.5,
    houseEdge = 0.005 }, 'testres')

local function newTable(id, kind, game, seats, source)
    local offs = {}
    for i = 1, seats do offs[i] = { x = 0, y = 0, z = 0, h = 0 } end
    local t = { id = id, label = 'T' .. id, kind = kind, source = source or 'public', model = 'p_tablepoker01x', bound = false,
        x = 0, y = 0, z = 0, h = 0, currency = 'cash', enabled = true, seats = offs, state = 'active', game = game,
        tier = 'low', occupants = {}, version = 0, defaultGame = game }
    GG.Tables.byId[id] = t
    return t
end
local poker = newTable(1, 'pvp', 'tpoker', 6)
local jack = newTable(2, 'pvd', 'tjack', 4)

local players = {}
local START = 5000 -- $50 each
for i = 1, 6 do players[i] = Fake.AddPlayer(i, 'CID' .. i, START / 100) end
local INITIAL = 6 * START

local function cents(d) return math.floor(d * 100 + 0.5) end
local function pockets()
    local n = 0
    for _, P in pairs(Fake.players) do n = n + cents(P.PlayerData.money.cash) end
    return n
end
local function sumOf(tbl, field) local n = 0 for _, r in pairs(tbl) do n = n + r[field] end return n end
local function ledgerBy(kind) local n = 0 for _, e in ipairs(F.ledger) do if e.kind == kind then n = n + e.amount end end return n end
local function ledgerSum() local n = 0 for _, e in ipairs(F.ledger) do n = n + e.amount end return n end
local function boxes() local n = 0 for _, v in pairs(F.cashboxes) do n = n + v end return n end
local funded = 0

-- pockets + chips + owed + cashboxes + destroyed - created == what we started with; ledger == money held by the core
local function check(where)
    if next(GG.Hands.open) then return end
    local destroyed = -(ledgerBy('rake') + ledgerBy('sink'))
    local created = ledgerBy('mint')
    local stacks, pending = sumOf(F.stacks, 'amount'), sumOf(F.pending, 'amount')
    local world = pockets() + stacks + pending + boxes() + destroyed - created
    if world ~= INITIAL + funded then
        error(('%s: money not conserved: world %d, expected %d (pockets %d stacks %d pending %d boxes %d destroyed %d created %d)')
            :format(where, world, INITIAL + funded, pockets(), stacks, pending, boxes(), destroyed, created))
    end
    if ledgerSum() ~= stacks + boxes() then
        error(('%s: ledger %d ~= held %d'):format(where, ledgerSum(), stacks + boxes()))
    end
    -- memory and database agree
    for _, t in pairs(GG.Tables.byId) do
        for _, occ in pairs(t.occupants) do
            local row = F.stacks[occ.cid]
            if (occ.stack or 0) > 0 and (not row or row.amount ~= occ.stack) then error(where .. ': stack row out of step for ' .. occ.cid) end
        end
    end
end

local function seat(t, i, src)
    -- an emptied table reset itself: reopen it the way the first player's game + tier choice would
    if t.state ~= 'active' then t.state, t.game, t.tier = 'active', t.defaultGame, 'low' end
    local P = Fake.bySrc[src]
    t.occupants[i] = { src = src, cid = P.PlayerData.citizenid, name = 'P' .. src, stack = 0 }
    GG.Seats.bySrc[src] = { id = t.id, seat = i }
end

---------------------------------------------------------------------
-- buy-in rules (low tier: big blind 10c, buy-in 130c – 260c)
---------------------------------------------------------------------
seat(poker, 1, 1); seat(poker, 2, 2); seat(poker, 3, 3)
T.eq(select(2, GG.Wallet.BuyIn(1, 100)), 'chips_out_of_range', 'buy-in under the minimum refused')
T.eq(select(2, GG.Wallet.BuyIn(1, 300)), 'chips_out_of_range', 'buy-in over the maximum refused')
T.eq(select(2, GG.Wallet.BuyIn(1, -5)), 'chips_bad_amount', 'negative buy-in refused')
T.ok(GG.Wallet.BuyIn(1, 200), 'buy-in $2.00')
T.eq(poker.occupants[1].stack, 200, 'stack set'); T.eq(cents(players[1].PlayerData.money.cash), START - 200, 'pocket debited')
T.ok(players[1].saves > 0, 'player saved after buy-in')
T.ok(GG.Wallet.BuyIn(2, 260), 'buy-in max'); T.ok(GG.Wallet.BuyIn(3, 130), 'buy-in min')
T.eq(select(2, GG.Wallet.BuyIn(3, 200)), 'chips_out_of_range', 'top-up above the max refused')
T.ok(GG.Wallet.BuyIn(3, 50), 'top-up within the max'); T.eq(poker.occupants[3].stack, 180, 'topped up')
check('after buy-ins')

---------------------------------------------------------------------
-- one exact PVP hand: rake 4.4% of 200c = 8.8 -> 8c now, 0.8c carried
---------------------------------------------------------------------
local id = assert(GG.Hands.Begin(poker.id))
T.eq(select(2, GG.Hands.Begin(poker.id)), 'hand_open', 'one hand per table')
T.ok(GG.Hands.Bet(id, 1, 100), 'A bets'); T.ok(GG.Hands.Bet(id, 2, 100), 'B calls')
T.eq(select(2, GG.Hands.Bet(id, 3, 999)), 'not_enough_chips', 'over-bet refused')
T.eq(GG.Hands.Info(id).pot, 192, 'pot shown net of rake (200 - 8)')
local ok, res = GG.Hands.Settle(id, { ranking = { { 1 }, { 2 } } })
T.ok(ok, 'settled'); T.eq(res.rake, 8, 'rake 8c'); T.eq(res.awards[1], 192, 'winner gets 192c')
T.eq(poker.occupants[1].stack, 292, 'winner stack'); T.eq(poker.occupants[2].stack, 160, 'loser stack')
T.near(GG.Rake.Remainder(poker.id), 0.8, 1e-9, '0.8c carried to the next hand')
check('exact hand')

-- the carried 0.8c tips the next identical hand to 9c
id = GG.Hands.Begin(poker.id); GG.Hands.Bet(id, 1, 100); GG.Hands.Bet(id, 2, 100)
ok, res = GG.Hands.Settle(id, { ranking = { { 2 }, { 1 } } })
T.eq(res.rake, 9, 'remainder carried: 9c'); check('carry hand')

-- no flop, no drop
id = GG.Hands.Begin(poker.id); GG.Hands.Bet(id, 1, 10); GG.Hands.Bet(id, 2, 5); GG.Hands.SetRakeable(id, false)
ok, res = GG.Hands.Settle(id, { ranking = { { 1 } } })
T.eq(res.rake, 0, 'unraked hand'); check('unraked hand')

-- bad results are refused and the hand stays open
id = GG.Hands.Begin(poker.id); GG.Hands.Bet(id, 1, 20); GG.Hands.Bet(id, 3, 20)
T.eq(select(2, GG.Hands.Settle(id, { ranking = { { 5 } } })), 'bad_ranking', 'unknown seat refused')
T.eq(select(2, GG.Hands.Settle(id, { ranking = { { 1 }, { 1 } } })), 'bad_ranking', 'duplicate seat refused')
-- database failure cancels: nobody loses their pre-hand stack
local before1, before3 = poker.occupants[1].stack, poker.occupants[3].stack
F.failSettle = true
T.eq(select(2, GG.Hands.Settle(id, { ranking = { { 1 }, { 3 } } })), 'db_error', 'db failure reported')
F.failSettle = false
T.eq(GG.Hands.ForTable(poker.id), nil, 'hand cancelled'); T.eq(poker.occupants[1].stack, before1, 'stack kept')
T.eq(poker.occupants[3].stack, before3, 'stack kept'); check('db failure')

-- uncalled bet handed back pays no rake
id = GG.Hands.Begin(poker.id); GG.Hands.Bet(id, 1, 50); GG.Hands.Bet(id, 2, 20); GG.Hands.Return(id, 1, 30)
ok, res = GG.Hands.Settle(id, { ranking = { { 1 } } })
T.eq(res.wagered, 40, 'returned bet not wagered'); check('returned bet')

---------------------------------------------------------------------
-- a player leaves mid-hand: their bet stays in, their chips go home, any win is paid to them later
---------------------------------------------------------------------
id = GG.Hands.Begin(poker.id); GG.Hands.Bet(id, 1, 40); GG.Hands.Bet(id, 3, 40)
local pocket3 = cents(players[3].PlayerData.money.cash)
local avail3 = poker.occupants[3].stack - 40
GG.Seats.Stand(3, nil)
T.eq(cents(players[3].PlayerData.money.cash), pocket3 + avail3, 'leaver cashed out what was not bet')
ok, res = GG.Hands.Settle(id, { ranking = { { 3 }, { 1 } } })
T.ok(ok, 'hand settles after a seat left')
T.ok(cents(players[3].PlayerData.money.cash) > pocket3 + avail3, 'leaver paid the pot they won')
check('leaver')

-- dropped player: chips wait for their next login
id = GG.Hands.Begin(poker.id); GG.Hands.Bet(id, 2, 30); GG.Hands.Bet(id, 1, 30)
Fake.Disconnect(2)
GG.Seats.Stand(2, nil, true)
ok = GG.Hands.Settle(id, { ranking = { { 2 }, { 1 } } })
T.ok(ok, 'settles with a dropped winner')
T.ok(sumOf(F.pending, 'amount') > 0, 'dropped winner is owed money'); check('dropped')
Fake.Reconnect(2, 'CID2')
GG.Wallet.PayPending(players[2])
T.eq(sumOf(F.pending, 'amount'), 0, 'paid on login'); check('login payout')

---------------------------------------------------------------------
-- crash mid-hand: the hand never happened
---------------------------------------------------------------------
seat(poker, 2, 2); GG.Wallet.BuyIn(2, 200)
id = GG.Hands.Begin(poker.id); GG.Hands.Bet(id, 1, 70); GG.Hands.Bet(id, 2, 70)
local preStacks = sumOf(F.stacks, 'amount')
GG.Hands.open, GG.Hands.byTable = {}, {}                    -- server dies
for _, t in pairs(GG.Tables.byId) do t.occupants = {} end
GG.Seats.bySrc = {}
GG.Wallet.Recover()                                         -- server starts
T.eq(sumOf(F.stacks, 'amount'), 0, 'no stack rows after recovery')
T.eq(cents(players[1].PlayerData.money.cash) + cents(players[2].PlayerData.money.cash) + sumOf(F.pending, 'amount')
    - (START * 2 - preStacks) >= 0, true, 'pre-hand stacks returned')
check('crash recovery')

---------------------------------------------------------------------
-- fuzz: 600 random PVP hands with buy-ins, top-ups, leavers and drops
---------------------------------------------------------------------
for i = 1, 6 do Fake.Reconnect(i, 'CID' .. i); GG.Wallet.PayPending(players[i]) end
local function ensureSeated()
    for i = 1, 6 do
        local P = players[i]
        if not GG.Seats.bySrc[i] and Fake.bySrc[i] and math.random() < 0.5 then
            local free
            for s = 1, 6 do if not poker.occupants[s] then free = s break end end
            if free and cents(P.PlayerData.money.cash) >= 130 then seat(poker, free, i); GG.Wallet.BuyIn(i, math.random(130, 260)) end
        end
    end
end
local played = 0
for n = 1, 600 do
    ensureSeated()
    local hid = GG.Hands.Begin(poker.id)
    if hid then
        played = played + 1
        local h = GG.Hands.Get(hid)
        local live = {}
        for s in pairs(h.seats) do
            local occ = poker.occupants[s]
            local b = math.random(0, math.min(occ.stack, 120))
            if b > 0 then assert(GG.Hands.Bet(hid, s, b)) end
            if math.random() < 0.7 then live[#live + 1] = s end
        end
        local _, anySeat = next(h.seats)
        if #live == 0 then live[1] = next(h.seats) end
        -- sometimes someone leaves or drops mid-hand
        if math.random() < 0.08 then
            local s = live[math.random(#live)]
            local src = h.seats[s].src
            if math.random() < 0.5 then GG.Seats.Stand(src, nil) else Fake.Disconnect(src); GG.Seats.Stand(src, nil, true) end
        end
        for k = #live, 2, -1 do local j = math.random(k); live[k], live[j] = live[j], live[k] end
        local ranking, k = {}, 1
        while k <= #live do
            local g = { live[k] }
            while k < #live and math.random() < 0.2 do k = k + 1; g[#g + 1] = live[k] end
            ranking[#ranking + 1] = g; k = k + 1
        end
        if math.random() < 0.15 then GG.Hands.SetRakeable(hid, false) end
        local sok, serr = GG.Hands.Settle(hid, { ranking = ranking })
        if not sok then error('fuzz hand ' .. n .. ' failed: ' .. tostring(serr)) end
        check('pvp fuzz ' .. n)
    end
    for i = 1, 6 do if not Fake.bySrc[i] and math.random() < 0.3 then Fake.Reconnect(i, 'CID' .. i); GG.Wallet.PayPending(players[i]) end end
    -- busted players stand up
    for s, occ in pairs(poker.occupants) do if occ.stack < 10 and math.random() < 0.5 then GG.Seats.Stand(occ.src, nil) end end
end
T.ok(played > 300, ('random PVP hands conserve money (%d played)'):format(played))
T.ok(-ledgerBy('rake') > 0, 'the rake removed money')

---------------------------------------------------------------------
-- PVD: public table (the server is the house) and a business cashbox
---------------------------------------------------------------------
for _, occ in pairs(poker.occupants) do GG.Seats.Stand(occ.src, nil) end
for i = 1, 6 do if not Fake.bySrc[i] then Fake.Reconnect(i, 'CID' .. i) end GG.Wallet.PayPending(players[i]) end
seat(jack, 1, 1); seat(jack, 2, 2)
GG.Wallet.BuyIn(1, 260); GG.Wallet.BuyIn(2, 260)
id = GG.Hands.Begin(jack.id)
local ok1, net1 = GG.Hands.Bet(id, 1, 100)
T.ok(ok1, 'pvd bet'); T.eq(net1, 99, '1.6% rake out of the bet: 98.4 -> 99 net, remainder carried')
GG.Hands.Bet(id, 2, 50)
T.eq(select(2, GG.Hands.Settle(id, { payouts = { [1] = 300 } })), 'payout_too_high', 'payout above maxPayout refused')
ok, res = GG.Hands.Settle(id, { payouts = { [1] = 198, [2] = 0 } })
T.ok(ok, 'pvd settled'); T.eq(res.house, 198 - (99 + 50 - 1), 'house paid the win minus the loss')
check('pvd public')

local pvdPlayed = 0
for n = 1, 400 do
    local hid = GG.Hands.Begin(jack.id)
    if not hid then break end
    pvdPlayed = pvdPlayed + 1
    local h = GG.Hands.Get(hid)
    local payouts = {}
    for s in pairs(h.seats) do
        local occ = jack.occupants[s]
        local b = math.random(1, math.min(occ.stack, 100))
        local bok, net = GG.Hands.Bet(hid, s, b)
        if bok then
            local roll = math.random()
            payouts[s] = roll < 0.48 and 0 or roll < 0.56 and net or roll < 0.96 and net * 2 or math.floor(net * 2.5)
        end
    end
    assert(GG.Hands.Settle(hid, { payouts = payouts }))
    check('pvd fuzz ' .. n)
    for s, occ in pairs(jack.occupants) do
        if occ.stack < 10 then GG.Seats.Stand(occ.src, nil); seat(jack, s, occ.src); GG.Wallet.BuyIn(occ.src, 200) end
    end
end
T.eq(pvdPlayed, 400, '400 random PVD hands conserve money')

-- business table: the cashbox is the house and must cover every bet
for _, occ in pairs(jack.occupants) do GG.Seats.Stand(occ.src, nil) end
jack.source = 'business'
F.cashboxes[jack.id] = 100; funded = 100
F.ledger[#F.ledger + 1] = { kind = 'fund', currency = 'cash', amount = 100 }
seat(jack, 1, 1); GG.Wallet.BuyIn(1, 260)
id = GG.Hands.Begin(jack.id)
-- a $1 stake can win back $2.50: the house must hold ~$1.49 of exposure, more than the $1.00 cashbox
T.eq(select(2, GG.Hands.Bet(id, 1, 100)), 'house_cover', 'bet the cashbox cannot cover refused')
T.ok(GG.Hands.Bet(id, 1, 60), 'smaller bet covered')
ok, res = GG.Hands.Settle(id, { payouts = { [1] = 0 } })
T.ok(F.cashboxes[jack.id] > 100, 'cashbox kept the losing bet'); check('business cashbox')
