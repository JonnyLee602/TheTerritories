Config = {}

Config.Debug = false
Config.AutoDatabase = true               -- create tables on start (set false and import install.sql yourself)

---------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------
Config.AdminCommand = 'pob'              -- /pob opens the admin menu
Config.AdminPermission = 'admin'         -- rsg-core permission for /pob and the government account

---------------------------------------------------------------------
-- Distances / world
---------------------------------------------------------------------
Config.SpawnDistance = 60.0              -- NPC and sign spawn for a client inside this range
Config.InteractDistance = 2.5            -- rsg-target distance
Config.ServerDistance = 6.0              -- server tolerance for "standing at the point" checks
Config.SignModel = 'p_sign_open_close06x' -- data/rdr3_discoveries/objects/object_list.lua (0xD0C40724)
Config.SignOpenRotation = 180.0          -- yaw added when the business is owned (sign shows "Open")

-- /pob editor: every point is placed with rsg-gizmo (you can walk while placing).
-- NPC, hotel door/room and stable preview: a ghost of the business NPC (where someone stands, which way they face).
-- Manager desk, crafting stations and stashes: a small marker you aim at the desk / stove / chest itself.
Config.PlaceDistance = 30.0              -- how far the ghost / marker / prop may be from you
Config.PointMarker = 'p_bottlebeer01x'   -- data/rdr3_discoveries/objects/object_list.lua (0x6DE02925)

-- Crafting station props: "Place prop" puts one of these down when the interior has no stove or bench.
-- Props are spawned locally for every player near the business. The target sits CraftPropZoneHeight above the
-- prop's base. Note: rsg-cooking (Config.WorldStations) also adds its Cook option to every p_stove01x/04x/05x/
-- 06x/07x/09x on the map, so a stove placed here can be cooked on by anyone too. Use a table if you don't want that.
Config.CraftProps = {
    { model = 'p_stove01x',        label = 'Stove (1)' },        -- rsg-cooking world station models
    { model = 'p_stove04x',        label = 'Stove (4)' },
    { model = 'p_stove05x',        label = 'Stove (5)' },
    { model = 'p_stove06x',        label = 'Stove (6)' },
    { model = 'p_stove07x',        label = 'Stove (7)' },
    { model = 'p_stove09x',        label = 'Stove (9)' },
    { model = 'p_craftedtable01x', label = 'Crafted table' },   -- data/rdr3_discoveries/objects/object_list.lua
    { model = 'p_sawbucktable01x', label = 'Sawbuck table' },
    { model = 'p_gen_table01x',    label = 'Plain table' },
}
Config.CraftPropZoneHeight = 0.8         -- metres above the prop's base for the crafting target

---------------------------------------------------------------------
-- Grades (one rsg-core job per business: pob_<id>)
-- Levels are 0..#Config.Grades-1. The last grade is the owner.
-- Grades pay nothing through rsg-core; wages come from the business account.
---------------------------------------------------------------------
Config.JobPrefix = 'pob_'
Config.JobType = 'pob'
Config.Grades = {
    [0] = 'Trainee',
    [1] = 'Employee',
    [2] = 'Supervisor',
    [3] = 'Manager',
    [4] = 'Owner',
}
Config.OwnerGrade = 4

-- Minimum grade for each action (owner can always do everything)
Config.Permissions = {
    stock        = 0, -- stock the shelves at the NPC while on duty
    craft        = 0, -- use crafting stations while on duty
    stash        = 0, -- open business stashes
    stable       = 0, -- keep horses at a business stable
    train        = 1, -- train horses for customers (stables)
    deposit      = 0, -- deposit cash into the business account
    viewAccount  = 2, -- see balance
    ledger       = 2, -- read the ledger
    applications = 2, -- read / accept / reject job applications
    prices       = 2, -- set shop prices and training prices
    takeStock    = 3, -- take stock back out of the shop
    withdraw     = 3, -- withdraw from the business account (daily limit below)
    hire         = 3, -- hire nearby players
    fire         = 3, -- fire employees (only lower grades)
    setGrade     = 3, -- promote / demote (only below your own grade)
    appearance   = 3, -- NPC model and blip style
    recipes      = 3, -- create custom recipes / items
    hotelRate    = 3, -- set the hotel room rate
    rename       = 4, -- rename the business
    wages        = 4, -- set wages per grade
}

-- Daily withdrawal limit per grade (owner = unlimited). nil = unlimited.
Config.WithdrawDailyLimit = {
    [3] = 50,
}

Config.RequireDutyForStash = true        -- stashes need the player on duty
Config.RequireDutyForCraft = true

---------------------------------------------------------------------
-- Money
---------------------------------------------------------------------
Config.MaxPrice = 1000000                -- highest purchase price an admin can set
Config.MaxTransfer = 100000              -- largest single deposit / withdrawal
Config.LedgerPageSize = 50

Config.Government = {
    Command = 'govaccount',              -- opens the government account (admins and the jobs below)
    Jobs = { governor = 0 },             -- [job] = min grade; create the job later in /jobadmin
    RequireDuty = false,
}

Config.Wages = {
    Enabled = true,
    IntervalMinutes = 30,                -- paid to on-duty employees (not the owner) every interval
    Max = 5,                             -- highest wage an owner can set per interval (doctrine: labor is paid in cents)
}

Config.Tax = {
    Enabled = true,
    IntervalDays = 14,                   -- real days between tax bills
    GraceDays = 3,                       -- unpaid tax for this long = business repossessed
    CheckMinutes = 30,                   -- how often bills are checked
    Default = 25,                        -- used when a type has no tax set
}

Config.Repossess = {
    BalanceToGovernment = true,          -- remaining business balance goes to the government
    WipeStock = true,                    -- shop stock is cleared
    WipeStashes = true,                  -- business stashes are emptied
}

---------------------------------------------------------------------
-- Laundering ("back room"). Owner only. Bought once per owner from the business account; lost when the
-- business is repossessed or changes hands. Only business types with launder = true can have one.
-- Doctrine: hybrid fronts wash outlaw money for a cut. Standing (grumpy-reputation) is ignored here.
---------------------------------------------------------------------
Config.Laundering = {
    Enabled    = true,
    Price      = 750,     -- clean $, paid from the business account to the government ("Renovations" in the ledger)
    ServerCut  = 15,      -- % of the dirty money that disappears (a money sink, not paid to anyone)
    MinAmount  = 1,
    -- Weekly allowance: a front can only wash as much as its books can explain.
    -- allowance = max(Floor, SalesShare x legit income over WindowDays) - dirty washed over WindowDays
    -- legit income = ledger kinds 'sale', 'rent', 'training' (washed money is logged as 'private' and doesn't count)
    WindowDays = 7,
    Floor      = 350,     -- $50 a day for a quiet front
    SalesShare = 1.0,
    -- Tips: each wash may tip off on-duty law (rsg-lawman alert at the business, no names)
    Tip = {
        Enabled = true,
        ChancePer100 = 5, -- % chance per $100 dirty washed in one go
        MaxChance = 50,
        Delay = { 60, 300 }, -- seconds before the tip reaches the law
    },
    KeepDays = 60,        -- laundering records are deleted after this many days
}

---------------------------------------------------------------------
-- Law audits. A lawman issues a books warrant at the business (item with metadata, tied to the current
-- owner), then any on-duty lawman holding it can inspect the real books at the manager desk and seize
-- laundered money from the business account into the government account.
---------------------------------------------------------------------
-- Gambling tables (grumpy-gambling 0.6.0+): the owner buys the table items from the manager's "Gambling" tab and
-- places them in the business. Paid from the business account to the government ("Furnishings" in the ledger).
-- grumpy-gambling sets the per-business limits. Prices: no doctrine band yet; set against the back room ($750) and
-- a town business ($1,500 – $3,000). A card table earns the box half the rake (about $0.25 – $3 per player-hour).
Config.Gambling = {
    Enabled  = true,
    Resource = 'grumpy-gambling',
    Prices   = { pvp = 150, pvd = 250 },   -- clean $: Card Table, Dealer's Table
}

Config.Audit = {
    Enabled       = true,
    Item          = 'books_warrant', -- add to rsg-core/shared/items.lua (see README)
    JobTypes      = { leo = true },  -- job.type values that count as law
    MinGrade      = 2,               -- lowest grade that may ISSUE a warrant (any on-duty lawman may use one)
    RequireOnDuty = true,
    Minutes       = 60,              -- warrant lifetime
    Cooldown      = 30,              -- seconds between warrants per officer
    LookbackDays  = 14,              -- washes older than this can't be proven (or seized)
    AllowSeize    = true,            -- officers can seize laundered money found in the books
    NotifyOwner   = true,            -- owner (if online) is told when the books are inspected or seized
}

---------------------------------------------------------------------
-- Shop / stock
---------------------------------------------------------------------
Config.Shop = {
    MinPrice = 0.01,                     -- doctrine: a cheap meal is $0.05-0.10
    MaxPrice = 1000,
    MinQuality = 0,                      -- items with info.quality below this are handed back when stocking
    StockSlots = 30,                     -- size of the stock box
    StockWeight = 200000,
}

---------------------------------------------------------------------
-- Stashes / crafting stations (placed by admins)
---------------------------------------------------------------------
Config.MaxCraftStations = 3
Config.MaxStashes = 3
Config.Stash = { Slots = 50, Weight = 400000 }
Config.CraftCooldownMs = 1500

---------------------------------------------------------------------
-- Applications
---------------------------------------------------------------------
Config.Applications = {
    MaxLength = 500,
    CooldownMinutes = 60,                -- per player per business
    MaxPending = 30,                     -- per business
}

---------------------------------------------------------------------
-- Appearance choices for managers (admins may set any valid model)
-- Ped names from data/rdr3_discoveries/objects/object_list.lua
---------------------------------------------------------------------
Config.NpcModels = {
    { label = 'Valentine Bartender', model = 'u_m_m_valbartender_01' },
    { label = 'Rhodes Bartender',    model = 'u_m_m_rhdbartender_01' },
    { label = 'Hotel Owner',         model = 'u_m_m_valhotelowner_01' },
    { label = 'Stable Hand',         model = 'u_m_m_bwmstablehand_01' },
    { label = 'Store Owner',         model = 'u_m_m_nbxgeneralstoreowner_01' },
}

-- Sprites from data/rdr3_discoveries/useful_info_from_rpfs/textures/blips/README.md
Config.BlipSprites = {
    { label = 'Saloon',      sprite = 'blip_saloon' },
    { label = 'Hotel',       sprite = 'blip_hotel_bed' },
    { label = 'Stable',      sprite = 'blip_shop_horse' },
    { label = 'Saddler',     sprite = 'blip_shop_horse_saddle' },
    { label = 'Store',       sprite = 'blip_shop_store' },
    { label = 'Butcher',     sprite = 'blip_shop_butcher' },
    { label = 'Market',      sprite = 'blip_shop_market_stall' },
    { label = 'Food',        sprite = 'blip_supplies_food' },
}

-- Modifiers from data/rdr3_discoveries/useful_info_from_rpfs/blip_modifiers/README.md
Config.BlipColors = {
    { label = 'Default', color = '' },
    { label = 'Red',     color = 'BLIP_MODIFIER_MP_COLOR_1' },
    { label = 'Blue',    color = 'BLIP_MODIFIER_MP_COLOR_2' },
    { label = 'Yellow',  color = 'BLIP_MODIFIER_MP_COLOR_3' },
    { label = 'Green',   color = 'BLIP_MODIFIER_MP_COLOR_6' },
    { label = 'Purple',  color = 'BLIP_MODIFIER_MP_COLOR_8' },
}
Config.BlipScale = 0.2
Config.BlipStyle = 1664425300            -- default coords blip style (same as grumpy-hotel)

---------------------------------------------------------------------
-- Custom recipes (owner-made items)
-- Needs the rsg-inventory and rsg-consume patches in integrations/.
---------------------------------------------------------------------
Config.CustomRecipes = {
    Enabled = true,
    MaxPerBusiness = 10,
    NameMin = 3, NameMax = 30,
    DescriptionMax = 120,
    MaxIngredients = 4,
    MaxIngredientAmount = 10,
    MaxOutput = 3,
    CraftTime = { min = 3000, max = 20000 },
    BlockedWords = {},                   -- lower-case words; a name/description containing any of these is rejected at once
}

-- Approval of custom recipes and images
Config.Approval = {
    Mode = 'timed',                      -- 'manual' (a person must approve), 'auto' (no approval), 'timed'
    AutoApproveMinutes = 15,             -- timed: approve automatically after this long without a decision
    AutoApproveOnlyIfNoAdminOnline = true, -- timed: only auto-approve while no admin is in game
    ImagesNeedHuman = true,              -- auto-approved items use the base image until a person approves the custom image
    Discord = {
        Enabled = false,                 -- needs Discord.BotToken etc. in server/sv_config.lua
        PollSeconds = 30,
        ImagePollHours = 72,             -- keep watching an auto-approved message for the image decision this long
    },
}

-- Image uploads (Fivemanage). API key goes in server/sv_config.lua.
Config.Images = {
    Enabled = false,
    MaxKB = 512,
    Types = { 'image/png', 'image/jpeg', 'image/webp' },
    AllowedPrefix = 'https://r2.fivemanage.com/', -- the URL Fivemanage returns must start with this
    PresignCooldown = 30,                -- seconds between upload links per player
}

---------------------------------------------------------------------
-- Horse training (stable businesses, needs the rsg-stables patch)
---------------------------------------------------------------------
Config.Training = {
    Enabled = true,
    Stats = { 'health', 'stamina', 'speed', 'accel', 'courage' }, -- rsg-stables Config.Training.statOrder keys
    DefaultPrice = 3,
    MinPrice = 1, MaxPrice = 25,          -- doctrine: a working horse costs $15-35
    BusinessShare = 0.40,                -- 40% to the business account
    EmployeeShare = 0.60,                -- 60% cash to the trainer
    Xp = 60,                             -- XP added to the stat per session
    DurationMs = 20000,                  -- trainer's progress bar
    Scenario = 'WORLD_HUMAN_CROUCH_INSPECT',
    HorseDistance = 8.0,                 -- horse must be this close to the trainer
    StableDistance = 30.0,               -- trainer and customer must be this close to the business NPC
    RequestMinutes = 10,                 -- open requests expire after this
}

---------------------------------------------------------------------
-- Business types. Add more by copying one.
--   shop      = true: the NPC sells stocked goods through rsg-stores
--   stock     = items employees may stock (rsg-core item categories + extra item names)
--   crafting  = true: needs 1..Config.MaxCraftStations crafting stations
--   recipes   = fixed recipes for this type (item names from rsg-core shared/items.lua)
--   custom    = custom recipe rules (bases must be rsg-consume consumables), nil = no custom recipes
--   hotel     = grumpy-hotel integration (admin sets rooms; points door + interior)
--   stable    = rsg-stables integration (points preview)
--   tax       = per Config.Tax.IntervalDays
---------------------------------------------------------------------
local drinkFoodRecipes = {
    { item = 'bottle_beer',  amount = 1, time = 6000,  ingredients = { wheat = 2, yeast = 1, water = 1 } },
    { item = 'glass_whisky', amount = 2, time = 8000,  ingredients = { corn = 2, yeast = 1, sugar = 1 } },
    { item = 'coffee',       amount = 1, time = 4000,  ingredients = { coffee_beans = 1, water = 1 } },
    { item = 'bread',        amount = 2, time = 6000,  ingredients = { wheat = 2, yeast = 1 } },
    { item = 'stew',         amount = 1, time = 10000, ingredients = { raw_meat = 1, potato = 1, carrot = 1 } },
    { item = 'cooked_meat',  amount = 1, time = 5000,  ingredients = { raw_meat = 1 } },
}

local drinkFoodCustom = {
    bases = { 'bottle_beer', 'glass_whisky', 'glass_rum', 'glass_gin', 'glass_wine_red', 'coffee', 'tea', 'bread', 'stew', 'stew_veg', 'cooked_meat', 'pie_peach' },
    ingredients = { 'wheat', 'corn', 'yeast', 'sugar', 'water', 'coffee_beans', 'raw_meat', 'potato', 'carrot', 'apple', 'orange', 'peach', 'blackberry', 'raspberry' },
}

Config.Types = {
    saloon = {
        label = 'Saloon',
        price = 2000,                   -- doctrine: Enterprise tier (an elite horse is $125-250)
        tax = 20,
        npcModel = 'u_m_m_valbartender_01',
        blip = { sprite = 'blip_saloon', color = '' },
        shop = true,
        stock = { categories = { 'consumable' }, items = {} },
        crafting = true,
        recipes = drinkFoodRecipes,
        custom = drinkFoodCustom,
        launder = true,                 -- can buy a back room (Config.Laundering)
    },
    restaurant = {
        label = 'Restaurant',
        price = 1500,
        tax = 15,
        npcModel = 'u_m_m_nbxgeneralstoreowner_01',
        blip = { sprite = 'blip_supplies_food', color = '' },
        shop = true,
        stock = { categories = { 'consumable' }, items = {} },
        crafting = true,
        recipes = drinkFoodRecipes,
        custom = drinkFoodCustom,
        launder = true,
    },
    hotel = {
        label = 'Hotel',
        price = 2500,
        tax = 25,
        npcModel = 'u_m_m_valhotelowner_01',
        blip = { sprite = 'blip_hotel_bed', color = '' },
        shop = false,
        crafting = false,
        launder = true,
        hotel = {
            maxRooms = 20,               -- admin picks 1..maxRooms
            defaultRate = 5,             -- per day, owners change it
            maxRate = 100,
            maxDays = 7,
        },
    },
    stable = {
        label = 'Stable',
        price = 3000,
        tax = 30,
        npcModel = 'u_m_m_bwmstablehand_01',
        blip = { sprite = 'blip_shop_horse', color = '' },
        shop = true,
        stock = { categories = { 'horse' }, items = {} },
        crafting = true,
        launder = true,                 -- a livery: the doctrine's classic front
        recipes = {
            { item = 'haysnack',        amount = 2, time = 5000, ingredients = { wheat = 2 } },
            { item = 'horsemeal',       amount = 1, time = 7000, ingredients = { wheat = 1, corn = 1, carrot = 1 } },
            { item = 'horse_stimulant', amount = 1, time = 9000, ingredients = { sugar = 2, apple = 1 } },
        },
        custom = nil,                    -- horse items use rsg-stables' own use code, so no custom items
        stable = {
            maxHorses = 40,              -- per employee at this stable (rsg-stables default is Config.MaxHorsesPerStable)
            capExempt = true,            -- horses here don't count toward rsg-stables Config.MaxOwnedHorses
            fallback = 'valentine',      -- rsg-stables Config.Stables name: fired staff / deleted business horses move here
        },
        training = true,
    },
}
