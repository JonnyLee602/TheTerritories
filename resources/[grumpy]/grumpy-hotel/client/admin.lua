-- /hotellist admin panel. The client only shows the panel and reads the admin's own position;
-- the server re-checks the permission and validates every field.
local RSGCore = exports['rsg-core']:GetCoreObject()

local function fetchAdmin() return RSGCore.Functions.AwaitCallback('grumpy-hotel:server:adminData') end

local function openAdmin()
    local data = fetchAdmin()
    if not data then return NotifyLocal(locale('no_permission'), 'error') end
    IsAdmin = true
    if UI.open and UI.view == 'admin' then UpdateUI('admin', data) else
        if UI.open then CloseUI() end
        OpenUI('admin', data)
    end
end

function AdminRefresh()
    if not (UI.open and UI.view == 'admin') then return end
    local data = fetchAdmin()
    if data then UpdateUI('admin', data) end
end

RegisterNetEvent('grumpy-hotel:client:openAdmin', function() CreateThread(openAdmin) end)
RegisterNetEvent('grumpy-hotel:client:adminRefresh', function() CreateThread(AdminRefresh) end)

-- "Use my position": returns the admin's coords + heading to the form
RegisterNUICallback('adminCapture', function(_, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    cb({ x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) })
end)

RegisterNUICallback('adminSave', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' or type(body.form) ~= 'table' then return end
    local f = body.form
    TriggerServerEvent('grumpy-hotel:server:adminSave', tonumber(body.id), {
        label = tostring(f.label or ''), rooms = tonumber(f.rooms), price = tonumber(f.price), maxDays = tonumber(f.maxDays),
        blip = f.blip == true, door = f.door, interior = f.interior,
    })
end)

RegisterNUICallback('adminDelete', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-hotel:server:adminDelete', tonumber(body.id)) end
end)

RegisterNUICallback('adminEvict', function(body, cb)
    cb('ok')
    if type(body) == 'table' then TriggerServerEvent('grumpy-hotel:server:adminEvict', tonumber(body.id), tonumber(body.room)) end
end)

RegisterNUICallback('adminTeleport', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    if InRoom then return NotifyLocal(locale('leave_room_first'), 'error') end
    CloseUI()
    TriggerServerEvent('grumpy-hotel:server:adminTeleport', tonumber(body.id), body.which == 'interior' and 'interior' or 'door')
end)

RegisterNetEvent('grumpy-hotel:client:adminTeleport', function(pos)
    CreateThread(function() TeleportTo(pos) end)
end)
