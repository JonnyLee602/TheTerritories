-- Distance-gated spawning of tables, chairs and dealer peds (local entities), seat targets and blips.
local world = {}   -- [id] = { key, obj, chairs = {}, dealer, zones = {}, frozen = {} }
local blips = {}   -- [id] = blip

local function geometryKey(t)
    return ('%s|%d|%.3f|%.3f|%.3f|%.2f|%s|%s'):format(t.model, t.bound and 1 or 0, t.x, t.y, t.z, t.h,
        json.encode(t.seats or {}), json.encode(t.dealer or false))
end

local function deleteEntity(e)
    if e and DoesEntityExist(e) then DeleteEntity(e) end
end

local function despawn(id)
    local w = world[id]
    if not w then return end
    for _, z in ipairs(w.zones) do exports['rsg-target']:removeZone(z, true) end
    for _, c in ipairs(w.chairs) do deleteEntity(c) end
    for _, f in ipairs(w.frozen) do if DoesEntityExist(f) then FreezeEntityPosition(f, false) end end
    for _, hd in ipairs(w.hidden) do RemoveModelHide(hd.x, hd.y, hd.z, hd.r, hd.model, false) end
    for _, c in pairs(w.chipProps or {}) do deleteEntity(c.obj) end
    for _, n in pairs(w.npcPeds or {}) do deleteEntity(n.ped) end
    deleteEntity(w.dealer)
    deleteEntity(w.obj)
    world[id] = nil
end

local function spawnObject(model, x, y, z, heading)
    local hash = GGC.LoadModel(model)
    if not hash then return nil end
    local obj = CreateObject(hash, x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(obj) then return nil end
    -- CreateObject shifts by the model's origin offset; rsg-gizmo's saved coords use none (same as grumpy-pob)
    SetEntityCoordsNoOffset(obj, x, y, z, false, false, false)
    SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
    FreezeEntityPosition(obj, true)
    return obj
end

local function playDealerIdle(ped)
    if Config.Dealer.IdleDict and DoesEntityExist(ped) and GGC.LoadDict(Config.Dealer.IdleDict) then
        TaskPlayAnim(ped, Config.Dealer.IdleDict, Config.Dealer.IdleClip, 8.0, -8.0, -1, Config.Dealer.IdleFlag or 25, 0.0, false, 0, false, 0, false)
    end
end

-- Returns the dealer ped and, when seated, the dealer's chair.
-- Seated (like Nt_Blackjack): a chair on the table's floor, the chair-at-table scenario, then the upper-body dealer
-- idle on top once the scenario has settled. Standing: the dealer offset's z is the ped root.
local function spawnDealer(t)
    local seated = Config.Dealer.Seated
    local off = t.dealer
    local x, y, z, h = Geo.ToWorld(GGC.Origin(t), t.h, seated and { x = off.x, y = off.y, z = 0.0, h = off.h } or off)
    local chair
    if seated and Config.Dealer.Chair then
        chair = spawnObject(Config.Dealer.Chair, x, y, z, h + (Config.Dealer.ChairYaw or 0.0))
    end
    local hash = GGC.LoadModel(Config.Dealer.Model)
    if not hash then return nil, chair end
    local ped = CreatePed(hash, x, y, seated and z or (z - 1.0), h, false, false, 0, 0)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return nil, chair end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION (peds spawn invisible without it)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if seated then
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
        TaskStartScenarioAtPosition(ped, joaat(Config.Seating.Scenario), x, y, z + (t.sitZ or 0.5), h, -1, false, true)
        -- don't layer the idle in the same frame: the scenario needs a moment to set its seated pose
        SetTimeout(500, function() playDealerIdle(ped) end)
    else
        FreezeEntityPosition(ped, true)
        playDealerIdle(ped)
    end
    return ped, chair
end

-- Bound map tables: freeze the world chairs at each seat so players can't knock them away
local function freezeWorldChairs(t, w)
    local objects = GetGamePool('CObject')
    for i = 1, #t.seats do
        local x, y = GGC.SeatWorld(t, i)
        local best, bestDist
        for _, obj in ipairs(objects) do
            if DoesEntityExist(obj) and obj ~= w.obj then
                local c = GetEntityCoords(obj)
                local d = math.sqrt((c.x - x) ^ 2 + (c.y - y) ^ 2)
                if d < Config.Seating.FreezeWorldChairRadius and (not bestDist or d < bestDist) then best, bestDist = obj, d end
            end
        end
        if best then
            FreezeEntityPosition(best, true)
            w.frozen[#w.frozen + 1] = best
        end
    end
end

local function seatOptions(id, i)
    return {
        {
            name = ('grumpy-gambling:sit:%d:%d'):format(id, i),
            icon = 'fa-solid fa-chair',
            label = locale('target_sit'),
            distance = Config.InteractDistance,
            canInteract = function()
                local t = GGC.Tables[id]
                if not t or not t.enabled or GGC.Seat then return false end
                if t.occupied and t.occupied[i] then return false end
                return not IsEntityDead(PlayerPedId())
            end,
            onSelect = function() TriggerServerEvent('grumpy-gambling:server:sit', id, i) end,
        },
    }
end

-- Hide the map's chairs around a placed table (our own spawned chairs are script objects and stay visible)
local function hideMapChairs(t, w)
    local cfg = Config.HideMapChairs
    if not cfg or not cfg.Enabled then return end
    for _, model in ipairs(cfg.Models) do
        local hash = joaat(model)
        CreateModelHideExcludingScriptObjects(t.x, t.y, t.z, cfg.Radius, hash, true)
        w.hidden[#w.hidden + 1] = { x = t.x, y = t.y, z = t.z, r = cfg.Radius, model = hash }
    end
end

-- Chip stacks: one in front of every seat with chips, using the tier's model (Config.ChipStacks)
local function updateChips(t, w)
    w.chipProps = w.chipProps or {}
    local cfg = Config.ChipStacks
    local model = cfg and cfg.Enabled and t.tier and cfg.Models[t.tier] or nil
    for i = 1, #t.seats do
        local want = model and t.chips and t.chips[i] and model or nil
        local have = w.chipProps[i]
        if have and have.model ~= want then
            deleteEntity(have.obj)
            w.chipProps[i], have = nil, nil
        end
        if want and not have then
            local slot = { model = want }       -- claim the seat before loading (loading yields)
            w.chipProps[i] = slot
            local x, y, z, h = GGC.SeatWorld(t, i)
            local fwd = t.chipForward or cfg.Forward
            local a = math.rad(h)
            local obj = spawnObject(want, x - math.sin(a) * fwd, y + math.cos(a) * fwd, z + (t.chipHeight or cfg.Height), h)
            if obj then SetEntityCollision(obj, false, false) end
            if w.chipProps[i] == slot and world[t.id] == w then
                slot.obj = obj
            else
                deleteEntity(obj)                -- the seat changed or the table despawned while loading
            end
        end
    end
end

-- NPC players: a seated local ped in every NPC seat, sitting like a player does
local function updateNpcs(t, w)
    w.npcPeds = w.npcPeds or {}
    for i = 1, #t.seats do
        local want = t.npc and t.npc[i] or nil
        if want == false then want = nil end
        local have = w.npcPeds[i]
        if have and have.model ~= want then
            deleteEntity(have.ped)
            w.npcPeds[i], have = nil, nil
        end
        if want and not have then
            local slot = { model = want }       -- claim the seat before loading (loading yields)
            w.npcPeds[i] = slot
            local x, y, z, h = GGC.SeatWorld(t, i)
            local hash = GGC.LoadModel(want)
            local ped
            if hash then
                ped = CreatePed(hash, x, y, z, h, false, false, 0, 0)
                SetModelAsNoLongerNeeded(hash)
            end
            if ped and DoesEntityExist(ped) and w.npcPeds[i] == slot and world[t.id] == w then
                Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetEntityCollision(ped, false, false)
                FreezeEntityPosition(ped, true)
                TaskStartScenarioAtPosition(ped, joaat(Config.Seating.Scenario), x, y, z + (t.sitZ or 0.5), h, -1, false, true)
                slot.ped = ped
            else
                deleteEntity(ped)
            end
        end
    end
end

local function spawn(t)
    local w = { key = geometryKey(t), chairs = {}, zones = {}, frozen = {}, hidden = {}, chipProps = {}, npcPeds = {} }
    world[t.id] = w
    if not t.bound then
        hideMapChairs(t, w)
        w.obj = spawnObject(t.model, t.x, t.y, t.z, t.h)
        if t.chair then
            for i = 1, #t.seats do
                local x, y, z, h = GGC.SeatWorld(t, i)
                local c = spawnObject(t.chair, x, y, z, h + (t.chairYaw or 0.0))
                if c then w.chairs[#w.chairs + 1] = c end
            end
        end
    else
        freezeWorldChairs(t, w)
    end
    if t.kind == 'pvd' and t.dealer then
        local chair
        w.dealer, chair = spawnDealer(t)
        if chair then w.chairs[#w.chairs + 1] = chair end
    end
    updateChips(t, w)
    updateNpcs(t, w)
    for i = 1, #t.seats do
        local x, y, z = GGC.SeatWorld(t, i)
        w.zones[#w.zones + 1] = exports['rsg-target']:addSphereZone({
            coords = vector3(x, y, z + (t.sitZ or 0.5) + 0.1),
            radius = Config.SeatZoneRadius,
            debug = Config.Debug,
            options = seatOptions(t.id, i),
        })
    end
end

---------------------------------------------------------------------
-- Blips: enabled cash tables only (back-room bloodmoney tables stay off the map)
---------------------------------------------------------------------
local function removeBlip(id)
    if blips[id] then RemoveBlip(blips[id]); blips[id] = nil end
end

local function updateBlip(t)
    removeBlip(t.id)
    if not Config.Blips.Enabled or not t.enabled or t.currency ~= 'cash' then return end
    local blip = BlipAddForCoords(Config.Blips.Style, t.x, t.y, t.z)
    SetBlipSprite(blip, joaat(Config.Blips.Sprites[t.kind] or Config.Blips.Sprites.pvp), true)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, t.label) -- _SET_BLIP_NAME
    blips[t.id] = blip
end

AddEventHandler('grumpy-gambling:client:tableChanged', function(id)
    local t = GGC.Tables[id]
    if not t then return end
    updateBlip(t)
    -- chip stacks follow buy-ins, busts and cash-outs (only for tables spawned near us, same geometry)
    local w = world[id]
    if w and w.key == geometryKey(t) then CreateThread(function() updateChips(t, w); updateNpcs(t, w) end) end
end)

AddEventHandler('grumpy-gambling:client:tableRemoved', function(id)
    despawn(id)
    removeBlip(id)
end)

---------------------------------------------------------------------
-- Spawn loop
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 2000
        local pos = GetEntityCoords(PlayerPedId())
        for id, t in pairs(GGC.Tables) do
            local near = #(pos - vector3(t.x, t.y, t.z)) < Config.SpawnDistance
            local w = world[id]
            if near then
                sleep = 1000
                if w and w.key ~= geometryKey(t) then
                    despawn(id)
                    w = nil
                end
                if not w then spawn(t) end
            elseif w then
                despawn(id)
            end
        end
        Wait(sleep)
    end
end)

-- Admin tools need the spawned table entity (move with rsg-gizmo)
function GGC.TableEntity(id)
    local w = world[id]
    return w and w.obj or nil
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(world) do despawn(id) end
    for id in pairs(blips) do removeBlip(id) end
end)
