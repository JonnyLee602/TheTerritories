-- grumpy-livery: every price and payout at a livery goes through here (doctrine/pricing.md §2).
--   market   'legal' (normal stables and yards) or 'underground' (Thieves Landing), per livery config
--   buy      base price x grumpy-reputation buy multiplier (legal: honor cheaper / infamy dearer; underground: the reverse)
--            x Config.Money.bloodmoneyMarkup when paid in bloodmoney (the wash fee: dirty money never spends as well)
--   sell     base payout x reputation sell multiplier, capped at Config.Money.sellCap x what this player would pay
--            for the same thing, so no standing can buy low and sell back high
--   account  the livery's accounts list ({ 'cash' } by default). Where there are several (Thieves Landing) the player
--            picks one with grumpy-livery:server:setPayment; the choice is checked again at every charge.
-- Loaded before server.lua and wagons.lua (fxmanifest), which use the global LiveryMoney.

local RSGCore = exports['rsg-core']:GetCoreObject()

LiveryMoney = {}
local M = LiveryMoney
local C = Config.Money

local choice = {} -- [src] = account the player picked at a multi-account livery

local function round2(n) return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 end
M.Round = round2

-- livery = a Config.Stables entry or a Config.Stores entry (both may carry market / accounts / payout)
function M.Market(livery)
    return (livery and livery.market) or 'legal'
end

function M.Accounts(livery)
    if livery and type(livery.accounts) == 'table' and #livery.accounts > 0 then return livery.accounts end
    return { C.defaultAccount }
end

function M.Account(src, livery)
    local list = M.Accounts(livery)
    local want = choice[src]
    for _, a in ipairs(list) do if a == want then return a end end
    return list[1]
end

-- account sales at this livery pay into
function M.PayoutAccount(livery)
    if livery and livery.payout then return livery.payout end
    return M.Market(livery) == 'underground' and 'bloodmoney' or C.defaultAccount
end

local function repMult(src, market, side)
    if not C.reputation or GetResourceState('grumpy-reputation') ~= 'started' then return 1.0 end
    local ok, m = pcall(function() return exports['grumpy-reputation']:GetPriceMultiplier(src, market, side) end)
    return (ok and tonumber(m)) or 1.0
end

-- multiplier on every buy price at this livery for this player (standing x bloodmoney markup)
function M.BuyMult(src, livery, account)
    account = account or M.Account(src, livery)
    local m = repMult(src, M.Market(livery), 'buy')
    if account == 'bloodmoney' then m = m * (C.bloodmoneyMarkup or 1.0) end
    return m
end

function M.BuyPrice(src, livery, base, account)
    return round2((tonumber(base) or 0) * M.BuyMult(src, livery, account))
end

-- sale payout: base x sell multiplier, capped at sellCap x this player's own buy price of listPrice (in that account)
function M.SellPrice(src, livery, base, listPrice)
    local mult = repMult(src, M.Market(livery), 'sell')
    local price = round2((tonumber(base) or 0) * mult)
    local cap
    if listPrice and (C.sellCap or 0) > 0 then
        cap = round2(listPrice * repMult(src, M.Market(livery), 'buy') * C.sellCap)
        if price > cap then price = cap end
    end
    return price, mult, cap
end

-- takes the money. Returns ok, paid, account
function M.Charge(src, livery, base, reason)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local account = M.Account(src, livery)
    local price = M.BuyPrice(src, livery, base, account)
    if price <= 0 then return true, 0, account end
    if (Player.PlayerData.money[account] or 0) < price then return false, price, account end
    if Player.Functions.RemoveMoney(account, price, reason or 'grumpy-livery') == false then return false, price, account end
    return true, price, account
end

function M.Refund(src, account, amount, reason)
    if (tonumber(amount) or 0) <= 0 then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then Player.Functions.AddMoney(account, amount, reason or 'grumpy-livery-refund') end
end

function M.Pay(src, livery, amount, reason)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or (tonumber(amount) or 0) <= 0 then return nil end
    local account = M.PayoutAccount(livery)
    Player.Functions.AddMoney(account, amount, reason or 'grumpy-livery-sale')
    return account
end

-- what the client needs to show the right prices: { mult, account, accounts, market, markup }
function M.Info(src, livery)
    local account = M.Account(src, livery)
    return {
        mult = M.BuyMult(src, livery, account),
        account = account,
        accounts = M.Accounts(livery),
        market = M.Market(livery),
        markup = C.bloodmoneyMarkup or 1.0,
    }
end

-- kind 'horse' = Config.Stables name, 'wagon' = Config.Stores key
function M.Livery(kind, key)
    if kind == 'wagon' then return Config.Stores[key] end
    for _, s in ipairs(Config.Stables) do if s.name == key then return s end end
end

RegisterNetEvent('grumpy-livery:server:setPayment', function(kind, key, account)
    local src = source
    local livery = M.Livery(kind, key)
    if not livery or type(account) ~= 'string' then return end
    for _, a in ipairs(M.Accounts(livery)) do
        if a == account then choice[src] = account return end
    end
end)

RSGCore.Functions.CreateCallback('grumpy-livery:server:priceInfo', function(source, cb, kind, key)
    cb(M.Info(source, M.Livery(kind, key)))
end)

AddEventHandler('playerDropped', function() choice[source] = nil end)
