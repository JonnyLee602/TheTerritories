-- grumpy-gambling module library (DESIGN.md §4.1, §11). Game modules load these files with
--   shared_scripts { '@grumpy-gambling/lib/init.lua', '@grumpy-gambling/lib/cards.lua', ... }
-- They run inside the module's own Lua VM: game state stays there, and anything touching money goes through the
-- core's exports (lib/server.lua). Amounts are integer cents.
GGLib = GGLib or {}
GGLib.Version = '0.5.0'
GGLib.CoreResource = 'grumpy-gambling'
-- IsDuplicityVersion() is truthy on the server but not always the boolean `true` (it can be 1), so test truthiness
if IsDuplicityVersion then
    local d = IsDuplicityVersion()
    GGLib.IsServer = d ~= nil and d ~= false and d ~= 0
else
    GGLib.IsServer = true
end

-- dollars <-> cents and display, the same rules as the core
function GGLib.Cents(dollars)
    local n = tonumber(dollars)
    if not n or n ~= n or n == math.huge or n < 0 then return nil end
    return math.tointeger(math.floor(n * 100 + 0.5))
end

function GGLib.Fmt(c)
    c = math.tointeger(c) or math.floor(c or 0)
    local sign = c < 0 and '-' or ''
    c = math.abs(c)
    return ('%s$%d.%02d'):format(sign, c // 100, c % 100)
end

function GGLib.Shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end
