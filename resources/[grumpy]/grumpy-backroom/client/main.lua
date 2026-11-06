local RSGCore = exports['rsg-core']:GetCoreObject()
local MenuData = exports['rsg-menubase']:GetMenuData()

BR = { MenuData = MenuData, RSGCore = RSGCore } -- shared with client/admin.lua

local Rooms = {}       -- from GlobalState.grumpyBackrooms
local spawned = {}     -- [roomId] = { ped, sig }
local roomZones = {}   -- [roomId] = rsg-core zone

function BR.Notify(key, ntype, ...)
    RSGCore.Functions.Notify({ title = locale('title'), description = locale(key, ...), type = ntype or 'inform', duration = 6000 })
end

function BR.Await(name, ...)
    return RSGCore.Functions.AwaitCallback(name, 10000, ...)
end

local function fmtLeft(secs)
    local m = math.floor(secs / 60)
    if m >= 60 then return locale('time_hm', m // 60, m % 60) end
    if m >= 1 then return locale('time_m', m) end
    return locale('time_s', secs)
end
BR.FmtLeft = fmtLeft

---------------------------------------------
-- the bribe menu
---------------------------------------------
local function openBribe(roomId)
    local q = BR.Await('grumpy-backroom:server:quote', roomId)
    if not q then return end
    local elements = {}
    for i, o in ipairs(q.options) do
        local fits = q.left + o.minutes * 60 <= q.max
        elements[#elements + 1] = {
            label = locale('menu_option', o.minutes, o.price),
            value = fits and i or 'full',
            desc = fits and locale('menu_option_desc') or locale('menu_option_full'),
        }
    end
    elements[#elements + 1] = { label = locale('menu_leave'), value = 'leave', desc = '' }
    MenuData.CloseAll()
    MenuData.Open('default', GetCurrentResourceName(), 'bribe', {
        title = q.name,
        subtext = q.left > 0 and locale('menu_open_for', fmtLeft(q.left)) or locale('menu_locked'),
        align = 'top-left',
        elements = elements,
    }, function(data, menu)
        local v = data.current.value
        if v == 'full' then return BR.Notify('too_long', 'error', math.floor(q.left / 60)) end
        menu.close()
        if type(v) == 'number' then TriggerServerEvent('grumpy-backroom:server:bribe', roomId, v) end
    end, function(_, menu)
        menu.close()
    end)
end

---------------------------------------------
-- doormen
---------------------------------------------
local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

local function fade(ped, from, to, step)
    for i = from, to, step do
        if not DoesEntityExist(ped) then return end
        SetEntityAlpha(ped, i, false)
        Wait(50)
    end
end

local function spawnPed(room)
    local hash = joaat(room.model or Config.Npc.model)
    if not loadModel(hash) then
        if Config.Debug then print(('[grumpy-backroom] invalid model %s for room %d'):format(room.model, room.id)) end
        return
    end
    local n = room.npc
    -- n is standing coords (peds spawn at z - 1.0), like grumpy-trader / grumpy-pob
    local ped = CreatePed(hash, n.x, n.y, n.z - 1.0, n.w or 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    if Config.Npc.scenario then
        TaskStartScenarioInPlace(ped, joaat(Config.Npc.scenario), -1, true, false, false, false)
    end
    exports['rsg-target']:addLocalEntity(ped, {
        {
            name = 'grumpy_backroom_bribe',
            icon = 'fa-solid fa-sack-dollar',
            label = locale('target_bribe'),
            distance = Config.InteractDistance,
            onSelect = function() openBribe(room.id) end,
        },
    })
    if Config.Npc.fadeIn then
        SetEntityAlpha(ped, 0, false)
        CreateThread(function() fade(ped, 0, 255, 51) end)
    end
    return ped
end

local function despawnPed(ped)
    if not ped or not DoesEntityExist(ped) then return end
    exports['rsg-target']:removeLocalEntity(ped, { 'grumpy_backroom_bribe' })
    if Config.Npc.fadeIn then
        CreateThread(function()
            fade(ped, 255, 0, -51)
            DeletePed(ped)
        end)
    else
        DeletePed(ped)
    end
end

-- a room's identity: if the doorman's model or spot changes, he is respawned
local function signature(r)
    return ('%s|%.2f|%.2f|%.2f|%.1f'):format(r.model, r.npc.x, r.npc.y, r.npc.z, r.npc.w or 0.0)
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local active = {}
        for _, r in ipairs(Rooms) do
            local sig = signature(r)
            local s = spawned[r.id]
            local inRange = #(me - vector3(r.npc.x, r.npc.y, r.npc.z)) < Config.Npc.spawnDistance
            active[r.id] = true
            if s and (not inRange or s.sig ~= sig) then
                despawnPed(s.ped)
                spawned[r.id], s = nil, nil
            end
            if inRange and not s then
                local ped = spawnPed(r)
                if ped then spawned[r.id] = { ped = ped, sig = sig } end
            end
        end
        for id, s in pairs(spawned) do
            if not active[id] then
                despawnPed(s.ped)
                spawned[id] = nil
            end
        end
        Wait(1000)
    end
end)

---------------------------------------------
-- walking in: say how long is left
---------------------------------------------
local function buildZones()
    for _, z in pairs(roomZones) do z:remove() end
    roomZones = {}
    for _, r in ipairs(Rooms) do
        local pts = {}
        local mid = (r.zone.minZ + r.zone.maxZ) / 2
        for i, p in ipairs(r.zone.points) do pts[i] = vec3(p.x, p.y, mid) end
        local z = zones.poly({
            points = pts,
            thickness = r.zone.maxZ - r.zone.minZ,
            onEnter = function()
                CreateThread(function()
                    local left = BR.Await('grumpy-backroom:server:timeLeft', r.id) or 0
                    if left > 0 then BR.Notify('enter_left', 'inform', fmtLeft(left)) end
                end)
            end,
        })
        z.minZ, z.maxZ = r.zone.minZ, r.zone.maxZ
        roomZones[r.id] = z
    end
end

local function setRooms(list)
    Rooms = {}
    for _, r in ipairs(list or {}) do
        if r.npc and BackroomZone.Valid(r.zone) then Rooms[#Rooms + 1] = r end
    end
    buildZones()
end

AddStateBagChangeHandler('grumpyBackrooms', 'global', function(_, _, value)
    setRooms(value)
end)

CreateThread(function()
    setRooms(GlobalState.grumpyBackrooms)
end)

---------------------------------------------
-- closing time: shown out
---------------------------------------------
RegisterNetEvent('grumpy-backroom:client:showOut', function(exit)
    if type(exit) ~= 'table' or not exit.x then return end
    MenuData.CloseAll()
    DoScreenFadeOut(600)
    local deadline = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(10) end
    if GetResourceState('grumpy-sit') == 'started' then
        pcall(function() if exports['grumpy-sit']:IsSeated() then exports['grumpy-sit']:Stand() end end)
    end
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, exit.x + 0.0, exit.y + 0.0, exit.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, (exit.w or 0.0) + 0.0)
    Wait(500)
    DoScreenFadeIn(800)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id, s in pairs(spawned) do
        if DoesEntityExist(s.ped) then DeletePed(s.ped) end
        spawned[id] = nil
    end
    MenuData.CloseAll()
end)
