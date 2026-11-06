-- Core state shared by every server file (GH = grumpy-hotel). Loads hotels, rentals and occupants.
local RSGCore = exports['rsg-core']:GetCoreObject()

GH = {
    Hotels    = {},     -- [hotelId] = { id, label, rooms, price, maxDays, door = vector4, interior = vector4, blip }
    Rentals   = {},     -- [hotelId] = { [room] = rental }   (see DOCS.md -> Data formats)
    Inside    = {},     -- [src] = { hotel, room, role, cid }   role = 'renter' | 'key' | 'visitor' | 'law'
    Occupants = {},     -- [citizenid] = { hotel, room, role }  persisted copy of Inside for logout / crash restore
    Ready     = false,
}

local busy, cooldowns = {}, {}

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
function GH.Notify(src, msg, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = msg, type = ntype or 'inform', duration = 6000 })
end

function GH.Debug(...) if Config.Debug then print('[grumpy-hotel]', ...) end end

function GH.IsAdmin(src) return RSGCore.Functions.HasPermission(src, Config.AdminPermission) end

function GH.Finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end

-- "J. Smith" from a charinfo table or JSON string
function GH.ShortName(charinfo)
    if type(charinfo) == 'string' then charinfo = json.decode(charinfo) end
    if type(charinfo) ~= 'table' then return '?' end
    local first = tostring(charinfo.firstname or ''):gsub('^%s+', '')
    local last = tostring(charinfo.lastname or ''):gsub('%s+$', '')
    local initial = first:sub(1, 1):upper()
    if initial == '' then return last ~= '' and last or '?' end
    return ('%s. %s'):format(initial, last)
end

function GH.PlayerName(Player) return GH.ShortName(Player.PlayerData.charinfo) end

function GH.Bucket(hotelId, room) return Config.BucketBase + hotelId * Config.BucketsPerHotel + room end
function GH.StashId(hotelId, room) return ('grumpy_hotel_%d_%d'):format(hotelId, room) end

function GH.Rental(hotelId, room) return GH.Rentals[hotelId] and GH.Rentals[hotelId][room] or nil end

function GH.RentalOf(cid, hotelId)
    for _, r in pairs(GH.Rentals[hotelId] or {}) do
        if r.citizenid == cid then return r end
    end
    return nil
end

-- Grace ends 24h after expiry, or 1h after the renter's first login after expiry, whichever is first
function GH.GraceEnd(r)
    local stop = r.expiresAt + Config.Grace.Hours * 3600
    if r.graceLoginAt then stop = math.min(stop, r.graceLoginAt + Config.Grace.LoginMinutes * 60) end
    return stop
end

-- 'active' | 'grace' | 'ended'
function GH.State(r, now)
    now = now or os.time()
    if now < r.expiresAt then return 'active' end
    if now < GH.GraceEnd(r) then return 'grace' end
    return 'ended'
end

function GH.ValidRoom(hotelId, room)
    local h = GH.Hotels[hotelId]
    room = math.tointeger(tonumber(room))
    if not h or not room or room < 1 or room > h.rooms then return nil end
    return h, room
end

function GH.Near(src, pos, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(pos.x, pos.y, pos.z)) <= dist
end

function GH.NearDoor(src, h) return GH.Near(src, h.door, Config.DoorRadius + Config.ServerDistance) end
function GH.NearInterior(src, h, extra) return GH.Near(src, h.interior, Config.RoomRadius + Config.ServerDistance + (extra or 0.0)) end

-- One paid / state-changing action at a time per player
function GH.Lock(src, fn)
    if busy[src] then return end
    busy[src] = true
    local ok, err = pcall(fn)
    busy[src] = nil
    if not ok then print(('^1[grumpy-hotel]^7 %s'):format(err)) end
end

function GH.OnCooldown(src, key, seconds)
    cooldowns[src] = cooldowns[src] or {}
    local now = GetGameTimer()
    local last = cooldowns[src][key]
    if last and now - last < seconds * 1000 then return true end
    cooldowns[src][key] = now
    return false
end

function GH.SrcByCid(cid)
    local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
    return P and P.PlayerData.source or nil
end

-- Empties the room stash (loads it first so an in-memory copy can't be saved back over the wipe)
function GH.WipeStash(hotelId, room)
    local id = GH.StashId(hotelId, room)
    local ok, err = pcall(function()
        exports['rsg-inventory']:RegisterStash(id, { label = id })
        exports['rsg-inventory']:ClearStash(id)
    end)
    if not ok then print(('^1[grumpy-hotel]^7 could not wipe stash %s: %s'):format(id, err)) end
end

---------------------------------------------------------------------
-- Client sync (public hotel data only; rentals are fetched on demand)
---------------------------------------------------------------------
function GH.PublicHotels()
    local out = {}
    for _, h in pairs(GH.Hotels) do
        out[#out + 1] = { id = h.id, label = h.label, rooms = h.rooms, door = h.door, interior = h.interior, stash = h.stash, blip = h.blip }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function GH.Broadcast() TriggerClientEvent('grumpy-hotel:client:sync', -1, GH.PublicHotels()) end

function GH.FreeRooms(hotelId)
    local h = GH.Hotels[hotelId]
    if not h then return 0 end
    local used = 0
    for room in pairs(GH.Rentals[hotelId] or {}) do
        if room <= h.rooms then used = used + 1 end
    end
    return h.rooms - used
end

---------------------------------------------------------------------
-- Rows -> records
---------------------------------------------------------------------
function GH.RowToHotel(row)
    return {
        id = row.id, label = row.label, rooms = row.rooms, price = tonumber(row.price) or 0, maxDays = row.max_days,
        door = vector4(row.door_x, row.door_y, row.door_z, row.door_h),
        interior = vector4(row.int_x, row.int_y, row.int_z, row.int_h),
        -- optional: without a stash point, storage opens from the room menu at the interior point
        stash = row.stash_x and vector4(row.stash_x, row.stash_y, row.stash_z, row.stash_h or 0.0) or nil,
        blip = row.blip == 1 or row.blip == true,
    }
end

-- Where the room storage opens: the stash point, or the interior point when none is set
function GH.StashPoint(h) return h.stash or h.interior end

function GH.RowToRental(row)
    return {
        id = row.id, hotel = row.hotel_id, room = row.room, citizenid = row.citizenid, name = row.renter_name,
        keyCid = row.key_citizenid, keyName = row.key_name,
        expiresAt = row.expires_at, graceLoginAt = row.grace_login_at,
    }
end

function GH.SetBucketDefaults(hotelId, rooms)
    for room = 1, rooms do
        SetRoutingBucketPopulationEnabled(GH.Bucket(hotelId, room), false)
    end
end

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `grumpy_hotels` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(50) NOT NULL,
            `rooms` INT NOT NULL,
            `price` DECIMAL(10,2) NOT NULL DEFAULT 0,
            `max_days` INT NOT NULL DEFAULT 1,
            `door_x` DOUBLE NOT NULL, `door_y` DOUBLE NOT NULL, `door_z` DOUBLE NOT NULL, `door_h` DOUBLE NOT NULL DEFAULT 0,
            `int_x` DOUBLE NOT NULL, `int_y` DOUBLE NOT NULL, `int_z` DOUBLE NOT NULL, `int_h` DOUBLE NOT NULL DEFAULT 0,
            `stash_x` DOUBLE DEFAULT NULL, `stash_y` DOUBLE DEFAULT NULL, `stash_z` DOUBLE DEFAULT NULL, `stash_h` DOUBLE DEFAULT NULL,
            `blip` TINYINT(1) NOT NULL DEFAULT 1,
            `created_by` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `grumpy_hotel_rentals` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `hotel_id` INT NOT NULL,
            `room` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `renter_name` VARCHAR(60) NOT NULL,
            `key_citizenid` VARCHAR(50) DEFAULT NULL,
            `key_name` VARCHAR(60) DEFAULT NULL,
            `expires_at` INT NOT NULL,
            `grace_login_at` INT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_room` (`hotel_id`, `room`),
            UNIQUE KEY `uniq_renter` (`hotel_id`, `citizenid`),
            KEY `idx_key` (`key_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `grumpy_hotel_occupants` (
            `citizenid` VARCHAR(50) NOT NULL,
            `hotel_id` INT NOT NULL,
            `room` INT NOT NULL,
            `role` VARCHAR(10) NOT NULL,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

-- v1.2: stash point columns for tables created before it existed (works on MySQL and MariaDB)
local function migrate()
    local has = MySQL.query.await("SHOW COLUMNS FROM `grumpy_hotels` LIKE 'stash_x'")
    if has and #has > 0 then return end
    MySQL.query.await([[ALTER TABLE `grumpy_hotels`
        ADD COLUMN `stash_x` DOUBLE DEFAULT NULL AFTER `int_h`, ADD COLUMN `stash_y` DOUBLE DEFAULT NULL AFTER `stash_x`,
        ADD COLUMN `stash_z` DOUBLE DEFAULT NULL AFTER `stash_y`, ADD COLUMN `stash_h` DOUBLE DEFAULT NULL AFTER `stash_z`]])
    print('[grumpy-hotel] added stash point columns to grumpy_hotels')
end

MySQL.ready(function()
    if Config.AutoDatabase then createTables() migrate() end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM grumpy_hotels') or {}) do
        local h = GH.RowToHotel(row)
        GH.Hotels[h.id] = h
        GH.Rentals[h.id] = {}
        GH.SetBucketDefaults(h.id, h.rooms)
    end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM grumpy_hotel_rentals') or {}) do
        if GH.Rentals[row.hotel_id] then
            local r = GH.RowToRental(row)
            GH.Rentals[r.hotel][r.room] = r
        else
            print(('^3[grumpy-hotel]^7 rental %d belongs to missing hotel %d; ignored'):format(row.id, row.hotel_id))
        end
    end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM grumpy_hotel_occupants') or {}) do
        GH.Occupants[row.citizenid] = { hotel = row.hotel_id, room = row.room, role = row.role }
    end

    GH.Ready = true
    GH.Broadcast()
    if GH.AfterLoad then GH.AfterLoad() end
    GH.Debug(('loaded %d hotels'):format(#GH.PublicHotels()))
end)

---------------------------------------------------------------------
-- Callbacks / exports
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-hotel:server:getHotels', function(source, cb)
    cb({ hotels = GH.PublicHotels(), isAdmin = GH.IsAdmin(source) })
end)

-- true once hotels and rentals are loaded (other resources wait for this before creating hotels)
exports('IsReady', function() return GH.Ready end)

-- List for other resources (bartender editor, saloon scripts)
exports('GetHotels', function()
    local out = {}
    for _, h in ipairs(GH.PublicHotels()) do
        local full = GH.Hotels[h.id]
        out[#out + 1] = { id = h.id, label = h.label, rooms = h.rooms, price = full.price, maxDays = full.maxDays, free = GH.FreeRooms(h.id) }
    end
    return out
end)

exports('GetHotel', function(hotelId)
    local h = GH.Hotels[math.tointeger(tonumber(hotelId)) or -1]
    if not h then return nil end
    return { id = h.id, label = h.label, rooms = h.rooms, price = h.price, maxDays = h.maxDays, free = GH.FreeRooms(h.id) }
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
    cooldowns[source] = nil
end)
