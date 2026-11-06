-- The table view pushed by the game (public + this player's private part) and the table feed.
-- Phase 4 draws it in the NUI. Until then, with Config.DevGames on, it's printed to F8 and actions are typed with
--   /gga <action> [amount in dollars]      e.g. /gga call, /gga raise 0.40, /gga bet 0.20, /gga fold
GGC.View = nil      -- { tableId, public, private, seat }
GGC.Feed = {}

RegisterNetEvent('grumpy-gambling:client:view', function(tableId, public, private, seat)
    if not GGC.Seat or GGC.Seat.id ~= tableId then return end
    GGC.View = { tableId = tableId, public = public, private = private, seat = seat }
    TriggerEvent('grumpy-gambling:client:viewUpdated', GGC.View)
    if Config.DevGames then
        print(('[grumpy-gambling] view %s'):format(json.encode(GGC.View)))
        local acts = private and private.actions
        if type(acts) == 'table' and #acts > 0 then
            local parts = {}
            for _, a in ipairs(acts) do
                if a.min and a.max then
                    parts[#parts + 1] = ('%s %s–%s'):format(a.id, GGLibFmt(a.min), GGLibFmt(a.max))
                elseif a.amount then
                    parts[#parts + 1] = ('%s %s'):format(a.id, GGLibFmt(a.amount))
                else
                    parts[#parts + 1] = a.id
                end
            end
            GGC.Notify(locale('dev_your_turn', table.concat(parts, ' · ')), 'inform', Config.DevNotify.TurnMs)
        end
    end
end)

RegisterNetEvent('grumpy-gambling:client:message', function(tableId, text)
    if not GGC.Seat or GGC.Seat.id ~= tableId or type(text) ~= 'string' then return end
    GGC.Feed[#GGC.Feed + 1] = text
    if #GGC.Feed > 30 then table.remove(GGC.Feed, 1) end
    TriggerEvent('grumpy-gambling:client:feed', text)
    if Config.DevGames then GGC.Notify(text, 'inform', Config.DevNotify.FeedMs) end
end)

RegisterNetEvent('grumpy-gambling:client:stood', function()
    GGC.View = nil
    GGC.Feed = {}
end)

function GGLibFmt(c)
    c = math.floor(tonumber(c) or 0)
    return ('$%d.%02d'):format(c // 100, c % 100)
end

-- Dev only: act in a hand by typing (the NUI action bar replaces this in phase 4)
if Config.DevGames then
    RegisterCommand('gga', function(_, args)
        local id = args[1]
        if not id then return end
        local cents
        if args[2] then
            local n = tonumber(args[2])
            if n then cents = math.floor(n * 100 + 0.5) end
        end
        TriggerServerEvent('grumpy-gambling:server:action', id, cents)
    end, false)
end
