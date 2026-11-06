Config = {}

---------------------------------
-- general settings
---------------------------------
Config.Debug          = false
Config.AutoDatabase   = true  -- create/upgrade the database tables on start (false = import install.sql manually)
Config.ImportRsgTrader = true -- first start only: copy traders and stock from rsg-trader's tables (rsg_trader / rsg_trader_npcs)
Config.Image          = 'rsg-inventory/html/images/' -- location of item images
Config.MaxBuyAmount   = 10    -- max items per buy transaction
Config.MaxSellAmount  = 10    -- max items per sell transaction
Config.InteractDistance = 5.0 -- server-side max distance (m) from the trader to buy/sell/launder
Config.Cooldown       = 2000  -- server-side cooldown (ms) between transactions per player

---------------------------------
-- frontend sounds (PlaySoundFrontend soundName / soundSet). set enabled = false to mute.
---------------------------------
Config.Sounds = {
    enabled = true,
    open    = { name = 'SELECT',   set = 'RDRO_Character_Creator_Sounds' }, -- speak with the trader
    close   = { name = 'BACK',     set = 'RDRO_Character_Creator_Sounds' }, -- close the trader window
    success = { name = 'PURCHASE', set = 'Ledger_Sounds' },                 -- buy / sell completed
    fail    = { name = 'UNAFFORDABLE', set = 'Ledger_Sounds' },             -- buy / sell failed
}

---------------------------------
-- npc settings
---------------------------------
Config.DistanceSpawn = 20.0
Config.FadeIn        = true

---------------------------------
-- dynamic price settings (stock based, from rsg-trader)
---------------------------------
Config.Pricing = {
    priceMultipliers = {
        lowStock    = 1.2, -- stock <= lowstock
        highStock   = 0.9, -- stock >= highstock
        normalStock = 1.0,
    },
    minPriceFactor = 0.7, -- price never below 70% of base
    maxPriceFactor = 1.5, -- price never above 150% of base
    -- traders pay this fraction of their current selling price when buying from players.
    sellFactor = 0.8,
}

---------------------------------
-- Trader kinds. The admin picks one per trader in /traderadmin.
-- The Territories doctrine: honest trade pays clean cash; fences pay dirty money (bloodmoney),
-- which can't buy property until it is laundered.
--   market    grumpy-reputation market for honor/infamy prices ('legal' | 'underground' | nil = off)
--   payWith   money types the player can pay with, tried in order (the whole bill comes from one type)
--   payOut    money type the trader pays sellers with
--   blockLaw  on-duty lawmen (job type 'leo') can't trade here
---------------------------------
Config.Kinds = {
    legal = {
        market   = 'legal',
        payWith  = { 'cash' },
        payOut   = 'cash',
        blockLaw = false,
        defaultBlip = true,
    },
    illegal = {
        market   = 'underground',
        payWith  = { 'bloodmoney', 'cash' },
        payOut   = 'bloodmoney',
        blockLaw = true,
        defaultBlip = false,  -- fences don't advertise
    },
}

-- Money reasons. grumpy-reputation uses these to move standing (trader_sale = legit, fence_sale = outlaw).
-- Don't add them to grumpy-reputation's Config.Pricing.SaleHooks: grumpy-trader applies standing prices itself.
Config.Reasons = {
    legal   = { buy = 'grumpy-trader-buy',   sell = 'grumpy-trader-sell' },
    illegal = { buy = 'grumpy-trader-fence-buy', sell = 'grumpy-trader-fence' },
    launder = 'grumpy-trader-launder',
}

---------------------------------
-- Honor / infamy prices (needs grumpy-reputation; off without it).
-- Selling an item that ANY trader also sells never pays more per unit than that item's lowest possible
-- buy price x grumpy-reputation's arbitrage factor, so nobody can buy low and sell back high.
-- Goods players gather (pelts, stolen jewellery) should be listed as "Players sell only" to get the full bonus.
---------------------------------
Config.Standing = {
    Enabled = true,
}

---------------------------------
-- Laundering: illegal traders with laundering switched on turn bloodmoney into clean cash for a cut.
-- Doctrine: "Dirty cash is heavy... it must be washed through a Hybrid or a fence at a calculated percentage cost."
---------------------------------
Config.Laundering = {
    DefaultCut      = 30,     -- % kept by the fence (admins can set it per trader)
    MinCut          = 5,
    MaxCut          = 90,
    StandingScales  = true,   -- cut x grumpy-reputation underground buy multiplier (outlaws pay less, honorable folk more)
    MinAmount       = 1,      -- smallest dirty amount per wash
    PlayerDailyLimit = 100,   -- most dirty dollars one character can wash per trader per real day (0 = no limit)
    TraderDailyLimit = 500,   -- most dirty dollars one trader washes per real day across all players (0 = no limit)
}

---------------------------------
-- Rumors (needs grumpy-rumors; the option is hidden without it).
-- Traders are informants: legal traders share legal rumors for free, fences only talk after a bribe.
-- Which rumor a player gets (and whether they get one at all) is decided by grumpy-rumors from their standing:
-- an outlaw asking a legal trader, or an honest player bribing a fence, hears nothing and pays nothing.
---------------------------------
Config.Rumors = {
    Enabled  = true,
    Distance = 3.0, -- target distance; the server checks Config.InteractDistance
    Kinds = {
        legal = {
            categories = { 'legal' },   -- grumpy-rumors Config.Rumors[].category values this trader knows
            price      = 0,             -- free: honest folk share news
            cooldown   = 1800,          -- seconds before the same character can ask this trader again
        },
        illegal = {
            categories = { 'illegal' },
            -- Doctrine band: informant tip $0.50 (pricing.md). Fences charge double: outlaws carry "high bribe costs".
            price      = 1.00,
            payWith    = { 'bloodmoney', 'cash' }, -- dirty money first; the whole bribe comes from one type
            standingScales = true,      -- x grumpy-reputation underground buy price (known outlaws pay less, min x0.75)
            cooldown   = 1800,
        },
    },
    Reason = 'grumpy-trader-bribe', -- money reason for the bribe
}

---------------------------------
-- trader npcs
-- traders are stored in the `grumpy_trader_npcs` table and managed in game: /traderadmin
-- Config.DefaultTraders is only used to seed a brand new table (when nothing was imported).
---------------------------------
Config.AdminCommand = 'traderadmin'
Config.DefaultModel = 'mp_u_m_m_trader_01'
Config.PlaceDistance = 30.0 -- /traderadmin: rsg-gizmo range when placing a trader (a ghost of its NPC; you can walk while placing)
Config.DefaultBlip  = { sprite = 'blip_shop_market_stall', scale = 0.2 }

Config.DefaultTraders = {
    --{ traderid = 'emeraldtrader', tradername = 'Emerald Ranch Trader', kind = 'legal', coords = vector4(1440.85, 355.17, 88.55, 102.52) },
}

---------------------------------
-- default items (only inserted into a brand new table). mode: 'both' | 'buy' (players buy only) | 'sell' (players sell only)
---------------------------------
Config.DefaultItems = {
    --{ traderid = 'emeraldtrader', item = 'bread', stock = 0, lowstock = 10, highstock = 100, baseprice = 0.10, mode = 'both' },
}

---------------------------------
-- shared helpers (used by client + server)
---------------------------------
Config.ItemModes = { both = true, buy = true, sell = true }

function Config.Round2(n)
    return math.floor(n * 100 + 0.5) / 100
end
local round2 = Config.Round2

--- Price the trader charges a player for one unit at the given stock level (before standing).
function Config.GetBuyPrice(stock, lowstock, highstock, basePrice)
    local p = Config.Pricing
    local mult = p.priceMultipliers.normalStock
    if stock <= lowstock then
        mult = p.priceMultipliers.lowStock
    elseif stock >= highstock then
        mult = p.priceMultipliers.highStock
    end
    local price = basePrice * mult
    price = math.max(basePrice * p.minPriceFactor, math.min(basePrice * p.maxPriceFactor, price))
    return round2(price)
end

--- Price the trader pays a player for one unit at the given stock level (before standing).
function Config.GetSellPrice(stock, lowstock, highstock, basePrice)
    return round2(Config.GetBuyPrice(stock, lowstock, highstock, basePrice) * Config.Pricing.sellFactor)
end

--- Lowest price this listing can ever be bought for (any stock level), before standing.
function Config.GetLowestBuyPrice(basePrice)
    local p = Config.Pricing
    local m = math.min(p.priceMultipliers.lowStock, p.priceMultipliers.highStock, p.priceMultipliers.normalStock)
    return round2(basePrice * math.max(p.minPriceFactor, m))
end
