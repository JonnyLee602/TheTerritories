-- /gambling admin panel: create (rsg-gizmo or bind a map table), move, calibrate, rename, enable, delete, teleport.
local RSGCore = GGC.Core

local function fetch()
    return RSGCore.Functions.AwaitCallback('grumpy-gambling:server:adminData', 10000)
end

RegisterNetEvent('grumpy-gambling:client:openAdmin', function()
    local data = fetch()
    if not data then return end
    GGC.OpenUI('admin', data)
end)

RegisterNetEvent('grumpy-gambling:client:adminRefresh', function()
    if GGC.uiOpen ~= 'admin' then return end
    local data = fetch()
    if data then GGC.UpdateUI('admin', data) end
end)

RegisterNetEvent('grumpy-gambling:client:calibrated', function(snippet)
    if GGC.uiOpen ~= 'admin' then return end
    SendNUIMessage({ action = 'snippet', text = snippet })
end)

RegisterNetEvent('grumpy-gambling:client:teleport', function(x, y, z)
    local ped = PlayerPedId()
    SetEntityCoords(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
end)

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local busy = false

-- Runs fn in a thread with the UI hidden; brings the UI back afterwards
local function withGizmo(fn)
    if busy or exports['rsg-gizmo']:IsActive() then return end
    busy = true
    GGC.HideUI()
    CreateThread(function()
        local ok, err = pcall(fn)
        if not ok then print('^1[grumpy-gambling] ' .. tostring(err) .. '^7') end
        busy = false
        GGC.ShowUI()
    end)
end

local function v(c) return { x = c.x, y = c.y, z = c.z } end

-- Nearest world (map) table of a kind around the player, skipping our own spawned tables
local function findWorldTable(kind)
    local pos = GetEntityCoords(PlayerPedId())
    local wanted = {}
    for name, m in pairs(Models) do if m.kind == kind then wanted[joaat(name)] = name end end
    local ours = {}
    for id in pairs(GGC.Tables) do
        local e = GGC.TableEntity(id)
        if e then ours[e] = true end
    end
    local best, bestDist, bestName
    local nearby = {}
    for _, obj in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(obj) and not ours[obj] then
            local d = #(GetEntityCoords(obj) - pos)
            if d <= Config.BindSearchRadius then
                local hash = GetEntityModel(obj)
                local name = wanted[hash]
                if name and (not bestDist or d < bestDist) then best, bestDist, bestName = obj, d, name end
                nearby[#nearby + 1] = ('%d (0x%X) at %.1fm'):format(hash, hash & 0xFFFFFFFF, d)
            end
        end
    end
    if not best then
        -- help the admin add a profile for a table model we don't know yet
        print('[grumpy-gambling] no known table model nearby. Objects within range (model hash):')
        for _, line in ipairs(nearby) do print('  ' .. line) end
    end
    return best, bestName
end

-- The map's own chairs around a table (the profile's chair, else its ghostChair), for autoChairs
local function mapChairs(name, centre)
    local prof = Models[name]
    local auto = prof.autoChairs
    local chairModel = prof.chair or prof.ghostChair
    if not auto or not chairModel then return nil end
    local chairHash = joaat(chairModel)
    local chairs = {}
    for _, o in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(o) and GetEntityModel(o) == chairHash then
            local c = GetEntityCoords(o)
            if #(vector2(c.x, c.y) - vector2(centre.x, centre.y)) <= auto.radius and #chairs < 12 then
                chairs[#chairs + 1] = v(c)
            end
        end
    end
    return chairs
end

---------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------
RegisterNUICallback('adminCreate', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    local base = {
        label = body.label, kind = body.kind, source = body.source, currency = body.currency, model = body.model,
    }
    if body.mode == 'bind' then
        local obj, name = findWorldTable(body.kind)
        if obj then
            base.model = name
            base.bound = true
            base.coords = v(GetEntityCoords(obj))
            base.heading = GetEntityHeading(obj)
            -- the map's own chairs around the table become the seats (the server works out their facing)
            base.chairs = mapChairs(name, GetEntityCoords(obj))
            TriggerServerEvent('grumpy-gambling:server:adminCreate', base)
            return
        end
        -- Some map tables are built into the interior and are not objects the game lists (Blackwater saloon's
        -- blackjack table). Then the admin lines up a see-through copy of the chosen model over it by hand; the
        -- table is saved as a map table (nothing is spawned) and the map chairs around it become the seats.
        if type(body.model) ~= 'string' or not Models[body.model] or Models[body.model].kind ~= body.kind then
            return GGC.Notify(locale('admin_no_world_table'), 'error')
        end
        GGC.Notify(locale('admin_bind_by_hand'), 'inform')
        -- Start on the floor in fine mode (arrows slide it, the wheel sets height): free mode follows the camera ray
        -- and would sit the copy on top of the real table. The floor height comes from the nearest map chair
        -- (chair models have their origin on the floor), else from the player's feet.
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local fwd = GetEntityForwardVector(ped)
        local floorZ = pos.z - 1.0
        local chairModel = Models[body.model].chair or Models[body.model].ghostChair
        if chairModel then
            local chair = GetClosestObjectOfType(pos.x, pos.y, pos.z, 4.0, joaat(chairModel), false, false, false)
            if chair and chair ~= 0 then floorZ = GetEntityCoords(chair).z end
        end
        withGizmo(function()
            local res = exports['rsg-gizmo']:Place(body.model, {
                title = locale('admin_bind_by_hand_title'), maxDistance = Config.PlaceDistance, rotation = 'z',
                allowInterior = true, allowWater = true, snapToGround = false, startMode = 'fine',
                startCoords = vector3(pos.x + fwd.x * 1.5, pos.y + fwd.y * 1.5, floorZ),
                startRotation = vector3(0.0, 0.0, GetEntityHeading(ped)),
            })
            if not res then return end
            base.bound = true
            base.coords = v(res.coords)
            base.heading = res.heading or res.rotation.z
            base.chairs = mapChairs(body.model, res.coords)
            TriggerServerEvent('grumpy-gambling:server:adminCreate', base)
        end)
        return
    end
    if type(body.model) ~= 'string' or not Models[body.model] then return end
    withGizmo(function()
        local res = exports['rsg-gizmo']:Place(body.model, {
            title = locale('admin_place_title'), maxDistance = Config.PlaceDistance, rotation = 'z', allowInterior = true, allowWater = true,
        })
        if not res then return end
        base.bound = false
        base.coords = v(res.coords)
        base.heading = res.heading or res.rotation.z
        TriggerServerEvent('grumpy-gambling:server:adminCreate', base)
    end)
end)

RegisterNUICallback('adminMove', function(body, cb)
    cb('ok')
    local id = type(body) == 'table' and tonumber(body.id)
    local t = id and GGC.Tables[id]
    if not t then return end
    if t.bound then return GGC.Notify(locale('admin_bound_no_move'), 'error') end
    local ent = GGC.TableEntity(id)
    if not ent then return GGC.Notify(locale('admin_go_near'), 'error') end
    withGizmo(function()
        local res = exports['rsg-gizmo']:Edit(ent, { maxDistance = Config.PlaceDistance, rotation = 'z', allowInterior = true, allowWater = true })
        if not res then return end
        TriggerServerEvent('grumpy-gambling:server:adminMove', id, v(res.coords), res.heading or res.rotation.z)
    end)
end)

-- Place a ghost chair on every seat (and the dealer), then send the world positions to the server
RegisterNUICallback('adminCalibrate', function(body, cb)
    cb('ok')
    local id = type(body) == 'table' and tonumber(body.id)
    local t = id and GGC.Tables[id]
    if not t then return end
    if #(GetEntityCoords(PlayerPedId()) - vector3(t.x, t.y, t.z)) > 15.0 then return GGC.Notify(locale('admin_go_near'), 'error') end
    local scope = body.scope == 'model' and 'model' or 'table'
    local profile = Models[t.model] or {}
    local chairModel = t.chair or profile.ghostChair or 'p_windsorchair03x'
    withGizmo(function()
        local seats = {}
        for i = 1, #t.seats do
            local x, y, z, h = GGC.SeatWorld(t, i)
            local res = exports['rsg-gizmo']:Place(chairModel, {
                title = locale('admin_calibrate_seat', i, #t.seats),
                startCoords = vector3(x, y, z), startRotation = vector3(0.0, 0.0, h + (t.chairYaw or 0.0)),
                startMode = 'fine', maxDistance = 8.0, rotation = 'z', allowInterior = true, allowWater = true,
            })
            if not res then return GGC.Notify(locale('admin_calibrate_cancelled'), 'inform') end
            seats[i] = { x = res.coords.x, y = res.coords.y, z = res.coords.z, h = res.heading or res.rotation.z }
        end
        local dealer
        if t.kind == 'pvd' then
            local off = t.dealer or { x = 0.0, y = 0.6, z = 1.0, h = 180.0 }
            if Config.Dealer.Seated and Config.Dealer.Chair then
                -- seated dealer: place his chair (a prop, so Place() is fine); the server faces it at the table
                local x, y, z, h = Geo.ToWorld(GGC.Origin(t), t.h, { x = off.x, y = off.y, z = 0.0, h = off.h })
                local res = exports['rsg-gizmo']:Place(Config.Dealer.Chair, {
                    title = locale('admin_calibrate_dealer'),
                    startCoords = vector3(x, y, z), startRotation = vector3(0.0, 0.0, h + (Config.Dealer.ChairYaw or 0.0)),
                    startMode = 'fine', maxDistance = 8.0, rotation = 'z', allowInterior = true, allowWater = true,
                })
                if not res then return GGC.Notify(locale('admin_calibrate_cancelled'), 'inform') end
                TriggerServerEvent('grumpy-gambling:server:adminCalibrate', id, {
                    seats = seats, scope = scope,
                    dealer = { x = res.coords.x, y = res.coords.y, z = res.coords.z, h = res.heading or res.rotation.z },
                })
                return
            end
            local x, y, z, h = Geo.ToWorld(GGC.Origin(t), t.h, off)
            -- rsg-gizmo's Place() only spawns props (CreateObject crashes on a ped model), so like grumpy-pob a
            -- local ghost ped is spawned and moved with Edit(). Edit returns the ped's root (standing) coords.
            local hash = GGC.LoadModel(Config.Dealer.Model)
            if not hash or not IsModelAPed(hash) then return GGC.Notify(locale('admin_calibrate_cancelled'), 'error') end
            local ghost = CreatePed(hash, x, y, z, h, false, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            if not ghost or ghost == 0 then return GGC.Notify(locale('admin_calibrate_cancelled'), 'error') end
            Citizen.InvokeNative(0x283978A15512B2FE, ghost, true) -- _SET_RANDOM_OUTFIT_VARIATION (else invisible)
            SetEntityInvincible(ghost, true)
            SetBlockingOfNonTemporaryEvents(ghost, true)
            FreezeEntityPosition(ghost, true)
            local res = exports['rsg-gizmo']:Edit(ghost, {
                title = locale('admin_calibrate_dealer'),
                startMode = 'fine', maxDistance = 8.0, rotation = 'z', allowInterior = true, allowWater = true,
            })
            if DoesEntityExist(ghost) then DeleteEntity(ghost) end
            if not res then return GGC.Notify(locale('admin_calibrate_cancelled'), 'inform') end
            dealer = { x = res.coords.x, y = res.coords.y, z = res.coords.z, h = res.heading or res.rotation.z }
        end
        TriggerServerEvent('grumpy-gambling:server:adminCalibrate', id, { seats = seats, dealer = dealer, scope = scope })
    end)
end)

local function simple(name, event, withArg)
    RegisterNUICallback(name, function(body, cb)
        cb('ok')
        local id = type(body) == 'table' and tonumber(body.id)
        if not id then return end
        if withArg then TriggerServerEvent(event, id, body[withArg]) else TriggerServerEvent(event, id) end
    end)
end

simple('adminRename', 'grumpy-gambling:server:adminRename', 'label')
simple('adminToggle', 'grumpy-gambling:server:adminToggle')
simple('adminDelete', 'grumpy-gambling:server:adminDelete')
simple('adminTeleport', 'grumpy-gambling:server:adminTeleport')
simple('adminResetCalibration', 'grumpy-gambling:server:adminResetCalibration', 'scope')
