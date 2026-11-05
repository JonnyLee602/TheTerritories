-- honor / infamy price multipliers (client + server). See Config.Pricing and doctrine/pricing.md.
Rep = Rep or {}

local function round3(n) return math.floor(n * 1000 + 0.5) / 1000 end

---Multiplier for one market side at a given standing. 1.0 when off or unknown.
---@param standing number
---@param market string 'legal' | 'underground'
---@param side string 'buy' | 'sell'
function Rep.PriceMultiplier(standing, market, side)
    local P = Config.Pricing
    if not P or not P.Enabled then return 1.0 end
    local m = P.Markets[market]
    local ends = m and m[side]
    if not ends then return 1.0 end
    standing = Rep.Clamp(standing)
    local dz = math.max(0, P.Deadzone or 0)
    local a = math.abs(standing)
    if a <= dz then return 1.0 end
    local limit = standing > 0 and Config.Standing.Max or -Config.Standing.Min
    local span = limit - dz
    local f = span > 0 and math.min(1, (a - dz) / span) or 1
    local target = tonumber(standing > 0 and ends.honor or ends.infamy) or 1.0
    return round3(1 + (target - 1) * f)
end

---Market an rsg-stores shop belongs to: 'legal', 'underground' or 'none'.
function Rep.MarketForShop(shopName)
    local P = Config.Pricing
    if not P or not P.Enabled or type(shopName) ~= 'string' then return 'none' end
    for _, pat in ipairs(P.ExcludePatterns or {}) do
        if shopName:match(pat) then return 'none' end
    end
    return P.Shops[shopName] or P.DefaultMarket or 'none'
end

---buy, sell multipliers for a shop at a given standing (1.0, 1.0 for 'none')
function Rep.ShopMultipliers(standing, shopName)
    local market = Rep.MarketForShop(shopName)
    if market == 'none' then return 1.0, 1.0, market end
    return Rep.PriceMultiplier(standing, market, 'buy'), Rep.PriceMultiplier(standing, market, 'sell'), market
end

---Lowest buy multiplier anyone can get, times the margin: a sell bonus is capped at
---(cheapest shop price x this) per unit so buying and selling back never makes money.
function Rep.ArbitrageFactor()
    local P = Config.Pricing
    local low = 1.0
    for _, m in pairs(P and P.Markets or {}) do
        if m.buy then low = math.min(low, tonumber(m.buy.honor) or 1.0, tonumber(m.buy.infamy) or 1.0) end
    end
    return low * (P and P.ArbitrageMargin or 0.95)
end
