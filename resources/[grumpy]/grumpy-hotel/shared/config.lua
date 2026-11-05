Config = {}

Config.Debug        = false
Config.AutoDatabase = true          -- create tables on start; set false and import install.sql to do it by hand

---------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------
Config.AdminPermission = 'admin'    -- rsg-core permission for /hotellist (create, edit, delete, evict)
Config.AdminCommand    = 'hotellist'
Config.MaxRooms        = 50         -- most rooms one hotel can have
Config.MaxDaysLimit    = 30         -- highest "max days" an admin can set
Config.MaxDailyRate    = 5          -- highest daily rate an admin can set ($). Doctrine: a night is $0.25-1.00

---------------------------------------------------------------------
-- Distances (metres)
---------------------------------------------------------------------
Config.DoorRadius      = 1.5        -- rsg-target zone at the door (outside) interaction point
Config.RoomRadius      = 1.5        -- rsg-target zone at the interior (inside) interaction point
Config.ServerDistance  = 4.0        -- server tolerance: player must be this close to the door / interior point
Config.RentalDistance  = 5.0        -- server tolerance: player must be this close to a rental point (bartender)
Config.RestoreDistance = 40.0       -- on login, a player this close to the interior point counts as "still in the room"

---------------------------------------------------------------------
-- Rentals
---------------------------------------------------------------------
Config.DaySeconds      = 86400      -- one rental day in real seconds
Config.SweepInterval   = 60         -- seconds between expiry checks
Config.WarnBefore      = 86400      -- warn the renter this many seconds before expiry (one day)
Config.Grace = {
    Hours        = 24,              -- room is locked but kept this long after expiry...
    LoginMinutes = 60,              -- ...or this long after the renter's first login after expiry, whichever comes first
}

---------------------------------------------------------------------
-- Room stash (rsg-inventory). One stash per room, shared by the renter and the key holder.
-- rsg-inventory clamps these to its own Config.Stash.MaxSlots / MaxWeight.
---------------------------------------------------------------------
Config.Stash = {
    slots     = 100,
    maxweight = 1000000,            -- grams
}

---------------------------------------------------------------------
-- Instancing. Room bucket = BucketBase + hotelId * BucketsPerHotel + room
-- Keep BucketsPerHotel above Config.MaxRooms. Pick a BucketBase no other script uses.
---------------------------------------------------------------------
Config.BucketBase      = 60000
Config.BucketsPerHotel = 100

-- rsg-voice uses plain Mumble proximity and does NOT respect routing buckets. Every room shares the same
-- interior coords, so without this, players in different rooms would hear each other.
-- Each room gets its own Mumble voice channel (VoiceChannelBase + bucket) while you are inside.
Config.Voice = {
    Enabled          = true,
    VoiceChannelBase = 0,           -- channel = VoiceChannelBase + bucket
}

---------------------------------------------------------------------
-- Knocking
---------------------------------------------------------------------
Config.Knock = {
    Timeout  = 20,                  -- seconds the occupant has to answer
    Cooldown = 15,                  -- seconds between knocks for the same visitor
}

---------------------------------------------------------------------
-- Animations (data/rdr3_discoveries/animations/ingameanims/ingameanims_list.lua)
---------------------------------------------------------------------
Config.Anims = {
    unlock = {
        dict     = 'script_mp@player@unlockdoor',
        male     = 'unlockdoorr_male',
        female   = 'unlockdoorr_female',
        duration = 2500,            -- ms played before the screen fades
    },
    knock = {
        dict     = 'amb_misc@world_human_door_knock@male_a@idle_a',
        clip     = 'idle_a',
        duration = 3000,
    },
}

---------------------------------------------------------------------
-- Blips (data/rdr3_discoveries/useful_info_from_rpfs/textures/blips/README.md)
---------------------------------------------------------------------
Config.Blip = {
    sprite = 'blip_hotel_bed',
    scale  = 0.2,
}

---------------------------------------------------------------------
-- Law warrants. A warrant is an item with room metadata; it only opens the room it was issued for,
-- only for the rental it was issued against, and only until it expires.
---------------------------------------------------------------------
Config.Warrant = {
    Enabled       = true,
    Item          = 'hotel_warrant', -- add this item to rsg-core/shared/items.lua (see README)
    JobTypes      = { leo = true },  -- job.type values that count as law
    MinGrade      = 2,               -- lowest job grade level allowed to issue a warrant
    RequireOnDuty = true,
    Minutes       = 60,              -- how long a warrant stays valid
    Cooldown      = 30,              -- seconds between warrants issued by the same officer
}
