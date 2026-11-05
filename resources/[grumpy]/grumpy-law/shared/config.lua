Config = {}

Config.Debug = false

---------------------------------------------------------------------
-- Witnesses
-- The server counts networked NPCs (OneSync population) and the criminal's game confirms
-- line of sight. If the server can't see ambient NPCs at all, the client's count is used instead.
---------------------------------------------------------------------
Config.Witness = {
    Radius        = 25.0,   -- NPCs within this range of the criminal can witness
    CloseRadius   = 8.0,    -- server counts these as witnesses even without a line-of-sight check
    ScanInterval  = 2,      -- seconds between server scans during an incident's hot window
    ClientInterval = 3,     -- seconds between the criminal's line-of-sight scans
    ClientMaxPeds = 10,     -- line-of-sight checks per client scan (nearest first)
    ClientFallbackMax = 3,  -- most witnesses taken from the client's count when the server sees no NPCs
    ReportChance  = 60,     -- % chance each witness goes to the law
    ReportDelay   = { 20, 60 },  -- seconds before a witness's report arrives
    DeadNoReport  = true,   -- a witness who is dead (or gone) when their report is due doesn't report
}

---------------------------------------------------------------------
-- Crimes. Scripts open incidents with one of these names.
--   hot          seconds witnesses can see it happen (scripts may override)
--   victimDelay  seconds before the victim's report (e.g. a robbed clerk), when the script says the victim reports
--   escapeAction grumpy-reputation action given when a SUCCEEDED, reported crime is followed by a clean escape
---------------------------------------------------------------------
Config.Crimes = {
    store_robbery = { hot = 45, victimDelay = { 5, 10 },  escapeAction = 'escaped' },
    shoplifting   = { hot = 10, victimDelay = { 10, 20 }, escapeAction = 'escaped', escapeMult = 0.5 },
    generic       = { hot = 30, victimDelay = { 15, 30 }, escapeAction = 'escaped' },
}

---------------------------------------------------------------------
-- Reports go to on-duty player law (job.type == 'leo') through rsg-lawman's alert.
-- When nobody is on duty, the 'grumpy-law:server:crimeReported' event is where NPC police will plug in.
---------------------------------------------------------------------
Config.Report = {
    NotifyCriminal = true,     -- "Word of your crime has reached the law"
    UseLawmanAlert = true,     -- rsg-lawman blip/notify for on-duty law (plain notify if rsg-lawman isn't running)
}

---------------------------------------------------------------------
-- Heat: after a report, the criminal is tracked. Jailed -> no bonus (rsg-prison / jailed hook handles it).
-- Died -> nothing. Logged off -> forfeits. Free and alive for Duration seconds -> escape bonus, only if
-- the crime succeeded.
---------------------------------------------------------------------
Config.Heat = {
    Duration       = 600,
    CheckInterval  = 5,
    NotifyEscaped  = true,
}

Config.AdminPermission = 'admin'
Config.TestCommand     = 'witnesstest'   -- shows how many NPCs the server and your game can see around you
