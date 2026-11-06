-- Client core: table sync, helpers and the NUI bridge.
local RSGCore = exports['rsg-core']:GetCoreObject()

GGC = {
    Core = RSGCore,
    Tables = {},        -- [id] = public table data from the server
    Seat = nil,         -- { id, seat } while seated
    uiOpen = nil,       -- 'admin' | 'setup' | nil
}

function GGC.Notify(msg, ntype, duration)
    RSGCore.Functions.Notify({ title = locale('title'), description = msg, type = ntype or 'inform', duration = duration or 5000 })
end

function GGC.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(50)
    end
    return hash
end

function GGC.LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(50)
    end
    return true
end

function GGC.Origin(t) return { x = t.x, y = t.y, z = t.z } end

-- Chair (floor) position and facing heading of a seat
function GGC.SeatWorld(t, i)
    local s = t.seats and t.seats[i]
    if not s then return nil end
    return Geo.ToWorld(GGC.Origin(t), t.h, s)
end

---------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------
local function applyAll(list)
    local seen = {}
    for _, t in ipairs(list or {}) do
        seen[t.id] = true
        GGC.Tables[t.id] = t
        TriggerEvent('grumpy-gambling:client:tableChanged', t.id)
    end
    for id in pairs(GGC.Tables) do
        if not seen[id] then
            GGC.Tables[id] = nil
            TriggerEvent('grumpy-gambling:client:tableRemoved', id)
        end
    end
end

local function requestSync()
    local data = RSGCore.Functions.AwaitCallback('grumpy-gambling:server:sync', 10000)
    if not data then return end
    applyAll(data.tables)
end

RegisterNetEvent('grumpy-gambling:client:sync', function(list) applyAll(list) end)

RegisterNetEvent('grumpy-gambling:client:table', function(t)
    if type(t) ~= 'table' or not t.id then return end
    GGC.Tables[t.id] = t
    TriggerEvent('grumpy-gambling:client:tableChanged', t.id)
end)

RegisterNetEvent('grumpy-gambling:client:removeTable', function(id)
    GGC.Tables[id] = nil
    TriggerEvent('grumpy-gambling:client:tableRemoved', id)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() CreateThread(requestSync) end)

CreateThread(function()
    -- resource (re)start while already in game
    Wait(1000)
    if LocalPlayer.state.isLoggedIn then requestSync() end
end)

---------------------------------------------------------------------
-- NUI bridge
---------------------------------------------------------------------
local uiStrings
local function uiLocale()
    if uiStrings then return uiStrings end
    uiStrings = {}
    local lang = GetConvar('rsg:locale', 'en')
    local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
        or LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
    local ok, data = pcall(json.decode, raw or '{}')
    if ok and type(data) == 'table' then
        for k in pairs(data) do
            if k:sub(1, 3) == 'ui_' or k:sub(1, 5) == 'tier_' then uiStrings[k] = locale(k) end
        end
    end
    return uiStrings
end

GGC.UiLocale = uiLocale

function GGC.OpenUI(view, data)
    GGC.uiOpen = view
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', view = view, data = data, locale = uiLocale() })
end

function GGC.UpdateUI(view, data)
    if GGC.uiOpen ~= view then return end
    SendNUIMessage({ action = 'update', view = view, data = data })
end

function GGC.CloseUI()
    if not GGC.uiOpen then return end
    GGC.uiOpen = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerEvent('grumpy-gambling:client:uiClosed')
end

-- Hide without forgetting the view (rsg-gizmo running)
function GGC.HideUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

function GGC.ShowUI()
    if not GGC.uiOpen then return end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' })
end

RegisterNUICallback('close', function(_, cb)
    GGC.CloseUI()
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and GGC.uiOpen then SetNuiFocus(false, false) end
end)
