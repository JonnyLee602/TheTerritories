-- NPC seats (DESIGN.md §8). An NPC occupies a seat like a player but has no client. It doesn't count as a real
-- player (the table resets when the last real player leaves). Its chips are created when it sits ('npc_mint') and
-- destroyed when it leaves ('npc_sink'): the free-NPC money the owner accepted, bounded later by the win cap.
-- Phase 3 ships the seat plumbing and the dev /ggbot command; phase 5 adds the seating rule, cap, brains, regulars.
local Npc = {}
GG.Npc = Npc
local M = GG.M

local function pick(list) return list[math.random(#list)] end

-- opts = { name?, model?, stack? (cents) }. Returns the occupant or nil, err.
function Npc.Seat(t, seat, opts)
    opts = opts or {}
    if t.state ~= 'active' or not t.tier then return nil, 'table_not_started' end
    if not t.seats[seat] or t.occupants[seat] then return nil, 'seat_taken' end
    local lim = GG.Wallet.Limits(t)
    local stack = opts.stack
    if not stack then
        local steps = (lim.max - lim.min) // lim.step
        stack = lim.min + math.random(0, steps) * lim.step
    end
    local cfg = Config.Npc
    local occ = {
        npc = true, cid = ('npc:%d:%d'):format(t.id, seat), name = opts.name or pick(cfg.Names),
        model = opts.model or pick(cfg.Models), stack = stack,
    }
    t.occupants[seat] = occ
    GG.DB.StackSet(occ.cid, t.id, t.currency, stack)
    GG.DB.Ledger({ kind = 'npc_mint', tableId = t.id, cid = occ.cid, currency = t.currency, amount = stack, note = occ.name })
    GG.Tables.OnSeatTaken(t, seat, nil)
    return occ
end

-- quiet = true when the table itself is closing (no seatLeft, no reset loop)
function Npc.Remove(t, seat, quiet)
    local occ = t.occupants[seat]
    if not occ or not occ.npc then return false end
    GG.Hands.SeatLeaving(t.id, seat)
    local amount = occ.stack - GG.Hands.Contributed(t.id, seat)
    GG.DB.StackDelete(occ.cid)
    if amount > 0 then
        GG.DB.Ledger({ kind = 'npc_sink', tableId = t.id, cid = occ.cid, currency = t.currency, amount = -amount, note = occ.name })
    end
    t.occupants[seat] = nil
    if quiet then GG.Tables.Sync(t) else GG.Tables.OnSeatLeft(t, seat, nil) end
    return true
end

function Npc.ClearTable(t, quiet)
    for seat, occ in pairs(t.occupants) do
        if occ.npc then Npc.Remove(t, seat, quiet) end
    end
end

function Npc.IsNpcCid(cid) return type(cid) == 'string' and cid:sub(1, 4) == 'npc:' end

-- Money an NPC won or had in a hand after it left: destroyed (nobody to pay)
function Npc.Sink(tableId, handId, cid, currency, amount, ledger)
    local e = { kind = 'npc_sink', tableId = tableId, handId = handId, cid = cid, currency = currency, amount = -amount }
    if ledger then ledger[#ledger + 1] = e else GG.DB.Ledger(e) end
end

---------------------------------------------------------------------
-- Dev: /ggbot [count | clear] seats NPCs at the table you're sitting at
---------------------------------------------------------------------
if Config.DevGames then
    GG.Core.Commands.Add('ggbot', 'Seat test NPCs at your table (dev)', { { name = 'count', help = 'number, or clear' } }, false,
        function(source, args)
            if not GG.IsAdmin(source) then return end
            local s = GG.Seats.bySrc[source]
            local t = s and GG.Tables.Get(s.id)
            if not t or t.state ~= 'active' then return GG.Notify(source, locale('dev_bot_sit_first'), 'error') end
            if args[1] == 'clear' then
                Npc.ClearTable(t)
                return GG.Notify(source, locale('dev_bot_cleared'), 'success')
            end
            local want, added = GG.Int(args[1] or 1, 1, 12) or 1, 0
            for seat = 1, #t.seats do
                if added >= want then break end
                if not t.occupants[seat] and Npc.Seat(t, seat) then added = added + 1 end
            end
            GG.Notify(source, locale('dev_bot_added', added), added > 0 and 'success' or 'error')
        end, Config.AdminPermission)
end

exports('SeatNpc', function(tableId, seat, opts)
    local t = GG.Tables.Get(tableId)
    if not t then return nil end
    local occ = Npc.Seat(t, seat, opts)
    return occ ~= nil
end)
