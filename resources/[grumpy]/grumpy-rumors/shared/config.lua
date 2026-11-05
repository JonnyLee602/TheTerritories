Config = {}

Config.Debug = false

---------------------------------------------------------------------
-- The note item. Registered with rsg-core at start if your items.lua doesn't have it.
---------------------------------------------------------------------
Config.Item = {
    name        = 'rumor_note',
    label       = 'Rumor',
    weight      = 10,
    image       = 'rumor_note.png', -- put this in rsg-inventory/html/images/
    description = 'Something you overheard. Better act before it goes stale.',
}

Config.MaxNotes      = 3     -- notes one player may carry at once
Config.SweepInterval = 300   -- seconds between removing expired notes from online players' pockets

---------------------------------------------------------------------
-- Informants: NPCs players ask for rumors (rsg-target on the ped)
-- Models: data/rdr3_discoveries/peds/peds_list.lua. Scenarios: data/rdr3_discoveries/animations
---------------------------------------------------------------------
Config.SpawnDistance   = 60.0  -- peds spawn locally when a player is this close
Config.AskDistance     = 3.0   -- server-checked distance to ask
Config.NothingCooldown = 120   -- seconds before asking again after "nothing for you"

Config.Informants = {
    {
        id         = 'valentine_drifter',
        enabled    = false,                                -- set coords, then enable
        model      = 'a_m_m_valcriminals_01',
        coords     = vector4(0.0, 0.0, 0.0, 0.0),
        scenario   = 'WORLD_HUMAN_SMOKE',
        categories = { 'illegal' },                        -- which rumor categories this informant knows
        price      = 0.50,                                 -- cash per tip (0 = free); only charged when a note is handed over
        cooldown   = 1800,                                 -- seconds before the same player can ask this informant again
    },
    {
        id         = 'valentine_clerk',
        enabled    = false,
        model      = 's_m_m_valdeputy_01',
        coords     = vector4(0.0, 0.0, 0.0, 0.0),
        scenario   = 'WORLD_HUMAN_CLIPBOARD',
        categories = { 'legal' },
        price      = 0,
        cooldown   = 1800,
    },
}

---------------------------------------------------------------------
-- Rumors
--   category  'legal' | 'illegal' | any word your informants list
--   tiers     grumpy-reputation tiers allowed to RECEIVE and ACT on it
--   weight    relative chance when several rumors qualify
--   lifetime  seconds the note stays good
--   cooldown  seconds after someone acts on it before any informant hands it out again (0 = none)
--   title / text  locale keys
--   job       optional. type = a job type another resource registered; args = passed to it as-is
--             group = 'auto' | 'posse' | 'gang' | 'job' | 'solo'; radius = metres for gang/job members (posses ignore it)
---------------------------------------------------------------------
Config.Rumors = {
    {
        id = 'stage_line_gossip', category = 'illegal', tiers = { 'outlaw', 'notorious', 'neutral' },
        weight = 10, lifetime = 3600, cooldown = 0,
        title = 'rumor_stage_title', text = 'rumor_stage_text',
        -- no job: flavour only
    },
    {
        id = 'old_camp_stash', category = 'illegal', tiers = { 'outlaw', 'notorious' },
        weight = 5, lifetime = 7200, cooldown = 3600,
        title = 'rumor_stash_title', text = 'rumor_stash_text',
        job = { type = 'mark', group = 'auto', radius = 75.0,
                args = { coords = vector3(0.0, 0.0, 0.0), radius = 120.0, duration = 1800, label = 'rumor_stash_blip' } },
    },
    {
        -- dig site: the note becomes a treasure map; rsg-treasure runs the hunt (solo, its own random spot)
        id = 'buried_strongbox', category = 'illegal', tiers = { 'neutral', 'outlaw', 'notorious' },
        weight = 6, lifetime = 5400, cooldown = 1800,
        title = 'rumor_dig_title', text = 'rumor_dig_text',
        job = { type = 'item', group = 'solo', args = { item = 'treasure_map', amount = 1, message = 'rumor_dig_received' } },
    },
    {
        id = 'lost_survey_crew', category = 'legal', tiers = { 'respected', 'upstanding', 'neutral' },
        weight = 5, lifetime = 7200, cooldown = 3600,
        title = 'rumor_survey_title', text = 'rumor_survey_text',
        job = { type = 'mark', group = 'auto', radius = 75.0,
                args = { coords = vector3(0.0, 0.0, 0.0), radius = 150.0, duration = 1800, label = 'rumor_survey_blip' } },
    },
}

---------------------------------------------------------------------
-- Built-in 'item' job type: acting on the note gives the READER an item that another resource runs
-- (e.g. treasure_map -> rsg-treasure dig site). Only whitelisted items can be given.
---------------------------------------------------------------------
Config.BuiltinItem = {
    enabled = true,
    allowed = { treasure_map = true },                   -- add e.g. legendary_map = true (needs info.animal, see DOCS)
    needsResource = { treasure_map = 'rsg-treasure' },   -- informants skip the rumor while this resource is stopped
}

---------------------------------------------------------------------
-- Built-in 'mark' job type: only puts a search-area blip on the map for the group.
-- Handy for testing and for flavour tips. Real jobs belong in their own resources.
---------------------------------------------------------------------
Config.BuiltinMark = {
    enabled  = true,
    style    = 'BLIP_STYLE_AREA',   -- useful_info_from_rpfs/blip_styles
}
