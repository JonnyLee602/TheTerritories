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
    -- every player sees their own chips (stack minus what's in the current hand), whatever the game shows
    local priv = seat and v.private[seat] or nil
    local occ = seat and t.occupants[seat]
    if occ and occ.src == src then
        local copy = {}
        for k, val in pairs(priv or {}) do copy[k] = val end
        copy._chips = math.max(0, (occ.stack or 0) - GG.Hands.Contributed(t.id, seat))
        priv = copy
    end
    TriggerClientEvent('grumpy-gambling:client:view', src, t.id, v.public, priv, seat)
end

-- A player's chips changed outside a game move (buy-in, top-up): resend their view
function Play.Resend(t, seat)
    local occ = t.occupants[seat]
    if occ and occ.src then send(t, occ.src, seat) end
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

---------------------------------------------------------------------
-- Game animations and table props (cards). Only players near the table get them; a client that walks up later asks
-- for the current props when it spawns the table. anim = { dict, clip, ms, fem? (female dict) }.
---------------------------------------------------------------------
Play.props = {}
Play.pots = {}   -- [tableId] = true while a hand has bets in it

local function nearby(t)
    local out, r = {}, Config.SpawnDistance + 10.0
    local here = vector3(t.x, t.y, t.z)
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local pos = src and GG.PlayerCoords(src)
        if pos and #(pos - here) <= r then out[#out + 1] = src end
    end
    return out
end
Play.Nearby = nearby

local function toNearby(t, event, ...)
    for _, src in ipairs(nearby(t)) do TriggerClientEvent(event, src, ...) end
end

local function animDef(a)
    if type(a) ~= 'table' or type(a.dict) ~= 'string' or type(a.clip) ~= 'string' then return nil end
    return { dict = a.dict:sub(1, 96), fem = type(a.fem) == 'string' and a.fem:sub(1, 96) or nil, clip = a.clip:sub(1, 64),
        ms = math.max(100, math.min(15000, math.tointeger(tonumber(a.ms)) or 2000)) }
end

exports('SeatAnim', function(tableId, seat, a)
    local t = GG.Tables.Get(tableId)
    seat = math.tointeger(seat)
    local def = animDef(a)
    if not t or not seat or not def or not callerOk(t) or not t.occupants[seat] then return false end
    toNearby(t, 'grumpy-gambling:client:seatAnim', t.id, seat, def)
    return true
end)

exports('DealerAnim', function(tableId, a)
    local t = GG.Tables.Get(tableId)
    local def = animDef(a)
    if not t or t.kind ~= 'pvd' or not def or not callerOk(t) then return false end
    toNearby(t, 'grumpy-gambling:client:dealerAnim', t.id, def)
    return true
end)

local RANKS = { ['2'] = true, ['3'] = true, ['4'] = true, ['5'] = true, ['6'] = true, ['7'] = true, ['8'] = true, ['9'] = true,
    T = true, J = true, Q = true, K = true, A = true }
local SUITS = { c = true, d = true, h = true, s = true }
local function num(v, lim) v = tonumber(v) or 0.0; if v ~= v then v = 0.0 end return math.max(-lim, math.min(lim, v)) + 0.0 end

-- list = { { key, at = 'seat' | 'dealer' | 'table', seat?, card = { r, s, down? } | model = 'name', x (forward),
--            y (right), z (up), h (turn) }, ... }. Replaces the table's props; send {} to clear.
function Play.SetProps(t, list)
    local clean = {}
    for _, p in ipairs(type(list) == 'table' and list or {}) do
        if #clean >= Config.Cards.Max then break end
        if type(p) == 'table' and type(p.key) == 'string' and (p.at == 'seat' or p.at == 'dealer' or p.at == 'table') then
            local item = { key = p.key:sub(1, 32), at = p.at, seat = math.tointeger(p.seat),
                x = num(p.x, 3), y = num(p.y, 3), z = num(p.z, 1), h = num(p.h, 360) }
            if type(p.card) == 'table' and p.card.down == true then
                -- face down: clients get a card back, never which card it is (nothing to read from the prop)
                item.card = { down = true }
            elseif type(p.card) == 'table' and RANKS[p.card.r] and SUITS[p.card.s] then
                item.card = { r = p.card.r, s = p.card.s }
            elseif type(p.model) == 'string' then
                item.model = p.model:sub(1, 64)
            end
            if (item.card or item.model) and (item.at ~= 'seat' or (item.seat and t.seats[item.seat])) then clean[#clean + 1] = item end
        end
    end
    Play.props[t.id] = clean
    toNearby(t, 'grumpy-gambling:client:props', t.id, Play.TableProps(t))
    return true
end

-- What clients get: the game's props plus the pot
function Play.TableProps(t)
    local list = Play.props[t.id] or {}
    if not Play.pots[t.id] or not Config.Pot.Enabled then return list end
    local out = {}
    for i, p in ipairs(list) do out[i] = p end
    local off = t.kind == 'pvd' and Config.Pot.Dealer or Config.Pot.Table
    out[#out + 1] = { key = '_pot', at = t.kind == 'pvd' and 'dealer' or 'table', model = Config.Pot.Model,
        x = off.x + 0.0, y = off.y + 0.0, z = 0.0, h = 0.0 }
    return out
end

-- Called by hands.lua: the first bet of a hand puts the pot on the table; settling or cancelling takes it away
-- to = where the chips go when the pot is taken off: a seat number (the winner) or 'dealer' (the house kept it)
function Play.SetPot(t, on, to)
    on = on == true
    if (Play.pots[t.id] == true) == on then return end
    Play.pots[t.id] = on or nil
    toNearby(t, 'grumpy-gambling:client:props', t.id, Play.TableProps(t), (not on and to) and { potTo = to } or nil)
end

exports('SetProps', function(tableId, list)
    local t = GG.Tables.Get(tableId)
    if not t or not callerOk(t) then return false end
    return Play.SetProps(t, list)
end)

GG.Core.Functions.CreateCallback('grumpy-gambling:server:props', function(source, cb, tableId)
    local t = GG.Tables.Get(tableId)
    cb(t and Play.TableProps(t) or {})
end)

AddEventHandler('grumpy-gambling:server:tableStopping', function(tableId)
    local t = GG.Tables.Get(tableId)
    if t then Play.pots[t.id] = nil end
    if t and Play.props[t.id] then Play.SetProps(t, {}) end
end)

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
    occ.acted = true -- took part in this hand (Seats.HandClosed counts hands without a move)
    TriggerEvent('grumpy-gambling:server:playerAction', t.id, t.game, s.seat, src, actionId, amount)
end)
