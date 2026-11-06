-- grumpy-drawpoker (sibling resource builds/grumpy-drawpoker): NPC draws, draw validation, the empty-deck reshuffle,
-- then full hands through the real core with players and an NPC making random legal moves, money conserved.
local T, F = Test, FakeDB
math.randomseed(41)
local D = DrawPoker
local function cards(str) local out = {} for s in str:gmatch('%S+') do out[#out + 1] = GGLib.Cards.Parse(s) end return out end
local function throwOf(str) local t = D.npcDraw(cards(str), { bluff = 0 }) table.sort(t) return t end
local function same(a, b) if #a ~= #b then return false end for i = 1, #a do if a[i] ~= b[i] then return false end end return true end

---------------------------------------------------------------------
-- 1. NPC draws and the rules
---------------------------------------------------------------------
T.ok(same(throwOf('9h 9d Ks 4c 2d'), { 3, 4, 5 }), 'a pair throws three')
T.ok(same(throwOf('9h 9d Ks Kc 2d'), { 5 }), 'two pair throws the odd card')
T.ok(same(throwOf('9h 9d 9s Kc 2d'), { 4, 5 }), 'trips throw two')
T.ok(#throwOf('5h 6d 7s 8c 9d') == 0, 'a straight stands pat')
T.ok(same(throwOf('2h 7h 9h Kh 4c'), { 5 }), 'a four-flush draws one')
T.ok(same(throwOf('5h 6d 7s 8c Kd'), { 5 }), 'an open-ended straight draws one')
T.ok(same(throwOf('Ah 3d 7s 9c Jd'), { 2, 3, 4, 5 }), 'ace-high nothing keeps the ace and draws four')
T.ok(same(throwOf('2h 5d 7s 9c Jd'), { 1, 2, 3 }), 'nothing keeps the two highest and draws three')

local hand5 = cards('Ah 3d 7s 9c Jd')
T.eq(#(D.validDraw(hand5, D.maskOf({ 2, 3, 4 })) or {}), 3, 'three cards may go')
T.eq(#(D.validDraw(hand5, D.maskOf({ 2, 3, 4, 5 })) or {}), 4, 'four may go when the card kept is an ace')
T.eq(D.validDraw(cards('Kh 3d 7s 9c Jd'), D.maskOf({ 2, 3, 4, 5 })), nil, 'not four without an ace')
T.eq(D.validDraw(hand5, 31), nil, 'never all five')
T.eq(#(D.validDraw(hand5, 0) or { 'x' }), 0, 'standing pat is a draw of none')
T.eq(D.validDraw(hand5, 99), nil, 'nonsense masks are refused')
T.ok(D.drawBonus(cards('2h 7h 9h Kh 4c')) > 0, 'a four-flush is worth more before the draw')
T.eq(D.drawBonus(cards('9h 9d Ks 4c 2d')), 0, 'made hands get no bonus')

-- the deck runs out during the draw: the discards are shuffled back in
local h = { shoe = GGLib.Cards.NewShoe(1), muck = {} }
for _ = 1, 52 do h.shoe:Draw() end
h.muck = cards('2c 3c 4c')
local c1 = D.draw(h)
T.ok(c1 ~= nil and #h.muck == 0, 'an empty deck takes the discards back')

---------------------------------------------------------------------
-- 2. Full hands through the core
---------------------------------------------------------------------
local offs = {}
for i = 1, 6 do offs[i] = { x = 0, y = 0, z = 0, h = 0 } end
local tb = { id = 1, label = 'Draw', kind = 'pvp', source = 'public', model = 'p_tablepoker01x', bound = false, x = 0, y = 0, z = 0,
    h = 0, currency = 'cash', enabled = true, seats = offs, state = 'empty', occupants = {}, version = 0, settings = {} }
GG.Tables.byId[1] = tb
T.eq(GG.Registry.Get('drawpoker').resource, 'grumpy-drawpoker', 'registered by its own resource')

local NP, START = 4, 50000
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
    tb.occupants[src] = { src = src, cid = 'CID' .. src, name = 'P' .. src, stack = 0 }
    GG.Seats.bySrc[src] = { id = 1, seat = src }
    if tb.state ~= 'active' then
        tb.state, tb.game, tb.tier = 'active', 'drawpoker', 'low'
        TriggerEvent('grumpy-gambling:server:tableStarted', 1, 'drawpoker', 'low', 'cash')
    end
    GG.Tables.OnSeatTaken(tb, src, src)
    Fake.Net(src, 'grumpy-gambling:server:buyIn', GG.Wallet.Limits(tb).max / 100)
end
GG.Npc.Seat(tb, 5, { persona = 'loose', drunk = false, sharp = false })

local drawsSent, badDraws = 0, 0
local foldEarly = false   -- later: fold whenever possible before the draw (hands that end early pay no rake)
local function act()
    for src, v in pairs(Fake.lastView) do
        if v.tableId == 1 and v.private and v.private.actions and #v.private.actions > 0 then
            local a = v.private.actions[math.random(#v.private.actions)]
            if foldEarly and v.public.phase == 'bet1' and v.private.actions[1].id == 'fold' then a = v.private.actions[1] end
            if a.pick then
                -- usually a legal throw; now and then four or five cards to test the refusal
                local n = math.random() < 0.1 and math.random(4, 5) or math.random(0, 3)
                local idx = { 1, 2, 3, 4, 5 }
                GGLib.Shuffle(idx)
                local mask = 0
                for i = 1, n do mask = mask + (1 << (idx[i] - 1)) end
                if n > 3 then badDraws = badDraws + 1 end
                drawsSent = drawsSent + 1
                Fake.Net(src, 'grumpy-gambling:server:action', 'draw', mask)
            else
                local amount = a.amount
                if a.min and a.max then amount = a.min + math.random(0, (a.max - a.min) // (a.step or 1)) * (a.step or 1) end
                -- fold less than uniform so more hands reach the draw and the showdown
                if a.id == 'fold' and not foldEarly and math.random() < 0.7 then
                    local other = v.private.actions[2]
                    if other and not other.min then a, amount = other, other.amount end
                end
                Fake.Net(src, 'grumpy-gambling:server:action', a.id, amount)
            end
            return true
        end
    end
end

local before, guard = #F.hands, 0
while #F.hands - before < 200 do
    guard = guard + 1
    if guard > 300000 then error('draw poker stalled after ' .. (#F.hands - before) .. ' hands') end
    if not act() then Fake.Advance(500) end
    for seat, occ in pairs(tb.occupants) do
        local lim = GG.Wallet.Limits(tb)
        if occ.src and occ.stack < lim.step * 4 and not GG.Hands.InHand(1, seat) then
            Fake.Net(occ.src, 'grumpy-gambling:server:buyIn', (lim.max - occ.stack) / 100)
        end
    end
    check('draw hand ' .. (#F.hands - before))
end
T.ok(true, '200 hands settled, money conserved after every step')
local early = #F.hands
foldEarly = true
guard = 0
while #F.hands - early < 15 do
    guard = guard + 1
    if guard > 100000 then error('fold-early hands stalled') end
    if not act() then Fake.Advance(500) end
    check('fold-early hand')
end
foldEarly = false
local seen = {}
for _, m in ipairs(Fake.messages) do seen[m] = (seen[m] or 0) + 1 end
for _, k in ipairs({ 'draw_starts', 'draws', 'stands_pat', 'wins_hand', 'wins', 'bad_draw' }) do
    T.ok((seen[k] or 0) > 0, ('hands saw %s (%d)'):format(k, seen[k] or 0))
end
T.ok(drawsSent > 0 and badDraws > 0, ('players drew (%d), bad throws were refused (%d tried)'):format(drawsSent, badDraws))
local norake, rake = 0, 0
for i = before + 1, #F.hands do if F.hands[i].rake == 0 then norake = norake + 1 else rake = rake + 1 end end
T.ok(norake > 0 and rake > 0, ('some hands paid no rake (ended before the draw: %d), others did (%d)'):format(norake, rake))
for src = 1, NP do GG.Seats.Stand(src, nil) end
check('after standing up')
T.eq(tb.state, 'empty', 'the table resets')
