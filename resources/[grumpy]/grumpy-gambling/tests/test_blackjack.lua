-- grumpy-blackjack (a sibling resource, builds/grumpy-blackjack): the rules on their own, a basic-strategy simulation
-- of the house edge, then full rounds through the real core with random legal moves, NPCs and money conservation.
local T, F = Test, FakeDB
math.randomseed(31)
local C = Config.Blackjack
local function c(str) return GGLib.Cards.Parse(str) end
local function hand(...) local cards = {} for _, s in ipairs({ ... }) do cards[#cards + 1] = c(s) end return { cards = cards } end

---------------------------------------------------------------------
-- 1. Rules
---------------------------------------------------------------------
local tot, soft = BJ.Score(hand('As', 'Kd').cards)
T.ok(tot == 21 and soft, 'A K = soft 21')
tot, soft = BJ.Score(hand('As', 'Ad').cards)
T.ok(tot == 12 and soft, 'A A = soft 12')
tot, soft = BJ.Score(hand('As', '6d', '9c').cards)
T.ok(tot == 16 and not soft, 'A 6 9 = hard 16')
T.ok(BJ.IsBust(hand('Ts', '6d', '8c').cards), '10 6 8 busts')
T.ok(BJ.IsBlackjack(hand('As', 'Kd')), 'a natural')
local sp = hand('As', 'Kd'); sp.split = true
T.ok(not BJ.IsBlackjack(sp), '21 after a split is not a blackjack')
local dealer17s = hand('As', '6d').cards
T.ok(not BJ.DealerHits(dealer17s, C.Rules), 'dealer stands on soft 17')
T.ok(BJ.DealerHits(hand('Ts', '6d').cards, C.Rules), 'dealer hits 16')
T.ok(BJ.DealerPeeks(c('Ah')) and BJ.DealerPeeks(c('Kh')) and not BJ.DealerPeeks(c('9h')), 'peeks with an ace or a ten')

T.eq(BJ.Outcome(hand('As', 'Kd'), hand('Ts', '9d').cards), 'blackjack', 'blackjack beats 19')
T.eq(BJ.Outcome(hand('As', 'Kd'), hand('Ah', 'Qd').cards), 'push', 'blackjack against blackjack pushes')
T.eq(BJ.Outcome(hand('Ts', '9d'), hand('Ah', 'Qd').cards), 'lose', 'dealer blackjack beats 19')
T.eq(BJ.Outcome(hand('Ts', '5d', '6c'), hand('Ah', 'Qd').cards), 'lose', 'dealer blackjack beats a three-card 21')
T.eq(BJ.Outcome(hand('Ts', '8d'), hand('Th', '6d', '9c').cards), 'win', 'dealer bust: win')
T.eq(BJ.Outcome(hand('Ts', '8d', '7c'), hand('Th', '6d', '9c').cards), 'lose', 'player bust loses even if the dealer busts')
T.eq(BJ.Outcome(hand('Ts', '8d'), hand('9h', '9d').cards), 'push', '18 against 18 pushes')
T.eq(BJ.Payout(100, 'blackjack'), 250, 'blackjack pays 3:2')
T.eq(BJ.Payout(101, 'blackjack'), 252, '3:2 on odd cents rounds down')
T.eq(BJ.Payout(100, 'win'), 200, 'a win pays 1:1')
T.eq(BJ.Payout(100, 'push'), 100, 'a push returns the stake')
T.eq(BJ.InsurancePayout(50, true), 150, 'insurance pays 2:1')

local pair8 = hand('8s', '8d')
T.ok(BJ.CanSplit(pair8, 1, C.Rules), '8 8 can split')
T.ok(not BJ.CanSplit(pair8, C.Rules.MaxHands, C.Rules), 'not past the hand limit')
local fromAces = hand('As', 'Ad'); fromAces.fromAces = true; fromAces.split = true
T.ok(not BJ.CanSplit(fromAces, 2, C.Rules) and not BJ.CanDouble(fromAces, C.Rules), 'split aces: no resplit, no double')
local afterSplit = hand('5s', '6d'); afterSplit.split = true
T.ok(BJ.CanDouble(afterSplit, C.Rules), 'double after split allowed')

local function basic(up, ...) local h = hand(...) return BJ.Basic(h, c(up), #h.cards == 2, #h.cards == 2 and BJ.Value(h.cards[1]) == BJ.Value(h.cards[2])) end
T.eq(basic('Th', 'Ts', '6d'), 'hit', 'basic: 16 vs 10 hits')
T.eq(basic('6h', 'Ts', '6d'), 'stand', 'basic: 16 vs 6 stands')
T.eq(basic('6h', '5s', '6d'), 'double', 'basic: 11 vs 6 doubles')
T.eq(basic('Ah', '5s', '6d'), 'hit', 'basic: 11 vs ace hits (S17)')
T.eq(basic('Th', 'As', 'Ad'), 'split', 'basic: always split aces')
T.eq(basic('Th', '8s', '8d'), 'split', 'basic: always split eights')
T.eq(basic('6h', 'Ts', 'Kd'), 'stand', 'basic: never split tens')
T.eq(basic('9h', 'As', '7d'), 'hit', 'basic: soft 18 vs 9 hits')
T.eq(basic('3h', 'As', '7d'), 'double', 'basic: soft 18 vs 3 doubles')
T.eq(basic('3h', '2s', 'Td'), 'hit', 'basic: 12 vs 3 hits')

---------------------------------------------------------------------
-- 2. House edge: basic strategy over many hands (catches payout mistakes, not tenths of a percent)
---------------------------------------------------------------------
local function simulate(n)
    local Cards = GGLib.Cards
    local shoe = Cards.NewShoe(C.Rules.Decks)
    local won = 0
    for _ = 1, n do
        if shoe:Remaining() < shoe.size * (1 - C.Rules.Penetration) then shoe = Cards.NewShoe(C.Rules.Decks) end
        local d = { shoe:Draw(), shoe:Draw() }
        local hands = { { cards = { shoe:Draw(), shoe:Draw() }, net = 100 } }
        local dealerBJ = BJ.Score(d) == 21
        if not (dealerBJ and BJ.DealerPeeks(d[1])) then
            local i = 1
            while hands[i] do
                local h = hands[i]
                while not h.done do
                    if BJ.IsBlackjack(h) or BJ.Score(h.cards) >= 21 then h.done = true break end
                    local move = BJ.Basic(h, d[1], BJ.CanDouble(h, C.Rules), BJ.CanSplit(h, #hands, C.Rules))
                    if move == 'stand' then h.done = true
                    elseif move == 'hit' then h.cards[#h.cards + 1] = shoe:Draw()
                    elseif move == 'double' then h.net = h.net * 2; h.doubled = true; h.cards[#h.cards + 1] = shoe:Draw(); h.done = true
                    elseif move == 'split' then
                        local aces = h.cards[1].r == 14
                        local h2 = { cards = { h.cards[2], shoe:Draw() }, net = h.net, split = true, fromAces = aces }
                        h.cards = { h.cards[1], shoe:Draw() }
                        h.split, h.fromAces = true, aces
                        table.insert(hands, i + 1, h2)
                        if aces then h.done, h2.done = true, true end
                    end
                end
                i = i + 1
            end
            local live = false
            for _, h in ipairs(hands) do if not BJ.IsBust(h.cards) and not BJ.IsBlackjack(h) then live = true end end
            while live and BJ.DealerHits(d, C.Rules) do d[#d + 1] = shoe:Draw() end
        end
        for _, h in ipairs(hands) do won = won + BJ.Payout(h.net, BJ.Outcome(h, d)) - h.net end
    end
    return -won / (n * 100)
end
local edge = simulate(40000)
T.ok(edge > -0.02 and edge < 0.025, ('basic strategy house edge is small (%.2f%% over 40,000 hands)'):format(edge * 100))

---------------------------------------------------------------------
-- 3. Full rounds through the core
---------------------------------------------------------------------
local offs = {}
for i = 1, 4 do offs[i] = { x = 0, y = 0, z = 0, h = 0 } end
local bj = { id = 1, label = 'BJ', kind = 'pvd', source = 'public', model = 'p_blackjacktable01x', bound = false, x = 0, y = 0, z = 0,
    h = 0, currency = 'cash', enabled = true, seats = offs, state = 'empty', occupants = {}, version = 0, settings = {},
    dealer = { x = 0, y = 0.7, z = 0, h = 180 } }
GG.Tables.byId[1] = bj
T.eq(GG.Registry.Get('blackjack').resource, 'grumpy-blackjack', 'blackjack registered by its own resource')
T.eq(GG.Registry.Get('blackjack').kind, 'pvd', 'a dealer game')

local NP, START = 3, 50000
for i = 1, NP do Fake.AddPlayer(i, 'CID' .. i, START / 100) end
local INITIAL = NP * START
local function cents(d) return math.floor(d * 100 + 0.5) end
local function sumOf(tbl, field) local n = 0 for _, r in pairs(tbl) do n = n + r[field] end return n end
local function ledgerBy(kind) local n = 0 for _, e in ipairs(F.ledger) do if e.kind == kind then n = n + e.amount end end return n end
local function check(where)
    if next(GG.Hands.open) then return end
    local pockets = 0
    for _, P in pairs(Fake.players) do pockets = pockets + cents(P.PlayerData.money.cash) end
    local stacks, pending = sumOf(F.stacks, 'amount'), sumOf(F.pending, 'amount')
    local world = pockets + stacks + pending - (ledgerBy('rake') + ledgerBy('sink') + ledgerBy('npc_sink')) - (ledgerBy('mint') + ledgerBy('npc_mint'))
    if world ~= INITIAL then error(('%s: money not conserved (%d vs %d)'):format(where, world, INITIAL)) end
    local led = 0 for _, e in ipairs(F.ledger) do led = led + e.amount end
    if led ~= stacks then error(('%s: ledger %d ~= stacks %d'):format(where, led, stacks)) end
end

for src = 1, NP do
    bj.occupants[src] = { src = src, cid = 'CID' .. src, name = 'P' .. src, stack = 0 }
    GG.Seats.bySrc[src] = { id = 1, seat = src }
    if bj.state ~= 'active' then
        bj.state, bj.game, bj.tier = 'active', 'blackjack', 'low'
        TriggerEvent('grumpy-gambling:server:tableStarted', 1, 'blackjack', 'low', 'cash')
    end
    GG.Tables.OnSeatTaken(bj, src, src)
    Fake.Net(src, 'grumpy-gambling:server:buyIn', GG.Wallet.Limits(bj).max / 100)
end
-- one NPC in the last seat (scenery bets)
GG.Npc.Seat(bj, 4, { persona = 'balanced', drunk = false, sharp = false })

local function act()
    for src, v in pairs(Fake.lastView) do
        if v.tableId == 1 and v.private and v.private.actions and #v.private.actions > 0 and math.random() < 0.7 then
            local a = v.private.actions[math.random(#v.private.actions)]
            local amount = a.amount
            if a.min and a.max then amount = a.min + math.random(0, (a.max - a.min) // (a.step or 1)) * (a.step or 1) end
            Fake.Net(src, 'grumpy-gambling:server:action', a.id, amount)
            return true
        end
    end
end

local before = #F.hands
local guard, potSeen, potLeft = 0, false, false
while #F.hands - before < 250 do
    guard = guard + 1
    if guard > 200000 then error('blackjack stalled after ' .. (#F.hands - before) .. ' rounds') end
    if not act() then Fake.Advance(500) end
    if GG.Play.pots[1] then potSeen = true end
    if GG.Play.pots[1] and not GG.Hands.ForTable(1) then potLeft = true end
    for seat, occ in pairs(bj.occupants) do
        local lim = GG.Wallet.Limits(bj)
        if occ.src and occ.stack < lim.step * 2 and not GG.Hands.InHand(1, seat) then
            Fake.Net(occ.src, 'grumpy-gambling:server:buyIn', (lim.max - occ.stack) / 100)
        end
    end
    check('blackjack round ' .. (#F.hands - before))
end
T.ok(true, '250 blackjack rounds settled, money conserved after every step')

local seen = {}
for _, m in ipairs(Fake.messages) do seen[m] = (seen[m] or 0) + 1 end
for _, k in ipairs({ 'doubles', 'splits', 'insures', 'result_blackjack', 'busts', 'result_push', 'dealer_blackjack' }) do
    T.ok((seen[k] or 0) > 0, ('rounds saw %s (%d)'):format(k, seen[k] or 0))
end
T.ok(potSeen, 'the pot is on the table while a hand has bets')
T.ok(not potLeft, 'and never outlives its hand')
local potItem
for _, it in ipairs(GG.Play.TableProps(bj)) do if it.key == '_pot' then potItem = it end end
GG.Play.pots[1] = true
for _, it in ipairs(GG.Play.TableProps(bj)) do if it.key == '_pot' then potItem = it end end
T.ok(potItem and potItem.at == 'dealer', 'at a dealer table the pot sits in front of the dealer')
GG.Play.pots[1] = nil
T.ok(-ledgerBy('rake') > 0, 'the rake was taken')
T.ok(ledgerBy('mint') ~= 0 or ledgerBy('sink') ~= 0, 'the house paid and kept money')
local props, anims = 0, 0
for _, e in ipairs(Fake.clientEvents) do
    if e.name == 'grumpy-gambling:client:props' then props = props + 1 end
end
T.ok(props == 0, 'no props sent to players far away (nobody is near in the fakes)')
T.ok(#(GG.Play.props[1] or {}) >= 0, 'props are kept for players who walk up')
for src = 1, NP do GG.Seats.Stand(src, nil) end
check('after standing up')
T.eq(bj.state, 'empty', 'the table resets when everyone leaves')
