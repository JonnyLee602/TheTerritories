-- Admin manager panel (/bartenders): list, edit, teleport, duplicate, delete.
-- Hotel rentals are managed in grumpy-hotel (/hotellist).
-- Every action is re-checked on the server (admin permission); the client only shows the panel.
local RSGCore = exports['rsg-core']:GetCoreObject()

local function managerPayload(data)
    return { bartenders = data.bartenders or {} }
end

-- switching = true when coming back from the editor (the NUI is already open)
function OpenManager(switching)
    if UI.open and not switching and UI.view ~= 'manager' then return end
    local data = RSGCore.Functions.AwaitCallback('grumpy-bartender:server:adminData')
    if not data then return NotifyLocal(locale('no_permission'), 'error') end
    IsAdmin = true
    EditorTarget, ReturnToManager = nil, false
    if UI.open and UI.view == 'manager' then
        UpdateUI('manager', managerPayload(data))
    else
        OpenUI('manager', managerPayload(data))
    end
end

local function refreshManager()
    if not (UI.open and UI.view == 'manager') then return end
    local data = RSGCore.Functions.AwaitCallback('grumpy-bartender:server:adminData')
    if data then UpdateUI('manager', managerPayload(data)) end
end
ManagerRefresh = refreshManager -- called from client.lua when the bartender list syncs

RegisterNetEvent('grumpy-bartender:client:openManager', function() CreateThread(OpenManager) end)
RegisterNetEvent('grumpy-bartender:client:managerRefresh', function() CreateThread(refreshManager) end)

---------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------
local function bartenderFrom(body)
    local id = type(body) == 'table' and body.id or nil
    return type(id) == 'string' and BartenderList[id] or nil
end

RegisterNUICallback('managerNew', function(_, cb)
    cb('ok')
    OpenEditor(nil, { fromManager = true })
end)

RegisterNUICallback('managerEdit', function(body, cb)
    cb('ok')
    local b = bartenderFrom(body)
    if b then OpenEditor(b, { fromManager = true }) end
end)

RegisterNUICallback('managerDuplicate', function(body, cb)
    cb('ok')
    local b = bartenderFrom(body)
    if b then OpenEditor(nil, { fromManager = true, template = b }) end
end)

RegisterNUICallback('managerTeleport', function(body, cb)
    cb('ok')
    local b = bartenderFrom(body)
    if b then TriggerServerEvent('grumpy-bartender:server:teleport', b.id) end
end)

RegisterNUICallback('managerDelete', function(body, cb)
    cb('ok')
    local b = bartenderFrom(body)
    if b and not b.static then TriggerServerEvent('grumpy-bartender:server:delete', b.id) end
end)

---------------------------------------------------------------------
-- Teleport (approved by the server): stand 1.5 m in front of the bartender, facing them
---------------------------------------------------------------------
RegisterNetEvent('grumpy-bartender:client:teleport', function(pos, heading)
    local rad = math.rad(heading or 0.0)
    local dest = pos + vector3(-math.sin(rad), math.cos(rad), 0.0) * 1.5
    local ped = PlayerPedId()
    CloseUI()
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, false)
    SetEntityHeading(ped, ((heading or 0.0) + 180.0) % 360.0)
    Wait(500)
    DoScreenFadeIn(300)
end)
