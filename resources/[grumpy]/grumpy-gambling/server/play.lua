-- Play plumbing between seated players and game modules (DESIGN.md §11): table views, player actions, stakes.
local Play = { views = {} }
GG.Play = Play

-- Only the resource that registered a table's game may drive it
local function callerOk(t)
    local inv = GetInvokingResource()
    if not inv or inv == GetCurrentResourceName() then return true end
    local g = t.game and GG.Registry.Get(t.game)
    return g ~= nil and g.resource == inv
end

---------------------------------------------------------------------
-- Stakes in cents for a table's tier
---------------------------------------------------------------------
function Play.Stakes(t)
    local tier = t.tier and Config.Tiers[t.tier]
    if not tier then return nil end
    local M = GG.M
    local bb = M.ToCents(tier.bigBlind)
    return {
        tier = t.tier, currency = t.currency, kind = t.kind,
        smallBlind = M.ToCents(tier.smallBlind), bigBlind = bb,
        buyInMin = tier.buyInMin * bb, buyInMax = tier.buyInMax * bb,
        minBet = bb, maxBet = bb * Config.Pvd.MaxBetMultiplier,
        rake = GG.Rake.Rate(t),
    }
end

exports('GetStakes', function(tableId)
    local t = GG.Tables.Get(tableId)
    return t and Play.Stakes(t) or nil
end)

---------------------------------------------------------------------
-- Views: public part for everyone at the table, private part per seat
---------------------------------------------------------------------
local function send(t, src, seat)
    local v = Play.views[t.id]
    if not v then return end
    v.public._now = os.time() -- the client counts `deadline` down against the server clock
    TriggerClientEvent('grumpy-gambling:client:view', src, t.id, v.public, seat and v.private[seat] or nil, seat)
end

-- What the table UI shows in its header, added by the core so every game gets it
local function tableInfo(t)
    local tier = t.tier and Config.Tiers[t.tier]
    local g = t.game and GG.Registry.Get(t.game)
    return {
        label = t.label, game = g and g.label or t.game, kind = t.kind, currency = t.currency,
        tier = t.tier, tierLabel = tier and locale(tier.label) or nil, -- the rake rate is never sent to players
        smallBlind = tier and GG.M.ToCents(tier.smallBlind) or nil, bigBlind = tier and GG.M.ToCents(tier.bigBlind) or nil,
    }
end

function Play.PushView(tableId, public, private)
    local t = GG.Tables.Get(tableId)
    if not t or not callerOk(t) then return false end
    if type(public) ~= 'table' then return false end
    private = type(private) == 'table' and private or {}
    local priv = {}
    for k, v in pairs(private) do local seat = math.tointeger(k); if seat then priv[seat] = v end end
    local pub = {}
    for k, v in pairs(public) do pub[k] = v end
    pub._table = tableInfo(t)
    Play.views[t.id] = { public = pub, private = priv }
    for seat, occ in pairs(t.occupants) do if occ.src then send(t, occ.src, seat) end end
    return true
end
exports('PushView', Play.PushView)

-- A player who sits down mid-game sees the current view straight away
AddEventHandler('grumpy-gambling:server:seatTaken', function(tableId, _, seat, src)
    local t = GG.Tables.Get(tableId)
    if t and src then send(t, src, seat) end
end)

-- The table stopped: forget its view and clear it on the players' screens
AddEventHandler('grumpy-gambling:server:tableStopping', function(tableId)
    Play.views[tableId] = nil
end)

---------------------------------------------------------------------
-- Messages for the table feed (text comes already translated from the module)
---------------------------------------------------------------------
exports('TableMessage', function(tableId, src, text)
    local t = GG.Tables.Get(tableId)
    if not t or not callerOk(t) or type(text) ~= 'string' then return false end
    text = text:sub(1, 200)
    if src then
        local s = GG.Seats.bySrc[src]
        if not s or s.id ~= t.id then return false end
        TriggerClientEvent('grumpy-gambling:client:message', src, t.id, text)
    else
        for _, occ in pairs(t.occupants) do
            if occ.src then TriggerClientEvent('grumpy-gambling:client:message', occ.src, t.id, text) end
        end
    end
    return true
end)

---------------------------------------------------------------------
-- Seat cues (Config.Anim.Cues): a move, a win or a tell played on that seat's ped by every client near the table.
-- A move by an NPC may also get a line in the feed.
---------------------------------------------------------------------
local MOVES = { check = true, call = true, bet = true, raise = true, allin = true, fold = true }

function Play.Cue(t, seat, cue)
    if not Config.Anim.Enabled or not Config.Anim.Cues[cue] or not t.occupants[seat] then return false end
    TriggerClientEvent('grumpy-gambling:client:seatCue', -1, t.id, seat, cue)
    return true
end

exports('SeatCue', function(tableId, seat, cue)
    local t = GG.Tables.Get(tableId)
    seat = math.tointeger(seat)
    if not t or not seat or not callerOk(t) or type(cue) ~= 'string' then return false end
    local occ = t.occupants[seat]
    if occ and occ.npc and MOVES[cue] then GG.Npc.Say(t, seat, cue == 'bet' and 'raise' or cue) end
    return Play.Cue(t, seat, cue)
end)

-- After a settled hand: the pot winner(s) rake it in (PVP); at dealer games winners smile and big losers sulk
function Play.SettleCues(t, h, awards)
    local bb = h.bb
    for seat, s in pairs(h.seats) do
        if not s.departed then
            local res = (awards[seat] or 0) - s.contrib
            if h.kind == 'pvp' then
                if res > 0 then Play.Cue(t, seat, 'win')
                elseif res <= -15 * bb then Play.Cue(t, seat, 'despair') end
            elseif s.contrib > 0 then
                if res >= 5 * bb then Play.Cue(t, seat, 'cheer')
                elseif res > 0 then Play.Cue(t, seat, 'happy')
                elseif res < 0 and math.random() < 0.5 then Play.Cue(t, seat, 'sad') end
            end
        end
    end
end

-- A module stands a seat up (e.g. a player who keeps timing out)
exports('StandSeat', function(tableId, seat)
    local t = GG.Tables.Get(tableId)
    local occ = t and t.occupants[seat]
    if not occ or not callerOk(t) then return false end
    if occ.npc then return GG.Npc.Remove(t, seat) end
    return GG.Seats.Stand(occ.src, 'stood_by_game')
end)

---------------------------------------------------------------------
-- Player actions: the core checks who and how often; the game checks whether the move is legal
---------------------------------------------------------------------
RegisterNetEvent('grumpy-gambling:server:action', function(actionId, amount)
    local src = source
    if GG.Cooldown(src, 'action', 250) then return end
    if type(actionId) ~= 'string' or #actionId > 24 or not actionId:match('^[%w_]+$') then return end
    if amount ~= nil then
        amount = math.tointeger(tonumber(amount))
        if not amount or amount < 0 then return end
    end
    local s = GG.Seats.bySrc[src]
    local t = s and GG.Tables.Get(s.id)
    if not t or t.state ~= 'active' or not t.game then return end
    local occ = t.occupants[s.seat]
    if not occ or occ.src ~= src then return end
    TriggerEvent('grumpy-gambling:server:playerAction', t.id, t.game, s.seat, src, actionId, amount)
end)
