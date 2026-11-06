-- Poker hand evaluation: the best five cards out of 5–7, comparable scores, hand names, and the seat ranking the
-- core's Settle expects ({ {best}, {tied, tied}, ... }).
local Poker = {}
GGLib.Poker = Poker

Poker.Names = { [8] = 'straight_flush', [7] = 'four_of_a_kind', [6] = 'full_house', [5] = 'flush', [4] = 'straight',
    [3] = 'three_of_a_kind', [2] = 'two_pair', [1] = 'pair', [0] = 'high_card' }

-- score = { category, tiebreak ranks... } compared left to right
local function evaluate5(c)
    local counts, ranks, flush = {}, {}, true
    for i = 1, 5 do
        counts[c[i].r] = (counts[c[i].r] or 0) + 1
        ranks[i] = c[i].r
        if c[i].s ~= c[1].s then flush = false end
    end
    table.sort(ranks, function(a, b) return a > b end)
    -- straight (A-2-3-4-5 counts, high card 5)
    local straightHigh
    local distinct = true
    for i = 2, 5 do if ranks[i] == ranks[i - 1] then distinct = false break end end
    if distinct then
        if ranks[1] - ranks[5] == 4 then straightHigh = ranks[1]
        elseif ranks[1] == 14 and ranks[2] == 5 and ranks[5] == 2 then straightHigh = 5 end
    end
    if straightHigh and flush then return { 8, straightHigh } end
    -- groups by count then rank
    local groups = {}
    for r, n in pairs(counts) do groups[#groups + 1] = { r = r, n = n } end
    table.sort(groups, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.r > b.r end)
    if groups[1].n == 4 then return { 7, groups[1].r, groups[2].r } end
    if groups[1].n == 3 and groups[2].n == 2 then return { 6, groups[1].r, groups[2].r } end
    if flush then return { 5, ranks[1], ranks[2], ranks[3], ranks[4], ranks[5] } end
    if straightHigh then return { 4, straightHigh } end
    if groups[1].n == 3 then return { 3, groups[1].r, groups[2].r, groups[3].r } end
    if groups[1].n == 2 and groups[2].n == 2 then return { 2, groups[1].r, groups[2].r, groups[3].r } end
    if groups[1].n == 2 then return { 1, groups[1].r, groups[2].r, groups[3].r, groups[4].r } end
    return { 0, ranks[1], ranks[2], ranks[3], ranks[4], ranks[5] }
end
Poker.Evaluate5 = evaluate5

-- > 0: a beats b, < 0: b beats a, 0: tie
function Poker.Compare(a, b)
    for i = 1, math.max(#a, #b) do
        local d = (a[i] or 0) - (b[i] or 0)
        if d ~= 0 then return d end
    end
    return 0
end

-- Best hand from 5..7 cards: score, name, and the five cards used
function Poker.Best(cards)
    local n = #cards
    if n < 5 then return nil end
    local best, bestFive
    local pick = {}
    for a = 1, n - 4 do for b = a + 1, n - 3 do for c = b + 1, n - 2 do for d = c + 1, n - 1 do for e = d + 1, n do
        pick[1], pick[2], pick[3], pick[4], pick[5] = cards[a], cards[b], cards[c], cards[d], cards[e]
        local s = evaluate5(pick)
        if not best or Poker.Compare(s, best) > 0 then
            best, bestFive = s, { cards[a], cards[b], cards[c], cards[d], cards[e] }
        end
    end end end end end
    return best, Poker.Names[best[1]], bestFive
end

-- entries: { { seat = n, score = score }, ... } (live seats only) -> ranking groups, best first, ties together
function Poker.Ranking(entries)
    local list = {}
    for _, e in ipairs(entries) do list[#list + 1] = e end
    table.sort(list, function(a, b)
        local d = Poker.Compare(a.score, b.score)
        if d ~= 0 then return d > 0 end
        return a.seat < b.seat
    end)
    local groups = {}
    for i, e in ipairs(list) do
        if i > 1 and Poker.Compare(e.score, list[i - 1].score) == 0 then
            local g = groups[#groups]
            g[#g + 1] = e.seat
        else
            groups[#groups + 1] = { e.seat }
        end
    end
    return groups
end
