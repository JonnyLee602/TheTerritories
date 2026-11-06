-- Module library: cards, poker evaluation and the betting engine.
local T = Test
local C, P, B = GGLib.Cards, GGLib.Poker, GGLib.Betting
local function hand(str) local out = {} for c in str:gmatch('%S+') do out[#out + 1] = assert(C.Parse(c), c) end return out end
local function best(str) local s, name = P.Best(hand(str)); return s, name end

---------------------------------------------------------------------
-- shoe
---------------------------------------------------------------------
local shoe = C.NewShoe(1)
local seen, n = {}, 0
while true do
    local c = shoe:Draw()
    if not c then break end
    local k = C.Str(c)
    if seen[k] then error('duplicate card ' .. k) end
    seen[k] = true; n = n + 1
end
T.eq(n, 52, 'a deck has 52 unique cards'); T.eq(shoe:Remaining(), 0, 'shoe empty')
T.eq(#C.NewShoe(6).cards, 312, 'six-deck shoe')
T.eq(C.Public(C.Parse('Th')).r, 'T', 'public card'); T.ok(C.Public(C.Parse('Th'), false).down, 'face-down card hides it')

---------------------------------------------------------------------
-- evaluator
---------------------------------------------------------------------
local names = {
    { 'As Ks Qs Js Ts', 'straight_flush' }, { '9c 9d 9h 9s 2c', 'four_of_a_kind' }, { 'Kc Kd Kh 2s 2c', 'full_house' },
    { '2h 7h 9h Jh Ah', 'flush' }, { '5c 6d 7h 8s 9c', 'straight' }, { 'Ac 2d 3h 4s 5c', 'straight' },
    { '7c 7d 7h Ks 2c', 'three_of_a_kind' }, { 'Jc Jd 4h 4s Ac', 'two_pair' }, { 'Tc Td 4h 8s Ac', 'pair' },
    { '2c 5d 9h Js Kc', 'high_card' },
}
for _, c in ipairs(names) do T.eq(select(2, best(c[1])), c[2], c[1]) end
local function beats(a, b) return P.Compare((best(a)), (best(b))) > 0 end
T.ok(beats('2c 3d 4h 5s 6c', 'Ac 2d 3h 4s 5c'), 'six-high straight beats the wheel')
T.ok(beats('Ah Kh 9h 5h 2h', 'Ah Qh Jh Th 8h'), 'flush compared by kickers')
T.ok(beats('Kc Kd Kh 2s 2c', 'Qc Qd Qh As Ac'), 'full house: trips decide')
T.ok(beats('Jc Jd 4h 4s Kc', 'Jh Js 4c 4d Qc'), 'two pair: kicker decides')
T.ok(beats('Tc Td Ah 8s 3c', 'Th Ts Kh Qs Jc'), 'pair: kickers decide')
T.eq(P.Compare((best('As Kd 9h 5s 2c')), (best('Ad Ks 9c 5h 2d'))), 0, 'same ranks, different suits tie')
-- 7 cards: board plays / hole cards improve
local s7, n7 = P.Best(hand('Ah Kh 2c 7d Qh Jh Th'))
T.eq(n7, 'straight_flush', 'royal flush found among 7 cards'); T.eq(s7[2], 14, 'ace high')
T.eq(select(2, P.Best(hand('2c 2d 2h 2s 3c 3d 3h'))), 'four_of_a_kind', 'quads over full house among 7')
-- ranking groups
local r = P.Ranking({ { seat = 1, score = (best('2c 5d 9h Js Kc')) }, { seat = 4, score = (best('Tc Td 4h 8s Ac')) },
    { seat = 6, score = (best('Th Ts 4c 8d As')) } })
T.eq(#r, 2, 'tie grouped'); T.eq(#r[1], 2, 'two winners tie'); T.eq(r[1][1], 4, 'seat order inside a group'); T.eq(r[2][1], 1, 'loser last')

---------------------------------------------------------------------
-- betting: heads-up preflop, button posts the small blind and acts first
---------------------------------------------------------------------
local rd = B.New({ order = { 1, 2 }, stacks = { [1] = 200, [2] = 200 }, bigBlind = 10 })
T.eq(rd:Post(1, 5), 5, 'small blind'); T.eq(rd:Post(2, 10), 10, 'big blind')
rd:Begin(1)
T.eq(rd.turn, 1, 'button acts first heads-up')
local lg = rd:Legal(1)
T.eq(lg.call, 5, 'call 5 to complete'); T.eq(lg.raise.min, 20, 'min raise to 20'); T.eq(lg.raise.max, 200, 'max all-in')
T.eq(select(2, rd:Act(2, 'check')), 'not_your_turn', 'out of turn refused')
T.ok(rd:Act(1, 'call'), 'button completes')
T.eq(rd.turn, 2, 'big blind gets the option'); T.ok(rd:Legal(2).check, 'big blind may check')
T.ok(rd:Act(2, 'check'), 'big blind checks'); T.ok(rd:Done(), 'betting over')

-- raise, re-raise, call
rd = B.New({ order = { 1, 2, 3 }, stacks = { [1] = 500, [2] = 500, [3] = 500 }, bigBlind = 10 })
rd:Post(2, 5); rd:Post(3, 10); rd:Begin(1)
T.eq(select(2, rd:Act(1, 'raise', 15)), 'illegal', 'raise below the minimum (to 20) refused')
local ok, put = rd:Act(1, 'raise', 30); T.ok(ok, 'raise to 30'); T.eq(put, 30, 'puts 30')
T.eq(rd:Legal(2).raise.min, 50, 'min re-raise = last raise size (20) on top')
rd:Act(2, 'raise', 80); T.eq(rd.minRaise, 50, 'raise size 50 becomes the minimum')
rd:Act(3, 'fold'); T.eq(rd.turn, 1, 'action back to the opener')
ok, put = rd:Act(1, 'call'); T.eq(put, 50, 'calls the extra 50'); T.ok(rd:Done(), 'done')
T.eq(rd.total[1] + rd.total[2] + rd.total[3], 170, 'chips in: 80 + 80 + 10')

-- a short all-in doesn't reopen the betting
rd = B.New({ order = { 1, 2, 3 }, stacks = { [1] = 500, [2] = 45, [3] = 500 }, bigBlind = 10 })
rd:Begin(1)
rd:Act(1, 'raise', 30)               -- full raise (bet)
rd:Act(2, 'allin')                   -- all-in to 45: a 15 raise, less than the 30 minimum
T.eq(rd.currentBet, 45, 'short all-in raises the bet')
T.ok(rd:Legal(3).raise ~= nil, 'player 3 has not acted yet: may raise')
rd:Act(3, 'call')
T.eq(rd.turn, 1, 'back to the opener'); T.eq(rd:Legal(1).raise, nil, 'opener may only call or fold (not reopened)')
T.eq(rd:Legal(1).call, 15, 'opener calls 15 more'); rd:Act(1, 'call'); T.ok(rd:Done(), 'done after short all-in')

-- uncalled bet comes back
rd = B.New({ order = { 1, 2 }, stacks = { [1] = 300, [2] = 100 }, bigBlind = 10 })
rd:Begin(1); rd:Act(1, 'raise', 250); rd:Act(2, 'allin')
T.ok(rd:Done(), 'all-in call ends it')
local us, ua = rd:Uncalled()
T.eq(us, 1, 'uncalled goes to the big bettor'); T.eq(ua, 150, '150 nobody matched'); T.eq(rd.stack[1], 200, 'back in the stack')

-- everyone folds to the big blind
rd = B.New({ order = { 1, 2, 3 }, stacks = { [1] = 100, [2] = 100, [3] = 100 }, bigBlind = 10 })
rd:Post(2, 5); rd:Post(3, 10); rd:Begin(1)
rd:Act(1, 'fold'); rd:Act(2, 'fold'); T.ok(rd:Done(), 'one player left'); T.eq(#rd:Live(), 1, 'big blind wins')

-- a player who leaves is folded and the turn moves on
rd = B.New({ order = { 1, 2, 3 }, stacks = { [1] = 100, [2] = 100, [3] = 100 }, bigBlind = 10 })
rd:Begin(1); rd:Remove(1); T.eq(rd.turn, 2, 'turn passes when the actor leaves')

-- fuzz: random legal play always ends, never over-spends, and chips balance
math.randomseed(11)
for g = 1, 3000 do
    local seats = math.random(2, 6)
    local order, stacks, start = {}, {}, {}
    for s = 1, seats do order[s] = s; stacks[s] = math.random(1, 40) * 5; start[s] = stacks[s] end
    local r2 = B.New({ order = order, stacks = stacks, bigBlind = 10 })
    r2:Post(1, 5); r2:Post(2 % seats + 1, 10); r2:Begin(3 % seats + 1)
    local steps = 0
    while not r2:Done() do
        steps = steps + 1
        if steps > 200 then error('betting round did not end in game ' .. g) end
        local s = r2.turn
        if not s then error('no turn but not done in game ' .. g) end
        local lgl = r2:Legal(s)
        local roll = math.random()
        local okA
        if lgl.raise and roll < 0.25 then
            okA = r2:Act(s, 'raise', math.random(lgl.raise.min, lgl.raise.max))
        elseif roll < 0.4 then okA = r2:Act(s, 'fold')
        elseif lgl.check then okA = r2:Act(s, 'check')
        else okA = r2:Act(s, 'call') end
        if not okA then error('legal action refused in game ' .. g) end
    end
    -- every live player who isn't all-in has matched the top bet
    for _, s in ipairs(r2:Live()) do
        if not r2.allin[s] and r2.bet[s] < r2.currentBet and #r2:Live() > 1 then
            local dump = {}
            for x = 1, seats do dump[#dump + 1] = ('s%d bet=%d stack=%d f=%s a=%s acted=%s'):format(x, r2.bet[x], r2.stack[x],
                tostring(r2.folded[x]), tostring(r2.allin[x]), tostring(r2.acted[x])) end
            error(('unmatched bet in game %d (cur %d): %s'):format(g, r2.currentBet, table.concat(dump, ' | ')))
        end
    end
    r2:Uncalled()
    for s = 1, seats do
        if r2.stack[s] < 0 then error('negative stack in game ' .. g) end
        if r2.stack[s] + r2.total[s] ~= start[s] then error('chips lost in game ' .. g) end
    end
end
T.ok(true, '3000 random betting rounds end correctly and balance')
