-- lib/npc_brain.lua: strength estimates, decisions that are always legal, personalities, reads, sharps.
local T = Test
local Brain, Cards, Betting, P = GGLib.Brain, GGLib.Cards, GGLib.Betting, GGLib.Poker
math.randomseed(5)

local function cards(str)
    local out = {}
    for c in str:gmatch('%S+') do out[#out + 1] = Cards.Parse(c) end
    return out
end
local function pf(a, b) return Brain.Preflop(Cards.Parse(a), Cards.Parse(b)) end

---------------------------------------------------------------------
-- Preflop
---------------------------------------------------------------------
T.eq(pf('As', 'Ah'), 1.0, 'AA is the best start')
T.eq(pf('7c', '2d'), 0.0, '72o is the worst')
T.ok(pf('As', 'Ks') > pf('Ks', 'Qs'), 'AKs > KQs')
T.ok(pf('Ks', 'Qs') > pf('Ks', 'Qd'), 'suited beats offsuit')
T.ok(pf('Ts', '9s') > pf('Ts', '5s'), 'connectors beat gappers')
T.ok(pf('2c', '2d') > pf('Kc', '4d'), 'a small pair beats K4o')

---------------------------------------------------------------------
-- Strength after the flop
---------------------------------------------------------------------
local function st(hole, board, opp) return (Brain.Strength(cards(hole), cards(board), opp)) end
T.ok(st('Ah Kh', 'Qh 7h 2h') > st('Ah Kd', 'Ac 7h 2s'), 'a made flush beats top pair')
T.ok(st('Ah Kd', 'Ac 7h 2s') > st('7c 6c', 'Ac Kh 2s'), 'top pair beats nothing')
T.ok(st('Qs Qd', 'Jc 7h 2s') > st('7s 7d', 'Jc 9h 2s'), 'an overpair beats an underpair')
T.ok(st('Ah 5h', 'Kh 9h 2c') > st('Ad 5c', 'Kh 9h 2c'), 'a flush draw adds strength')
T.ok(st('8c 7d', '9s 6h 2c') > st('8c 3d', '9s 6h 2c'), 'an open-ended straight draw adds strength')
T.ok(st('Ac 3d', 'Ks Kh 7c 7d 2s') < 0.3, 'playing the board is weak')
T.ok(st('Ah Kd', 'Ac 7h 2s', 1) > st('Ah Kd', 'Ac 7h 2s', 4), 'the same hand is worth less against more players')
T.ok(st('Kc Kd Ks 4h 4c', '') > st('Ac Qd 9s 5h 3c', ''), 'draw poker: a full house beats high card')

---------------------------------------------------------------------
-- Decisions are always legal, at every stage of a real betting round
---------------------------------------------------------------------
local personas = { 'teacher', 'tight', 'balanced', 'loose', 'aggressive', 'shark' }
local P_ = {
    teacher = { play = 0.55, call = 0.05, raise = 0.72, aggression = 0.35, bluff = 0.02, slowplay = 0.05, size = 0.5, open = 2.5, noise = 0.08 },
    tight = { play = 0.60, call = 0.08, raise = 0.75, aggression = 0.45, bluff = 0.03, slowplay = 0.15, size = 0.6, open = 3.0, noise = 0.06 },
    balanced = { play = 0.50, call = 0.03, raise = 0.68, aggression = 0.50, bluff = 0.06, slowplay = 0.10, size = 0.7, open = 3.0, noise = 0.06 },
    loose = { play = 0.38, call = -0.03, raise = 0.70, aggression = 0.35, bluff = 0.08, slowplay = 0.05, size = 0.6, open = 2.5, noise = 0.08 },
    aggressive = { play = 0.43, call = 0.00, raise = 0.60, aggression = 0.70, bluff = 0.12, slowplay = 0.05, size = 0.85, open = 3.5, noise = 0.07 },
    shark = { play = 0.50, call = 0.02, raise = 0.62, aggression = 0.65, bluff = 0.09, slowplay = 0.20, size = 0.8, open = 3.0, noise = 0.03 },
}
local illegal, decisions, folds, raises = 0, 0, 0, 0
for _ = 1, 400 do
    local n = math.random(2, 6)
    local order, stacks = {}, {}
    for s = 1, n do order[s] = s; stacks[s] = math.random(50, 600) end
    local rd = Betting.New({ order = order, stacks = stacks, bigBlind = 10 })
    rd:Post(1, 5); rd:Post(2, 10)
    rd:Begin(n >= 3 and 3 or 1)
    local shoe = Cards.NewShoe(1)
    local hole = {}
    for s = 1, n do hole[s] = { shoe:Draw(), shoe:Draw() } end
    local board = {}
    if math.random() < 0.5 then for _ = 1, math.random(3, 5) do board[#board + 1] = shoe:Draw() end end
    local guard = 0
    while rd.turn and guard < 40 do
        guard = guard + 1
        local seat = rd.turn
        local lg = rd:Legal(seat)
        local pot = 0
        for _, s in ipairs(order) do pot = pot + rd.total[s] end
        local action, amount = Brain.Decide({
            hole = hole[seat], board = board, legal = lg, pot = pot, currentBet = rd.currentBet, myBet = rd.bet[seat],
            stack = rd.stack[seat], bigBlind = 10, step = 5, opponents = #rd:Live() - 1, position = math.random(),
            persona = P_[personas[math.random(#personas)]],
        })
        decisions = decisions + 1
        if action == 'fold' then folds = folds + 1 elseif action == 'raise' or action == 'allin' then raises = raises + 1 end
        local ok = rd:Act(seat, action, amount)
        if not ok then illegal = illegal + 1; rd:Act(seat, lg.check and 'check' or 'fold') end
    end
end
T.eq(illegal, 0, ('%d brain decisions were all legal'):format(decisions))
T.ok(folds > 0 and raises > 0, ('brains fold (%d) and raise (%d)'):format(folds, raises))

---------------------------------------------------------------------
-- Personalities: AA never folds to a raise; 72o folds to a pot-sized bet; loose plays more than tight
---------------------------------------------------------------------
local function decideMany(hole, persona, legal, pot, cur, n, opp)
    local counts = {}
    for _ = 1, n do
        local a = Brain.Decide({ hole = cards(hole), board = {}, legal = legal, pot = pot, currentBet = cur, myBet = 10,
            stack = 1000, bigBlind = 10, step = 5, opponents = 1, position = 0.5, persona = persona, opp = opp })
        counts[a] = (counts[a] or 0) + 1
    end
    return counts
end
local facing = { fold = true, call = 30, raise = { min = 70, max = 1010 } } -- facing a raise to 40 from the big blind
local aa = decideMany('As Ah', P_.tight, facing, 55, 40, 300)
T.eq(aa.fold or 0, 0, 'tight AA never folds to a raise')
local trash = decideMany('7c 2d', P_.balanced, facing, 55, 40, 300)
T.ok((trash.fold or 0) > 270, ('72o folds to a raise (%d/300)'):format(trash.fold or 0))
local medium = { fold = true, call = 10, raise = { min = 30, max = 1010 } }
local tightPlays = 300 - (decideMany('Kc 9d', P_.tight, medium, 25, 20, 300).fold or 0)
local loosePlays = 300 - (decideMany('Kc 9d', P_.loose, medium, 25, 20, 300).fold or 0)
T.ok(loosePlays > tightPlays, ('loose plays K9o more than tight (%d vs %d)'):format(loosePlays, tightPlays))
local free = decideMany('7c 2d', P_.balanced, { fold = true, check = true, raise = { min = 20, max = 1000 } }, 20, 10, 200)
T.eq(free.call, nil, 'never "calls" when it can check')
T.ok((free.check or 0) > 150, 'trash checks when it can')

-- reads: call wider against a player who raises everything
local vsManiac = 300 - (decideMany('Qc 9d', P_.balanced, facing, 55, 40, 300, { agg = 0.9 }).fold or 0)
local vsRock = 300 - (decideMany('Qc 9d', P_.balanced, facing, 55, 40, 300, { agg = 0.05, bluffs = 0 }).fold or 0)
T.ok(vsManiac > vsRock, ('calls a maniac more than a rock (%d vs %d)'):format(vsManiac, vsRock))

---------------------------------------------------------------------
-- Tracker
---------------------------------------------------------------------
local tr = Brain.Tracker()
T.eq(tr:Profile('a'), nil, 'no read before enough actions')
for _ = 1, 6 do tr:Note('a', 'raise') end
for _ = 1, 2 do tr:Note('a', 'call') end
tr:Shown('a', true); tr:Shown('a', false)
local pr = tr:Profile('a')
T.near(pr.agg, 0.75, 1e-9, 'aggression = raises / actions')
T.near(pr.bluffs, 0.5, 1e-9, 'bluff rate from shown hands')

---------------------------------------------------------------------
-- PVD bets and think time
---------------------------------------------------------------------
local okBets = true
for _ = 1, 200 do
    local b = Brain.PvdBet({ bet = { 2, 6 } }, 10, 100, 1000, 10)
    if not b or b < 20 or b > 60 or b % 10 ~= 0 then okBets = false end
end
T.ok(okBets, 'PVD bets stay in the persona range, on the step')
T.eq(Brain.PvdBet({ bet = { 1, 2 } }, 10, 100, 5, 10), nil, 'no bet when the NPC cannot cover the minimum')
local tm = Brain.ThinkMs({ think = { 1000, 2000 } }, 0.5)
T.ok(tm >= 1000 and tm <= 2000, 'think time within its range')

---------------------------------------------------------------------
-- Cardsharp: a better card, and the deck stays whole
---------------------------------------------------------------------
local improved, whole = 0, true
for _ = 1, 100 do
    local shoe = Cards.NewShoe(1)
    local hole = { shoe:Draw(), shoe:Draw() }
    local before = Brain.Preflop(hole[1], hole[2])
    if Brain.SharpSwap(shoe, hole, {}) and Brain.Preflop(hole[1], hole[2]) > before then improved = improved + 1 end
    -- the undealt part of the shoe plus the hand is still exactly one deck
    local seen, n = {}, 0
    local function add(c)
        local k = c.r .. c.s
        if seen[k] then whole = false end
        seen[k] = true
        n = n + 1
    end
    for i = shoe.pos, shoe.size do add(shoe.cards[i]) end
    for _, c in ipairs(hole) do add(c) end
    if n ~= 52 then whole = false end
end
T.ok(improved > 80, ('sharps improve their hand (%d/100)'):format(improved))
T.ok(whole, 'the shoe keeps 52 unique cards and dealt cards stay out of it')
