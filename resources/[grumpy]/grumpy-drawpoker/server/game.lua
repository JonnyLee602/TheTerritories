-- Five-Card Draw on a grumpy-gambling card table. Game state lives here; every chip goes through the core
-- (GGLib.Bet / Return / Settle), which takes the rake, builds side pots and seats NPCs.
--
-- Hand: blinds -> five cards each -> betting (no-limit) -> the draw (each player in turn from the button's left
-- throws up to three cards, four when keeping an ace, or stands pat) -> betting -> showdown (best five-card hand).
-- A hand that ends before the draw pays no rake ("no draw, no drop").
local L, Cards, Poker, Betting, Brain = GGLib, GGLib.Cards, GGLib.Poker, GGLib.Betting, GGLib.Brain
local C = Config.DrawPoker
local R, T, LAY = C.Rules, C.Timers, C.Layout
local GAME = C.GameId
local tables = {}   -- [tableId] = { button, tracker, hand }

local function key(tid, what) return ('dp:%d:%s'):format(tid, what) end
local function nameOf(h, seat) return h.names[seat] or ('Seat ' .. seat) end

-- seats in table order, starting with the first seat after `seat`
local function after(order, seat)
    for i, s in ipairs(order) do if s == seat then return order[i % #order + 1] end end
    return order[1]
end

-- 0 = first to act after the button, 1 = the button (acts last)
local function position(h, seat, button)
    local n, s = #h.order, button
    for i = 1, n do
        s = after(h.order, s)
        if s == seat then return i / n end
    end
    return 0.5
end

---------------------------------------------------------------------
-- Drawing: what a hand is worth before the draw, and what an NPC throws away
---------------------------------------------------------------------
local function suitCounts(cards)
    local n = {}
    for _, c in ipairs(cards) do n[c.s] = (n[c.s] or 0) + 1 end
    return n
end

-- Four cards of one suit: the index of the odd one, or nil
local function fourFlush(cards)
    for s, n in pairs(suitCounts(cards)) do
        if n == 4 then
            for i, c in ipairs(cards) do if c.s ~= s then return i end end
        end
    end
end

-- Four in a row (open-ended, not ace-high or ace-low): the index of the odd one, or nil
local function openEnded(cards)
    for skip = 1, 5 do
        local ranks, seen, ok = {}, {}, true
        for i, c in ipairs(cards) do
            if i ~= skip then
                if seen[c.r] then ok = false end
                seen[c.r] = true
                ranks[#ranks + 1] = c.r
            end
        end
        if ok then
            table.sort(ranks)
            if ranks[4] - ranks[1] == 3 and ranks[1] >= 2 and ranks[4] <= 13 then return skip end
        end
    end
end

-- Extra strength before the draw for hands that draw well (the brain only sees what's made)
local function drawBonus(cards)
    local cat = Poker.Evaluate5(cards)[1]
    if cat >= 1 then return 0 end
    if fourFlush(cards) then return 0.18 end
    if openEnded(cards) then return 0.12 end
    return 0
end

local function maskOf(list) local m = 0 for _, i in ipairs(list) do m = m + (1 << (i - 1)) end return m end

-- An NPC's draw: keep what's made, draw to flushes and straights, keep an ace, else the two highest. Returns the
-- indexes to throw away, and whether standing pat on nothing is a bluff.
local function npcDraw(cards, persona)
    local score = Poker.Evaluate5(cards)
    local cat = score[1]
    if cat >= 4 then return {}, false end
    local counts = {}
    for _, c in ipairs(cards) do counts[c.r] = (counts[c.r] or 0) + 1 end
    local throw = {}
    if cat >= 1 then
        for i, c in ipairs(cards) do if counts[c.r] == 1 then throw[#throw + 1] = i end end
        if #throw > R.MaxDraw then -- only a pair of something with three loose cards: keep the highest kicker
            table.sort(throw, function(a, b) return cards[a].r < cards[b].r end)
            table.remove(throw)
        end
        return throw, false
    end
    if persona and math.random() < (persona.bluff or 0) * 0.5 then return {}, true end -- stand pat on nothing
    local odd = fourFlush(cards) or openEnded(cards)
    if odd then return { odd }, false end
    local order = { 1, 2, 3, 4, 5 }
    table.sort(order, function(a, b) return cards[a].r > cards[b].r end)
    if cards[order[1]].r == 14 and R.MaxDrawWithAce >= 4 then return { order[2], order[3], order[4], order[5] }, false end
    return { order[3], order[4], order[5] }, false
end

-- Is this throw allowed? mask bits = card positions
local function validDraw(cards, mask)
    if not mask or mask < 0 or mask > 31 then return nil end
    local throw, kept = {}, {}
    for i = 1, #cards do
        if mask & (1 << (i - 1)) ~= 0 then throw[#throw + 1] = i else kept[#kept + 1] = cards[i] end
    end
    if #throw <= R.MaxDraw then return throw end
    if #throw <= R.MaxDrawWithAce and #kept == 1 and kept[1].r == 14 then return throw end
    return nil
end

---------------------------------------------------------------------
-- Views and the cards on the table
---------------------------------------------------------------------
local function liveCount(h) return #h.rd:Live() end

-- Which of a seat's cards are on the table yet: dealt so far (round by round around the table) and not thrown away
-- while the new ones come in
local function visible(h, seat, i)
    if h.dealt then
        local pos
        for p, s in ipairs(h.order) do if s == seat then pos = p break end end
        if not pos or (i - 1) * #h.order + pos > h.dealt then return false end
    end
    return not (h.hidden[seat] and h.hidden[seat][i])
end

local function visibleCards(h, seat)
    local out = {}
    for i, c in ipairs(h.hole[seat] or {}) do if visible(h, seat, i) then out[#out + 1] = c end end
    return out
end

local function actionsFor(h, seat)
    if h.waiting or h.dealt then return {} end
    if h.phase == 'draw' then
        if h.drawTurn ~= seat then return {} end
        return { { id = 'draw', pick = { max = R.MaxDraw, aceMax = R.MaxDrawWithAce } } }
    end
    if h.phase ~= 'bet1' and h.phase ~= 'bet2' then return {} end
    local lg = h.rd:Legal(seat)
    if not lg then return {} end
    local list = { { id = 'fold' } }
    if lg.check then list[#list + 1] = { id = 'check' } end
    if lg.call then list[#list + 1] = { id = 'call', amount = lg.call } end
    if lg.raise then
        list[#list + 1] = { id = h.rd.currentBet == 0 and 'bet' or 'raise', min = lg.raise.min, max = lg.raise.max,
            step = h.stakes.smallBlind }
    end
    return list
end

local RANK = Cards.RankChars

local function props(tid, h)
    local list = {}
    if h then
        for _, seat in ipairs(h.order) do
            if not h.rd.folded[seat] then
                local show = h.shown[seat] == true
                for i, c in ipairs(h.hole[seat]) do
                    if visible(h, seat, i) then
                        list[#list + 1] = { key = ('s%d_%d'):format(seat, i), at = 'seat', seat = seat,
                            card = { r = RANK[c.r], s = c.s, down = not show }, x = LAY.x, y = LAY.y + (i - 1) * LAY.step,
                            z = (i - 1) * LAY.rise }
                    end
                end
            end
        end
    end
    L.Props(tid, list)
end

local function push(tid, results)
    local st = tables[tid]
    local h = st and st.hand
    if not h then
        L.View(tid, { game = GAME, phase = 'waiting' })
        L.Props(tid, {})
        return
    end
    local info = L.Hand(h.id)
    local seats, private = {}, {}
    for _, seat in ipairs(h.order) do
        local live = not h.rd.folded[seat]
        local showdown = h.shown[seat] == true
        local label
        if showdown and live and h.handNames[seat] then label = locale(h.handNames[seat])
        elseif h.drew[seat] then label = h.drew[seat] == 0 and locale('label_pat') or locale('label_drew', h.drew[seat]) end
        seats[#seats + 1] = {
            seat = seat, name = nameOf(h, seat), stack = h.rd.stack[seat], bet = h.rd.bet[seat],
            folded = h.rd.folded[seat] == true, allin = h.rd.allin[seat] == true,
            cards = live and Cards.PublicList(visibleCards(h, seat), showdown) or nil, label = label, dealer = seat == st.button,
        }
        private[seat] = { cards = Cards.PublicList(visibleCards(h, seat), true), actions = actionsFor(h, seat) }
    end
    local turn = (h.phase == 'draw' and h.drawTurn) or ((h.phase == 'bet1' or h.phase == 'bet2') and not h.dealt and h.rd.turn) or nil
    L.View(tid, {
        game = GAME, phase = h.phase, pot = info and info.pot or 0, turn = turn, deadline = h.deadline,
        seats = seats, results = results,
    }, private)
    props(tid, h)
end

---------------------------------------------------------------------
-- Hand flow
---------------------------------------------------------------------
local startHand, finish, toDraw, nextDraw, toBet2, armBet, armNow, apply

local function abort(tid, why)
    local st = tables[tid]
    local h = st and st.hand
    if h then
        L.Cancel(h.id, why)
        L.Say(tid, nil, locale('hand_failed', tostring(why)))
        st.hand = nil
    end
    L.CancelTimers(('dp:%d:'):format(tid))
    push(tid)
    L.After(key(tid, 'next'), T.Next, function() startHand(tid) end)
end

local function bet(tid, h, seat, put)
    if put <= 0 then return true end
    local ok, err = L.Bet(h.id, seat, put)
    if not ok then abort(tid, err) end
    return ok
end

-- The part of a street's top bet nobody matched goes back before the next street (no rake on it)
local function returnUncalled(tid, h)
    local us, ua = h.rd:Uncalled()
    if us then
        local ok, err = L.Return(h.id, us, ua)
        if not ok then abort(tid, err) return false end
    end
    return true
end

local function draw(h)
    local c = h.shoe:Draw()
    if not c then
        -- the deck ran out during the draw: shuffle the discards back in, as dealers do
        local cards = h.muck
        h.muck = {}
        GGLib.Shuffle(cards)
        h.shoe = setmetatable({ cards = cards, pos = 1, size = #cards }, getmetatable(h.shoe))
        c = h.shoe:Draw()
    end
    return c
end

startHand = function(tid)
    local st = tables[tid]
    if not st or st.hand then return end
    local players, names, stacks, npc, cids = {}, {}, {}, {}, {}
    for _, p in ipairs(L.Seats(tid)) do
        if p.available > 0 then
            players[#players + 1] = p.seat
            names[p.seat], stacks[p.seat], npc[p.seat], cids[p.seat] = p.name, p.available, p.npc, p.cid
        end
    end
    table.sort(players)
    if #players < 2 then return push(tid) end
    local handId, err = L.BeginHand(tid)
    if not handId then
        if err ~= 'no_players' then print(('[%s] BeginHand: %s'):format(GAME, tostring(err))) end
        return push(tid)
    end
    local stakes = L.Stakes(tid)
    st.button = after(players, st.button or players[#players])
    local sb, bb, first
    if #players == 2 then
        sb = st.button; bb = after(players, sb); first = sb
    else
        sb = after(players, st.button); bb = after(players, sb); first = after(players, bb)
    end
    local h = {
        id = handId, phase = 'bet1', order = players, names = names, stakes = stakes, npc = npc, cids = cids,
        rd = Betting.New({ order = players, stacks = stacks, bigBlind = stakes.bigBlind }),
        shoe = Cards.NewShoe(1), muck = {}, hole = {}, drew = {}, handNames = {}, raised = {}, cheated = {},
        hidden = {}, shown = {}, dealt = 0,
    }
    st.hand = h
    for _, pair in ipairs({ { sb, stakes.smallBlind }, { bb, stakes.bigBlind } }) do
        local put = h.rd:Post(pair[1], pair[2])
        if not bet(tid, h, pair[1], put) then return end
        L.Say(tid, nil, locale('posts_blind', nameOf(h, pair[1]), L.Fmt(put)))
        L.Cue(tid, pair[1], 'blind')
    end
    for _ = 1, 5 do for _, seat in ipairs(players) do
        h.hole[seat] = h.hole[seat] or {}
        h.hole[seat][#h.hole[seat] + 1] = h.shoe:Draw()
    end end
    -- back-room cardsharps sometimes slip themselves a better card (a player can call them out)
    for _, seat in ipairs(players) do
        if npc[seat] then
            local prof = L.NpcProfile(tid, seat)
            if prof and prof.sharp and math.random() < prof.sharp and Brain.SharpSwap(h.shoe, h.hole[seat], {}) then
                h.cheated[seat] = true
                L.NpcEvent(tid, seat, 'sleight')
            end
        end
    end
    h.rd:Begin(first)
    -- deal the cards round the table one at a time, then play starts
    local total = 5 * #players
    local function dealStep()
        local cur = tables[tid] and tables[tid].hand
        if cur ~= h then return end
        h.dealt = h.dealt + 1
        if h.dealt >= total then
            h.dealt = nil
            if h.rd:Done() then return toDraw(tid) end
            return armBet(tid, h)
        end
        push(tid)
        L.After(key(tid, 'deal'), T.Deal, dealStep)
    end
    push(tid)
    L.After(key(tid, 'deal'), T.Deal, dealStep)
end

-- NPC betting turn: the core's brain (tells show while it thinks), with a bonus for hands that draw well
local function npcBet(tid, h, seat)
    local st = tables[tid]
    local lg = h.rd:Legal(seat)
    if not lg then return end
    local info = L.Hand(h.id)
    L.NpcTurn(key(tid, 'bot'), tid, seat, {
        hole = h.hole[seat], board = {}, legal = lg, pot = info and info.pot or 0,
        currentBet = h.rd.currentBet, myBet = h.rd.bet[seat], stack = h.rd.stack[seat],
        bigBlind = h.stakes.bigBlind, step = h.stakes.smallBlind, opponents = liveCount(h) - 1,
        position = position(h, seat, st.button), bonus = h.phase == 'bet1' and drawBonus(h.hole[seat]) or nil,
        opp = h.aggressor and h.aggressor ~= seat and st.tracker:Profile(h.cids[h.aggressor]) or nil,
    }, function(action, amount)
        if not tables[tid] or tables[tid].hand ~= h or h.rd.turn ~= seat then return end
        if action == 'raise' then action = h.rd.currentBet == 0 and 'bet' or 'raise' end
        if not apply(tid, h, seat, action, amount) then
            local now = h.rd:Legal(seat)
            apply(tid, h, seat, now and now.check and 'check' or 'fold')
        end
    end)
end

-- A beat before each betting turn: the turn moves (marker, heads turn), then the player can act
armBet = function(tid, h)
    if not h.rd.turn then return end
    local seat = h.rd.turn
    h.waiting, h.deadline = true, nil
    push(tid)
    L.After(key(tid, 'beat'), L.Beat(T.TurnBeat[1], T.TurnBeat[2]), function()
        local st = tables[tid]
        if not st or st.hand ~= h or h.rd.turn ~= seat then return end
        h.waiting = false
        armNow(tid, h)
        push(tid)
    end)
end

armNow = function(tid, h)
    if not h.rd.turn then return end
    h.deadline = os.time() + T.Act // 1000
    local seat = h.rd.turn
    if h.npc[seat] then
        L.After(key(tid, 'botwait'), 600, function()
            local st = tables[tid]
            if st and st.hand == h and h.rd.turn == seat then npcBet(tid, h, seat) end
        end)
    end
    L.After(key(tid, 'turn'), T.Act, function()
        local st = tables[tid]
        if not st or st.hand ~= h or h.rd.turn ~= seat then return end
        local lg = h.rd:Legal(seat)
        local move = lg and lg.check and 'check' or 'fold'
        L.Say(tid, nil, locale('timed_out', nameOf(h, seat)))
        apply(tid, h, seat, move)
    end)
end

-- After a betting move: the street goes on, or it's over
local function streetOver(tid, h)
    L.CancelTimer(key(tid, 'turn'))
    if liveCount(h) <= 1 then return finish(tid) end
    if h.phase == 'bet1' then return toDraw(tid) end  -- toDraw and finish give back any uncalled bet
    finish(tid)
end

toDraw = function(tid)
    local st = tables[tid]
    local h = st.hand
    if liveCount(h) <= 1 then return finish(tid) end
    if h.phase == 'bet1' and not returnUncalled(tid, h) then return end
    h.phase = 'draw'
    h.drawQueue = {}
    local s = st.button
    for _ = 1, #h.order do
        s = after(h.order, s)
        if not h.rd.folded[s] then h.drawQueue[#h.drawQueue + 1] = s end
    end
    L.Say(tid, nil, locale('draw_starts'))
    h.waiting = true
    push(tid)
    L.After(key(tid, 'draw'), T.DrawBeat, function()
        local cur = tables[tid] and tables[tid].hand
        if cur ~= h then return end
        h.waiting = false
        nextDraw(tid)
    end)
end

local function doDraw(tid, h, seat, throw)
    L.CancelTimer(key(tid, 'draw'))
    L.CancelTimer(key(tid, 'npcdraw'))
    local cards = h.hole[seat]
    h.hidden[seat] = {}
    for _, i in ipairs(throw) do
        h.muck[#h.muck + 1] = cards[i]
        cards[i] = draw(h)
        h.hidden[seat][i] = true                 -- the thrown card leaves the table first
    end
    h.drew[seat] = #throw
    h.waiting = true
    if #throw == 0 then L.Say(tid, nil, locale('stands_pat', nameOf(h, seat)))
    else L.Say(tid, nil, locale('draws', nameOf(h, seat), #throw)) end
    L.Cue(tid, seat, #throw == 0 and 'check' or 'call')
    push(tid)
    local seq = L.Seq(key(tid, 'draw')):Wait(#throw > 0 and 450 or 0)
    for _, i in ipairs(throw) do
        seq:Do(function()
            if not tables[tid] or tables[tid].hand ~= h then return false end
            h.hidden[seat][i] = nil
            push(tid)
        end):Wait(T.Replace)
    end
    seq:Wait(L.Beat(400, 700)):Do(function()
        if not tables[tid] or tables[tid].hand ~= h or h.drawTurn ~= seat or h.phase ~= 'draw' then return false end
        h.waiting = false
        nextDraw(tid)
    end):Run()
end

nextDraw = function(tid)
    local st = tables[tid]
    local h = st.hand
    L.CancelTimer(key(tid, 'draw'))
    local seat = table.remove(h.drawQueue, 1)
    while seat and h.rd.folded[seat] do seat = table.remove(h.drawQueue, 1) end
    if not seat then return toBet2(tid) end
    h.drawTurn = seat
    h.deadline = os.time() + T.Draw // 1000
    if h.npc[seat] then
        L.After(key(tid, 'npcdraw'), math.random(T.NpcDraw[1], T.NpcDraw[2]), function()
            local cur = tables[tid] and tables[tid].hand
            if cur ~= h or h.phase ~= 'draw' or h.drawTurn ~= seat then return end
            local throw, bluff = npcDraw(h.hole[seat], L.NpcProfile(tid, seat))
            if bluff then L.NpcEvent(tid, seat, 'bluff') end
            doDraw(tid, h, seat, throw)
        end)
    end
    L.After(key(tid, 'draw'), T.Draw, function()
        local cur = tables[tid] and tables[tid].hand
        if cur ~= h or h.phase ~= 'draw' or h.drawTurn ~= seat then return end
        L.Say(tid, nil, locale('timed_out_draw', nameOf(h, seat)))
        doDraw(tid, h, seat, {})
    end)
    push(tid)
end

toBet2 = function(tid)
    local st = tables[tid]
    local h = st.hand
    h.phase, h.drawTurn = 'bet2', nil
    h.aggressor = nil
    h.rd:NewStreet(after(h.order, st.button))
    if h.rd:Done() then return finish(tid) end
    armBet(tid, h)
end

finish = function(tid)
    local st = tables[tid]
    local h = st and st.hand
    if not h or h.finishing then return end
    h.finishing = true
    L.CancelTimers(('dp:%d:'):format(tid))
    h.deadline, h.waiting, h.drawTurn = nil, true, nil
    if not returnUncalled(tid, h) then return end
    local live = h.rd:Live()
    local ranking
    if #live == 1 then
        if R.NoDrawNoDrop and h.phase == 'bet1' then L.SetRakeable(h.id, false) end -- no draw, no drop
        ranking = { { live[1] } }
    else
        local entries = {}
        for _, seat in ipairs(live) do
            local score, name = Poker.Best(h.hole[seat])
            h.handNames[seat] = name
            entries[#entries + 1] = { seat = seat, score = score }
            if h.raised[seat] then st.tracker:Shown(h.cids[seat], score[1] == 0) end -- raised with nothing = a bluff
        end
        ranking = Poker.Ranking(entries)
    end
    h.phase = 'showdown'
    push(tid)
    local function here() return tables[tid] ~= nil and tables[tid].hand == h end
    -- a real showdown: the live hands are turned up one at a time, from the button's left
    local seq = L.Seq(key(tid, 'show'))
    if #live > 1 then
        local s = st.button
        for _ = 1, #h.order do
            s = after(h.order, s)
            local seat = s
            if not h.rd.folded[seat] then
                seq:Wait(T.Reveal):Do(function()
                    if not here() then return false end
                    h.shown[seat] = true
                    L.Say(tid, nil, locale('shows', nameOf(h, seat), locale(h.handNames[seat])))
                    push(tid)
                end)
            end
        end
    end
    seq:Wait(#live > 1 and T.Settle or 500):Do(function()
        if not here() then return false end
        local oddOrder, s = {}, st.button
        for _ = 1, #h.order do s = after(h.order, s); oddOrder[#oddOrder + 1] = s end
        local ok, res = L.Settle(h.id, { ranking = ranking, oddOrder = oddOrder })  -- the pot slides to the winner
        if not ok then abort(tid, res) return false end
        local results = {}
        for seat, amount in pairs(res.awards) do
            results[#results + 1] = { seat = seat, amount = amount }
            if h.handNames[seat] then
                L.Say(tid, nil, locale('wins_hand', nameOf(h, seat), L.Fmt(amount), locale(h.handNames[seat])))
            else
                L.Say(tid, nil, locale('wins', nameOf(h, seat), L.Fmt(amount)))
            end
        end
        push(tid, results)
        st.hand = nil
        L.After(key(tid, 'next'), T.Next, function() startHand(tid) end)
    end):Run()
end

---------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------
local verbs = { fold = 'folds', check = 'checks', call = 'calls', raise = 'raises', bet = 'bets', allin = 'raises' }

apply = function(tid, h, seat, id, amount, src)
    local action = (id == 'bet') and 'raise' or id
    local before = h.rd.bet[seat]
    local ok, put = h.rd:Act(seat, action, amount)
    if not ok then
        if src then L.Say(tid, src, locale('illegal')) end
        return false
    end
    if not bet(tid, h, seat, put) then return true end
    local st = tables[tid]
    if st then st.tracker:Note(h.cids[seat], action) end
    if action == 'raise' or action == 'allin' then h.aggressor = seat; h.raised[seat] = true end
    L.Cue(tid, seat, id)
    local verb = verbs[id] or id
    if verb == 'calls' then L.Say(tid, nil, locale('calls', nameOf(h, seat), L.Fmt(put)))
    elseif verb == 'raises' or verb == 'bets' then L.Say(tid, nil, locale(verb, nameOf(h, seat), L.Fmt(before + put)))
    else L.Say(tid, nil, locale(verb, nameOf(h, seat))) end
    if h.rd:Done() then
        -- a breath before the street ends (or the hand does)
        local phase = h.phase
        h.waiting = true
        push(tid)
        L.After(key(tid, 'beat'), L.Beat(600, 900), function()
            local st2 = tables[tid]
            if not st2 or st2.hand ~= h or h.phase ~= phase or h.finishing then return end
            h.waiting = false
            streetOver(tid, h)
        end)
    else
        armBet(tid, h)
    end
    return true
end

local function onAction(tid, seat, src, id, amount)
    local st = tables[tid]
    local h = st and st.hand
    if not h or h.npc[seat] then return end
    if h.phase == 'draw' then
        if id ~= 'draw' then return L.Say(tid, src, locale('illegal')) end
        if h.drawTurn ~= seat then return L.Say(tid, src, locale('not_your_turn')) end
        local throw = validDraw(h.hole[seat], amount)
        if not throw then return L.Say(tid, src, locale('bad_draw', R.MaxDraw, R.MaxDrawWithAce)) end
        return doDraw(tid, h, seat, throw)
    end
    if h.phase ~= 'bet1' and h.phase ~= 'bet2' then return end
    if h.rd.turn ~= seat then return L.Say(tid, src, locale('not_your_turn')) end
    apply(tid, h, seat, id, amount, src)
end

---------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------
L.RegisterGame({
    id = GAME, label = locale('label'), kind = 'pvp', minSeats = 2, maxSeats = C.MaxSeats, models = C.Models,
    houseEdge = 0.0,
}, {
    tableStarted = function(tid)
        tables[tid] = { button = nil, tracker = Brain.Tracker() }
        L.After(key(tid, 'next'), T.Start, function() startHand(tid) end)
    end,
    seatTaken = function(tid)
        local st = tables[tid]
        if st and not st.hand then L.After(key(tid, 'next'), T.Start, function() startHand(tid) end) end
    end,
    stackChanged = function(tid)
        local st = tables[tid]
        if st and not st.hand then L.After(key(tid, 'next'), T.Start, function() startHand(tid) end) end
    end,
    seatLeft = function(tid, seat)
        local st = tables[tid]
        local h = st and st.hand
        if not h or h.rd.folded[seat] or not h.hole[seat] then return end
        if h.phase == 'bet1' or h.phase == 'bet2' then
            local wasTurn = h.rd.turn == seat
            h.rd:Remove(seat)
            if h.dealt then return push(tid) end -- still dealing: play starts when the deal is done
            if h.rd:Done() then return streetOver(tid, h) end
            if wasTurn then return armBet(tid, h) end
            return push(tid)
        end
        if h.phase == 'draw' then
            h.rd:Remove(seat)
            if liveCount(h) <= 1 then return finish(tid) end
            if h.drawTurn == seat and not h.waiting then return nextDraw(tid) end
            push(tid)
        end
    end,
    action = onAction,
    -- a player accuses an NPC of cheating: right if that NPC swapped a card this hand (the hand is called off)
    callOut = function(tid, seat)
        local st = tables[tid]
        local h = st and st.hand
        if h and h.cheated[seat] then
            L.Cancel(h.id, 'cheat')
            st.hand = nil
            L.CancelTimers(('dp:%d:'):format(tid))
            L.ResolveCallOut(tid, seat, true)
            push(tid)
            L.After(key(tid, 'next'), T.Next, function() startHand(tid) end)
        else
            L.ResolveCallOut(tid, seat, false)
        end
    end,
    tableStopping = function(tid)
        L.CancelTimers(('dp:%d:'):format(tid))
        tables[tid] = nil
    end,
})

-- for tests
DrawPoker = { npcDraw = npcDraw, validDraw = validDraw, drawBonus = drawBonus, maskOf = maskOf, draw = draw }
