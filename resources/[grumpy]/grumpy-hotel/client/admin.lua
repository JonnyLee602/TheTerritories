-- /hotellist admin panel. The client shows the panel and places points with rsg-gizmo;
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

-- Place the door / interior point with rsg-gizmo. rsg-gizmo's Place() only takes props, so (like
-- grumpy-bartender) a local ghost ped is spawned and moved with Edit(). The ghost shows where players
-- stand and which way they face; its coords are standing coords, like the old "Use my position".
local function loadModel(name)
    local hash = joaat(name)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(10)
    end
    return hash
end

RegisterNUICallback('adminPlace', function(body, cb)
    if GetResourceState('rsg-gizmo') ~= 'started' or exports['rsg-gizmo']:IsActive() then
        NotifyLocal(locale('gizmo_busy'), 'error')
        return cb(nil)
    end
    local hash = loadModel(Config.PlaceModel)
    if not hash then return cb(nil) end
    local cur = type(body) == 'table' and type(body.current) == 'table' and tonumber(body.current.x) and body.current or nil
    local me = PlayerPedId()
    local start = cur and vector3(cur.x, cur.y, cur.z) or GetOffsetFromEntityInWorldCoords(me, 0.0, 1.5, 0.0)
    local heading = cur and (tonumber(cur.w) or 0.0) or (GetEntityHeading(me) + 180.0)

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    CreateThread(function()
        local ghost = CreatePed(hash, start.x, start.y, start.z, heading, false, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        local res
        if ghost and ghost ~= 0 then
            SetRandomOutfitVariation(ghost, true) -- RedM: otherwise peds can spawn invisible
            SetEntityInvincible(ghost, true)
            SetBlockingOfNonTemporaryEvents(ghost, true)
            FreezeEntityPosition(ghost, true)
            res = exports['rsg-gizmo']:Edit(ghost, {
                title = locale(body.which == 'interior' and 'gizmo_interior' or 'gizmo_door'),
                maxDistance = Config.PlaceDistance, rotation = 'z', startMode = 'free',
            })
            if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        end
        SendNUIMessage({ action = 'show' })
        if UI.open then SetNuiFocus(true, true) end
        if not res then return cb(nil) end
        cb({ x = res.coords.x, y = res.coords.y, z = res.coords.z, w = (res.heading or 0.0) % 360.0 })
    end)
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
