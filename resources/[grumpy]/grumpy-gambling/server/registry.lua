-- Game module registry (DESIGN.md §11.1). Modules call exports['grumpy-gambling']:RegisterGame(def) on start.
-- Phase 1 stores and validates registrations so the game picker can list them; the hand API comes in phase 3.
local Registry = { games = {} }
GG.Registry = Registry

local function validModelList(models, kind)
    if models == nil then return true end
    if type(models) ~= 'table' then return false end
    for _, m in ipairs(models) do
        if type(m) ~= 'string' or not Models[m] or Models[m].kind ~= kind then return false end
    end
    return true
end

function Registry.Register(def, resource)
    if type(def) ~= 'table' then return false, 'definition must be a table' end
    local id = type(def.id) == 'string' and def.id:match('^[%w_%-]+$') and def.id:lower() or nil
    if not id or #id > 32 then return false, 'id must be letters, numbers, - or _ (max 32)' end
    if def.kind ~= 'pvp' and def.kind ~= 'pvd' then return false, 'kind must be pvp or pvd' end
    local minSeats = GG.Int(def.minSeats, 1, 12) or 1
    local maxSeats = GG.Int(def.maxSeats, minSeats, 12) or minSeats
    if not validModelList(def.models, def.kind) then return false, 'models must be known ' .. def.kind .. ' table models' end
    local existing = Registry.games[id]
    if existing and existing.resource ~= resource and GetResourceState(existing.resource) == 'started' then
        return false, ('id %s is already registered by %s'):format(id, existing.resource)
    end
    Registry.games[id] = {
        id = id,
        label = GG.Str(def.label, 40) or id,
        kind = def.kind,
        minSeats = minSeats,
        maxSeats = maxSeats,
        models = def.models,
        dealer = def.dealer == true,
        houseEdge = GG.Finite(def.houseEdge) and math.max(0, math.min(0.5, def.houseEdge)) or 0.0,
        maxPayout = GG.Finite(def.maxPayout) and math.max(1, math.min(100, def.maxPayout)) or nil,
        rules = type(def.rules) == 'table' and def.rules or {},
        resource = resource,
    }
    print(('^2[grumpy-gambling] game registered: %s (%s) by %s^7'):format(id, def.kind, resource))
    return true
end

function Registry.Get(id) return id and Registry.games[id] or nil end

-- Games that can run at a table: same kind, seat count fits, model allowed
function Registry.ForTable(t)
    local list = {}
    local seatCount = #(t.seats or {})
    for _, g in pairs(Registry.games) do
        local modelOk = not g.models
        if g.models then for _, m in ipairs(g.models) do if m == t.model then modelOk = true break end end end
        if g.kind == t.kind and modelOk and seatCount >= g.minSeats and GetResourceState(g.resource) == 'started' then
            list[#list + 1] = { id = g.id, label = g.label }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

exports('RegisterGame', function(def)
    local ok, err = Registry.Register(def, GetInvokingResource() or 'unknown')
    if not ok then print(('^1[grumpy-gambling] RegisterGame from %s refused: %s^7'):format(GetInvokingResource() or '?', err)) end
    return ok, err
end)

exports('GetGames', function()
    local list = {}
    for _, g in pairs(Registry.games) do list[#list + 1] = { id = g.id, label = g.label, kind = g.kind, resource = g.resource } end
    return list
end)

-- A module stopping takes its game off every table that runs it
AddEventHandler('onResourceStop', function(res)
    for id, g in pairs(Registry.games) do
        if g.resource == res then
            Registry.games[id] = nil
            if GG.Tables then GG.Tables.GameRemoved(id) end
        end
    end
end)
