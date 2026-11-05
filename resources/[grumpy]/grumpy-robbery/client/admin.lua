-- /robberyadmin panel. The client shows the panel and places points with rsg-gizmo;
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

-- Runs rsg-gizmo with the panel hidden, then sends the result. model = prop shown while placing.
local function gizmoPlace(model, title, send)
    if GetResourceState('rsg-gizmo') ~= 'started' then return GRC.Notify(locale('admin_no_gizmo'), 'error') end
    if exports['rsg-gizmo']:IsActive() then return end
    GRC.HideUI()
    CreateThread(function()
        local res = exports['rsg-gizmo']:Place(model, { title = title, maxDistance = Config.PlaceDistance, rotation = 'z' })
        GRC.ShowUI()
        if res then send(res) end
    end)
end

local function markerPoint(res)
    return { x = res.coords.x, y = res.coords.y, z = res.coords.z, h = res.heading }
end

RegisterNUICallback('toggle', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-robbery:server:adminToggle', tonumber(body.id), body.enabled == true) end
end)

-- shelf point: aim the marker at the shelf itself
RegisterNUICallback('addShelf', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    local id = tonumber(body.id)
    gizmoPlace(Config.PointMarker, locale('admin_place_shelf'), function(res)
        TriggerServerEvent('grumpy-robbery:server:adminAddShelf', id, markerPoint(res))
    end)
end)

RegisterNUICallback('removeShelf', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-robbery:server:adminRemoveShelf', tonumber(body.id), tonumber(body.index)) end
end)

-- existing safe in the interior: aim the marker at the safe itself (no prop is spawned)
RegisterNUICallback('safeHere', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    local id = tonumber(body.id)
    gizmoPlace(Config.PointMarker, locale('admin_place_safe_point'), function(res)
        TriggerServerEvent('grumpy-robbery:server:adminSetSafe', id, markerPoint(res), false)
    end)
end)

-- place a safe prop with rsg-gizmo
RegisterNUICallback('safeProp', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    local id = tonumber(body.id)
    gizmoPlace(Config.Safe.PropModel, locale('admin_place_safe'), function(res)
        local p = markerPoint(res)
        p.rot = { x = res.rotation.x, y = res.rotation.y, z = res.rotation.z }
        TriggerServerEvent('grumpy-robbery:server:adminSetSafe', id, p, true)
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
