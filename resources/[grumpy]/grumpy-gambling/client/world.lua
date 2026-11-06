-- Distance-gated spawning of tables, chairs and dealer peds (local entities), seat targets and blips.
local RSGCore = exports['rsg-core']:GetCoreObject()
local world = {}   -- [id] = { key, obj, chairs = {}, dealer, zones = {}, frozen = {} }
local blips = {}   -- [id] = blip

local function geometryKey(t)
    return ('%s|%d|%.3f|%.3f|%.3f|%.2f|%s|%s'):format(t.model, t.bound and 1 or 0, t.x, t.y, t.z, t.h,
        json.encode(t.seats or {}), json.encode(t.dealer or false))
end

local function deleteEntity(e)
    if e and DoesEntityExist(e) then
        SetEntityAsMissionEntity(e, true, true) -- ours to delete, whatever the game thinks
        DeleteEntity(e)
    end
end

local function despawn(id)
    local w = world[id]
    if not w then return end
    for _, z in ipairs(w.zones) do exports['rsg-target']:removeZone(z, true) end
    for _, c in ipairs(w.chairs) do deleteEntity(c) end
    for _, f in ipairs(w.frozen) do if DoesEntityExist(f) then FreezeEntityPosition(f, false) end end
    for _, hd in ipairs(w.hidden) do RemoveModelHide(hd.x, hd.y, hd.z, hd.r, hd.model, false) end
    for _, c in pairs(w.chipProps or {}) do deleteEntity(c.obj) end
    for _, p in pairs(w.props or {}) do deleteEntity(p.obj) end
    for _, n in pairs(w.npcPeds or {}) do
        GGC.Anim.Stop(n.ped)
        deleteEntity(n.ped)
    end
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
        -- a map table may already have a chair on the dealer's spot: use it instead of stacking a second one
        local existing = t.bound and GetClosestObjectOfType(x, y, z, 0.5, joaat(Config.Dealer.Chair), false, false, false)
        if not existing or existing == 0 then
            chair = spawnObject(Config.Dealer.Chair, x, y, z, h + (Config.Dealer.ChairYaw or 0.0))
        end
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
                -- a table that's closed for a reason (unfunded, owner gone, out of range) still offers the seat: the
                -- server answers with the reason instead of the option silently missing
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

-- NPC players: a seated local ped in every NPC seat, sitting like a player does. The server picks the outfit so
-- every client shows the same person.
local function applyOutfit(ped, outfit)
    local n = outfit and Citizen.InvokeNative(0x10C70A515BC03707, ped, Citizen.ResultAsInteger()) or 0 -- GET_NUM_META_PED_OUTFITS
    if n and n > 0 then
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfit % n, false) -- _EQUIP_META_PED_OUTFIT_PRESET
    else
        Citizen.InvokeNative(0x283978A15512B2FE, ped, true)             -- _SET_RANDOM_OUTFIT_VARIATION
    end
end

local function updateNpcs(t, w)
    w.npcPeds = w.npcPeds or {}
    for i = 1, #t.seats do
        local want = t.npc and t.npc[i] or nil
        if want == false then want = nil end
        local outfit = want and t.npcOutfit and t.npcOutfit[i] or nil
        if outfit == false then outfit = nil end
        local have = w.npcPeds[i]
        if have and (have.model ~= want or have.outfit ~= outfit) then
            GGC.Anim.Stop(have.ped)
            deleteEntity(have.ped)
            w.npcPeds[i], have = nil, nil
        end
        if want and not have then
            local slot = { model = want, outfit = outfit } -- claim the seat before loading (loading yields)
            w.npcPeds[i] = slot
            local x, y, z, h = GGC.SeatWorld(t, i)
            local hash = GGC.LoadModel(want)
            local ped
            if hash then
                ped = CreatePed(hash, x, y, z, h, false, false, 0, 0)
                SetModelAsNoLongerNeeded(hash)
            end
            if ped and DoesEntityExist(ped) and w.npcPeds[i] == slot and world[t.id] == w then
                applyOutfit(ped, outfit)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetEntityCollision(ped, false, false)
                FreezeEntityPosition(ped, true)
                TaskStartScenarioAtPosition(ped, joaat(Config.Seating.Scenario), x, y, z + (t.sitZ or 0.5), h, -1, false, true)
                slot.ped = ped
                GGC.Anim.Start(ped)
            else
                deleteEntity(ped)
            end
        end
    end
end

-- Moves, wins and tells (Config.Anim.Cues): on our own ped when it's our seat (everyone else sees it through the
-- network), or on the NPC ped this client spawned for that seat
RegisterNetEvent('grumpy-gambling:client:seatCue', function(tableId, seat, cue)
    if GGC.Seat and GGC.Seat.id == tableId and GGC.Seat.seat == seat then
        return GGC.Anim.Play(PlayerPedId(), cue)
    end
    local w = world[tableId]
    local slot = w and w.npcPeds and w.npcPeds[seat]
    if slot and slot.ped then GGC.Anim.Play(slot.ped, cue) end
end)

---------------------------------------------------------------------
-- Game animations and table props (cards) from the core (SeatAnim / DealerAnim / SetProps)
---------------------------------------------------------------------
GGC.TableProps = {}   -- [tableId] = latest prop list (kept while the table is spawned)

local RANK = { T = '10', J = 'j', Q = 'q', K = 'k', A = 'a' }
local function cardModel(t, card)
    local style = Config.Cards.StyleByTable[t.id] or Config.Cards.Style
    return ('p_crd_%s_%s01x_%s'):format(RANK[card.r] or card.r, card.s, style)
end

-- Anchor frame: position on the floor and the heading the anchor faces (seat: the player; dealer: the dealer)
local function anchorOf(t, p)
    if p.at == 'seat' then
        local x, y, z, h = GGC.SeatWorld(t, p.seat)
        return x, y, z, h
    elseif p.at == 'dealer' and t.dealer then
        local off = t.dealer
        return Geo.ToWorld(GGC.Origin(t), t.h, { x = off.x, y = off.y, z = 0.0, h = off.h })
    end
    return t.x, t.y, t.z, t.h
end

---------------------------------------------------------------------
-- Motion: one small tween loop for every moving prop (only runs while something moves)
---------------------------------------------------------------------
local Mo = Config.Motion
local tweens = {}

local function ease(p) return 1 - (1 - p) ^ 3 end

-- Moves obj from a to b (x, y, z, ry, h) over ms, then calls done
local function tween(obj, a, b, ms, done)
    if not Mo.Enabled or ms <= 0 then
        SetEntityCoordsNoOffset(obj, b.x, b.y, b.z, false, false, false)
        SetEntityRotation(obj, 0.0, b.ry, b.h, 2, true)
        if done then done() end
        return
    end
    tweens[#tweens + 1] = { obj = obj, a = a, b = b, t0 = GetGameTimer(), ms = ms, done = done }
end

CreateThread(function()
    while true do
        if #tweens == 0 then
            Wait(100)
        else
            local now = GetGameTimer()
            for i = #tweens, 1, -1 do
                local tw = tweens[i]
                if not DoesEntityExist(tw.obj) then
                    table.remove(tweens, i)
                else
                    local p = math.min(1.0, (now - tw.t0) / tw.ms)
                    local e = ease(p)
                    local a, b = tw.a, tw.b
                    SetEntityCoordsNoOffset(tw.obj, a.x + (b.x - a.x) * e, a.y + (b.y - a.y) * e, a.z + (b.z - a.z) * e, false, false, false)
                    SetEntityRotation(tw.obj, 0.0, a.ry + (b.ry - a.ry) * e, a.h + (b.h - a.h) * e, 2, true)
                    if p >= 1.0 then
                        table.remove(tweens, i)
                        if tw.done then tw.done() end
                    end
                end
            end
            Wait(0)
        end
    end
end)

-- Where dealt cards come from and collected cards go: in front of the dealer, or the middle of a card table
local function deckPoint(t)
    local z = t.z + (t.cardHeight or Config.Cards.Height)
    if t.kind == 'pvd' and t.dealer then
        local off = t.dealer
        local x, y, _, h = Geo.ToWorld(GGC.Origin(t), t.h, { x = off.x, y = off.y, z = 0.0, h = off.h })
        local r = math.rad(h)
        return { x = x - math.sin(r) * 0.3, y = y + math.cos(r) * 0.3, z = z + 0.02, ry = 180.0, h = h }
    end
    return { x = t.x, y = t.y, z = z + 0.02, ry = 180.0, h = t.h }
end

-- Where a pot goes: the winner's chips, or the dealer
local function potPoint(t, to)
    if to == 'dealer' or (type(to) ~= 'number') then
        local d = deckPoint(t)
        d.ry = 0.0
        return d
    end
    local x, y, z, h = GGC.SeatWorld(t, to)
    if not x then return nil end
    local f = t.chipForward or Config.ChipStacks.Forward
    local r = math.rad(h)
    return { x = x - math.sin(r) * f, y = y + math.cos(r) * f, z = z + (t.chipHeight or Config.ChipStacks.Height), ry = 0.0, h = h }
end

local function spawnProp(model, at)
    local hash = GGC.LoadModel(model)
    if not hash then return nil end
    local obj = CreateObject(hash, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or not DoesEntityExist(obj) then return nil end
    SetEntityCoordsNoOffset(obj, at.x, at.y, at.z, false, false, false)
    SetEntityRotation(obj, 0.0, at.ry, at.h, 2, true)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    return obj
end

-- extra = { potTo = seat | 'dealer' } when a settled hand takes the pot off the table
local function updateProps(t, w, extra)
    w.props = w.props or {}
    local want = {}
    for _, p in ipairs(GGC.TableProps[t.id] or {}) do
        local ax, ay, az, ah = anchorOf(t, p)
        if ax then
            local r = math.rad(ah)
            local fx, fy = -math.sin(r), math.cos(r)  -- forward
            local rx, ry = math.cos(r), math.sin(r)   -- right
            local down = p.card and p.card.down == true
            local model = p.card and cardModel(t, down and { r = 'K', s = 's' } or p.card) or p.model
            local x, y = ax + fx * p.x + rx * p.y, ay + fy * p.x + ry * p.y
            local z = az + (t.cardHeight or Config.Cards.Height) + p.z
            want[p.key] = { model = model, card = p.card ~= nil, down = down, x = x, y = y, z = z, h = ah + p.h,
                ry = down and 180.0 or 0.0, sig = ('%s|%.3f|%.3f|%.3f|%.1f'):format(model, x, y, z, ah + p.h) }
        end
    end
    -- leaving: cards slide back to the deck, the pot to whoever won it, anything else just goes
    for key, have in pairs(w.props) do
        local d = want[key]
        if not d then
            w.props[key] = nil
            local obj = have.obj
            if obj and DoesEntityExist(obj) then
                local dest = (key == '_pot' and extra and extra.potTo ~= nil and potPoint(t, extra.potTo)) or (have.card and deckPoint(t)) or nil
                if dest and Mo.Enabled then
                    dest.ry = have.card and 180.0 or 0.0
                    tween(obj, have, dest, key == '_pot' and Mo.PotMs or Mo.CollectMs, function() deleteEntity(obj) end)
                else
                    deleteEntity(obj)
                end
            end
        elseif d.sig ~= have.sig then
            -- turned over (a back becomes this card) or moved/changed: a new prop takes over from the old one
            w.props[key] = nil
            local old = have.obj
            local slot = { sig = d.sig, card = d.card, down = d.down, x = d.x, y = d.y, z = d.z, h = d.h, ry = d.ry }
            w.props[key] = slot
            local flip = have.card and have.down and not d.down and math.abs(have.x - d.x) < 0.01 and math.abs(have.y - d.y) < 0.01
            CreateThread(function()
                local from = flip and { x = d.x, y = d.y, z = d.z + 0.02, ry = 180.0, h = d.h } or { x = have.x, y = have.y, z = have.z, ry = have.ry, h = have.h }
                local obj = spawnProp(d.model, from)
                deleteEntity(old)
                if not obj then return end
                if w.props[key] ~= slot or world[t.id] ~= w then return deleteEntity(obj) end
                slot.obj = obj
                tween(obj, from, d, flip and Mo.FlipMs or Mo.SlideMs)
            end)
        end
    end
    -- arriving: cards are dealt from the deck, other props (the pot) appear in place
    for key, d in pairs(want) do
        if not w.props[key] then
            local slot = { sig = d.sig, card = d.card, down = d.down, x = d.x, y = d.y, z = d.z, h = d.h, ry = d.ry }
            w.props[key] = slot
            CreateThread(function()
                local from = d.card and Mo.Enabled and deckPoint(t) or d
                local obj = spawnProp(d.model, from)
                if not obj then return end
                if w.props[key] ~= slot or world[t.id] ~= w then return deleteEntity(obj) end
                slot.obj = obj
                if from ~= d then tween(obj, from, d, Mo.SlideMs) end
            end)
        end
    end
end

RegisterNetEvent('grumpy-gambling:client:props', function(tableId, list, extra)
    if Config.Debug then print(('[grumpy-gambling] props for table %s: %d'):format(tostring(tableId), type(list) == 'table' and #list or -1)) end
    GGC.TableProps[tableId] = list
    local t, w = GGC.Tables[tableId], world[tableId]
    if t and w then CreateThread(function() updateProps(t, w, type(extra) == 'table' and extra or nil) end) end
end)

-- The peds this client spawned at a table (NPC players by seat, and the dealer), for look-at
function GGC.TablePeds(id)
    local w = world[id]
    if not w then return nil end
    local npcs = {}
    for seat, slot in pairs(w.npcPeds or {}) do if slot.ped and DoesEntityExist(slot.ped) then npcs[seat] = slot.ped end end
    return npcs, w.dealer
end

RegisterNetEvent('grumpy-gambling:client:seatAnim', function(tableId, seat, a)
    local ped
    if GGC.Seat and GGC.Seat.id == tableId and GGC.Seat.seat == seat then
        ped = PlayerPedId()
    else
        local w = world[tableId]
        local slot = w and w.npcPeds and w.npcPeds[seat]
        ped = slot and slot.ped
    end
    if not ped or not DoesEntityExist(ped) then return end
    local dict = (a.fem and not IsPedMale(ped)) and a.fem or a.dict
    GGC.Anim.PlayClip(ped, dict, a.clip, a.ms)
end)

RegisterNetEvent('grumpy-gambling:client:dealerAnim', function(tableId, a)
    local w = world[tableId]
    local ped = w and w.dealer
    if not ped or not DoesEntityExist(ped) then return end
    w.dealerBusy = (w.dealerBusy or 0) + 1
    local mine = w.dealerBusy
    CreateThread(function()
        if not GGC.LoadDict(a.dict) or not DoesEntityExist(ped) then return end
        TaskPlayAnim(ped, a.dict, a.clip, 4.0, -2.0, a.ms, Config.Dealer.ActionFlag or 24, 0.0, false, 0, false, 0, false)
        Wait(a.ms)
        -- back to the idle unless another move started meanwhile
        if w.dealerBusy == mine and DoesEntityExist(ped) then playDealerIdle(ped) end
    end)
end)

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
    -- cards already on the table when we arrive
    local id = t.id
    CreateThread(function()
        local list = RSGCore.Functions.AwaitCallback('grumpy-gambling:server:props', 5000, id)
        if world[id] == w and type(list) == 'table' then
            GGC.TableProps[id] = list
            updateProps(t, w)
        end
    end)
    for i = 1, #t.seats do
        local x, y, z = GGC.SeatWorld(t, i)
        w.zones[#w.zones + 1] = exports['rsg-target']:addSphereZone({
            coords = vector3(x, y, z + (t.sitZ or 0.5) + 0.1),
            radius = Config.SeatZoneRadius,
            debug = Config.Debug,
            options = seatOptions(t.id, i),
        })
        -- Back rooms: "Call out cheat" on an NPC in this seat, for players seated at the same table. A zone at chest
        -- height, not the ped: seated NPCs have no collision, so rsg-target's raycast would pass straight through them.
        if t.currency == 'bloodmoney' then
            local id, seat = t.id, i
            w.zones[#w.zones + 1] = exports['rsg-target']:addSphereZone({
                coords = vector3(x, y, z + (t.sitZ or 0.5) + 0.6),
                radius = 0.45,
                debug = Config.Debug,
                options = { {
                    name = ('grumpy-gambling:callout:%d:%d'):format(id, seat),
                    icon = 'fa-solid fa-hand-point-right',
                    label = locale('target_callout'),
                    distance = 3.5,
                    canInteract = function()
                        local tt = GGC.Tables[id]
                        if not GGC.Seat or GGC.Seat.id ~= id or GGC.Seat.seat == seat then return false end
                        return tt ~= nil and tt.npc ~= nil and tt.npc[seat] ~= nil and tt.npc[seat] ~= false
                    end,
                    onSelect = function() TriggerServerEvent('grumpy-gambling:server:callOut', id, seat) end,
                } },
            })
        end
    end
    -- business tables: the owner manages theirs from the middle of the table
    if t.businessId then
        local id = t.id
        w.zones[#w.zones + 1] = exports['rsg-target']:addSphereZone({
            coords = vector3(t.x, t.y, t.z + (t.chipHeight or Config.ChipStacks.Height)),
            radius = 0.7,
            debug = Config.Debug,
            options = { {
                name = ('grumpy-gambling:manage:%d'):format(id),
                icon = 'fa-solid fa-cash-register',
                label = locale('target_manage'),
                distance = Config.Business.ManageDistance,
                canInteract = function() return GGC.MyTables[id] == true and not GGC.Seat and not GGC.uiOpen end,
                onSelect = function() GGC.OpenBizPanel(id) end,
            } },
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
    -- an empty table has no game, so nothing may stay on it (cards, the pot), whatever messages went missing
    if t.state == 'empty' then GGC.TableProps[id] = {} end
    if w and w.key == geometryKey(t) then
        CreateThread(function()
            updateChips(t, w)
            updateNpcs(t, w)
            if t.state == 'empty' then updateProps(t, w) end
        end)
    end
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

-- Other resources (grumpy-sit) ask whether a chair belongs to a card table, so they leave it alone.
-- True for chairs this resource spawned, map chairs it froze at bound tables, and any object sitting on
-- a seat of a table spawned near the player.
local function isTableChair(entity)
    if type(entity) ~= 'number' or entity == 0 or not DoesEntityExist(entity) then return false end
    local c = GetEntityCoords(entity)
    local r = Config.Seating.FreezeWorldChairRadius
    for id, w in pairs(world) do
        for _, e in ipairs(w.chairs) do if e == entity then return true end end
        for _, e in ipairs(w.frozen) do if e == entity then return true end end
        local t = GGC.Tables[id]
        if t and t.seats then
            for i = 1, #t.seats do
                local x, y, z = GGC.SeatWorld(t, i)
                if x and (c.x - x) ^ 2 + (c.y - y) ^ 2 < r * r and math.abs(c.z - z) < 1.5 then return true end
            end
        end
    end
    return false
end
exports('IsTableChair', isTableChair)

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
