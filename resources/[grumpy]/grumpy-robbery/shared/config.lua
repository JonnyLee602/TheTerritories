Config = {}

Config.Debug = false
Config.AutoDatabase = true   -- create grumpy_robbery_stores on start (or import install.sql)

-- Stores come from rsg-stores (NPC shops only, read from rsg_shops_npcs). rsg-stores itself is not changed.
Config.StoreRefresh = 300     -- seconds between re-reading rsg-stores' NPC shops (admins add shops in game)
Config.ClerkScenario = 'WORLD_HUMAN_STAND_IMPATIENT' -- rsg-stores' Config.DefaultScenario, restored after a robbery
Config.ClerkFindRadius = 2.5  -- how close a ped must be to the store's saved coords to count as its clerk

---------------------------------------------------------------------
-- Register robbery: aim a gun at the clerk and keep them covered
---------------------------------------------------------------------
Config.Robbery = {
    Enabled        = true,
    DefaultEnabled = true,      -- new stores are robbable until an admin turns them off
    AimDistance    = 8.0,       -- max distance to the clerk to start
    LeaveDistance  = 12.0,      -- leave this far from the clerk and the robbery fails (server-checked)
    Duration       = 30,        -- seconds the clerk must be held up
    Grace          = 3,         -- seconds you may lower your gun before it fails
    MoneyType      = 'bloodmoney',
    CashMin        = 15,        -- doctrine: low-tier score (illegal tiers 1-3 pay $25-57 per job)
    CashMax        = 45,
    StoreCooldown  = 3600,      -- seconds before the same store can be robbed again
    FailCooldown   = 600,       -- cooldown after a failed robbery
    GlobalCooldown = 0,         -- seconds between any two robberies server-wide (0 = off)
    MinLawmen      = 0,         -- on-duty law needed to start (0 = off)
    BlockLawmen    = true,      -- on-duty lawmen can't rob
    AlertLaw       = true,      -- the clerk reports the robbery (through grumpy-law if running, else a direct rsg-lawman alert)
    AlertDelay     = 5,         -- seconds before the direct alert (only used without grumpy-law)
}

---------------------------------------------------------------------
-- Safe: optional per store (admin sets it). Opens after a successful register robbery
-- for the robber and their posse, for a short window.
---------------------------------------------------------------------
Config.Safe = {
    Enabled      = true,
    Window       = 300,          -- seconds after the robbery the safe can be cracked
    Distance     = 2.0,          -- server-checked distance to the safe
    MaxAttempts  = 3,            -- failed attempts before it jams for this robbery
    MinSeconds   = 4,            -- an attempt shorter than this is rejected
    CrackTime    = 15000,        -- ms progress bar when rsg-lockpick isn't running
    FallbackChance = 50,         -- % success without the minigame (rolled on the server)
    RequiredItem = nil,          -- e.g. 'lockpick' (must exist in your items) or nil
    BreakChance  = 30,           -- % RequiredItem breaks on a failed attempt
    CashMin      = 50,           -- doctrine: a mid-tier score; the top syndicate job pays $250
    CashMax      = 150,
    Items        = {},           -- e.g. { { name = 'goldbar', min = 1, max = 1, chance = 25 } }
    PropModel    = 'p_gen_safe01', -- data/rdr3_discoveries/objects/object_list.lua
}

-- /robberyadmin: shelf points and the "existing safe" point are placed with rsg-gizmo using this small marker.
-- Aim it at the shelf / safe itself: it sits on the surface you aim at, and that spot becomes the target point.
Config.PointMarker = 'p_bottlebeer01x' -- data/rdr3_discoveries/objects/object_list.lua (0x6DE02925)
Config.PlaceDistance = 12.0           -- rsg-gizmo: how far the marker may be from you (you can walk while placing)

---------------------------------------------------------------------
-- Shoplifting: up to 4 shelf points per store (admin sets them). Always available.
---------------------------------------------------------------------
Config.Shoplift = {
    Enabled        = true,
    MaxShelves     = 4,
    Distance       = 2.0,        -- server-checked distance to the shelf
    Time           = 4000,       -- ms to pocket something
    Cooldown       = 180,        -- seconds per player per store after a clean steal
    CaughtCooldown = 900,        -- seconds per player per store after being caught
    MaxPrice       = 1.0,        -- only items priced at or below this in that store
    AllowLimitedStock = false,   -- false = only items the shop sells with unlimited stock (stock is never changed)
    Blacklist      = { 'dollar', 'cent', 'blood_dollar', 'blood_cent' },
    -- catch chance (%), rolled on the server
    BaseChance     = 15,
    ClerkSees      = 45,         -- added when the clerk has line of sight
    PerWitness     = 10,         -- added per other player nearby who isn't in your posse
    WitnessRadius  = 10.0,
    MaxChance      = 90,
    AlertLaw       = true,       -- the clerk reports you when caught
    AmbientWitnesses = true,     -- with grumpy-law: NPCs nearby can witness a steal the clerk missed
    Anim = { dict = 'mech_pickup@loot@armoire_sml', clip = 'base' }, -- animations/ingameanims
}

---------------------------------------------------------------------
-- Admin menu
---------------------------------------------------------------------
Config.AdminCommand    = 'robberyadmin'
Config.AdminPermission = 'admin'
Config.MaxPointDistance = 40.0   -- shelves/safe must be within this distance of the store's clerk

-- Reputation (grumpy-reputation). Outlaw standing is only GAINED by succeeding: the store_robbery and
-- safe_crack money hooks fire on payouts. Failing or getting caught by the clerk shrinks standing toward 0.
Config.Reputation = {
    robberyFailed  = 'robbery_failed',      -- towardZero penalty
    shopliftCaught = 'caught_shoplifting',  -- towardZero penalty
}
