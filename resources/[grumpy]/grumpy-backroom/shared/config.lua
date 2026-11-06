Config = {}

Config.Debug = false

---------------------------------------------
-- Admin
---------------------------------------------
Config.AdminCommand    = 'backroom' -- /backroom opens the room list + editor
Config.AdminPermission = 'admin'    -- RSG permission (god, developer, headadmin, admin, mod)
Config.TestSeconds     = 60         -- "Open for a test" in the editor opens the room free for this long

---------------------------------------------
-- The bribe
-- Doctrine: Outlaw/Hybrid, Survival → Stability. Scaled from the "Fence bribe for a rumor" band ($1.00,
-- ×0.75–1.5 by standing, doctrine/pricing.md): an hour in the back room costs about one fence bribe.
-- One payment opens the door for everybody; paying while it's open adds time (up to MaxOpenMinutes).
-- The money is destroyed (server sink), it never goes to a business account.
---------------------------------------------
Config.Bribes = {
    { minutes = 30,  price = 0.50 },
    { minutes = 60,  price = 1.00 },
    { minutes = 120, price = 1.75 },
}
Config.MaxOpenMinutes = 180                       -- time left can't go above this
Config.PayWith        = { 'bloodmoney', 'cash' }  -- tried in order; the whole bribe comes from one type
Config.StandingScales = true                      -- × grumpy-reputation 'underground' buy price (known outlaws pay less)
Config.BlockLaw       = true                      -- on-duty lawmen (job type 'leo') can't bribe the doorman
Config.MoneyReason    = 'grumpy-backroom-bribe'

---------------------------------------------
-- Closing time
---------------------------------------------
Config.WarnAt        = { 300, 60, 15 } -- seconds left when everyone inside is warned
Config.LockDelay     = 1500            -- ms after the room is cleared before the doors lock
Config.SweepAfter    = { 4000, 10000 } -- ms after closing: anyone still inside is moved out by the server
Config.StandFromTables = true          -- stand players up from grumpy-gambling tables first (their chips are cashed out)
Config.Exempt = {
    admins = false,  -- true = admins are never shown out (handy while building, off for testing)
    jobs   = {},     -- e.g. { 'saloon_owner' }: these jobs may stay after closing
}

---------------------------------------------
-- The doorman
---------------------------------------------
Config.Npc = {
    model         = 'u_m_m_gamdoorman_01',    -- data/rdr3_discoveries/peds/peds_list.lua (0x51B75106)
    scenario      = 'WORLD_HUMAN_STAND_WAITING', -- data/rdr3_discoveries/animations/scenarios/scenario_types_with_conditional_anims.lua; nil = none
    spawnDistance = 40.0,
    fadeIn        = true,
}
Config.InteractDistance  = 2.5 -- rsg-target range
Config.DistanceTolerance = 3.0 -- extra server-side leeway (latency)

---------------------------------------------
-- Setup limits
---------------------------------------------
Config.Zone = {
    FloorOffset   = 1.2,  -- a standing ped's coords are ~1 m above the floor: the zone floor is the lowest corner minus this
    DefaultHeight = 4.0,  -- metres from the floor to the ceiling of the zone
    MinHeight     = 2,
    MaxHeight     = 15,
    MaxCorners    = 24,
}
Config.MaxDoors      = 8     -- rsg-doorlock locks per room
Config.DoorPickRange = 30.0  -- the door picker lists rsg-doorlock locks within this many metres
Config.PlaceDistance = 20.0  -- rsg-gizmo range when placing the doorman
