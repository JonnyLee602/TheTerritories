-- Player interactions: NPC, sign, manager screen, crafting and horse training.
local RSGCore = exports['rsg-core']:GetCoreObject()

local current = { manager = nil, craft = nil }

local function live(id) return POBC.Live(id) end

---------------------------------------------------------------------
-- NPC options (shop / stock / hotel / stable / training)
---------------------------------------------------------------------
local function openShop(id)
    local ok, res = RSGCore.Functions.AwaitCallback('grumpy-pob:server:canShop', nil, id)
    if not ok then return POBC.Notify(locale(res or 'unavailable'), 'error') end
    local b = live(id)
    exports['rsg-stores']:OpenShop(res, vector3(b.points.npc.x, b.points.npc.y, b.points.npc.z))
end

local function myHorseNetId()
    local ped = PlayerPedId()
    local mount = GetMount(ped)
    if mount ~= 0 and Entity(mount).state.rsgStablesOwned then return NetworkGetNetworkIdFromEntity(mount) end
    local pos, best, bestD = GetEntityCoords(ped), nil, Config.Training.HorseDistance
    for _, e in ipairs(GetGamePool('CPed')) do
        if e ~= ped and not IsPedHuman(e) and Entity(e).state.rsgStablesOwned and NetworkGetEntityIsNetworked(e) then
            local d = #(GetEntityCoords(e) - pos)
            if d < bestD then best, bestD = e, d end
        end
    end
    return best and NetworkGetNetworkIdFromEntity(best) or nil
end

function POBC.NpcOptions(biz)
    local id = biz.id
    local d = Config.InteractDistance
    local opts = {
        { name = 'grumpy-pob:closed:' .. id, icon = 'fa-solid fa-door-closed', label = locale('target_closed'), distance = d,
          canInteract = function() local b = live(id) return b and not b.owned end,
          onSelect = function() POBC.Notify(locale('biz_closed'), 'error') end },
    }
    if biz.shop then
        opts[#opts + 1] = { name = 'grumpy-pob:shop:' .. id, icon = 'fa-solid fa-store', label = locale('target_shop'), distance = d,
            canInteract = function() local b = live(id) return b and b.owned and not POBC.OnDutyAt(b) end,
            onSelect = function() openShop(id) end }
        opts[#opts + 1] = { name = 'grumpy-pob:stock:' .. id, icon = 'fa-solid fa-boxes-stacked', label = locale('target_stock'), distance = d,
            canInteract = function() local b = live(id) return b and b.owned and POBC.OnDutyAt(b) end,
            onSelect = function() TriggerServerEvent('grumpy-pob:server:openStock', id) end }
    end
    if biz.hotel then
        opts[#opts + 1] = { name = 'grumpy-pob:hotel:' .. id, icon = 'fa-solid fa-bed', label = locale('target_hotel'), distance = d,
            canInteract = function() local b = live(id) return b and b.owned end,
            onSelect = function() exports['grumpy-hotel']:OpenRental('grumpy-pob:' .. id) end }
    end
    if biz.stable then
        opts[#opts + 1] = { name = 'grumpy-pob:stable:' .. id, icon = 'fa-solid fa-horse', label = locale('target_stable'), distance = d,
            canInteract = function() local b = live(id) return b and b.owned and POBC.WorksAt(b) end,
            onSelect = function() exports['grumpy-livery']:OpenStable('pob_' .. id) end }
    end
    if biz.training then
        opts[#opts + 1] = { name = 'grumpy-pob:train:' .. id, icon = 'fa-solid fa-dumbbell', label = locale('target_training'), distance = d,
            canInteract = function() local b = live(id) return b and b.owned end,
            onSelect = function() POBC.OpenTraining(id) end }
        opts[#opts + 1] = { name = 'grumpy-pob:trainer:' .. id, icon = 'fa-solid fa-list-check', label = locale('target_trainer'), distance = d,
            canInteract = function() local b = live(id) return b and b.owned and POBC.OnDutyAt(b) end,
            onSelect = function() POBC.OpenTrainer(id) end }
    end
    return opts
end

---------------------------------------------------------------------
-- Sign (buy / apply)
---------------------------------------------------------------------
function POBC.SignOptions(biz)
    local id = biz.id
    return {
        { name = 'grumpy-pob:sign:' .. id, icon = 'fa-solid fa-sign-hanging', distance = Config.InteractDistance,
          label = biz.owned and locale('target_apply') or locale('target_buy', biz.price),
          canInteract = function() local b = live(id) return b and not (b.owned and POBC.WorksAt(b)) end,
          onSelect = function()
              local info = RSGCore.Functions.AwaitCallback('grumpy-pob:server:signInfo', nil, id)
              if info then POBC.OpenUI('sign', info) end
          end },
    }
end

RegisterNUICallback('buy', function(body, cb)
    TriggerServerEvent('grumpy-pob:server:buy', body.id)
    POBC.CloseUI()
    cb('ok')
end)

RegisterNUICallback('apply', function(body, cb)
    TriggerServerEvent('grumpy-pob:server:apply', body.id, body.message)
    POBC.CloseUI()
    cb('ok')
end)

---------------------------------------------------------------------
-- Manager screen
---------------------------------------------------------------------
function POBC.OpenManager(id)
    local data = RSGCore.Functions.AwaitCallback('grumpy-pob:server:manager', nil, id)
    if not data then return POBC.Notify(locale('too_far'), 'error') end
    current.manager = id
    if POBC.uiOpen == 'manager' then POBC.UpdateUI('manager', data) else POBC.OpenUI('manager', data) end
end

RegisterNetEvent('grumpy-pob:client:refresh', function(which)
    if which == 'manager' and POBC.uiOpen == 'manager' and current.manager then POBC.OpenManager(current.manager) end
end)

-- One NUI callback per manager action; the server validates every one
local managerEvents = {
    duty        = function(b) TriggerServerEvent('grumpy-pob:server:duty', b.id) end,
    money       = function(b) TriggerServerEvent('grumpy-pob:server:money', b.id, b.action, b.amount) end,
    price       = function(b) TriggerServerEvent('grumpy-pob:server:setPrice', b.id, b.item, b.price) end,
    takeStock   = function(b) TriggerServerEvent('grumpy-pob:server:takeStock', b.id, b.item, b.qty) end,
    hire        = function(b) TriggerServerEvent('grumpy-pob:server:hire', b.id, b.target) end,
    fire        = function(b) TriggerServerEvent('grumpy-pob:server:fire', b.id, b.cid) end,
    grade       = function(b) TriggerServerEvent('grumpy-pob:server:setGrade', b.id, b.cid, b.grade) end,
    application = function(b) TriggerServerEvent('grumpy-pob:server:application', b.id, b.appId, b.accept) end,
    rename      = function(b) TriggerServerEvent('grumpy-pob:server:rename', b.id, b.label) end,
    appearance  = function(b) TriggerServerEvent('grumpy-pob:server:appearance', b.id, b.data) end,
    wages       = function(b) TriggerServerEvent('grumpy-pob:server:wages', b.id, b.wages) end,
    buyTable    = function(b) TriggerServerEvent('grumpy-pob:server:buyGamblingTable', b.id, b.kind) end,
    trainPrice  = function(b) TriggerServerEvent('grumpy-pob:server:setTrainingPrice', b.id, b.stat, b.price) end,
    hotelRate   = function(b) TriggerServerEvent('grumpy-pob:server:setHotelRate', b.id, b.rate) end,
    delRecipe   = function(b) TriggerServerEvent('grumpy-pob:server:deleteRecipe', b.id, b.recipe) end,
    buyBackroom = function(b) TriggerServerEvent('grumpy-pob:server:buyBackroom', b.id) end,
    launder     = function(b) TriggerServerEvent('grumpy-pob:server:launder', b.id, b.amount) end,
}

---------------------------------------------------------------------
-- Law audit (books warrant holders)
---------------------------------------------------------------------
local auditing = nil

function POBC.OpenAudit(id)
    local data = RSGCore.Functions.AwaitCallback('grumpy-pob:server:audit', nil, id)
    if not data then return end
    auditing = id
    if POBC.uiOpen == 'audit' then POBC.UpdateUI('audit', data) else POBC.OpenUI('audit', data) end
end

RegisterNetEvent('grumpy-pob:client:auditRefresh', function(id)
    if POBC.uiOpen == 'audit' and auditing == id then POBC.OpenAudit(id) end
end)

RegisterNUICallback('audit', function(body, cb)
    if type(body) == 'table' and body.op == 'seize' and body.id then TriggerServerEvent('grumpy-pob:server:seize', body.id) end
    cb('ok')
end)

RegisterNUICallback('manager', function(body, cb)
    local fn = type(body) == 'table' and managerEvents[body.op]
    if fn then fn(body) end
    cb('ok')
end)

RegisterNUICallback('nearby', function(body, cb)
    cb(RSGCore.Functions.AwaitCallback('grumpy-pob:server:nearbyPlayers', nil, body.id) or {})
end)

RegisterNUICallback('ledger', function(body, cb)
    cb(RSGCore.Functions.AwaitCallback('grumpy-pob:server:ledger', nil, body.id, body.page) or {})
end)

RegisterNUICallback('presign', function(body, cb)
    cb({ url = RSGCore.Functions.AwaitCallback('grumpy-pob:server:presign', nil, body.id) })
end)

RegisterNUICallback('submitRecipe', function(body, cb)
    local ok = RSGCore.Functions.AwaitCallback('grumpy-pob:server:submitRecipe', nil, body.id, body.recipe)
    cb({ ok = ok == true })
    if ok then
        POBC.Notify(locale('recipe_sent'), 'success')
        POBC.OpenManager(body.id)
    end
end)

---------------------------------------------------------------------
-- Crafting
---------------------------------------------------------------------
function POBC.OpenCraft(id, station)
    local data = RSGCore.Functions.AwaitCallback('grumpy-pob:server:craftMenu', nil, id, station)
    if not data then return end
    current.craft = { id = id, station = station }
    data.id, data.station = id, station
    POBC.OpenUI('craft', data)
end

local crafting = false
RegisterNUICallback('craft', function(body, cb)
    cb('ok')
    if crafting or not current.craft then return end
    local c = current.craft
    POBC.CloseUI()
    crafting = true
    local ok, res = RSGCore.Functions.AwaitCallback('grumpy-pob:server:craftStart', nil, c.id, c.station, body.key, body.count)
    if not ok then crafting = false return end
    local done = RSGCore.Functions.ProgressBar({
        duration = res.duration, label = locale('crafting', res.label), useWhileDead = false, canCancel = true,
        disable = { move = true, combat = true }, anim = { scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
    })
    ClearPedTasks(PlayerPedId())
    TriggerServerEvent('grumpy-pob:server:craftFinish', res.token, done == true)
    crafting = false
end)

---------------------------------------------------------------------
-- Horse training
---------------------------------------------------------------------
function POBC.OpenTraining(id)
    local data = RSGCore.Functions.AwaitCallback('grumpy-pob:server:trainingInfo', nil, id)
    if not data then return POBC.Notify(locale('too_far'), 'error') end
    if not data.horse then return POBC.Notify(locale('no_active_horse'), 'error') end
    data.id = id
    POBC.OpenUI('training', data)
end

RegisterNUICallback('requestTraining', function(body, cb)
    cb('ok')
    POBC.CloseUI()
    local netId = myHorseNetId()
    if not netId then return POBC.Notify(locale('horse_too_far'), 'error') end
    TriggerServerEvent('grumpy-pob:server:requestTraining', body.id, body.stat, netId)
end)

RegisterNUICallback('cancelTraining', function(body, cb)
    TriggerServerEvent('grumpy-pob:server:cancelTraining', body.id)
    POBC.CloseUI()
    cb('ok')
end)

function POBC.OpenTrainer(id)
    local list = RSGCore.Functions.AwaitCallback('grumpy-pob:server:trainingRequests', nil, id)
    if not list then return end
    POBC.OpenUI('trainer', { id = id, requests = list })
end

local training = false
RegisterNUICallback('acceptTraining', function(body, cb)
    cb('ok')
    if training then return end
    POBC.CloseUI()
    training = true
    local ok, res = RSGCore.Functions.AwaitCallback('grumpy-pob:server:acceptTraining', nil, body.id, body.src)
    if not ok then training = false return end
    local horse = NetworkGetEntityFromNetworkId(res.netId)
    if horse and horse ~= 0 then TaskTurnPedToFaceEntity(PlayerPedId(), horse, 1500) Wait(1500) end
    local done = RSGCore.Functions.ProgressBar({
        duration = res.duration, label = locale('training_progress', res.horse, res.stat), useWhileDead = false, canCancel = true,
        disable = { move = true, combat = true }, anim = { scenario = Config.Training.Scenario },
    })
    ClearPedTasks(PlayerPedId())
    TriggerServerEvent('grumpy-pob:server:finishTraining', res.token, done == true)
    training = false
end)

---------------------------------------------------------------------
-- Government account
---------------------------------------------------------------------
local function openGov(page)
    local data = RSGCore.Functions.AwaitCallback('grumpy-pob:server:govData', nil, page or 0)
    if not data then return end
    data.page = page or 0
    if POBC.uiOpen == 'gov' then POBC.UpdateUI('gov', data) else POBC.OpenUI('gov', data) end
end

RegisterNetEvent('grumpy-pob:client:openGov', function() openGov(0) end)
RegisterNetEvent('grumpy-pob:client:refresh', function(which) if which == 'gov' and POBC.uiOpen == 'gov' then openGov(0) end end)

RegisterNUICallback('gov', function(body, cb)
    if body.op == 'money' then TriggerServerEvent('grumpy-pob:server:govMoney', body.action, body.amount)
    elseif body.op == 'page' then openGov(tonumber(body.page) or 0) end
    cb('ok')
end)
