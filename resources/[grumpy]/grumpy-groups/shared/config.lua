Config = {}

Config.Debug = false
Config.AutoDatabase = true -- create the management_funds table on start (set false and import install.sql to do it yourself)

---------------------------------------------------------------------
-- Gangs (replaces rsg-gangmenu). Gangs themselves are defined in rsg-core/shared/gangs.lua
---------------------------------------------------------------------
Config.Gang = {
    Command          = 'gangmenu',  -- boss menu anywhere (members + recruit only, like rsg-gangmenu)
    Keybind          = 'J',         -- prompt key at a gang location (RSGCore.Shared.Keybinds)
    InteractDistance = 5.0,         -- server-side max distance from a gang location for stash / bank
    HireDistance     = 10.0,        -- max distance between boss and recruit
    MaxTransaction   = 1000000,     -- max single deposit / withdraw
    StorageMaxWeight = 4000000,
    StorageMaxSlots  = 50,
    InviteTimeout    = 30,          -- seconds the recruit has to answer
    TargetRecruit    = true,        -- bosses get "Recruit to gang" when targeting a player
    Blip = { sprite = 'blip_honor_bad', scale = 0.2 },
}

-- id must match the gang name in rsg-core/shared/gangs.lua
Config.GangLocations = {
    {
        id         = 'gang1',
        name       = 'Gang Menu',
        blipname   = 'Gang Name',
        coords     = vector3(0, 0, 0),
        showblip   = false,
        blipforall = false, -- true = everyone sees the blip, false = only gang members
    },
}

---------------------------------------------------------------------
-- Posses (temporary, player-made groups)
---------------------------------------------------------------------
Config.Posse = {
    Command         = 'posse',  -- opens the posse panel
    MaxMembers      = 7,        -- including the leader
    MaxLifetime     = 7200,     -- seconds. Hard cap from creation; leadership changes never reset it
    WarningTime     = 300,      -- seconds before the end that members are warned
    InviteDistance  = 5.0,      -- server-side max distance between inviter and invitee
    InviteTimeout   = 30,       -- seconds the invitee has to answer
    InviteCooldown  = 5,        -- seconds between invites from the same player
    MembersCanInvite = false,   -- false = only the leader invites
    LeaderGrace     = 120,      -- seconds an offline leader keeps the lead before it passes on
    TickInterval    = 15,       -- seconds between expiry / leader checks
    Blips = {
        enabled  = true,
        interval = 3,           -- seconds between member position updates
        style    = 'BLIP_STYLE_FRIENDLY',            -- useful_info_from_rpfs/blip_styles
        modifier = 'BLIP_MODIFIER_POSSE_ALLY',       -- useful_info_from_rpfs/blip_modifiers
        leaderSprite = 'blip_ambient_posse_leader',  -- useful_info_from_rpfs/textures/blips_mp
    },
}

---------------------------------------------------------------------
-- GetMembers() defaults (used by grumpy-rumors and other scripts)
---------------------------------------------------------------------
Config.Members = {
    Radius     = { gang = 100.0, job = 100.0 }, -- metres from the caller; false = no distance check. Posses never check distance
    JobOnDuty  = true,                          -- job members must be on duty
    IgnoreJobs = { unemployed = true },         -- these jobs never count as a group
}
