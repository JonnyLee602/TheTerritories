-- Entering / leaving rooms, instancing, knocking, visitors, keys, stash, death and logout restore.
local RSGCore = exports['rsg-core']:GetCoreObject()

local knocks = {}           -- [knockId] = { id, visitor, hotel, room, hosts = { [src] = true } }
local knockByVisitor = {}   -- [visitorSrc] = knockId
local pendingRestore = {}   -- [src] = { hotel, room, role }  set on login, resolved once the client has spawned
local nextKnockId = 0

local HOST_ROLES = { renter = true, key = true }
local STASH_ROLES = { renter = true, key = true, law = true }

---------------------------------------------------------------------
-- Access
---------------------------------------------------------------------
-- Role a player has on a room from rentals / keys / warrants (visitors are only ever let in, never derived)
function GH.AccessRole(src, Player, hotelId, room)
    local r = GH.Rental(hotelId, room)
    if not r then return nil end
    local cid, state = Player.PlayerData.citizenid, GH.State(r)
    if state == 'active' then
        if r.citizenid == cid then return 'renter' end
        if r.keyCid == cid then return 'key' end
    end
    if state ~= 'ended' and GH.HasWarrant and GH.HasWarrant(src, hotelId, room, r.id) then return 'law' end
    return nil
end

function GH.RoomOccupants(hotelId, room)
    local out = {}
    for src, info in pairs(GH.Inside) do
        if info.hotel == hotelId and info.room == room then out[#out + 1] = src end
    end
    return out
end

local function hostsIn(hotelId, room)
    local out = {}
    for _, src in ipairs(GH.RoomOccupants(hotelId, room)) do
        if HOST_ROLES[GH.Inside[src].role] then out[#out + 1] = src end
    end
    return out
end

local function saveOccupant(cid, hotelId, room, role)
    GH.Occupants[cid] = { hotel = hotelId, room = room, role = role }
    MySQL.prepare('INSERT INTO grumpy_hotel_occupants (citizenid, hotel_id, room, role) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE hotel_id = VALUES(hotel_id), room = VALUES(room), role = VALUES(role)',
        { cid, hotelId, room, role })
end

local function clearOccupant(cid)
    if not GH.Occupants[cid] then return end
    GH.Occupants[cid] = nil
    MySQL.prepare('DELETE FROM grumpy_hotel_occupants WHERE citizenid = ?', { cid })
end

local function roomPayload(h, room, role)
    return {
        hotel = h.id, room = room, role = role, label = h.label, interior = h.interior,
        voice = Config.Voice.Enabled and (Config.Voice.VoiceChannelBase + GH.Bucket(h.id, room)) or nil,
    }
end

---------------------------------------------------------------------
-- Moving players in and out
---------------------------------------------------------------------
function GH.PutInRoom(src, hotelId, room, role, noTeleport)
    local Player = RSGCore.Functions.GetPlayer(src)
    local h = GH.Hotels[hotelId]
    if not Player or not h then return false end
    RSGCore.Functions.SetPlayerBucket(src, GH.Bucket(hotelId, room))
    GH.Inside[src] = { hotel = hotelId, room = room, role = role, cid = Player.PlayerData.citizenid }
    saveOccupant(Player.PlayerData.citizenid, hotelId, room, role)
    TriggerClientEvent('grumpy-hotel:client:entered', src, roomPayload(h, room, role), noTeleport == true)
    return true
end

local ejectGuestsIfNoHost

-- opts: toDoor (default true) = teleport to the hotel door, message/ntype = notify, noCascade = don't eject guests
function GH.RemoveFromRoom(src, opts)
    opts = opts or {}
    local info = GH.Inside[src]
    if not info then return end
    GH.Inside[src] = nil
    clearOccupant(info.cid)
    for _, k in pairs(knocks) do k.hosts[src] = nil end
    RSGCore.Functions.SetPlayerBucket(src, 0)
    pcall(function() exports['rsg-inventory']:CloseInventory(src) end)
    local h = GH.Hotels[info.hotel]
    TriggerClientEvent('grumpy-hotel:client:left', src, opts.toDoor ~= false and h and h.door or nil)
    if opts.message then GH.Notify(src, opts.message, opts.ntype or 'inform') end
    if not opts.noCascade then ejectGuestsIfNoHost(info.hotel, info.room) end
end

-- Visitors leave with the last renter / key holder
ejectGuestsIfNoHost = function(hotelId, room)
    if #hostsIn(hotelId, room) > 0 then return end
    for _, src in ipairs(GH.RoomOccupants(hotelId, room)) do
        if GH.Inside[src].role == 'visitor' then
            GH.RemoveFromRoom(src, { message = locale('host_left'), noCascade = true })
        end
    end
end

-- Everyone out (expiry, eviction, deletion). keepLaw = officers with a warrant may stay during grace
function GH.EjectAll(hotelId, room, message, keepLaw)
    for _, src in ipairs(GH.RoomOccupants(hotelId, room)) do
        if not (keepLaw and GH.Inside[src].role == 'law') then
            GH.RemoveFromRoom(src, { message = message, noCascade = true })
        end
    end
end

-- A key holder / renter whose access changed while inside (key revoked, key given)
function GH.SetRole(src, role)
    local info = GH.Inside[src]
    if not info then return end
    info.role = role
    saveOccupant(info.cid, info.hotel, info.room, role)
    TriggerClientEvent('grumpy-hotel:client:role', src, role)
end

---------------------------------------------------------------------
-- Door: list rooms
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-hotel:server:getDoor', function(source, cb, hotelId)
    local Player = RSGCore.Functions.GetPlayer(source)
    local h = Player and GH.Hotels[math.tointeger(tonumber(hotelId)) or -1]
    if not h or GH.Inside[source] then return cb(nil) end
    if not GH.NearDoor(source, h) then GH.Notify(source, locale('too_far'), 'error') return cb(nil) end

    local cid, now = Player.PlayerData.citizenid, os.time()
    local canIssue = GH.CanIssueWarrant and GH.CanIssueWarrant(Player) or false
    local rooms = {}
    for room = 1, h.rooms do
        local r = GH.Rental(h.id, room)
        local entry = { room = room, status = 'available' }
        if r then
            local state = GH.State(r, now)
            local law = state ~= 'ended' and GH.HasWarrant and GH.HasWarrant(source, h.id, room, r.id)
            if r.citizenid == cid then
                entry.status = state == 'active' and 'mine' or 'locked'
                entry.canEnter = state == 'active'
            elseif r.keyCid == cid and state == 'active' then
                entry.status, entry.name, entry.canEnter = 'key', r.name, true
            else
                entry.status, entry.name = 'taken', r.name
                entry.canKnock = state == 'active'
            end
            if law and not entry.canEnter then entry.canEnter, entry.warrant = true, true end
            entry.canWarrant = canIssue and state ~= 'ended' and r.citizenid ~= cid
        end
        rooms[#rooms + 1] = entry
    end
    cb({ hotel = h.id, label = h.label, rooms = rooms })
end)

---------------------------------------------------------------------
-- Enter (renter, key holder or warrant)
---------------------------------------------------------------------
local function enterCheck(src, hotelId, room)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or GH.Inside[src] then return nil end
    local h
    h, room = GH.ValidRoom(math.tointeger(tonumber(hotelId)) or -1, room)
    if not h then return nil end
    if not GH.NearDoor(src, h) then GH.Notify(src, locale('too_far'), 'error') return nil end
    local meta = Player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return nil end
    local role = GH.AccessRole(src, Player, h.id, room)
    if not role then GH.Notify(src, locale('no_access'), 'error') return nil end
    return h, room, role
end

-- Asked before the unlock animation plays
RSGCore.Functions.CreateCallback('grumpy-hotel:server:canEnter', function(source, cb, hotelId, room)
    cb(enterCheck(source, hotelId, room) ~= nil)
end)

RegisterNetEvent('grumpy-hotel:server:enter', function(hotelId, room)
    local src = source
    GH.Lock(src, function()
        local h, r, role = enterCheck(src, hotelId, room)
        if not h then return end
        GH.PutInRoom(src, h.id, r, role)
        if role == 'law' then
            for _, other in ipairs(GH.RoomOccupants(h.id, r)) do
                if other ~= src then GH.Notify(other, locale('law_entered'), 'warning') end
            end
        end
    end)
end)

---------------------------------------------------------------------
-- Leave
---------------------------------------------------------------------
RegisterNetEvent('grumpy-hotel:server:leave', function()
    local src = source
    local info = GH.Inside[src]
    if not info then return end
    local h = GH.Hotels[info.hotel]
    if h and not GH.NearInterior(src, h, Config.RestoreDistance) then return GH.Notify(src, locale('too_far'), 'error') end
    GH.RemoveFromRoom(src)
end)

---------------------------------------------------------------------
-- Knocking
---------------------------------------------------------------------
local function closeKnock(k, visitorMsg, ntype)
    knocks[k.id] = nil
    if knockByVisitor[k.visitor] == k.id then knockByVisitor[k.visitor] = nil end
    for host in pairs(k.hosts) do TriggerClientEvent('grumpy-hotel:client:knockClosed', host, k.id) end
    if visitorMsg and GetPlayerPed(k.visitor) ~= 0 then GH.Notify(k.visitor, visitorMsg, ntype or 'inform') end
end

RegisterNetEvent('grumpy-hotel:server:knock', function(hotelId, room)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or GH.Inside[src] or knockByVisitor[src] then return end
    local h
    h, room = GH.ValidRoom(math.tointeger(tonumber(hotelId)) or -1, room)
    if not h then return end
    if not GH.NearDoor(src, h) then return GH.Notify(src, locale('too_far'), 'error') end
    if GH.OnCooldown(src, 'knock', Config.Knock.Cooldown) then return GH.Notify(src, locale('knock_cooldown'), 'error') end

    local r = GH.Rental(h.id, room)
    if not r or GH.State(r) ~= 'active' then return GH.Notify(src, locale('no_answer'), 'inform') end

    local hosts = hostsIn(h.id, room)
    if #hosts == 0 then
        -- nobody home: answer after the knock animation so it feels like waiting at the door
        SetTimeout(Config.Anims.knock.duration, function() GH.Notify(src, locale('no_answer'), 'inform') end)
        return
    end

    nextKnockId = nextKnockId + 1
    local k = { id = nextKnockId, visitor = src, hotel = h.id, room = room, hosts = {} }
    knocks[k.id], knockByVisitor[src] = k, k.id
    local name = GH.PlayerName(Player)
    for _, host in ipairs(hosts) do
        k.hosts[host] = true
        TriggerClientEvent('grumpy-hotel:client:knock', host, { id = k.id, name = name, timeout = Config.Knock.Timeout })
    end
    GH.Notify(src, locale('knocked'), 'inform')

    SetTimeout(Config.Knock.Timeout * 1000, function()
        if knocks[k.id] then closeKnock(k, locale('no_answer'), 'inform') end
    end)
end)

RegisterNetEvent('grumpy-hotel:server:answerKnock', function(knockId, allow)
    local src = source
    local k = knocks[math.tointeger(tonumber(knockId)) or -1]
    local info = GH.Inside[src]
    if not k or not k.hosts[src] or not info or info.hotel ~= k.hotel or info.room ~= k.room or not HOST_ROLES[info.role] then return end

    if allow ~= true then
        closeKnock(k, locale('knock_refused'), 'error')
        return
    end

    local visitor = k.visitor
    local h = GH.Hotels[k.hotel]
    local VPlayer = RSGCore.Functions.GetPlayer(visitor)
    if not h or not VPlayer or GH.Inside[visitor] or not GH.NearDoor(visitor, h) then
        closeKnock(k)
        return GH.Notify(src, locale('visitor_gone'), 'error')
    end
    closeKnock(k)
    GH.PutInRoom(visitor, k.hotel, k.room, 'visitor')
    GH.Notify(visitor, locale('let_in'), 'success')
    GH.Notify(src, locale('you_let_in', GH.PlayerName(VPlayer)), 'success')
end)

---------------------------------------------------------------------
-- Room menu (inside): occupants, key, kick, stash
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-hotel:server:roomMenu', function(source, cb)
    local info = GH.Inside[source]
    local h = info and GH.Hotels[info.hotel]
    if not h then return cb(nil) end
    local r = GH.Rental(info.hotel, info.room)
    local now = os.time()
    local occupants = {}
    for _, other in ipairs(GH.RoomOccupants(info.hotel, info.room)) do
        if other ~= source then
            local P = RSGCore.Functions.GetPlayer(other)
            if P then occupants[#occupants + 1] = { src = other, name = GH.PlayerName(P), role = GH.Inside[other].role } end
        end
    end
    cb({
        label = h.label, room = info.room, role = info.role,
        renter = r and r.name or nil,
        expiresIn = r and math.max(0, r.expiresAt - now) or 0,
        keyName = r and r.keyName or nil,
        hasKeyHolder = r and r.keyCid ~= nil or false,
        canStash = STASH_ROLES[info.role] == true,
        occupants = occupants,
    })
end)

local function insideHost(src, roles)
    local Player = RSGCore.Functions.GetPlayer(src)
    local info = GH.Inside[src]
    if not Player or not info or not roles[info.role] then return nil end
    local h = GH.Hotels[info.hotel]
    local r = GH.Rental(info.hotel, info.room)
    if not h or not r then return nil end
    return Player, info, h, r
end

RegisterNetEvent('grumpy-hotel:server:openStash', function()
    local src = source
    local Player, info, h = insideHost(src, STASH_ROLES)
    if not Player then return end
    -- re-derive the role: a warrant may have expired, a key may have been revoked
    if GH.AccessRole(src, Player, info.hotel, info.room) ~= info.role then
        return GH.Notify(src, locale('no_access'), 'error')
    end
    if not GH.NearInterior(src, h, 10.0) then return GH.Notify(src, locale('too_far'), 'error') end
    exports['rsg-inventory']:OpenInventory(src, GH.StashId(info.hotel, info.room), {
        label = locale('stash_label', h.label, info.room),
        maxweight = Config.Stash.maxweight,
        slots = Config.Stash.slots,
    })
end)

RegisterNetEvent('grumpy-hotel:server:kick', function(target)
    local src = source
    local Player, info = insideHost(src, HOST_ROLES)
    target = math.tointeger(tonumber(target))
    local tInfo = target and GH.Inside[target]
    if not Player or not tInfo or target == src or tInfo.hotel ~= info.hotel or tInfo.room ~= info.room then return end
    -- renter can show out visitors and the key holder; a key holder only visitors; nobody kicks the law
    local allowed = tInfo.role == 'visitor' or (tInfo.role == 'key' and info.role == 'renter')
    if not allowed then return GH.Notify(src, locale('cant_kick'), 'error') end
    GH.RemoveFromRoom(target, { message = locale('you_were_kicked'), ntype = 'error' })
    GH.Notify(src, locale('kicked'), 'success')
    TriggerClientEvent('grumpy-hotel:client:roomRefresh', src)
end)

RegisterNetEvent('grumpy-hotel:server:giveKey', function(target)
    local src = source
    GH.Lock(src, function()
        local Player, info, h, r = insideHost(src, { renter = true })
        target = math.tointeger(tonumber(target))
        local tInfo = target and GH.Inside[target]
        if not Player or not tInfo or target == src or tInfo.hotel ~= info.hotel or tInfo.room ~= info.room then return end
        if r.keyCid then return GH.Notify(src, locale('key_already_given'), 'error') end
        if tInfo.role ~= 'visitor' then return end
        local TPlayer = RSGCore.Functions.GetPlayer(target)
        if not TPlayer then return end
        local name = GH.PlayerName(TPlayer)
        MySQL.update.await('UPDATE grumpy_hotel_rentals SET key_citizenid = ?, key_name = ? WHERE id = ?', { TPlayer.PlayerData.citizenid, name, r.id })
        r.keyCid, r.keyName = TPlayer.PlayerData.citizenid, name
        GH.SetRole(target, 'key')
        GH.Notify(src, locale('key_given', name), 'success')
        GH.Notify(target, locale('key_received', h.label, info.room), 'success')
        TriggerClientEvent('grumpy-hotel:client:roomRefresh', src)
    end)
end)

-- Shared by the room menu and the rental menu
function GH.RevokeKey(src, r)
    if not r.keyCid then return end
    local keySrc = GH.SrcByCid(r.keyCid)
    MySQL.update.await('UPDATE grumpy_hotel_rentals SET key_citizenid = NULL, key_name = NULL WHERE id = ?', { r.id })
    local oldName = r.keyName
    r.keyCid, r.keyName = nil, nil
    GH.Notify(src, locale('key_revoked', oldName or '?'), 'success')
    if keySrc then
        local h = GH.Hotels[r.hotel]
        GH.Notify(keySrc, locale('your_key_revoked', h and h.label or '?', r.room), 'error')
        local kInfo = GH.Inside[keySrc]
        if kInfo and kInfo.hotel == r.hotel and kInfo.room == r.room and kInfo.role == 'key' then
            GH.SetRole(keySrc, 'visitor')
            ejectGuestsIfNoHost(r.hotel, r.room)
        end
    end
end

RegisterNetEvent('grumpy-hotel:server:revokeKey', function()
    local src = source
    GH.Lock(src, function()
        local Player, _, _, r = insideHost(src, { renter = true })
        if not Player then return end
        GH.RevokeKey(src, r)
        TriggerClientEvent('grumpy-hotel:client:roomRefresh', src)
    end)
end)

---------------------------------------------------------------------
-- Death: out of the instance and to the door so medics can reach them
---------------------------------------------------------------------
RegisterNetEvent('grumpy-hotel:server:died', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not GH.Inside[src] then return end
    local ped = GetPlayerPed(src)
    local dead = (Player.PlayerData.metadata or {}).isdead or (ped ~= 0 and GetEntityHealth(ped) <= 0)
    if not dead then return end
    GH.RemoveFromRoom(src)
end)

---------------------------------------------------------------------
-- Logout / crash / restart
---------------------------------------------------------------------
local function resolveRestore(src)
    local row = pendingRestore[src]
    pendingRestore[src] = nil
    if not row then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local h = GH.Hotels[row.hotel]
    local role = h and GH.AccessRole(src, Player, row.hotel, row.room) or nil
    local nearInterior = h and GH.Near(src, h.interior, Config.RestoreDistance)

    if h and role and nearInterior then
        GH.PutInRoom(src, h.id, row.room, role, true)
        return
    end
    -- no access any more (or spawned elsewhere): back to the open world
    clearOccupant(cid)
    RSGCore.Functions.SetPlayerBucket(src, 0)
    if h and nearInterior then
        TriggerClientEvent('grumpy-hotel:client:left', src, h.door)
        GH.Notify(src, locale('restored_outside'), 'inform')
    end
end

-- Login: put them straight into a private bucket so they never stand in the shared interior in bucket 0
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    local row = GH.Occupants[Player.PlayerData.citizenid]
    if not row or not GH.Hotels[row.hotel] then return end
    pendingRestore[src] = row
    RSGCore.Functions.SetPlayerBucket(src, GH.Bucket(row.hotel, row.room))
    -- safety net if the client never reports that it spawned
    SetTimeout(120000, function() if pendingRestore[src] then resolveRestore(src) end end)
end)

-- Client has finished spawning
RegisterNetEvent('grumpy-hotel:server:spawned', function()
    resolveRestore(source)
end)

local function onGone(src)
    pendingRestore[src] = nil
    if knockByVisitor[src] then
        local k = knocks[knockByVisitor[src]]
        if k then closeKnock(k) end
    end
    for _, k in pairs(knocks) do k.hosts[src] = nil end
    local info = GH.Inside[src]
    if not info then return end
    -- keep the occupant row so they come back into the room on next login
    GH.Inside[src] = nil
    ejectGuestsIfNoHost(info.hotel, info.room)
end

AddEventHandler('playerDropped', function() onGone(source) end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) onGone(src) end)

-- Resource restart: players are still in their room buckets; rebuild Inside from the occupant rows
function GH.AfterLoad()
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local Player = RSGCore.Functions.GetPlayer(src)
        local row = Player and GH.Occupants[Player.PlayerData.citizenid]
        if row and GH.Hotels[row.hotel] and GetPlayerRoutingBucket(src) == GH.Bucket(row.hotel, row.room) then
            local role = row.role == 'visitor' and 'visitor' or GH.AccessRole(src, Player, row.hotel, row.room)
            if role then
                GH.PutInRoom(src, row.hotel, row.room, role, true)
            else
                GH.Inside[src] = { hotel = row.hotel, room = row.room, role = row.role, cid = Player.PlayerData.citizenid }
                GH.RemoveFromRoom(src)
            end
        end
    end
end

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('IsInRoom', function(src)
    local info = GH.Inside[src]
    if not info then return false end
    return true, info.hotel, info.room, info.role
end)

exports('RemoveFromRoom', function(src) GH.RemoveFromRoom(src) end)
