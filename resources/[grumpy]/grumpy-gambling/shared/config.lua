Config = {}

Config.Debug = false
Config.AutoDatabase = true                 -- create tables from install.sql on start

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
