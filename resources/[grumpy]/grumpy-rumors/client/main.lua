local RSGCore = exports['rsg-core']:GetCoreObject()

local peds = {}       -- [informantId] = ped
local marks = {}      -- list of { blip, untilTime }
local reading = nil   -- { slot, serial } of the open note

-----------------------------------------------------------------------
-- informant peds (local, spawned by distance)
-----------------------------------------------------------------------
local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    return HasModelLoaded(hash)
end

local function spawnInformant(inf)
    local hash = joaat(inf.model)
    if not loadModel(hash) then
        return print(('[grumpy-rumors] invalid model for informant %s'):format(inf.id))
    end
    local c = inf.coords
    local ped = CreatePed(hash, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if inf.scenario then TaskStartScenarioInPlace(ped, joaat(inf.scenario), 0, true, false, false, false) end

    exports['rsg-target']:addLocalEntity(ped, {
        {
            name = 'grumpy-rumors:ask:' .. inf.id,
            icon = 'fa-solid fa-comment-dots',
            label = (inf.price or 0) > 0 and locale('target_ask_price', inf.price) or locale('target_ask'),
            distance = Config.AskDistance,
            onSelect = function() TriggerServerEvent('grumpy-rumors:server:ask', inf.id) end,
        },
    })
    peds[inf.id] = ped
end

local function despawnInformant(id)
    local ped = peds[id]
    peds[id] = nil
    if ped and DoesEntityExist(ped) then
        exports['rsg-target']:removeLocalEntity(ped)
        DeletePed(ped)
    end
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local nearest = 9999.0
        for _, inf in ipairs(Config.Informants) do
            if inf.enabled then
                local dist = #(pos - inf.coords.xyz)
                nearest = math.min(nearest, dist)
                if dist <= Config.SpawnDistance and not peds[inf.id] then spawnInformant(inf)
                elseif dist > Config.SpawnDistance + 10.0 and peds[inf.id] then despawnInformant(inf.id) end
            end
        end
        Wait(nearest < Config.SpawnDistance + 50.0 and 1000 or 4000)
    end
end)

-----------------------------------------------------------------------
-- reading a note
-----------------------------------------------------------------------
local function strings()
    local t = {}
    for _, k in ipairs({ 'ui_subtitle', 'ui_good_for', 'ui_act', 'ui_put_away', 'ui_flavour' }) do t[k] = locale(k) end
    return t
end

local function closeNote()
    if not reading then return end
    reading = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('grumpy-rumors:client:read', function(data)
    if type(data) ~= 'table' then return end
    reading = { slot = data.slot, serial = data.serial }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data, locale = strings() })
end)

RegisterNUICallback('close', function(_, cb) closeNote(); cb('ok') end)

RegisterNUICallback('act', function(_, cb)
    if reading then TriggerServerEvent('grumpy-rumors:server:act', reading.slot, reading.serial) end
    closeNote()
    cb('ok')
end)

-----------------------------------------------------------------------
-- built-in 'mark' job type: a timed search-area blip
-----------------------------------------------------------------------
RegisterNetEvent('grumpy-rumors:client:mark', function(d)
    if type(d) ~= 'table' or not d.coords then return end
    local c = d.coords
    local blip = BlipAddForRadius(joaat(Config.BuiltinMark.style), c.x, c.y, c.z, d.radius + 0.0) -- BLIP_ADD_FOR_RADIUS
    SetBlipName(blip, d.label or '')
    marks[#marks + 1] = { blip = blip, untilTime = GetGameTimer() + (d.duration * 1000) }
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for i = #marks, 1, -1 do
            if now >= marks[i].untilTime then
                if DoesBlipExist(marks[i].blip) then RemoveBlip(marks[i].blip) end
                table.remove(marks, i)
            end
        end
    end
end)

-----------------------------------------------------------------------
-- cleanup
-----------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(peds) do despawnInformant(id) end
    for _, m in ipairs(marks) do if DoesBlipExist(m.blip) then RemoveBlip(m.blip) end end
    if reading then SetNuiFocus(false, false) end
end)
