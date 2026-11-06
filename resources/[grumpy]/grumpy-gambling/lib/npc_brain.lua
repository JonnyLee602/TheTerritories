-- NPC brains (DESIGN.md §8.5). Pure Lua, no natives: game modules call it on an NPC's turn only.
-- Needs lib/init.lua, lib/cards.lua and lib/poker.lua loaded first.
--
-- The core hands each NPC a profile (exports GetNpc / GGLib.NpcProfile): its personality numbers with the tier,
-- drunk and tilt modifiers already applied (see Config.Npc.Personas). Strength is a 0–1 estimate of how good the
-- hand is; personalities turn it into fold / check / call / raise / all-in. Ideas follow NT's confidence model
-- (hand strength, draws, board threat, opponents, position, pot odds, stack pressure, noise), written fresh.
local Brain = {}
GGLib.Brain = Brain
local Poker = GGLib.Poker

local DEFAULT = { play = 0.5, call = 0.03, raise = 0.68, aggression = 0.5, bluff = 0.05, slowplay = 0.1, size = 0.7,
    open = 3.0, noise = 0.06, bet = { 1, 2 } }

local function clamp(x, lo, hi) if x < lo then return lo elseif x > hi then return hi end return x end

---------------------------------------------------------------------
-- Strength
---------------------------------------------------------------------
-- Two hole cards before any board (Chen-style points, scaled to 0–1: AA/KK 1.0, AKs .81, KQs .63, 22 .38, 72o 0)
function Brain.Preflop(a, b)
    local hi, lo = math.max(a.r, b.r), math.min(a.r, b.r)
    local function points(r)
        if r == 14 then return 10 elseif r == 13 then return 8 elseif r == 12 then return 7 elseif r == 11 then return 6 end
        return r / 2
    end
    local s = points(hi)
    if hi == lo then
        s = math.max(5, s * 2)
    else
        local gap = hi - lo - 1
        if gap == 1 then s = s - 1 elseif gap == 2 then s = s - 2 elseif gap == 3 then s = s - 4 elseif gap >= 4 then s = s - 5 end
        if gap <= 1 and hi < 12 then s = s + 1 end
    end
    if a.s == b.s then s = s + 2 end
    return clamp((s + 1) / 16, 0, 1)
end

-- Category the board makes on its own (pairs/trips/quads; a full five-card board is evaluated properly)
local function boardCategory(board)
    if #board >= 5 then return Poker.Best(board)[1] end
    local counts, pairs3, trips, quads = {}, 0, 0, 0
    for _, c in ipairs(board) do counts[c.r] = (counts[c.r] or 0) + 1 end
    for _, n in pairs(counts) do
        if n == 2 then pairs3 = pairs3 + 1 elseif n == 3 then trips = trips + 1 elseif n == 4 then quads = quads + 1 end
    end
    if quads > 0 then return 7 elseif trips > 0 and pairs3 > 0 then return 6 elseif trips > 0 then return 3
    elseif pairs3 >= 2 then return 2 elseif pairs3 == 1 then return 1 end
    return 0
end

-- Outs for flush and straight draws that use at least one hole card
local function draws(hole, board)
    local all = {}
    for _, c in ipairs(hole) do all[#all + 1] = c end
    for _, c in ipairs(board) do all[#all + 1] = c end
    local outs, flushDraw = 0, false
    local suits, holeSuit = {}, {}
    for _, c in ipairs(all) do suits[c.s] = (suits[c.s] or 0) + 1 end
    for _, c in ipairs(hole) do holeSuit[c.s] = true end
    for s, n in pairs(suits) do if n == 4 and holeSuit[s] then outs, flushDraw = outs + 9, true end end
    local present = {}
    for _, c in ipairs(all) do present[c.r] = true; if c.r == 14 then present[1] = true end end
    local straightOuts = 0
    for x = 2, 14 do
        if not present[x] then
            for lo = math.max(1, x - 4), math.min(10, x) do
                local ok = true
                for r = lo, lo + 4 do if r ~= x and not present[r] then ok = false break end end
                if ok then straightOuts = straightOuts + 1 break end
            end
        end
    end
    if straightOuts >= 2 then outs = outs + 8 elseif straightOuts == 1 then outs = outs + 4 end
    if flushDraw and straightOuts > 0 then outs = outs - 2 end -- shared outs
    return math.min(outs, 15)
end

-- Is the board itself scary (three to a flush, or four to a straight)?
local function boardThreat(board)
    local suits, ranks = {}, {}
    for _, c in ipairs(board) do suits[c.s] = (suits[c.s] or 0) + 1; ranks[c.r] = true; if c.r == 14 then ranks[1] = true end end
    for _, n in pairs(suits) do if n >= 3 then return true end end
    for lo = 1, 10 do
        local n = 0
        for r = lo, lo + 4 do if ranks[r] then n = n + 1 end end
        if n >= 4 then return true end
    end
    return false
end

local BASE = { [0] = 0.12, 0.42, 0.66, 0.76, 0.84, 0.88, 0.94, 0.98, 1.0 }

-- hole = cards only this player sees, board = shared cards (may be empty; draw games pass 5 hole cards).
-- Returns strength 0–1 and { category, outs, made, threat }.
function Brain.Strength(hole, board, opponents)
    board = board or {}
    opponents = math.max(1, opponents or 1)
    if #board == 0 and #hole == 2 then
        local s = Brain.Preflop(hole[1], hole[2])
        return s, { category = hole[1].r == hole[2].r and 1 or 0, outs = 0 }
    end
    local all = {}
    for _, c in ipairs(hole) do all[#all + 1] = c end
    for _, c in ipairs(board) do all[#all + 1] = c end
    if #all < 5 then return 0.3, { category = 0, outs = 0 } end
    local score = Poker.Best(all)
    local cat = score[1]
    local s = BASE[cat]
    local info = { category = cat, outs = 0 }
    if #board >= 3 then
        local bc = boardCategory(board)
        local topBoard, second = 0, 0
        for _, c in ipairs(board) do
            if c.r > topBoard then second, topBoard = topBoard, c.r elseif c.r > second and c.r < topBoard then second = c.r end
        end
        local hiHole = 0
        for _, c in ipairs(hole) do hiHole = math.max(hiHole, c.r) end
        if cat <= bc then
            s = 0.10 + hiHole / 14 * 0.10                 -- only playing the board
        elseif cat == bc + 1 and bc >= 1 and cat <= 3 then
            s = 0.48                                      -- the board's pair plus one of ours
        elseif cat == 1 then
            local pr = score[2]
            if pr > topBoard then s = 0.62                -- overpair
            elseif pr == topBoard then s = 0.55 + (score[3] or 0) / 14 * 0.05
            elseif pr >= second then s = 0.42
            else s = 0.33 end
        end
        info.threat = boardThreat(board)
        if cat < 4 and info.threat then s = s - 0.06 end
        if #board < 5 and #hole == 2 then
            info.outs = draws(hole, board)
            local eq = info.outs * (#board == 3 and 0.04 or 0.02)
            s = s + (1 - s) * eq
        end
    else
        -- draw poker (no board): the made hand is all there is
        if cat == 0 then s = 0.08 + score[2] / 14 * 0.1 end
    end
    s = clamp(s, 0, 1)
    -- more opponents: the same hand is worth less
    return s ^ (1 + 0.3 * (opponents - 1)), info
end

---------------------------------------------------------------------
-- Opponent tracking (per table, kept by the module): what each player tends to do
---------------------------------------------------------------------
local Tracker = {}
Tracker.__index = Tracker

function Brain.Tracker() return setmetatable({ p = {} }, Tracker) end

local function rec(tr, key)
    local r = tr.p[key]
    if not r then r = { raise = 0, call = 0, check = 0, fold = 0, shown = 0, bluffs = 0 }; tr.p[key] = r end
    return r
end

-- action: 'fold' | 'check' | 'call' | 'raise' | 'allin'
function Tracker:Note(key, action)
    if key == nil then return end
    local r = rec(self, key)
    if action == 'allin' or action == 'bet' then action = 'raise' end
    if r[action] then r[action] = r[action] + 1 end
end

-- At showdown: did a player who bet or raised turn up a weak hand?
function Tracker:Shown(key, wasBluff)
    if key == nil then return end
    local r = rec(self, key)
    r.shown = r.shown + 1
    if wasBluff then r.bluffs = r.bluffs + 1 end
end

-- { agg = 0–1 (share of actions that are raises), bluffs = 0–1, seen = actions } or nil before enough data
function Tracker:Profile(key)
    local r = key ~= nil and self.p[key]
    if not r then return nil end
    local acts = r.raise + r.call + r.check + r.fold
    if acts < 6 then return nil end
    return { agg = r.raise / acts, bluffs = r.shown > 0 and r.bluffs / r.shown or nil, seen = acts }
end

function Tracker:Forget(key) self.p[key] = nil end

---------------------------------------------------------------------
-- Poker decision
-- ctx = { hole, board, legal (Round:Legal), pot (cents, all bets so far), currentBet, myBet, stack (chips behind),
--         bigBlind, step, opponents (live others), position (0 early – 1 last), persona (NPC profile),
--         opp (Tracker:Profile of the player who bet, optional) }
-- Returns action ('fold'|'check'|'call'|'raise'|'allin'), amount (raise-to), meta { strength, strong, bluff }.
---------------------------------------------------------------------
local function roundTo(x, step) step = math.max(1, step or 1); return math.floor(x / step + 0.5) * step end

function Brain.Decide(ctx)
    local p = ctx.persona or DEFAULT
    local lg = ctx.legal or {}
    local board = ctx.board or {}
    local opponents = math.max(1, ctx.opponents or 1)
    local s = Brain.Strength(ctx.hole, board, opponents)
    -- a game may add to it (e.g. a four-flush before the draw in five-card draw)
    if ctx.bonus then s = math.max(0, math.min(1, s + ctx.bonus)) end
    local meta = { strength = s, strong = s >= (p.strongAt or 0.82), bluff = false }
    local preflop = #board == 0 and #ctx.hole == 2
    local e = s + (math.random() * 2 - 1) * (p.noise or 0.06) + ((ctx.position or 0.5) - 0.5) * 0.06
    local toCall = lg.call or 0
    local pot = math.max(0, ctx.pot or 0)
    local bb = math.max(1, ctx.bigBlind or 1)
    local cur = ctx.currentBet or 0

    -- reads: call wider against players who raise a lot, give credit to players who rarely bluff
    if ctx.opp and toCall > 0 then
        e = e + (ctx.opp.agg - 0.35) * 0.2
        if ctx.opp.bluffs and ctx.opp.bluffs < 0.15 then e = e - 0.04 end
    end

    local function raiseTo(fraction)
        local r = lg.raise
        if not r then return nil end
        local target
        if preflop then
            target = cur + bb * (p.open or 3) * (0.8 + math.random() * 0.5)
        else
            target = cur + (pot + toCall) * fraction * (0.8 + math.random() * 0.4)
        end
        target = roundTo(target, ctx.step)
        return clamp(math.tointeger(target) or r.min, r.min, r.max)
    end
    local function raise(fraction)
        local to = raiseTo(fraction)
        if not to then return nil end
        if to >= lg.raise.max then return 'allin', lg.raise.max, meta end
        return 'raise', to, meta
    end

    if toCall <= 0 then
        -- nobody has bet: check or bet
        if lg.raise and e >= p.raise and math.random() < p.aggression + 0.2 then
            if s >= 0.9 and math.random() < (p.slowplay or 0) then return 'check', nil, meta end
            return raise(p.size)
        end
        if lg.raise and not preflop and math.random() < (p.bluff or 0) * (1 - 0.2 * (opponents - 1)) then
            meta.bluff = true
            return raise(p.size * 0.8)
        end
        return 'check', nil, meta
    end

    -- facing a bet
    local stack = math.max(1, ctx.stack or 1)
    local pressure = math.min(1, toCall / stack)
    local potOdds = toCall / (pot + toCall)
    local need
    if preflop then
        need = math.max(p.play, potOdds + p.call) + pressure * 0.25
        if toCall <= bb then need = need - 0.04 end    -- limping / completing is cheap
    else
        need = potOdds + p.call + pressure * 0.25
    end
    if lg.raise and e >= p.raise and math.random() < p.aggression then
        if s >= 0.95 and math.random() < 0.3 then return 'allin', lg.raise.max, meta end
        local a, to = raise(p.size)
        if a then return a, to, meta end
    end
    if e >= need then return 'call', nil, meta end
    if lg.raise and pressure < 0.3 and math.random() < (p.bluff or 0) * 0.4 then
        meta.bluff = true
        local a, to = raise(p.size)
        if a then return a, to, meta end
    end
    return 'fold', nil, meta
end

---------------------------------------------------------------------
-- Dealer games: how much an NPC bets (cents), from its persona's bet range in minimum bets
---------------------------------------------------------------------
function Brain.PvdBet(persona, minBet, maxBet, available, step)
    local range = (persona and persona.bet) or DEFAULT.bet
    local mult = math.random(range[1], math.max(range[1], range[2]))
    local amount = roundTo(minBet * mult, step or minBet)
    amount = math.min(amount, maxBet, available)
    if amount < minBet then return nil end
    return amount
end

-- How long an NPC "thinks" (ms): close decisions take longer, drunks are slower
function Brain.ThinkMs(persona, strength)
    local lo, hi = 1200, 3500
    if persona and persona.think then lo, hi = persona.think[1], persona.think[2] end
    local close = 1 - math.abs((strength or 0.5) - 0.5) * 2   -- 1 when strength ~0.5
    return math.floor(lo + (hi - lo) * (0.3 * math.random() + 0.7 * close))
end

---------------------------------------------------------------------
-- Cardsharps (back-room tables): swap one of the NPC's cards for a better one still in the shoe. The swapped-out
-- card goes back into the shoe where the new one was, so the deck stays whole. Returns true if it cheated.
---------------------------------------------------------------------
function Brain.SharpSwap(shoe, hole, board, tries)
    board = board or {}
    local function value(cards)
        if #board == 0 and #cards == 2 then return Brain.Preflop(cards[1], cards[2]) end
        local all = {}
        for _, c in ipairs(cards) do all[#all + 1] = c end
        for _, c in ipairs(board) do all[#all + 1] = c end
        if #all < 5 then return 0 end
        local sc = Poker.Best(all)
        return sc[1] + (sc[2] or 0) / 15
    end
    local best, bestK, bestJ = value(hole), nil, nil
    local left = shoe.size - shoe.pos + 1
    for _ = 1, math.min(tries or 12, left) do
        local j = shoe.pos + math.random(0, left - 1)
        for k = 1, #hole do
            local keep = hole[k]
            hole[k] = shoe.cards[j]
            local v = value(hole)
            hole[k] = keep
            if v > best then best, bestK, bestJ = v, k, j end
        end
    end
    if not bestK then return false end
    hole[bestK], shoe.cards[bestJ] = shoe.cards[bestJ], hole[bestK]
    return true
end
