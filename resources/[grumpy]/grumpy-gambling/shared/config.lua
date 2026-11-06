Config = {}

Config.Debug = false
Config.AutoDatabase = true                 -- create tables from install.sql on start
Config.DevGames = false                    -- dev servers only: placeholder "Test (no gameplay)" games so tables can start
                                           -- and buy-in / cash-out can be tried before any game module is installed

---------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------
Config.AdminCommand = 'gambling'           -- /gambling opens the admin panel
Config.AdminPermission = 'admin'           -- rsg-core permission level
Config.PlaceDistance = 10.0                -- rsg-gizmo range when placing or moving a table
Config.BindSearchRadius = 3.0              -- "bind nearest world table" looks this far around the admin
Config.Micro = { Max = 2 }                 -- the doctrine's practice tables: exactly two on the server

---------------------------------------------------------------------
-- World and seating
---------------------------------------------------------------------
Config.SpawnDistance = 40.0                -- tables, chairs and dealers spawn for players within this range
Config.SeatZoneRadius = 0.6                -- rsg-target sphere around each seat
Config.InteractDistance = 2.0              -- rsg-target reach for "Sit down"
Config.ServerSeatDistance = 3.5            -- server tolerance between a player and the seat they ask for
Config.SetupTimeoutSeconds = 120           -- the first player has this long to pick game and tier before
                                           -- the choice passes to another seated player
Config.Seating = {
    Scenario = 'GENERIC_SEAT_CHAIR_TABLE_SCENARIO', -- data/rdr3_discoveries/animations/scenarios/scenario_types_with_conditional_anims.lua
    FemaleZ = 0.0,                         -- extra height for female peds if they clip into chairs
    FreezeWorldChairRadius = 0.75,         -- bound map tables: world chairs this close to a seat are frozen
    StandKey = 0xE3BF959B,                 -- INPUT_CONTEXT_X (R), data/rdr3_discoveries/Controls/README.md
    SetupKey = 0x760A9C6F,                 -- INPUT_INTERACT_OPTION1 (G), same file
    StandHoldMs = 750,
}

-- Placed (spawned) tables hide the map's own chairs around them while spawned, so they don't pile up on the
-- table's chairs. Map (bound) tables are never affected. CREATE_MODEL_HIDE_EXCLUDING_SCRIPT_OBJECTS (natives/db).
Config.HideMapChairs = {
    Enabled = true,
    Radius = 2.2,                          -- metres from the table centre
    Models = {                             -- data/rdr3_discoveries/objects/object_list.lua
        'p_windsorchair03x',
        'p_chairpokerfancy01x',
        'p_gen_chairpokerfancy01x',
    },
}

-- A chip stack on the table in front of every player with chips, one model per tier, so people walking past can
-- tell the stakes. Models: data/rdr3_discoveries/objects/object_list.lua (s_minigame.rpf).
Config.ChipStacks = {
    Enabled = true,
    Models = {
        micro = 'p_chips_la_bas02x',
        low = 'p_crd_chips040x',
        mid = 'p_crd_chips440x',
        high = 'p_crd_chips449x',
    },
    Forward = 0.6,                         -- metres from the chair toward the table (NT puts bet chips ~0.68 m out)
    Height = 0.80,                         -- metres above the floor, about the table top (a model can override both:
                                           -- chipForward / chipHeight in shared/models.lua)
}

-- Table UI (phase 4): the panel shown while seated
Config.TableUI = {
    AutoFocus = true,                      -- take the mouse when it's your turn (Esc gives it back, G takes it again)
    FeedLines = 8,                         -- lines of the table feed shown
}

-- NPC players (phase 3: seat plumbing + dev /ggbot; phase 5: seating rule, win cap, brains, regulars)
Config.Npc = {
    Models = { 'a_m_m_valtownfolk_01', 'a_m_m_rhdtownfolk_01', 'a_f_m_valtownfolk_01' }, -- data/rdr3_discoveries/peds/peds_list.lua
    Names = { 'Silas', 'Walter', 'Ezra', 'Martha', 'Josephine', 'Clara' },
}

Config.Dealer = {
    Model = 'u_m_m_bht_saintdenissaloon',  -- data/rdr3_discoveries/peds/peds_list.lua
    Seated = true,                         -- sit the dealer in a chair behind the table (like Nt_Blackjack)
    Chair = 'p_windsorchair03x',           -- the dealer's chair (data/rdr3_discoveries/objects/object_list.lua)
    ChairYaw = 180.0,                      -- p_windsorchair03x's model faces backwards (seen in game 2026-11-05)
    IdleDict = 'mini_games@blackjack_mg@dealer@self@idle', -- data/rdr3_discoveries/animations/ingameanims/ingameanims_list.lua
    IdleClip = 'idle',
    IdleFlag = 25,                         -- 1 loop + 8 upper body + 16 secondary: dealer arms over the seated (or
                                           -- standing) pose. Full body (1) plays the seated clip with no chair under him.
                                           -- Set IdleDict = nil for no idle.
}

Config.Calibration = {
    FaceTable = true,                      -- calibrated seats face the table centre (only the chair position matters)
}

Config.Blips = {
    Enabled = true,
    Style = 1664425300,                    -- default coords blip style (same as grumpy-pob)
    Sprites = {                            -- data/rdr3_discoveries/useful_info_from_rpfs/textures/blips/README.md
        pvp = 'blip_mg_poker',
        pvd = 'blip_mg_blackjack',
    },
}

---------------------------------------------------------------------
-- Currencies (doctrine: a table is cash OR bloodmoney, never both)
---------------------------------------------------------------------
Config.Currencies = { 'cash', 'bloodmoney' }

---------------------------------------------------------------------
-- Stake tiers (DESIGN.md §6, approved 2026-11-05)
-- Money values follow doctrine/pricing.md: a saloon drink is $0.10–0.20 (Low big blind),
-- a working horse $15–35 (High buy-in). NPC caps sit at the matching job-matrix tier.
---------------------------------------------------------------------
Config.Tiers = {
    micro = {
        order = 1, label = 'tier_micro', stage = 'Training',
        smallBlind = 0.01, bigBlind = 0.02,        -- below Low; practice tables only
        buyInMin = 13, buyInMax = 26,              -- × big blind: $0.26 – $0.52
        npcCapMultiplier = 20,                     -- × min buy-in = $5.20 per window (below a tier-1 job, $15)
        choosable = false,                         -- only on the two fixed Micro tables
        bloodmoney = false,
    },
    low = {
        order = 2, label = 'tier_low', stage = 'Survival',
        smallBlind = 0.05, bigBlind = 0.10,        -- big blind = a saloon drink
        buyInMin = 13, buyInMax = 26,              -- $1.30 – $2.60
        npcCapMultiplier = 20,                     -- $26 per window = tier 2 job ($22–26)
        choosable = true, bloodmoney = true,
    },
    mid = {
        order = 3, label = 'tier_mid', stage = 'Stability',
        smallBlind = 0.25, bigBlind = 0.50,
        buyInMin = 13, buyInMax = 26,              -- $6.50 – $13.00
        npcCapMultiplier = 10,                     -- $65 per window = tier 5 job ($55–62)
        choosable = true, bloodmoney = true,
    },
    high = {
        order = 4, label = 'tier_high', stage = 'Enterprise',
        smallBlind = 1.00, bigBlind = 2.00,
        buyInMin = 13, buyInMax = 26,              -- $26 – $52 (a working horse)
        npcCapMultiplier = 5,                      -- $130 per window = tier 7–8 job ($102–150)
        choosable = true, bloodmoney = true,
    },
}

Config.Pvd = {
    MaxBetMultiplier = 10,                     -- PVD max bet = 10 × min bet (min bet = the tier's big blind)
}

---------------------------------------------------------------------
-- Money (DESIGN.md §7). Amounts inside the core are integer cents.
---------------------------------------------------------------------
Config.Money = {
    SavePlayer = true,                     -- rsg-core Player.Functions.Save() after a buy-in or cash-out
    BuyInStep = 'smallBlind',              -- the buy-in slider moves in small blinds
}

---------------------------------------------------------------------
-- Rake (DESIGN.md §6.3, approved 2026-11-05). Taken out of every bet; auto-tuned so the average player loses
-- about Target units per player-hour: big blinds at PVP, minimum bets at PVD (the game's own edge counts).
-- About half what a real card room takes (5–6 BB/h). Launch gentle, raise Target in 0.5 steps if money piles up.
---------------------------------------------------------------------
Config.Rake = {
    Target = { pvp = 3.0, pvd = 2.5 },
    FreeTiers = { micro = true },          -- practice tables never pay rake
    -- starting rates until a tier/kind/game has MinSamples hands (assumptions in DESIGN.md §6.3)
    Seed = {
        pvp = { low = 0.044, mid = 0.033, high = 0.027 },
        pvd = { low = 0.016, mid = 0.011, high = 0.0075 },   -- tuned for blackjack (edge ~0.5%)
    },
    MinRate = { pvp = 0.01, pvd = 0.0025 }, -- the PVD floor keeps cashboxes and the sink fed
    MaxRate = { pvp = 0.07, pvd = 0.03 },
    MaxDailyStep = 0.0025,                 -- a rate moves at most 0.25 percentage points per tuning run
    MinSamples = 200,                      -- hands in the window before a rate is tuned
    WindowDays = 7,                        -- stats window the tuner reads
    TuneEveryHours = 24,
    Pinned = {},                           -- fixed rates that skip the tuner, e.g. ['pvp:low:holdem'] = 0.04
    Pvp = { MaxPerHandBB = 3 },            -- safety cap on rake per hand, in big blinds
    -- business tables (phase 6): share of the rake that goes to the owner's cashbox; the rest is destroyed
    BusinessShare = { pvp = 0.5, pvd = 0.0 },
}
