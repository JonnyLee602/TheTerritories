-- Client core: business sync, NPC / sign spawning, blips, target zones and the NUI bridge.
local RSGCore = exports['rsg-core']:GetCoreObject()

POBC = {
    Businesses = {},   -- [id] = public business data
    Employment = {},   -- [id] = grade (businesses this character works at)
    world = {},        -- [id] = { ped, sign, blip, zones = {}, signOwned }
    uiOpen = false,
}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
function POBC.Notify(msg, ntype)
    RSGCore.Functions.Notify({ title = locale('title'), description = msg, type = ntype or 'inform', duration = 5000 })
end

function POBC.Job() return (RSGCore.Functions.GetPlayerData() or {}).job or {} end

function POBC.OnDutyAt(biz)
    local j = POBC.Job()
    return j.name == biz.job and j.onduty == true
end

function POBC.WorksAt(biz) return POBC.Employment[biz.id] ~= nil end

-- Current copy of a business (target closures look it up so they never act on stale data)
function POBC.Live(id) return POBC.Businesses[id] end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil end
        Wait(50)
    end
    return hash
end

local function v3(p) return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end

-- Display only (the server checks again): on-duty law, and for issuing warrants the minimum grade
function POBC.IsLaw(issuing)
    local A = Config.Audit
    if not A or not A.Enabled then return false end
    local job = (RSGCore.Functions.GetPlayerData() or {}).job or {}
    if not A.JobTypes[job.type] or (A.RequireOnDuty and not job.onduty) then return false end
    return not issuing or (job.grade and tonumber(job.grade.level) or 0) >= A.MinGrade
end

---------------------------------------------------------------------
-- NUI bridge
---------------------------------------------------------------------
function POBC.OpenUI(view, data)
    POBC.uiOpen = view
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', view = view, data = data, locale = POBC.UiLocale })
end

function POBC.UpdateUI(view, data)
    if POBC.uiOpen ~= view then return end
    SendNUIMessage({ action = 'update', view = view, data = data })
end

function POBC.CloseUI()
    if not POBC.uiOpen then return end
    POBC.uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- Hide the UI without forgetting the view (used while rsg-gizmo or capture runs)
function POBC.HideUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

function POBC.ShowUI()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' })
end

RegisterNUICallback('close', function(_, cb) POBC.CloseUI() cb('ok') end)

-- Every player-facing UI string, sent once with each open
CreateThread(function()
    local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(GetConvar('rsg:locale', GetConvar('ox:locale', 'en'))))
        or LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
    local ok, data = pcall(json.decode, raw or '{}')
    local en = json.decode(LoadResourceFile(GetCurrentResourceName(), 'locales/en.json') or '{}') or {}
    local out = {}
    for k, v in pairs(en) do if k:sub(1, 3) == 'ui_' then out[k] = v end end
    if ok and type(data) == 'table' then for k, v in pairs(data) do if k:sub(1, 3) == 'ui_' then out[k] = v end end end
    POBC.UiLocale = out
end)

---------------------------------------------------------------------
-- Blips
---------------------------------------------------------------------
local function removeBlip(w) if w.blip and DoesBlipExist(w.blip) then RemoveBlip(w.blip) end w.blip = nil end

local function makeBlip(biz, w)
    removeBlip(w)
    if not biz.points.npc or (biz.blip and biz.blip.enabled == false) then return end
    local p = biz.points.npc
    local blip = BlipAddForCoords(Config.BlipStyle, p.x, p.y, p.z)
    local t = Config.Types[biz.type] or {}
    SetBlipSprite(blip, joaat((biz.blip and biz.blip.sprite) or (t.blip and t.blip.sprite) or 'blip_shop_store'), true)
    SetBlipScale(blip, Config.BlipScale)
    SetBlipName(blip, biz.owned and biz.label or locale('blip_for_sale', biz.label))
    local color = biz.blip and biz.blip.color or ''
    if color ~= '' then BlipAddModifier(blip, joaat(color)) end
    w.blip = blip
end

---------------------------------------------------------------------
-- Zones (manager, crafting, stashes)
---------------------------------------------------------------------
local function removeZones(w)
    for _, z in ipairs(w.zones or {}) do exports['rsg-target']:removeZone(z, true) end
    w.zones = {}
end

local function zone(w, coords, options)
    w.zones[#w.zones + 1] = exports['rsg-target']:addSphereZone({
        coords = coords, radius = 1.2, debug = Config.Debug, options = options,
    })
end

local function makeZones(biz, w)
    removeZones(w)
    local id = biz.id
    if biz.points.manager then
        zone(w, v3(biz.points.manager), {
            { name = 'grumpy-pob:manage:' .. id, icon = 'fa-solid fa-briefcase', label = locale('target_manage'), distance = Config.InteractDistance,
              canInteract = function() return POBC.Live(id) and POBC.WorksAt(POBC.Live(id)) end,
              onSelect = function() POBC.OpenManager(id) end },
            { name = 'grumpy-pob:duty:' .. id, icon = 'fa-solid fa-clock', distance = Config.InteractDistance,
              label = locale('target_duty'),
              canInteract = function() local b = POBC.Live(id) return b and POBC.WorksAt(b) and b.owned end,
              onSelect = function() TriggerServerEvent('grumpy-pob:server:duty', id) end },
            { name = 'grumpy-pob:warrant:' .. id, icon = 'fa-solid fa-file-signature', distance = Config.InteractDistance,
              label = locale('target_books_warrant'),
              canInteract = function() local b = POBC.Live(id) return b and b.owned and POBC.IsLaw(true) end,
              onSelect = function() TriggerServerEvent('grumpy-pob:server:issueBooksWarrant', id) end },
            { name = 'grumpy-pob:audit:' .. id, icon = 'fa-solid fa-book-open', distance = Config.InteractDistance,
              label = locale('target_audit'),
              canInteract = function() local b = POBC.Live(id) return b and b.owned and POBC.IsLaw(false) end,
              onSelect = function() POBC.OpenAudit(id) end },
        })
    end
    for i, p in ipairs(biz.points.craft or {}) do
        zone(w, v3(p), {
            { name = ('grumpy-pob:craft:%d:%d'):format(id, i), icon = 'fa-solid fa-hammer', label = locale('target_craft'), distance = Config.InteractDistance,
              canInteract = function() local b = POBC.Live(id) return b and POBC.WorksAt(b) and b.owned end,
              onSelect = function() POBC.OpenCraft(id, i) end },
        })
    end
    for i, p in ipairs(biz.points.stash or {}) do
        zone(w, v3(p), {
            { name = ('grumpy-pob:stash:%d:%d'):format(id, i), icon = 'fa-solid fa-box-open', label = locale('target_stash'), distance = Config.InteractDistance,
              canInteract = function() local b = POBC.Live(id) return b and POBC.WorksAt(b) and b.owned end,
              onSelect = function() TriggerServerEvent('grumpy-pob:server:openStash', id, i) end },
        })
    end
end

---------------------------------------------------------------------
-- Ped + sign (spawned near the player only)
---------------------------------------------------------------------
local function despawn(w)
    if w.ped and DoesEntityExist(w.ped) then
        exports['rsg-target']:removeLocalEntity(w.ped)
        DeleteEntity(w.ped)
    end
    if w.sign and DoesEntityExist(w.sign) then
        exports['rsg-target']:removeLocalEntity(w.sign)
        DeleteEntity(w.sign)
    end
    w.ped, w.sign, w.pedModel = nil, nil, nil
end

local function spawnPed(biz, w)
    local p = biz.points.npc
    local hash = loadModel(biz.npcModel)
    if not hash then return end
    local ped = CreatePed(hash, p.x, p.y, p.z - 1.0, p.w or 0.0, false, false, 0, 0)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SET_RANDOM_OUTFIT_VARIATION
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    w.ped, w.pedModel = ped, biz.npcModel
    exports['rsg-target']:addLocalEntity(ped, POBC.NpcOptions(biz))
end

local function spawnSign(biz, w)
    local s = biz.points.sign
    local hash = loadModel(Config.SignModel)
    if not hash then return end
    local obj = CreateObject(hash, s.x, s.y, s.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(obj) then return end
    local yaw = (s.rz or 0.0) + (biz.owned and Config.SignOpenRotation or 0.0)
    SetEntityRotation(obj, s.rx or 0.0, s.ry or 0.0, yaw, 2, true)
    FreezeEntityPosition(obj, true)
    w.sign, w.signOwned = obj, biz.owned
    exports['rsg-target']:addLocalEntity(obj, POBC.SignOptions(biz))
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for id, biz in pairs(POBC.Businesses) do
            local w = POBC.world[id]
            if w and biz.points.npc then
                local near = #(pos - v3(biz.points.npc)) < Config.SpawnDistance
                if near then
                    if w.ped and (w.pedModel ~= biz.npcModel or not DoesEntityExist(w.ped)) then despawn(w) end
                    if w.sign and (w.signOwned ~= biz.owned or not DoesEntityExist(w.sign)) then
                        exports['rsg-target']:removeLocalEntity(w.sign)
                        DeleteEntity(w.sign)
                        w.sign = nil
                    end
                    if not w.ped then spawnPed(biz, w) end
                    if not w.sign and biz.points.sign then spawnSign(biz, w) end
                elseif w.ped or w.sign then
                    despawn(w)
                end
            end
        end
        Wait(1500)
    end
end)

---------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------
local function clearWorld(id)
    local w = POBC.world[id]
    if not w then return end
    despawn(w)
    removeZones(w)
    removeBlip(w)
    POBC.world[id] = nil
end

function POBC.RefreshEmployment()
    local list = RSGCore.Functions.AwaitCallback('grumpy-pob:server:myEmployment') or {}
    local out = {}
    for _, e in ipairs(list) do out[e.id] = e.grade end
    POBC.Employment = out
end

RegisterNetEvent('grumpy-pob:client:sync', function(list)
    local seen = {}
    for _, biz in ipairs(list or {}) do
        seen[biz.id] = true
        local old = POBC.Businesses[biz.id]
        POBC.Businesses[biz.id] = biz
        local w = POBC.world[biz.id]
        local moved = old and json.encode(old.points) ~= json.encode(biz.points)
        if w and (moved or old.type ~= biz.type) then clearWorld(biz.id) w = nil end
        if not w then
            w = { zones = {} }
            POBC.world[biz.id] = w
            makeZones(biz, w)
        elseif old and (old.label ~= biz.label or old.owned ~= biz.owned or old.price ~= biz.price) then
            despawn(w) -- options capture the label; respawn picks up the new ones
        end
        makeBlip(biz, w)
    end
    for id in pairs(POBC.Businesses) do
        if not seen[id] then clearWorld(id) POBC.Businesses[id] = nil end
    end
    CreateThread(POBC.RefreshEmployment)
end)

RegisterNetEvent('grumpy-pob:client:employmentChanged', function() CreateThread(POBC.RefreshEmployment) end)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function() CreateThread(POBC.RefreshEmployment) end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() TriggerServerEvent('grumpy-pob:server:requestSync') end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('grumpy-pob:server:requestSync') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(POBC.world) do clearWorld(id) end
    if POBC.uiOpen then SetNuiFocus(false, false) end
end)
