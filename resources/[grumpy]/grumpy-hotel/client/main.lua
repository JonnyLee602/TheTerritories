-- Hotel sync, door zones, blips, NUI bridge, door menu and the rental menu export.
local RSGCore = exports['rsg-core']:GetCoreObject()

-- Shared with client/room.lua and client/admin.lua
HotelList = {}                  -- [id] = { id, label, rooms, door = vector4, interior = vector4, blip }
IsAdmin   = false
UI        = { open = false, view = nil, knock = false }
InRoom    = nil                 -- { hotel, room, role, label, interior, voice } while inside a room

local zones, blips = {}, {}
local doorHotel = nil           -- hotel id whose door menu is open
local rentalKey, rentalPos = nil, nil

local function dbg(...) if Config.Debug then print('[grumpy-hotel]', ...) end end

function NotifyLocal(msg, ntype)
    RSGCore.Functions.Notify({ title = locale('title'), description = msg, type = ntype or 'inform', duration = 6000 })
end

---------------------------------------------------------------------
-- NUI bridge
---------------------------------------------------------------------
local UI_KEYS = {
    'ui_rooms', 'ui_room', 'ui_available', 'ui_your_room', 'ui_locked', 'ui_enter', 'ui_enter_yours', 'ui_enter_warrant',
    'ui_knock', 'ui_issue_warrant', 'ui_per_day', 'ui_max_days', 'ui_free_rooms', 'ui_days', 'ui_total', 'ui_rent',
    'ui_extend', 'ui_renew', 'ui_checkout', 'ui_confirm_checkout', 'ui_expires_in', 'ui_grace_in', 'ui_expired',
    'ui_extend_max', 'ui_key_holder', 'ui_no_key', 'ui_revoke', 'ui_confirm_revoke', 'ui_already_renting', 'ui_select_room',
    'ui_stash', 'ui_leave', 'ui_occupants', 'ui_nobody', 'ui_give_key', 'ui_show_out', 'ui_role_renter', 'ui_role_key',
    'ui_role_visitor', 'ui_role_law', 'ui_rented_by', 'ui_knocking', 'ui_let_in', 'ui_ignore', 'ui_seconds',
    'ui_admin_title', 'ui_new_hotel', 'ui_no_hotels', 'ui_edit', 'ui_renters', 'ui_tp_door', 'ui_tp_interior',
    'ui_delete', 'ui_confirm_delete', 'ui_back', 'ui_no_renters', 'ui_evict', 'ui_confirm_evict', 'ui_offline',
    'ui_inside', 'ui_editor_new', 'ui_editor_edit', 'ui_name', 'ui_room_count', 'ui_daily_rate', 'ui_max_days_label',
    'ui_blip', 'ui_door_point', 'ui_interior_point', 'ui_use_position', 'ui_not_set', 'ui_save', 'ui_cash',
    'ui_state_active', 'ui_state_grace', 'ui_key', 'ui_door_hint', 'ui_interior_hint',
}
local uiStrings
local function strings()
    if uiStrings then return uiStrings end
    uiStrings = {}
    for _, k in ipairs(UI_KEYS) do uiStrings[k] = locale(k) end
    return uiStrings
end

local function syncFocus()
    local want = UI.open or UI.knock
    SetNuiFocus(want, want)
end

function OpenUI(view, data)
    UI.open, UI.view = true, view
    syncFocus()
    SendNUIMessage({ action = 'open', view = view, data = data, strings = strings() })
end

function UpdateUI(view, data)
    if UI.open and UI.view == view then SendNUIMessage({ action = 'update', view = view, data = data }) end
end

function CloseUI()
    if not UI.open then return end
    UI.open, UI.view = false, nil
    doorHotel, rentalKey, rentalPos = nil, nil, nil
    syncFocus()
    SendNUIMessage({ action = 'close' })
end

function ShowKnock(data)
    UI.knock = true
    syncFocus()
    SendNUIMessage({ action = 'knock', data = data, strings = strings() })
end

function HideKnock(id)
    if not UI.knock then return end
    UI.knock = false
    syncFocus()
    SendNUIMessage({ action = 'knockClose', id = id })
end

RegisterNUICallback('close', function(_, cb) CloseUI(); cb('ok') end)

---------------------------------------------------------------------
-- Helpers: animation, teleport
---------------------------------------------------------------------
local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then dbg('anim dict failed to load', dict) return false end
        Wait(10)
    end
    return true
end

function PlayAnim(dict, clip, duration)
    local ped = PlayerPedId()
    if not loadDict(dict) then return end
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, duration, 0, 0.0, false, 0, false, '', false)
    Wait(duration)
    StopAnimTask(ped, dict, clip, 1.0)
    RemoveAnimDict(dict)
end

function FaceHeading(heading)
    if heading then SetEntityHeading(PlayerPedId(), heading + 0.0) end
end

-- Fades, moves the ped and waits for the interior / collision to stream (same approach as rsg-character spawn)
function TeleportTo(pos, keepFaded)
    local ped = PlayerPedId()
    if not IsScreenFadedOut() then
        DoScreenFadeOut(500)
        local t = GetGameTimer() + 2000
        while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
    end
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    FreezeEntityPosition(ped, true)
    local interior = GetInteriorAtCoords(pos.x, pos.y, pos.z)
    if interior ~= 0 and IsValidInterior(interior) then
        PinInteriorInMemory(interior)
        local t = GetGameTimer() + 8000
        while not IsInteriorReady(interior) and GetGameTimer() < t do
            RequestCollisionAtCoord(pos.x, pos.y, pos.z)
            Wait(50)
        end
    end
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    local t = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        Wait(50)
    end
    SetEntityCoords(ped, pos.x, pos.y, pos.z - 1.0, false, false, false, false)
    if pos.w then SetEntityHeading(ped, pos.w + 0.0) end
    if interior ~= 0 then UnpinInterior(interior) end
    FreezeEntityPosition(ped, false)
    if not keepFaded then DoScreenFadeIn(800) end
end

---------------------------------------------------------------------
-- Door menu (outside interaction point)
---------------------------------------------------------------------
local function fetchDoor(id) return RSGCore.Functions.AwaitCallback('grumpy-hotel:server:getDoor', nil, id) end

local function watchDistance(view, pos, dist)
    CreateThread(function()
        while UI.open and UI.view == view do
            if #(GetEntityCoords(PlayerPedId()) - pos) > dist then CloseUI() break end
            Wait(500)
        end
    end)
end

function OpenDoor(id)
    if UI.open or InRoom then return end
    local h = HotelList[id]
    if not h then return end
    local data = fetchDoor(id)
    if not data then return end
    doorHotel = id
    OpenUI('door', data)
    watchDistance('door', vector3(h.door.x, h.door.y, h.door.z), Config.DoorRadius + 3.0)
end

local function refreshDoor()
    if not (UI.open and UI.view == 'door' and doorHotel) then return end
    local data = fetchDoor(doorHotel)
    if data then UpdateUI('door', data) else CloseUI() end
end

local entering = false
RegisterNUICallback('doorEnter', function(body, cb)
    cb('ok')
    local id, room = doorHotel, type(body) == 'table' and math.tointeger(tonumber(body.room)) or nil
    if not id or not room or entering then return end
    CloseUI()
    CreateThread(function()
        entering = true
        if RSGCore.Functions.AwaitCallback('grumpy-hotel:server:canEnter', nil, id, room) then
            local h = HotelList[id]
            local a = Config.Anims.unlock
            FaceHeading(h and h.door.w)
            PlayAnim(a.dict, IsPedMale(PlayerPedId()) and a.male or a.female, a.duration)
            DoScreenFadeOut(500)
            local t = GetGameTimer() + 2000
            while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
            TriggerServerEvent('grumpy-hotel:server:enter', id, room)
            -- the server answers with grumpy-hotel:client:entered; fade back in if it refused
            local deadline = GetGameTimer() + 6000
            while not InRoom and GetGameTimer() < deadline do Wait(100) end
            if not InRoom then DoScreenFadeIn(500) end
        end
        entering = false
    end)
end)

RegisterNUICallback('doorKnock', function(body, cb)
    cb('ok')
    local id, room = doorHotel, type(body) == 'table' and math.tointeger(tonumber(body.room)) or nil
    if not id or not room then return end
    CloseUI()
    TriggerServerEvent('grumpy-hotel:server:knock', id, room)
    CreateThread(function()
        local h = HotelList[id]
        FaceHeading(h and h.door.w)
        PlayAnim(Config.Anims.knock.dict, Config.Anims.knock.clip, Config.Anims.knock.duration)
    end)
end)

RegisterNUICallback('doorWarrant', function(body, cb)
    cb('ok')
    local id, room = doorHotel, type(body) == 'table' and math.tointeger(tonumber(body.room)) or nil
    if not id or not room then return end
    TriggerServerEvent('grumpy-hotel:server:issueWarrant', id, room)
    SetTimeout(800, function() CreateThread(refreshDoor) end)
end)

---------------------------------------------------------------------
-- Rental menu (opened by grumpy-bartender / saloon scripts through the OpenRental export)
---------------------------------------------------------------------
local function fetchRental(key) return RSGCore.Functions.AwaitCallback('grumpy-hotel:server:getRental', nil, key) end

function OpenRental(key)
    if UI.open or InRoom or type(key) ~= 'string' then return false end
    local data = fetchRental(key)
    if not data then return false end
    rentalKey, rentalPos = key, GetEntityCoords(PlayerPedId())
    OpenUI('rental', data)
    watchDistance('rental', rentalPos, Config.RentalDistance + 3.0)
    return true
end
exports('OpenRental', function(key) CreateThread(function() OpenRental(key) end) end)

RegisterNetEvent('grumpy-hotel:client:rentalRefresh', function()
    if not (UI.open and UI.view == 'rental' and rentalKey) then return end
    local data = fetchRental(rentalKey)
    if data then UpdateUI('rental', data) else CloseUI() end
end)

RegisterNUICallback('rentalRent', function(body, cb)
    cb('ok')
    if not rentalKey or type(body) ~= 'table' then return end
    TriggerServerEvent('grumpy-hotel:server:rent', rentalKey, tonumber(body.room), tonumber(body.days))
end)

RegisterNUICallback('rentalExtend', function(body, cb)
    cb('ok')
    if not rentalKey or type(body) ~= 'table' then return end
    TriggerServerEvent('grumpy-hotel:server:extend', rentalKey, tonumber(body.days))
end)

RegisterNUICallback('rentalCheckout', function(_, cb)
    cb('ok')
    if rentalKey then TriggerServerEvent('grumpy-hotel:server:checkout', rentalKey) end
end)

RegisterNUICallback('rentalRevokeKey', function(_, cb)
    cb('ok')
    if rentalKey then TriggerServerEvent('grumpy-hotel:server:rentalRevokeKey', rentalKey) end
end)

---------------------------------------------------------------------
-- Door zones + blips
---------------------------------------------------------------------
local function clearWorld()
    for _, z in ipairs(zones) do pcall(function() exports['rsg-target']:removeZone(z) end) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    zones, blips = {}, {}
end

local function buildWorld()
    clearWorld()
    for id, h in pairs(HotelList) do
        zones[#zones + 1] = exports['rsg-target']:addSphereZone({
            coords = vector3(h.door.x, h.door.y, h.door.z),
            radius = Config.DoorRadius,
            debug = Config.Debug,
            options = {
                { name = 'grumpy-hotel:door:' .. id, icon = 'fa-solid fa-door-closed', label = locale('opt_door'),
                  distance = Config.DoorRadius + 1.0, canInteract = function() return InRoom == nil end,
                  onSelect = function() CreateThread(function() OpenDoor(id) end) end },
            },
        })
        if h.blip then
            local blip = BlipAddForCoords(1664425300, h.door.x, h.door.y, h.door.z) -- 1664425300 = default coords blip style
            SetBlipSprite(blip, joaat(Config.Blip.sprite), true)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipName(blip, h.label)
            blips[#blips + 1] = blip
        end
    end
end

local function applyList(list)
    local byId = {}
    for _, h in ipairs(list or {}) do
        h.door = vector4(h.door.x, h.door.y, h.door.z, h.door.w)
        h.interior = vector4(h.interior.x, h.interior.y, h.interior.z, h.interior.w)
        byId[h.id] = h
    end
    HotelList = byId
    buildWorld()
    if UI.open and UI.view == 'door' and doorHotel and not HotelList[doorHotel] then CloseUI() end
    if AdminRefresh then CreateThread(AdminRefresh) end
end

RegisterNetEvent('grumpy-hotel:client:sync', applyList)

local function requestAll()
    local res = RSGCore.Functions.AwaitCallback('grumpy-hotel:server:getHotels')
    if not res then return end
    IsAdmin = res.isAdmin == true
    applyList(res.hotels)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() CreateThread(requestAll) end)
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then requestAll() end
end)

-- Client-side list for other resources (e.g. the bartender editor's hotel dropdown)
exports('GetHotels', function()
    local out = {}
    for id, h in pairs(HotelList) do out[#out + 1] = { id = id, label = h.label, rooms = h.rooms } end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearWorld()
    if UI.open or UI.knock then SetNuiFocus(false, false) end
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(0) end
end)
