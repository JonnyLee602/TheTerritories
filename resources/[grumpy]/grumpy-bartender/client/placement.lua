-- Admin editor + placement through rsg-gizmo (patterns/prop-placement.md).
-- rsg-gizmo's Place() spawns an object ghost, so for a ped we spawn a local ghost ped and use Edit() on it.

EditorTarget = nil          -- bartender id being edited (nil = new)
ReturnToManager = false     -- editor was opened from /bartenders: go back there afterwards
local moving = nil          -- bartender id whose ped is being moved
local ghostPed = nil        -- local preview ped while placing a new bartender

function PlacementBusy(id) return moving == id end

-- Back to the manager panel if the editor came from it
local function afterEdit()
    if ReturnToManager and OpenManager then
        SetTimeout(500, function() CreateThread(OpenManager) end) -- give the server time to sync
    end
end

-- b = bartender to edit; template = settings to copy into a new bartender (duplicate)
local function editorPayload(b, template)
    local models, anims, hotels = {}, {}, {}
    for _, m in ipairs(Config.Models) do models[#models + 1] = m end
    for k in pairs(Config.Animations) do anims[#anims + 1] = k end
    table.sort(anims)
    -- hotels come from grumpy-hotel (created in game with /hotellist)
    if GetResourceState('grumpy-hotel') == 'started' then
        local ok, list = pcall(function() return exports['grumpy-hotel']:GetHotels() end)
        for _, h in ipairs(ok and list or {}) do hotels[#hotels + 1] = { key = tostring(h.id), label = ('%s (#%d)'):format(h.label, h.id) } end
    end
    local src = b or template
    return {
        isNew = b == nil,
        fromManager = ReturnToManager,
        barShop = Config.BarShop.Enabled == true,
        autoStore = b ~= nil and b.services.autoStore == true,
        models = models, animations = anims, hotels = hotels,
        form = src and {
            label = src.label, model = src.model, animation = src.animation,
            store = src.services.store or '', hotel = src.services.hotel and tostring(src.services.hotel) or '',
            lottery = src.services.lottery, loyalty = src.services.loyalty, blip = src.services.blip,
        } or {
            label = locale('default_label'), model = Config.DefaultModel, animation = Config.DefaultAnimation,
            store = '', hotel = '', lottery = true, loyalty = true, blip = false,
        },
    }
end

-- opts.template = bartender to copy (duplicate), opts.fromManager = opened from /bartenders
function OpenEditor(b, opts)
    opts = opts or {}
    if not IsAdmin then return end
    if UI.open and not (opts.fromManager and UI.view == 'manager') then return end
    if b and b.static then return NotifyLocal(locale('static_locked'), 'error') end
    EditorTarget = b and b.id or nil
    ReturnToManager = opts.fromManager == true
    OpenUI('editor', editorPayload(b, opts.template))
end

RegisterNetEvent('grumpy-bartender:client:openEditor', function()
    -- only sent by the server command, which checks the permission; refresh the flag in case it changed
    IsAdmin = true
    OpenEditor(nil)
end)

---------------------------------------------------------------------
-- Ghost ped placement
---------------------------------------------------------------------
local function gizmoReady()
    if GetResourceState('rsg-gizmo') ~= 'started' then return false end
    return not exports['rsg-gizmo']:IsActive()
end

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

local function placeNew(form)
    if not gizmoReady() then return NotifyLocal(locale('gizmo_busy'), 'error') end
    local hash = loadModel(form.model)
    if not hash then return NotifyLocal(locale('invalid_model'), 'error') end

    local me = PlayerPedId()
    local start = GetOffsetFromEntityInWorldCoords(me, 0.0, 1.5, 0.0)
    local ghost = CreatePed(hash, start.x, start.y, start.z, GetEntityHeading(me) + 180.0, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ghost or ghost == 0 then return end
    ghostPed = ghost
    SetRandomOutfitVariation(ghost, true)
    SetEntityInvincible(ghost, true)
    SetBlockingOfNonTemporaryEvents(ghost, true)
    FreezeEntityPosition(ghost, true)

    local res = exports['rsg-gizmo']:Edit(ghost, {
        title = locale('place_title'),
        maxDistance = Config.PlaceDistance,
        rotation = 'z',
        startMode = 'free',
    })
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    ghostPed = nil
    if not res then return NotifyLocal(locale('place_cancelled'), 'inform') end
    TriggerServerEvent('grumpy-bartender:server:create', form, res.coords, res.heading)
end

local function moveExisting(id)
    local ped = SpawnedPeds[id]
    if not ped or not DoesEntityExist(ped) then return NotifyLocal(locale('move_too_far'), 'error') end
    if not gizmoReady() then return NotifyLocal(locale('gizmo_busy'), 'error') end
    moving = id
    ClearPedTasksImmediately(ped)
    local res = exports['rsg-gizmo']:Edit(ped, {
        title = locale('move_title'),
        maxDistance = Config.PlaceDistance,
        rotation = 'z',
    })
    moving = nil
    local b = BartenderList[id]
    if DoesEntityExist(ped) and b then PlayAnimation(ped, b.animation) end
    if not res then return NotifyLocal(locale('place_cancelled'), 'inform') end
    TriggerServerEvent('grumpy-bartender:server:move', id, res.coords, res.heading)
end

---------------------------------------------------------------------
-- Editor NUI callbacks (the server re-checks admin permission and sanitises every field)
---------------------------------------------------------------------
local function readForm(body)
    local f = type(body) == 'table' and body.form or nil
    if type(f) ~= 'table' then return nil end
    return {
        label = tostring(f.label or ''), model = tostring(f.model or ''), animation = tostring(f.animation or ''),
        store = tonumber(f.store), hotel = tonumber(f.hotel),
        lottery = f.lottery == true, loyalty = f.loyalty == true, blip = f.blip == true,
        createShop = f.createShop == true,
    }
end

-- Existing bartender: create its bar shop now (server checks admin + rsg-stores hook)
RegisterNUICallback('editorCreateShop', function(_, cb)
    cb('ok')
    if EditorTarget then TriggerServerEvent('grumpy-bartender:server:createBarShop', EditorTarget) end
end)

RegisterNetEvent('grumpy-bartender:client:editorStore', function(id, storeId)
    if UI.open and UI.view == 'editor' and EditorTarget == id then
        UpdateUI('editor', { store = storeId, autoStore = true })
    end
end)

RegisterNUICallback('editorPlace', function(body, cb)
    cb('ok')
    local form = readForm(body)
    if not form or EditorTarget then return end
    CloseUI()
    CreateThread(function() placeNew(form); afterEdit() end)
end)

RegisterNUICallback('editorSave', function(body, cb)
    cb('ok')
    local form = readForm(body)
    if not form or not EditorTarget then return end
    TriggerServerEvent('grumpy-bartender:server:update', EditorTarget, form)
    CloseUI()
    afterEdit()
end)

RegisterNUICallback('editorMove', function(_, cb)
    cb('ok')
    local id = EditorTarget
    if not id then return end
    CloseUI()
    CreateThread(function() moveExisting(id); afterEdit() end)
end)

RegisterNUICallback('editorDelete', function(_, cb)
    cb('ok')
    if not EditorTarget then return end
    TriggerServerEvent('grumpy-bartender:server:delete', EditorTarget)
    CloseUI()
    afterEdit()
end)

RegisterNUICallback('editorBack', function(_, cb)
    cb('ok')
    if not ReturnToManager then return CloseUI() end
    CreateThread(function() OpenManager(true) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if (moving or ghostPed) and GetResourceState('rsg-gizmo') == 'started' then pcall(function() exports['rsg-gizmo']:Cancel() end) end
    if ghostPed and DoesEntityExist(ghostPed) then DeleteEntity(ghostPed) end
end)
