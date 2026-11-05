local RSGCore = exports['rsg-core']:GetCoreObject()
local W = Config.Witness

-- human, alive, non-player peds near me, nearest first
local function humansNear(radius)
    local me = PlayerPedId()
    local pos = GetEntityCoords(me)
    local list = {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= me and not IsPedAPlayer(ped) and IsPedHuman(ped) and not IsPedDeadOrDying(ped, true) then
            local d = #(GetEntityCoords(ped) - pos)
            if d <= radius then list[#list + 1] = { ped = ped, dist = d } end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- line-of-sight scan during an incident's hot window (only on the criminal's game)
local scanning = {}
RegisterNetEvent('grumpy-law:client:scan', function(incId, seconds)
    if scanning[incId] then return end
    scanning[incId] = true
    CreateThread(function()
        local untilTime = GetGameTimer() + (tonumber(seconds) or 0) * 1000
        while GetGameTimer() < untilTime do
            local me = PlayerPedId()
            local netIds, seen = {}, 0
            for i, n in ipairs(humansNear(W.Radius)) do
                if i > W.ClientMaxPeds then break end
                if HasEntityClearLosToEntity(n.ped, me, 17) then -- HAS_ENTITY_CLEAR_LOS_TO_ENTITY (17 = map + objects)
                    seen = seen + 1
                    if NetworkGetEntityIsNetworked(n.ped) then netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(n.ped) end
                end
            end
            TriggerServerEvent('grumpy-law:server:scanResult', incId, netIds, seen)
            Wait(W.ClientInterval * 1000)
        end
        scanning[incId] = nil
    end)
end)

-- /witnesstest result
RegisterNetEvent('grumpy-law:client:test', function(serverCount, serverTotal, radius)
    local list = humansNear(radius)
    local networked = 0
    for _, n in ipairs(list) do if NetworkGetEntityIsNetworked(n.ped) then networked = networked + 1 end end
    local msg = locale('test_result', math.floor(radius), serverCount, #list, networked, serverTotal)
    RSGCore.Functions.Notify({ title = locale('title'), description = msg, type = 'inform', duration = 12000 })
    print('[grumpy-law] ' .. msg)
end)
