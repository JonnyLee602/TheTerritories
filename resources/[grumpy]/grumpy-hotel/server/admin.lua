-- /hotellist: create, edit, delete hotels, list renters, evict. Every action re-checks the admin permission.
local RSGCore = exports['rsg-core']:GetCoreObject()

RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_admin_help'), {}, false, function(source)
    TriggerClientEvent('grumpy-hotel:client:openAdmin', source)
end, Config.AdminPermission)

local function admin(src)
    if not RSGCore.Functions.GetPlayer(src) or not GH.IsAdmin(src) then return false end
    return true
end

local function adminHotels()
    local now, out = os.time(), {}
    for _, pub in ipairs(GH.PublicHotels()) do
        local h = GH.Hotels[pub.id]
        local rentals = {}
        for room, r in pairs(GH.Rentals[h.id] or {}) do
            local occupants = 0
            for _ in ipairs(GH.RoomOccupants(h.id, room)) do occupants = occupants + 1 end
            rentals[#rentals + 1] = {
                room = room, name = r.name, citizenid = r.citizenid, keyName = r.keyName,
                state = GH.State(r, now), expiresIn = r.expiresAt - now,
                online = GH.SrcByCid(r.citizenid) ~= nil, occupants = occupants,
            }
        end
        table.sort(rentals, function(a, b) return a.room < b.room end)
        out[#out + 1] = {
            id = h.id, label = h.label, rooms = h.rooms, price = h.price, maxDays = h.maxDays, blip = h.blip,
            door = { x = h.door.x, y = h.door.y, z = h.door.z, w = h.door.w },
            interior = { x = h.interior.x, y = h.interior.y, z = h.interior.z, w = h.interior.w },
            free = GH.FreeRooms(h.id), rentals = rentals,
        }
    end
    return out
end

RSGCore.Functions.CreateCallback('grumpy-hotel:server:adminData', function(source, cb)
    if not admin(source) then return cb(nil) end
    cb({ hotels = adminHotels(), limits = { maxRooms = Config.MaxRooms, maxDays = Config.MaxDaysLimit, maxRate = Config.MaxDailyRate } })
end)

local function refreshAdmin(src) TriggerClientEvent('grumpy-hotel:client:adminRefresh', src) end

---------------------------------------------------------------------
-- Form validation
---------------------------------------------------------------------
local function point(p)
    if type(p) ~= 'table' then return nil end
    local x, y, z, w = tonumber(p.x), tonumber(p.y), tonumber(p.z), tonumber(p.w) or 0.0
    if not (GH.Finite(x) and GH.Finite(y) and GH.Finite(z) and GH.Finite(w)) then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    return vector4(x, y, z, w % 360.0)
end

local function sanitise(data)
    if type(data) ~= 'table' then return nil, 'invalid_form' end
    local label = type(data.label) == 'string' and data.label:gsub('[<>"\'`]', ''):gsub('^%s+', ''):gsub('%s+$', '') or ''
    label = label:sub(1, 50)
    if label == '' then return nil, 'invalid_name' end
    local rooms = math.tointeger(tonumber(data.rooms))
    if not rooms or rooms < 1 or rooms > Config.MaxRooms or rooms >= Config.BucketsPerHotel then return nil, 'invalid_rooms' end
    local price = tonumber(data.price)
    if not GH.Finite(price) or price < 0 or price > Config.MaxDailyRate then return nil, 'invalid_price' end
    price = math.floor(price * 100 + 0.5) / 100
    local maxDays = math.tointeger(tonumber(data.maxDays))
    if not maxDays or maxDays < 1 or maxDays > Config.MaxDaysLimit then return nil, 'invalid_days' end
    local door, interior = point(data.door), point(data.interior)
    if not door then return nil, 'invalid_door' end
    if not interior then return nil, 'invalid_interior' end
    return { label = label, rooms = rooms, price = price, maxDays = maxDays, door = door, interior = interior, blip = data.blip == true }
end

---------------------------------------------------------------------
-- Create / update / delete (shared by the admin menu and the exports)
---------------------------------------------------------------------
-- f = sanitised form. Returns ok, errKey, hotelId
function GH.SaveHotel(id, f, createdBy)
    if id then
        local h = GH.Hotels[id]
        if not h then return false, 'hotel_unavailable' end
        for room in pairs(GH.Rentals[id] or {}) do
            if room > f.rooms then return false, 'rooms_in_use', room end
        end
        MySQL.update.await([[UPDATE grumpy_hotels SET label = ?, rooms = ?, price = ?, max_days = ?,
            door_x = ?, door_y = ?, door_z = ?, door_h = ?, int_x = ?, int_y = ?, int_z = ?, int_h = ?, blip = ? WHERE id = ?]],
            { f.label, f.rooms, f.price, f.maxDays, f.door.x, f.door.y, f.door.z, f.door.w,
              f.interior.x, f.interior.y, f.interior.z, f.interior.w, f.blip and 1 or 0, id })
        h.label, h.rooms, h.price, h.maxDays, h.door, h.interior, h.blip = f.label, f.rooms, f.price, f.maxDays, f.door, f.interior, f.blip
        GH.SetBucketDefaults(id, f.rooms)
        GH.Broadcast()
        return true, nil, id
    end
    local newId = MySQL.insert.await([[INSERT INTO grumpy_hotels (label, rooms, price, max_days,
        door_x, door_y, door_z, door_h, int_x, int_y, int_z, int_h, blip, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { f.label, f.rooms, f.price, f.maxDays, f.door.x, f.door.y, f.door.z, f.door.w,
          f.interior.x, f.interior.y, f.interior.z, f.interior.w, f.blip and 1 or 0, createdBy })
    if not newId then return false, 'db_error' end
    GH.Hotels[newId] = { id = newId, label = f.label, rooms = f.rooms, price = f.price, maxDays = f.maxDays,
        door = f.door, interior = f.interior, blip = f.blip }
    GH.Rentals[newId] = {}
    GH.SetBucketDefaults(newId, f.rooms)
    GH.Broadcast()
    return true, nil, newId
end

function GH.DeleteHotel(id)
    local h = GH.Hotels[id]
    if not h then return false end
    local list = {}
    for _, r in pairs(GH.Rentals[id] or {}) do list[#list + 1] = r end
    for _, r in ipairs(list) do GH.EndRental(r, locale('hotel_closed', h.label)) end
    -- anyone still inside (e.g. law after the rental ended)
    for room = 1, h.rooms do GH.EjectAll(id, room, locale('room_closed')) end
    MySQL.update.await('DELETE FROM grumpy_hotels WHERE id = ?', { id })
    MySQL.update.await('DELETE FROM grumpy_hotel_occupants WHERE hotel_id = ?', { id })
    GH.Hotels[id], GH.Rentals[id] = nil, nil
    for cid, row in pairs(GH.Occupants) do if row.hotel == id then GH.Occupants[cid] = nil end end
    GH.Broadcast()
    return true, h.label
end

RegisterNetEvent('grumpy-hotel:server:adminSave', function(id, data)
    local src = source
    if not admin(src) or GH.OnCooldown(src, 'adminSave', 1) then return end
    local f, err = sanitise(data)
    if not f then return GH.Notify(src, locale(err), 'error') end
    id = math.tointeger(tonumber(id))
    if id and not GH.Hotels[id] then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local ok, errKey, extra = GH.SaveHotel(id, f, Player and Player.PlayerData.citizenid)
    if not ok then return GH.Notify(src, locale(errKey, extra), 'error') end
    if id then
        GH.Notify(src, locale('hotel_saved', f.label), 'success')
    else
        GH.Notify(src, locale('hotel_created', f.label, extra), 'success')
        print(('[grumpy-hotel] %s created hotel %d "%s"'):format(GetPlayerName(src), extra, f.label))
    end
    refreshAdmin(src)
end)

RegisterNetEvent('grumpy-hotel:server:adminDelete', function(id)
    local src = source
    if not admin(src) or GH.OnCooldown(src, 'adminDelete', 1) then return end
    id = math.tointeger(tonumber(id))
    local ok, label = GH.DeleteHotel(id or -1)
    if not ok then return end
    GH.Notify(src, locale('hotel_deleted', label), 'success')
    print(('[grumpy-hotel] %s deleted hotel %d "%s"'):format(GetPlayerName(src), id, label))
    refreshAdmin(src)
end)

---------------------------------------------------------------------
-- Exports for other resources (grumpy-pob hotel businesses)
-- data = { label, rooms, price, maxDays, door = {x,y,z,w}, interior = {x,y,z,w}, blip = bool }
---------------------------------------------------------------------
exports('CreateHotel', function(data)
    local f, err = sanitise(data)
    if not f then return nil, err end
    local ok, errKey, id = GH.SaveHotel(nil, f, GetInvokingResource())
    if not ok then return nil, errKey end
    print(('[grumpy-hotel] %s created hotel %d "%s"'):format(GetInvokingResource() or '?', id, f.label))
    return id
end)

exports('UpdateHotel', function(id, data)
    id = math.tointeger(tonumber(id))
    if not id or not GH.Hotels[id] then return false, 'hotel_unavailable' end
    local f, err = sanitise(data)
    if not f then return false, err end
    local ok, errKey = GH.SaveHotel(id, f)
    return ok, errKey
end)

exports('DeleteHotel', function(id)
    return (GH.DeleteHotel(math.tointeger(tonumber(id)) or -1))
end)


RegisterNetEvent('grumpy-hotel:server:adminEvict', function(id, room)
    local src = source
    if not admin(src) or GH.OnCooldown(src, 'adminEvict', 1) then return end
    local h
    h, room = GH.ValidRoom(math.tointeger(tonumber(id)) or -1, room)
    local r = h and GH.Rental(h.id, room)
    if not r then return end
    GH.EndRental(r, locale('evicted', room, h.label))
    GH.Notify(src, locale('evict_done', r.name, room), 'success')
    print(('[grumpy-hotel] %s evicted %s from %s room %d'):format(GetPlayerName(src), r.citizenid, h.label, room))
    refreshAdmin(src)
end)

-- Teleport is approved here and carried out by the admin's client (always bucket 0)
RegisterNetEvent('grumpy-hotel:server:adminTeleport', function(id, which)
    local src = source
    if not admin(src) or GH.Inside[src] then return end
    local h = GH.Hotels[math.tointeger(tonumber(id)) or -1]
    if not h then return end
    TriggerClientEvent('grumpy-hotel:client:adminTeleport', src, which == 'interior' and h.interior or h.door)
end)
