-- /robberyadmin panel. The client shows the panel and reads the admin's own position;
-- the server re-checks the permission and validates every point.

local function fetch()
    local data = RSGCore.Functions.AwaitCallback('grumpy-robbery:server:adminData', 5000)
    if data then
        local pos = GetEntityCoords(PlayerPedId())
        for _, s in ipairs(data.stores) do s.distance = math.floor(#(pos - vector3(s.x, s.y, s.z))) end
        table.sort(data.stores, function(a, b) return a.distance < b.distance end)
    end
    return data
end

RegisterNetEvent('grumpy-robbery:client:openAdmin', function()
    CreateThread(function()
        local data = fetch()
        if not data then return GRC.Notify(locale('no_permission'), 'error') end
        if GRC.UIOpen then GRC.UpdateUI(data) else GRC.OpenUI(data) end
    end)
end)

RegisterNetEvent('grumpy-robbery:client:adminRefresh', function()
    if not GRC.UIOpen then return end
    CreateThread(function()
        local data = fetch()
        if data then GRC.UpdateUI(data) end
    end)
end)

local function myPoint()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
end

RegisterNUICallback('toggle', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-robbery:server:adminToggle', tonumber(body.id), body.enabled == true) end
end)

RegisterNUICallback('addShelf', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-robbery:server:adminAddShelf', tonumber(body.id), myPoint()) end
end)

RegisterNUICallback('removeShelf', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-robbery:server:adminRemoveShelf', tonumber(body.id), tonumber(body.index)) end
end)

RegisterNUICallback('safeHere', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-robbery:server:adminSetSafe', tonumber(body.id), myPoint(), false) end
end)

-- place a safe prop with rsg-gizmo (the panel closes while placing)
RegisterNUICallback('safeProp', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    local id = tonumber(body.id)
    GRC.CloseUI()
    CreateThread(function()
        if GetResourceState('rsg-gizmo') ~= 'started' then return GRC.Notify(locale('admin_no_gizmo'), 'error') end
        local res = exports['rsg-gizmo']:Place(Config.Safe.PropModel, {
            title = locale('admin_place_safe'), maxDistance = 8.0, rotation = 'z',
        })
        if not res then return end
        TriggerServerEvent('grumpy-robbery:server:adminSetSafe', id, {
            x = res.coords.x, y = res.coords.y, z = res.coords.z, h = res.heading,
            rot = { x = res.rotation.x, y = res.rotation.y, z = res.rotation.z },
        }, true)
        Wait(500)
        TriggerEvent('grumpy-robbery:client:openAdmin')
    end)
end)

RegisterNUICallback('removeSafe', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-robbery:server:adminRemoveSafe', tonumber(body.id)) end
end)

RegisterNUICallback('reload', function(_, cb)
    cb('ok')
    TriggerServerEvent('grumpy-robbery:server:adminReload')
end)

-- teleport the admin (own ped only)
RegisterNUICallback('teleport', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    local x, y, z = tonumber(body.x), tonumber(body.y), tonumber(body.z)
    if not (x and y and z) then return end
    GRC.CloseUI()
    SetEntityCoords(PlayerPedId(), x, y, z, false, false, false, false)
end)
