-- /gambling admin: public and micro tables, binding map tables, moving, calibration, enable/disable, delete.
local RSGCore = GG.Core

local function admin(src) return GG.IsAdmin(src) end

local function adminRow(t)
    return {
        id = t.id, label = t.label, kind = t.kind, source = t.source, model = t.model, bound = t.bound,
        currency = t.currency, fixedTier = t.fixedTier, enabled = t.enabled, state = t.state,
        game = t.game, tier = t.tier, players = GG.Tables.RealCount(t), seats = #t.seats,
        calibrated = t.seatsOverride ~= nil, modelCalibrated = GG.Tables.modelOverrides[t.model] ~= nil,
        x = t.x, y = t.y, z = t.z, h = t.h,
    }
end

RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_admin'), {}, false, function(source)
    if not admin(source) then return GG.Notify(source, locale('no_permission'), 'error') end
    TriggerClientEvent('grumpy-gambling:client:openAdmin', source)
end, Config.AdminPermission)

RSGCore.Functions.CreateCallback('grumpy-gambling:server:adminData', function(source, cb)
    if not admin(source) then return cb(nil) end
    local list = {}
    for _, t in pairs(GG.Tables.byId) do list[#list + 1] = adminRow(t) end
    table.sort(list, function(a, b) return a.id < b.id end)
    cb({
        tables = list,
        models = { pvp = ModelsOfKind('pvp'), pvd = ModelsOfKind('pvd') },
        currencies = Config.Currencies,
        microCount = GG.Tables.MicroCount(), microMax = Config.Micro.Max,
    })
end)

local function refresh(src) TriggerClientEvent('grumpy-gambling:client:adminRefresh', src) end

local function finiteCoords(c)
    return type(c) == 'table' and GG.Finite(c.x) and GG.Finite(c.y) and GG.Finite(c.z)
end

local function validCurrency(c)
    for _, v in ipairs(Config.Currencies) do if v == c then return true end end
    return false
end

---------------------------------------------------------------------
-- Create (spawned with rsg-gizmo, or bound to a map table)
---------------------------------------------------------------------
RegisterNetEvent('grumpy-gambling:server:adminCreate', function(d)
    local src = source
    if not admin(src) or GG.Cooldown(src, 'adminCreate', 2000) or type(d) ~= 'table' then return end
    local label = GG.Str(d.label, 60)
    local kind = d.kind
    local sourceType = d.source
    local model = type(d.model) == 'string' and d.model or nil
    local profile = model and Models[model]
    if not label then return GG.Notify(src, locale('admin_need_label'), 'error') end
    if (kind ~= 'pvp' and kind ~= 'pvd') or not profile or profile.kind ~= kind then return GG.Notify(src, locale('admin_bad_model'), 'error') end
    -- only models marked spawn can be placed; the rest are map tables that can only be bound
    if not d.bound and not profile.spawn then return GG.Notify(src, locale('admin_bad_model'), 'error') end
    if sourceType ~= 'public' and sourceType ~= 'micro' then return end
    local currency = d.currency
    if not validCurrency(currency) then return end
    if sourceType == 'micro' then
        if currency ~= 'cash' then return GG.Notify(src, locale('admin_micro_cash'), 'error') end
        if GG.Tables.MicroCount() >= Config.Micro.Max then return GG.Notify(src, locale('admin_micro_max', Config.Micro.Max), 'error') end
    end
    if not finiteCoords(d.coords) or not GG.Finite(tonumber(d.heading)) then return end
    local coords = vector3(d.coords.x + 0.0, d.coords.y + 0.0, d.coords.z + 0.0)
    local range = d.bound and (Config.BindSearchRadius + 3.0) or Config.PlaceDistance
    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, range) then return GG.Notify(src, locale('too_far'), 'error') end

    local t = GG.Tables.Insert({
        label = label, kind = kind, source = sourceType, model = model, bound = d.bound == true,
        x = coords.x, y = coords.y, z = coords.z, h = Geo.Wrap(tonumber(d.heading)),
        currency = currency, fixedTier = sourceType == 'micro' and 'micro' or nil,
    }, src)
    if not t then return GG.Notify(src, locale('admin_failed'), 'error') end
    GG.Notify(src, locale('admin_created', t.label, t.id), 'success')
    if t.bound and profile.autoChairs then
        local n = GG.AutoSeats(t, d.chairs, profile.autoChairs.radius)
        GG.Notify(src, n > 0 and locale('admin_auto_chairs', n) or locale('admin_auto_chairs_none'), n > 0 and 'success' or 'inform')
    end
    refresh(src)
end)

-- Map tables: the chairs the admin's client found around the table become its seats, each facing the table centre.
-- Positions come from the client, so each one is range-checked against the table here. Returns the seat count.
function GG.AutoSeats(t, chairs, radius)
    if type(chairs) ~= 'table' or #chairs < 2 or #chairs > 12 then return 0 end
    local origin = GG.Tables.Origin(t)
    local seats, dealer = {}, nil
    for _, c in ipairs(chairs) do
        if type(c) ~= 'table' or not GG.Finite(c.x) or not GG.Finite(c.y) or not GG.Finite(c.z) then return 0 end
        local dx, dy = t.x - c.x, t.y - c.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > radius + 0.5 or math.abs(c.z - t.z) > 2.0 then return 0 end
        -- heading that faces the table centre: forward = (-sin h, cos h)
        local facing = math.deg(math.atan(-dx, dy))
        local loc = Geo.ToLocal(origin, t.h, c.x, c.y, c.z, facing)
        -- a dealer table's chair behind the straight edge (+y) is the dealer's, not a player's
        if t.kind == 'pvd' and loc.y > Config.DealerSideY and (not dealer or loc.y > dealer.y) then
            if dealer then seats[#seats + 1] = dealer end
            dealer = loc
        else
            seats[#seats + 1] = loc
        end
    end
    if #seats < 1 then return 0 end
    if dealer then t.dealerOverride = { x = dealer.x, y = dealer.y, z = 0.0, h = dealer.h } end
    -- number the seats around the table in a steady order
    table.sort(seats, function(a, b) return Geo.Wrap(a.h) < Geo.Wrap(b.h) end)
    t.seatsOverride = seats
    GG.Tables.SaveCalibration(t)
    GG.Tables.Sync(t)
    return #seats
end

local function getTable(src, id)
    if not admin(src) then return nil end
    return GG.Tables.Get(id)
end

---------------------------------------------------------------------
-- Move (spawned tables only, nobody seated)
---------------------------------------------------------------------
RegisterNetEvent('grumpy-gambling:server:adminMove', function(id, coords, heading)
    local src = source
    local t = getTable(src, id)
    if not t or GG.Cooldown(src, 'adminMove', 1500) then return end
    if t.bound then return GG.Notify(src, locale('admin_bound_no_move'), 'error') end
    if GG.Tables.RealCount(t) > 0 then return GG.Notify(src, locale('admin_table_busy'), 'error') end
    if not finiteCoords(coords) or not GG.Finite(tonumber(heading)) then return end
    local c = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    if not exports['rsg-gizmo']:IsPlacementValid(src, c, Config.PlaceDistance) then return GG.Notify(src, locale('too_far'), 'error') end
    t.x, t.y, t.z, t.h = c.x, c.y, c.z, Geo.Wrap(tonumber(heading))
    GG.Tables.SavePlacement(t)
    GG.Tables.Sync(t)
    GG.Notify(src, locale('admin_moved'), 'success')
    refresh(src)
end)

---------------------------------------------------------------------
-- Rename, enable/disable, delete, teleport
---------------------------------------------------------------------
RegisterNetEvent('grumpy-gambling:server:adminRename', function(id, label)
    local src = source
    local t = getTable(src, id)
    label = GG.Str(label, 60)
    if not t or not label or GG.Cooldown(src, 'adminRename', 1000) then return end
    t.label = label
    GG.Tables.SaveMeta(t)
    GG.Tables.Sync(t)
    refresh(src)
end)

RegisterNetEvent('grumpy-gambling:server:adminToggle', function(id)
    local src = source
    local t = getTable(src, id)
    if not t or GG.Cooldown(src, 'adminToggle', 1000) then return end
    t.enabled = not t.enabled
    if not t.enabled then GG.Seats.StandAll(t, 'table_closed') end
    GG.Tables.SaveMeta(t)
    GG.Tables.Sync(t)
    GG.Notify(src, locale(t.enabled and 'admin_enabled' or 'admin_disabled'), 'success')
    refresh(src)
end)

RegisterNetEvent('grumpy-gambling:server:adminDelete', function(id)
    local src = source
    local t = getTable(src, id)
    if not t or GG.Cooldown(src, 'adminDelete', 1500) then return end
    GG.Tables.Delete(t)
    GG.Notify(src, locale('admin_deleted'), 'success')
    refresh(src)
end)

RegisterNetEvent('grumpy-gambling:server:adminTeleport', function(id)
    local src = source
    local t = getTable(src, id)
    if not t then return end
    -- stand a little in front of the table's first seat
    local x, y, z = GG.Tables.SeatWorld(t, 1)
    TriggerClientEvent('grumpy-gambling:client:teleport', src, x or t.x, y or t.y, (z or t.z) + 0.5)
end)

---------------------------------------------------------------------
-- Calibration: the client sends world positions of each chair (and the dealer);
-- the server turns them into table-local offsets.
---------------------------------------------------------------------
local function fmt(n) return ('%.4f'):format(n) end

local function luaSnippet(model, seats, dealer)
    local lines = { ('-- %s (paste into shared/models.lua)'):format(model), '        seats = {' }
    for _, s in ipairs(seats) do
        lines[#lines + 1] = ('            { x = %s, y = %s, z = %s, h = %s },'):format(fmt(s.x), fmt(s.y), fmt(s.z), fmt(s.h))
    end
    lines[#lines + 1] = '        },'
    if dealer then
        lines[#lines + 1] = ('        dealer = { x = %s, y = %s, z = %s, h = %s },'):format(fmt(dealer.x), fmt(dealer.y), fmt(dealer.z), fmt(dealer.h))
    end
    return table.concat(lines, '\n')
end

local function toLocalChecked(t, p, maxDist)
    if type(p) ~= 'table' or not GG.Finite(p.x) or not GG.Finite(p.y) or not GG.Finite(p.z) or not GG.Finite(tonumber(p.h)) then return nil end
    if #(vector3(p.x, p.y, p.z) - vector3(t.x, t.y, t.z)) > maxDist then return nil end
    return Geo.ToLocal(GG.Tables.Origin(t), t.h, p.x, p.y, p.z, tonumber(p.h))
end

RegisterNetEvent('grumpy-gambling:server:adminCalibrate', function(id, data)
    local src = source
    local t = getTable(src, id)
    if not t or type(data) ~= 'table' or GG.Cooldown(src, 'adminCalibrate', 2000) then return end
    if GG.Tables.RealCount(t) > 0 then return GG.Notify(src, locale('admin_table_busy'), 'error') end
    local pos = GG.PlayerCoords(src)
    if not pos or #(pos - vector3(t.x, t.y, t.z)) > 15.0 then return GG.Notify(src, locale('too_far'), 'error') end
    if type(data.seats) ~= 'table' or #data.seats < 1 or #data.seats > 12 then return end

    local seats = {}
    for i, p in ipairs(data.seats) do
        local o = toLocalChecked(t, p, 4.0)
        if not o then return GG.Notify(src, locale('admin_calibrate_bad'), 'error') end
        if Config.Calibration.FaceTable then
            -- face the table centre: forward = (-sin h, cos h) points from the seat (x, y) to the origin
            o.h = math.floor(math.deg(math.atan(o.x, -o.y)) * 10000 + 0.5) / 10000
        else
            -- the chair prop is turned by chairYaw; the seat heading is the way a seated player faces
            o.h = o.h - (t.chairYaw or 0.0)
        end
        seats[i] = o
    end
    local dealer
    if t.kind == 'pvd' then
        dealer = toLocalChecked(t, data.dealer, 4.0)
        if not dealer then return GG.Notify(src, locale('admin_calibrate_bad'), 'error') end
        if Config.Dealer.Seated and Config.Calibration.FaceTable then
            -- a seated dealer's chair faces the table centre, like the player seats
            dealer.h = math.floor(math.deg(math.atan(dealer.x, -dealer.y)) * 10000 + 0.5) / 10000
            dealer.z = 0.0
        end
    end

    if data.scope == 'model' then
        if not t.bound then
            t.seatsOverride, t.dealerOverride = nil, nil
            GG.Tables.SaveCalibration(t)
        end
        GG.Tables.SaveModelOverride(t.model, { seats = seats, dealer = dealer }, src)
    else
        t.seatsOverride, t.dealerOverride = seats, dealer
        GG.Tables.SaveCalibration(t)
        GG.Tables.Sync(t)
    end
    local snippet = luaSnippet(t.model, seats, dealer)
    print(('[grumpy-gambling] calibration for table %d by %s\n%s'):format(t.id, GetPlayerName(src) or src, snippet))
    TriggerClientEvent('grumpy-gambling:client:calibrated', src, snippet)
    GG.Notify(src, locale('admin_calibrated'), 'success')
    refresh(src)
end)

RegisterNetEvent('grumpy-gambling:server:adminResetCalibration', function(id, scope)
    local src = source
    local t = getTable(src, id)
    if not t or GG.Cooldown(src, 'adminResetCal', 1500) then return end
    if GG.Tables.RealCount(t) > 0 then return GG.Notify(src, locale('admin_table_busy'), 'error') end
    if scope == 'model' then
        GG.Tables.SaveModelOverride(t.model, nil, src)
    else
        t.seatsOverride, t.dealerOverride = nil, nil
        GG.Tables.SaveCalibration(t)
        GG.Tables.Sync(t)
    end
    GG.Notify(src, locale('admin_calibration_reset'), 'success')
    refresh(src)
end)
