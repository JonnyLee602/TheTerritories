-- Pure maths tests for server/money.lua. Run with tests/run_tests.py (needs Python 3.12 + lupa).
local M = GG.M
local T = Test

-- cents
T.eq(M.ToCents(0.1 + 0.2), 30, 'float dollars round to cents')
T.eq(M.ToCents('1.305'), 131, 'string dollars')
T.eq(M.ToCents(-1), nil, 'negative refused')
T.eq(M.ToCents(0/0), nil, 'NaN refused')
T.eq(M.Fmt(1234), '$12.34', 'format')
T.eq(M.Fmt(5), '$0.05', 'format small')

-- skim with remainder: 1000 bets of 10c at 4.4% = 440c exactly over time
local total, rem = 0, 0
for _ = 1, 1000 do local s; s, rem = M.Skim(10, 0.044, rem); total = total + s end
T.eq(total, 440, '1000 x 10c at 4.4% rakes 440c')
-- single small bet rakes nothing but carries the fraction
local s1, r1 = M.Skim(10, 0.044, 0)
T.eq(s1, 0, 'sub-cent rake is carried'); T.near(r1, 0.44, 1e-9, 'remainder kept')
-- cap
local s2, r2 = M.Skim(10000, 0.05, 0.3, 30)
T.eq(s2, 30, 'cap bites'); T.eq(r2, 0, 'remainder resets at cap')
T.eq(M.Skim(100, 0, 0.5), 0, 'zero rate')

-- split
local box, sink = M.Split(7, 0.5)
T.eq(box, 3, 'split box'); T.eq(sink, 4, 'odd cent to sink')
T.eq(select(2, M.Split(7, 0)), 7, 'no share: all sink')

-- side pots: A all-in 50, B 100, C 100 (all live)
local pots = M.SidePots({ [1] = 50, [2] = 100, [3] = 100 }, { [1] = true, [2] = true, [3] = true })
T.eq(#pots, 2, 'two pots'); T.eq(pots[1].amount, 150, 'main pot'); T.eq(pots[2].amount, 100, 'side pot')
T.eq(#pots[1].eligible, 3, 'main pot 3 contenders'); T.eq(#pots[2].eligible, 2, 'side pot 2 contenders')
-- A (short stack) wins: gets main, best of B/C gets side
local aw = M.Award(pots, { { 1 }, { 3 }, { 2 } })
T.eq(aw[1], 150, 'short stack wins main only'); T.eq(aw[3], 100, 'next best wins side'); T.eq(aw[2], nil, 'loser nothing')
-- folded money stays in the pot
local p2 = M.SidePots({ [1] = 40, [2] = 20, [3] = 20 }, { [2] = true, [3] = true })
local sum = 0 for _, p in ipairs(p2) do sum = sum + p.amount end
T.eq(sum, 80, 'folded contributions stay in the pots')
-- tie with odd cent
local aw2 = M.Award({ { amount = 101, eligible = { 2, 5 } } }, { { 2, 5 } }, { 5, 2 })
T.eq(aw2[5], 51, 'odd cent follows oddOrder'); T.eq(aw2[2], 50, 'other half')
-- rake comes off the main pot first
local p3 = { { amount = 10, eligible = { 1 } }, { amount = 100, eligible = { 2 } } }
M.TakeRake(p3, 15); T.eq(p3[1].amount, 0, 'main pot emptied'); T.eq(p3[2].amount, 95, 'rest from side pot')

-- fuzz: conservation awards + rake == total, for random hands
math.randomseed(42)
for n = 1, 2000 do
    local seats = math.random(2, 6)
    local contrib, live, ranking = {}, {}, {}
    local total = 0
    for s = 1, seats do
        contrib[s] = math.random(0, 5) == 0 and 0 or math.random(1, 500)
        total = total + contrib[s]
        if math.random() < 0.7 then live[s] = true end
    end
    if not next(live) then live[1] = true end
    local order = {}
    for s in pairs(live) do order[#order + 1] = s end
    for i = #order, 2, -1 do local j = math.random(i); order[i], order[j] = order[j], order[i] end
    local i = 1
    while i <= #order do -- random ties
        local g = { order[i] }
        while i < #order and math.random() < 0.25 do i = i + 1; g[#g + 1] = order[i] end
        ranking[#ranking + 1] = g; i = i + 1
    end
    local rake = M.Skim(total, 0.044, 0, 30)
    local pots = assert(M.SidePots(contrib, live))
    assert(M.TakeRake(pots, rake))
    local awards = assert(M.Award(pots, ranking))
    local paid = 0
    for s, a in pairs(awards) do
        paid = paid + a
        if not live[s] then error('folded seat ' .. s .. ' was paid in hand ' .. n) end
    end
    if paid + rake ~= total then error(('hand %d: paid %d + rake %d ~= %d'):format(n, paid, rake, total)) end
end
T.ok(true, '2000 random hands conserve money')

-- tuner: PVP low, players wager 1.5 BB/hand at 45 hands/h -> 67.5 BB/h; target 3 BB/h -> 4.44%
local r = M.TuneRate({ hands = 5000, wageredC = 6750 * 10, playerSeconds = 100 * 3600, unitC = 10, target = 3,
    edge = 0, current = 0.044, min = 0.01, max = 0.07, step = 1, minSamples = 200 })
T.near(r, 0.04444, 1e-4, 'tuner hits 3 BB/h')
-- more aggressive play -> lower rate, limited by step
local r2 = M.TuneRate({ hands = 5000, wageredC = 13500 * 10, playerSeconds = 100 * 3600, unitC = 10, target = 3,
    edge = 0, current = 0.044, min = 0.01, max = 0.07, step = 0.0025, minSamples = 200 })
T.near(r2, 0.0415, 1e-6, 'step limits the change')
-- PVD: edge counts toward the target
local r3 = M.TuneRate({ hands = 5000, wageredC = 120 * 10, playerSeconds = 3600, unitC = 10, target = 2.5,
    edge = 0.005, current = 0.016, min = 0.0025, max = 0.03, step = 1, minSamples = 200 })
T.near(r3, 2.5 / 120 - 0.005, 1e-4, 'PVD rate = target - edge')
local r4 = M.TuneRate({ hands = 10, wageredC = 1, playerSeconds = 1, unitC = 10, target = 3, current = 0.02, minSamples = 200 })
T.eq(r4, 0.02, 'too few samples keeps the current rate')
