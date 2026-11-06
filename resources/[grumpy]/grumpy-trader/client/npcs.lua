local spawnedPeds = {}

local function loadModel(model, timeout)
    if not IsModelValid(model) then return false end
    RequestModel(model, false)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(model) do
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

local function spawnPed(trader)
    local model = joaat(trader.npcmodel)
    if not loadModel(model, 5000) then
        if Config.Debug then print(('[grumpy-trader] invalid model %s for trader %s'):format(trader.npcmodel, trader.traderid)) end
        return
    end

    local ped = CreatePed(model, trader.x, trader.y, trader.z - 1.0, trader.heading, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)

    local options = {
        {
            name = 'grumpy_trader_speak',
            icon = 'fa-solid fa-comments',
            label = locale(trader.kind == 'illegal' and 'cl_target_fence' or 'cl_target_speak'),
            distance = 3.0,
            onSelect = function() TraderOpenMenu(trader.traderid, 'buy') end,
        },
    }
    local rumor = Config.Rumors.Enabled and Config.Rumors.Kinds[trader.kind]
    if rumor then
        local price = tonumber(rumor.price) or 0
        options[#options + 1] = {
            name = 'grumpy_trader_rumor',
            icon = price > 0 and 'fa-solid fa-sack-dollar' or 'fa-solid fa-comment-dots',
            -- price shown is the base; known outlaws pay less (the server works it out)
            label = price > 0 and locale('cl_target_bribe', ('%.2f'):format(price)) or locale('cl_target_rumor'),
            distance = Config.Rumors.Distance,
            canInteract = function() return GetResourceState('grumpy-rumors') == 'started' end,
            onSelect = function() TriggerServerEvent('grumpy-trader:server:askRumor', trader.traderid) end,
        }
    end
    exports['rsg-target']:addLocalEntity(ped, options)

    if Config.FadeIn then
        SetEntityAlpha(ped, 0, false)
        CreateThread(function() fade(ped, 0, 255, 51) end)
    end
    return ped
end

local function despawnPed(ped)
    if not ped or not DoesEntityExist(ped) then return end
    exports['rsg-target']:removeLocalEntity(ped, { 'grumpy_trader_speak', 'grumpy_trader_rumor' })
    if Config.FadeIn then
        CreateThread(function()
            fade(ped, 255, 0, -51)
            DeletePed(ped)
        end)
    else
        DeletePed(ped)
    end
end

-- a trader's identity: if its model, position or kind changes, the ped is respawned
local function signature(t)
    return ('%s|%.2f|%.2f|%.2f|%.1f|%s'):format(t.npcmodel, t.x, t.y, t.z, t.heading, t.kind or 'legal')
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local active = {}

        for _, t in ipairs(GetTraders()) do
            local id = t.traderid
            local sig = signature(t)
            local spawned = spawnedPeds[id]
            local inRange = #(playerCoords - vector3(t.x, t.y, t.z)) < Config.DistanceSpawn
            active[id] = true

            if spawned and (not inRange or spawned.sig ~= sig) then
                despawnPed(spawned.ped)
                spawnedPeds[id] = nil
                spawned = nil
            end
            if inRange and not spawned then
                local ped = spawnPed(t)
                if ped then spawnedPeds[id] = { ped = ped, sig = sig } end
            end
        end

        -- traders removed by an admin
        for id, spawned in pairs(spawnedPeds) do
            if not active[id] then
                despawnPed(spawned.ped)
                spawnedPeds[id] = nil
            end
        end

        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for k, spawned in pairs(spawnedPeds) do
        if DoesEntityExist(spawned.ped) then DeletePed(spawned.ped) end
        spawnedPeds[k] = nil
    end
end)
