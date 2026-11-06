-- Sitting out: missed hands stand a player up, and so does staying out of chips past the rebuy time.
local T, F = Test, FakeDB
math.randomseed(11)
local offs = {}
for i = 1, 4 do offs[i] = { x = 0, y = 0, z = 0, h = 0 } end
local tb = { id = 1, label = 'HC', kind = 'pvd', source = 'public', model = 'p_blackjacktable01x', bound = false, x = 0, y = 0, z = 0,
    h = 0, currency = 'cash', enabled = true, seats = offs, state = 'empty', occupants = {}, version = 0, settings = {},
    dealer = { x = 0, y = 0.7, z = 0, h = 180 } }
GG.Tables.byId[1] = tb
for i = 1, 3 do Fake.AddPlayer(i, 'CID' .. i, 500) end

local function seat(src, buy)
    tb.occupants[src] = { src = src, cid = 'CID' .. src, name = 'P' .. src, stack = 0 }
    GG.Seats.bySrc[src] = { id = 1, seat = src }
    if tb.state ~= 'active' then
        tb.state, tb.game, tb.tier = 'active', 'test_highcard', 'low'
        TriggerEvent('grumpy-gambling:server:tableStarted', 1, 'test_highcard', 'low', 'cash')
    end
    GG.Tables.OnSeatTaken(tb, src, src)
    if buy then Fake.Net(src, 'grumpy-gambling:server:buyIn', GG.Wallet.Limits(tb).max / 100) end
end
local function notified(src, key)
    for _, e in ipairs(Fake.clientEvents) do
        if e.name == 'RSGCore:Client:Notify' and e.src == src and e.args[1] and e.args[1].description == key then return true end
    end
    return false
end

---------------------------------------------------------------------
-- 1. Missed hands: player 1 bets every round, player 2 never moves
---------------------------------------------------------------------
seat(1, true)
seat(2, true)
local rounds, guard = 0, 0
local lastHands = #F.hands
while GG.Seats.bySrc[2] and guard < 2000 do
    guard = guard + 1
    local v = Fake.lastView[1]
    if v and v.private and v.private.actions and #v.private.actions > 0 then
        Fake.Net(1, 'grumpy-gambling:server:action', 'bet', v.private.actions[1].min)
    end
    Fake.Advance(1000)
    if #F.hands > lastHands then rounds = rounds + (#F.hands - lastHands); lastHands = #F.hands end
end
T.ok(GG.Seats.bySrc[2] == nil, ('a player who never moves is stood up (after %d rounds)'):format(rounds))
T.ok(notified(2, 'missed_warn'), 'they were warned one hand before')
T.ok(notified(2, 'stood_missed'), 'and told why')
T.ok(GG.Seats.bySrc[1] ~= nil, 'the player who kept betting stays')
T.eq(tb.occupants[1].missed, 0, 'moves reset the count')

---------------------------------------------------------------------
-- 2. Out of chips: the chips window, then stood up after the rebuy time
---------------------------------------------------------------------
seat(3, false)                          -- sits without buying in
GG.Seats.CheckBroke(tb)
local offered = false
for _, e in ipairs(Fake.clientEvents) do if e.name == 'grumpy-gambling:client:chips' and e.src == 3 then offered = true end end
T.ok(offered and notified(3, 'chips_rebuy'), 'no chips: the chips window opens with a warning')
T.ok(GG.Seats.bySrc[3] ~= nil, 'still seated while there is time')
tb.occupants[3].brokeSince = os.time() - Config.Seating.RebuySeconds - 1
GG.Seats.CheckBroke(tb)
T.ok(GG.Seats.bySrc[3] == nil and notified(3, 'stood_broke'), 'stood up when the time runs out')

-- buying in stops the clock
seat(3, false)
GG.Seats.CheckBroke(tb)
Fake.Net(3, 'grumpy-gambling:server:buyIn', GG.Wallet.Limits(tb).max / 100)
GG.Seats.CheckBroke(tb)
T.eq(tb.occupants[3] and tb.occupants[3].brokeSince, nil, 'buying in clears the timer')

---------------------------------------------------------------------
-- 3. Every player's view carries their own chips, refreshed by a buy-in
---------------------------------------------------------------------
local v3 = Fake.lastView[3]
T.ok(v3 and v3.private and v3.private._chips == tb.occupants[3].stack, ('the view shows your chips (%s)'):format(v3 and v3.private and tostring(v3.private._chips)))
local v1 = Fake.lastView[1]
T.ok(v1 and v1.private and v1.private._chips ~= nil, "and every seated player's own")
