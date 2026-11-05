-- /robberyadmin: per store robbable toggle, shelf points (max 4) and safe. Every action re-checks the permission.

RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_admin'), {}, false, function(source)
    TriggerClientEvent('grumpy-robbery:client:openAdmin', source)
end, Config.AdminPermission)

local function admin(src)
    return RSGCore.Functions.GetPlayer(src) ~= nil and GR.IsAdmin(src)
end

local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end

-- a point the admin captured; must be near the store's clerk and near the admin
local function point(src, store, p)
    if type(p) ~= 'table' then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    local v = vector3(x, y, z)
    if #(v - store.coords) > Config.MaxPointDistance then return nil end
    if GR.Dist(src, v) > 15.0 then return nil end
    return v
end

local function changed(src, id, msgKey)
    GR.Save(id)
    GR.Sync()
    TriggerClientEvent('grumpy-robbery:client:adminRefresh', src)
    if msgKey then GR.Notify(src, locale(msgKey), 'success') end
end

RSGCore.Functions.CreateCallback('grumpy-robbery:server:adminData', function(src, cb)
    if not admin(src) then return cb(nil) end
    cb({ stores = GR.PublicStores(), maxShelves = Config.Shoplift.MaxShelves })
end)

RegisterNetEvent('grumpy-robbery:server:adminReload', function()
    local src = source
    if not admin(src) then return end
    GR.LoadStores()
    TriggerClientEvent('grumpy-robbery:client:adminRefresh', src)
end)

RegisterNetEvent('grumpy-robbery:server:adminToggle', function(id, enabled)
    local src = source
    local store = GR.Stores[tonumber(id) or -1]
    if not admin(src) or not store then return end
    store.enabled = enabled == true
    changed(src, store.id, store.enabled and 'admin_enabled' or 'admin_disabled')
end)

RegisterNetEvent('grumpy-robbery:server:adminAddShelf', function(id, p)
    local src = source
    local store = GR.Stores[tonumber(id) or -1]
    if not admin(src) or not store then return end
    if #store.shelves >= Config.Shoplift.MaxShelves then return GR.Notify(src, locale('admin_max_shelves', Config.Shoplift.MaxShelves), 'error') end
    local v = point(src, store, p)
    if not v then return GR.Notify(src, locale('admin_bad_point', Config.MaxPointDistance), 'error') end
    store.shelves[#store.shelves + 1] = v
    changed(src, store.id, 'admin_shelf_added')
end)

RegisterNetEvent('grumpy-robbery:server:adminRemoveShelf', function(id, index)
    local src = source
    local store = GR.Stores[tonumber(id) or -1]
    index = tonumber(index)
    if not admin(src) or not store or not index or not store.shelves[index] then return end
    table.remove(store.shelves, index)
    changed(src, store.id, 'admin_shelf_removed')
end)

-- safe: { x, y, z, h, prop = bool, rx, ry, rz }
RegisterNetEvent('grumpy-robbery:server:adminSetSafe', function(id, p, withProp)
    local src = source
    local store = GR.Stores[tonumber(id) or -1]
    if not admin(src) or not store or type(p) ~= 'table' then return end
    local v = point(src, store, p)
    if not v then return GR.Notify(src, locale('admin_bad_point', Config.MaxPointDistance), 'error') end
    local safe = { x = v.x, y = v.y, z = v.z, h = (tonumber(p.h) or 0.0) % 360.0, prop = withProp == true }
    if safe.prop then
        if GetResourceState('rsg-gizmo') == 'started' then
            if not exports['rsg-gizmo']:IsPlacementValid(src, v, 15.0) then return end
            local rot = exports['rsg-gizmo']:SanitiseRotation(p.rot)
            if rot then safe.rx, safe.ry, safe.rz = rot.x, rot.y, rot.z end
        end
    end
    store.safe = safe
    changed(src, store.id, 'admin_safe_set')
end)

RegisterNetEvent('grumpy-robbery:server:adminRemoveSafe', function(id)
    local src = source
    local store = GR.Stores[tonumber(id) or -1]
    if not admin(src) or not store then return end
    store.safe = nil
    changed(src, store.id, 'admin_safe_removed')
end)
