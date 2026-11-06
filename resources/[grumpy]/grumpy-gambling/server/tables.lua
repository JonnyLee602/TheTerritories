-- Table registry, persistence and lifecycle (DESIGN.md §5).
-- States: 'empty' -> 'setup' (first real player picks game + tier) -> 'active' -> back to 'empty' when the last
-- real player leaves. Micro tables are locked to the micro tier.
local Tables = { byId = {}, modelOverrides = {} }
GG.Tables = Tables

local json = json

---------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------
local function copyOffsets(list)
    if type(list) ~= 'table' then return nil end
    local out = {}
    for i, o in ipairs(list) do
        out[i] = { x = tonumber(o.x) or 0.0, y = tonumber(o.y) or 0.0, z = tonumber(o.z) or 0.0, h = tonumber(o.h) or 0.0 }
    end
    return out
end

local function copyOffset(o)
    if type(o) ~= 'table' then return nil end
    return { x = tonumber(o.x) or 0.0, y = tonumber(o.y) or 0.0, z = tonumber(o.z) or 0.0, h = tonumber(o.h) or 0.0 }
end

-- Effective profile: config model, then a database override for the model, then the table's own calibration
local function applyProfile(t)
    local base = Models[t.model] or {}
    local mo = Tables.modelOverrides[t.model] or {}
    t.chair = base.chair
    t.chipForward = base.chipForward
    t.chipHeight = base.chipHeight
    t.sitZ = base.sitZ or 0.5
    t.chairYaw = base.chairYaw or 0.0
    t.seats = copyOffsets(t.seatsOverride) or copyOffsets(mo.seats) or copyOffsets(base.seats) or {}
    if t.kind == 'pvd' then
        t.dealer = copyOffset(t.dealerOverride) or copyOffset(mo.dealer) or copyOffset(base.dealer)
    else
        t.dealer = nil
    end
end

local function decode(s)
    if type(s) ~= 'string' or s == '' then return nil end
    local ok, v = pcall(json.decode, s)
    return ok and v or nil
end

local function fromRow(r)
    local t = {
        id = r.id, label = r.label, kind = r.kind, source = r.source, model = r.model,
        bound = r.bound == 1 or r.bound == true,
        x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), h = Geo.Wrap(r.h),
        currency = r.currency, fixedTier = r.fixed_tier, businessId = r.business_id, ownerCid = r.owner_cid,
        seatsOverride = decode(r.seats), dealerOverride = decode(r.dealer), settings = decode(r.settings) or {},
        enabled = r.enabled == 1 or r.enabled == true,
        state = 'empty', game = nil, tier = nil, occupants = {}, setupBy = nil, setupUntil = nil, version = 0,
    }
    if t.fixedTier and not Config.Tiers[t.fixedTier] then t.fixedTier = nil end
    applyProfile(t)
    return t
end

---------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------
function Tables.Get(id)
    id = math.tointeger(tonumber(id))
    return id and Tables.byId[id] or nil
end

function Tables.Count()
    local n = 0
    for _ in pairs(Tables.byId) do n = n + 1 end
    return n
end

function Tables.Origin(t) return { x = t.x, y = t.y, z = t.z } end

-- World position of a seat's chair (floor) and the heading a seated player faces
function Tables.SeatWorld(t, i)
    local s = t.seats[i]
    if not s then return nil end
    return Geo.ToWorld(Tables.Origin(t), t.h, s)
end

-- Real players only: NPCs never keep a table open
function Tables.RealCount(t)
    local n = 0
    for _, occ in pairs(t.occupants) do if not occ.npc then n = n + 1 end end
    return n
end

function Tables.MicroCount()
    local n = 0
    for _, t in pairs(Tables.byId) do if t.source == 'micro' then n = n + 1 end end
    return n
end

local function gameLabel(t)
    local g = t.game and GG.Registry.Get(t.game)
    return g and g.label or nil
end

function Tables.Public(t)
    local occupied, chips, npc, npcOutfit = {}, {}, {}, {}
    for i = 1, #t.seats do
        local occ = t.occupants[i]
        occupied[i] = occ ~= nil
        chips[i] = occ ~= nil and (occ.stack or 0) > 0
        npc[i] = occ ~= nil and occ.npc and occ.model or false
        npcOutfit[i] = occ ~= nil and occ.npc and occ.outfit or false -- every client shows the same outfit
    end
    return {
        id = t.id, label = t.label, kind = t.kind, source = t.source, model = t.model, bound = t.bound,
        x = t.x, y = t.y, z = t.z, h = t.h, currency = t.currency, fixedTier = t.fixedTier, enabled = t.enabled,
        seats = t.seats, dealer = t.dealer, chair = t.chair, sitZ = t.sitZ, chairYaw = t.chairYaw,
        chipForward = t.chipForward, chipHeight = t.chipHeight,
        state = t.state, game = t.game, gameLabel = gameLabel(t), tier = t.tier, occupied = occupied, chips = chips, npc = npc,
        npcOutfit = npcOutfit, usable = (Tables.Usable(t)), businessId = t.businessId,
        version = t.version,
    }
end

function Tables.PublicAll()
    local list = {}
    for _, t in pairs(Tables.byId) do list[#list + 1] = Tables.Public(t) end
    return list
end

function Tables.Sync(t)
    t.version = t.version + 1
    TriggerClientEvent('grumpy-gambling:client:table', -1, Tables.Public(t))
end

local function notifyTable(t, msg, ntype)
    for _, occ in pairs(t.occupants) do if occ.src then GG.Notify(occ.src, msg, ntype) end end
end
Tables.NotifyTable = notifyTable

---------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------
function Tables.Load()
    Tables.byId = {}
    for _, r in ipairs(MySQL.query.await('SELECT model, data FROM grumpy_gambling_models') or {}) do
        local d = decode(r.data)
        if d and Models[r.model] then Tables.modelOverrides[r.model] = d end
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM grumpy_gambling_tables') or {}) do
        if Models[r.model] then
            Tables.byId[r.id] = fromRow(r)
        else
            print(('^3[grumpy-gambling] table %d skipped: model %s has no profile in shared/models.lua^7'):format(r.id, r.model))
        end
    end
end
GG.AfterLoad(Tables.Load)

function Tables.Insert(d, src)
    local Player = GG.Core.Functions.GetPlayer(src)
    local id = MySQL.insert.await([[INSERT INTO grumpy_gambling_tables
        (label, kind, source, model, bound, x, y, z, h, currency, fixed_tier, business_id, owner_cid, settings, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        d.label, d.kind, d.source, d.model, d.bound and 1 or 0, d.x, d.y, d.z, d.h, d.currency, d.fixedTier,
        d.businessId, d.ownerCid, d.settings and json.encode(d.settings) or nil,
        Player and Player.PlayerData.citizenid or nil,
    })
    if not id then return nil end
    local row = MySQL.single.await('SELECT * FROM grumpy_gambling_tables WHERE id = ?', { id })
    if not row then return nil end
    local t = fromRow(row)
    Tables.byId[t.id] = t
    Tables.Sync(t)
    return t
end

function Tables.SavePlacement(t)
    MySQL.update.await('UPDATE grumpy_gambling_tables SET x = ?, y = ?, z = ?, h = ? WHERE id = ?', { t.x, t.y, t.z, t.h, t.id })
end

function Tables.SaveMeta(t)
    MySQL.update.await('UPDATE grumpy_gambling_tables SET label = ?, enabled = ? WHERE id = ?', { t.label, t.enabled and 1 or 0, t.id })
end

function Tables.SaveSettings(t)
    MySQL.update.await('UPDATE grumpy_gambling_tables SET settings = ? WHERE id = ?', { json.encode(t.settings or {}), t.id })
end

-- Can players sit and play? (closed by an admin or its owner, its owner lost the business, or it's out of range)
function Tables.Usable(t)
    if not t.enabled then return false, 'table_closed' end
    local s = t.settings or {}
    if s.orphaned then return false, 'biz_table_orphaned' end
    if s.outOfRange then return false, 'biz_table_out_of_range' end
    -- a dealer table whose box can't cover even the lowest tier can't open
    if t.source == 'business' and t.kind == 'pvd' and t.state == 'empty' and #Tables.AllowedTiers(t) == 0 then
        return false, 'biz_table_unfunded'
    end
    return true
end

function Tables.SaveCalibration(t)
    MySQL.update.await('UPDATE grumpy_gambling_tables SET seats = ?, dealer = ? WHERE id = ?', {
        t.seatsOverride and json.encode(t.seatsOverride) or nil,
        t.dealerOverride and json.encode(t.dealerOverride) or nil,
        t.id,
    })
    applyProfile(t)
end

function Tables.SaveModelOverride(model, data, src)
    local Player = GG.Core.Functions.GetPlayer(src)
    if data then
        MySQL.query.await([[INSERT INTO grumpy_gambling_models (model, data, updated_by) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)]],
            { model, json.encode(data), Player and Player.PlayerData.citizenid or nil })
    else
        MySQL.query.await('DELETE FROM grumpy_gambling_models WHERE model = ?', { model })
    end
    Tables.modelOverrides[model] = data
    for _, t in pairs(Tables.byId) do
        if t.model == model then applyProfile(t); Tables.Sync(t) end
    end
end

function Tables.Delete(t)
    -- business tables are packed up (the box and the item go back to their owner)
    if t.source == 'business' and GG.Biz and not t.packing then return GG.Biz.PackUp(t, nil, 'admin') end
    GG.Seats.StandAll(t, 'table_removed')
    MySQL.query.await('DELETE FROM grumpy_gambling_tables WHERE id = ?', { t.id })
    Tables.byId[t.id] = nil
    TriggerClientEvent('grumpy-gambling:client:removeTable', -1, t.id)
end

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------
-- Tiers this table may offer, in order
function Tables.AllowedTiers(t)
    local list = {}
    for id, tier in pairs(Config.Tiers) do
        local ok
        if t.fixedTier then
            ok = id == t.fixedTier
        else
            ok = tier.choosable and (t.currency ~= 'bloodmoney' or tier.bloodmoney)
        end
        if ok and t.source == 'business' and GG.Biz then ok = GG.Biz.TierAllowed(t, id, tier) end
        if ok then
            list[#list + 1] = {
                id = id, label = locale(tier.label), stage = tier.stage, order = tier.order,
                smallBlind = tier.smallBlind, bigBlind = tier.bigBlind,
                buyInMin = tier.buyInMin * tier.bigBlind, buyInMax = tier.buyInMax * tier.bigBlind,
            }
        end
    end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

function Tables.SetupOptions(t)
    return {
        tableId = t.id, label = t.label, kind = t.kind, currency = t.currency,
        games = GG.Registry.ForTable(t), tiers = Tables.AllowedTiers(t), fixedTier = t.fixedTier,
        maxBetMultiplier = Config.Pvd.MaxBetMultiplier,
        seconds = math.max(0, (t.setupUntil or os.time()) - os.time()),
    }
end

local function startSetup(t, src)
    t.state = 'setup'
    t.game, t.tier = nil, nil
    t.setupBy = src
    t.setupUntil = os.time() + Config.SetupTimeoutSeconds
    TriggerClientEvent('grumpy-gambling:client:setup', src, Tables.SetupOptions(t))
end

-- Back to an empty table (tier and game are forgotten; micro tables keep their fixed tier)
function Tables.Reset(t, reason)
    local h = GG.Hands and GG.Hands.ForTable(t.id)
    if h then GG.Hands.Cancel(h.id, 'table_stopped') end
    if GG.Npc then GG.Npc.ClearTable(t, true) end -- NPCs leave with the last real player
    if t.state == 'active' and t.game then
        TriggerEvent('grumpy-gambling:server:tableStopping', t.id, t.game, reason or 'empty')
    end
    t.state = 'empty'
    t.game, t.tier = nil, nil
    t.setupBy, t.setupUntil = nil, nil
    Tables.Sync(t)
end

function Tables.OnSeatTaken(t, seat, src)
    if t.state == 'empty' then
        startSetup(t, src)
    elseif t.state == 'active' then
        TriggerEvent('grumpy-gambling:server:seatTaken', t.id, t.game, seat, src)
    end
    Tables.Sync(t)
end

-- First seated real player other than `except`
local function anotherOccupant(t, except)
    for i = 1, #t.seats do
        local occ = t.occupants[i]
        if occ and occ.src and occ.src ~= except then return occ.src end
    end
    return nil
end

function Tables.OnSeatLeft(t, seat, src)
    if t.state == 'active' then
        TriggerEvent('grumpy-gambling:server:seatLeft', t.id, t.game, seat, src)
    end
    if Tables.RealCount(t) == 0 then
        Tables.Reset(t, 'empty')
        return
    end
    if t.state == 'setup' and t.setupBy == src then
        startSetup(t, anotherOccupant(t, src))
    end
    Tables.Sync(t)
end

function Tables.Configure(t, src, gameId, tierId)
    if t.state ~= 'setup' or t.setupBy ~= src then return false, 'not_your_setup' end
    local g = GG.Registry.Get(gameId)
    local allowed = false
    for _, opt in ipairs(GG.Registry.ForTable(t)) do if g and opt.id == g.id then allowed = true break end end
    if not allowed then return false, 'game_unavailable' end
    local tierOk = false
    for _, opt in ipairs(Tables.AllowedTiers(t)) do if opt.id == tierId then tierOk = true break end end
    if not tierOk then return false, 'tier_unavailable' end

    t.state = 'active'
    t.game, t.tier = g.id, tierId
    t.setupBy, t.setupUntil = nil, nil
    Tables.Sync(t)
    notifyTable(t, locale('table_started', g.label, locale(Config.Tiers[tierId].label)), 'success')
    TriggerEvent('grumpy-gambling:server:tableStarted', t.id, g.id, tierId, t.currency)
    for _, occ in pairs(t.occupants) do if occ.src then GG.Wallet.Offer(occ.src, t, occ) end end
    return true
end

-- A module stopped: tables running its game go back to setup (or empty)
function Tables.GameRemoved(gameId)
    for _, t in pairs(Tables.byId) do
        if t.game == gameId then
            local h = GG.Hands.ForTable(t.id)
            if h then GG.Hands.Cancel(h.id, 'game_stopped') end
            notifyTable(t, locale('game_closed'), 'error')
            local first = anotherOccupant(t, nil)
            if first then startSetup(t, first) else t.state = 'empty'; t.game, t.tier = nil, nil end
            Tables.Sync(t)
        end
    end
end

-- Setup timeout: pass the choice to the next seated player; a lone player keeps it
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, t in pairs(Tables.byId) do
            if t.state == 'setup' and t.setupUntil and now >= t.setupUntil then
                local nextSrc = anotherOccupant(t, t.setupBy)
                if nextSrc then
                    TriggerClientEvent('grumpy-gambling:client:setupClosed', t.setupBy)
                    GG.Notify(t.setupBy, locale('setup_passed'), 'inform')
                    startSetup(t, nextSrc)
                    Tables.Sync(t)
                else
                    t.setupUntil = now + Config.SetupTimeoutSeconds
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Exports (read only)
---------------------------------------------------------------------
exports('GetTable', function(id)
    local t = Tables.Get(id)
    return t and Tables.Public(t) or nil
end)
exports('GetTables', function() return Tables.PublicAll() end)
