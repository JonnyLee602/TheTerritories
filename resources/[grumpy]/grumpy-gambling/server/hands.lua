-- Hands (DESIGN.md §7.3–7.6, §11.3): the only place money moves during play. Amounts are integer cents.
--
-- A hand holds bets in memory. Nothing is written until Settle, which commits every stack, the rake, the house
-- and the ledger in ONE transaction. A crash mid-hand therefore leaves everyone's pre-hand stack (the hand never
-- happened). Settle refuses any result where money doesn't balance.
--
-- Ledger sign: amount = change in money held by the core (stacks + open pots + cashboxes): + in, - out.
local Hands = { open = {}, byTable = {}, seq = 0 }
GG.Hands = Hands
local M = GG.M

---------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------
function Hands.Get(handId) return handId and Hands.open[handId] or nil end
function Hands.ForTable(tableId) local id = Hands.byTable[tableId]; return id and Hands.open[id] or nil end

function Hands.Contributed(tableId, seat)
    local h = Hands.ForTable(tableId)
    local s = h and h.seats[seat]
    return s and s.contrib or 0
end

-- Chips of a seat that are really in the pot. NPC bets at PVD tables are scenery (DESIGN.md §8.2): nothing at risk.
function Hands.AtRisk(tableId, seat)
    local h = Hands.ForTable(tableId)
    local s = h and h.seats[seat]
    if not s or (h.kind == 'pvd' and s.npc) then return 0 end
    return s.contrib
end

function Hands.InHand(tableId, seat)
    local h = Hands.ForTable(tableId)
    return h ~= nil and h.seats[seat] ~= nil and not h.seats[seat].departed
end

function Hands.Reserved(tableId)
    local h = Hands.ForTable(tableId)
    return h and h.reserved or 0
end

local function total(h)
    local n = 0
    for _, s in pairs(h.seats) do n = n + s.contrib end
    return n
end

local function rakeCap(h) return Config.Rake.Pvp.MaxPerHandBB * h.bb end

-- Pot as players should see it: bets minus the rake they've paid so far
function Hands.PotDisplay(h)
    local t = total(h)
    if h.kind ~= 'pvp' or not h.rakeable then return t end
    local r = M.Skim(t, h.rate, h.rem, rakeCap(h))
    return t - r
end

-- Only the resource that registered a table's game may drive its hands
local function callerOk(t)
    local inv = GetInvokingResource()
    if not inv or inv == GetCurrentResourceName() then return true end
    local g = GG.Registry.Get(t.game)
    return g ~= nil and g.resource == inv
end

-- the pot appears on the table with the hand's first chip (GG.Play loads after this file)
local function potUp(t) if GG.Play then GG.Play.SetPot(t, true) end end

local function handAndTable(handId)
    local h = Hands.open[handId]
    if not h then return nil, nil, 'no_hand' end
    local t = GG.Tables.Get(h.tableId)
    if not t then return nil, nil, 'no_table' end
    if not callerOk(t) then return nil, nil, 'not_your_table' end
    return h, t
end

---------------------------------------------------------------------
-- Begin
---------------------------------------------------------------------
function Hands.Begin(tableId)
    local t = GG.Tables.Get(tableId)
    if not t then return nil, 'no_table' end
    if t.state ~= 'active' or not t.game or not t.tier then return nil, 'table_not_started' end
    if not callerOk(t) then return nil, 'not_your_table' end
    if Hands.byTable[t.id] then return nil, 'hand_open' end
    local g = GG.Registry.Get(t.game)
    if not g then return nil, 'no_game' end
    if t.kind == 'pvd' and not g.maxPayout then return nil, 'game_needs_maxPayout' end

    local seats, n = {}, 0
    for i = 1, #t.seats do
        local occ = t.occupants[i]
        if occ and (occ.stack or 0) > 0 then
            seats[i] = { cid = occ.cid, src = occ.src, name = occ.name, npc = occ.npc == true, contrib = 0, net = 0, skim = 0 }
            n = n + 1
        end
    end
    if n == 0 then return nil, 'no_players' end

    Hands.seq = Hands.seq + 1
    local h = {
        id = ('%d-%d-%d'):format(t.id, os.time(), Hands.seq),
        tableId = t.id, game = t.game, tier = t.tier, kind = t.kind, currency = t.currency,
        rate = GG.Rake.Rate(t), rem = GG.Rake.Remainder(t.id), rakeable = true,
        bb = M.ToCents(Config.Tiers[t.tier].bigBlind), maxPayout = g.maxPayout,
        startedAt = os.time(), seats = seats, reserved = 0,
    }
    Hands.open[h.id] = h
    Hands.byTable[t.id] = h.id
    return h.id
end

---------------------------------------------------------------------
-- Bets
---------------------------------------------------------------------
-- PVP: the amount goes into the pot. PVD: the rake comes out of the amount and the rest is the stake at risk
-- (returned as `net`, which is what payouts are worked out on).
function Hands.Bet(handId, seat, amountC)
    local h, t, err = handAndTable(handId)
    if not h then return false, err end
    local s = h.seats[seat]
    if not s or s.departed then return false, 'not_in_hand' end
    amountC = math.tointeger(amountC)
    if not M.IsCents(amountC) or amountC <= 0 then return false, 'bad_amount' end
    local occ = t.occupants[seat]
    if not occ or occ.cid ~= s.cid then return false, 'not_in_hand' end
    if amountC > occ.stack - s.contrib then return false, 'not_enough_chips' end

    -- PVD NPC bets move no money: no rake, no house cover, no house result. Only the NPC's own (made-up) stack
    -- follows the result, so it looks like a real player.
    if h.kind == 'pvd' and s.npc then
        s.contrib = s.contrib + amountC
        s.net = s.net + amountC
        potUp(t)
        return true, amountC
    end

    if h.kind == 'pvd' then
        local skim, rem = M.Skim(amountC, h.rate, h.rem)
        local net = amountC - skim
        local exposure = math.ceil(net * (h.maxPayout - 1))
        if not GG.House.CanCover(t, exposure) then return false, 'house_cover' end
        h.rem = rem
        h.reserved = h.reserved + exposure
        s.net = s.net + net
        s.skim = s.skim + skim
        s.contrib = s.contrib + amountC
        potUp(t)
        return true, net
    end
    s.contrib = s.contrib + amountC
    potUp(t)
    return true, amountC
end

-- PVP: hand back an uncalled bet (it never reaches the pot, so it pays no rake)
function Hands.Return(handId, seat, amountC)
    local h, _, err = handAndTable(handId)
    if not h then return false, err end
    if h.kind ~= 'pvp' then return false, 'pvp_only' end
    local s = h.seats[seat]
    amountC = math.tointeger(amountC)
    if not s or not M.IsCents(amountC) or amountC <= 0 or amountC > s.contrib then return false, 'bad_amount' end
    s.contrib = s.contrib - amountC
    return true
end

-- PVP: false = no rake this hand (e.g. Hold'em ends before the flop: "no flop, no drop")
function Hands.SetRakeable(handId, rakeable)
    local h, _, err = handAndTable(handId)
    if not h then return false, err end
    h.rakeable = rakeable == true
    return true
end

function Hands.SeatLeaving(tableId, seat)
    local h = Hands.ForTable(tableId)
    if h and h.seats[seat] then h.seats[seat].departed = true end
end

function Hands.Info(handId)
    local h, t, err = handAndTable(handId)
    if not h then return nil, err end
    local seats = {}
    for seat, s in pairs(h.seats) do
        local occ = t.occupants[seat]
        seats[#seats + 1] = { seat = seat, bet = s.contrib, net = s.net, departed = s.departed == true,
            available = (occ and occ.cid == s.cid) and (occ.stack - s.contrib) or 0 }
    end
    return { id = h.id, kind = h.kind, rate = h.rate, pot = Hands.PotDisplay(h), wagered = total(h), seats = seats }
end

---------------------------------------------------------------------
-- Cancel: everyone keeps their pre-hand stack; players who already left get their bets back
---------------------------------------------------------------------
local function close(h)
    Hands.open[h.id] = nil
    if Hands.byTable[h.tableId] == h.id then Hands.byTable[h.tableId] = nil end
    local t = GG.Play and GG.Tables.Get(h.tableId)
    if t then GG.Play.SetPot(t, false) end
end

function Hands.Cancel(handId, reason)
    local h = Hands.open[handId]
    if not h then return false, 'no_hand' end
    local t = GG.Tables.Get(h.tableId)
    if t and not callerOk(t) then return false, 'not_your_table' end
    close(h)
    for _, s in pairs(h.seats) do
        if s.departed and s.contrib > 0 then
            if s.npc then
                if h.kind == 'pvp' then GG.Npc.Sink(h.tableId, h.id, s.cid, h.currency, s.contrib) end
            else GG.Wallet.PayOrPend(s.cid, h.currency, s.contrib, 'refund', h.tableId, h.id) end
        end
    end
    GG.Debug('hand cancelled', h.id, reason)
    if t and GG.Npc then GG.Npc.AfterHand(t, nil) end
    return true
end

---------------------------------------------------------------------
-- Settle
-- PVP result: { ranking = { {seat}, {seat, seat}, ... } (best first, ties grouped; folded seats left out),
--               oddOrder = { seat, ... } (optional: who gets odd cents of a split) }
-- PVD result: { payouts = { [seat] = cents } } total returned to each seat (stake included; 0 = lost)
---------------------------------------------------------------------
local function settlePvp(h, result)
    if type(result.ranking) ~= 'table' or #result.ranking == 0 then return nil, 'bad_ranking' end
    local live, seen = {}, {}
    for _, group in ipairs(result.ranking) do
        if type(group) ~= 'table' or #group == 0 then return nil, 'bad_ranking' end
        for _, seat in ipairs(group) do
            if not h.seats[seat] or seen[seat] then return nil, 'bad_ranking' end
            seen[seat] = true
            live[seat] = true
        end
    end
    local contrib, sum = {}, 0
    for seat, s in pairs(h.seats) do contrib[seat] = s.contrib; sum = sum + s.contrib end
    local rakeC, rem = 0, h.rem
    if h.rakeable and h.rate > 0 then rakeC, rem = M.Skim(sum, h.rate, h.rem, rakeCap(h)) end
    local pots, perr = M.SidePots(contrib, live)
    if not pots then return nil, perr end
    if not M.TakeRake(pots, rakeC) then return nil, 'rake_exceeds_pot' end
    local awards, aerr = M.Award(pots, result.ranking, result.oddOrder)
    if not awards then return nil, aerr end
    local paid = 0
    for _, a in pairs(awards) do paid = paid + a end
    if paid + rakeC ~= sum then return nil, 'unbalanced' end
    return { awards = awards, rake = rakeC, rem = rem, house = 0, wagered = sum }
end

local function settlePvd(h, result)
    if type(result.payouts) ~= 'table' then return nil, 'bad_payouts' end
    local awards, paid, net, rakeC, sum = {}, 0, 0, 0, 0
    local payouts = {}
    for seat, p in pairs(result.payouts) do
        seat, p = math.tointeger(seat), math.tointeger(p)
        if not seat or not h.seats[seat] or not M.IsCents(p) then return nil, 'bad_payouts' end
        payouts[seat] = p
    end
    for seat, s in pairs(h.seats) do
        local p = payouts[seat] or 0
        if p > math.floor(s.net * h.maxPayout + 0.5) then return nil, 'payout_too_high' end
        if p > 0 then awards[seat] = p end
        if not s.npc then -- NPC bets are scenery: they never touch the house
            paid, net, rakeC, sum = paid + p, net + s.net, rakeC + s.skim, sum + s.contrib
        end
    end
    if net + rakeC ~= sum then return nil, 'unbalanced' end
    -- house: > 0 pays players (created or from the cashbox), < 0 keeps the players' losses
    return { awards = awards, rake = rakeC, rem = h.rem, house = paid - net, wagered = sum }
end

function Hands.Settle(handId, result)
    local h, t, err = handAndTable(handId)
    if not h then return false, err end
    if type(result) ~= 'table' then return false, 'bad_result' end
    local r, rerr
    if h.kind == 'pvp' then r, rerr = settlePvp(h, result) else r, rerr = settlePvd(h, result) end
    if not r then return false, rerr end

    local boxShare, sinkC = GG.Rake.Split(t, r.rake)
    local cashbox = GG.House.IsCashbox(t)
    local boxDelta = cashbox and (boxShare - r.house) or 0
    if cashbox and GG.House.Balance(t) + boxDelta < 0 then return false, 'house_cover' end

    local stacks, pending, ledger, data = {}, {}, {}, {}
    local newStacks = {}
    for seat, s in pairs(h.seats) do
        local award = r.awards[seat] or 0
        local occ = t.occupants[seat]
        data[#data + 1] = { seat = seat, cid = s.cid, bet = s.contrib, won = award, left = s.departed == true, npc = s.npc or nil }
        if not s.departed and occ and occ.cid == s.cid then
            local ns = occ.stack - s.contrib + award
            newStacks[seat] = ns
            stacks[#stacks + 1] = { cid = s.cid, tableId = t.id, currency = h.currency, amount = ns }
            if s.npc and h.kind == 'pvd' and award ~= s.contrib then
                -- the NPC's scenery bet: its made-up stack grows or shrinks with nobody paying
                ledger[#ledger + 1] = { kind = award > s.contrib and 'npc_mint' or 'npc_sink', tableId = t.id, handId = h.id,
                    cid = s.cid, currency = h.currency, amount = award - s.contrib, note = 'pvd scenery' }
            end
        elseif s.npc then
            if award > 0 and h.kind == 'pvp' then
                GG.Npc.Sink(t.id, h.id, s.cid, h.currency, award, ledger) -- an NPC that left can't be paid
            end
        elseif award > 0 then
            pending[#pending + 1] = { cid = s.cid, currency = h.currency, amount = award }
            ledger[#ledger + 1] = { kind = 'pending', tableId = t.id, handId = h.id, cid = s.cid, currency = h.currency,
                amount = -award, note = 'won after leaving' }
        end
    end
    if sinkC > 0 then
        ledger[#ledger + 1] = { kind = 'rake', tableId = t.id, handId = h.id, currency = h.currency, amount = -sinkC }
    end
    if boxShare > 0 then
        ledger[#ledger + 1] = { kind = 'rake_box', tableId = t.id, handId = h.id, currency = h.currency, amount = 0,
            note = M.Fmt(boxShare) }
    end
    if not cashbox and r.house ~= 0 then
        ledger[#ledger + 1] = { kind = r.house > 0 and 'mint' or 'sink', tableId = t.id, handId = h.id,
            currency = h.currency, amount = r.house }
    end

    local npcWindow = GG.Npc and h.kind == 'pvp' and GG.Npc.CapEntries(h, r.awards) or {}

    local ok = GG.DB.Settle({
        stacks = stacks, pending = pending, ledger = ledger, npcWindow = npcWindow,
        remainder = { tableId = t.id, value = r.rem },
        cashbox = cashbox and { tableId = t.id, currency = h.currency, delta = boxDelta } or nil,
        boxStats = cashbox and { tableId = t.id, rake = boxShare, house = -r.house } or nil,
        hand = { id = h.id, tableId = t.id, game = h.game, tier = h.tier, currency = h.currency, startedAt = h.startedAt,
            wagered = r.wagered, rake = r.rake, house = r.house, data = { rate = h.rate, seats = data } },
    })
    if not ok then
        print(('^1[grumpy-gambling] settling hand %s failed in the database; the hand is cancelled^7'):format(h.id))
        Hands.Cancel(h.id, 'db_error')
        return false, 'db_error'
    end

    -- committed: bring memory in line
    close(h)
    local now = os.time()
    local chipsChanged = false
    for seat, ns in pairs(newStacks) do
        local occ = t.occupants[seat]
        if (occ.stack > 0) ~= (ns > 0) then chipsChanged = true end
        occ.stack = ns
        if occ.markAt then GG.Rake.RecordSeconds(t, now - occ.markAt); occ.markAt = now end
    end
    if chipsChanged then GG.Tables.Sync(t) end -- someone busted (or came back): their chip stack follows
    GG.Rake.SetRemainder(t.id, r.rem)
    GG.House.Applied(t, boxDelta)
    GG.Rake.RecordHand(t, r.wagered, r.rake)
    for _, p in ipairs(pending) do
        local Player = GG.Core.Functions.GetPlayerByCitizenId(p.cid)
        if Player then GG.Wallet.PayPending(Player) end
    end
    if GG.Play then GG.Play.SettleCues(t, h, r.awards) end
    if GG.Npc then
        GG.Npc.CapApplied(npcWindow)
        GG.Npc.AfterHand(t, h, r.awards)
    end
    return true, { awards = r.awards, rake = r.rake, house = r.house, wagered = r.wagered }
end

---------------------------------------------------------------------
-- Seats with chips, for modules
---------------------------------------------------------------------
function Hands.Seats(tableId)
    local t = GG.Tables.Get(tableId)
    if not t then return nil end
    local list = {}
    for i = 1, #t.seats do
        local occ = t.occupants[i]
        if occ then
            list[#list + 1] = { seat = i, src = occ.src, cid = occ.cid, name = occ.name, npc = occ.npc == true, stack = occ.stack or 0,
                available = (occ.stack or 0) - Hands.Contributed(t.id, i), inHand = Hands.InHand(t.id, i) }
        end
    end
    return list
end

---------------------------------------------------------------------
-- Exports (DESIGN.md §11.3). Only the game's own resource may call the hand functions for its tables.
---------------------------------------------------------------------
exports('BeginHand', Hands.Begin)
exports('Bet', Hands.Bet)
exports('Return', Hands.Return)
exports('SetRakeable', Hands.SetRakeable)
exports('Settle', Hands.Settle)
exports('CancelHand', Hands.Cancel)
exports('GetHand', Hands.Info)
exports('GetSeats', Hands.Seats)
