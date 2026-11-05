local RSGCore = exports['rsg-core']:GetCoreObject()

-- Shared with server/hotel.lua (same resource, server side only)
Bartenders = {}          -- [id] = bartender record (see DOCS.md -> Data formats)

local KEY_PREFIX = 'grumpy-bartender:'
local cooldowns = {}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
function Notify(src, msg, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = msg, type = ntype or 'inform', duration = 5000 })
end

local function dbg(...) if Config.Debug then print('[grumpy-bartender]', ...) end end

local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function onCooldown(src, seconds)
    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < (seconds or 1) * 1000 then return true end
    cooldowns[src] = now
    return false
end

local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end

local modelSet = {}
for _, m in ipairs(Config.Models) do modelSet[m] = true end

function IsNearBartender(src, id, extra)
    local b = Bartenders[id]
    if not b then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(b.x, b.y, b.z)) <= Config.ServerDistance + (extra or 0.0)
end

local function sanitiseForm(data)
    if type(data) ~= 'table' then return nil end
    local label = type(data.label) == 'string' and data.label:gsub('[<>"\']', '') or ''
    label = label:sub(1, 50)
    if label:match('^%s*$') then label = locale('default_label') end

    local model = modelSet[data.model] and data.model or Config.DefaultModel
    local animation = Config.Animations[data.animation] and data.animation or Config.DefaultAnimation

    local store = math.tointeger(tonumber(data.store))
    if not store or store <= 0 then store = false end
    local hotel = math.tointeger(tonumber(data.hotel))
    if not hotel or hotel <= 0 then hotel = false end

    return {
        label = label,
        model = model,
        animation = animation,
        services = {
            store   = store,
            hotel   = hotel,
            lottery = data.lottery == true,
            loyalty = data.loyalty == true,
            blip    = data.blip == true,
        },
    }
end

local function toList()
    local out = {}
    for _, b in pairs(Bartenders) do out[#out + 1] = b end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function broadcast()
    TriggerClientEvent('grumpy-bartender:client:sync', -1, toList())
end

---------------------------------------------------------------------
-- Integration hooks (rsg-stores / rsg-loyalty must have the patches in integrations/)
---------------------------------------------------------------------
local function callExport(res, fn, ...)
    if GetResourceState(res) ~= 'started' then return false end
    local args = { ... }
    local ok, result = pcall(function()
        local e = exports[res]
        return e[fn](e, table.unpack(args))
    end)
    if not ok then dbg(('%s:%s failed (missing integration patch?): %s'):format(res, fn, result)) end
    return ok, result
end

local function registerIntegrations(b)
    local key, pos = KEY_PREFIX .. b.id, vector3(b.x, b.y, b.z)
    if b.services.store then
        callExport('rsg-stores', 'SetShopAccessPoint', key, b.services.store, pos)
    else
        callExport('rsg-stores', 'RemoveShopAccessPoint', key)
    end
    if b.services.loyalty then
        callExport('rsg-loyalty', 'SetRedeemPoint', key, pos)
    else
        callExport('rsg-loyalty', 'RemoveRedeemPoint', key)
    end
    -- grumpy-hotel: this bartender becomes a rental point for its hotel (the hotel checks distance to pos)
    if b.services.hotel then
        callExport('grumpy-hotel', 'SetRentalPoint', key, b.services.hotel, pos)
    else
        callExport('grumpy-hotel', 'RemoveRentalPoint', key)
    end
end

local function unregisterIntegrations(id)
    callExport('rsg-stores', 'RemoveShopAccessPoint', KEY_PREFIX .. id)
    callExport('rsg-loyalty', 'RemoveRedeemPoint', KEY_PREFIX .. id)
    callExport('grumpy-hotel', 'RemoveRentalPoint', KEY_PREFIX .. id)
end

---------------------------------------------------------------------
-- Automatic bar shop (rsg-stores part 2 hook: CreateShop / DeleteShop / ShopExists)
---------------------------------------------------------------------
local function saveServices(b)
    if b.static then return end
    MySQL.update.await('UPDATE grumpy_bartenders SET services = ? WHERE id = ?', { json.encode(b.services), b.dbId })
end

local function barShopItems()
    local out = {}
    for _, it in ipairs(Config.BarShop.Items or {}) do
        local shared = RSGCore.Shared.Items[it.name]
        if shared then
            out[#out + 1] = { name = it.name, label = shared.label, price = tonumber(it.price) or 0, amount = it.amount }
        else
            print(('^3[grumpy-bartender]^7 Config.BarShop item %s does not exist in rsg-core items; skipped'):format(tostring(it.name)))
        end
    end
    return out
end

-- Returns the new store id, or nil (and tells the admin why)
local function createBarShop(src, b)
    if not Config.BarShop.Enabled then return nil end
    if b.services.store then
        local ok, exists = callExport('rsg-stores', 'ShopExists', b.services.store)
        if ok and exists then Notify(src, locale('shop_already_linked', b.services.store), 'error') return nil end
    end
    local items = barShopItems()
    if #items == 0 then Notify(src, locale('shop_no_items'), 'error') return nil end
    local ok, storeId = callExport('rsg-stores', 'CreateShop', {
        name = b.label, shopName = 'bar_' .. b.id, label = b.label,
        x = b.x, y = b.y, z = b.z, h = b.h, items = items, model = 'none',
    })
    storeId = ok and math.tointeger(tonumber(storeId)) or nil
    if not storeId then Notify(src, locale('shop_create_failed'), 'error') return nil end
    b.services.store, b.services.autoStore = storeId, true
    saveServices(b)
    registerIntegrations(b)
    Notify(src, locale('shop_created', b.label, storeId), 'success')
    return storeId
end

local function deleteBarShop(b)
    if not (b.services.autoStore and b.services.store and Config.BarShop.DeleteWithBartender) then return end
    callExport('rsg-stores', 'DeleteShop', b.services.store)
end

-- rsg-stores / rsg-loyalty / grumpy-hotel restarted: their access points are gone, add them back
AddEventHandler('onResourceStart', function(res)
    if res ~= 'rsg-stores' and res ~= 'rsg-loyalty' and res ~= 'grumpy-hotel' then return end
    SetTimeout(2000, function()
        for _, b in pairs(Bartenders) do registerIntegrations(b) end
    end)
end)

---------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------
local function rowToBartender(row)
    local services = json.decode(row.services or '{}') or {}
    return {
        id = 'db_' .. row.id, dbId = row.id, static = false,
        label = row.label, model = row.model, animation = row.animation,
        x = row.x + 0.0, y = row.y + 0.0, z = row.z + 0.0, h = row.h + 0.0,
        services = {
            store   = math.tointeger(tonumber(services.store)) or false,
            autoStore = services.autoStore == true and services.store ~= nil and services.store ~= false,
            hotel   = math.tointeger(tonumber(services.hotel)) or false, -- grumpy-hotel id (old string keys are dropped)
            lottery = services.lottery == true,
            loyalty = services.loyalty == true,
            blip    = services.blip == true,
        },
    }
end

local function loadStatic()
    for key, c in pairs(Config.Bartenders) do
        local form = sanitiseForm({
            label = c.label, model = c.model, animation = c.animation,
            store = c.services and c.services.store, hotel = c.services and c.services.hotel,
            lottery = c.services and c.services.lottery, loyalty = c.services and c.services.loyalty,
            blip = c.services and c.services.blip,
        })
        if c.model and not modelSet[c.model] then
            print(('^3[grumpy-bartender]^7 static bartender %s uses model %s which is not in Config.Models; using %s'):format(key, c.model, form.model))
        end
        local id = 'cfg_' .. key
        Bartenders[id] = {
            id = id, static = true, label = form.label, model = form.model, animation = form.animation,
            x = c.coords.x, y = c.coords.y, z = c.coords.z, h = c.coords.w or 0.0, services = form.services,
        }
    end
end

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `grumpy_bartenders` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(50) NOT NULL,
            `model` VARCHAR(64) NOT NULL,
            `animation` VARCHAR(50) NOT NULL,
            `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
            `services` LONGTEXT NOT NULL,
            `created_by` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

MySQL.ready(function()
    if Config.AutoDatabase then createTables() end
    loadStatic()
    local rows = MySQL.query.await('SELECT * FROM grumpy_bartenders') or {}
    for _, row in ipairs(rows) do
        local b = rowToBartender(row)
        Bartenders[b.id] = b
    end
    for _, b in pairs(Bartenders) do registerIntegrations(b) end
    broadcast()
    dbg(('loaded %d bartenders'):format(#toList()))
end)

---------------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-bartender:server:getAll', function(source, cb)
    cb({ bartenders = toList(), isAdmin = isAdmin(source) })
end)

---------------------------------------------------------------------
-- Admin: create / update / move / delete
---------------------------------------------------------------------
RSGCore.Commands.Add(Config.PlaceCommand, locale('cmd_place_help'), {}, false, function(source)
    TriggerClientEvent('grumpy-bartender:client:openEditor', source, nil)
end, Config.AdminPermission)

local function readPlacement(src, coords, heading)
    if type(coords) ~= 'vector3' then return nil end
    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, Config.PlaceDistance) then return nil end
    heading = tonumber(heading)
    if not finite(heading) then heading = 0.0 end
    return coords, heading % 360.0
end

-- "Use my position": the server reads the admin's own ped, nothing comes from the client
local function playerPlacement(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped), GetEntityHeading(ped) % 360.0
end

local function createBartender(src, Player, form, pos, h, wantShop)
    local dbId = MySQL.insert.await(
        'INSERT INTO grumpy_bartenders (label, model, animation, x, y, z, h, services, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { form.label, form.model, form.animation, pos.x, pos.y, pos.z, h, json.encode(form.services), Player.PlayerData.citizenid })
    if not dbId then return Notify(src, locale('db_error'), 'error') end

    local b = {
        id = 'db_' .. dbId, dbId = dbId, static = false, label = form.label, model = form.model, animation = form.animation,
        x = pos.x, y = pos.y, z = pos.z, h = h, services = form.services,
    }
    Bartenders[b.id] = b
    registerIntegrations(b)
    Notify(src, locale('placed', b.label), 'success')
    if wantShop then createBarShop(src, b) end
    broadcast()
    print(('[grumpy-bartender] %s placed bartender %s at vector4(%.2f, %.2f, %.2f, %.2f)'):format(GetPlayerName(src), b.id, pos.x, pos.y, pos.z, h))
end

RegisterNetEvent('grumpy-bartender:server:create', function(data, coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not isAdmin(src) or onCooldown(src, 2) then return end
    local form = sanitiseForm(data)
    local pos, h = readPlacement(src, coords, heading)
    if not form or not pos then return Notify(src, locale('invalid_placement'), 'error') end
    createBartender(src, Player, form, pos, h, data.createShop == true)
end)

RegisterNetEvent('grumpy-bartender:server:createHere', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not isAdmin(src) or onCooldown(src, 2) then return end
    local form = sanitiseForm(data)
    local pos, h = playerPlacement(src)
    if not form or not pos then return Notify(src, locale('invalid_placement'), 'error') end
    createBartender(src, Player, form, pos, h, data.createShop == true)
end)

local function editable(src, id)
    if not RSGCore.Functions.GetPlayer(src) or not isAdmin(src) then return nil end
    local b = type(id) == 'string' and Bartenders[id] or nil
    if not b then return nil end
    if b.static then Notify(src, locale('static_locked'), 'error') return nil end
    return b
end

RegisterNetEvent('grumpy-bartender:server:update', function(id, data)
    local src = source
    if onCooldown(src, 1) then return end
    local b = editable(src, id)
    local form = b and sanitiseForm(data)
    if not form then return end
    -- keep "this shop was created by us" only while the store id stays the same
    form.services.autoStore = (b.services.autoStore and form.services.store == b.services.store) or nil
    MySQL.update.await('UPDATE grumpy_bartenders SET label = ?, model = ?, animation = ?, services = ? WHERE id = ?',
        { form.label, form.model, form.animation, json.encode(form.services), b.dbId })
    b.label, b.model, b.animation, b.services = form.label, form.model, form.animation, form.services
    registerIntegrations(b)
    broadcast()
    Notify(src, locale('saved', b.label), 'success')
end)

local function moveBartender(src, b, pos, h)
    MySQL.update.await('UPDATE grumpy_bartenders SET x = ?, y = ?, z = ?, h = ? WHERE id = ?', { pos.x, pos.y, pos.z, h, b.dbId })
    b.x, b.y, b.z, b.h = pos.x, pos.y, pos.z, h
    registerIntegrations(b)
    broadcast()
    Notify(src, locale('moved', b.label), 'success')
end

RegisterNetEvent('grumpy-bartender:server:move', function(id, coords, heading)
    local src = source
    if onCooldown(src, 1) then return end
    local b = editable(src, id)
    if not b then return end
    local pos, h = readPlacement(src, coords, heading)
    if not pos then return Notify(src, locale('invalid_placement'), 'error') end
    moveBartender(src, b, pos, h)
end)

RegisterNetEvent('grumpy-bartender:server:moveHere', function(id)
    local src = source
    if onCooldown(src, 1) then return end
    local b = editable(src, id)
    if not b then return end
    local pos, h = playerPlacement(src)
    if not pos then return Notify(src, locale('invalid_placement'), 'error') end
    moveBartender(src, b, pos, h)
end)

RegisterNetEvent('grumpy-bartender:server:delete', function(id)
    local src = source
    if onCooldown(src, 1) then return end
    local b = editable(src, id)
    if not b then return end
    MySQL.update.await('DELETE FROM grumpy_bartenders WHERE id = ?', { b.dbId })
    Bartenders[b.id] = nil
    unregisterIntegrations(b.id)
    deleteBarShop(b)
    broadcast()
    Notify(src, locale('deleted', b.label), 'success')
end)

RegisterNetEvent('grumpy-bartender:server:createBarShop', function(id)
    local src = source
    if onCooldown(src, 2) then return end
    local b = editable(src, id)
    if not b then return end
    local storeId = createBarShop(src, b)
    if not storeId then return end
    broadcast()
    TriggerClientEvent('grumpy-bartender:client:editorStore', src, b.id, storeId)
end)

---------------------------------------------------------------------
-- Admin manager (/bartenders)
---------------------------------------------------------------------
RSGCore.Commands.Add(Config.ManageCommand, locale('cmd_manage_help'), {}, false, function(source)
    TriggerClientEvent('grumpy-bartender:client:openManager', source)
end, Config.AdminPermission)

RSGCore.Functions.CreateCallback('grumpy-bartender:server:adminData', function(source, cb)
    if not isAdmin(source) then return cb(nil) end
    cb({ bartenders = toList() })
end)

-- Teleport is approved here and carried out by the admin's client
RegisterNetEvent('grumpy-bartender:server:teleport', function(id)
    local src = source
    if not isAdmin(src) or onCooldown(src, 1) then return end
    local b = type(id) == 'string' and Bartenders[id] or nil
    if not b then return end
    TriggerClientEvent('grumpy-bartender:client:teleport', src, vector3(b.x, b.y, b.z), b.h)
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('GetBartenders', function() return toList() end)
exports('GetBartender', function(id) return Bartenders[id] end)
exports('IsNearBartender', function(src, id) return IsNearBartender(src, id) end)

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Bartenders) do unregisterIntegrations(id) end
end)
