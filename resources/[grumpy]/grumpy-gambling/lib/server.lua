-- Server wrappers for game modules: register a game, receive table events, and call the core.
-- Load order in a module: lib/init.lua, lib/cards.lua, lib/poker.lua, lib/betting.lua (as needed), lib/server.lua.
-- List this file under server_scripts only (it uses server natives and exports).

local CORE = GGLib.CoreResource
local function core() return exports[CORE] end

---------------------------------------------------------------------
-- Registration and events
---------------------------------------------------------------------
-- handlers (all optional): tableStarted(tableId, tier, currency), seatTaken(tableId, seat, src),
-- seatLeft(tableId, seat, src), stackChanged(tableId, seat, src, cents), action(tableId, seat, src, id, amount),
-- tableStopping(tableId, reason)
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
