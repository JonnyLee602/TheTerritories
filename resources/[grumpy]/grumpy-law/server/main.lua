RSGCore = exports['rsg-core']:GetCoreObject()

local W, H = Config.Witness, Config.Heat
local Incidents = {}   -- [id] = incident
local Heat = {}        -- [citizenid] = { [incidentId] = untilTime }
local nextId = 0

local function notify(src, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = description, type = nType or 'inform', duration = 6000 })
end

local function u32(h) return (tonumber(h) or 0) & 0xFFFFFFFF end

local function rand(range) return math.random(range[1], range[2]) end

local function crimeCfg(name) return Config.Crimes[name] or Config.Crimes.generic end

local function rep(src, action, mult)
    if action and GetResourceState('grumpy-reputation') == 'started' then
        exports['grumpy-reputation']:Action(src, action, mult)
    end
end

local function isLaw(Player)
    local job = Player and Player.PlayerData.job
    return job and job.type == 'leo' and job.onduty or false
end

local function lawOnDuty()
    local list = {}
    for _, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if isLaw(Player) then list[#list + 1] = Player.PlayerData.source end
    end
    return list
end

-- networked, alive, human NPCs within radius of coords (server view)
local function npcsNear(coords, radius)
    local out = {}
    for _, ped in ipairs(GetAllPeds()) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and GetEntityHealth(ped) > 0
            and not AnimalModels[u32(GetEntityModel(ped))] then
            local d = #(GetEntityCoords(ped) - coords)
            if d <= radius then out[#out + 1] = { ped = ped, dist = d } end
        end
    end
    return out
end

local function publicIncident(inc)
    return {
        id = inc.id, crime = inc.crime, label = inc.label, coords = inc.coords, criminal = inc.src,
        citizenid = inc.cid, opened = inc.opened, succeeded = inc.succeeded, reported = inc.reported,
        witnesses = inc.witnessCount,
    }
end

-----------------------------------------------------------------------
-- heat
-----------------------------------------------------------------------
local function startHeat(inc)
    Heat[inc.cid] = Heat[inc.cid] or {}
    if Heat[inc.cid][inc.id] then return end
    Heat[inc.cid][inc.id] = os.time() + H.Duration
end

local function endHeat(cid, incId, outcome)
    if not Heat[cid] then return end
    Heat[cid][incId] = nil
    if next(Heat[cid]) == nil then Heat[cid] = nil end
    local inc = Incidents[incId]
    TriggerEvent('grumpy-law:server:heatEnded', cid, incId, outcome, inc and publicIncident(inc) or nil)
end

CreateThread(function()
    while true do
        Wait(H.CheckInterval * 1000)
        local now = os.time()
        for cid, list in pairs(Heat) do
            local Player = RSGCore.Functions.GetPlayerByCitizenId(cid)
            for incId, untilTime in pairs(list) do
                local inc = Incidents[incId]
                if not Player then
                    endHeat(cid, incId, 'offline')          -- logging off forfeits
                elseif Player.PlayerData.metadata.isdead then
                    endHeat(cid, incId, 'died')
                elseif (tonumber(Player.PlayerData.metadata.injail) or 0) > 0 then
                    endHeat(cid, incId, 'jailed')           -- the jailed hook gives its own slight gain
                elseif now >= untilTime then
                    local src = Player.PlayerData.source
                    if inc and inc.succeeded then
                        local cfg = crimeCfg(inc.crime)
                        rep(src, cfg.escapeAction, cfg.escapeMult)
                        if H.NotifyEscaped then notify(src, locale('heat_escaped'), 'success') end
                    end
                    endHeat(cid, incId, 'escaped')
                end
            end
        end
        -- forget old incidents nobody tracks any more
        for id, inc in pairs(Incidents) do
            if now - inc.opened > H.Duration + 600 then Incidents[id] = nil end
        end
    end
end)

-----------------------------------------------------------------------
-- reports
-----------------------------------------------------------------------
local function report(inc, by)
    if inc.reported then return end
    inc.reported = true
    inc.reportedBy = by

    local text = locale('alert_' .. inc.crime) ~= ('alert_' .. inc.crime) and locale('alert_' .. inc.crime, inc.label or '') or locale('alert_generic', inc.label or '')
    local law = lawOnDuty()
    for _, id in ipairs(law) do
        if Config.Report.UseLawmanAlert and GetResourceState('rsg-lawman') == 'started' then
            TriggerClientEvent('rsg-lawman:client:lawmanAlert', id, inc.coords, text)
        else
            notify(id, text, 'warning')
        end
    end

    if Config.Report.NotifyCriminal and RSGCore.Functions.GetPlayer(inc.src) then
        notify(inc.src, locale('reported'), 'warning')
    end
    startHeat(inc)
    -- NPC police (or anything else) hooks here. lawCount = on-duty player law right now.
    TriggerEvent('grumpy-law:server:crimeReported', publicIncident(inc), #law)
    if Config.Debug then print(('[grumpy-law] incident %s (%s) reported by %s, %s law on duty'):format(inc.id, inc.crime, by, #law)) end
end

local function addWitness(inc, key, ped)
    if inc.witnesses[key] then return end
    inc.witnesses[key] = true
    inc.witnessCount = inc.witnessCount + 1
    if math.random(100) > W.ReportChance then return end
    SetTimeout(rand(W.ReportDelay) * 1000, function()
        if inc.reported or not Incidents[inc.id] then return end
        if W.DeadNoReport and ped and (not DoesEntityExist(ped) or GetEntityHealth(ped) <= 0) then return end
        report(inc, 'witness')
    end)
end

-----------------------------------------------------------------------
-- incidents
-----------------------------------------------------------------------
---@param src number criminal
---@param opts table { crime, coords?, label?, hot?, victimReports?, succeeded? }
---@return number|nil incident id
local function OpenIncident(src, opts)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(opts) ~= 'table' then return nil end
    local crime = Config.Crimes[opts.crime] and opts.crime or 'generic'
    local cfg = crimeCfg(crime)
    nextId = nextId + 1
    local now = os.time()
    local inc = {
        id = nextId, src = src, cid = Player.PlayerData.citizenid, crime = crime,
        label = type(opts.label) == 'string' and opts.label or nil,
        coords = opts.coords and vector3(opts.coords.x, opts.coords.y, opts.coords.z) or GetEntityCoords(GetPlayerPed(src)),
        opened = now, hotUntil = now + (tonumber(opts.hot) or cfg.hot),
        succeeded = opts.succeeded == true, reported = false,
        witnesses = {}, witnessCount = 0, serverSawAny = false, clientFallback = 0,
    }
    Incidents[inc.id] = inc

    if opts.victimReports then
        inc.witnessCount = inc.witnessCount + 1
        SetTimeout(rand(cfg.victimDelay) * 1000, function()
            if Incidents[inc.id] then report(inc, 'victim') end
        end)
    end

    TriggerClientEvent('grumpy-law:client:scan', src, inc.id, inc.hotUntil - now)

    -- server scan while hot: NPCs close to the criminal (or passing by) witness it
    CreateThread(function()
        while Incidents[inc.id] and os.time() < inc.hotUntil do
            local ped = GetPlayerPed(inc.src)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local here = GetEntityCoords(ped)
                local list = npcsNear(here, W.Radius)
                if #list > 0 then inc.serverSawAny = true end
                for _, n in ipairs(list) do
                    if n.dist <= W.CloseRadius then addWitness(inc, 'e' .. n.ped, n.ped) end
                end
            end
            Wait(W.ScanInterval * 1000)
        end
        -- population not networked: fall back to the client's line-of-sight count (capped)
        if Incidents[inc.id] and not inc.serverSawAny and inc.clientFallback > 0 then
            for i = 1, math.min(inc.clientFallback, W.ClientFallbackMax) do addWitness(inc, 'c' .. i, nil) end
        end
    end)

    if Config.Debug then print(('[grumpy-law] incident %s opened: %s by %s'):format(inc.id, crime, src)) end
    return inc.id
end

-- the criminal's game reports humans with line of sight to them
RegisterNetEvent('grumpy-law:server:scanResult', function(incId, netIds, localCount)
    local src = source
    local inc = Incidents[tonumber(incId) or -1]
    if not inc or inc.src ~= src or os.time() > inc.hotUntil + 2 then return end
    local now = GetGameTimer()
    if inc.lastClient and now - inc.lastClient < (W.ClientInterval * 1000 - 500) then return end
    inc.lastClient = now

    local myPos = GetEntityCoords(GetPlayerPed(src))
    if type(netIds) == 'table' then
        for i = 1, math.min(#netIds, W.ClientMaxPeds) do
            local ped = NetworkGetEntityFromNetworkId(tonumber(netIds[i]) or 0)
            if ped and ped ~= 0 and DoesEntityExist(ped) and GetEntityType(ped) == 1 and not IsPedAPlayer(ped)
                and GetEntityHealth(ped) > 0 and not AnimalModels[u32(GetEntityModel(ped))]
                and #(GetEntityCoords(ped) - myPos) <= W.Radius + 2.0 then
                addWitness(inc, 'e' .. ped, ped)
            end
        end
    end
    localCount = math.floor(tonumber(localCount) or 0)
    if localCount > inc.clientFallback then inc.clientFallback = math.min(localCount, W.ClientMaxPeds) end
end)

local function MarkSucceeded(id)
    local inc = Incidents[tonumber(id) or -1]
    if inc then inc.succeeded = true return true end
    return false
end

local function GetIncident(id)
    local inc = Incidents[tonumber(id) or -1]
    return inc and publicIncident(inc) or nil
end

local function IsHot(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player ~= nil and Heat[Player.PlayerData.citizenid] ~= nil
end

local function ReportNow(id)
    local inc = Incidents[tonumber(id) or -1]
    if not inc then return false end
    report(inc, 'script')
    return true
end

exports('OpenIncident', OpenIncident)
exports('MarkSucceeded', MarkSucceeded)
exports('GetIncident', GetIncident)
exports('ReportNow', ReportNow)
exports('IsHot', IsHot)
exports('LawOnDuty', function() return #lawOnDuty() end)

-----------------------------------------------------------------------
-- /witnesstest: can the server see ambient NPCs on this server?
-----------------------------------------------------------------------
RSGCore.Commands.Add(Config.TestCommand, locale('cmd_test'), {}, false, function(source)
    local src = source
    local pos = GetEntityCoords(GetPlayerPed(src))
    local serverCount = #npcsNear(pos, W.Radius)
    local total = 0
    for _, ped in ipairs(GetAllPeds()) do if not IsPedAPlayer(ped) then total = total + 1 end end
    TriggerClientEvent('grumpy-law:client:test', src, serverCount, total, W.Radius)
end, Config.AdminPermission)
