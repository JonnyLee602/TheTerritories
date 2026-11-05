-- /pob admin menu: list, editor, point capture, sign placement (rsg-gizmo) and recipe approval.
local RSGCore = exports['rsg-core']:GetCoreObject()

local function openAdmin(afterSave)
    local data = RSGCore.Functions.AwaitCallback('grumpy-pob:server:adminData')
    if not data then return end
    data.recipes = RSGCore.Functions.AwaitCallback('grumpy-pob:server:adminRecipes') or {}
    data.closeEditor = afterSave == true -- the server only refreshes after a successful change
    if POBC.uiOpen == 'admin' then POBC.UpdateUI('admin', data) else POBC.OpenUI('admin', data) end
end

RegisterNetEvent('grumpy-pob:client:openAdmin', function() openAdmin(false) end)
RegisterNetEvent('grumpy-pob:client:refresh', function(which)
    if which == 'admin' and POBC.uiOpen == 'admin' then openAdmin(true) end
end)

-- Current position + heading for a point
RegisterNUICallback('adminCapture', function(_, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    cb({ x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) })
end)

-- Place the open/closed sign with rsg-gizmo. Placed at default rotation the sign reads "Closed".
RegisterNUICallback('adminPlaceSign', function(body, cb)
    POBC.HideUI()
    CreateThread(function()
        local start = type(body.current) == 'table' and body.current.x and vector3(body.current.x, body.current.y, body.current.z) or nil
        local res = exports['rsg-gizmo']:Place(Config.SignModel, {
            title = locale('gizmo_sign'), maxDistance = 15.0, rotation = 'z', snapToGround = true,
            startCoords = start,
            startRotation = start and vector3(body.current.rx or 0.0, body.current.ry or 0.0, body.current.rz or 0.0) or nil,
        })
        POBC.ShowUI()
        if not res then return cb(nil) end
        if not RSGCore.Functions.AwaitCallback('grumpy-pob:server:adminCheckSign', nil, res.coords) then
            POBC.Notify(locale('too_far'), 'error')
            return cb(nil)
        end
        cb({ x = res.coords.x, y = res.coords.y, z = res.coords.z, rx = res.rotation.x, ry = res.rotation.y, rz = res.rotation.z })
    end)
end)

RegisterNUICallback('admin', function(body, cb)
    local op = body.op
    if op == 'save' then TriggerServerEvent('grumpy-pob:server:adminSave', body.id, body.data)
    elseif op == 'delete' then TriggerServerEvent('grumpy-pob:server:adminDelete', body.id)
    elseif op == 'reset' then TriggerServerEvent('grumpy-pob:server:adminReset', body.id)
    elseif op == 'owner' then TriggerServerEvent('grumpy-pob:server:adminSetOwner', body.id, tonumber(body.target))
    elseif op == 'teleport' then TriggerServerEvent('grumpy-pob:server:adminTeleport', body.id)
    elseif op == 'decide' then TriggerServerEvent('grumpy-pob:server:adminRecipeDecide', body.recipe, body.what, body.approve == true)
    elseif op == 'gov' then TriggerEvent('grumpy-pob:client:openGov')
    end
    cb('ok')
end)
