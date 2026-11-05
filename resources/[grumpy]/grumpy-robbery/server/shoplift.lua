-- Shoplifting at admin-set shelf points. The server picks the item, times the attempt and rolls the catch.
-- rsg-stores stock is never changed: by default only items the shop sells with unlimited stock can be taken.

local SL = Config.Shoplift
local Pending = {}     -- [src] = { store, shelf, item, started }
local Cooldown = {}    -- [citizenid] = { [storeId] = os.time() }
local busy = {}

local blacklist = {}
for _, n in ipairs(SL.Blacklist) do blacklist[n] = true end

local function pickItem(store)
    local pool = {}
    for _, it in ipairs(store.items) do
        local def = RSGCore.Shared.Items[it.name]
        if def and not blacklist[it.name] and not def.unique and def.type ~= 'weapon'
            and it.price > 0 and it.price <= SL.MaxPrice
            and (it.stock == nil or SL.AllowLimitedStock) then
            pool[#pool + 1] = it.name
        end
    end
    return #pool > 0 and pool[math.random(#pool)] or nil
end

local function witnesses(src, coords)
    local mates = {}
    for _, id in ipairs(GR.Posse(src)) do mates[id] = true end
    local n = 0
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        if not mates[id] and #(GetEntityCoords(GetPlayerPed(id)) - coords) <= SL.WitnessRadius then n = n + 1 end
    end
    return n
end

RSGCore.Functions.CreateCallback('grumpy-robbery:server:shopliftStart', function(src, cb, storeId, shelf)
    storeId, shelf = tonumber(storeId), tonumber(shelf)
    local Player = RSGCore.Functions.GetPlayer(src)
    local store = storeId and GR.Stores[storeId]
    local point = store and shelf and store.shelves[shelf]
    if not SL.Enabled or not Player or not point then return cb(false) end
    local now = GetGameTimer()
    if busy[src] and now - busy[src] < 1500 then return cb(false) end
    busy[src] = now

    if Player.PlayerData.metadata.isdead or GR.Dist(src, point) > SL.Distance + 1.0 then return cb(false) end
    if GR.IsBeingRobbed(storeId) then return cb(false, locale('lift_busy')) end
    local cid = Player.PlayerData.citizenid
    local until_ = Cooldown[cid] and Cooldown[cid][storeId] or 0
    if until_ > os.time() then return cb(false, locale('lift_cooldown')) end

    local item = pickItem(store)
    if not item then return cb(false, locale('lift_nothing')) end
    Pending[src] = { store = storeId, shelf = shelf, item = item, started = now }
    cb(true)
end)

RegisterNetEvent('grumpy-robbery:server:shopliftFinish', function(clerkSees)
    local src = source
    local p = Pending[src]
    Pending[src] = nil
    local Player = RSGCore.Functions.GetPlayer(src)
    if not p or not Player then return end
    local store = GR.Stores[p.store]
    local point = store and store.shelves[p.shelf]
    if not point then return end
    if GetGameTimer() - p.started < SL.Time - 500 then return end
    if GR.Dist(src, point) > SL.Distance + 1.5 then return end

    local cid = Player.PlayerData.citizenid
    Cooldown[cid] = Cooldown[cid] or {}

    local chance = SL.BaseChance + (clerkSees == true and SL.ClerkSees or 0) + witnesses(src, point) * SL.PerWitness
    chance = math.min(SL.MaxChance, chance)
    if math.random(100) <= chance then
        Cooldown[cid][p.store] = os.time() + SL.CaughtCooldown
        GR.Notify(src, locale('lift_caught'), 'error')
        TriggerClientEvent('grumpy-robbery:client:clerkState', -1, p.store, 'shout', { thief = src })
        GR.Rep(src, Config.Reputation.shopliftCaught)
        if GR.Law() then
            exports['grumpy-law']:OpenIncident(src, {
                crime = 'shoplifting', coords = point, label = store.label, victimReports = SL.AlertLaw, succeeded = false,
            })
        elseif SL.AlertLaw then
            GR.AlertLaw(store.coords, locale('alert_shoplift', store.label))
        end
        TriggerEvent('grumpy-robbery:server:shopliftCaught', src, p.store)
        return
    end

    Cooldown[cid][p.store] = os.time() + SL.Cooldown
    if not exports['rsg-inventory']:CanAddItem(src, p.item, 1) then return GR.Notify(src, locale('lift_full'), 'error') end
    exports['rsg-inventory']:AddItem(src, p.item, 1, nil, nil, 'grumpy-robbery-shoplift')
    if GR.Law() and SL.AmbientWitnesses then
        -- the clerk missed it, but NPCs nearby might not have
        exports['grumpy-law']:OpenIncident(src, { crime = 'shoplifting', coords = point, label = store.label, succeeded = true })
    end
    GR.Notify(src, locale('lift_success', RSGCore.Shared.Items[p.item].label), 'success')
    TriggerEvent('grumpy-robbery:server:shoplifted', src, p.store, p.item)
end)

RegisterNetEvent('grumpy-robbery:server:shopliftCancel', function() Pending[source] = nil end)

AddEventHandler('playerDropped', function()
    Pending[source], busy[source] = nil, nil
end)
