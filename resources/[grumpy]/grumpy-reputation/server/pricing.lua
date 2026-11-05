-- honor / infamy pricing on the server: exports for shops, and payout adjustments for RSG sale resources
local P = Config.Pricing

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

---@return number multiplier (1.0 if the player isn't loaded)
function Reputation.GetPriceMultiplier(src, market, side)
    local standing = Reputation.GetStanding(src)
    if not standing then return 1.0 end
    return Rep.PriceMultiplier(standing, market, side)
end

---@return number buy, number sell, string market
function Reputation.GetShopMultipliers(src, shopName)
    local standing = Reputation.GetStanding(src)
    if not standing then return 1.0, 1.0, Rep.MarketForShop(shopName) end
    return Rep.ShopMultipliers(standing, shopName)
end

exports('GetPriceMultiplier', Reputation.GetPriceMultiplier)
exports('GetShopMultipliers', Reputation.GetShopMultipliers)
exports('GetMarketForShop', Rep.MarketForShop)
exports('GetArbitrageFactor', Rep.ArbitrageFactor)

-----------------------------------------------------------------------
-- Sale hooks: RSG resources pay at their own price; we add or take the difference right after.
-----------------------------------------------------------------------
local function saleHook(reason)
    for _, h in ipairs(P.SaleHooks or {}) do
        if (h.reason and h.reason == reason) or (h.pattern and reason:match(h.pattern)) then return h end
    end
end

local function notify(src, key, amount)
    if not P.NotifySale then return end
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('title'), description = locale(key, ('%.2f'):format(amount)), type = key:find('bonus') and 'success' or 'warning', duration = 5000,
    })
end

AddEventHandler('RSGCore:Server:OnMoneyChange', function(src, moneytype, amount, operation, reason)
    if not P.Enabled or operation ~= 'add' or type(reason) ~= 'string' or reason == P.Reason then return end
    local hook = saleHook(reason)
    if not hook then return end
    amount = tonumber(amount) or 0
    if amount < (P.MinSale or 0.01) then return end

    local mult = Reputation.GetPriceMultiplier(src, hook.market, 'sell')
    if hook.maxMult then mult = math.min(mult, hook.maxMult) end
    if hook.minMult then mult = math.max(mult, hook.minMult) end
    local delta = round2(amount * mult - amount)
    if math.abs(delta) < 0.01 then return end
    if Config.Debug then print(('[grumpy-reputation] price %s %s $%.2f x%.3f -> %+.2f (%s)'):format(src, moneytype, amount, mult, delta, reason)) end

    -- after the original AddMoney has finished
    SetTimeout(0, function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        if delta > 0 then
            if Player.Functions.AddMoney(moneytype, delta, P.Reason) then
                notify(src, 'price_bonus_' .. hook.market, delta)
            end
        else
            local cut = round2(math.min(-delta, tonumber(Player.Functions.GetMoney(moneytype)) or 0))
            if cut >= 0.01 and Player.Functions.RemoveMoney(moneytype, cut, P.Reason) then
                notify(src, 'price_cut_' .. hook.market, cut)
            end
        end
    end)
end)
