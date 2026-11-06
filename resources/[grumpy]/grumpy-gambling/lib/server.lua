-- Server wrappers for game modules: register a game, receive table events, and call the core.
-- Load order in a module: lib/init.lua, lib/cards.lua, lib/poker.lua, lib/betting.lua, lib/npc_brain.lua (as needed),
-- lib/server.lua.
-- List this file under server_scripts only (it uses server natives and exports).

local CORE = GGLib.CoreResource
local function core() return exports[CORE] end

---------------------------------------------------------------------
-- Registration and events
---------------------------------------------------------------------
-- handlers (all optional): tableStarted(tableId, tier, currency), seatTaken(tableId, seat, src),
-- seatLeft(tableId, seat, src), stackChanged(tableId, seat, src, cents), action(tableId, seat, src, id, amount),
-- tableStopping(tableId, reason), callOut(tableId, npcSeat, src) (a player accuses a back-room NPC of cheating:
-- answer with GGLib.ResolveCallOut)
function GGLib.RegisterGame(def, handlers)
    GGLib.Game = def
    local function register()
        local ok, res, err = pcall(function() return core():RegisterGame(def) end)
        if not ok or not res then
            print(('^1[%s] RegisterGame(%s) failed: %s^7'):format(GetCurrentResourceName(), def.id, tostring(err or res)))
            return false
        end
        return true
    end
    local function on(event, fn)
        if not fn then return end
        AddEventHandler('grumpy-gambling:server:' .. event, function(tableId, gameId, ...)
            if gameId == def.id then fn(tableId, ...) end
        end)
    end
    on('tableStarted', handlers.tableStarted)
    on('seatTaken', handlers.seatTaken)
    on('seatLeft', handlers.seatLeft)
    on('stackChanged', handlers.stackChanged)
    on('playerAction', handlers.action)
    on('tableStopping', handlers.tableStopping)
    on('playerCallOut', handlers.callOut)
    -- register now if the core is up, and again whenever the core (re)starts
    AddEventHandler('grumpy-gambling:server:ready', register)
    if GetResourceState(CORE) == 'started' then
        local ok, ready = pcall(function() return core():IsReady() end)
        if ok and ready then register() end
    end
end

---------------------------------------------------------------------
-- Core calls (cents). See the core's DOCS.md for errors.
---------------------------------------------------------------------
function GGLib.BeginHand(tableId) return core():BeginHand(tableId) end
function GGLib.Bet(handId, seat, cents) return core():Bet(handId, seat, cents) end
function GGLib.Return(handId, seat, cents) return core():Return(handId, seat, cents) end
function GGLib.SetRakeable(handId, on) return core():SetRakeable(handId, on) end
function GGLib.Settle(handId, result) return core():Settle(handId, result) end
function GGLib.Cancel(handId, reason) return core():CancelHand(handId, reason) end
function GGLib.Hand(handId) return core():GetHand(handId) end
function GGLib.Seats(tableId) return core():GetSeats(tableId) or {} end
function GGLib.Table(tableId) return core():GetTable(tableId) end
function GGLib.Stakes(tableId) return core():GetStakes(tableId) end
function GGLib.Stand(tableId, seat) return core():StandSeat(tableId, seat) end

---------------------------------------------------------------------
-- NPCs (DESIGN.md §8). Seats with npc = true in GGLib.Seats are NPCs; the core seats and removes them.
---------------------------------------------------------------------
-- The NPC's personality numbers for lib/npc_brain.lua (tier, drunk and tilt already applied), or nil
function GGLib.NpcProfile(tableId, seat) return core():GetNpc(tableId, seat) end

-- Tell the core what an NPC just did: 'strong' / 'bluff' (may show a tell in the world), 'sleight' (a cardsharp
-- cheated), or a move id ('raise', 'allin', 'fold', 'call', 'check') for a chance of a chatter line
function GGLib.NpcEvent(tableId, seat, event) return core():NpcEvent(tableId, seat, event) end

-- Answer a call-out: caught = true if that NPC cheated in this hand (cancel or settle the hand yourself first)
function GGLib.ResolveCallOut(tableId, seat, caught) return core():ResolveCallOut(tableId, seat, caught) end

-- Poker convenience: gets the profile, runs GGLib.Brain.Decide(ctx) and reports a possible tell.
-- ctx as in Brain.Decide (persona is filled in). Returns action, amount, meta.
function GGLib.NpcDecide(tableId, seat, ctx)
    ctx.persona = ctx.persona or GGLib.NpcProfile(tableId, seat)
    local action, amount, meta = GGLib.Brain.Decide(ctx)
    if meta.bluff then meta.told = GGLib.NpcEvent(tableId, seat, 'bluff')
    elseif meta.strong and action ~= 'fold' then meta.told = GGLib.NpcEvent(tableId, seat, 'strong') end
    return action, amount, meta
end

-- An NPC's whole poker turn: it decides at once (so a tell plays while it "thinks"), then after its think time
-- calls act(action, amount). `key` is the timer key (scheduling it again replaces the turn).
function GGLib.NpcTurn(key, tableId, seat, ctx, act)
    local action, amount, meta = GGLib.NpcDecide(tableId, seat, ctx)
    local ms = GGLib.Brain.ThinkMs(ctx.persona, meta.strength)
    if meta.told then ms = math.max(ms, 3200) end -- let the tell finish before the move's own clip
    GGLib.After(key, ms, function() act(action, amount) end)
end

-- Plays a clip on a seat for everyone near the table (Config.Anim.Cues): moves ('check', 'call', 'bet', 'raise',
-- 'allin', 'fold', 'blind'), or 'happy' / 'sad' / 'cheer' / 'despair'. Call it for every move, players and NPCs:
-- NPC moves may also get a chatter line. Pot wins and buy-ins are cued by the core.
function GGLib.Cue(tableId, seat, cue) return core():SeatCue(tableId, seat, cue) end

-- Animations and props, seen by players near the table (DESIGN.md §10). anim = { dict, clip, ms, fem? }: fem is the
-- female dict to use for women where the game has one. Props: see the core's DOCS.md (SetProps).
function GGLib.SeatAnim(tableId, seat, anim) return core():SeatAnim(tableId, seat, anim) end
function GGLib.DealerAnim(tableId, anim) return core():DealerAnim(tableId, anim) end
function GGLib.Props(tableId, list) return core():SetProps(tableId, list or {}) end

-- Sends the table view to everyone seated: public for all, private[seat] only to that seat's player (hole cards,
-- the actions they can take). See DESIGN.md §11.4 for the shape.
function GGLib.View(tableId, public, private) return core():PushView(tableId, public, private or {}) end

-- Short line for the table's feed, to one seated player or the whole table (src = nil). Text is the module's own
-- (already translated with its locale).
function GGLib.Say(tableId, src, text) return core():TableMessage(tableId, src, text) end

---------------------------------------------------------------------
-- Timers: one pending callback per key (scheduling a key again replaces it)
---------------------------------------------------------------------
local timers, serial = {}, 0

function GGLib.After(key, ms, fn)
    serial = serial + 1
    local token = serial
    timers[key] = token
    SetTimeout(ms, function()
        if timers[key] ~= token then return end
        timers[key] = nil
        local ok, err = pcall(fn)
        if not ok then print(('^1[%s] timer %s: %s^7'):format(GetCurrentResourceName(), tostring(key), tostring(err))) end
    end)
end

function GGLib.CancelTimer(key) timers[key] = nil end

function GGLib.CancelTimers(prefix)
    for key in pairs(timers) do
        if tostring(key):sub(1, #prefix) == prefix then timers[key] = nil end
    end
end
