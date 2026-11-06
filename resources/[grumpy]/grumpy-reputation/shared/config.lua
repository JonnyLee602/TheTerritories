Config = {}

Config.Debug = false
Config.AutoDatabase = true -- create grumpy_reputation_pending on start (or import install.sql)

---------------------------------------------------------------------
-- Standing: one axis. Positive = legit, negative = outlaw.
-- Stored in rsg-core rep: metadata.rep[Config.Standing.RepKey]
---------------------------------------------------------------------
Config.Standing = {
    RepKey = 'standing',
    Min    = -1000,
    Max    = 1000,
    Start  = 0,
}

-- checked from the top down: the first tier whose min the standing reaches wins
Config.Tiers = {
    { name = 'upstanding', min = 600 },
    { name = 'respected',  min = 200 },
    { name = 'neutral',    min = -199 },
    { name = 'outlaw',     min = -599 },
    { name = 'notorious',  min = -1000 },
}

---------------------------------------------------------------------
-- Actions: what moves standing. amount > 0 = legit, < 0 = outlaw.
-- dailyCap = most standing (absolute) one character can get from this action per real day (nil = no cap)
---------------------------------------------------------------------
Config.Actions = {
    -- legal work
    delivery        = { amount = 4,   dailyCap = 40 },
    fish_sale       = { amount = 2,   dailyCap = 30 },
    butcher_sale    = { amount = 2,   dailyCap = 30 },
    trader_sale     = { amount = 2,   dailyCap = 30 },
    lumber_sale     = { amount = 3,   dailyCap = 30 },
    bounty_turnin   = { amount = 10,  dailyCap = 60 },
    moonshine_raid  = { amount = 8,   dailyCap = 40 },
    medic_reward    = { amount = 3,   dailyCap = 30 },

    -- illegal work: always counts, witnessed or not
    drug_sale       = { amount = -3,  dailyCap = 45 },
    drug_export     = { amount = -8,  dailyCap = 60 },
    horse_fence     = { amount = -8,  dailyCap = 48 },
    fence_sale      = { amount = -5,  dailyCap = 50 },  -- for your own fence script
    chop_wagon      = { amount = -10, dailyCap = 60 },  -- for your own chop-shop script
    store_robbery   = { amount = -15, dailyCap = 60 },  -- grumpy-robbery register hold-up
    safe_crack      = { amount = -10, dailyCap = 40 },  -- grumpy-robbery safe
    blood_money     = { amount = -2,  dailyCap = 30 },  -- any bloodmoney payout not matched below

    -- caught by the law: a slight outlaw gain (call from law scripts)
    charged         = { amount = -4,  dailyCap = 12 },
    jailed          = { amount = -8,  dailyCap = 16 },

    -- crime witnessed / reported, for a witness script to use ONLY when the crime itself succeeded
    crime_reported  = { amount = -5,  dailyCap = 30 },
    -- grumpy-law: a reported crime that SUCCEEDED, and the criminal stayed free and alive through the heat window
    escaped         = { amount = -6,  dailyCap = 36 },

    -- failures: towardZero = shrink the player's reputation toward 0 by `amount`, never past it.
    -- A failed criminal loses outlaw cred and a legit player loses respectability; nobody gains rep by failing.
    robbery_failed      = { amount = 10, towardZero = true },
    caught_shoplifting  = { amount = 5,  towardZero = true },
}

---------------------------------------------------------------------
-- Money hooks: rsg-core fires RSGCore:Server:OnMoneyChange on the server for every payout.
-- Any 'add' whose reason matches below applies the action. No RSG resource needs editing.
-- reason = exact reason string, pattern = Lua pattern. First match wins.
---------------------------------------------------------------------
Config.MoneyHooks = {
    { reason = 'rsg-deliveries-complete', action = 'delivery' },
    { reason = 'fishmonger-sale',         action = 'fish_sale' },
    { reason = 'rsg-hunting-butcher',     action = 'butcher_sale' },
    { reason = 'vendor-sale',             action = 'trader_sale' },
    { reason = 'rsg-trader-sell',         action = 'trader_sale' },
    { reason = 'grumpy-trader-sell',      action = 'trader_sale' },  -- grumpy-trader legal trader
    { reason = 'grumpy-trader-fence',     action = 'fence_sale' },   -- grumpy-trader illegal trader (fence)
    { reason = 'lumberjack-wagon-sale',   action = 'lumber_sale' },
    { reason = 'rsg-bountyhunter-reward', action = 'bounty_turnin' },
    { reason = 'moonshine-raid',          action = 'moonshine_raid' },
    { reason = 'rsg-medic-reward',        action = 'medic_reward' },
    { reason = 'rsg-drugs-npc-sale',      action = 'drug_sale' },
    { reason = 'rsg-drugs-export',        action = 'drug_export' },
    { reason = 'rsg-stables-horse-fence', action = 'horse_fence' },
    { reason = 'grumpy-robbery-store',    action = 'store_robbery' },
    { reason = 'grumpy-robbery-safe',     action = 'safe_crack' },
}
Config.BloodMoneyAction = 'blood_money' -- any unmatched bloodmoney 'add' (nil = off)
Config.MinHookAmount = 1                 -- ignore payouts smaller than this
-- money handed back (a failed purchase or bribe) isn't income: never moves standing. Lua patterns.
Config.IgnoreReasons = { '%-refund$' }

---------------------------------------------------------------------
-- Honor / infamy pricing (doctrine/pricing.md section 2).
-- Merchants read the standing of whoever is at the counter ("lazy sync": read once per sale or
-- shop visit, never polled). Multipliers are linear from 1.0 at the edge of the dead zone to the
-- honor value at +Max standing and the infamy value at Min standing.
---------------------------------------------------------------------
Config.Pricing = {
    Enabled  = true,
    Deadzone = 199,   -- |standing| at or below this pays normal prices (the 'neutral' tier)

    -- buy  = what the player pays (x price), sell = what the player is paid (x payout)
    Markets = {
        legal = {        -- general stores, butchers, trappers, fishmongers, bars
            buy  = { honor = 0.75, infamy = 1.50 },
            sell = { honor = 1.50, infamy = 0.50 },
        },
        underground = {  -- fences, black-market traders, outlaw contacts
            buy  = { honor = 1.50, infamy = 0.75 },
            sell = { honor = 0.50, infamy = 1.50 },
        },
    },

    -- rsg-stores NPC shops (needs integrations/rsg-stores.md). Market by shop name (rsg-stores 'shop_name');
    -- unlisted shops use DefaultMarket. 'none' = normal prices. Player-owned stores are never touched.
    DefaultMarket = 'legal',
    Shops = {
        -- ['valentine_fence'] = 'underground',
    },
    ExcludePatterns = { '^pob_' },   -- grumpy-pob businesses set their own prices

    -- rsg-stores: selling an item that some store also sells never pays more per unit than
    -- (cheapest store price x lowest buy multiplier x ArbitrageMargin), so nobody can buy low and sell back high.
    -- Keep store prices of goods the SaleHooks resources buy (fish, meat, lumber) above 2x what those resources pay.
    ArbitrageMargin = 0.95,

    -- Sales in other RSG resources: after a payout with this reason, the difference is added or taken
    -- (same money type) and the player is told why. maxMult / minMult clamp the multiplier.
    -- Resources that also SELL what they buy (rsg-trader) are capped at 1.0 so honor can't create a money loop.
    SaleHooks = {
        { reason = 'rsg-hunting-butcher',     market = 'legal' },
        { reason = 'vendor-sale',             market = 'legal' },
        { reason = 'fishmonger-sale',         market = 'legal' },
        { reason = 'lumberjack-wagon-sale',   market = 'legal' },
        { reason = 'rsg-ranch-animal-sale',   market = 'legal' },
        { reason = 'rsg-ranch-market-sale',   market = 'legal' },
        { reason = 'rsg-trader-sell',         market = 'legal', maxMult = 1.0 },
        -- grumpy-trader prices by standing itself: never add its reasons here
        { reason = 'rsg-drugs-npc-sale',      market = 'underground' },
        { reason = 'rsg-drugs-export',        market = 'underground' },
        { reason = 'rsg-stables-horse-fence', market = 'underground' },
    },
    MinSale    = 0.05,                       -- ignore payouts smaller than this
    NotifySale = true,                       -- tell the player about the bonus / cut
    Reason     = 'grumpy-reputation-price',  -- money reason for the adjustment (ignored by the rep hooks)
}

---------------------------------------------------------------------
-- Decay: standing drifts toward 0 when a character hasn't earned or lost any for a while
---------------------------------------------------------------------
Config.Decay = {
    enabled   = true,
    afterDays = 7,   -- days without a standing change before decay starts
    perDay    = 10,  -- points per day after that, toward 0
}

---------------------------------------------------------------------
-- Player notifications
---------------------------------------------------------------------
Config.NotifyTierChange = true   -- "People are starting to talk about you..."
Config.NotifyEveryChange = false -- small notify on every change (good for testing)

---------------------------------------------------------------------
-- /rep panel
---------------------------------------------------------------------
Config.Command = 'rep'
Config.ShowStandingNumber = true -- false = only the tier name and bar
-- order of the other rep values. Unlisted keys are shown after these, sorted by name.
-- labels come from locales: "rep_<key>" (falls back to the key itself)
Config.RepOrder = { 'hunting', 'fishing', 'cooking', 'crafting', 'drugs' }
Config.HideRep = {}              -- e.g. { drugs = true } to keep a key out of the panel

---------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------
Config.AdminCommand = 'setstanding'   -- /setstanding [id] [value]
Config.AdminPermission = 'admin'
