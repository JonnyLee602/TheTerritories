-- Whose turn: a marker floating over the seat that's acting (players and NPCs), for the players seated at that
-- table (Config.TurnMarker). Not over your own seat: the table panel tells you when it's yours.
local M = Config.TurnMarker
local lastTurn, lastTable = nil, nil

-- Everyone this client animates at the table (NPC players, the dealer) looks at whoever is acting; the actor looks
-- at their own cards; with nobody acting they watch the dealer (or the middle of a card table).
local function lookAt(tableId, turn)
    if not Config.Motion.LookAt then return end
    local t = GGC.Tables[tableId]
    local npcs, dealer = GGC.TablePeds(tableId)
    if not t or not npcs then return end
    local tx, ty, tz
    if turn and t.seats[turn] then
        local x, y, z = GGC.SeatWorld(t, turn)
        tx, ty, tz = x, y, z + (t.sitZ or 0.5) + 0.65
    elseif t.kind == 'pvd' and dealer and DoesEntityExist(dealer) then
        local c = GetEntityCoords(dealer)
        tx, ty, tz = c.x, c.y, c.z + 0.6
    else
        tx, ty, tz = t.x, t.y, t.z + (t.cardHeight or Config.Cards.Height)
    end
    for seat, ped in pairs(npcs) do
        if seat == turn then
            local x, y, z, h = GGC.SeatWorld(t, seat)
            local r = math.rad(h)
            TaskLookAtCoord(ped, x - math.sin(r) * 0.6, y + math.cos(r) * 0.6, z + (t.cardHeight or Config.Cards.Height), -1, 2048, 3, false)
        else
            TaskLookAtCoord(ped, tx, ty, tz, -1, 2048, 3, false)
        end
    end
    if dealer and DoesEntityExist(dealer) and turn then TaskLookAtCoord(dealer, tx, ty, tz, -1, 2048, 3, false) end
end

CreateThread(function()
    while true do
        local v = GGC.View
        local turn = v and v.public and v.public.turn
        local t = v and GGC.Tables[v.tableId]
        if v and (turn ~= lastTurn or v.tableId ~= lastTable) then
            lastTurn, lastTable = turn, v.tableId
            lookAt(v.tableId, turn)
        elseif not v then
            lastTurn, lastTable = nil, nil
        end
        if M.Enabled and t and turn and turn ~= v.seat and t.seats and t.seats[turn] then
            local x, y, z = GGC.SeatWorld(t, turn)
            if x then
                local c = M.Color
                Citizen.InvokeNative(0x2A32FAA57B937173, M.Type, x, y, z + (t.sitZ or 0.5) + M.Height, -- DRAW_MARKER
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, M.Scale, M.Scale, M.Scale, c[1], c[2], c[3], c[4],
                    M.Bob, true, 2, false, 0, 0, false)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
