-- NPC players (DESIGN.md §8). An NPC occupies a seat like a player but has no client, and doesn't count as a real
-- player (the table resets when the last real player leaves). Its chips are created when it sits ('npc_mint') and
-- destroyed when it leaves ('npc_sink'): the free-NPC money the owner accepted, bounded by the per-player win cap.
--
-- Seating rule (§8.1): NPCs = min(seats, game maxSeats) - real players - 1, so one seat is always free. NPCs join
-- one at a time between hands and leave only between hands. Each has a personality (Config.Npc.Personas, mixed by
-- tier), a session plan (cut loss, take profit, hands to stay), and may be drunk, tilted, a cardsharp (back rooms)
-- or a named regular who remembers players.
local Npc = { window = {}, notified = {}, regularsAt = {}, memory = {}, lastChat = {}, callOutBlock = {}, lastPurge = 0 }
GG.Npc = Npc
local M = GG.M
local C = Config.Npc

local function now() return os.time() end
local function pick(list) return list[math.random(#list)] end

local function weighted(mix)
    local total = 0
    for _, w in pairs(mix) do total = total + w end
    if total <= 0 then return nil end
    local roll = math.random() * total
    local keys = {}
    for k in pairs(mix) do keys[#keys + 1] = k end
    table.sort(keys) -- stable order so a seeded random is repeatable
    for _, k in ipairs(keys) do
        roll = roll - mix[k]
        if roll <= 0 then return k end
    end
    return keys[#keys]
end

-- Only the resource that registered a table's game may drive its NPCs
local function callerOk(t)
    local inv = GetInvokingResource()
    if not inv or inv == GetCurrentResourceName() then return true end
    local g = t.game and GG.Registry.Get(t.game)
    return g ~= nil and g.resource == inv
end

local function npcSeats(t)
    local list = {}
    for seat, occ in pairs(t.occupants) do if occ.npc then list[#list + 1] = seat end end
    table.sort(list)
    return list
end

local function firstName(name) return type(name) == 'string' and (name:match('^(%S+)') or name) or '' end

---------------------------------------------------------------------
-- Game hour (rsg-weather's GlobalState.rsgTime) for drunk evenings
---------------------------------------------------------------------
local function gameHour()
    local ok, data = pcall(function() return GlobalState.rsgTime end)
    if ok and type(data) == 'table' and tonumber(data.time) then return math.floor(data.time / 3600) % 24 end
    return nil
end

local function drinkingHours()
    local h = gameHour()
    if not h then return false end
    local a, b = C.Drunk.Hours[1], C.Drunk.Hours[2]
    if a <= b then return h >= a and h < b end
    return h >= a or h < b
end

---------------------------------------------------------------------
-- Win cap (§8.3): one rolling window per player across all tables
---------------------------------------------------------------------
function Npc.Cap(t)
    local tier = Config.Tiers[t.tier]
    if not tier then return math.huge end
    return tier.npcCapMultiplier * tier.buyInMin * M.ToCents(tier.bigBlind)
end

function Npc.WindowTotal(cid)
    local since = now() - C.CapWindowMinutes * 60
    local w = Npc.window[cid]
    if not w then
        w = GG.DB.WindowLoad(cid, since) or {}
        Npc.window[cid] = w
    end
    local total = 0
    for i = #w, 1, -1 do
        if w[i].ts < since then table.remove(w, i) else total = total + w[i].amount end
    end
    return total
end

function Npc.Capped(cid, t) return Npc.WindowTotal(cid) >= Npc.Cap(t) end

-- Per hand (PVP): what the NPCs together lost is credited to the real players who won, in proportion to their
-- winnings (never more than each one won); what they won is taken off the real players who lost, the same way.
function Npc.CapEntries(h, awards)
    local npcNet, win, lose, wsum, lsum = 0, {}, {}, 0, 0
    local anyNpc = false
    for seat, s in pairs(h.seats) do
        local res = (awards[seat] or 0) - s.contrib
        if s.npc then
            anyNpc = true
            npcNet = npcNet + res
        elseif res > 0 then
            win[s.cid] = (win[s.cid] or 0) + res; wsum = wsum + res
        elseif res < 0 then
            lose[s.cid] = (lose[s.cid] or 0) - res; lsum = lsum - res
        end
    end
    local out, ts = {}, now()
    if not anyNpc then return out end
    if npcNet < 0 and wsum > 0 then
        for cid, w in pairs(win) do
            local a = math.min(w, (-npcNet) * w // wsum)
            if a > 0 then out[#out + 1] = { cid = cid, ts = ts, amount = a } end
        end
    elseif npcNet > 0 and lsum > 0 then
        for cid, l in pairs(lose) do
            local a = math.min(l, npcNet * l // lsum)
            if a > 0 then out[#out + 1] = { cid = cid, ts = ts, amount = -a } end
        end
    end
    return out
end

-- The settle transaction committed these rows: keep the in-memory windows in step
function Npc.CapApplied(entries)
    for _, e in ipairs(entries or {}) do
        local w = Npc.window[e.cid]
        if w then w[#w + 1] = { ts = e.ts, amount = e.amount } end
    end
end

---------------------------------------------------------------------
-- Profiles: persona + tier + drunk + tilt, the numbers the brains read (lib/npc_brain.lua)
---------------------------------------------------------------------
local PROBS = { aggression = true, bluff = true, slowplay = true }

function Npc.Profile(t, occ)
    local base = C.Personas[occ.persona] or C.Personas.balanced
    local p = {}
    for k, v in pairs(base) do p[k] = v end
    local function add(mods)
        for k, v in pairs(mods or {}) do
            if k == 'tells' then p.tells = (p.tells or 1) * v
            elseif type(p[k]) == 'number' then p[k] = p[k] + v end
        end
    end
    add(C.TierMods[t.tier])
    if occ.drunk then add(C.Drunk.Mods) end
    if (occ.tilt or 0) > 0 then add(C.Tilt.Mods) end
    if occ.skill then p.noise = (p.noise or 0.06) * (1.5 - occ.skill) end
    for k in pairs(PROBS) do if p[k] then p[k] = math.max(0, math.min(1, p[k])) end end
    p.think = { C.ThinkMs[1], math.floor(C.ThinkMs[2] * (occ.drunk and 1.3 or 1)) }
    p.persona, p.name = occ.persona, occ.name
    p.drunk, p.tilt, p.regular = occ.drunk == true, occ.tilt or 0, occ.regular
    p.sharp = occ.sharp and C.Sharp.CheatChance or nil
    p.strongAt = C.Tells.Strong
    return p
end

---------------------------------------------------------------------
-- Chatter (§8.7) and tells
---------------------------------------------------------------------
local function feed(t, text)
    for _, occ in pairs(t.occupants) do
        if occ.src then TriggerClientEvent('grumpy-gambling:client:message', occ.src, t.id, text) end
    end
end
Npc.Feed = feed

-- force = skip the chance and the per-table gap (greetings, exits). arg = optional value for the line's %s.
function Npc.Say(t, seat, event, force, arg)
    local occ = t.occupants[seat]
    if not occ or not occ.npc then return false end
    local ch = C.Chatter
    if not ch.Lines[event] then return false end
    if not force then
        local chance = (ch.Chance[event] or 0) * (occ.drunk and 1.5 or 1)
        if math.random() >= chance then return false end
        local last = Npc.lastChat[t.id]
        if last and now() - last < ch.GapSeconds then return false end
    end
    -- drunks sometimes just ramble
    if occ.drunk and not force and ch.Lines.drunk and math.random() < (ch.Chance.drunk or 0) then event = 'drunk' end
    Npc.lastChat[t.id] = now()
    local key = ('npc_%s_%d'):format(event, math.random(ch.Lines[event]))
    local line = arg and locale(key, arg) or locale(key)
    feed(t, locale('npc_says', occ.name, line))
    return true
end

-- A visible cue on the NPC's ped in the world (tells are never shown in the NUI)
function Npc.Cue(t, seat, cue)
    return GG.Play and GG.Play.Cue(t, seat, cue)
end

-- From a game module: 'strong' / 'bluff' (maybe a tell, shown while the NPC thinks), 'sleight' (a cardsharp's cheat),
-- or another chatter event. Moves go through SeatCue (animation + chatter).
function Npc.Event(t, seat, event)
    local occ = t.occupants[seat]
    if not occ or not occ.npc then return false end
    if event == 'strong' or event == 'bluff' then
        local p = Npc.Profile(t, occ)
        if math.random() < (C.Tells.Chance[event] or 0) * (p.tells or 1) then return Npc.Cue(t, seat, event) == true end
    elseif event == 'sleight' then
        if math.random() < C.Sharp.TellChance then return Npc.Cue(t, seat, 'sleight') == true end
    else
        return Npc.Say(t, seat, event)
    end
    return false
end

---------------------------------------------------------------------
-- Regulars (§8.6): memory per player, saved as increments
---------------------------------------------------------------------
local function memKey(rid, cid) return rid .. '|' .. cid end

local function memoryOf(rid, cid, load)
    local key = memKey(rid, cid)
    local m = Npc.memory[key]
    if not m then
        m = { regularId = rid, cid = cid, hands = 0, net = 0, dh = 0, dn = 0, lastSeen = 0, loaded = false }
        Npc.memory[key] = m
    end
    if load and not m.loaded then
        local db = GG.DB.MemoryGet(rid, cid)
        if db then m.hands, m.net, m.lastSeen = db.hands + m.dh, db.net + m.dn, db.lastSeen end
        m.loaded = true
    end
    return m
end

function Npc.FlushMemory(rid)
    local rows = {}
    for key, m in pairs(Npc.memory) do
        if (not rid or m.regularId == rid) and m.dh > 0 then
            rows[#rows + 1] = { regularId = m.regularId, cid = m.cid, hands = m.dh, net = m.dn, lastSeen = m.lastSeen }
            m.dh, m.dn = 0, 0
        end
        if not rid or m.regularId == rid then Npc.memory[key] = nil end
    end
    if #rows > 0 then GG.DB.MemorySave(rows) end
end

local function regularDef(id)
    for _, r in ipairs(C.Regulars.List) do if r.id == id then return r end end
end

local function pickRegular(t)
    local R = C.Regulars
    if not R or math.random() >= (R.Chance or 0) then return nil end
    local mix, defs = {}, {}
    for _, r in ipairs(R.List) do
        if not Npc.regularsAt[r.id] and (not r.tiers or r.tiers[t.tier]) and C.Personas[r.persona] then
            local home = r.home and ((t.x - r.home.x) ^ 2 + (t.y - r.home.y) ^ 2) ^ 0.5 <= (r.home.radius or 100)
            local w = home and 3 or (r.roams and 1 or 0)
            if w > 0 then mix[r.id], defs[r.id] = w, r end
        end
    end
    local id = next(mix) and weighted(mix)
    return id and defs[id] or nil
end

-- A regular says hello to the player it knows best at the table (or only to `onlyCid`)
local function greet(t, seat, onlyCid)
    local occ = t.occupants[seat]
    if not occ or not occ.regular then return false end
    local best
    for _, p in pairs(t.occupants) do
        if not p.npc and (not onlyCid or p.cid == onlyCid) then
            local m = memoryOf(occ.regular, p.cid, true)
            if m.hands >= C.Regulars.KnownHands and (not best or m.hands > best.m.hands) then best = { p = p, m = m } end
        end
    end
    if not best then return false end
    local ev = best.m.net > 0 and 'greet_friend' or best.m.net < 0 and 'greet_grudge' or 'greet_known'
    return Npc.Say(t, seat, ev, true, firstName(best.p.name))
end

---------------------------------------------------------------------
-- Seats
---------------------------------------------------------------------
local function uniqueName(t, female)
    local used = {}
    for _, occ in pairs(t.occupants) do if occ.name then used[occ.name] = true end end
    local fem = {}
    for _, n in ipairs(C.FemaleNames or {}) do fem[n] = true end
    local list = {}
    for _, n in ipairs(C.Names) do
        if not used[n] and (fem[n] == true) == female then list[#list + 1] = n end
    end
    if #list == 0 then return pick(C.Names) end
    return pick(list)
end

-- opts = { name?, model?, outfit?, persona?, regular?, skill?, stack? (cents), drunk?, sharp? }. Returns occ or nil, err.
function Npc.Seat(t, seat, opts)
    opts = opts or {}
    if t.state ~= 'active' or not t.tier then return nil, 'table_not_started' end
    if not t.seats[seat] or t.occupants[seat] then return nil, 'seat_taken' end
    local persona = opts.persona
    if not persona or not C.Personas[persona] then persona = weighted(C.Mix[t.tier] or C.Mix.low) or 'balanced' end
    local P = C.Personas[persona]
    local lim = GG.Wallet.Limits(t)
    local stack = opts.stack
    if not stack then
        local steps = (lim.max - lim.min) // lim.step
        local lo, hi = 0, steps
        if persona == 'aggressive' or persona == 'shark' then lo = steps // 2 elseif persona == 'tight' or persona == 'teacher' then hi = steps // 2 end
        stack = lim.min + math.random(lo, math.max(lo, hi)) * lim.step
    end
    local model = opts.model
    if not model then
        if t.currency == 'bloodmoney' and C.BloodmoneyModels and #C.BloodmoneyModels > 0 and math.random() < 0.5 then
            model = pick(C.BloodmoneyModels)
        else
            model = pick(C.Models)
        end
    end
    local drunk = opts.drunk
    if drunk == nil then drunk = math.random() < (drinkingHours() and C.Drunk.Chance or C.Drunk.DayChance) end
    local sharp = opts.sharp
    if sharp == nil then sharp = t.currency == 'bloodmoney' and t.tier ~= 'micro' and math.random() < C.Sharp.Chance end
    local occ = {
        npc = true, cid = ('npc:%d:%d'):format(t.id, seat),
        name = opts.name or uniqueName(t, model:sub(1, 4) == 'a_f_'),
        model = model, outfit = opts.outfit or math.random(0, 9999), persona = persona, regular = opts.regular,
        skill = opts.skill, stack = stack, startStack = stack, hands = 0,
        maxHands = math.random(P.hands[1], math.max(P.hands[1], P.hands[2])), tilt = 0,
        drunk = drunk == true, sharp = sharp == true, joinedAt = now(),
    }
    t.occupants[seat] = occ
    if occ.regular then Npc.regularsAt[occ.regular] = t.id end
    GG.DB.StackSet(occ.cid, t.id, t.currency, stack)
    GG.DB.Ledger({ kind = 'npc_mint', tableId = t.id, cid = occ.cid, currency = t.currency, amount = stack, note = occ.name })
    GG.Tables.OnSeatTaken(t, seat, nil)
    return occ
end

-- quiet = true when the table itself is closing (no seatLeft, no reset loop)
function Npc.Remove(t, seat, quiet)
    local occ = t.occupants[seat]
    if not occ or not occ.npc then return false end
    GG.Hands.SeatLeaving(t.id, seat)
    local amount = occ.stack - GG.Hands.AtRisk(t.id, seat)
    GG.DB.StackDelete(occ.cid)
    if amount > 0 then
        GG.DB.Ledger({ kind = 'npc_sink', tableId = t.id, cid = occ.cid, currency = t.currency, amount = -amount, note = occ.name })
    end
    t.occupants[seat] = nil
    if occ.regular and Npc.regularsAt[occ.regular] == t.id then
        Npc.regularsAt[occ.regular] = nil
        Npc.FlushMemory(occ.regular)
    end
    if quiet then GG.Tables.Sync(t) else GG.Tables.OnSeatLeft(t, seat, nil) end
    return true
end

function Npc.ClearTable(t, quiet)
    for seat, occ in pairs(t.occupants) do
        if occ.npc then Npc.Remove(t, seat, quiet) end
    end
    t.npcOverride = nil
    Npc.lastChat[t.id] = nil
end

function Npc.IsNpcCid(cid) return type(cid) == 'string' and cid:sub(1, 4) == 'npc:' end

-- Money an NPC won or had in a hand after it left: destroyed (nobody to pay)
function Npc.Sink(tableId, handId, cid, currency, amount, ledger)
    local e = { kind = 'npc_sink', tableId = tableId, handId = handId, cid = cid, currency = currency, amount = -amount }
    if ledger then ledger[#ledger + 1] = e else GG.DB.Ledger(e) end
end

---------------------------------------------------------------------
-- Seating rule
---------------------------------------------------------------------
-- How many NPCs this table should have now, and why it's zero when a player is capped
function Npc.Wanted(t)
    if t.state ~= 'active' or not t.game or not t.tier then return 0 end
    local real = GG.Tables.RealCount(t)
    if real == 0 then return 0 end
    if t.npcOverride then return t.npcOverride end
    if not C.Enabled then return 0 end
    if t.settings and t.settings.npcs == false then return 0 end
    for _, occ in pairs(t.occupants) do
        if not occ.npc and Npc.Capped(occ.cid, t) then return 0, 'capped' end
    end
    local g = GG.Registry.Get(t.game)
    local seats = math.min(#t.seats, (g and g.maxSeats) or #t.seats)
    return math.max(0, math.min(seats - real - 1, C.MaxPerTable))
end

local function leave(t, seat, why)
    Npc.Say(t, seat, 'leave_' .. why, true)
    return Npc.Remove(t, seat)
end

local function join(t)
    local free = {}
    for i = 1, #t.seats do if not t.occupants[i] then free[#free + 1] = i end end
    if #free == 0 or (#free == 1 and not t.npcOverride) then return false end -- keep one seat for a real player
    local seat = pick(free)
    local reg = pickRegular(t)
    local opts = reg and { name = reg.name, model = reg.model, outfit = reg.outfit, persona = reg.persona,
        regular = reg.id, skill = reg.skill } or nil
    local occ = Npc.Seat(t, seat, opts)
    if not occ then return false end
    if not (reg and greet(t, seat)) then Npc.Say(t, seat, 'join') end
    return true
end

-- Brings the NPC count to what the table wants. Leaving only happens between hands; joining may happen any time
-- (the game adds a newcomer to the next hand). One NPC joins per call unless `fill`.
function Npc.Balance(t, fill)
    if t.state ~= 'active' then return end
    if not C.Enabled and t.npcOverride == nil then return end
    local want, why = Npc.Wanted(t)
    if not GG.Hands.ForTable(t.id) then
        for _, seat in ipairs(npcSeats(t)) do
            local occ = t.occupants[seat]
            local reason = occ.leaving or ((occ.stack or 0) <= 0 and 'bust') or nil
            if reason then leave(t, seat, reason) end
        end
        local list = npcSeats(t)
        if #list > want then
            -- the ones who have been here longest go first
            table.sort(list, function(a, b) return t.occupants[a].hands > t.occupants[b].hands end)
            for i = 1, #list - want do leave(t, list[i], why == 'capped' and 'night' or 'room') end
        end
    end
    local have = #npcSeats(t)
    if have < want then
        for _ = 1, fill and (want - have) or 1 do
            if not join(t) then break end
        end
    end
end

---------------------------------------------------------------------
-- After every hand (called by hands.lua): reactions, tilt, session plans, regulars' memory, the cap
---------------------------------------------------------------------
function Npc.AfterHand(t, h, awards)
    if h and awards then
        local bb = h.bb
        local real = {}
        for _, s in pairs(h.seats) do if not s.npc and not s.departed then real[#real + 1] = s.cid end end
        for seat, s in pairs(h.seats) do
            local occ = t.occupants[seat]
            if s.npc and occ and occ.cid == s.cid and not s.departed then
                occ.hands = occ.hands + 1
                if occ.tilt > 0 then occ.tilt = occ.tilt - 1 end
                local res = (awards[seat] or 0) - s.contrib
                local P = C.Personas[occ.persona] or {}
                -- (the win / loss clips come from Play.SettleCues, for players and NPCs alike)
                if res >= C.BigPotBB * bb then Npc.Say(t, seat, 'win_big')
                elseif res <= -C.BigPotBB * bb then Npc.Say(t, seat, 'lose_big') end
                if res <= -C.Tilt.LossBB * bb and math.random() < (P.tiltProne or 0) then
                    occ.tilt = C.Tilt.Hands
                    if math.random() < C.Tilt.StormOff then occ.leaving = 'storm' end
                end
                if not occ.leaving then
                    local start = occ.startStack or occ.stack
                    if occ.stack <= 0 then occ.leaving = 'bust'
                    elseif occ.stack <= start * (1 - (P.cutLoss or 1)) then occ.leaving = 'loss'
                    elseif occ.stack >= start * (1 + (P.takeProfit or 99)) and math.random() < 0.5 then occ.leaving = 'profit'
                    elseif occ.hands >= occ.maxHands then occ.leaving = 'bored' end
                end
                if occ.regular then
                    for _, cid in ipairs(real) do
                        local m = memoryOf(occ.regular, cid, false)
                        m.hands, m.net, m.dh, m.dn, m.lastSeen = m.hands + 1, m.net + res, m.dh + 1, m.dn + res, now()
                    end
                end
            end
        end
        -- players who just reached the cap: tell them once; the NPCs leave at the next break
        if h.kind == 'pvp' then
            for _, occ in pairs(t.occupants) do
                if occ.src then
                    if Npc.Capped(occ.cid, t) then
                        if not Npc.notified[occ.cid] then
                            Npc.notified[occ.cid] = now()
                            GG.Notify(occ.src, locale('npc_cap_reached'), 'inform')
                        end
                    else
                        Npc.notified[occ.cid] = nil
                    end
                end
            end
        end
    end
    SetTimeout(C.LeaveDelayMs, function() Npc.Balance(t) end)
end

---------------------------------------------------------------------
-- Upkeep: tables between hands, window purge, regulars' memory
---------------------------------------------------------------------
function Npc.Tick()
    for _, t in pairs(GG.Tables.byId) do
        if t.state == 'active' then Npc.Balance(t) end
    end
    if now() - Npc.lastPurge >= 600 then
        Npc.lastPurge = now()
        local before = now() - C.CapWindowMinutes * 60
        GG.DB.WindowPurge(before)
        local seated = {}
        for _, t in pairs(GG.Tables.byId) do for _, occ in pairs(t.occupants) do seated[occ.cid] = true end end
        for cid in pairs(Npc.window) do if not seated[cid] then Npc.window[cid] = nil end end
        for cid, at in pairs(Npc.notified) do if at < before then Npc.notified[cid] = nil end end
        -- save memory of regulars still seated without forgetting it
        local rows = {}
        for _, m in pairs(Npc.memory) do
            if m.dh > 0 then
                rows[#rows + 1] = { regularId = m.regularId, cid = m.cid, hands = m.dh, net = m.dn, lastSeen = m.lastSeen }
                m.dh, m.dn = 0, 0
            end
        end
        if #rows > 0 then GG.DB.MemorySave(rows) end
    end
end

CreateThread(function()
    while true do
        Wait(C.TickMs)
        if GG.Ready then
            local ok, err = pcall(Npc.Tick)
            if not ok then print('^1[grumpy-gambling] npc tick: ' .. tostring(err) .. '^7') end
        end
    end
end)

-- A real player sits: load their window, and regulars at the table may recognise them
AddEventHandler('grumpy-gambling:server:seatTaken', function(tableId, _, seat, src)
    if not src then return end
    local t = GG.Tables.Get(tableId)
    local occ = t and t.occupants[seat]
    if not occ or occ.npc then return end
    Npc.WindowTotal(occ.cid)
    for s2, o in pairs(t.occupants) do
        if o.npc and o.regular then greet(t, s2, occ.cid) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Npc.FlushMemory(nil)
end)

---------------------------------------------------------------------
-- Cardsharps: calling one out (back-room tables, DESIGN.md §8.7). The game module knows whether the NPC cheated
-- this hand; it answers with ResolveCallOut. A module that never answers counts as a wrong call.
---------------------------------------------------------------------
RegisterNetEvent('grumpy-gambling:server:callOut', function(tableId, seat)
    local src = source
    if GG.Cooldown(src, 'callout', 3000) then return end
    local s = GG.Seats.bySrc[src]
    local t = s and GG.Tables.Get(s.id)
    seat = GG.Int(seat, 1, 12)
    if not t or t.id ~= GG.Int(tableId) or not seat or t.currency ~= 'bloodmoney' or t.state ~= 'active' then return end
    local occ = t.occupants[seat]
    local me = t.occupants[s.seat]
    if not occ or not occ.npc or not me then return end
    local until_ = Npc.callOutBlock[me.cid]
    if until_ and until_ > now() then return GG.Notify(src, locale('callout_wait'), 'error') end
    if not GG.Hands.ForTable(t.id) then return GG.Notify(src, locale('callout_no_hand'), 'error') end
    occ.calledBy = src
    feed(t, locale('callout_feed', me.name, occ.name))
    TriggerEvent('grumpy-gambling:server:playerCallOut', t.id, t.game, seat, src)
    SetTimeout(3000, function()
        if t.occupants[seat] == occ and occ.calledBy == src then Npc.ResolveCallOut(t, seat, false) end
    end)
end)

function Npc.ResolveCallOut(t, seat, caught)
    local occ = t.occupants[seat]
    if not occ or not occ.npc or not occ.calledBy then return false end
    local src = occ.calledBy
    occ.calledBy = nil
    local caller = GG.Seats.bySrc[src] and t.occupants[GG.Seats.bySrc[src].seat]
    if caught then
        Npc.Say(t, seat, 'caught', true)
        feed(t, locale('callout_caught', occ.name))
        occ.leaving = 'caught'
        GG.Notify(src, locale('callout_right'), 'success')
    else
        Npc.Say(t, seat, 'offended', true)
        if caller then Npc.callOutBlock[caller.cid] = now() + C.Sharp.CallOutCooldownSeconds end
        GG.Notify(src, locale('callout_wrong'), 'error')
    end
    return true
end

---------------------------------------------------------------------
-- Dev: /ggbot [count | clear | auto] at the table you're sitting at
---------------------------------------------------------------------
if Config.DevGames then
    GG.Core.Commands.Add('ggbot', 'Seat test NPCs at your table (dev)', { { name = 'count', help = 'number, clear or auto' } }, false,
        function(source, args)
            if not GG.IsAdmin(source) then return end
            local s = GG.Seats.bySrc[source]
            local t = s and GG.Tables.Get(s.id)
            if not t or t.state ~= 'active' then return GG.Notify(source, locale('dev_bot_sit_first'), 'error') end
            if args[1] == 'auto' then
                t.npcOverride = nil
                Npc.Balance(t, true)
                return GG.Notify(source, locale('dev_bot_auto'), 'success')
            end
            if args[1] == 'clear' then
                t.npcOverride = 0
                Npc.Balance(t)
                return GG.Notify(source, locale('dev_bot_cleared'), 'success')
            end
            local before = #npcSeats(t)
            t.npcOverride = math.min(#t.seats - GG.Tables.RealCount(t), before + (GG.Int(args[1] or 1, 1, 12) or 1))
            Npc.Balance(t, true)
            GG.Notify(source, locale('dev_bot_added', #npcSeats(t) - before), 'success')
        end, Config.AdminPermission)
end

---------------------------------------------------------------------
-- Exports (game modules)
---------------------------------------------------------------------
exports('SeatNpc', function(tableId, seat, opts)
    local t = GG.Tables.Get(tableId)
    if not t or not callerOk(t) then return nil end
    return Npc.Seat(t, seat, opts) ~= nil
end)

-- The NPC's profile for the brains (server only: never sent to players)
exports('GetNpc', function(tableId, seat)
    local t = GG.Tables.Get(tableId)
    local occ = t and t.occupants[seat]
    if not occ or not occ.npc or not callerOk(t) then return nil end
    return Npc.Profile(t, occ)
end)

exports('NpcEvent', function(tableId, seat, event)
    local t = GG.Tables.Get(tableId)
    if not t or not callerOk(t) or type(event) ~= 'string' then return false end
    return Npc.Event(t, seat, event)
end)

exports('ResolveCallOut', function(tableId, seat, caught)
    local t = GG.Tables.Get(tableId)
    if not t or not callerOk(t) then return false end
    return Npc.ResolveCallOut(t, seat, caught == true)
end)

-- How much a player has won from NPCs in the current window, and their cap at a table (cents)
exports('GetNpcWindow', function(cid, tableId)
    local t = tableId and GG.Tables.Get(tableId)
    return { total = Npc.WindowTotal(cid), cap = t and t.tier and Npc.Cap(t) or nil }
end)
