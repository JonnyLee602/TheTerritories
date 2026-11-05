-- automatic hooks, the /rep panel data and the admin command

-----------------------------------------------------------------------
-- payouts: rsg-core fires this on the server for every AddMoney, with the reason string
-----------------------------------------------------------------------
local function matchHook(reason)
    if type(reason) ~= 'string' then return end
    for _, h in ipairs(Config.MoneyHooks) do
        if (h.reason and h.reason == reason) or (h.pattern and reason:match(h.pattern)) then return h.action end
    end
end

AddEventHandler('RSGCore:Server:OnMoneyChange', function(src, moneytype, amount, operation, reason)
    if operation ~= 'add' or (tonumber(amount) or 0) < Config.MinHookAmount then return end
    if Config.Pricing and reason == Config.Pricing.Reason then return end -- price adjustments aren't work
    local action = matchHook(reason)
    if not action and moneytype == 'bloodmoney' then action = Config.BloodMoneyAction end
    if Config.Debug then print(('[grumpy-reputation] payout %s %s $%s reason=%s -> %s'):format(src, moneytype, amount, tostring(reason), action or 'no hook')) end
    if action then Reputation.Action(src, action) end
end)

-----------------------------------------------------------------------
-- /rep panel data
-----------------------------------------------------------------------
local function label(key)
    local k = 'rep_' .. key
    local text = locale(k)
    return text ~= k and text or key
end

RSGCore.Functions.CreateCallback('grumpy-reputation:server:getPanel', function(src, cb)
    local all = Reputation.GetAllRep(src)
    if not all then return cb(nil) end
    local standing = all[Config.Standing.RepKey]
    local tier = Rep.TierFor(standing)

    local list, seen = {}, { [Config.Standing.RepKey] = true }
    for _, key in ipairs(Config.RepOrder) do
        seen[key] = true
        if all[key] ~= nil and not Config.HideRep[key] then list[#list + 1] = { key = key, label = label(key), value = all[key] } end
    end
    local rest = {}
    for key, value in pairs(all) do
        if not seen[key] and not Config.HideRep[key] then rest[#rest + 1] = { key = key, label = label(key), value = value } end
    end
    table.sort(rest, function(a, b) return a.label < b.label end)
    for _, r in ipairs(rest) do list[#list + 1] = r end

    cb({
        standing = Config.ShowStandingNumber and standing or nil,
        position = (standing - Config.Standing.Min) / (Config.Standing.Max - Config.Standing.Min), -- 0..1 for the bar marker
        tier = tier,
        tierLabel = locale('tier_' .. tier),
        tierDesc = locale('tier_desc_' .. tier),
        reps = list,
    })
end)

-----------------------------------------------------------------------
-- admin: /setstanding [id] [value]
-----------------------------------------------------------------------
RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_setstanding'), {
    { name = 'id', help = locale('cmd_arg_id') },
    { name = 'value', help = locale('cmd_arg_value', Config.Standing.Min, Config.Standing.Max) },
}, true, function(source, args)
    local target, value = tonumber(args[1]), tonumber(args[2])
    if not target or not value or not RSGCore.Functions.GetPlayer(target) then
        return TriggerClientEvent('RSGCore:Client:Notify', source, { title = locale('title'), description = locale('admin_bad_args'), type = 'error' })
    end
    Reputation.SetStanding(target, value, 'admin')
    TriggerClientEvent('RSGCore:Client:Notify', source, {
        title = locale('title'), description = locale('admin_set', target, Reputation.GetStanding(target)), type = 'success',
    })
end, Config.AdminPermission)
