-- Register hold-up (aim at the clerk) and the optional safe.

local R, S = Config.Robbery, Config.Safe
local robbing = nil    -- { storeId, endsAt, grace, lowSince }
local lastAsk = 0

-----------------------------------------------------------------------
-- aim detection
-----------------------------------------------------------------------
local function aimedClerk()
    local pid = PlayerId()
    if not IsPlayerFreeAiming(pid) then return nil end
    local ok, ent = GetEntityPlayerIsFreeAimingAt(pid)
    if not ok or not ent or ent == 0 or not IsEntityAPed(ent) or IsPedAPlayer(ent) then return nil end
    return ent
end

CreateThread(function()
    while true do
        local wait = 1000
        if R.Enabled and #GRC.Stores > 0 then
            local pos = GetEntityCoords(PlayerPedId())
            local near = false
            for _, s in ipairs(GRC.Stores) do
                if s.enabled and #(pos - s.coords) < 25.0 then near = true break end
            end
            if near then
                wait = 250
                local ped = aimedClerk()
                if robbing then
                    local store = GRC.ById[robbing.storeId]
                    local clerk = store and GRC.FindClerk(store)
                    if ped and clerk and ped == clerk then
                        robbing.lowSince = nil
                    else
                        robbing.lowSince = robbing.lowSince or GetGameTimer()
                        if GetGameTimer() - robbing.lowSince > robbing.grace * 1000 then
                            TriggerServerEvent('grumpy-robbery:server:abortRobbery', robbing.storeId)
                            robbing.lowSince = GetGameTimer() + 60000 -- don't spam while the server answers
                        end
                    end
                    local left = math.max(0, math.ceil((robbing.endsAt - GetGameTimer()) / 1000))
                    GRC.Notify(locale('rob_progress', left), 'warning', 'grumpy-robbery-progress')
                    wait = 1000
                elseif ped and GetGameTimer() - lastAsk > 3000 then
                    local store = GRC.StoreForClerk(ped)
                    if store and store.enabled and #(pos - store.coords) <= R.AimDistance then
                        lastAsk = GetGameTimer()
                        TriggerServerEvent('grumpy-robbery:server:startRobbery', store.id)
                    end
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('grumpy-robbery:client:robberyStarted', function(storeId, duration, grace)
    robbing = { storeId = storeId, endsAt = GetGameTimer() + duration * 1000, grace = grace }
end)

RegisterNetEvent('grumpy-robbery:client:robberyEnded', function(storeId)
    if robbing and robbing.storeId == storeId then robbing = nil end
end)

-----------------------------------------------------------------------
-- safes: target zone (+ optional local prop) per store, usable while the server says it's open for you
-----------------------------------------------------------------------
local safeZones, safeProps, safeOpenUntil = {}, {}, {}
local cracking = false

RegisterNetEvent('grumpy-robbery:client:safeOpen', function(storeId, seconds)
    safeOpenUntil[storeId] = GetGameTimer() + seconds * 1000
end)

local function crackSafe(store)
    if cracking then return end
    cracking = true
    local ok, msg = RSGCore.Functions.AwaitCallback('grumpy-robbery:server:safeStart', 5000, store.id)
    if not ok then
        cracking = false
        if msg then GRC.Notify(msg, 'error') end
        return
    end

    local success = false
    if GetResourceState('rsg-lockpick') == 'started' then
        local done = false
        TriggerEvent('rsg-lockpick:client:openLockpick', function(result) success, done = result == true, true end)
        local timeout = GetGameTimer() + 60000
        while not done and GetGameTimer() < timeout do Wait(100) end
    else
        -- no minigame: wait out the bar, the server rolls the result
        success = RSGCore.Functions.ProgressBar({
            duration = S.CrackTime, label = locale('safe_progress'), useWhileDead = false, canCancel = true,
            disable = { move = true, sprint = true, mount = true, combat = true },
        })
        if not success then
            TriggerServerEvent('grumpy-robbery:server:safeCancel') -- walked away: not a failed attempt
            cracking = false
            return
        end
    end
    TriggerServerEvent('grumpy-robbery:server:safeResult', success)
    cracking = false
end

local function clearSafes()
    for _, id in pairs(safeZones) do exports['rsg-target']:removeZone(id) end
    for _, obj in pairs(safeProps) do if DoesEntityExist(obj) then DeleteObject(obj) end end
    safeZones, safeProps = {}, {}
end

local function buildSafes()
    clearSafes()
    if not S.Enabled then return end
    for _, s in ipairs(GRC.Stores) do
        if s.safe then
            local store = s
            safeZones[s.id] = exports['rsg-target']:addSphereZone({
                coords = vector3(s.safe.x, s.safe.y, s.safe.z), radius = 1.0, debug = Config.Debug,
                options = {{
                    name = 'grumpy-robbery:safe:' .. s.id, icon = 'fa-solid fa-vault', label = locale('target_safe'),
                    distance = S.Distance,
                    canInteract = function() return (safeOpenUntil[store.id] or 0) > GetGameTimer() and not cracking end,
                    onSelect = function() CreateThread(function() crackSafe(store) end) end,
                }},
            })
        end
    end
end
GRC.OnStores(buildSafes)

-- local safe props near the player
CreateThread(function()
    local hash = joaat(S.PropModel)
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, s in ipairs(GRC.Stores) do
            local safe = s.safe
            local want = S.Enabled and safe and safe.prop and #(pos - vector3(safe.x, safe.y, safe.z)) < 50.0
            if want and not safeProps[s.id] then
                RequestModel(hash, false)
                local t = GetGameTimer() + 5000
                while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(50) end
                if HasModelLoaded(hash) then
                    local obj = CreateObject(hash, safe.x, safe.y, safe.z, false, false, false, false, false)
                    SetEntityCoordsNoOffset(obj, safe.x, safe.y, safe.z, false, false, false) -- match rsg-gizmo's placed coords (no model offset)
                    if safe.rx then SetEntityRotation(obj, safe.rx, safe.ry, safe.rz, 2, true) else SetEntityHeading(obj, safe.h or 0.0) end
                    FreezeEntityPosition(obj, true)
                    SetModelAsNoLongerNeeded(hash)
                    safeProps[s.id] = obj
                end
            elseif not want and safeProps[s.id] then
                if DoesEntityExist(safeProps[s.id]) then DeleteObject(safeProps[s.id]) end
                safeProps[s.id] = nil
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearSafes() end
end)
