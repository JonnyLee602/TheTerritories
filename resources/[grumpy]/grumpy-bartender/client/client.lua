local RSGCore = exports['rsg-core']:GetCoreObject()

-- Shared with client/placement.lua and client/hotel.lua
BartenderList = {}      -- [id] = bartender record from the server
SpawnedPeds   = {}      -- [id] = ped handle
IsAdmin       = false
UI            = { open = false, view = nil }

local spawning = {}     -- [id] = true while the model loads
local signatures = {}   -- [id] = string, respawn when it changes
local blips = {}

local function dbg(...) if Config.Debug then print('[grumpy-bartender]', ...) end end

function NotifyLocal(msg, ntype)
    RSGCore.Functions.Notify({ title = locale('title'), description = msg, type = ntype or 'inform', duration = 5000 })
end

function BartenderPos(b) return vector3(b.x, b.y, b.z) end

---------------------------------------------------------------------
-- NUI bridge (hotel, editor and manager views live in one page)
---------------------------------------------------------------------
local UI_KEYS = {
    'ui_manager_title', 'ui_search', 'ui_new_bartender', 'ui_static',
    'ui_services_none', 'ui_edit', 'ui_teleport', 'ui_duplicate', 'ui_no_bartenders',
    'ui_place_here', 'ui_move_here', 'ui_back',
    'ui_svc_store', 'ui_svc_hotel', 'ui_svc_lottery', 'ui_svc_loyalty', 'ui_create_shop', 'ui_create_shop_new', 'ui_store_auto',
    'ui_close', 'ui_editor_new', 'ui_editor_edit', 'ui_label', 'ui_model', 'ui_animation',
    'ui_services', 'ui_store_id', 'ui_store_hint', 'ui_hotel', 'ui_hotel_hint', 'ui_none', 'ui_lottery', 'ui_loyalty', 'ui_blip',
    'ui_place', 'ui_save', 'ui_move', 'ui_delete', 'ui_confirm_delete', 'ui_cancel',
}
local uiStrings
local function strings()
    if uiStrings then return uiStrings end
    uiStrings = {}
    for _, k in ipairs(UI_KEYS) do uiStrings[k] = locale(k) end
    return uiStrings
end

function OpenUI(view, data)
    UI.open, UI.view = true, view
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', view = view, data = data, strings = strings() })
end

function UpdateUI(view, data)
    if UI.open and UI.view == view then SendNUIMessage({ action = 'update', view = view, data = data }) end
end

function CloseUI()
    if not UI.open then return end
    UI.open, UI.view = false, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb) CloseUI(); cb('ok') end)

---------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------
function PlayAnimation(ped, animKey)
    local anim = Config.Animations[animKey] or Config.Animations[Config.DefaultAnimation]
    if not anim or not DoesEntityExist(ped) then return end
    ClearPedTasksImmediately(ped)
    if anim.type == 'scenario' then
        TaskStartScenarioInPlace(ped, joaat(anim.name), 0, true)
    elseif anim.type == 'anim' then
        RequestAnimDict(anim.dict)
        local deadline = GetGameTimer() + 5000
        while not HasAnimDictLoaded(anim.dict) do
            if GetGameTimer() > deadline then return dbg('anim dict failed to load', anim.dict) end
            Wait(10)
        end
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag or 1, 0.0, false, 0, false, '', false)
    end
end

---------------------------------------------------------------------
-- Services (integrations)
---------------------------------------------------------------------
local function started(res) return GetResourceState(res) == 'started' end

local function openStore(b)
    if not started('rsg-stores') then return NotifyLocal(locale('service_unavailable'), 'error') end
    local ok = pcall(function() exports['rsg-stores']:OpenShop(b.services.store, BartenderPos(b)) end)
    if not ok then NotifyLocal(locale('service_unavailable'), 'error') end
end

local function openLottery()
    if not started('rsg-lottery') then return NotifyLocal(locale('service_unavailable'), 'error') end
    local ok = pcall(function() exports['rsg-lottery']:OpenLottery() end)
    if not ok then NotifyLocal(locale('service_unavailable'), 'error') end
end

local function openLoyalty(b)
    if not started('rsg-loyalty') then return NotifyLocal(locale('service_unavailable'), 'error') end
    TriggerEvent('rsg-loyalty:client:openloyaltyUI', BartenderPos(b))
end

local function buildOptions(b)
    local id, opts = b.id, {}
    local function current() return BartenderList[id] end
    local s = b.services
    if s.store then
        opts[#opts + 1] = { name = 'grumpy-bartender:store', icon = 'fa-solid fa-beer-mug-empty', label = locale('opt_store'),
            distance = Config.TargetDistance, canInteract = function() return started('rsg-stores') end,
            onSelect = function() local c = current() if c then openStore(c) end end }
    end
    if s.hotel then
        -- grumpy-hotel owns the rental menu; the server registered this bartender as a rental point
        opts[#opts + 1] = { name = 'grumpy-bartender:hotel', icon = 'fa-solid fa-bed', label = locale('opt_hotel'),
            distance = Config.TargetDistance, canInteract = function() return started('grumpy-hotel') end,
            onSelect = function()
                local ok = pcall(function() exports['grumpy-hotel']:OpenRental('grumpy-bartender:' .. id) end)
                if not ok then NotifyLocal(locale('service_unavailable'), 'error') end
            end }
    end
    if s.lottery then
        opts[#opts + 1] = { name = 'grumpy-bartender:lottery', icon = 'fa-solid fa-ticket', label = locale('opt_lottery'),
            distance = Config.TargetDistance, canInteract = function() return started('rsg-lottery') end,
            onSelect = openLottery }
    end
    if s.loyalty then
        opts[#opts + 1] = { name = 'grumpy-bartender:loyalty', icon = 'fa-solid fa-star', label = locale('opt_loyalty'),
            distance = Config.TargetDistance, canInteract = function() return started('rsg-loyalty') end,
            onSelect = function() local c = current() if c then openLoyalty(c) end end }
    end
    if not b.static then
        opts[#opts + 1] = { name = 'grumpy-bartender:manage', icon = 'fa-solid fa-gear', label = locale('opt_manage'),
            distance = Config.TargetDistance, canInteract = function() return IsAdmin end,
            onSelect = function() local c = current() if c then OpenEditor(c) end end }
    end
    return opts
end

---------------------------------------------------------------------
-- Ped spawning (local peds, distance-gated)
---------------------------------------------------------------------
local function signature(b)
    local s = b.services
    return ('%s|%s|%.2f|%.2f|%.2f|%.1f|%s|%s|%s|%s|%s|%s'):format(b.model, b.animation, b.x, b.y, b.z, b.h, b.label,
        tostring(s.store), tostring(s.hotel), tostring(s.lottery), tostring(s.loyalty), tostring(s.blip))
end

function DespawnBartender(id)
    spawning[id] = nil
    local ped = SpawnedPeds[id]
    SpawnedPeds[id] = nil
    if ped and DoesEntityExist(ped) then
        pcall(function() exports['rsg-target']:removeLocalEntity(ped) end)
        DeleteEntity(ped)
    end
end

local function spawnBartender(b)
    local id = b.id
    if spawning[id] or SpawnedPeds[id] then return end
    spawning[id] = true
    local hash = joaat(b.model)
    if not IsModelValid(hash) then
        print(('^1[grumpy-bartender]^7 invalid ped model for %s: %s'):format(id, b.model))
        return -- keep spawning[id] set so we don't retry every tick
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then spawning[id] = nil return end
        Wait(10)
    end
    -- removed, changed or walked away while the model loaded
    if not spawning[id] or not BartenderList[id] or signatures[id] ~= signature(b) then
        SetModelAsNoLongerNeeded(hash)
        spawning[id] = nil
        return
    end

    local ped = CreatePed(hash, b.x, b.y, b.z - 1.0, b.h, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    spawning[id] = nil
    if not ped or ped == 0 then return end

    SetRandomOutfitVariation(ped, true) -- RedM: otherwise peds can spawn invisible
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    PlayAnimation(ped, b.animation)
    exports['rsg-target']:addLocalEntity(ped, buildOptions(b))
    SpawnedPeds[id] = ped
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local nearest = math.huge
        for id, b in pairs(BartenderList) do
            local dist = #(pos - BartenderPos(b))
            if dist < nearest then nearest = dist end
            if dist <= Config.SpawnDistance then
                if not SpawnedPeds[id] and not spawning[id] and not (PlacementBusy and PlacementBusy(id)) then
                    CreateThread(function() spawnBartender(b) end)
                end
            elseif SpawnedPeds[id] or spawning[id] then
                DespawnBartender(id)
            end
        end
        Wait(nearest > Config.SpawnDistance * 3 and 3000 or 1000)
    end
end)

---------------------------------------------------------------------
-- Blips
---------------------------------------------------------------------
local function rebuildBlips()
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    blips = {}
    for _, b in pairs(BartenderList) do
        if b.services.blip then
            local blip = BlipAddForCoords(1664425300, b.x, b.y, b.z) -- 1664425300 = default coords blip style
            SetBlipSprite(blip, joaat(Config.Blip.sprite), true)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipName(blip, b.label)
            blips[#blips + 1] = blip
        end
    end
end

---------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------
local function applyList(list)
    local newById = {}
    for _, b in ipairs(list or {}) do newById[b.id] = b end
    for id in pairs(BartenderList) do
        if not newById[id] or signatures[id] ~= signature(newById[id]) then DespawnBartender(id) end
    end
    BartenderList, signatures = newById, {}
    for id, b in pairs(newById) do signatures[id] = signature(b) end
    rebuildBlips()
    if UI.open and UI.view == 'editor' and EditorTarget and not BartenderList[EditorTarget] then CloseUI() end
    if UI.open and UI.view == 'manager' and ManagerRefresh then CreateThread(ManagerRefresh) end
end

RegisterNetEvent('grumpy-bartender:client:sync', applyList)

local function requestAll()
    local res = RSGCore.Functions.AwaitCallback('grumpy-bartender:server:getAll')
    if not res then return end
    IsAdmin = res.isAdmin == true
    applyList(res.bartenders)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() CreateThread(requestAll) end)

CreateThread(function()
    if LocalPlayer.state.isLoggedIn then requestAll() end
end)

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if UI.open then SetNuiFocus(false, false) end
    for id in pairs(SpawnedPeds) do DespawnBartender(id) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)
