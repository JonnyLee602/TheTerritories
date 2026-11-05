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

-- Place a point with rsg-gizmo. Where someone stands (NPC, hotel door/room, stable preview): rsg-gizmo's Place()
-- only takes props, so (like grumpy-bartender) a local ghost of the business NPC is spawned and moved with Edit().
-- The result is standing coords (peds spawn at z - 1.0), the same as grumpy-bartender.
-- Objects (manager desk, crafting stations, stashes) use placeMarker below instead.
local function ghostModel(name, typeKey)
    for _, m in ipairs({ name, Config.Types[typeKey] and Config.Types[typeKey].npcModel }) do
        if type(m) == 'string' then
            local hash = joaat(m)
            if IsModelValid(hash) and IsModelAPed(hash) then
                RequestModel(hash)
                local deadline = GetGameTimer() + 5000
                while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
                if HasModelLoaded(hash) then return hash end
            end
        end
    end
end

-- Manager desk, crafting station, stash: a small marker you aim at the desk / stove / chest itself.
-- The point is where the marker sits (the rsg-target zone is centred there).
local function placeMarker(body, cb)
    local cur = type(body.current) == 'table' and tonumber(body.current.x) and body.current or nil
    POBC.HideUI()
    CreateThread(function()
        local res = exports['rsg-gizmo']:Place(Config.PointMarker, {
            title = locale('gizmo_marker', tostring(body.label or '')),
            maxDistance = Config.PlaceDistance, rotation = 'z',
            startCoords = cur and vector3(cur.x, cur.y, cur.z) or nil,
        })
        POBC.ShowUI()
        if not res then return cb(nil) end
        cb({ x = res.coords.x, y = res.coords.y, z = res.coords.z, w = (res.heading or 0.0) % 360.0 })
    end)
end

RegisterNUICallback('adminPlacePoint', function(body, cb)
    if exports['rsg-gizmo']:IsActive() then return cb(nil) end
    if body.kind == 'marker' then return placeMarker(body, cb) end
    local hash = ghostModel(body.model, body.type)
    if not hash then POBC.Notify(locale('invalid_model'), 'error') return cb(nil) end
    local cur = type(body.current) == 'table' and tonumber(body.current.x) and body.current or nil
    local me = PlayerPedId()
    local start = cur and vector3(cur.x, cur.y, cur.z) or GetOffsetFromEntityInWorldCoords(me, 0.0, 1.5, 0.0)
    local heading = cur and (tonumber(cur.w) or 0.0) or (GetEntityHeading(me) + 180.0)
    POBC.HideUI()
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
                title = locale('gizmo_point', tostring(body.label or '')),
                maxDistance = Config.PlaceDistance, rotation = 'z', startMode = 'free',
            })
            if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        end
        POBC.ShowUI()
        if not res then return cb(nil) end
        cb({ x = res.coords.x, y = res.coords.y, z = res.coords.z, w = (res.heading or 0.0) % 360.0 })
    end)
end)

-- Crafting station with its own prop (stove / table from Config.CraftProps) for interiors that have none.
-- The prop is placed with rsg-gizmo; the crafting target sits CraftPropZoneHeight above its base.
local function craftProp(model)
    for _, p in ipairs(Config.CraftProps) do if p.model == model then return p end end
end

RegisterNUICallback('adminPlaceProp', function(body, cb)
    if exports['rsg-gizmo']:IsActive() then return cb(nil) end
    local def = craftProp(body.model)
    if not def then return cb(nil) end
    local cur = type(body.current) == 'table' and type(body.current.prop) == 'table' and body.current.prop.model == def.model
        and body.current.prop or nil
    POBC.HideUI()
    CreateThread(function()
        local res = exports['rsg-gizmo']:Place(def.model, {
            title = locale('gizmo_craft_prop', def.label),
            maxDistance = Config.PlaceDistance, rotation = 'z', snapToGround = true,
            startCoords = cur and vector3(cur.x, cur.y, cur.z) or nil,
            startRotation = cur and vector3(cur.rx or 0.0, cur.ry or 0.0, cur.rz or 0.0) or nil,
        })
        POBC.ShowUI()
        if not res then return cb(nil) end
        local c, r = res.coords, res.rotation
        cb({
            x = c.x, y = c.y, z = c.z + Config.CraftPropZoneHeight, w = (res.heading or 0.0) % 360.0,
            prop = { model = def.model, x = c.x, y = c.y, z = c.z, rx = r.x, ry = r.y, rz = r.z },
        })
    end)
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
