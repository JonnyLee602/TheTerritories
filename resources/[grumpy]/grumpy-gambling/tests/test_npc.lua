-- NPC system (DESIGN.md §8) through the real core and the dev test games: the seating rule, leaving only between
-- hands, the win cap, scenery bets at dealer tables, regulars, cardsharp call-outs, and money conservation.
local T, F = Test, FakeDB
math.randomseed(77)
local Npc = GG.Npc

local function newTable(id, kind, seats, currency, x, y)
    local offs = {}
    for i = 1, seats do offs[i] = { x = 0, y = 0, z = 0, h = 0 } end
    local t = { id = id, label = 'T' .. id, kind = kind, source = 'public', model = 'p_tablepoker01x', bound = false,
        x = x or 0, y = y or 0, z = 0, h = 0, currency = currency or 'cash', enabled = true, seats = offs, state = 'empty',
        occupants = {}, version = 0, settings = {} }
    GG.Tables.byId[id] = t
    return t
end

local NPLAYERS, START = 8, 20000
local players = {}
for i = 1, NPLAYERS do players[i] = Fake.AddPlayer(i, 'CID' .. i, START / 100, START / 100) end
local INITIAL = NPLAYERS * START * 2

local function cents(d) return math.floor(d * 100 + 0.5) end
local function sumOf(tbl, field) local n = 0 for _, r in pairs(tbl) do n = n + r[field] end return n end
local function ledgerBy(kind) local n = 0 for _, e in ipairs(F.ledger) do if e.kind == kind then n = n + e.amount end end return n end
local function check(where)
    if next(GG.Hands.open) then return end
    local pockets = 0
    for _, P in pairs(Fake.players) do pockets = pockets + cents(P.PlayerData.money.cash) + cents(P.PlayerData.money.bloodmoney) end
    local stacks, pending = sumOf(F.stacks, 'amount'), sumOf(F.pending, 'amount')
    local destroyed = -(ledgerBy('rake') + ledgerBy('sink') + ledgerBy('npc_sink'))
    local created = ledgerBy('mint') + ledgerBy('npc_mint')
    local world = pockets + stacks + pending + destroyed - created
    if world ~= INITIAL then error(('%s: money not conserved (%d vs %d)'):format(where, world, INITIAL)) end
    local led = 0 for _, e in ipairs(F.ledger) do led = led + e.amount end
    if led ~= stacks then error(('%s: ledger %d ~= stacks %d'):format(where, led, stacks)) end
end

local function npcCount(t) local n = 0 for _, o in pairs(t.occupants) do if o.npc then n = n + 1 end end return n end
local function realCount(t) return GG.Tables.RealCount(t) end

local function start(t, game, tier)
    t.state, t.game, t.tier = 'active', game, tier or 'low'
    TriggerEvent('grumpy-gambling:server:tableStarted', t.id, game, t.tier, t.currency)
end
-- a real player sits in the first free seat (the core's sit flow minus the distance check) and buys in
local function sit(t, src, game)
    for i = 1, #t.seats do
        if not t.occupants[i] then
            local P = Fake.bySrc[src]
            t.occupants[i] = { src = src, cid = P.PlayerData.citizenid, name = 'P' .. src, stack = 0 }
            GG.Seats.bySrc[src] = { id = t.id, seat = i }
            if t.state ~= 'active' then start(t, game) end
            GG.Tables.OnSeatTaken(t, i, src)
            local lim = GG.Wallet.Limits(t)
            Fake.Net(src, 'grumpy-gambling:server:buyIn', lim.max / 100)
            return i
        end
    end
end

-- real players act randomly from their views; time passes otherwise (NPCs think, hands start, the tick runs)
local function actor(tid)
    for src, v in pairs(Fake.lastView) do
        local s = GG.Seats.bySrc[src]
        if s and s.id == tid and v.tableId == tid and v.private and v.private.actions and #v.private.actions > 0 then return src, v end
    end
end
local function pick(actions)
    local a = actions[math.random(#actions)]
    local amount = a.amount
    if a.min and a.max then amount = a.min + math.random(0, (a.max - a.min) // (a.step or 1)) * (a.step or 1) end
    return a.id, amount
end
local function play(t, hands, where, each)
    local target, guard = #F.hands + hands, 0
    while #F.hands < target do
        guard = guard + 1
        if guard > 20000 then error(where .. ': stalled at ' .. #F.hands .. ' hands, npcs ' .. npcCount(t)) end
        local src, v = actor(t.id)
        if src then Fake.Net(src, 'grumpy-gambling:server:action', pick(v.private.actions))
        else Fake.Advance(1000); Npc.Tick() end
        if each then each() end
        check(where)
    end
end
local function settle(ms) for _ = 1, (ms or 10000) // 1000 do Fake.Advance(1000); Npc.Tick() end end

---------------------------------------------------------------------
-- 1. Seating rule: a solo player gets seats - 1 - 1 NPCs, one seat always free
---------------------------------------------------------------------
local poker = newTable(1, 'pvp', 6)
Config.Npc.Chatter.Chance.join = 1.0
sit(poker, 1, 'test_showdown')
settle(15000)
Config.Npc.Chatter.Chance.join = 0.6
T.eq(npcCount(poker), 4, 'solo player at 6 seats: 4 NPCs (one seat stays free)')
T.eq(Npc.Wanted(poker), 4, 'wanted = seats - real - 1')
local msgs = 0
for _, m in ipairs(Fake.messages) do if m == 'npc_says' then msgs = msgs + 1 end end
T.ok(msgs > 0, 'NPCs talk when they sit down')

play(poker, 20, 'solo')
T.ok(true, 'a solo player plays 20 hands against NPCs')

-- 2. a second player takes the free seat: an NPC leaves, but only between hands
local guard = 0
while not GG.Hands.ForTable(poker.id) and guard < 30 do Fake.Advance(500); guard = guard + 1 end
T.ok(GG.Hands.ForTable(poker.id) ~= nil, 'a hand is in progress')
local before = npcCount(poker)
sit(poker, 2, 'test_showdown')
Npc.Tick()
T.eq(npcCount(poker), before, 'no NPC leaves in the middle of a hand')
play(poker, 2, 'second player')
settle(4000)
T.eq(npcCount(poker), 3, 'after the hand an NPC made room: 6 seats, 2 players, 3 NPCs')

-- 3. everyone at a full table of real players: no NPCs at all
for src = 3, 6 do
    play(poker, 1, 'filling')
    settle(4000)
    sit(poker, src, 'test_showdown')
end
play(poker, 2, 'full')
settle(4000)
T.eq(npcCount(poker), 0, 'six real players: no NPCs')
T.eq(realCount(poker), 6, 'six real players seated')

-- 4. players leave: NPCs come back, and leave with the last player
for src = 2, 6 do GG.Seats.Stand(src, nil) end
settle(20000)
T.eq(npcCount(poker), 4, 'back to one player: NPCs fill in again')
play(poker, 30, 'long session', function()
    for s, occ in pairs(poker.occupants) do
        if occ.src and occ.stack == 0 and not GG.Hands.InHand(poker.id, s) then
            Fake.Net(occ.src, 'grumpy-gambling:server:buyIn', GG.Wallet.Limits(poker).max / 100)
        end
    end
end)
T.ok(ledgerBy('npc_mint') > 0 and ledgerBy('npc_sink') < 0, 'NPC chips are created and destroyed in the ledger')
local cueSeen = {}
for _, e in ipairs(Fake.clientEvents) do
    if e.name == 'grumpy-gambling:client:seatCue' and e.args[1] == poker.id then cueSeen[e.args[3]] = (cueSeen[e.args[3]] or 0) + 1 end
end
T.ok(cueSeen.blind and cueSeen.win and cueSeen.buyin, 'blinds, pot wins and buy-ins play clips')
T.ok((cueSeen.fold or 0) + (cueSeen.call or 0) + (cueSeen.check or 0) > 0, 'moves play clips')
T.ok((cueSeen.strong or 0) + (cueSeen.bluff or 0) > 0, ('NPC tells show (%d strong, %d bluff)'):format(cueSeen.strong or 0, cueSeen.bluff or 0))
GG.Seats.Stand(1, nil)
T.eq(npcCount(poker), 0, 'NPCs leave with the last real player')
T.eq(poker.state, 'empty', 'the table resets')
check('after reset')

---------------------------------------------------------------------
-- 5. Win cap: attribution per hand, and NPCs call it a night for a capped player
---------------------------------------------------------------------
local fakeHand = { seats = {
    [1] = { cid = 'A', contrib = 100 }, [2] = { cid = 'B', contrib = 100 },
    [3] = { cid = 'npc:9:3', npc = true, contrib = 300 }, [4] = { cid = 'C', contrib = 50 },
} }
local entries = Npc.CapEntries(fakeHand, { [1] = 400, [2] = 200 }) -- A +300, B +100, C -50, NPC -300
local byCid = {}
for _, e in ipairs(entries) do byCid[e.cid] = e.amount end
T.eq(byCid.A, 225, 'NPC losses go to the winners in proportion (A won 3/4)')
T.eq(byCid.B, 75, 'B won 1/4 of what the NPC lost')
T.eq(byCid.C, nil, 'losers get nothing when NPCs lost')
entries = Npc.CapEntries(fakeHand, { [3] = 550 }) -- NPC +250, A -100, B -100, C -50
byCid = {}
for _, e in ipairs(entries) do byCid[e.cid] = e.amount end
T.eq(byCid.A, -100, 'NPC wins come off the losers, never more than they lost (A)')
T.eq(byCid.C, -50, 'C is credited back what it lost')
T.eq(#Npc.CapEntries({ seats = { [1] = { cid = 'A', contrib = 10 }, [2] = { cid = 'B', contrib = 10 } } }, { [1] = 20 }), 0,
    'hands without NPCs never touch the window')

sit(poker, 7, 'test_showdown')
settle(15000)
T.eq(npcCount(poker), 4, 'NPCs sit with player 7')
-- player 7 has already won the cap from NPCs this window
-- (with headroom: losing the next hand to the NPCs would credit some back and reopen the window)
local injected = { cid = 'CID7', ts = os.time() - 60, amount = Npc.Cap(poker) * 3 }
F.window[#F.window + 1] = injected
Npc.window['CID7'] = nil
T.ok(Npc.Capped('CID7', poker), 'player 7 is at the cap')
T.eq(Npc.Wanted(poker), 0, 'a capped player gets no NPCs')
play(poker, 1, 'capped')
settle(5000)
T.eq(npcCount(poker), 0, 'the NPCs called it a night')
local nights = 0
for _, e in ipairs(Fake.clientEvents) do
    if e.name == 'grumpy-gambling:client:message' and e.args[2] == 'npc_says' then nights = nights + 1 end
end
T.ok(nights > 0, 'they said goodbye')
-- an old entry outside the window no longer counts
for _, w in ipairs(F.window) do if w.cid == 'CID7' then w.ts = os.time() - Config.Npc.CapWindowMinutes * 60 - 5 end end
Npc.window['CID7'] = nil
T.ok(not Npc.Capped('CID7', poker), 'the window frees up')
settle(15000)
T.eq(npcCount(poker), 4, 'NPCs come back once the window frees up')
-- cap entries are written in the settle transaction
local w0 = #F.window
play(poker, 15, 'window rows')
T.ok(#F.window > w0, 'hands against NPCs add window rows')
GG.Seats.Stand(7, nil)
check('after cap')

---------------------------------------------------------------------
-- 6. Dealer games: NPC bets are scenery (no house money, no rake, no cover)
---------------------------------------------------------------------
local hc = newTable(2, 'pvd', 4)
local houseBefore = ledgerBy('mint') + ledgerBy('sink')
local rakeBefore = ledgerBy('rake')
sit(hc, 8, 'test_highcard')
settle(12000)
T.eq(npcCount(hc), 2, 'dealer table, 4 seats, 1 player: 2 NPCs')
-- player 8 never bets: only NPC bets for a while
local h0 = #F.hands
for _ = 1, 120 do Fake.Advance(1000); Npc.Tick(); check('pvd scenery') end
T.ok(#F.hands > h0, 'rounds with only NPC bets settle')
T.eq(ledgerBy('mint') + ledgerBy('sink'), houseBefore, 'NPC bets never create or destroy house money')
T.eq(ledgerBy('rake'), rakeBefore, 'NPC bets pay no rake')
local scenery = 0
for _, e in ipairs(F.ledger) do if e.note == 'pvd scenery' then scenery = scenery + 1 end end
T.ok(scenery > 0, 'NPC stacks still move with their results (ledgered as npc_mint / npc_sink)')
GG.Seats.Stand(8, nil)
check('after pvd')

---------------------------------------------------------------------
-- 7. Profiles: tier and drunk modifiers
---------------------------------------------------------------------
local fakeT = { tier = 'high' }
local prof = Npc.Profile(fakeT, { persona = 'tight', drunk = true, tilt = 0, name = 'X' })
T.near(prof.tells, 1.0 * 0.5 * 2.0, 1e-9, 'tells: persona × high-tier 0.5 × drunk 2')
T.near(prof.play, 0.60 - 0.05 - 0.10, 1e-9, 'play threshold: persona + tier + drunk')
local tilted = Npc.Profile({ tier = 'low' }, { persona = 'tight', tilt = 2, name = 'Y' })
T.ok(tilted.aggression > Config.Npc.Personas.tight.aggression, 'tilt makes them more aggressive')
T.eq(prof.sharp, nil, 'not a sharp unless flagged')

---------------------------------------------------------------------
-- 8. Regulars: chosen at their home tables, remember players, greet them
---------------------------------------------------------------------
Config.Npc.Regulars.Chance = 1.0
local valentine = newTable(3, 'pvp', 6, 'cash', -308.29, 810.2)
F.memory['old_jeb|CID3'] = { hands = 50, net = 500, lastSeen = 0 } -- Jeb has won a lot off player 3
sit(valentine, 3, 'test_showdown')
start(valentine, 'test_showdown', 'low')
settle(15000)
local jeb
for s, o in pairs(valentine.occupants) do if o.regular == 'old_jeb' then jeb = s end end
T.ok(jeb ~= nil, 'Old Jeb sits at his home table in Valentine')
T.eq(Npc.regularsAt['old_jeb'], valentine.id, 'a regular is only at one table at a time')
local greeted = false
for _, e in ipairs(Fake.clientEvents) do
    if e.name == 'grumpy-gambling:client:message' and e.src == 3 and e.args[2] == 'npc_says' then greeted = true end
end
T.ok(greeted, 'the regular greets a player he knows')
play(valentine, 10, 'regulars')
GG.Seats.Stand(3, nil)
local m = F.memory['old_jeb|CID3']
T.ok(m and m.hands >= 55, ('memory saved as increments when the regular leaves (%s hands)'):format(m and m.hands or 'nil'))
T.eq(Npc.regularsAt['old_jeb'], nil, 'the regular is free again')
Config.Npc.Regulars.Chance = 0.35
check('after regulars')

---------------------------------------------------------------------
-- 9. Cardsharps at a back-room table: a right call-out voids the hand; a wrong one has a cost
---------------------------------------------------------------------
Config.Npc.Sharp.Chance, Config.Npc.Sharp.CheatChance, Config.Npc.Sharp.TellChance = 1.0, 1.0, 1.0
local back = newTable(4, 'pvp', 4, 'bloodmoney')
local function sitBlood(t, src)
    local i = 1
    while t.occupants[i] do i = i + 1 end
    local P = Fake.bySrc[src]
    t.occupants[i] = { src = src, cid = P.PlayerData.citizenid, name = 'P' .. src, stack = 0 }
    GG.Seats.bySrc[src] = { id = t.id, seat = i }
    if t.state ~= 'active' then start(t, 'test_showdown', 'low') end
    GG.Tables.OnSeatTaken(t, i, src)
    Fake.Net(src, 'grumpy-gambling:server:buyIn', GG.Wallet.Limits(t).max / 100)
end
sitBlood(back, 4)
settle(10000)
T.eq(npcCount(back), 2, 'back room, 4 seats: 2 NPCs')
for _, o in pairs(back.occupants) do if o.npc then T.ok(o.sharp, 'everyone is a sharp in this test') end end
guard = 0
while not GG.Hands.ForTable(back.id) and guard < 30 do Fake.Advance(500); guard = guard + 1 end
local h = GG.Hands.ForTable(back.id)
T.ok(h ~= nil, 'a back-room hand is in progress')
local stackBefore = back.occupants[GG.Seats.bySrc[4].seat].stack
-- a sharp that swapped a card this hand shows it (TellChance = 1 here): that's the one to call out
local sharpSeat
for _, e in ipairs(Fake.clientEvents) do
    if e.name == 'grumpy-gambling:client:seatCue' and e.args[1] == back.id and e.args[3] == 'sleight' then sharpSeat = e.args[2] end
end
T.ok(sharpSeat ~= nil, 'a sharp showed a sleight')
Fake.Net(4, 'grumpy-gambling:server:callOut', back.id, sharpSeat)
T.eq(GG.Hands.ForTable(back.id), nil, 'a right call-out calls the hand off')
T.eq(back.occupants[GG.Seats.bySrc[4].seat].stack, stackBefore, 'the player keeps their pre-hand stack')
T.eq(back.occupants[sharpSeat] and back.occupants[sharpSeat].leaving, 'caught', 'the cheat is thrown out')
Config.Npc.Sharp.CheatChance = 0.0 -- from here on nobody cheats (the next hand may start while we wait)
settle(4000)
T.ok(not back.occupants[sharpSeat] or not back.occupants[sharpSeat].cid:find(':' .. sharpSeat .. '$') or
    back.occupants[sharpSeat].leaving == nil, 'the cheat has left')
check('after call-out')
-- a wrong call-out (no cheating this hand)
guard = 0
while not GG.Hands.ForTable(back.id) and guard < 40 do Fake.Advance(500); Npc.Tick(); guard = guard + 1 end
local other
for s, o in pairs(back.occupants) do if o.npc then other = s end end
local openBefore = GG.Hands.ForTable(back.id) ~= nil
local m0 = #Fake.messages
Fake.Net(4, 'grumpy-gambling:server:callOut', back.id, other)
T.ok(GG.Hands.ForTable(back.id) ~= nil, ('a wrong call-out leaves the hand alone (open before %s, other %s, npcs %d, state %s)'):format(
    tostring(openBefore), tostring(other), npcCount(back), back.state) .. ' msgs: ' .. table.concat(Fake.messages, ',', m0 + 1))
T.ok((Npc.callOutBlock['CID4'] or 0) > os.time(), 'and the accuser has to wait before trying again')
-- cash tables have no call-outs
GG.Seats.Stand(4, nil)
check('end')
Config.Npc.Sharp.Chance, Config.Npc.Sharp.CheatChance, Config.Npc.Sharp.TellChance = 0.15, 0.25, 0.6
