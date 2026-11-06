-- Pure money maths (DESIGN.md §6.3, §7). No natives, no database: unit-tested in tests/.
-- All amounts are INTEGER CENTS. Dollars only exist at the rsg-core boundary (ToCents / ToDollars).
GG = GG or {}
local M = {}
GG.M = M

local floor = math.floor

local function int(n) return math.tointeger(n) or floor(n) end

-- dollars -> cents (nil for anything that isn't a finite, non-negative amount)
function M.ToCents(dollars)
    local n = tonumber(dollars)
    if not n or n ~= n or n == math.huge or n == -math.huge or n < 0 then return nil end
    return int(floor(n * 100 + 0.5))
end

function M.ToDollars(c) return c / 100 end

function M.Fmt(c)
    c = int(c or 0)
    local sign = c < 0 and '-' or ''
    c = math.abs(c)
    return ('%s$%d.%02d'):format(sign, c // 100, c % 100)
end

function M.IsCents(c) return math.type(c) == 'integer' and c >= 0 end

local function round6(n) return floor(n * 1e6 + 0.5) / 1e6 end

---------------------------------------------------------------------
-- Rake
---------------------------------------------------------------------
-- Rake on `amountC` at `rate`, carrying the fractions of a cent between calls.
-- Returns whole cents (never more than amountC or capLeftC) and the new remainder.
-- When the cap bites, the excess is forgiven and the remainder resets.
function M.Skim(amountC, rate, remainder, capLeftC)
    if not rate or rate <= 0 or amountC <= 0 then return 0, remainder or 0 end
    local exact = amountC * rate + (remainder or 0)
    local whole = int(floor(exact + 1e-9))
    if whole > amountC then whole = amountC end
    if capLeftC and whole >= capLeftC then return int(math.max(0, capLeftC)), 0 end
    return whole, round6(exact - whole)
end

-- Splits a rake between a business cashbox and the sink. share = fraction to the cashbox (0..1).
-- Odd cents go to the sink.
function M.Split(rakeC, share)
    if not share or share <= 0 then return 0, rakeC end
    if share >= 1 then return rakeC, 0 end
    local box = int(floor(rakeC * share))
    return box, rakeC - box
end

---------------------------------------------------------------------
-- Side pots and awards (PVP)
---------------------------------------------------------------------
-- contrib: { [seat] = cents } for every seat that put money in (folded or not)
-- live:    { [seat] = true } seats still contesting the hand
-- Returns pots, main pot first: { { amount = cents, eligible = { seat, ... } } }
function M.SidePots(contrib, live)
    local levels, seen = {}, {}
    for seat in pairs(live) do
        local c = contrib[seat] or 0
        if c > 0 and not seen[c] then seen[c] = true; levels[#levels + 1] = c end
    end
    table.sort(levels)
    local pots, prev = {}, 0
    for _, level in ipairs(levels) do
        local amount = 0
        for _, c in pairs(contrib) do
            amount = amount + math.max(0, math.min(c, level) - math.min(c, prev))
        end
        local eligible = {}
        for seat in pairs(live) do
            if (contrib[seat] or 0) >= level then eligible[#eligible + 1] = seat end
        end
        table.sort(eligible)
        local last = pots[#pots]
        if last and #last.eligible == #eligible then
            last.amount = last.amount + amount -- same contenders: one pot
        else
            pots[#pots + 1] = { amount = amount, eligible = eligible }
        end
        prev = level
    end
    if #pots == 0 then
        -- no live seat put money in (only folded seats did, or nobody did): one pot for every live seat
        local all = {}
        for seat in pairs(live) do all[#all + 1] = seat end
        table.sort(all)
        if #all == 0 then return nil, 'no_live_seats' end
        pots[1] = { amount = 0, eligible = all }
    end
    -- money above the highest live level (from folded seats) joins the last pot
    local over = 0
    for _, c in pairs(contrib) do over = over + math.max(0, c - prev) end
    pots[#pots].amount = pots[#pots].amount + over
    return pots
end

-- Takes the rake out of the pots, main pot first.
function M.TakeRake(pots, rakeC)
    local left = rakeC
    for _, p in ipairs(pots) do
        if left <= 0 then break end
        local take = math.min(left, p.amount)
        p.amount = p.amount - take
        left = left - take
    end
    return left == 0
end

-- ranking: groups of seats, best first ({ {3}, {1, 5}, {2} }; ties share a group)
-- oddOrder: seats in the order that receive odd cents of a split (defaults to seat order)
-- Returns { [seat] = cents }
function M.Award(pots, ranking, oddOrder)
    local awards = {}
    for _, pot in ipairs(pots) do
        if pot.amount > 0 then
            local isEligible = {}
            for _, s in ipairs(pot.eligible) do isEligible[s] = true end
            local winners
            for _, group in ipairs(ranking) do
                local w = {}
                for _, s in ipairs(group) do if isEligible[s] then w[#w + 1] = s end end
                if #w > 0 then winners = w break end
            end
            if not winners then return nil, 'no_winner' end
            local order = {}
            if oddOrder then
                local inW = {}
                for _, s in ipairs(winners) do inW[s] = true end
                for _, s in ipairs(oddOrder) do if inW[s] then order[#order + 1] = s; inW[s] = nil end end
                for s in pairs(inW) do order[#order + 1] = s end
            else
                for _, s in ipairs(winners) do order[#order + 1] = s end
                table.sort(order)
            end
            local share = pot.amount // #order
            local odd = pot.amount - share * #order
            for i, s in ipairs(order) do
                awards[s] = (awards[s] or 0) + share + (i <= odd and 1 or 0)
            end
        end
    end
    return awards
end

---------------------------------------------------------------------
-- Rake tuner (DESIGN.md §6.3)
-- rate = target units per player-hour / units wagered per player-hour - game edge
---------------------------------------------------------------------
-- p = { hands, wageredC, playerSeconds, unitC, target, edge, current, seed, min, max, step, minSamples }
function M.TuneRate(p)
    local current = p.current or p.seed or 0
    if (p.hands or 0) < (p.minSamples or 0) or (p.playerSeconds or 0) <= 0 or (p.wageredC or 0) <= 0 then
        return current, 'not_enough_data'
    end
    local unitsPerHour = (p.wageredC / p.unitC) / (p.playerSeconds / 3600)
    local want = p.target / unitsPerHour - (p.edge or 0)
    if p.min then want = math.max(p.min, want) end
    if p.max then want = math.min(p.max, want) end
    if p.step and p.step > 0 then
        want = math.max(current - p.step, math.min(current + p.step, want))
    end
    return floor(want * 1e5 + 0.5) / 1e5, 'tuned'
end

return M
