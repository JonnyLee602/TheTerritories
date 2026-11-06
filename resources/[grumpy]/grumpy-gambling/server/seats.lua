-- Sit / stand, one seat per player server-wide, setup choice, disconnects.
local Seats = { bySrc = {} }
GG.Seats = Seats

local function seatOf(src) return Seats.bySrc[src] end

-- Frees the seat a player holds. reason is a locale key shown to them (or nil for a quiet stand).
function Seats.Stand(src, reason, dropped)
    local s = seatOf(src)
    if not s then return false end
    Seats.bySrc[src] = nil
    local t = GG.Tables.Get(s.id)
    local cashed = 0
    if t and t.occupants[s.seat] and t.occupants[s.seat].src == src then
        local occ = t.occupants[s.seat]
        GG.Hands.SeatLeaving(t.id, s.seat)          -- bets already in an open hand stay there
        cashed = GG.Wallet.CashOut(t, s.seat, occ, dropped)
        t.occupants[s.seat] = nil
        GG.Tables.OnSeatLeft(t, s.seat, src)
    end
    if not dropped then
        TriggerClientEvent('grumpy-gambling:client:stood', src)
        if reason then GG.Notify(src, locale(reason), 'inform') end
        if cashed > 0 and t then
            GG.Notify(src, locale('chips_cashed_out', GG.M.Fmt(cashed), locale('currency_' .. t.currency)), 'success')
        end
    end
    return true
end

function Seats.StandAll(t, reason)
    for seat, occ in pairs(t.occupants) do
        if occ.npc then GG.Npc.Remove(t, seat) else Seats.Stand(occ.src, reason) end
    end
end

RegisterNetEvent('grumpy-gambling:server:sit', function(tableId, seat)
    local src = source
    local Player = GG.Core.Functions.GetPlayer(src)
    if not Player or GG.Cooldown(src, 'sit', 1500) then return end
    local t = GG.Tables.Get(tableId)
    seat = GG.Int(seat, 1, 12)
    if not t or not seat or not t.seats[seat] then return end
    if not t.enabled then return GG.Notify(src, locale('table_closed'), 'error') end
    if seatOf(src) then return GG.Notify(src, locale('already_seated'), 'error') end
    if t.occupants[seat] then return GG.Notify(src, locale('seat_taken'), 'error') end
    if Player.PlayerData.metadata and Player.PlayerData.metadata.isdead then return end

    local pos = GG.PlayerCoords(src)
    local x, y, z = GG.Tables.SeatWorld(t, seat)
    if not pos or #(pos - vector3(x, y, z)) > Config.ServerSeatDistance then
        return GG.Notify(src, locale('too_far'), 'error')
    end

    t.occupants[seat] = { src = src, cid = Player.PlayerData.citizenid, name = GG.CharName(src), stack = 0 }
    Seats.bySrc[src] = { id = t.id, seat = seat }
    TriggerClientEvent('grumpy-gambling:client:seated', src, t.id, seat)
    GG.Tables.OnSeatTaken(t, seat, src)
    if t.state == 'active' then GG.Wallet.Offer(src, t, t.occupants[seat]) end
end)

RegisterNetEvent('grumpy-gambling:server:stand', function()
    local src = source
    if GG.Cooldown(src, 'stand', 1000) then return end
    Seats.Stand(src, nil)
end)

-- The setup player reopens the picker (prompt while seated)
RegisterNetEvent('grumpy-gambling:server:requestSetup', function()
    local src = source
    if GG.Cooldown(src, 'setup', 1000) then return end
    local s = seatOf(src)
    local t = s and GG.Tables.Get(s.id)
    if not t or t.state ~= 'setup' or t.setupBy ~= src then return end
    TriggerClientEvent('grumpy-gambling:client:setup', src, GG.Tables.SetupOptions(t))
end)

RegisterNetEvent('grumpy-gambling:server:configure', function(gameId, tierId)
    local src = source
    if GG.Cooldown(src, 'configure', 1000) then return end
    local s = seatOf(src)
    local t = s and GG.Tables.Get(s.id)
    if not t or type(gameId) ~= 'string' or type(tierId) ~= 'string' then return end
    local ok, err = GG.Tables.Configure(t, src, gameId, tierId)
    if not ok then return GG.Notify(src, locale(err), 'error') end
    TriggerClientEvent('grumpy-gambling:client:setupClosed', src)
end)

AddEventHandler('playerDropped', function() Seats.Stand(source, nil, true) end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) Seats.Stand(src, nil) end)

-- Client asks for the full table list (on load / resource start)
GG.Core.Functions.CreateCallback('grumpy-gambling:server:sync', function(source, cb)
    local s = seatOf(source)
    cb({ tables = GG.Tables.PublicAll(), seat = s and { id = s.id, seat = s.seat } or nil })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Seats.bySrc) do TriggerClientEvent('grumpy-gambling:client:stood', src) end
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('GetSeat', function(src)
    local s = seatOf(src)
    return s and { tableId = s.id, seat = s.seat } or nil
end)

exports('GetSeated', function(tableId)
    local t = GG.Tables.Get(tableId)
    if not t then return nil end
    local list = {}
    for i = 1, #t.seats do
        local occ = t.occupants[i]
        if occ then list[#list + 1] = { seat = i, src = occ.src, cid = occ.cid, name = occ.name } end
    end
    return list
end)

exports('StandPlayer', function(src) return Seats.Stand(src, nil) end)
