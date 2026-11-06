-- Blackjack round flow on a grumpy-gambling dealer table. Game state lives here; every chip goes through the core
-- (GGLib.Bet / Settle), which takes the rake, covers bets from the house or the business cashbox, and seats NPCs.
--
-- Round: betting window -> deal (two cards each, the dealer's second face down) -> insurance (dealer shows an ace)
-- -> peek (ace or ten showing: dealer blackjack ends the round) -> each seat plays its hands in turn -> the dealer
-- draws to 17 -> payouts -> cards collected -> next round.
local L, Cards, Brain = GGLib, GGLib.Cards, GGLib.Brain
local C = Config.Blackjack
local R, T, A, LAY = C.Rules, C.Timers, C.Anim, C.Layout
local GAME = C.GameId
local tables = {}   -- [tableId] = { shoe, round }

local function key(tid, what) return ('bj:%d:%s'):format(tid, what) end
local function sortedSeats(set)
    local list = {}
    for seat in pairs(set) do list[#list + 1] = seat end
    table.sort(list)
    return list
end

---------------------------------------------------------------------
-- Animations
---------------------------------------------------------------------
local function pick(list) return list[math.random(#list)] end

local function seatAnim(tid, seat, name)
    local P = A.Player
    local def = P[name]
    if def then L.SeatAnim(tid, seat, { dict = P.dict, fem = P.fem, clip = pick(def.clips), ms = def.ms }) end
end

-- Table-wide dealer moves take the seats they reach as a suffix in Rockstar's numbering (deal_124, win_13 …)
local function combo(seats)
    local nums = {}
    for _, s in ipairs(seats) do local n = A.Seats[s]; if n then nums[#nums + 1] = n end end
    table.sort(nums)
    local out, seen = {}, {}
    for _, n in ipairs(nums) do if not seen[n] then seen[n] = true; out[#out + 1] = tostring(n) end end
    return table.concat(out)
end

local function dealerAnim(tid, name, seats, clip)
    local def = A.Dealer[name]
    if not def then return end
    if def.prefix then
        local suffix = combo(seats or {})
        if suffix == '' then return end
        clip = def.prefix .. suffix
    end
    L.DealerAnim(tid, { dict = def.dict, clip = clip or def.clip, ms = def.ms })
end

---------------------------------------------------------------------
-- Labels, views and the cards on the table
---------------------------------------------------------------------
local function label(cards, natural)
    local l = BJ.Label(cards, natural)
    if not l then return nil end
    if l == 'bust' then return locale('label_bust') end
    if l == 'blackjack' then return locale('label_blackjack') end
    local soft = l:match('^soft:(%d+)$')
    if soft then return locale('label_soft', soft) end
    return l
end

-- One card on its own (the dealer's upcard): "A", "10", "7"
local function upLabel(c) return c.r == 14 and 'A' or tostring(BJ.Value(c)) end

local function shownCards(r, cards)
    local out = {}
    for _, c in ipairs(cards) do if c.seq <= r.shown then out[#out + 1] = c end end
    return out
end

local function free(P) return P.avail - P.staked end

local function actionsFor(r, seat, P)
    local acts = {}
    if P.gone then return acts end
    if r.phase == 'betting' and not P.amount then
        local max = math.min(r.stakes.maxBet, P.avail)
        if max >= r.stakes.minBet then acts[1] = { id = 'bet', min = r.stakes.minBet, max = max, step = r.stakes.minBet } end
    elseif r.phase == 'insurance' and P.amount and not P.insDecided then
        local ins = P.amount // 2
        if ins > 0 and free(P) >= ins then acts[#acts + 1] = { id = 'insurance', amount = ins } end
        acts[#acts + 1] = { id = 'no_insurance' }
    elseif r.phase == 'playing' and r.turn == seat and not r.busy and not r.waiting then
        local h = P.hands[P.active]
        if h and not h.done then
            acts[#acts + 1] = { id = 'hit' }
            acts[#acts + 1] = { id = 'stand' }
            if BJ.CanDouble(h, R) and free(P) >= h.amount then acts[#acts + 1] = { id = 'double', amount = h.amount } end
            if BJ.CanSplit(h, #P.hands, R) and free(P) >= h.amount then acts[#acts + 1] = { id = 'split', amount = h.amount } end
        end
    end
    return acts
end

local RANK = Cards.RankChars

local function props(tid, r)
    local list = {}
    if r then
        for _, seat in ipairs(r.order) do
            local P = r.seats[seat]
            local n = #P.hands
            for hi, h in ipairs(P.hands) do
                for ci, c in ipairs(shownCards(r, h.cards)) do
                    list[#list + 1] = { key = ('s%d_%d_%d'):format(seat, hi, ci), at = 'seat', seat = seat,
                        card = { r = RANK[c.r], s = c.s }, x = LAY.Seat.x,
                        y = LAY.Seat.y + (hi - (n + 1) / 2) * LAY.Seat.handGap + (ci - 1) * LAY.Seat.step,
                        z = (ci - 1) * LAY.Seat.rise }
                end
            end
        end
        for ci, c in ipairs(shownCards(r, r.dealer)) do
            list[#list + 1] = { key = 'd' .. ci, at = 'dealer', card = { r = RANK[c.r], s = c.s, down = ci == 2 and not r.holeShown },
                x = LAY.Dealer.x, y = LAY.Dealer.y + (ci - 1) * LAY.Dealer.step, z = (ci - 1) * LAY.Dealer.rise }
        end
    end
    L.Props(tid, list)
end

local function push(tid, results)
    local st = tables[tid]
    local r = st and st.round
    if not r then
        L.View(tid, { game = GAME, phase = 'waiting' })
        L.Props(tid, {})
        return
    end
    local seats, private = {}, {}
    for _, seat in ipairs(r.order) do
        local P = r.seats[seat]
        local hands = {}
        for hi, h in ipairs(P.hands) do
            local cards = shownCards(r, h.cards)
            hands[#hands + 1] = { cards = Cards.PublicList(cards, true), label = label(cards, BJ.IsBlackjack(h) and #cards == 2),
                active = r.phase == 'playing' and r.turn == seat and P.active == hi }
        end
        seats[#seats + 1] = { seat = seat, name = P.name, bet = P.staked > 0 and P.staked or nil,
            hands = #hands > 0 and hands or nil, label = P.insurance and locale('label_insured') or nil }
        private[seat] = { actions = actionsFor(r, seat, P) }
    end
    local dealer = {}
    for ci, c in ipairs(shownCards(r, r.dealer)) do dealer[ci] = Cards.Public(c, ci ~= 2 or r.holeShown) end
    local dealerLabel
    if r.holeShown then dealerLabel = label(shownCards(r, r.dealer), #r.dealer == 2 and BJ.Score(r.dealer) == 21)
    elseif #dealer > 0 then dealerLabel = upLabel(r.dealer[1]) end
    L.View(tid, {
        game = GAME, phase = r.phase, deadline = r.deadline, turn = r.phase == 'playing' and r.turn or nil,
        dealer = dealer, dealerLabel = dealerLabel, seats = seats, results = results,
    }, private)
    props(tid, r)
end

---------------------------------------------------------------------
-- Dealing
---------------------------------------------------------------------
-- to = the seat the card goes to, or 'dealer'
local function draw(st, r, to)
    local c = st.shoe:Draw()
    if not c then -- never runs dry mid-round with the penetration rule, but just in case
        st.shoe = Cards.NewShoe(R.Decks)
        c = st.shoe:Draw()
    end
    r.seq = r.seq + 1
    local card = { r = c.r, s = c.s, seq = r.seq, to = to }
    r.bySeq[r.seq] = card
    return card
end

-- Deals the cards drawn so far, one at a time: the dealer reaches for the seat (or his own spot), and the card lands
-- partway into the clip. Then calls done.
local function reveal(tid, r, done)
    r.busy = true
    local function step()
        local st = tables[tid]
        if not st or st.round ~= r then return end
        if r.shown >= r.seq then
            r.busy = false
            return done()
        end
        local c = r.bySeq[r.shown + 1]
        if c and c.to == 'dealer' then
            dealerAnim(tid, 'self', nil, ('%02d'):format(math.max(3, math.min(11, #r.dealer))))
        elseif c then
            dealerAnim(tid, 'hit', { c.to })
        end
        L.After(key(tid, 'reveal'), T.CardAt, function()
            if not tables[tid] or tables[tid].round ~= r then return end
            r.shown = r.shown + 1
            push(tid)
            L.After(key(tid, 'reveal'), T.Card - T.CardAt, step)
        end)
    end
    step()
end

---------------------------------------------------------------------
-- Round flow
---------------------------------------------------------------------
local startRound, closeBetting, afterDeal, afterInsurance, nextTurn, dealerPlay, settle, applyMove

local function abort(tid, why)
    local st = tables[tid]
    local r = st and st.round
    if r then
        L.Cancel(r.id, why)
        L.Say(tid, nil, locale('hand_failed', tostring(why)))
        st.round = nil
    end
    L.CancelTimers(('bj:%d:'):format(tid))
    push(tid)
    L.After(key(tid, 'next'), T.Next, function() startRound(tid) end)
end

local function stake(tid, r, seat, amount)
    local ok, net = L.Bet(r.id, seat, amount)
    if not ok then
        local P = r.seats[seat]
        if P and P.src then L.Say(tid, P.src, locale('hand_failed', tostring(net))) end
        return nil
    end
    r.seats[seat].staked = r.seats[seat].staked + amount
    return net
end

startRound = function(tid)
    local st = tables[tid]
    if not st or st.round then return end
    local handId, err = L.BeginHand(tid)
    if not handId then
        if err ~= 'no_players' then print(('[%s] BeginHand: %s'):format(GAME, tostring(err))) end
        return push(tid)
    end
    local r = { id = handId, phase = 'betting', stakes = L.Stakes(tid), seats = {}, order = {}, dealer = {}, seq = 0, bySeq = {},
        shown = 0, holeShown = false, deadline = os.time() + T.Bet // 1000 }
    for _, p in ipairs(L.Seats(tid)) do
        if p.inHand then
            r.seats[p.seat] = { seat = p.seat, name = p.name, src = p.src, npc = p.npc, avail = p.available, staked = 0,
                hands = {}, active = 1 }
        end
    end
    r.order = sortedSeats(r.seats)
    st.round = r
    L.After(key(tid, 'bet'), T.Bet, function() closeBetting(tid) end)
    L.Say(tid, nil, locale('place_bets'))
    -- NPCs bet a moment in, sized by their personality (their bets are scenery: no house money)
    for _, seat in ipairs(r.order) do
        local P = r.seats[seat]
        if P.npc then
            L.After(key(tid, 'npcbet' .. seat), math.random(T.NpcBet[1], T.NpcBet[2]), function()
                local cur = tables[tid] and tables[tid].round
                if cur ~= r or r.phase ~= 'betting' or P.amount then return end
                local amount = Brain.PvdBet(L.NpcProfile(tid, seat), r.stakes.minBet, r.stakes.maxBet, P.avail, r.stakes.minBet)
                if amount then applyMove(tid, seat, 'bet', amount) end
            end)
        end
    end
    push(tid)
end

local function everyone(r, test)
    for _, seat in ipairs(r.order) do
        local P = r.seats[seat]
        if not P.gone and not test(P) then return false end
    end
    return true
end

local function dealCards(tid)
    local st = tables[tid]
    local r = st and st.round
    if not r then return end
    r.phase = 'dealing'
    for _ = 1, 2 do
        for _, seat in ipairs(r.order) do
            local h = r.seats[seat].hands[1]
            h.cards[#h.cards + 1] = draw(st, r, seat)
        end
        r.dealer[#r.dealer + 1] = draw(st, r, 'dealer')
    end
    reveal(tid, r, function() afterDeal(tid) end)
end

closeBetting = function(tid)
    local st = tables[tid]
    local r = st and st.round
    if not r or r.phase ~= 'betting' then return end
    L.CancelTimer(key(tid, 'bet'))
    local order = {}
    for _, seat in ipairs(r.order) do if r.seats[seat].amount then order[#order + 1] = seat else r.seats[seat] = nil end end
    r.order = order
    r.deadline = nil
    if #order == 0 then
        L.Cancel(r.id, 'no_bets')
        st.round = nil
        L.Say(tid, nil, locale('no_bets'))
        push(tid)
        return L.After(key(tid, 'next'), T.Next, function() startRound(tid) end)
    end
    if not st.shoe or st.shoe:Remaining() < st.shoe.size * (1 - R.Penetration) then
        st.shoe = Cards.NewShoe(R.Decks)
        L.Say(tid, nil, locale('shuffle'))
        dealerAnim(tid, 'shuffle')
        r.phase = 'dealing'
        push(tid)
        return L.After(key(tid, 'shuffle'), T.Shuffle, function() dealCards(tid) end)
    end
    dealCards(tid)
end

afterDeal = function(tid)
    local r = tables[tid].round
    local up = r.dealer[1]
    L.Say(tid, nil, locale('dealer_shows', upLabel(up)))
    if R.Insurance and up.r == 14 then
        r.phase = 'insurance'
        r.deadline = os.time() + T.Insurance // 1000
        dealerAnim(tid, 'insurance')
        L.Say(tid, nil, locale('insurance_offer'))
        for _, seat in ipairs(r.order) do
            local P = r.seats[seat]
            if P.npc then
                L.After(key(tid, 'npcins' .. seat), math.random(1200, 3500), function()
                    local cur = tables[tid] and tables[tid].round
                    if cur ~= r or r.phase ~= 'insurance' or P.insDecided then return end
                    local prof = L.NpcProfile(tid, seat)
                    -- basic strategy never insures; a drunk or a nervous one sometimes does
                    local take = prof and math.random() < ((prof.drunk and 0.4 or 0) + (prof.noise or 0.05))
                    applyMove(tid, seat, take and 'insurance' or 'no_insurance')
                end)
            end
        end
        L.After(key(tid, 'ins'), T.Insurance, function() afterInsurance(tid) end)
        return push(tid)
    end
    afterInsurance(tid)
end

afterInsurance = function(tid)
    local st = tables[tid]
    local r = st and st.round
    if not r or (r.phase ~= 'insurance' and r.phase ~= 'dealing') then return end
    L.CancelTimer(key(tid, 'ins'))
    r.deadline = nil
    for _, seat in ipairs(r.order) do r.seats[seat].insDecided = true end
    local up = r.dealer[1]
    if BJ.DealerPeeks(up) then
        dealerAnim(tid, 'peek')
        if BJ.Score(r.dealer) == 21 then
            r.phase = 'dealer'
            r.holeShown = true
            dealerAnim(tid, 'peekReveal')
            L.Say(tid, nil, locale('dealer_blackjack'))
            push(tid)
            return L.After(key(tid, 'settle'), T.DealerStep, function() settle(tid) end)
        end
    end
    r.phase = 'playing'
    for _, seat in ipairs(r.order) do
        local h = r.seats[seat].hands[1]
        if BJ.IsBlackjack(h) then
            h.done = true
            L.Say(tid, nil, locale('has_blackjack', r.seats[seat].name))
        end
    end
    nextTurn(tid)
end

local function armTurn(tid, r, seat)
    r.deadline = os.time() + T.Act // 1000
    L.After(key(tid, 'act'), T.Act, function()
        local cur = tables[tid] and tables[tid].round
        if cur ~= r or r.turn ~= seat or r.phase ~= 'playing' then return end
        L.Say(tid, nil, locale('timed_out', r.seats[seat].name))
        applyMove(tid, seat, 'stand')
    end)
    local P = r.seats[seat]
    if P.npc then
        local prof = L.NpcProfile(tid, seat)
        L.After(key(tid, 'npc'), Brain.ThinkMs(prof, 0.5), function()
            local cur = tables[tid] and tables[tid].round
            if cur ~= r or r.turn ~= seat or r.busy or r.waiting then return end
            local h = P.hands[P.active]
            if not h then return end
            local move = BJ.NpcMove(h, r.dealer[1], BJ.CanDouble(h, R) and free(P) >= h.amount,
                BJ.CanSplit(h, #P.hands, R) and free(P) >= h.amount, prof)
            applyMove(tid, seat, move)
        end)
    end
end

nextTurn = function(tid)
    local r = tables[tid].round
    L.CancelTimer(key(tid, 'act'))
    L.CancelTimer(key(tid, 'npc'))
    for _, seat in ipairs(r.order) do
        local P = r.seats[seat]
        if not P.gone then
            for hi, h in ipairs(P.hands) do
                if not h.done then
                    -- a beat first: the turn moves (marker, heads turn), then the actions appear
                    r.turn, P.active, r.waiting, r.deadline = seat, hi, true, nil
                    push(tid)
                    L.After(key(tid, 'beat'), L.Beat(T.TurnBeat[1], T.TurnBeat[2]), function()
                        local cur = tables[tid] and tables[tid].round
                        if cur ~= r or r.turn ~= seat then return end
                        r.waiting = false
                        armTurn(tid, r, seat)
                        push(tid)
                    end)
                    return
                end
            end
        end
    end
    r.turn = nil
    dealerPlay(tid)
end

-- After a move: the same hand goes on, or the turn moves on
local function continueTurn(tid, r, seat)
    local P = r.seats[seat]
    local h = P.hands[P.active]
    if h and not h.done then
        armTurn(tid, r, seat)
        return push(tid)
    end
    nextTurn(tid)
end

dealerPlay = function(tid)
    local st = tables[tid]
    local r = st.round
    r.phase = 'dealer'
    r.deadline = nil
    push(tid)
    local live = false
    for _, seat in ipairs(r.order) do
        for _, h in ipairs(r.seats[seat].hands) do
            if not BJ.IsBust(h.cards) and not BJ.IsBlackjack(h) then live = true end
        end
    end
    local function step()
        local cur = tables[tid] and tables[tid].round
        if cur ~= r then return end
        if live and BJ.DealerHits(r.dealer, R) then
            r.dealer[#r.dealer + 1] = draw(st, r, 'dealer')
            dealerAnim(tid, 'self', nil, ('%02d'):format(math.min(11, #r.dealer)))
            -- the card lands partway into his reach
            return L.After(key(tid, 'dealer'), T.CardAt, function()
                if not tables[tid] or tables[tid].round ~= r then return end
                r.shown = r.seq
                push(tid)
                L.After(key(tid, 'dealer'), T.DealerStep - T.CardAt, step)
            end)
        end
        local total = BJ.Score(r.dealer)
        L.Say(tid, nil, locale(total > 21 and 'dealer_busts' or 'dealer_has', total))
        settle(tid)
    end
    -- a breath, then he turns his hole card over in time with the clip
    L.Seq(key(tid, 'dealer')):Wait(L.Beat(500, 800)):Do(function()
        if not tables[tid] or tables[tid].round ~= r then return false end
        dealerAnim(tid, 'reveal')
    end):Wait(T.RevealAt):Do(function()
        if not tables[tid] or tables[tid].round ~= r then return false end
        r.holeShown = true
        push(tid)
    end):Wait(T.DealerStep):Do(step):Run()
end

settle = function(tid)
    local st = tables[tid]
    local r = st and st.round
    if not r or r.phase == 'result' or r.settling then return end
    r.settling = true
    local dealerBJ = #r.dealer == 2 and BJ.Score(r.dealer) == 21
    local payouts, outcomes = {}, {}
    for _, seat in ipairs(r.order) do
        local P = r.seats[seat]
        local total, best = 0, 'lose'
        for _, h in ipairs(P.hands) do
            h.outcome = BJ.Outcome(h, r.dealer)
            total = total + BJ.Payout(h.net, h.outcome)
            if h.outcome == 'blackjack' or (h.outcome == 'win' and best ~= 'blackjack') or (h.outcome == 'push' and best == 'lose') then
                best = h.outcome
            end
        end
        if P.insurance then total = total + BJ.InsurancePayout(P.insurance.net, dealerBJ) end
        payouts[seat], outcomes[seat] = total, best
    end
    -- who won and lost, worked out now; shown as a sequence: the dealer takes the losing bets, the money settles
    -- (the pot slides to him or to the biggest winner), he pays the winners, everyone reacts, one line at a time
    local results, winners, losers, lines = {}, {}, {}, {}
    for _, seat in ipairs(r.order) do
        local P = r.seats[seat]
        local profit = payouts[seat] - P.staked
        if profit > 0 then
            results[#results + 1] = { seat = seat, amount = profit }
            winners[#winners + 1] = seat
        elseif profit < 0 then
            losers[#losers + 1] = seat
        end
        local o = outcomes[seat]
        if o == 'blackjack' then lines[#lines + 1] = locale('result_blackjack', P.name, L.Fmt(math.max(0, profit)))
        elseif profit > 0 then lines[#lines + 1] = locale('result_win', P.name, L.Fmt(profit))
        elseif profit == 0 then lines[#lines + 1] = locale('result_push', P.name)
        else lines[#lines + 1] = locale('result_lose', P.name, L.Fmt(-profit)) end
        if P.insurance and dealerBJ then lines[#lines + 1] = locale('insurance_pays', P.name, L.Fmt(P.insurance.net * 2)) end
    end
    local function here() return tables[tid] ~= nil and tables[tid].round == r end
    local seq = L.Seq(key(tid, 'result')):Wait(L.Beat(500, 800)):Do(function()
        if not here() then return false end
        for _, seat in ipairs(losers) do seatAnim(tid, seat, 'lose') end
        dealerAnim(tid, 'collect', losers)
    end):Wait(#losers > 0 and math.floor(A.Dealer.collect.ms * 0.6) or 0):Do(function()
        if not here() then return false end
        local ok, err = L.Settle(r.id, { payouts = payouts })
        if not ok then abort(tid, err) return false end
        r.phase, r.turn, r.deadline, r.holeShown, r.shown = 'result', nil, nil, true, r.seq
        push(tid, results)
    end):Wait(#winners > 0 and 600 or 0):Do(function()
        if not here() then return false end
        for _, seat in ipairs(winners) do seatAnim(tid, seat, 'win') end
        dealerAnim(tid, 'pay', winners)
    end)
    for _, line in ipairs(lines) do
        seq:Wait(T.Line):Do(function() if not here() then return false end L.Say(tid, nil, line) end)
    end
    seq:Wait(T.Result):Do(function()
        if not here() then return false end
        dealerAnim(tid, 'cards', r.order)
    end):Wait(math.floor(A.Dealer.cards.ms * 0.5)):Do(function()
        local cur = tables[tid]
        if not cur or cur.round ~= r then return false end
        cur.round = nil
        push(tid)                                  -- the cards go back to the dealer (they slide on the client)
        L.After(key(tid, 'next'), T.Next, function() startRound(tid) end)
    end):Run()
end

---------------------------------------------------------------------
-- Moves (players and NPCs)
---------------------------------------------------------------------
applyMove = function(tid, seat, id, amount, src)
    local st = tables[tid]
    local r = st and st.round
    if not r then return false end
    local P = r.seats[seat]
    if not P or P.gone then return false end
    local function no(msg) if src then L.Say(tid, src, locale(msg or 'illegal')) end return false end

    if id == 'bet' then
        if r.phase ~= 'betting' then return no() end
        if P.amount then return no('already_bet') end
        local max = math.min(r.stakes.maxBet, P.avail)
        amount = math.tointeger(amount)
        if not amount or amount < r.stakes.minBet or amount > max or amount % r.stakes.minBet ~= 0 then
            if src then L.Say(tid, src, locale('bad_bet', L.Fmt(r.stakes.minBet), L.Fmt(max))) end
            return false
        end
        local net = stake(tid, r, seat, amount)
        if not net then return false end
        P.amount = amount
        P.hands = { { cards = {}, amount = amount, net = net } }
        seatAnim(tid, seat, 'bet')
        L.Say(tid, nil, locale('bets', P.name, L.Fmt(amount)))
        if everyone(r, function(x) return x.amount ~= nil end) then closeBetting(tid) else push(tid) end
        return true
    end

    if id == 'insurance' or id == 'no_insurance' then
        if r.phase ~= 'insurance' or not P.amount or P.insDecided then return no() end
        if id == 'insurance' then
            local ins = P.amount // 2
            if ins <= 0 or free(P) < ins then return no() end
            local net = stake(tid, r, seat, ins)
            if not net then return false end
            P.insurance = { amount = ins, net = net }
            seatAnim(tid, seat, 'insurance')
            L.Say(tid, nil, locale('insures', P.name))
        end
        P.insDecided = true
        if everyone(r, function(x) return x.insDecided end) then afterInsurance(tid) else push(tid) end
        return true
    end

    -- playing moves
    if r.phase ~= 'playing' or r.turn ~= seat or r.busy or r.waiting then return no(r.turn ~= seat and 'not_your_turn' or nil) end
    local h = P.hands[P.active]
    if not h or h.done then return no() end
    L.CancelTimer(key(tid, 'act'))
    L.CancelTimer(key(tid, 'npc'))

    if id == 'stand' then
        h.done = true
        seatAnim(tid, seat, 'stand')
        L.Say(tid, nil, locale('stands', P.name, BJ.Score(h.cards)))
        nextTurn(tid)
        return true
    end

    if id == 'hit' then
        h.cards[#h.cards + 1] = draw(st, r, seat)
        seatAnim(tid, seat, 'hit')
        reveal(tid, r, function()
            local total = BJ.Score(h.cards)
            if total > 21 then
                h.done = true
                L.Say(tid, nil, locale('busts', P.name, total))
            elseif total == 21 then
                h.done = true
            end
            continueTurn(tid, r, seat)
        end)
        return true
    end

    if id == 'double' then
        if not BJ.CanDouble(h, R) or free(P) < h.amount then return no() end
        local net = stake(tid, r, seat, h.amount)
        if not net then return false end
        h.net, h.amount, h.doubled = h.net + net, h.amount * 2, true
        h.cards[#h.cards + 1] = draw(st, r, seat)
        seatAnim(tid, seat, 'double')
        L.Say(tid, nil, locale('doubles', P.name))
        reveal(tid, r, function()
            h.done = true
            local total = BJ.Score(h.cards)
            if total > 21 then L.Say(tid, nil, locale('busts', P.name, total)) end
            continueTurn(tid, r, seat)
        end)
        return true
    end

    if id == 'split' then
        if not BJ.CanSplit(h, #P.hands, R) or free(P) < h.amount then return no() end
        local net = stake(tid, r, seat, h.amount)
        if not net then return false end
        local aces = h.cards[1].r == 14
        local h2 = { cards = { h.cards[2] }, amount = h.amount, net = net, split = true, fromAces = aces }
        h.cards = { h.cards[1] }
        h.split, h.fromAces = true, aces
        table.insert(P.hands, P.active + 1, h2)
        h.cards[2] = draw(st, r, seat)
        h2.cards[2] = draw(st, r, seat)
        seatAnim(tid, seat, 'split')
        L.Say(tid, nil, locale('splits', P.name))
        reveal(tid, r, function()
            if aces then
                h.done, h2.done = true, true          -- split aces: one card each
            else
                if BJ.Score(h.cards) == 21 then h.done = true end
                if BJ.Score(h2.cards) == 21 then h2.done = true end
            end
            continueTurn(tid, r, seat)
        end)
        return true
    end
    return no()
end

local function onAction(tid, seat, src, id, amount)
    local st = tables[tid]
    local r = st and st.round
    if not r then return end
    local P = r.seats[seat]
    if not P then
        if r.phase == 'betting' then L.Say(tid, src, locale('not_in_round')) end
        return
    end
    if P.npc then return end
    applyMove(tid, seat, id, amount, src)
end

---------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------
L.RegisterGame({
    id = GAME, label = locale('label'), kind = 'pvd', minSeats = 1, maxSeats = 4,
    models = { 'p_blackjacktable01x', 'p_blackjacktable02x' },
    dealer = true, houseEdge = C.HouseEdge, maxPayout = C.MaxPayout,
}, {
    tableStarted = function(tid)
        tables[tid] = {}
        L.After(key(tid, 'next'), 2500, function() startRound(tid) end)
    end,
    seatTaken = function(tid)
        local st = tables[tid]
        if st and not st.round then L.After(key(tid, 'next'), 1500, function() startRound(tid) end) end
    end,
    stackChanged = function(tid, seat)
        local st = tables[tid]
        if st and not st.round then L.After(key(tid, 'next'), 1000, function() startRound(tid) end) end
        -- a player who bought in during the betting window joins this round
        local r = st and st.round
        if r and r.phase == 'betting' and not r.seats[seat] then
            for _, p in ipairs(L.Seats(tid)) do
                if p.seat == seat and p.inHand then
                    r.seats[seat] = { seat = seat, name = p.name, src = p.src, npc = p.npc, avail = p.available, staked = 0,
                        hands = {}, active = 1 }
                    r.order = sortedSeats(r.seats)
                    push(tid)
                end
            end
        end
    end,
    seatLeft = function(tid, seat)
        local st = tables[tid]
        local r = st and st.round
        local P = r and r.seats[seat]
        if not P then return end
        P.gone = true
        if r.phase == 'betting' and not P.amount then
            r.seats[seat] = nil
            r.order = sortedSeats(r.seats)
            if #r.order > 0 and everyone(r, function(x) return x.amount ~= nil end) then closeBetting(tid) else push(tid) end
            return
        end
        -- bets already in stay in: their hands stand, and any win is paid to them by the core
        for _, h in ipairs(P.hands) do h.done = true end
        P.insDecided = true
        if r.phase == 'insurance' and everyone(r, function(x) return x.insDecided end) then return afterInsurance(tid) end
        if r.phase == 'playing' and r.turn == seat and not r.busy then return nextTurn(tid) end
        push(tid)
    end,
    action = onAction,
    tableStopping = function(tid)
        L.CancelTimers(('bj:%d:'):format(tid))
        tables[tid] = nil
    end,
})
