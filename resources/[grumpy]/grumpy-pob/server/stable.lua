-- Stable businesses: an rsg-stables stable only staff can use (bigger per-player limit), plus paid
-- horse training done by on-duty staff. Needs integrations/rsg-stables.md.
local RSGCore = POB.Core()

local Stable = {}
POB.Stable = Stable

local STABLES = 'rsg-stables'
local T = Config.Training
local requests = {}   -- [bizId][customerSrc] = { stat, horseId, horseName, netId, price, at, name, takenBy }
local sessions = {}   -- [trainerSrc] = { token, biz, customer, horseId, stat, price, finishAt }

local function call(fn, ...)
    local args = { ... }
    local ok, a, b, c = pcall(function() return exports[STABLES][fn](exports[STABLES], table.unpack(args)) end)
    if not ok then
        print(('^1[grumpy-pob] rsg-stables export %s failed (is integrations/rsg-stables.md applied?): %s^7'):format(fn, tostring(a)))
        return nil
    end
    return a, b, c
end

function Stable.Name(biz) return 'pob_' .. biz.id end

local function v4(p) return p and vector4(p.x + 0.0, p.y + 0.0, p.z + 0.0, (p.w or 0.0) + 0.0) or nil end

function Stable.Register(biz)
    local t = POB.Type(biz)
    if not t or not t.stable or not biz.points.npc then return end
    local npc = v4(biz.points.npc)
    call('RegisterStable', {
        name = Stable.Name(biz), label = biz.label,
        pedCoords = npc, storeCoords = npc, previewCoords = v4(biz.points.preview) or npc,
        restrictJob = biz.job, maxHorses = t.stable.maxHorses, capExempt = t.stable.capExempt == true,
    })
end

function Stable.Remove(biz)
    local t = POB.Type(biz)
    if not t or not t.stable then return end
    call('MoveHorses', Stable.Name(biz), nil, t.stable.fallback)
    call('RemoveStable', Stable.Name(biz))
end

-- A fired employee's horses at this stable go to the fallback stable
function POB.StableEvict(biz, cid)
    local t = POB.Type(biz)
    if not t or not t.stable then return end
    call('MoveHorses', Stable.Name(biz), cid, t.stable.fallback)
end

local function syncAll() for _, biz in pairs(POB.Businesses) do Stable.Register(biz) end end
POB.AfterLoad(syncAll)
AddEventHandler('onResourceStart', function(res)
    if res == STABLES and POB.Ready then SetTimeout(2000, syncAll) end
end)

---------------------------------------------------------------------
-- Training
---------------------------------------------------------------------
local function trainingOn(biz)
    local t = POB.Type(biz)
    return T.Enabled and t and t.training == true and biz.owner ~= nil
end

local function validStat(stat)
    for _, s in ipairs(T.Stats) do if s == stat then return true end end
    return false
end

function Stable.Price(biz, stat)
    local p = tonumber(biz.settings.training[stat])
    if not p then return T.DefaultPrice end
    return math.max(T.MinPrice, math.min(T.MaxPrice, p))
end

local function horseNear(netId, model, to, dist)
    local ent = NetworkGetEntityFromNetworkId(math.tointeger(tonumber(netId)) or 0)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    if (GetEntityModel(ent) & 0xFFFFFFFF) ~= (math.floor(tonumber(model) or 0) & 0xFFFFFFFF) then return false end
    return #(GetEntityCoords(ent) - to) <= dist
end

local function pedPos(src) return GetEntityCoords(GetPlayerPed(src)) end

local function trainers(biz)
    local list = {}
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        local j = P.PlayerData.job or {}
        if j.name == biz.job and j.onduty then
            local grade = j.grade and tonumber(j.grade.level) or 0
            if POB.HasPerm(grade, 'train') then list[#list + 1] = P.PlayerData.source end
        end
    end
    return list
end

RSGCore.Functions.CreateCallback('grumpy-pob:server:trainingInfo', function(source, cb, id)
    local biz = POB.Biz(id)
    if not biz or not trainingOn(biz) or not POB.Near(source, biz.points.npc, T.StableDistance) then return cb(nil) end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    local horse = call('GetActiveHorse', Player.PlayerData.citizenid)
    local held = exports['rsg-core']:HasPlayerJob(source, biz.job)
    local stats = {}
    for _, s in ipairs(T.Stats) do stats[#stats + 1] = { stat = s, label = locale('stat_' .. s), price = held and 0 or Stable.Price(biz, s) } end
    cb({ horse = horse and horse.name or nil, stats = stats, trainers = #trainers(biz), pending = requests[biz.id] and requests[biz.id][source] ~= nil })
end)

RegisterNetEvent('grumpy-pob:server:requestTraining', function(id, stat, netId)
    local src = source
    local biz = POB.Biz(id)
    if not biz or not trainingOn(biz) or POB.Cooldown(src, 'trainreq', 5000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(stat) ~= 'string' or not validStat(stat) then return end
    if not POB.Near(src, biz.points.npc, T.StableDistance) then return POB.Notify(src, locale('too_far'), 'error') end
    local horse = call('GetActiveHorse', Player.PlayerData.citizenid)
    if not horse then return POB.Notify(src, locale('no_active_horse'), 'error') end
    if not horseNear(netId, horse.model, pedPos(src), T.HorseDistance) then return POB.Notify(src, locale('horse_too_far'), 'error') end
    local ok, err = call('CanTrainHorse', horse.id, stat)
    if not ok then return POB.Notify(src, err or locale('cannot_train'), 'error') end
    local held = exports['rsg-core']:HasPlayerJob(src, biz.job)
    local price = held and 0 or Stable.Price(biz, stat)
    if price > 0 and (Player.PlayerData.money.cash or 0) < price then return POB.Notify(src, locale('not_enough_cash'), 'error') end
    requests[biz.id] = requests[biz.id] or {}
    requests[biz.id][src] = { stat = stat, horseId = horse.id, horseName = horse.name, model = horse.model, netId = netId,
        price = price, at = os.time(), name = POB.PlayerName(Player), cid = Player.PlayerData.citizenid }
    local list = trainers(biz)
    for _, t in ipairs(list) do POB.Notify(t, locale('training_requested', POB.PlayerName(Player), locale('stat_' .. stat)), 'inform') end
    POB.Notify(src, locale(#list > 0 and 'training_request_sent' or 'training_request_no_staff'), 'success')
end)

RegisterNetEvent('grumpy-pob:server:cancelTraining', function(id)
    local src = source
    local biz = POB.Biz(id)
    if biz and requests[biz.id] and requests[biz.id][src] and not requests[biz.id][src].takenBy then
        requests[biz.id][src] = nil
        POB.Notify(src, locale('training_cancelled'), 'inform')
    end
end)

RSGCore.Functions.CreateCallback('grumpy-pob:server:trainingRequests', function(source, cb, id)
    local biz = POB.Biz(id)
    if not biz or not trainingOn(biz) then return cb(nil) end
    local Player = POB.Require(source, biz, 'train', true)
    if not Player or not POB.Near(source, biz.points.npc, T.StableDistance) then return cb(nil) end
    local out, now = {}, os.time()
    for csrc, r in pairs(requests[biz.id] or {}) do
        if now - r.at > T.RequestMinutes * 60 or GetPlayerPing(csrc) == 0 then
            requests[biz.id][csrc] = nil
        elseif not r.takenBy then
            out[#out + 1] = { src = csrc, name = r.name, horse = r.horseName, stat = locale('stat_' .. r.stat), price = r.price,
                earn = math.floor(r.price * T.EmployeeShare * 100) / 100 }
        end
    end
    cb(out)
end)

RSGCore.Functions.CreateCallback('grumpy-pob:server:acceptTraining', function(source, cb, id, customer)
    local src = source
    local biz = POB.Biz(id)
    if not biz or not trainingOn(biz) or sessions[src] or POB.Cooldown(src, 'trainaccept', 2000) then return cb(false) end
    local Player = POB.Require(src, biz, 'train', true)
    customer = POB.Int(customer)
    local r = customer and requests[biz.id] and requests[biz.id][customer]
    if not Player or not r or r.takenBy then return cb(false) end
    local Customer = RSGCore.Functions.GetPlayer(customer)
    if not Customer or Customer.PlayerData.citizenid ~= r.cid then requests[biz.id][customer] = nil return cb(false) end
    if not POB.Near(src, biz.points.npc, T.StableDistance) or not POB.Near(customer, biz.points.npc, T.StableDistance) then
        POB.Notify(src, locale('training_customer_left'), 'error')
        return cb(false)
    end
    if not horseNear(r.netId, r.model, pedPos(src), T.HorseDistance) then POB.Notify(src, locale('horse_too_far'), 'error') return cb(false) end
    local ok, err = call('CanTrainHorse', r.horseId, r.stat)
    if not ok then POB.Notify(src, err or locale('cannot_train'), 'error') return cb(false) end
    if r.price > 0 and not Customer.Functions.RemoveMoney('cash', r.price, 'grumpy-pob:training') then
        POB.Notify(src, locale('training_customer_broke'), 'error')
        POB.Notify(customer, locale('not_enough_cash'), 'error')
        requests[biz.id][customer] = nil
        return cb(false)
    end
    r.takenBy = src
    local token = ('%d-%d-%d'):format(src, GetGameTimer(), math.random(100000, 999999))
    sessions[src] = { token = token, biz = biz.id, customer = customer, cid = r.cid, horseId = r.horseId, horseName = r.horseName,
        stat = r.stat, price = r.price, finishAt = GetGameTimer() + T.DurationMs, netId = r.netId, model = r.model }
    POB.Notify(customer, locale('training_started', POB.PlayerName(Player)), 'inform')
    cb(true, { token = token, duration = T.DurationMs, netId = r.netId, horse = r.horseName, stat = locale('stat_' .. r.stat) })
end)

local function refundCustomer(s)
    if s.price <= 0 then return end
    local C = RSGCore.Functions.GetPlayerByCitizenId(s.cid)
    if C then
        C.Functions.AddMoney('cash', s.price, 'grumpy-pob:training-refund')
        POB.Notify(C.PlayerData.source, locale('training_refunded', s.price), 'inform')
    else
        local biz = POB.Biz(s.biz)
        if biz then POB.Acc.Add(POB.AccountId(biz), s.price, 'training', nil, locale('ledger_training_unclaimed')) end
    end
end

RegisterNetEvent('grumpy-pob:server:finishTraining', function(token, completed)
    local src = source
    local s = sessions[src]
    if not s or s.token ~= token then return end
    sessions[src] = nil
    local biz = POB.Biz(s.biz)
    if requests[s.biz] then requests[s.biz][s.customer] = nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not biz then return refundCustomer(s) end
    if completed ~= true or GetGameTimer() < s.finishAt - 750
        or not horseNear(s.netId, s.model, pedPos(src), T.HorseDistance + 2.0) then
        POB.Notify(src, locale('training_failed'), 'error')
        return refundCustomer(s)
    end
    local ok, res = call('TrainHorse', s.horseId, s.stat, T.Xp)
    if not ok then
        POB.Notify(src, type(res) == 'string' and res or locale('cannot_train'), 'error')
        return refundCustomer(s)
    end
    if s.price > 0 then
        local bizShare = math.floor(s.price * T.BusinessShare * 100) / 100
        local empShare = math.floor((s.price - bizShare) * 100) / 100
        if bizShare > 0 then POB.Acc.Add(POB.AccountId(biz), bizShare, 'training', POB.Acc.Who(Player), locale('ledger_training', s.horseName, locale('stat_' .. s.stat))) end
        if empShare > 0 then Player.Functions.AddMoney('cash', empShare, 'grumpy-pob:training-share') end
        POB.Notify(src, locale('training_done_paid', s.horseName, empShare), 'success')
    else
        POB.Notify(src, locale('training_done', s.horseName), 'success')
    end
    local C = RSGCore.Functions.GetPlayerByCitizenId(s.cid)
    if C then POB.Notify(C.PlayerData.source, locale('training_done_customer', s.horseName, locale('stat_' .. s.stat)), 'success') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local s = sessions[src]
    if s then
        sessions[src] = nil
        if requests[s.biz] then requests[s.biz][s.customer] = nil end
        refundCustomer(s)
    end
    for _, list in pairs(requests) do
        local r = list[src]
        if r and not r.takenBy then list[src] = nil end
    end
end)

RegisterNetEvent('grumpy-pob:server:setTrainingPrice', function(id, stat, price)
    local src = source
    local biz = POB.Biz(id)
    if not biz or not trainingOn(biz) or POB.Cooldown(src, 'trainprice', 300) then return end
    local Player = POB.Require(src, biz, 'prices')
    if not Player or not POB.Near(src, biz.points.manager) then return end
    price = POB.Money(tonumber(price))
    if type(stat) ~= 'string' or not validStat(stat) or not price or price < T.MinPrice or price > T.MaxPrice then
        return POB.Notify(src, locale('price_range', T.MinPrice, T.MaxPrice), 'error')
    end
    biz.settings.training[stat] = price
    POB.SaveBiz(biz)
    TriggerClientEvent('grumpy-pob:client:refresh', src, 'manager')
end)
