Config = {}

-- Doctrine: no prices, payouts or items. Comfort feature only (path: all, no tier).

Config.Debug = false              -- draws a marker on every seat spot of a targeted prop and prints model/offset info

-- The base game's own "E to sit" prompt is prompt type 8 ("sit").
-- Source: data/rdr3_discoveries/graphics/HUD/prompts/prompt_types/README.md
-- Hidden every frame with _UI_PROMPT_DISABLE_PROMPT_TYPE_THIS_FRAME (natives/db/HUD.md).
Config.DisableNativeSitPrompt = true
Config.NativeSitPromptType    = 8

Config.TargetDistance = 2.0       -- how close the player must be to the prop to see the target option
Config.TargetIcon     = 'fa-solid fa-chair'
Config.SeatTakenRadius = 0.45     -- any ped this close to a seat spot means the spot is taken

-- Key to stand up. INPUT_CONTEXT_X = R on keyboard, X on pad.
-- Source: data/rdr3_discoveries/Controls/README.md (0xE3BF959B)
Config.StandControl = 0xE3BF959B

-- Chairs other resources own. grumpy-sit asks each started resource's export (entity -> bool) and
-- hides Sit down when one says yes. grumpy-gambling claims the chairs at its card tables.
Config.ClaimedBy = {
    { resource = 'grumpy-gambling', export = 'IsTableChair' },
}
Config.ClaimCacheMs = 3000        -- how long one answer per chair is reused

-- Seat types. Each spot is an offset from the prop's origin in the prop's own space
-- (x = right, y = forward, z = up). heading is added to the prop's heading.
-- Scenarios from data/rdr3_discoveries/animations/scenarios (PROP_HUMAN_SEAT_*).
-- The offsets are starting values: tune them in game with Config.Debug = true.
Config.SeatTypes = {
    chair = {
        scenario = 'PROP_HUMAN_SEAT_CHAIR',
        spots    = { vector3(0.0, 0.0, 0.5) },
        heading  = 180.0,
    },
    armchair = {
        scenario = 'PROP_HUMAN_SEAT_CHAIR',
        spots    = { vector3(0.0, 0.05, 0.45) },
        heading  = 180.0,
    },
    stool = {
        scenario = 'PROP_HUMAN_SEAT_CHAIR',
        spots    = { vector3(0.0, 0.0, 0.55) },
        heading  = 180.0,
    },
    barstool = {
        scenario = 'PROP_HUMAN_SEAT_CHAIR',
        spots    = { vector3(0.0, 0.0, 0.8) },
        heading  = 180.0,
    },
    bench = {
        scenario = 'PROP_HUMAN_SEAT_BENCH',
        spots    = { vector3(-0.55, 0.0, 0.5), vector3(0.0, 0.0, 0.5), vector3(0.55, 0.0, 0.5) },
        heading  = 180.0,
    },
    shortbench = {
        scenario = 'PROP_HUMAN_SEAT_BENCH',
        spots    = { vector3(-0.3, 0.0, 0.5), vector3(0.3, 0.0, 0.5) },
        heading  = 180.0,
    },
}

-- Seatable props. Model names from data/rdr3_discoveries/objects/object_list.lua.
-- Value is a seat type name, or a table { type = 'chair', spots = {...}, heading = 0.0 } to override one model.
-- Left out on purpose: barber chairs (rsg-barbers), theatre chairs (rsg-theatre), poker chairs (gambling tables),
-- damaged/broken props, prop sets, workbenches, wheelchair, toilet chair, electric chair, birthing chair.
Config.Models = {
    -- chairs
    p_ambchair01x = 'chair', p_ambchair02x = 'chair',
    p_bistrochair01x = 'chair',
    p_chair02x = 'chair', p_chair04x = 'chair', p_chair05x = 'chair', p_chair05x_sea = 'chair',
    p_chair06x = 'chair', p_chair07x = 'chair', p_chair09x = 'chair', p_chair_10x = 'chair',
    p_chair11x = 'chair', p_chair12x = 'chair', p_chair12bx = 'chair', p_chair13x = 'chair',
    p_chair14x = 'chair', p_chair15x = 'chair', p_chair16x = 'chair', p_chair17x = 'chair',
    p_chair18x = 'chair', p_chair19x = 'chair', p_chair20x = 'chair', p_chair21x = 'chair',
    p_chair21x_fussar = 'chair', p_chair22x = 'chair', p_chair23x = 'chair', p_chair24x = 'chair',
    p_chair25x = 'chair', p_chair26x = 'chair', p_chair27x = 'chair', p_chair30x = 'chair',
    p_chair31x = 'chair', p_chair34x = 'chair', p_chair37x = 'chair', p_chair38x = 'chair',
    p_chair_barrel04b = 'chair', p_chair_crate02x = 'chair', p_chair_crate15x = 'chair', p_chair_cs05x = 'chair',
    p_chair_privatedining01x = 'chair',
    p_chairdesk01x = 'chair', p_chairdesk02x = 'chair',
    p_chairdining01x = 'chair', p_chairdining02x = 'chair', p_chairdining03x = 'chair',
    p_chairdoctor01x = 'chair', p_chairdoctor02x = 'chair', p_chaireagle01x = 'chair',
    p_chairfolding02x = 'chair', p_chairhob01x = 'chair', p_chairhob02x = 'chair',
    p_chairironnbx01x = 'chair', p_chairmed01x = 'chair', p_chairmed02x = 'chair', p_chairnbx02x = 'chair',
    p_chairoffice02x = 'chair', p_chairporch01x = 'chair',
    p_chairrustic01x = 'chair', p_chairrustic02x = 'chair', p_chairrustic03x = 'chair',
    p_chairrustic04x = 'chair', p_chairrustic05x = 'chair', p_chairrusticsav01x = 'chair',
    p_chairsalon01x = 'chair', p_chairtall01x = 'chair', p_chairvictorian01x = 'chair', p_chairwhite01x = 'chair',
    p_chairwicker01x = 'chair', p_chairwicker01b_static = 'chair', p_chairwicker02x = 'chair', p_chairwicker03x = 'chair',
    p_sit_chairwicker01a = 'chair', p_sit_chairwicker01b = 'chair', p_sit_chairwicker01c = 'chair',
    p_sit_chairwicker01d = 'chair', p_sit_chairwicker01e = 'chair',
    p_chairdeck01x = 'chair',
    p_gen_chair06x = 'chair', p_gen_chair07x = 'chair', p_gen_chair08x = 'chair', p_group_chair05x = 'chair',
    p_pianochair01x = 'chair', p_privatelounge_chair01x = 'chair',
    p_windsorchair01x = 'chair', p_windsorchair02x = 'chair', p_windsorchair03x = 'chair',
    p_woodenchair01x = 'chair', p_woodendeskchair01x = 'chair',
    p_chairrocking02x = 'chair', p_chairrocking03x = 'chair', p_chairrocking04x = 'chair',
    p_chairrocking05x = 'chair', p_chairrocking06x = 'chair',
    p_rockingchair01x = 'chair', p_rockingchair02x = 'chair', p_rockingchair03x = 'chair',

    -- armchairs / comfy chairs
    p_armchair01x = 'armchair', p_oldarmchair01x = 'armchair', p_chairComfy01x = 'armchair',
    p_chaircomfy02 = 'armchair', p_chaircomfy03x = 'armchair', p_chaircomfy04x = 'armchair',
    p_chaircomfy05x = 'armchair', p_chaircomfy06x = 'armchair', p_chaircomfy07x = 'armchair',
    p_chaircomfy08x = 'armchair', p_chaircomfy09x = 'armchair', p_chaircomfy10x = 'armchair',
    p_chaircomfy11x = 'armchair', p_chaircomfy12x = 'armchair', p_chaircomfy14x = 'armchair',
    p_chaircomfy16x = 'armchair', p_chaircomfy17x = 'armchair', p_chaircomfy18x = 'armchair',
    p_chaircomfy22x = 'armchair', p_chaircomfy23x = 'armchair', p_chairconvoround01x = 'armchair',

    -- stools
    p_stool01x = 'stool', p_stool02x = 'stool', p_stool03x = 'stool', p_stool04x = 'stool',
    p_stool05x = 'stool', p_stool06x = 'stool', p_stool07x = 'stool', p_stool08x = 'stool',
    p_stool09x = 'stool', p_stool10x = 'stool', p_stool11x = 'stool', p_stool12x = 'stool',
    p_stool13x = 'stool', p_stool013x = 'stool', p_stool14x = 'stool', p_stool15x = 'stool', p_stool16x = 'stool',
    p_stoolcomfy01x = 'stool', p_stoolcomfy02x = 'stool', p_stoolfolding01x = 'stool', p_stoolfolding01bx = 'stool',
    p_stoolwinter01x = 'stool', p_gen_stool01x = 'stool', p_gen_stool03x = 'stool',
    p_grp_w_tra_stool01x = 'stool', p_rockstool02x = 'stool', p_boxlrgstool01x = 'stool',
    p_dressinglbstool01x = 'stool',
    p_barstool01x = 'barstool',

    -- benches
    p_bench03x = 'bench', p_bench06x = 'bench', p_bench08bx = 'bench', p_bench09x = 'bench',
    p_bench11x = 'bench', p_bench15x = 'bench', p_bench15_mjr = 'bench', p_bench16x = 'bench',
    p_bench17x = 'bench', p_bench18x = 'bench', p_bench20x = 'bench',
    p_bench_log01x = 'bench', p_bench_log02x = 'bench', p_bench_log03x = 'bench', p_bench_log04x = 'bench',
    p_bench_log05x = 'bench', p_bench_log06x = 'bench', p_bench_log07x = 'bench', p_bench_logsnow07x = 'bench',
    p_benchannsaloon01x = 'bench', p_benchbear01x = 'bench', p_benchch01x = 'bench',
    p_benchironnbx01x = 'bench', p_benchironnbx02x = 'bench', p_benchlong05x = 'bench',
    p_benchnbx01x = 'bench', p_benchnbx02x = 'bench', p_benchnbx03x = 'bench',
    p_hallbench01x = 'bench', p_new_rich_bench2x = 'bench', p_new_stonebench02x = 'bench',
    p_seatbench01x = 'bench', p_windsorbench01x = 'bench', p_woodbench02x = 'bench',
    p_benchpiano02x = 'shortbench', p_gen_benchpiano01x_tc01 = 'shortbench',
}
