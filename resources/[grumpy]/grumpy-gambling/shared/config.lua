Config = {}

Config.Debug = false
Config.AutoDatabase = true                 -- create tables from install.sql on start
Config.DevGames = false                    -- dev servers only: the /gga (type a move) and /ggbot (NPC count) commands

---------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------
Config.AdminCommand = 'gambling'           -- /gambling opens the admin panel
Config.AdminPermission = 'admin'           -- rsg-core permission level
Config.PlaceDistance = 10.0                -- rsg-gizmo range when placing or moving a table
Config.DealerSideY = 0.45                -- binding a dealer table: a map chair further than this behind the table's
                                          -- centre (towards its straight edge) is the dealer's chair, not a player's
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
    RebuySeconds = 45,                     -- out of chips at a running table: buy back in within this, or stand up
    MissedHands = 5,                       -- stood up after this many hands in a row without a single move
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
                                           -- chipForward / chipHeight / cardHeight in shared/models.lua)
}

-- Seated animations (players and NPCs). The chair scenario alone leaves everyone frozen with their hands on the
-- table, so a looping upper-body poker idle plays over it (swapped now and then), and every move, win and tell plays
-- its own clip. Clips: data/rdr3_discoveries/animations/ingameanims/ingameanims_list.lua (mini_games@poker_mg@base, the
-- game's own poker players; Nt_Holdem uses the same set). Flags: 25 = loop + upper body + secondary (idles),
-- 24 = upper body + secondary, played once (moves). Set Enabled = false to keep the plain scenario.
Config.Anim = {
    Enabled = true,
    Dict = 'mini_games@poker_mg@base',
    Idles = { 'no_cards_idle_a', 'no_cards_idle_b', 'no_cards_idle_c', 'no_cards_idle_d', 'no_cards_idle_e',
              'no_cards_idle_subtle_a', 'no_cards_idle_subtle_b', 'no_cards_idle_subtle_c' },
    IdleFlag = 25,
    IdleSwapMs = { 8000, 20000 },          -- a different idle every so often, so a table never looks frozen
    StartDelayMs = 600,                    -- after sitting: let the chair scenario settle first (same as the dealer)
    Flag = 24,
    -- cue = { clips, ms, dict? }. Moves come from the game (GGLib.Cue); win/buyin from the core; the rest are NPC tells
    -- and reactions. Female = clips from the female set where the game has them.
    Cues = {
        check   = { clips = { 'check_a', 'check_b', 'check_c' }, ms = 1200 },
        call    = { clips = { 'bet_stack_a', 'bet_stack_b' }, ms = 2000 },
        bet     = { clips = { 'bet_stack_a', 'bet_stack_b', 'bet_stack_c', 'bet_stack_d' }, ms = 2000 },
        raise   = { clips = { 'bet_stack_b', 'bet_stack_c', 'bet_stack_d' }, ms = 2000 },
        allin   = { clips = { 'bet_all' }, ms = 3000 },
        fold    = { clips = { 'fold' }, ms = 1200 },
        blind   = { clips = { 'bet_blind_a' }, ms = 1200 },
        buyin   = { clips = { 'buy_in_a', 'buy_in_b', 'buy_in_c' }, ms = 4000 },
        win     = { dict = 'mini_games@poker_mg@take_pot@base@a', clips = { 'take' }, ms = 3000 },
        happy   = { clips = { 'express_win_subtle_a', 'express_win_subtle_b', 'express_win_subtle_c' }, ms = 3000 },
        sad     = { clips = { 'express_loss_subtle_a', 'express_loss_subtle_b', 'express_loss_subtle_c' }, ms = 3000 },
        cheer   = { clips = { 'express_win_a', 'express_win_b', 'express_win_c' }, ms = 3500 },
        despair = { clips = { 'express_loss_a', 'express_loss_b', 'express_loss_c' }, ms = 3500 },
        -- NPC tells: a long look at strong cards, fidgeting on a bluff, a cardsharp's peek
        strong  = { clips = { 'look_no_cards_long_1a', 'look_no_cards_long_2b', 'look_no_cards_long_3c' }, ms = 3500 },
        bluff   = { clips = { 'no_cards_idle_subtle_d', 'no_cards_idle_subtle_e', 'look_no_cards_quick_2a' }, ms = 3000 },
        sleight = { clips = { 'peek_cheat_idle' }, ms = 3000 },
    },
    Female = {
        dict = 'mini_games@poker_mg@fem_relaxed',
        Cues = {
            check = { 'check_a', 'check_b', 'check_c' }, call = { 'bet_stack_a', 'bet_stack_b' },
            bet = { 'bet_stack_a', 'bet_stack_b', 'bet_stack_c', 'bet_stack_d' }, raise = { 'bet_stack_b', 'bet_stack_c' },
            allin = { 'bet_all' }, fold = { 'fold' },
            happy = { 'express_win_subtle_a', 'express_win_subtle_b' }, sad = { 'express_loss_subtle_a', 'express_loss_subtle_b' },
            cheer = { 'express_win_a', 'express_win_b' }, despair = { 'express_loss_a', 'express_loss_b' },
        },
    },
}

-- Cards on the table (props a game module lays out with SetProps). Models are p_crd_<rank>_<suit>01x_<style>
-- (data/rdr3_discoveries/objects/object_list.lua: all 52 exist for val, bla, rho, camp, van, rrs, std_labastille,
-- new). A face-down card is the same model turned over.
Config.Cards = {
    Style = 'val',                         -- Valentine deck; e.g. 'std_labastille' for Saint Denis
    StyleByTable = {},                     -- [tableId] = style, to give one table its own deck
    Height = 0.805,                        -- metres above the floor: the table top (like Config.ChipStacks.Height)
    Max = 48,                              -- most props one table may show
}

-- The pot: a pile of chips on the table while a hand has bets in it (from the first bet until it settles). In front
-- of the dealer at dealer tables, in the middle at card tables. Model: data/rdr3_discoveries/objects/object_list.lua
-- (p_saloon_01.rpf). Offsets: x = forward, y = right from the dealer (or the table's centre), metres.
Config.Pot = {
    Enabled = true,
    Model = 'p_gen_pokerchipante01x',
    Dealer = { x = 0.55, y = 0.0 },       -- straight out in front of the dealer, beyond his own cards
    Table = { x = 0.0, y = 0.0 },
}

-- Whose turn: a marker over the seat that's acting (players and NPCs), drawn for the players seated at that table.
-- Types: data/rdr3_discoveries/graphics/markers/marker_types.lua (0xD6445746 = prop_mp_halo_point).
Config.TurnMarker = {
    Enabled = true,
    Type = 0xD6445746,
    Height = 1.25,                         -- metres above the seat cushion (over a seated head)
    Scale = 0.18,
    Color = { 210, 175, 90, 200 },         -- r, g, b, alpha (house gold)
    Bob = true,
}

-- How the table moves (all on each player's own screen): cards slide from the dealer (or the middle of a card table)
-- to where they land, turn over instead of popping, slide back when collected; the pot slides to whoever won it.
-- Seated NPCs and the dealer look at whoever is acting.
Config.Motion = {
    Enabled = true,
    SlideMs = 280,                         -- a card dealt
    FlipMs = 260,                          -- a card turned over
    CollectMs = 340,                       -- cards gathered back
    PotMs = 700,                           -- the pot pushed to the winner (or raked in by the dealer)
    LookAt = true,
}

-- Sounds for the player at the table (frontend sounds: data/rdr3_discoveries/audio/frontend_soundsets). The game's
-- poker set has no card or chip sounds, so these are your turn, your bet or fold, and winning.
Config.Sounds = {
    Enabled = true,
    Set = 'RDRO_Poker_Sounds',
    Turn = 'player_turn_countdown_start',
    Bet = 'menu_select_bet',
    Fold = 'menu_select_fold',
    Win = 'showdown_win',
}

-- Table UI (phase 4): the panel shown while seated
Config.TableUI = {
    AutoFocus = true,                      -- take the mouse when it's your turn (Esc gives it back, G takes it again)
    FeedLines = 8,                         -- lines of the table feed shown
}

---------------------------------------------------------------------
-- NPC players (DESIGN.md §8). Free NPCs: their chips are created when they sit and destroyed when they leave
-- (accepted doctrine deviation, doctrine/compliance.md), bounded by the per-player win cap (npcCapMultiplier).
---------------------------------------------------------------------
Config.Npc = {
    Enabled = true,
    MaxPerTable = 5,                       -- never more NPCs than this, whatever the seat count
    -- seats = min(table seats, game maxSeats); NPCs = seats - real players - 1 (one seat always stays free)
    TickMs = 3000,                         -- how often tables between hands are checked (one NPC joins per check)
    LeaveDelayMs = 2500,                   -- after a hand: time to see the result before NPCs leave or join
    CapWindowMinutes = 90,                 -- the shared rolling win-cap window (DESIGN.md §8.3; open item: 60 or 90)
    ThinkMs = { 1200, 3500 },              -- poker NPCs "think" this long before acting (drunks a bit longer)
    BigPotBB = 15,                         -- a hand result this big (in big blinds) gets a win/loss reaction

    -- Strangers' looks: a random model and outfit preset (every client shows the same outfit)
    Models = {                             -- data/rdr3_discoveries/peds/peds_list.lua
        'a_m_m_valtownfolk_01', 'a_m_m_valtownfolk_02', 'a_m_m_rhdtownfolk_01', 'a_m_m_strtownfolk_01',
        'a_m_m_valfarmer_01', 'a_m_m_vallaborer_01', 'a_m_m_rancher_01', 'a_m_m_blwupperclass_01',
        'a_f_m_valtownfolk_01', 'a_f_m_rhdtownfolk_01', 'a_f_m_blwtownfolk_01',
    },
    Names = {
        'Silas', 'Walter', 'Ezra', 'Amos', 'Jedediah', 'Horace', 'Virgil', 'Cyrus', 'Elias', 'Otis', 'Thaddeus',
        'Martha', 'Josephine', 'Clara', 'Hattie', 'Lottie', 'Adeline',
    },
    FemaleNames = { 'Martha', 'Josephine', 'Clara', 'Hattie', 'Lottie', 'Adeline' }, -- used with a_f_* models
    BloodmoneyModels = { 'a_m_m_valcriminals_01', 'a_m_m_strtownfolk_01', 'a_m_m_vallaborer_01' }, -- back rooms

    -- Personalities. Poker: play = strength needed to enter a pot (0–1), call = extra margin over the pot odds,
    -- raise = strength to bet/raise, aggression = chance to bet/raise when strong enough, bluff = chance to bluff,
    -- slowplay = chance to just check a monster, size = bet size as a share of the pot, open = preflop raise in big
    -- blinds, noise = random error, tells = how often tells show (×), tiltProne = chance a big loss tilts them.
    -- Session: cutLoss = leaves after losing this share of the buy-in, takeProfit = may leave after winning this
    -- multiple of it, hands = stays this many hands. PVD: bet = { min, max } × the minimum bet.
    Personas = {
        teacher    = { play = 0.55, call = 0.05, raise = 0.72, aggression = 0.35, bluff = 0.02, slowplay = 0.05, size = 0.5,
                       open = 2.5, noise = 0.08, tells = 1.5, tiltProne = 0.0, cutLoss = 0.8, takeProfit = 2.0, hands = { 25, 70 },
                       bet = { 1, 2 } },
        tight      = { play = 0.60, call = 0.08, raise = 0.75, aggression = 0.45, bluff = 0.03, slowplay = 0.15, size = 0.6,
                       open = 3.0, noise = 0.06, tells = 1.0, tiltProne = 0.2, cutLoss = 0.5, takeProfit = 1.0, hands = { 15, 45 },
                       bet = { 1, 2 } },
        balanced   = { play = 0.50, call = 0.03, raise = 0.68, aggression = 0.50, bluff = 0.06, slowplay = 0.10, size = 0.7,
                       open = 3.0, noise = 0.06, tells = 1.0, tiltProne = 0.3, cutLoss = 0.7, takeProfit = 1.2, hands = { 15, 45 },
                       bet = { 1, 3 } },
        loose      = { play = 0.38, call = -0.03, raise = 0.70, aggression = 0.35, bluff = 0.08, slowplay = 0.05, size = 0.6,
                       open = 2.5, noise = 0.08, tells = 1.2, tiltProne = 0.4, cutLoss = 0.9, takeProfit = 1.5, hands = { 10, 40 },
                       bet = { 1, 4 } },
        aggressive = { play = 0.43, call = 0.00, raise = 0.60, aggression = 0.70, bluff = 0.12, slowplay = 0.05, size = 0.85,
                       open = 3.5, noise = 0.07, tells = 1.0, tiltProne = 0.5, cutLoss = 1.0, takeProfit = 1.5, hands = { 10, 35 },
                       bet = { 2, 6 } },
        shark      = { play = 0.50, call = 0.02, raise = 0.62, aggression = 0.65, bluff = 0.09, slowplay = 0.20, size = 0.8,
                       open = 3.0, noise = 0.03, tells = 0.4, tiltProne = 0.1, cutLoss = 0.8, takeProfit = 2.0, hands = { 20, 60 },
                       bet = { 2, 8 } },
    },
    -- Who sits where (weights), and how each tier shifts them (DESIGN.md §8.4): bolder as stakes rise
    Mix = {
        micro = { teacher = 6, tight = 2, balanced = 2 },
        low   = { tight = 3, balanced = 3, loose = 2, aggressive = 2 },
        mid   = { tight = 1, balanced = 3, loose = 3, aggressive = 3 },
        high  = { balanced = 2, loose = 3, aggressive = 4, shark = 2 },
    },
    TierMods = {                           -- added to the persona (tells is a multiplier)
        micro = { tells = 2.0 },
        low   = {},
        mid   = { play = -0.03, call = -0.02, size = 0.1 },
        high  = { play = -0.05, call = -0.04, size = 0.2, aggression = 0.05, tells = 0.5 },
    },

    Tells = {
        Chance = { strong = 0.6, bluff = 0.6 },   -- × the persona's tells: how often a tell shows when it applies
        Strong = 0.70,                     -- hand strength (0–1) that counts as "strong" for a tell
    },
    Chatter = {
        GapSeconds = 6,                    -- at most one NPC line per table this often (greetings and exits skip it)
        Chance = { join = 0.6, leave = 0.8, win_big = 0.6, lose_big = 0.6, raise = 0.12, allin = 0.5, fold = 0.06,
                   call = 0.05, check = 0.03, drunk = 0.15 },
        -- number of locale lines per event: npc_<event>_<n>
        Lines = { join = 5, greet_friend = 3, greet_grudge = 3, greet_known = 2, win_big = 5, lose_big = 5, raise = 4,
                  allin = 3, fold = 4, call = 3, check = 2, drunk = 5, leave_bust = 3, leave_profit = 3, leave_loss = 3,
                  leave_night = 3, leave_room = 2, leave_storm = 3, leave_bored = 3, caught = 2, offended = 3 },
    },

    Drunk = {
        Hours = { 21, 3 },                 -- in-game hours (rsg-weather) when saloon NPCs are often drunk
        Chance = 0.35, DayChance = 0.05,
        Mods = { play = -0.10, call = -0.05, bluff = 0.05, noise = 0.08, tells = 2.0 },
    },
    Tilt = {
        LossBB = 20,                       -- losing this many big blinds in one hand may tilt (× tiltProne)
        Hands = 4,                         -- tilt lasts this many hands
        StormOff = 0.25,                   -- chance a tilted NPC leaves at the end of the hand (× tiltProne)
        Mods = { aggression = 0.25, bluff = 0.08, call = -0.05, play = -0.08, noise = 0.05 },
    },
    -- Back-room (bloodmoney) tables only: some NPCs cheat. The game module decides how (DESIGN.md §8.7).
    Sharp = {
        Chance = 0.15,                     -- an NPC at a bloodmoney table is a cardsharp
        CheatChance = 0.25,                -- chance per hand they try something
        TellChance = 0.6,                  -- chance their sleight shows (a peek animation)
        CallOutCooldownSeconds = 600,      -- after a wrong call-out
    },

    -- Recurring named NPCs with a fixed look and personality (DESIGN.md §8.6). They remember each player (hands
    -- together, money won from them) and greet them. home = { x, y, z, radius }: they prefer tables there; roams = may
    -- sit anywhere else too. tiers = where they play (nil = any).
    Regulars = {
        Chance = 0.35,                     -- chance a joining NPC is a free regular who fits the table
        KnownHands = 10,                   -- hands together before a regular greets you by name
        List = {
            { id = 'old_jeb', name = 'Old Jeb', model = 'a_m_m_valfarmer_01', outfit = 3, persona = 'tight', skill = 0.6,
              home = { x = -308.29, y = 810.2, z = 117.98, radius = 120.0 }, roams = false, -- Valentine saloon (rsg-fortuneteller config)
              tiers = { micro = true, low = true } },
            { id = 'miss_lottie', name = 'Miss Lottie', model = 'a_f_m_rhdtownfolk_01', outfit = 1, persona = 'balanced', skill = 0.7,
              home = { x = 1355.99, y = -1298.06, z = 76.78, radius = 150.0 }, roams = true }, -- Rhodes (rsg-bountyhunter office)
            { id = 'deacon_ward', name = 'Deacon Ward', model = 'a_m_m_blwupperclass_01', outfit = 2, persona = 'shark', skill = 0.85,
              home = { x = 2510.08, y = -1318.03, z = 48.53, radius = 250.0 }, roams = true, -- Saint Denis (rsg-bountyhunter office)
              tiers = { mid = true, high = true } },
            { id = 'whistling_pete', name = 'Whistling Pete', model = 'a_m_m_vallaborer_01', outfit = 4, persona = 'loose', skill = 0.3,
              roams = true, tiers = { low = true, mid = true } },
            { id = 'colonel_bragg', name = 'Colonel Bragg', model = 'a_m_m_rhdupperclass_01', outfit = 0, persona = 'aggressive', skill = 0.55,
              roams = true, tiers = { mid = true, high = true } },
        },
    },
}

Config.Dealer = {
    Model = 'u_m_m_bht_saintdenissaloon',  -- data/rdr3_discoveries/peds/peds_list.lua
    Seated = true,                         -- sit the dealer in a chair behind the table (like Nt_Blackjack)
    Chair = 'p_windsorchair03x',           -- the dealer's chair (data/rdr3_discoveries/objects/object_list.lua)
    ChairYaw = 180.0,                      -- p_windsorchair03x's model faces backwards (seen in game 2026-11-05)
    IdleDict = 'mini_games@blackjack_mg@dealer@self@idle', -- data/rdr3_discoveries/animations/ingameanims/ingameanims_list.lua
    IdleClip = 'idle',
    ActionFlag = 24,                       -- dealer moves from game modules (DealerAnim): upper body, played once
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

---------------------------------------------------------------------
-- Business tables (DESIGN.md §9): POB owners place tables in their business with two items. Each table has a
-- cashbox (the placer's, same money as the table) that collects the business share of the rake (Rake.BusinessShare)
-- and, at dealer tables, is the house: it pays players' wins and keeps their losses.
---------------------------------------------------------------------
Config.Business = {
    Enabled = true,
    Items = { pvp = 'gambling_table_pvp', pvd = 'gambling_table_pvd' }, -- add to rsg-core/shared/items.lua (README)
    Models = { pvp = 'p_tablepoker01x', pvd = 'p_blackjacktable01x' },  -- placed models (spawnable profiles)
    MaxDistanceFromNpc = 25.0,             -- metres from the business's NPC (grumpy-pob points.npc)
    MaxTables = { pvp = 2, pvd = 2 },      -- per business
    BackroomForBloodmoney = true,          -- bloodmoney tables need the business's back room (grumpy-pob laundering)
    PvdCoverMaxBets = 20,                  -- a dealer table offers a tier only if its box holds this many max bets
    AbandonDays = 7,                       -- a table whose owner lost the business is packed up after this (box and
                                           -- item owed to the owner at their next login)
    ManageDistance = 3.0,                  -- the owner must be this close to manage the table
    PobResource = 'grumpy-pob',
}
