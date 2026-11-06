local RSGCore = exports['rsg-core']:GetCoreObject()

-- Rooms[id] = { id, name, model, npc = {x,y,z,w}, doors = {doorlockId,...}, zone = {points, minZ, maxZ},
--               exit = {x,y,z,w}, enabled, openUntil (os.time, 0 = closed), warned = { [seconds] = true } }
local Rooms = {}
local ready = false
local lastAct = {}
local quoteFor -- defined with the bribe below

---------------------------------------------
-- helpers
---------------------------------------------
local function notify(src, key, ntype, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('title'),
        description = locale(key, ...),
        type = ntype or 'error',
        duration = 6000,
    })
end

local function dbg(...)
    if Config.Debug then print('[grumpy-backroom] ' .. string.format(...)) end
end

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function money(n) return ('%.2f'):format(n) end

local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function cooldown(src, ms)
    local now = GetGameTimer()
    if lastAct[src] and now - lastAct[src] < ms then return true end
    lastAct[src] = now
    return false
end

-- a room the players can use: enabled and fully set up
local function usable(room)
    return room.enabled and room.npc ~= nil and room.exit ~= nil and #room.doors > 0 and BackroomZone.Valid(room.zone)
end

local function timeLeft(room)
    return math.max(0, (room.openUntil or 0) - os.time())
end

-- what clients need: the doorman and the zone (no timers, no door ids)
local function publish()
    local list = {}
    for id, r in pairs(Rooms) do
        if usable(r) then
            list[#list + 1] = { id = id, name = r.name, model = r.model, npc = r.npc, zone = r.zone }
        end
    end
    GlobalState.grumpyBackrooms = list
end

local function rowToRoom(row)
    return {
        id = row.id,
        name = row.name,
        model = row.npc_model,
        npc = row.npc and json.decode(row.npc) or nil,
        doors = json.decode(row.doors or '[]') or {},
        zone = row.zone and json.decode(row.zone) or nil,
        exit = row.exit_point and json.decode(row.exit_point) or nil,
        enabled = row.enabled == 1 or row.enabled == true,
        openUntil = tonumber(row.open_until) or 0,
        warned = {},
    }
end

---------------------------------------------
-- doors (rsg-doorlock)
-- rsg-doorlock has no export of its own to lock a door from another resource; the [grumpy-backroom hook]
-- adds SetDoorState (integrations/rsg-doorlock.md). Without it we fall back to telling the clients directly,
-- which works for everyone online but late joiners see the saved (locked) state.
---------------------------------------------
local hookWarned = false
local function setDoor(id, locked)
    local ok, res = pcall(function() return exports['rsg-doorlock']:SetDoorState(id, locked) end)
    if ok and res ~= nil then return res == true end
    if not hookWarned then
        hookWarned = true
        print('^3[grumpy-backroom] rsg-doorlock has no SetDoorState export: add the hook from integrations/rsg-doorlock.md. Falling back to client sync.^7')
    end
    TriggerClientEvent('rsg-doorlock:client:setState', -1, id, locked)
    return true
end

-- rsg-doorlock may still be loading its database: retry for a while
local function setDoors(room, locked, doors)
    local pending = {}
    for _, id in ipairs(doors or room.doors) do pending[#pending + 1] = id end
    CreateThread(function()
        for _ = 1, 30 do
            for i = #pending, 1, -1 do
                if setDoor(pending[i], locked) then table.remove(pending, i) end
            end
            if #pending == 0 then return end
            Wait(1000)
        end
        print(('[grumpy-backroom] room #%d: rsg-doorlock doors %s not found'):format(room.id, json.encode(pending)))
    end)
end

---------------------------------------------
-- who is inside
---------------------------------------------
local function exempt(src)
    if Config.Exempt.admins and isAdmin(src) then return true end
    if #Config.Exempt.jobs > 0 then
        local Player = RSGCore.Functions.GetPlayer(src)
        local job = Player and Player.PlayerData.job
        if job then
            for _, name in ipairs(Config.Exempt.jobs) do
                if name == job.name then return true end
            end
        end
    end
    return false
end

local function playersInside(room, includeExempt)
    local list = {}
    if not BackroomZone.Valid(room.zone) then return list end
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and BackroomZone.Contains(room.zone, GetEntityCoords(ped)) then
            if includeExempt or not exempt(src) then list[#list + 1] = src end
        end
    end
    return list
end

local function showOut(room, src)
    if Config.StandFromTables and GetResourceState('grumpy-gambling') == 'started' then
        pcall(function() exports['grumpy-gambling']:StandPlayer(src) end)
    end
    TriggerClientEvent('grumpy-backroom:client:showOut', src, room.exit)
end

-- last resort: the client didn't move (or ignored the event), the server puts the ped outside
local function forceOut(room, src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local e = room.exit
    SetEntityCoords(ped, e.x + 0.0, e.y + 0.0, e.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, (e.w or 0.0) + 0.0)
    print(('[grumpy-backroom] room #%d: %s (%d) was still inside after closing, moved out by the server'):format(room.id, GetPlayerName(src) or '?', src))
end

---------------------------------------------
-- open / close
---------------------------------------------
local function saveOpenUntil(room)
    MySQL.update('UPDATE grumpy_backroom_rooms SET open_until = ? WHERE id = ?', { room.openUntil or 0, room.id })
end

local function openRoom(room, seconds)
    local wasOpen = timeLeft(room) > 0
    room.openUntil = math.max(os.time(), room.openUntil or 0) + seconds
    room.warned = {}
    saveOpenUntil(room)
    if not wasOpen then setDoors(room, false) end
    dbg('room #%d open for %ds', room.id, timeLeft(room))
end

local function closeRoom(room, why)
    room.openUntil = 0
    room.warned = {}
    saveOpenUntil(room)
    if room.exit then
        for _, src in ipairs(playersInside(room)) do
            showOut(room, src)
            notify(src, why or 'shown_out', 'inform')
        end
    end
    SetTimeout(Config.LockDelay, function()
        if timeLeft(room) == 0 then setDoors(room, true) end
    end)
    if room.exit then
        for _, ms in ipairs(Config.SweepAfter) do
            SetTimeout(ms, function()
                if timeLeft(room) > 0 then return end -- someone paid again in the meantime
                for _, src in ipairs(playersInside(room)) do forceOut(room, src) end
            end)
        end
    end
    dbg('room #%d closed', room.id)
end

-- one ticker for every room: warnings, then closing time
CreateThread(function()
    while true do
        Wait(1000)
        if ready then
            for _, room in pairs(Rooms) do
                if (room.openUntil or 0) > 0 then
                    local left = timeLeft(room)
                    if left <= 0 then
                        closeRoom(room)
                    else
                        for _, at in ipairs(Config.WarnAt) do
                            if left <= at and not room.warned[at] then
                                room.warned[at] = true
                                for _, src in ipairs(playersInside(room, true)) do
                                    if Config.Reup.Enabled then
                                        TriggerClientEvent('grumpy-backroom:client:reup', src, quoteFor(src, room))
                                    elseif at >= 60 then
                                        notify(src, 'warn_minutes', 'inform', math.floor(left / 60 + 0.5))
                                    else
                                        notify(src, 'warn_seconds', 'error', left)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

---------------------------------------------
-- database bootstrap
---------------------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `grumpy_backroom_rooms` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(48) NOT NULL,
            `npc_model` VARCHAR(64) NOT NULL,
            `npc` LONGTEXT NULL,
            `doors` LONGTEXT NOT NULL,
            `zone` LONGTEXT NULL,
            `exit_point` LONGTEXT NULL,
            `enabled` TINYINT(1) NOT NULL DEFAULT 0,
            `open_until` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    for _, row in ipairs(MySQL.query.await('SELECT * FROM grumpy_backroom_rooms') or {}) do
        Rooms[row.id] = rowToRoom(row)
    end
    ready = true
    publish()
    -- put every door in the right state (a restart keeps paid time; rooms whose time ran out while down are closed)
    for _, room in pairs(Rooms) do
        if #room.doors > 0 then
            if timeLeft(room) > 0 and usable(room) then setDoors(room, false) else
                if (room.openUntil or 0) > 0 then room.openUntil = 0 saveOpenUntil(room) end
                setDoors(room, true)
            end
        end
    end
end)

-- rsg-doorlock restarted: it reloads the saved (locked) state, so open rooms unlock again
AddEventHandler('onResourceStart', function(res)
    if res ~= 'rsg-doorlock' then return end
    SetTimeout(3000, function()
        for _, room in pairs(Rooms) do
            if timeLeft(room) > 0 then setDoors(room, false) end
        end
    end)
end)

---------------------------------------------
-- the bribe
---------------------------------------------
local function lawBlocked(Player)
    if not Config.BlockLaw then return false end
    local job = Player.PlayerData.job or {}
    return job.type == 'leo' and job.onduty == true
end

local function standingMult(src)
    if not Config.StandingScales or GetResourceState('grumpy-reputation') ~= 'started' then return 1.0 end
    local ok, m = pcall(function() return exports['grumpy-reputation']:GetPriceMultiplier(src, 'underground', 'buy') end)
    m = ok and tonumber(m) or 1.0
    if m ~= m or m <= 0 then return 1.0 end
    return m
end

local function nearNpc(src, room)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not room.npc then return false end
    local n = room.npc
    return #(GetEntityCoords(ped) - vector3(n.x, n.y, n.z)) <= Config.InteractDistance + Config.DistanceTolerance
end

-- the whole price comes from the first money type in the list the player can cover
local function charge(Player, price)
    for _, mt in ipairs(Config.PayWith) do
        if (tonumber(Player.PlayerData.money[mt]) or 0) >= price and Player.Functions.RemoveMoney(mt, price, Config.MoneyReason) then
            return mt
        end
    end
end

-- prices for this player (× their standing) and what still fits under MaxOpenMinutes
quoteFor = function(src, room)
    local mult = standingMult(src)
    local left = timeLeft(room)
    local options = {}
    for i, b in ipairs(Config.Bribes) do
        options[i] = { minutes = b.minutes, price = money(round2(b.price * mult)),
                       fits = left + b.minutes * 60 <= Config.MaxOpenMinutes * 60 }
    end
    return { id = room.id, name = room.name, left = left, max = Config.MaxOpenMinutes * 60, options = options }
end

RSGCore.Functions.CreateCallback('grumpy-backroom:server:quote', function(src, cb, roomId)
    local room = ready and Rooms[tonumber(roomId) or -1]
    if not room or not usable(room) then return cb(nil) end
    cb(quoteFor(src, room))
end)

-- shared by the doorman (outside) and the re-up panel (inside); the caller checks where the player is
local function pay(src, Player, room, bribe, isReup)
    local meta = Player.PlayerData.metadata or {}
    if meta.isdead or meta.ishandcuffed then return false end
    if lawBlocked(Player) then notify(src, 'law_blocked') return false end

    local left = timeLeft(room)
    if isReup and left <= 0 then notify(src, 'reup_too_late') return false end
    if left + bribe.minutes * 60 > Config.MaxOpenMinutes * 60 then
        notify(src, 'too_long', 'error', math.floor(left / 60))
        return false
    end

    local price = round2(bribe.price * standingMult(src))
    local paidWith = price <= 0 and 'free' or charge(Player, price)
    if not paidWith then notify(src, 'no_money', 'error', money(price)) return false end

    openRoom(room, bribe.minutes * 60)
    local total = math.floor(timeLeft(room) / 60)
    notify(src, left > 0 and 'paid_extend' or 'paid_open', 'success', money(price), bribe.minutes, total)
    print(('[grumpy-backroom] %s (%s) paid $%s %s for %d min in "%s" (#%d)%s'):format(GetPlayerName(src) or '?',
        Player.PlayerData.citizenid, money(price), paidWith, bribe.minutes, room.name, room.id, isReup and ' (re-up from inside)' or ''))

    -- everyone else inside: close their panel and tell them who kept the room
    local name = Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname or GetPlayerName(src) or '?'
    for _, other in ipairs(playersInside(room, true)) do
        TriggerClientEvent('grumpy-backroom:client:reupDone', other, room.id)
        if other ~= src and left > 0 then notify(other, 'reup_by_other', 'success', name, bribe.minutes, total) end
    end
    return true
end

local function bribeFrom(src, roomId, choice)
    if not ready or cooldown(src, 2000) then return end
    local room = Rooms[tonumber(roomId) or -1]
    local bribe = Config.Bribes[tonumber(choice) or -1]
    if not room or not usable(room) or not bribe then return end
    return room, bribe, RSGCore.Functions.GetPlayer(src)
end

-- at the doorman
RegisterNetEvent('grumpy-backroom:server:bribe', function(roomId, choice)
    local src = source
    local room, bribe, Player = bribeFrom(src, roomId, choice)
    if not Player then return end
    if not nearNpc(src, room) then return notify(src, 'too_far') end
    pay(src, Player, room, bribe, false)
end)

-- from inside the room (the closing-time panel)
RegisterNetEvent('grumpy-backroom:server:reup', function(roomId, choice)
    local src = source
    if not Config.Reup.Enabled then return end
    local room, bribe, Player = bribeFrom(src, roomId, choice)
    if not Player then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not BackroomZone.Contains(room.zone, GetEntityCoords(ped)) then
        return notify(src, 'reup_not_inside')
    end
    pay(src, Player, room, bribe, true)
end)

-- the client asks when it walks into a room, to show how long is left
RSGCore.Functions.CreateCallback('grumpy-backroom:server:timeLeft', function(_, cb, roomId)
    local room = Rooms[tonumber(roomId) or -1]
    cb(room and timeLeft(room) or 0)
end)

---------------------------------------------
-- admin
---------------------------------------------
RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_help'), {}, false, function(source)
    TriggerClientEvent('grumpy-backroom:client:openAdmin', source)
end, Config.AdminPermission)

local function adminList()
    local list = {}
    for id, r in pairs(Rooms) do
        list[#list + 1] = {
            id = id, name = r.name, model = r.model, npc = r.npc, doors = r.doors, zone = r.zone, exit = r.exit,
            enabled = r.enabled, usable = usable(r), left = timeLeft(r),
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

RSGCore.Functions.CreateCallback('grumpy-backroom:server:adminRooms', function(src, cb)
    if not isAdmin(src) then return cb(nil) end
    cb(adminList())
end)

-- finite number inside the map bounds (rejects NaN / inf / absurd values)
local function num(n)
    return type(n) == 'number' and n == n and math.abs(n) < 20000.0
end

local function point(p, withHeading)
    if type(p) ~= 'table' or not num(p.x) or not num(p.y) or not num(p.z) then return nil end
    local w = tonumber(p.w) or 0.0
    if w ~= w then w = 0.0 end
    return { x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0, w = withHeading and (w % 360.0) or nil }
end

-- validates a room from the editor; returns room or nil, errorKey
local function sanitise(d)
    if type(d) ~= 'table' then return nil, 'err_invalid' end
    local name = type(d.name) == 'string' and d.name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #name < 1 or #name > 48 then return nil, 'err_name' end
    local model = type(d.model) == 'string' and d.model or Config.Npc.model
    if not model:match('^[%w_]+$') or #model > 64 then return nil, 'err_model' end

    local doors, seen = {}, {}
    if type(d.doors) == 'table' then
        for _, id in ipairs(d.doors) do
            id = math.tointeger(id)
            if not id then return nil, 'err_invalid' end
            if not seen[id] then seen[id] = true doors[#doors + 1] = id end
        end
    end
    if #doors > Config.MaxDoors then return nil, 'err_doors' end

    local zone
    if type(d.zone) == 'table' and type(d.zone.points) == 'table' and #d.zone.points > 0 then
        local z = d.zone
        if #z.points < 3 or #z.points > Config.Zone.MaxCorners then return nil, 'err_zone' end
        if not num(z.minZ) or not num(z.maxZ) or z.maxZ <= z.minZ or z.maxZ - z.minZ > Config.Zone.MaxHeight + 2 then
            return nil, 'err_zone'
        end
        local pts = {}
        for i, p in ipairs(z.points) do
            if type(p) ~= 'table' or not num(p.x) or not num(p.y) then return nil, 'err_zone' end
            pts[i] = { x = p.x + 0.0, y = p.y + 0.0 }
        end
        zone = { points = pts, minZ = z.minZ + 0.0, maxZ = z.maxZ + 0.0 }
    end

    local room = {
        name = name, model = model, doors = doors, zone = zone,
        npc = d.npc and point(d.npc, true) or nil,
        exit = d.exit and point(d.exit, true) or nil,
        enabled = d.enabled == true,
    }
    if (d.npc and not room.npc) or (d.exit and not room.exit) then return nil, 'err_invalid' end
    if room.enabled and not usable(room) then return nil, 'err_incomplete' end
    if room.exit and zone and BackroomZone.Contains(zone, room.exit) then return nil, 'err_exit_inside' end
    return room
end

local function encode(v) return v and json.encode(v) or nil end

RSGCore.Functions.CreateCallback('grumpy-backroom:server:adminSave', function(src, cb, data)
    if not isAdmin(src) then return cb(false, 'err_perm') end
    local room, err = sanitise(data)
    if not room then return cb(false, err) end
    local id = tonumber(type(data) == 'table' and data.id)
    local old = id and Rooms[id]
    if id and not old then return cb(false, 'err_invalid') end

    local params = { room.name, room.model, encode(room.npc), json.encode(room.doors), encode(room.zone), encode(room.exit), room.enabled and 1 or 0 }
    if old then
        params[#params + 1] = id
        MySQL.update.await('UPDATE grumpy_backroom_rooms SET name = ?, npc_model = ?, npc = ?, doors = ?, zone = ?, exit_point = ?, enabled = ? WHERE id = ?', params)
    else
        id = MySQL.insert.await('INSERT INTO grumpy_backroom_rooms (name, npc_model, npc, doors, zone, exit_point, enabled) VALUES (?, ?, ?, ?, ?, ?, ?)', params)
        if not id then return cb(false, 'err_invalid') end
    end

    room.id = id
    room.openUntil = old and old.openUntil or 0
    room.warned = old and old.warned or {}
    Rooms[id] = room

    -- doors taken off the room lock again; new doors follow the room's state
    if old then
        local keep = {}
        for _, d in ipairs(room.doors) do keep[d] = true end
        local dropped = {}
        for _, d in ipairs(old.doors) do if not keep[d] then dropped[#dropped + 1] = d end end
        if #dropped > 0 then setDoors(room, true, dropped) end
    end
    if timeLeft(room) > 0 then
        if usable(room) then setDoors(room, false) else closeRoom(room, 'closed_by_admin') end
    elseif #room.doors > 0 then
        setDoors(room, true)
    end

    publish()
    print(('[grumpy-backroom] %s (%s) saved room #%d "%s"'):format(GetPlayerName(src) or '?', src, id, room.name))
    cb(true, id)
end)

RSGCore.Functions.CreateCallback('grumpy-backroom:server:adminDelete', function(src, cb, id)
    if not isAdmin(src) then return cb(false) end
    local room = Rooms[tonumber(id) or -1]
    if not room then return cb(false) end
    if timeLeft(room) > 0 then closeRoom(room, 'closed_by_admin') end
    MySQL.query.await('DELETE FROM grumpy_backroom_rooms WHERE id = ?', { room.id })
    Rooms[room.id] = nil
    publish()
    print(('[grumpy-backroom] %s (%s) deleted room #%d "%s"'):format(GetPlayerName(src) or '?', src, room.id, room.name))
    cb(true)
end)

-- open free for a test, or close now (shows everyone out)
RSGCore.Functions.CreateCallback('grumpy-backroom:server:adminSetOpen', function(src, cb, id, open)
    if not isAdmin(src) then return cb(false) end
    local room = Rooms[tonumber(id) or -1]
    if not room then return cb(false) end
    if open then
        if not usable(room) then return cb(false, 'err_incomplete') end
        openRoom(room, Config.TestSeconds)
    else
        closeRoom(room, 'closed_by_admin')
    end
    cb(true)
end)

AddEventHandler('playerDropped', function()
    lastAct[source] = nil
end)

---------------------------------------------
-- exports
---------------------------------------------
exports('GetTimeLeft', function(id)
    local room = Rooms[tonumber(id) or -1]
    return room and timeLeft(room) or 0
end)

exports('OpenRoom', function(id, seconds)
    local room = Rooms[tonumber(id) or -1]
    seconds = math.tointeger(seconds)
    if not room or not usable(room) or not seconds or seconds <= 0 then return false end
    openRoom(room, seconds)
    return true
end)

exports('CloseRoom', function(id)
    local room = Rooms[tonumber(id) or -1]
    if not room then return false end
    closeRoom(room, 'closed_by_admin')
    return true
end)

exports('IsInside', function(src, id)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    for rid, room in pairs(Rooms) do
        if (not id or rid == tonumber(id)) and BackroomZone.Contains(room.zone, c) then return true, rid end
    end
    return false
end)
