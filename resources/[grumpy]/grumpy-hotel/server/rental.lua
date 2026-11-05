-- Renting through rental points (bartenders, saloon NPCs), expiry, grace period and stash wipe.
local RSGCore = exports['rsg-core']:GetCoreObject()

local points = {}   -- [key] = { hotel = id, coords = vector3 }  registered by other resources

---------------------------------------------------------------------
-- Rental points (server exports for grumpy-bartender and future saloon scripts)
---------------------------------------------------------------------
exports('SetRentalPoint', function(key, hotelId, coords)
    hotelId = math.tointeger(tonumber(hotelId))
    if type(key) ~= 'string' or not hotelId then return false end
    if type(coords) == 'table' then coords = vector3(coords.x, coords.y, coords.z) end
    if type(coords) ~= 'vector3' and type(coords) ~= 'vector4' then return false end
    points[key] = { hotel = hotelId, coords = vector3(coords.x, coords.y, coords.z), owner = GetInvokingResource() }
    return true
end)

exports('RemoveRentalPoint', function(key) points[key] = nil end)

-- A resource that registered points stopped: its points are gone too
AddEventHandler('onResourceStop', function(res)
    for key, p in pairs(points) do
        if p.owner == res then points[key] = nil end
    end
end)

local function pointFor(src, key)
    local p = type(key) == 'string' and points[key] or nil
    if not p then return nil end
    local h = GH.Hotels[p.hotel]
    if not h then GH.Notify(src, locale('hotel_unavailable'), 'error') return nil end
    if not GH.Near(src, p.coords, Config.RentalDistance) then GH.Notify(src, locale('too_far'), 'error') return nil end
    return h, p
end

---------------------------------------------------------------------
-- End a rental: everyone out, stash wiped, row deleted
---------------------------------------------------------------------
function GH.EndRental(r, renterMsg)
    GH.EjectAll(r.hotel, r.room, locale('room_closed'))
    GH.WipeStash(r.hotel, r.room)
    MySQL.update.await('DELETE FROM grumpy_hotel_rentals WHERE id = ?', { r.id })
    if GH.Rentals[r.hotel] then GH.Rentals[r.hotel][r.room] = nil end
    local src = GH.SrcByCid(r.citizenid)
    if src and renterMsg then GH.Notify(src, renterMsg, 'error') end
    local keySrc = r.keyCid and GH.SrcByCid(r.keyCid)
    if keySrc then
        local h = GH.Hotels[r.hotel]
        GH.Notify(keySrc, locale('key_room_ended', h and h.label or '?', r.room), 'inform')
    end
end

local function maxExtraDays(h, r, now)
    if GH.State(r, now) ~= 'active' then return h.maxDays end -- renewing an expired room starts from now
    local paidAhead = r.expiresAt - now
    return math.max(0, math.floor((h.maxDays * Config.DaySeconds - paidAhead) / Config.DaySeconds))
end

---------------------------------------------------------------------
-- Rental menu payload
---------------------------------------------------------------------
local function rentalPayload(src, Player, h, key)
    local cid, now = Player.PlayerData.citizenid, os.time()
    local rooms = {}
    for room = 1, h.rooms do
        local r = GH.Rental(h.id, room)
        local e = { room = room, status = 'available' }
        if r then
            if r.citizenid == cid then e.status = 'mine'
            else e.status, e.name = 'taken', r.name end
        end
        rooms[#rooms + 1] = e
    end
    local mine = GH.RentalOf(cid, h.id)
    local mineOut
    if mine then
        local state = GH.State(mine, now)
        mineOut = {
            room = mine.room, state = state,
            expiresIn = math.max(0, mine.expiresAt - now),
            graceIn = state == 'grace' and math.max(0, GH.GraceEnd(mine) - now) or 0,
            canExtend = maxExtraDays(h, mine, now),
            keyName = mine.keyName,
        }
    end
    return {
        key = key, label = h.label, price = h.price, maxDays = h.maxDays,
        free = GH.FreeRooms(h.id), total = h.rooms, rooms = rooms, mine = mineOut,
    }
end

RSGCore.Functions.CreateCallback('grumpy-hotel:server:getRental', function(source, cb, key)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    local h = pointFor(source, key)
    if not h then return cb(nil) end
    cb(rentalPayload(source, Player, h, key))
end)

local function refresh(src) TriggerClientEvent('grumpy-hotel:client:rentalRefresh', src) end

---------------------------------------------------------------------
-- Rent / extend / check out / revoke key
---------------------------------------------------------------------
local function sanitiseDays(days, max)
    days = math.tointeger(tonumber(days))
    if not days or days < 1 or days > max then return nil end
    return days
end

RegisterNetEvent('grumpy-hotel:server:rent', function(key, room, days)
    local src = source
    GH.Lock(src, function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        local h = pointFor(src, key)
        if not h then return end
        local _, r = GH.ValidRoom(h.id, room)
        days = sanitiseDays(days, h.maxDays)
        if not r or not days then return end

        local cid, now = Player.PlayerData.citizenid, os.time()
        if GH.RentalOf(cid, h.id) then return GH.Notify(src, locale('already_renting'), 'error') end
        if GH.Rental(h.id, r) then return GH.Notify(src, locale('room_taken'), 'error') end

        local cost = h.price * days
        if cost > 0 and not Player.Functions.RemoveMoney('cash', cost, 'grumpy-hotel:rent') then
            return GH.Notify(src, locale('not_enough_money'), 'error')
        end

        local name = GH.PlayerName(Player)
        local expires = now + days * Config.DaySeconds
        local ok, id = pcall(MySQL.insert.await,
            'INSERT INTO grumpy_hotel_rentals (hotel_id, room, citizenid, renter_name, expires_at) VALUES (?, ?, ?, ?, ?)',
            { h.id, r, cid, name, expires })
        if not ok or not id or id == 0 then
            if cost > 0 then Player.Functions.AddMoney('cash', cost, 'grumpy-hotel:rent-refund') end
            return GH.Notify(src, locale('room_taken'), 'error')
        end

        GH.WipeStash(h.id, r) -- a fresh room always starts empty
        GH.Rentals[h.id][r] = { id = id, hotel = h.id, room = r, citizenid = cid, name = name, expiresAt = expires }
        if cost > 0 then TriggerEvent('grumpy-hotel:server:rentPaid', h.id, src, cost, 'rent') end -- server-only (grumpy-pob routes it to a business)
        GH.Notify(src, locale('rented', r, h.label, days, cost), 'success')
        refresh(src)
    end)
end)

RegisterNetEvent('grumpy-hotel:server:extend', function(key, days)
    local src = source
    GH.Lock(src, function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        local h = pointFor(src, key)
        if not h then return end
        local r = GH.RentalOf(Player.PlayerData.citizenid, h.id)
        if not r then return GH.Notify(src, locale('no_rental'), 'error') end

        local now = os.time()
        local state = GH.State(r, now)
        if state == 'ended' then return GH.Notify(src, locale('no_rental'), 'error') end
        days = sanitiseDays(days, maxExtraDays(h, r, now))
        if not days then return GH.Notify(src, locale('extend_limit', h.maxDays), 'error') end

        local cost = h.price * days
        if cost > 0 and not Player.Functions.RemoveMoney('cash', cost, 'grumpy-hotel:extend') then
            return GH.Notify(src, locale('not_enough_money'), 'error')
        end
        local base = state == 'active' and r.expiresAt or now
        local newExpiry = base + days * Config.DaySeconds
        MySQL.update.await('UPDATE grumpy_hotel_rentals SET expires_at = ?, grace_login_at = NULL WHERE id = ?', { newExpiry, r.id })
        r.expiresAt, r.graceLoginAt, r.warned, r.expiredHandled = newExpiry, nil, nil, nil
        if cost > 0 then TriggerEvent('grumpy-hotel:server:rentPaid', h.id, src, cost, 'extend') end
        GH.Notify(src, locale(state == 'active' and 'extended' or 'renewed', days, cost), 'success')
        refresh(src)
    end)
end)

RegisterNetEvent('grumpy-hotel:server:checkout', function(key)
    local src = source
    GH.Lock(src, function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        local h = pointFor(src, key)
        if not h then return end
        local r = GH.RentalOf(Player.PlayerData.citizenid, h.id)
        if not r then return GH.Notify(src, locale('no_rental'), 'error') end
        GH.EndRental(r, nil)
        GH.Notify(src, locale('checked_out'), 'success')
        refresh(src)
    end)
end)

RegisterNetEvent('grumpy-hotel:server:rentalRevokeKey', function(key)
    local src = source
    GH.Lock(src, function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        local h = pointFor(src, key)
        if not h then return end
        local r = GH.RentalOf(Player.PlayerData.citizenid, h.id)
        if not r then return end
        GH.RevokeKey(src, r)
        refresh(src)
    end)
end)

---------------------------------------------------------------------
-- Expiry sweep
---------------------------------------------------------------------
local function hoursLeft(seconds) return math.max(1, math.ceil(seconds / 3600)) end

local function sweep()
    local now = os.time()
    local ended = {}
    for _, rooms in pairs(GH.Rentals) do
        for _, r in pairs(rooms) do
            local state = GH.State(r, now)
            local h = GH.Hotels[r.hotel]
            local label = h and h.label or '?'
            local renterSrc = GH.SrcByCid(r.citizenid)
            if state == 'active' then
                if not r.warned and r.expiresAt - now <= Config.WarnBefore and renterSrc then
                    r.warned = true
                    GH.Notify(renterSrc, locale('rental_expiring', r.room, label, hoursLeft(r.expiresAt - now)), 'warning')
                end
            elseif state == 'grace' then
                if not r.expiredHandled then
                    r.expiredHandled = true
                    -- renter is online when it runs out: that counts as their first login after expiry
                    if renterSrc and not r.graceLoginAt then
                        r.graceLoginAt = now
                        MySQL.update.await('UPDATE grumpy_hotel_rentals SET grace_login_at = ? WHERE id = ?', { now, r.id })
                    end
                    GH.EjectAll(r.hotel, r.room, locale('room_locked'), true)
                    if renterSrc then
                        GH.Notify(renterSrc, locale('rental_expired', r.room, label, math.ceil((GH.GraceEnd(r) - now) / 60)), 'error')
                    end
                end
            else
                ended[#ended + 1] = r
            end
        end
    end
    for _, r in ipairs(ended) do
        local h = GH.Hotels[r.hotel]
        GH.EndRental(r, locale('rental_ended', r.room, h and h.label or '?'))
    end
end

CreateThread(function()
    while not GH.Ready do Wait(500) end
    while true do
        local ok, err = pcall(sweep)
        if not ok then print(('^1[grumpy-hotel]^7 sweep failed: %s'):format(err)) end
        Wait(Config.SweepInterval * 1000)
    end
end)

-- Login: start the 1h grace clock on expired rooms, and warn about rooms running out
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src, cid, now = Player.PlayerData.source, Player.PlayerData.citizenid, os.time()
    SetTimeout(10000, function()
        if not RSGCore.Functions.GetPlayer(src) then return end
        for _, rooms in pairs(GH.Rentals) do
            for _, r in pairs(rooms) do
                if r.citizenid == cid then
                    local h = GH.Hotels[r.hotel]
                    local label = h and h.label or '?'
                    local state = GH.State(r, now)
                    if state == 'grace' then
                        if not r.graceLoginAt then
                            r.graceLoginAt = now
                            MySQL.update.await('UPDATE grumpy_hotel_rentals SET grace_login_at = ? WHERE id = ?', { now, r.id })
                        end
                        GH.Notify(src, locale('rental_grace_login', r.room, label, math.ceil((GH.GraceEnd(r) - os.time()) / 60)), 'error')
                    elseif state == 'active' and r.expiresAt - now <= Config.WarnBefore then
                        r.warned = true
                        GH.Notify(src, locale('rental_expiring', r.room, label, hoursLeft(r.expiresAt - now)), 'warning')
                    end
                end
            end
        end
    end)
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
-- Does this character rent a room (at a hotel, or anywhere)? Returns rental info or nil
exports('GetRental', function(citizenid, hotelId)
    local now = os.time()
    for hid, rooms in pairs(GH.Rentals) do
        if not hotelId or hid == hotelId then
            for _, r in pairs(rooms) do
                if r.citizenid == citizenid then
                    return { hotel = r.hotel, room = r.room, state = GH.State(r, now), expiresAt = r.expiresAt, keyName = r.keyName }
                end
            end
        end
    end
    return nil
end)

exports('HasKey', function(citizenid, hotelId, room)
    local r = GH.Rental(hotelId, room)
    return r ~= nil and GH.State(r) == 'active' and (r.citizenid == citizenid or r.keyCid == citizenid)
end)
