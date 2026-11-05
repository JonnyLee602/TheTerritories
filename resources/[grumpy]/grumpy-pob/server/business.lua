-- Player-facing business flows: buy, apply, duty, manager screen, staff and money.
local RSGCore = POB.Core()

local Acc, Jobs = POB.Acc, POB.Jobs

local function refresh(src) TriggerClientEvent('grumpy-pob:client:refresh', src, 'manager') end

local function atManager(src, biz)
    if POB.Near(src, biz.points.manager) then return true end
    POB.Notify(src, locale('too_far'), 'error')
    return false
end

local function notifyStaff(biz, perm, msg)
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        local held, grade = exports['rsg-core']:HasPlayerJob(P.PlayerData.source, biz.job)
        if held and POB.HasPerm(grade, perm) then POB.Notify(P.PlayerData.source, msg, 'inform') end
    end
end
POB.NotifyStaff = notifyStaff

-- Everything that has to follow an ownership or name change
function POB.Refresh(biz)
    POB.Shop.Push(biz)
    POB.Hotel.Ensure(biz)
    POB.Broadcast()
end

---------------------------------------------------------------------
-- Sign: buy (unowned) or apply (owned)
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-pob:server:signInfo', function(source, cb, id)
    local biz = POB.Biz(id)
    if not biz then return cb(nil) end
    local _, grade = POB.Employment(source, biz)
    local Player = RSGCore.Functions.GetPlayer(source)
    local applied = Player and MySQL.scalar.await('SELECT 1 FROM grumpy_pob_applications WHERE business_id = ? AND citizenid = ?',
        { biz.id, Player.PlayerData.citizenid }) ~= nil
    cb({ id = biz.id, label = biz.label, type = POB.Type(biz).label, owned = biz.owner ~= nil, price = biz.price,
        owner = biz.owner and biz.owner.name or nil, employee = grade ~= nil, applied = applied, maxLength = Config.Applications.MaxLength })
end)

RegisterNetEvent('grumpy-pob:server:buy', function(id)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'buy', 3000) then return end
    POB.Lock('biz:' .. biz.id, function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        if biz.owner then return POB.Notify(src, locale('already_owned'), 'error') end
        if not POB.Near(src, biz.points.sign) then return POB.Notify(src, locale('too_far'), 'error') end
        local ok, why = exports['rsg-core']:CanTakePlayerJob(src, biz.job)
        if not ok and why ~= 'already_held' then return POB.Notify(src, locale(why == 'max_jobs' and 'max_jobs' or 'cannot_take_job'), 'error') end
        local price = biz.price
        if price > 0 then
            if (Player.PlayerData.money.cash or 0) < price then return POB.Notify(src, locale('not_enough_cash'), 'error') end
            if not Player.Functions.RemoveMoney('cash', price, 'grumpy-pob:buy-business') then return POB.Notify(src, locale('not_enough_cash'), 'error') end
        end
        local given = Jobs.Give(src, biz, Config.OwnerGrade, true)
        if not given then
            if price > 0 then Player.Functions.AddMoney('cash', price, 'grumpy-pob:buy-refund') end
            return POB.Notify(src, locale('cannot_take_job'), 'error')
        end
        local who = Acc.Who(Player)
        if price > 0 then Acc.Add(Acc.GOV, price, 'purchase', who, locale('ledger_bought', biz.label)) end
        biz.owner = { cid = who.cid, name = who.name }
        biz.taxDue = os.time() + Config.Tax.IntervalDays * 86400
        biz.taxOwedSince = nil
        POB.SaveBiz(biz)
        Acc.Ensure(POB.AccountId(biz))
        Acc.Log(POB.AccountId(biz), 'owner', 0, who, locale('ledger_bought', biz.label))
        MySQL.update.await('DELETE FROM grumpy_pob_applications WHERE business_id = ? AND citizenid = ?', { biz.id, who.cid })
        POB.Refresh(biz)
        POB.Notify(src, locale('bought_business', biz.label, price), 'success')
        print(('[grumpy-pob] %s (%s) bought business %d "%s" for $%s'):format(who.name, who.cid, biz.id, biz.label, price))
    end)
end)

RegisterNetEvent('grumpy-pob:server:apply', function(id, message)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'apply', 3000) then return end
    local Player, grade = POB.Employment(src, biz)
    if not Player then return end
    if not biz.owner then return POB.Notify(src, locale('biz_closed'), 'error') end
    if grade then return POB.Notify(src, locale('already_employee'), 'error') end
    if not POB.Near(src, biz.points.sign) then return POB.Notify(src, locale('too_far'), 'error') end
    message = POB.Str(message, Config.Applications.MaxLength)
    if not message or #message < 10 then return POB.Notify(src, locale('application_too_short'), 'error') end
    local cid = Player.PlayerData.citizenid
    local last = MySQL.scalar.await('SELECT created_at FROM grumpy_pob_applications WHERE business_id = ? AND citizenid = ?', { biz.id, cid })
    if last and os.time() - last < Config.Applications.CooldownMinutes * 60 then return POB.Notify(src, locale('application_cooldown'), 'error') end
    if not last and (MySQL.scalar.await('SELECT COUNT(*) FROM grumpy_pob_applications WHERE business_id = ?', { biz.id }) or 0) >= Config.Applications.MaxPending then
        return POB.Notify(src, locale('applications_full'), 'error')
    end
    MySQL.query.await([[INSERT INTO grumpy_pob_applications (business_id, citizenid, name, message, created_at) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), message = VALUES(message), created_at = VALUES(created_at)]],
        { biz.id, cid, POB.PlayerName(Player), message, os.time() })
    POB.Notify(src, locale('application_sent', biz.label), 'success')
    notifyStaff(biz, 'applications', locale('application_new', POB.PlayerName(Player), biz.label))
end)

---------------------------------------------------------------------
-- Duty (clock in at the manager point, switches the active job if needed)
---------------------------------------------------------------------
RegisterNetEvent('grumpy-pob:server:duty', function(id)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'duty', 2500) then return end
    local Player, grade, onDuty = POB.Employment(src, biz)
    if not Player or not grade then return end
    if not biz.owner then return POB.Notify(src, locale('biz_closed'), 'error') end
    if not atManager(src, biz) then return end
    local job = Player.PlayerData.job or {}
    if onDuty then
        Player.Functions.SetJobDuty(false)
    else
        if job.name ~= biz.job then Player.Functions.SetJob(biz.job, grade) end
        Player.Functions.SetJobDuty(true)
    end
    local now = not onDuty
    TriggerEvent('RSGCore:Server:SetDuty', src, now)
    TriggerClientEvent('RSGCore:Client:SetDuty', src, now)
    POB.Notify(src, locale(now and 'clocked_in' or 'clocked_out', biz.label), 'success')
    refresh(src)
end)

---------------------------------------------------------------------
-- Manager screen
---------------------------------------------------------------------
local function withdrawnToday(biz, cid)
    return tonumber(MySQL.scalar.await('SELECT amount FROM grumpy_pob_withdrawals WHERE business_id = ? AND citizenid = ? AND day = ?',
        { biz.id, cid, POB.Today() })) or 0
end

local function withdrawLeft(biz, grade, cid)
    if grade >= Config.OwnerGrade then return nil end
    local limit = Config.WithdrawDailyLimit[grade]
    if not limit then return nil end
    return math.max(0, limit - withdrawnToday(biz, cid))
end

local function options(list, key)
    local out = {}
    for _, o in ipairs(list) do out[#out + 1] = { label = o.label, value = o[key] } end
    return out
end

RSGCore.Functions.CreateCallback('grumpy-pob:server:manager', function(source, cb, id)
    local src = source
    local biz = POB.Biz(id)
    if not biz then return cb(nil) end
    local Player, grade, onDuty = POB.Employment(src, biz)
    if not Player or not grade or not POB.Near(src, biz.points.manager) then return cb(nil) end
    local t = POB.Type(biz)
    local perms = POB.Perms(grade)
    local cid = Player.PlayerData.citizenid
    local data = {
        id = biz.id, label = biz.label, typeLabel = t.label, owned = biz.owner ~= nil, owner = biz.owner and biz.owner.name,
        grade = grade, gradeLabel = Config.Grades[grade], onDuty = onDuty, perms = perms, isOwner = grade >= Config.OwnerGrade,
        grades = {}, shop = t.shop == true, hotel = t.hotel ~= nil, stable = t.stable ~= nil,
        training = t.training == true and Config.Training.Enabled, ledgerPage = Config.LedgerPageSize,
    }
    for lvl = 0, Config.OwnerGrade do data.grades[#data.grades + 1] = { level = lvl, label = Config.Grades[lvl] } end

    if perms.viewAccount then data.balance = Acc.Balance(POB.AccountId(biz)) end
    if perms.withdraw then data.withdrawLeft = withdrawLeft(biz, grade, cid) end
    if Config.Tax.Enabled and perms.viewAccount then
        data.tax = { amount = t.tax or Config.Tax.Default, due = biz.taxDue, owedSince = biz.taxOwedSince, graceDays = Config.Tax.GraceDays, now = os.time() }
    end
    if t.shop then
        data.stock = POB.Shop.Rows(biz)
        data.priceRange = { min = Config.Shop.MinPrice, max = Config.Shop.MaxPrice }
    end
    if perms.hire or perms.fire or perms.setGrade or perms.wages then data.staff = Jobs.Staff(biz) end
    if perms.applications then
        data.applications = MySQL.query.await('SELECT id, name, message, created_at FROM grumpy_pob_applications WHERE business_id = ? ORDER BY created_at DESC', { biz.id }) or {}
    end
    if perms.wages and Config.Wages.Enabled then
        data.wages = {}
        for lvl = 0, Config.OwnerGrade - 1 do data.wages[#data.wages + 1] = { level = lvl, label = Config.Grades[lvl], amount = tonumber(biz.settings.wages[tostring(lvl)]) or 0 } end
        data.wageMax, data.wageInterval = Config.Wages.Max, Config.Wages.IntervalMinutes
    end
    if perms.appearance then
        data.appearance = { model = biz.npcModel, sprite = biz.blip.sprite or t.blip.sprite, color = biz.blip.color or t.blip.color or '',
            enabled = biz.blip.enabled ~= false, models = options(Config.NpcModels, 'model'), sprites = options(Config.BlipSprites, 'sprite'),
            colors = options(Config.BlipColors, 'color') }
    end
    if data.training then
        data.trainingPrices = {}
        for _, s in ipairs(Config.Training.Stats) do data.trainingPrices[#data.trainingPrices + 1] = { stat = s, label = locale('stat_' .. s), price = POB.Stable.Price(biz, s) } end
        data.trainingRange = { min = Config.Training.MinPrice, max = Config.Training.MaxPrice }
    end
    if t.hotel then data.hotelRate, data.hotelMax, data.rooms = POB.Hotel.Rate(biz), t.hotel.maxRate, biz.rooms end
    if POB.Launder then data.backroom = POB.Launder.ManagerData(src, biz, Player) end -- owner only
    if perms.recipes then
        data.recipeRules = POB.Recipes.Rules(biz)
        data.recipes = POB.Recipes.ListFor(biz)
        data.typeRecipes = {}
        for _, r in ipairs(POB.Craft.Recipes(biz)) do
            if not r.custom then data.typeRecipes[#data.typeRecipes + 1] = { label = r.label, amount = r.amount } end
        end
    end
    cb(data)
end)

RSGCore.Functions.CreateCallback('grumpy-pob:server:ledger', function(source, cb, id, page)
    local biz = POB.Biz(id)
    if not biz then return cb(nil) end
    local _, grade = POB.Employment(source, biz)
    if not POB.HasPerm(grade, 'ledger') or not POB.Near(source, biz.points.manager) then return cb(nil) end
    cb(Acc.Ledger(POB.AccountId(biz), page))
end)

---------------------------------------------------------------------
-- Money
---------------------------------------------------------------------
RegisterNetEvent('grumpy-pob:server:money', function(id, action, amount)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'money', 1500) then return end
    local perm = action == 'deposit' and 'deposit' or action == 'withdraw' and 'withdraw' or nil
    if not perm then return end
    local Player, grade = POB.Require(src, biz, perm)
    if not Player or not atManager(src, biz) then return end
    local account = POB.AccountId(biz)
    amount = POB.Money(tonumber(amount))
    if not amount or amount <= 0 then return POB.Notify(src, locale('invalid_amount'), 'error') end
    POB.Lock('money:' .. biz.id, function()
        local ok, err
        if perm == 'deposit' then
            ok, err = Acc.DepositCash(Player, account, amount, 'deposit')
        else
            local left = withdrawLeft(biz, grade, Player.PlayerData.citizenid)
            if left and amount > left then return POB.Notify(src, locale('withdraw_limit', left), 'error') end
            ok, err = Acc.WithdrawCash(Player, account, amount, 'withdraw')
            if ok and left then
                MySQL.query.await([[INSERT INTO grumpy_pob_withdrawals (business_id, citizenid, day, amount) VALUES (?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)]], { biz.id, Player.PlayerData.citizenid, POB.Today(), amount })
            end
        end
        if not ok then return POB.Notify(src, locale(err), 'error') end
        POB.Notify(src, locale(perm == 'deposit' and 'deposited' or 'withdrew', amount), 'success')
        if biz.taxOwedSince and POB.Upkeep then POB.Upkeep.TryTax(biz) end
    end)
    refresh(src)
end)

---------------------------------------------------------------------
-- Staff
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-pob:server:nearbyPlayers', function(source, cb, id)
    local biz = POB.Biz(id)
    if not biz then return cb({}) end
    local _, grade = POB.Employment(source, biz)
    if not POB.HasPerm(grade, 'hire') then return cb({}) end
    local me = GetEntityCoords(GetPlayerPed(source))
    local out = {}
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        local s = P.PlayerData.source
        if s ~= source and #(GetEntityCoords(GetPlayerPed(s)) - me) <= 5.0 then
            local held = exports['rsg-core']:HasPlayerJob(s, biz.job)
            if not held then out[#out + 1] = { src = s, name = POB.PlayerName(P) } end
        end
    end
    cb(out)
end)

local function hire(src, biz, identifier, name)
    local ok, why = exports['rsg-core']:CanTakePlayerJob(identifier, biz.job)
    if not ok then
        POB.Notify(src, locale(why == 'max_jobs' and 'target_max_jobs' or why == 'already_held' and 'already_employee_target' or 'cannot_take_job'), 'error')
        return false
    end
    if not Jobs.Give(identifier, biz, 0) then POB.Notify(src, locale('cannot_take_job'), 'error') return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    Acc.Log(POB.AccountId(biz), 'staff', 0, Acc.Who(Player), locale('ledger_hired', name))
    POB.Notify(src, locale('hired', name), 'success')
    local tsrc = type(identifier) == 'number' and identifier or POB.SrcByCid(identifier)
    if tsrc then POB.Notify(tsrc, locale('you_were_hired', biz.label), 'success') end
    return true
end

RegisterNetEvent('grumpy-pob:server:hire', function(id, target)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'staff', 1000) then return end
    local Player = POB.Require(src, biz, 'hire')
    target = POB.Int(target)
    local T = target and RSGCore.Functions.GetPlayer(target)
    if not Player or not T or not atManager(src, biz) then return end
    if #(GetEntityCoords(GetPlayerPed(target)) - GetEntityCoords(GetPlayerPed(src))) > 6.0 then return POB.Notify(src, locale('too_far'), 'error') end
    hire(src, biz, target, POB.PlayerName(T))
    refresh(src)
end)

RegisterNetEvent('grumpy-pob:server:application', function(id, appId, accept)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'staff', 1000) then return end
    local Player = POB.Require(src, biz, accept == true and 'hire' or 'applications')
    if not Player or not atManager(src, biz) then return end
    local app = MySQL.single.await('SELECT * FROM grumpy_pob_applications WHERE id = ? AND business_id = ?', { POB.Int(appId) or -1, biz.id })
    if not app then return end
    if accept == true and not hire(src, biz, app.citizenid, app.name) then return refresh(src) end
    MySQL.update.await('DELETE FROM grumpy_pob_applications WHERE id = ?', { app.id })
    if accept ~= true then
        local tsrc = POB.SrcByCid(app.citizenid)
        if tsrc then POB.Notify(tsrc, locale('application_rejected', biz.label), 'inform') end
    end
    refresh(src)
end)

local function targetGrade(biz, cid)
    local held, grade = exports['rsg-core']:HasPlayerJob(cid, biz.job)
    return held and tonumber(grade) or nil
end

RegisterNetEvent('grumpy-pob:server:fire', function(id, cid)
    local src = source
    local biz = POB.Biz(id)
    if not biz or type(cid) ~= 'string' or POB.Cooldown(src, 'staff', 1000) then return end
    local Player, grade = POB.Require(src, biz, 'fire')
    if not Player or not atManager(src, biz) then return end
    local tg = targetGrade(biz, cid)
    if not tg then return end
    if cid == Player.PlayerData.citizenid or tg >= grade or tg >= Config.OwnerGrade then return POB.Notify(src, locale('cannot_manage_grade'), 'error') end
    if not Jobs.Take(cid, biz) then return POB.Notify(src, locale('action_failed'), 'error') end
    POB.StableEvict(biz, cid)
    local name = POB.ShortName(MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid }))
    Acc.Log(POB.AccountId(biz), 'staff', 0, Acc.Who(Player), locale('ledger_fired', name))
    local tsrc = POB.SrcByCid(cid)
    if tsrc then POB.Notify(tsrc, locale('you_were_fired', biz.label), 'error') end
    POB.Notify(src, locale('fired', name), 'success')
    refresh(src)
end)

RegisterNetEvent('grumpy-pob:server:setGrade', function(id, cid, newGrade)
    local src = source
    local biz = POB.Biz(id)
    if not biz or type(cid) ~= 'string' or POB.Cooldown(src, 'staff', 1000) then return end
    local Player, grade = POB.Require(src, biz, 'setGrade')
    if not Player or not atManager(src, biz) then return end
    newGrade = POB.Int(newGrade, 0, Config.OwnerGrade - 1)
    local tg = targetGrade(biz, cid)
    if not newGrade or not tg or cid == Player.PlayerData.citizenid then return end
    if tg >= grade or newGrade >= grade then return POB.Notify(src, locale('cannot_manage_grade'), 'error') end
    if not Jobs.Give(cid, biz, newGrade, true) then return POB.Notify(src, locale('action_failed'), 'error') end
    local name = POB.ShortName(MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid }))
    Acc.Log(POB.AccountId(biz), 'staff', 0, Acc.Who(Player), locale('ledger_grade', name, Config.Grades[newGrade]))
    local tsrc = POB.SrcByCid(cid)
    if tsrc then POB.Notify(tsrc, locale('your_grade', Config.Grades[newGrade], biz.label), 'inform') end
    refresh(src)
end)

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
RegisterNetEvent('grumpy-pob:server:rename', function(id, label)
    local src = source
    local biz = POB.Biz(id)
    if not biz or POB.Cooldown(src, 'rename', 5000) then return end
    local Player = POB.Require(src, biz, 'rename')
    if not Player or not atManager(src, biz) then return end
    label = POB.Str(label, 40)
    if not label or #label < 3 then return POB.Notify(src, locale('bad_name'), 'error') end
    local old = biz.label
    biz.label = label
    POB.SaveBiz(biz)
    Jobs.Ensure(biz)
    POB.Stable.Register(biz)
    POB.Refresh(biz)
    Acc.Log(POB.AccountId(biz), 'settings', 0, Acc.Who(Player), locale('ledger_renamed', old, label))
    POB.Notify(src, locale('renamed', label), 'success')
    refresh(src)
end)

local function inOptions(list, key, value)
    for _, o in ipairs(list) do if o[key] == value then return true end end
    return false
end

RegisterNetEvent('grumpy-pob:server:appearance', function(id, data)
    local src = source
    local biz = POB.Biz(id)
    if not biz or type(data) ~= 'table' or POB.Cooldown(src, 'appearance', 2000) then return end
    local Player = POB.Require(src, biz, 'appearance')
    if not Player or not atManager(src, biz) then return end
    if type(data.model) ~= 'string' or not inOptions(Config.NpcModels, 'model', data.model) then return end
    if type(data.sprite) ~= 'string' or not inOptions(Config.BlipSprites, 'sprite', data.sprite) then return end
    if type(data.color) ~= 'string' or not inOptions(Config.BlipColors, 'color', data.color) then return end
    biz.npcModel = data.model
    biz.blip = { sprite = data.sprite, color = data.color, enabled = data.enabled ~= false }
    POB.SaveBiz(biz)
    POB.Broadcast()
    Acc.Log(POB.AccountId(biz), 'settings', 0, Acc.Who(Player), locale('ledger_appearance'))
    POB.Notify(src, locale('saved'), 'success')
    refresh(src)
end)

RegisterNetEvent('grumpy-pob:server:wages', function(id, wages)
    local src = source
    local biz = POB.Biz(id)
    if not biz or type(wages) ~= 'table' or not Config.Wages.Enabled or POB.Cooldown(src, 'wages', 2000) then return end
    local Player = POB.Require(src, biz, 'wages')
    if not Player or not atManager(src, biz) then return end
    local out = {}
    for lvl = 0, Config.OwnerGrade - 1 do
        local v = POB.Money(tonumber(wages[tostring(lvl)] or wages[lvl + 1]) or 0)
        if not v or v < 0 or v > Config.Wages.Max then return POB.Notify(src, locale('price_range', 0, Config.Wages.Max), 'error') end
        out[tostring(lvl)] = v
    end
    biz.settings.wages = out
    POB.SaveBiz(biz)
    Acc.Log(POB.AccountId(biz), 'settings', 0, Acc.Who(Player), locale('ledger_wages'))
    POB.Notify(src, locale('saved'), 'success')
    refresh(src)
end)
