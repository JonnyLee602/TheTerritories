local RSGCore = exports['rsg-core']:GetCoreObject()

local OPTION_NAME = 'grumpy-sit:sit'

local seatTypes = {}   -- model hash -> resolved seat definition { scenario = hash, spots = {}, heading = n }
local modelList = {}   -- model names registered with rsg-target
local seated = nil     -- { entity, spot = vector3, heading } while the player is sitting
local textShown = false

---------------------------------------------------------------------
-- config resolution (once, at start)
---------------------------------------------------------------------
local function resolveSeat(value)
    local def = type(value) == 'table' and value or { type = value }
    local base = Config.SeatTypes[def.type]
    if not base then return nil end
    return {
        scenario = joaat(def.scenario or base.scenario),
        spots    = def.spots or base.spots,
        heading  = def.heading or base.heading or 0.0,
    }
end

for model, value in pairs(Config.Models) do
    local seat = resolveSeat(value)
    if seat then
        seatTypes[joaat(model)] = seat
        modelList[#modelList + 1] = model
    else
        print(('[grumpy-sit] model %s has unknown seat type %s'):format(model, tostring(value)))
    end
end

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function showText(text)
    exports['rsg-core']:DrawText(text, 'left')
    textShown = true
end

local function hideText()
    if not textShown then return end
    exports['rsg-core']:HideText()
    textShown = false
end

local function spotIsTaken(coords, myPed)
    local r = Config.SeatTakenRadius
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= myPed and not IsEntityDead(ped) and #(GetEntityCoords(ped) - coords) < r then
            return true
        end
    end
    return false
end

-- every free seat spot on this prop, nearest to the player first
local function freeSpots(entity, def, ped)
    local pedCoords = GetEntityCoords(ped)
    local list = {}
    for i, offset in ipairs(def.spots) do
        local world = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
        if not spotIsTaken(world, ped) then
            list[#list + 1] = { index = i, coords = world, dist = #(pedCoords - world) }
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- Chairs owned by another resource (card tables) are left to that resource.
-- canInteract runs every frame while aiming, so each entity's answer is cached for a few seconds.
local claimCache = {} -- entity -> { claimed = bool, at = ms }

local function isClaimed(entity)
    if not entity or entity == 0 then return false end
    local now = GetGameTimer()
    local hit = claimCache[entity]
    if hit and now - hit.at < Config.ClaimCacheMs then return hit.claimed end
    local claimed = false
    for _, check in ipairs(Config.ClaimedBy) do
        if GetResourceState(check.resource) == 'started' then
            local ok, res = pcall(function()
                local r = exports[check.resource]
                return r[check.export](r, entity) -- same as exports['res']:Export(entity)
            end)
            if ok and res then claimed = true break end
        end
    end
    claimCache[entity] = { claimed = claimed, at = now }
    return claimed
end

-- drop old cache entries now and then
CreateThread(function()
    while true do
        Wait(60000)
        local now = GetGameTimer()
        for e, v in pairs(claimCache) do
            if now - v.at > Config.ClaimCacheMs then claimCache[e] = nil end
        end
    end
end)

local function canSit(ped)
    return not seated
        and not IsEntityDead(ped)
        and not IsPedOnMount(ped)
        and not IsPedInAnyVehicle(ped, false)
        and not IsPedSwimming(ped)
end

---------------------------------------------------------------------
-- stand / sit
---------------------------------------------------------------------
local function stand()
    if not seated then return end
    local ped = PlayerPedId()
    seated = nil
    hideText()
    ClearPedTasks(ped)
    -- fall back to a hard clear if the exit anim didn't release the ped
    SetTimeout(1500, function()
        if not seated and IsPedUsingAnyScenario(ped) then ClearPedTasksImmediately(ped) end
    end)
end

local function debugSpots(entity, def)
    if not Config.Debug then return end
    print(('[grumpy-sit] model %s heading %.1f (+%.1f)'):format(GetEntityModel(entity), GetEntityHeading(entity), def.heading))
    CreateThread(function()
        local untilTime = GetGameTimer() + 15000
        while GetGameTimer() < untilTime and DoesEntityExist(entity) do
            for i, o in ipairs(def.spots) do
                local w = GetOffsetFromEntityInWorldCoords(entity, o.x, o.y, o.z)
                RSGCore.Functions.DrawText3D(w.x, w.y, w.z, ('seat %d (%.2f, %.2f, %.2f)'):format(i, o.x, o.y, o.z))
            end
            Wait(0)
        end
    end)
end

local function sit(entity)
    local ped = PlayerPedId()
    if not entity or entity == 0 or not DoesEntityExist(entity) or not canSit(ped) then return end

    local def = seatTypes[GetEntityModel(entity)]
    if not def or isClaimed(entity) then return end

    debugSpots(entity, def)

    local spot = freeSpots(entity, def, ped)[1]
    if not spot then
        RSGCore.Functions.Notify(locale('seat_taken'), 'error')
        return
    end

    local heading = (GetEntityHeading(entity) + def.heading) % 360.0
    -- same call shape as rsg-theatre's audience seats (TASK_START_SCENARIO_AT_POSITION, natives/db/TASK.md)
    TaskStartScenarioAtPosition(ped, def.scenario, spot.coords.x, spot.coords.y, spot.coords.z, heading, -1, false, true, 0, 0.25, false)

    seated = { entity = entity, spot = spot.coords, heading = heading }
    showText(locale('stand_hint'))

    CreateThread(function()
        local graceUntil = GetGameTimer() + 2000 -- the scenario needs a moment to start
        while seated do
            Wait(0)
            if IsControlJustPressed(0, Config.StandControl) or IsDisabledControlJustPressed(0, Config.StandControl) then
                stand()
                break
            end
            local p = PlayerPedId()
            if GetGameTimer() > graceUntil and (IsEntityDead(p) or not IsPedUsingAnyScenario(p)) then
                -- knocked out of the seat (ragdoll, death, another script cleared tasks)
                seated = nil
                hideText()
                break
            end
        end
    end)
end

---------------------------------------------------------------------
-- target option on every seat model (rsg-target does the aiming; no scan loop here)
---------------------------------------------------------------------
exports['rsg-target']:addModel(modelList, {
    {
        name = OPTION_NAME,
        icon = Config.TargetIcon,
        label = locale('target_sit'),
        distance = Config.TargetDistance,
        canInteract = function(entity)
            return canSit(PlayerPedId()) and not isClaimed(entity)
        end,
        onSelect = function(data)
            sit(data.entity)
        end,
    },
})

---------------------------------------------------------------------
-- hide the base game's own sit prompt (prompt type 8)
---------------------------------------------------------------------
if Config.DisableNativeSitPrompt then
    CreateThread(function()
        while true do
            Citizen.InvokeNative(0xFC094EF26DD153FA, Config.NativeSitPromptType) -- _UI_PROMPT_DISABLE_PROMPT_TYPE_THIS_FRAME
            Wait(0)
        end
    end)
end

---------------------------------------------------------------------
-- exports
---------------------------------------------------------------------
exports('IsSeated', function() return seated ~= nil end)
exports('Stand', stand)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() stand() end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    if GetResourceState('rsg-target') == 'started' then
        exports['rsg-target']:removeModel(modelList, OPTION_NAME)
    end
    if seated then
        seated = nil
        ClearPedTasks(PlayerPedId())
    end
    hideText()
end)
