-- Full games: the dev test module (a separate resource using lib/) plays real hands through the core. Players read
-- their legal moves from the views the game pushes and act through the core's action relay, like real clients.
local T, F = Test, FakeDB
math.randomseed(21)

local function newTable(id, kind, seats)
    local offs = {}
    for i = 1, seats do offs[i] = { x = 0, y = 0, z = 0, h = 0 } end
    local t = { id = id, label = 'T' .. id, kind = kind, source = 'public', model = 'p_tablepoker01x', bound = false,
        x = 0, y = 0, z = 0, h = 0, currency = 'cash', enabled = true, seats = offs, state = 'empty', occupants = {}, version = 0 }
    GG.Tables.byId[id] = t
    return t
end
local poker, hc = newTable(1, 'pvp', 6), newTable(2, 'pvd', 4)

local NPLAYERS, START = 10, 5000
local players = {}
for i = 1, NPLAYERS do players[i] = Fake.AddPlayer(i, 'CID' .. i, START / 100) end
local INITIAL = NPLAYERS * START

local function cents(d) return math.floor(d * 100 + 0.5) end
local function sumOf(tbl, field) local n = 0 for _, r in pairs(tbl) do n = n + r[field] end return n end
local function ledgerBy(kind) local n = 0 for _, e in ipairs(F.ledger) do if e.kind == kind then n = n + e.amount end end return n end
local function check(where)
    if next(GG.Hands.open) then return end
    local pockets = 0
    for _, P in pairs(Fake.players) do pockets = pockets + cents(P.PlayerData.money.cash) end
    local stacks, pending = sumOf(F.stacks, 'amount'), sumOf(F.pending, 'amount')
    local destroyed = -(ledgerBy('rake') + ledgerBy('sink') + ledgerBy('npc_sink'))
    local created = ledgerBy('mint') + ledgerBy('npc_mint')
    local world = pockets + stacks + pending + destroyed - created
    if world ~= INITIAL then error(('%s: money not conserved (%d vs %d)'):format(where, world, INITIAL)) end
    local led = 0 for _, e in ipairs(F.ledger) do led = led + e.amount end
    if led ~= stacks then error(('%s: ledger %d ~= stacks %d'):format(where, led, stacks)) end
end

local function start(t, game)
    t.state, t.game, t.tier = 'active', game, 'low'
    TriggerEvent('grumpy-gambling:server:tableStarted', t.id, game, 'low', 'cash')
end
local function sit(t, src)
    if GG.Seats.bySrc[src] or not Fake.bySrc[src] then return false end
    if cents(Fake.bySrc[src].PlayerData.money.cash) < 130 then return false end -- can't afford the minimum buy-in
    for i = 1, #t.seats do
        if not t.occupants[i] then
            local P = Fake.bySrc[src]
            t.occupants[i] = { src = src, cid = P.PlayerData.citizenid, name = 'P' .. src, stack = 0 }
            GG.Seats.bySrc[src] = { id = t.id, seat = i }
            if t.state ~= 'active' then start(t, t.id == 1 and 'test_showdown' or 'test_highcard') end
            TriggerEvent('grumpy-gambling:server:seatTaken', t.id, t.game, i, src)
            local avail = cents(P.PlayerData.money.cash)
            if avail >= 130 then Fake.Net(src, 'grumpy-gambling:server:buyIn', math.random(130, math.min(260, avail)) / 100) end
            return true
        end
    end
    return false
end

---------------------------------------------------------------------
-- the module registered both games from its own resource
---------------------------------------------------------------------
T.eq(GG.Registry.Get('test_showdown').resource, 'grumpy-gambling-test', 'showdown registered by the module resource')
T.eq(GG.Registry.Get('test_highcard').kind, 'pvd', 'high card is a dealer game')

---------------------------------------------------------------------
-- poker: 4 players, random play until 300 hands settle
---------------------------------------------------------------------
for src = 1, 4 do sit(poker, src) end
Fake.Advance(3000)
T.ok(GG.Hands.ForTable(poker.id) ~= nil, 'the game opened a hand')
-- another resource can't touch this table's hand
local hid = GG.Hands.ForTable(poker.id).id
Fake.invoking = 'some-other-resource'
T.eq(select(2, GG.Hands.Bet(hid, 1, 10)), 'not_your_table', 'other resources are refused')
T.eq(select(2, GG.Hands.Settle(hid, { ranking = { { 1 } } })), 'not_your_table', 'other resources cannot settle')
Fake.invoking = nil
T.ok(Fake.lastView[1] and Fake.lastView[1].public.game == 'test_showdown', 'players get the table view')

local function actor(tid)
    for src, v in pairs(Fake.lastView) do
        local s = GG.Seats.bySrc[src]
        if s and s.id == tid and v.tableId == tid and v.private and v.private.actions and #v.private.actions > 0 then return src, v end
    end
end

local function pick(actions)
    local a = actions[math.random(#actions)]
    local amount = a.amount
    if a.min and a.max then
        local steps = (a.max - a.min) // (a.step or 1)
        amount = math.random() < 0.3 and a.max or a.min + math.random(0, steps) * (a.step or 1)
    end
    return a.id, amount
end

local timeouts, standups = 0, 0
local guard = 0
while #F.hands < 300 do
    guard = guard + 1
    if guard > 60000 then
        local d = {}
        for s2, occ in pairs(poker.occupants) do d[#d + 1] = ('seat%d src%d stack%d'):format(s2, occ.src, occ.stack) end
        for i = 1, NPLAYERS do d[#d + 1] = ('p%d pocket%d seated=%s'):format(i, cents(players[i].PlayerData.money.cash), tostring(GG.Seats.bySrc[i] ~= nil)) end
        d[#d + 1] = 'openHand=' .. tostring(GG.Hands.ForTable(poker.id) ~= nil) .. ' state=' .. poker.state .. ' timers=' .. #Fake.timers
        local lv = Fake.lastView[next(Fake.lastView)]
        error('poker stalled after ' .. #F.hands .. ' hands: ' .. table.concat(d, ', '))
    end
    local src, v = actor(poker.id)
    if src and math.random() < 0.01 then
        Fake.Advance(31000); timeouts = timeouts + 1           -- let the action timer run out
    elseif src then
        local id, amount = pick(v.private.actions)
        Fake.Net(src, 'grumpy-gambling:server:action', id, amount)
    else
        Fake.Advance(7000)                                     -- between hands
    end
    -- people come and go
    if math.random() < 0.004 then
        local occ = poker.occupants[math.random(#poker.seats)]
        if occ then GG.Seats.Stand(occ.src, nil); standups = standups + 1 end
    end
    for s, occ in pairs(poker.occupants) do
        if occ.stack == 0 and not GG.Hands.InHand(poker.id, s) then GG.Seats.Stand(occ.src, nil) end
    end
    local seated = 0
    for _ in pairs(poker.occupants) do seated = seated + 1 end
    if seated < 3 then for src2 = 1, NPLAYERS do if sit(poker, src2) then break end end end
    check('poker after ' .. #F.hands .. ' hands')
end
T.ok(timeouts > 0 and standups > 0, ('300 poker hands with time-outs (%d) and stand-ups (%d)'):format(timeouts, standups))
T.ok(-ledgerBy('rake') > 0, 'rake was taken')
local showdowns = 0
for _, m in ipairs(Fake.messages) do if m == 'wins_hand' then showdowns = showdowns + 1 end end
T.ok(showdowns > 0, 'hands reached a showdown')

---------------------------------------------------------------------
-- high card: 3 players against the house, 200 rounds
---------------------------------------------------------------------
for _, occ in pairs(poker.occupants) do GG.Seats.Stand(occ.src, nil) end
Fake.Advance(10000)
local before = #F.hands
for src = 5, 7 do sit(hc, src) end
guard = 0
while #F.hands - before < 200 do
    guard = guard + 1
    if guard > 20000 then error('high card stalled') end
    local src, v = actor(hc.id)
    if src and math.random() < 0.85 then
        local id, amount = pick(v.private.actions)
        Fake.Net(src, 'grumpy-gambling:server:action', id, amount)
    else
        Fake.Advance(16000)
    end
    for s, occ in pairs(hc.occupants) do
        if occ.stack < 10 and not GG.Hands.InHand(hc.id, s) then GG.Seats.Stand(occ.src, nil) end
    end
    local seated = 0
    for _ in pairs(hc.occupants) do seated = seated + 1 end
    if seated < 2 then for src2 = 1, NPLAYERS do if sit(hc, src2) then break end end end
    check('high card after ' .. (#F.hands - before) .. ' rounds')
end
T.ok(true, '200 high-card rounds against the house')
T.ok(ledgerBy('mint') > 0 and ledgerBy('sink') < 0, 'the house both paid out and kept losses')

---------------------------------------------------------------------
-- one real player against two NPCs (dev /ggbot path); the test bot plays the NPC seats
---------------------------------------------------------------------
for _, occ in pairs(hc.occupants) do if occ.src then GG.Seats.Stand(occ.src, nil) end end
Fake.Advance(20000)
local human
for src = 1, NPLAYERS do if sit(poker, src) then human = src break end end
T.ok(human ~= nil, 'a real player sits')
T.ok(GG.Npc.Seat(poker, 5) ~= nil and GG.Npc.Seat(poker, 6) ~= nil, 'two NPCs seated')
T.eq(GG.Tables.RealCount(poker), 1, 'NPCs are not real players')
local before2, npcActs = #F.hands, 0
guard = 0
while #F.hands - before2 < 100 do
    guard = guard + 1
    if guard > 20000 then error('NPC poker stalled') end
    local src, v = actor(poker.id)
    if src then
        local id, amount = pick(v.private.actions)
        Fake.Net(src, 'grumpy-gambling:server:action', id, amount)
    else
        Fake.Advance(2000); npcActs = npcActs + 1          -- NPC bots act on their own timers
    end
    for seat, occ in pairs(poker.occupants) do
        if occ.npc and occ.stack == 0 and not GG.Hands.InHand(poker.id, seat) then
            GG.Npc.Remove(poker, seat); GG.Npc.Seat(poker, seat)
        elseif not occ.npc and occ.stack == 0 and not GG.Hands.InHand(poker.id, seat) then
            GG.Seats.Stand(occ.src, nil)
        end
    end
    if GG.Tables.RealCount(poker) == 0 then
        for src2 = 1, NPLAYERS do if sit(poker, src2) then human = src2 break end end
        if GG.Tables.RealCount(poker) == 0 then break end
        GG.Npc.Seat(poker, 5); GG.Npc.Seat(poker, 6)
    end
    check('npc poker after ' .. (#F.hands - before2) .. ' hands')
end
T.ok(#F.hands - before2 >= 100, '100 hands against NPCs')
T.ok(npcActs > 0 and ledgerBy('npc_mint') > 0, 'NPCs played with created chips')
-- the last real player leaves: the NPCs go too and their chips are destroyed
for _, occ in pairs(poker.occupants) do if occ.src then GG.Seats.Stand(occ.src, nil) end end
local npcLeft = 0
for _, occ in pairs(poker.occupants) do if occ.npc then npcLeft = npcLeft + 1 end end
T.eq(npcLeft, 0, 'NPCs leave with the last real player')
T.eq(poker.state, 'empty', 'table reset')
local npcRows = 0
for cid in pairs(F.stacks) do if cid:sub(1, 4) == 'npc:' then npcRows = npcRows + 1 end end
T.eq(npcRows, 0, 'no NPC stack rows left')
check('after NPCs left')
