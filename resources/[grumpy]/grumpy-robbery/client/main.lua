RSGCore = exports['rsg-core']:GetCoreObject()

-- shared client state for robbery.lua, shoplift.lua and admin.lua
GRC = { Stores = {}, ById = {}, listeners = {} }

function GRC.Notify(description, nType, id)
    RSGCore.Functions.Notify({ title = locale('title'), description = description, type = nType or 'inform', duration = 5000, id = id })
end

function GRC.OnStores(fn) GRC.listeners[#GRC.listeners + 1] = fn end

RegisterNetEvent('grumpy-robbery:client:stores', function(list)
    GRC.Stores, GRC.ById = list or {}, {}
    for _, s in ipairs(GRC.Stores) do
        s.coords = vector3(s.x, s.y, s.z)
        s.hash = joaat(s.model)
        GRC.ById[s.id] = s
    end
    for _, fn in ipairs(GRC.listeners) do fn() end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then TriggerServerEvent('grumpy-robbery:server:requestStores') end
end)

-----------------------------------------------------------------------
-- finding the rsg-stores clerk: rsg-stores spawns a local ped at the store's saved coords
-- with the saved model. We look it up instead of changing rsg-stores.
-----------------------------------------------------------------------
-- Cached per store: the ped pool is only searched when the cached handle is gone (rsg-stores despawned
-- or respawned the clerk), and a miss is remembered for a second so callers can't trigger a search every tick.
local clerkCache = {}   -- [storeId] = ped
local clerkMiss = {}    -- [storeId] = GetGameTimer() of the last failed search

local function isClerk(ped, store)
    if not ped or not DoesEntityExist(ped) or GetEntityModel(ped) ~= store.hash or IsPedAPlayer(ped) then return false end
    local c = GetEntityCoords(ped)
    return #(vector2(c.x, c.y) - vector2(store.x, store.y)) <= Config.ClerkFindRadius
end

function GRC.FindClerk(store)
    if not store then return nil end
    local cached = clerkCache[store.id]
    if cached and isClerk(cached, store) then return cached end
    clerkCache[store.id] = nil
    if clerkMiss[store.id] and GetGameTimer() - clerkMiss[store.id] < 1000 then return nil end

    local best, bestDist = nil, Config.ClerkFindRadius
    for _, ped in ipairs(GetGamePool('CPed')) do
        if GetEntityModel(ped) == store.hash and not IsPedAPlayer(ped) then
            local c = GetEntityCoords(ped)
            local d = #(vector2(c.x, c.y) - vector2(store.x, store.y))
            if d <= bestDist then best, bestDist = ped, d end
        end
    end
    if best then clerkCache[store.id], clerkMiss[store.id] = best, nil else clerkMiss[store.id] = GetGameTimer() end
    return best
end

GRC.OnStores(function() clerkCache, clerkMiss = {}, {} end) -- store list changed: forget handles

-- which store's clerk is this ped? (only stores within 20 m)
function GRC.StoreForClerk(ped)
    local pos = GetEntityCoords(PlayerPedId())
    for _, s in ipairs(GRC.Stores) do
        if #(pos - s.coords) < 20.0 and GRC.FindClerk(s) == ped then return s end
    end
end

-----------------------------------------------------------------------
-- clerk reactions, broadcast by the server so every nearby player sees them on their own copy
-----------------------------------------------------------------------
local clerkJobs = {}   -- [storeId] = token

local function restore(store)
    local ped = GRC.FindClerk(store)
    if ped then
        ClearPedTasks(ped)
        TaskStartScenarioInPlace(ped, joaat(Config.ClerkScenario), 0, true)
    end
end

RegisterNetEvent('grumpy-robbery:client:clerkState', function(storeId, state, data)
    local store = GRC.ById[storeId]
    if not store or #(GetEntityCoords(PlayerPedId()) - store.coords) > 80.0 then return end
    data = data or {}
    local token = {}
    clerkJobs[storeId] = token

    if state == 'idle' then return restore(store) end

    CreateThread(function()
        local duration = state == 'robbed' and (data.duration or 35000) or ((data.duration or 6) * 1000)
        local untilTime = GetGameTimer() + duration
        local applied = nil
        while clerkJobs[storeId] == token and GetGameTimer() < untilTime do
            local ped = GRC.FindClerk(store)
            if ped and ped ~= applied then -- (re)apply if rsg-stores respawned the ped
                ClearPedTasksImmediately(ped)
                if state == 'robbed' or state == 'cower' then
                    local robberPed = 0
                    if data.robber then
                        local p = GetPlayerFromServerId(data.robber)
                        if p ~= -1 then robberPed = GetPlayerPed(p) end
                    end
                    TaskHandsUp(ped, untilTime - GetGameTimer(), robberPed, 500, 1) -- TASK_HANDS_UP, 1 = straight to loop
                elseif state == 'shout' then
                    local p = data.thief and GetPlayerFromServerId(data.thief) or -1
                    if p ~= -1 then TaskTurnPedToFaceEntity(ped, GetPlayerPed(p), 2000) end
                end
                applied = ped
            end
            Wait(500)
        end
        if clerkJobs[storeId] == token then
            clerkJobs[storeId] = nil
            restore(store)
        end
    end)
end)

-----------------------------------------------------------------------
-- NUI bridge (admin panel)
-----------------------------------------------------------------------
GRC.UIOpen = false

function GRC.OpenUI(data)
    GRC.UIOpen = true
    SetNuiFocus(true, true)
    local strings = {}
    for _, k in ipairs({ 'ui_title', 'ui_subtitle', 'ui_search', 'ui_robbable', 'ui_shelves', 'ui_safe', 'ui_none',
        'ui_add_shelf', 'ui_set_safe_here', 'ui_place_safe_prop', 'ui_remove', 'ui_teleport', 'ui_back', 'ui_reload',
        'ui_on', 'ui_off', 'ui_safe_prop', 'ui_safe_marker', 'ui_no_stores', 'ui_shelf', 'ui_distance' }) do
        strings[k] = locale(k)
    end
    SendNUIMessage({ action = 'open', data = data, locale = strings })
end

function GRC.UpdateUI(data) if GRC.UIOpen then SendNUIMessage({ action = 'update', data = data }) end end

function GRC.CloseUI()
    if not GRC.UIOpen then return end
    GRC.UIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- out of the way while rsg-gizmo runs; the panel keeps the selected store
function GRC.HideUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

function GRC.ShowUI()
    if not GRC.UIOpen then return end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' })
end

RegisterNUICallback('close', function(_, cb) GRC.CloseUI(); cb('ok') end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if GRC.UIOpen then SetNuiFocus(false, false) end
    for _, s in ipairs(GRC.Stores) do if clerkJobs[s.id] then restore(s) end end
end)
