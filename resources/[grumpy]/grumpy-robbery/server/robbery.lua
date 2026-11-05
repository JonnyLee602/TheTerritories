-- Register hold-ups and safes. Everything is timed and checked here; the client only says
-- "I'm aiming at this clerk" and "I lowered my gun".

local R, S = Config.Robbery, Config.Safe
local Active = {}       -- [storeId] = { src, cid, endsAt, lastWarn }
local Cooldown = {}     -- [storeId] = os.time() it can be robbed again
local lastAny = 0       -- os.time() of the last robbery start (global cooldown)
local SafeWindow = {}   -- [storeId] = { untilTime, cids = { [cid] = true }, cracked, fails }
local SafeTry = {}      -- [src] = { store, started }
local busy = {}         -- [src] = GetGameTimer() rate limit

local UNARMED = joaat('WEAPON_UNARMED')

local function rate(src, ms)
    local now = GetGameTimer()
    if busy[src] and now - busy[src] < ms then return true end
    busy[src] = now
    return false
end

local function storeState(storeId, state, data)
    TriggerClientEvent('grumpy-robbery:client:clerkState', -1, storeId, state, data)
end

-----------------------------------------------------------------------
-- end a robbery
-----------------------------------------------------------------------
-- gone = the robber disconnected / logged out / switched character mid-robbery
local function finish(storeId, success, reasonKey, gone)
    local a = Active[storeId]
    if not a then return end
    Active[storeId] = nil
    local store = GR.Stores[storeId]
    local now = os.time()
    TriggerClientEvent('grumpy-robbery:client:robberyEnded', a.src, storeId, success)

    if not success then
        Cooldown[storeId] = now + R.FailCooldown
        storeState(storeId, 'idle')
        local P = RSGCore.Functions.GetPlayer(a.src)
        if not gone and P and P.PlayerData.citizenid == a.cid then
            GR.Notify(a.src, locale(reasonKey or 'rob_failed'), 'error')
            GR.Rep(a.src, Config.Reputation.robberyFailed)
        else
            -- leaving can't dodge the penalty: it's queued for that character's next login
            GR.RepCid(a.cid, Config.Reputation.robberyFailed)
        end
        return
    end

    Cooldown[storeId] = now + R.StoreCooldown
    if a.incident and GR.Law() then exports['grumpy-law']:MarkSucceeded(a.incident) end -- escape bonus is only for successes
    storeState(storeId, 'cower', { duration = 20 })
    local Player = RSGCore.Functions.GetPlayer(a.src)
    if not Player then return end
    local cash = math.random(R.CashMin, R.CashMax)
    Player.Functions.AddMoney(R.MoneyType, cash, 'grumpy-robbery-store')
    GR.Notify(a.src, locale('rob_success', cash), 'success')
    TriggerEvent('grumpy-robbery:server:robbed', a.src, storeId, cash)

    -- the safe opens for the robber and their posse
    if S.Enabled and store and store.safe then
        local cids = {}
        for _, id in ipairs(GR.Posse(a.src)) do
            local P = RSGCore.Functions.GetPlayer(id)
            if P then
                cids[P.PlayerData.citizenid] = true
                TriggerClientEvent('grumpy-robbery:client:safeOpen', id, storeId, S.Window)
            end
        end
        SafeWindow[storeId] = { untilTime = now + S.Window, cids = cids, cracked = false, fails = 0 }
        GR.Notify(a.src, locale('safe_available'), 'inform')
    end
end

-----------------------------------------------------------------------
-- start
-----------------------------------------------------------------------
RegisterNetEvent('grumpy-robbery:server:startRobbery', function(storeId)
    local src = source
    storeId = tonumber(storeId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not storeId or rate(src, 2000) or not R.Enabled then return end
    local store = GR.Stores[storeId]
    if not store or not store.enabled then return end

    local now = os.time()
    if Active[storeId] then return end
    for _, a in pairs(Active) do if a.src == src then return end end
    if Player.PlayerData.metadata.isdead then return end
    if GR.Dist(src, store.coords) > R.AimDistance + 2.0 then return end
    if GetSelectedPedWeapon(GetPlayerPed(src)) == UNARMED then return end
    if R.BlockLawmen and GR.IsLaw(Player) then return GR.Notify(src, locale('rob_lawman'), 'error') end
    if (Cooldown[storeId] or 0) > now then return GR.Notify(src, locale('rob_cooldown'), 'error') end
    if R.GlobalCooldown > 0 and now - lastAny < R.GlobalCooldown then return GR.Notify(src, locale('rob_cooldown'), 'error') end
    if R.MinLawmen > 0 and GR.LawOnDuty() < R.MinLawmen then return GR.Notify(src, locale('rob_no_law'), 'error') end

    lastAny = now
    Active[storeId] = { src = src, cid = Player.PlayerData.citizenid, endsAt = now + R.Duration }
    storeState(storeId, 'robbed', { robber = src, duration = (R.Duration + 5) * 1000 })
    TriggerClientEvent('grumpy-robbery:client:robberyStarted', src, storeId, R.Duration, R.Grace)
    GR.Notify(src, locale('rob_started'), 'warning')

    if GR.Law() then
        -- grumpy-law: the clerk reports (victim) and NPCs nearby can witness; heat follows the report
        Active[storeId].incident = exports['grumpy-law']:OpenIncident(src, {
            crime = 'store_robbery', coords = store.coords, label = store.label,
            hot = R.Duration + 15, victimReports = R.AlertLaw,
        })
    elseif R.AlertLaw then
        SetTimeout(R.AlertDelay * 1000, function()
            if Active[storeId] or (Cooldown[storeId] or 0) > os.time() then
                GR.AlertLaw(store.coords, locale('alert_robbery', store.label))
            end
        end)
    end

    -- server-side watch: distance, death, timer
    CreateThread(function()
        while Active[storeId] and Active[storeId].src == src do
            Wait(1000)
            local a = Active[storeId]
            if not a then return end
            local P = RSGCore.Functions.GetPlayer(src)
            if not P or P.PlayerData.citizenid ~= a.cid then return finish(storeId, false, nil, true) end
            if P.PlayerData.metadata.isdead then return finish(storeId, false, 'rob_failed') end
            if GR.Dist(src, store.coords) > R.LeaveDistance then return finish(storeId, false, 'rob_left') end
            if os.time() >= a.endsAt then return finish(storeId, true) end
        end
    end)
end)

RegisterNetEvent('grumpy-robbery:server:abortRobbery', function(storeId)
    local src = source
    storeId = tonumber(storeId)
    local a = storeId and Active[storeId]
    if a and a.src == src then finish(storeId, false, 'rob_lowered') end
end)

-----------------------------------------------------------------------
-- safe
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('grumpy-robbery:server:safeStart', function(src, cb, storeId)
    storeId = tonumber(storeId)
    local Player = RSGCore.Functions.GetPlayer(src)
    local store = storeId and GR.Stores[storeId]
    local w = storeId and SafeWindow[storeId]
    if not Player or not store or not store.safe or not w then return cb(false) end
    if rate(src, 1000) then return cb(false) end
    if w.untilTime < os.time() or w.cracked then return cb(false, locale('safe_closed')) end
    if not w.cids[Player.PlayerData.citizenid] then return cb(false, locale('safe_not_yours')) end
    if w.fails >= S.MaxAttempts then return cb(false, locale('safe_jammed')) end
    if GR.Dist(src, vector3(store.safe.x, store.safe.y, store.safe.z)) > S.Distance + 1.0 then return cb(false) end
    if S.RequiredItem and not exports['rsg-inventory']:HasItem(src, S.RequiredItem, 1) then
        local def = RSGCore.Shared.Items[S.RequiredItem]
        return cb(false, locale('safe_need_item', def and def.label or S.RequiredItem))
    end
    for _, t in pairs(SafeTry) do if t.store == storeId then return cb(false, locale('safe_busy')) end end
    SafeTry[src] = { store = storeId, started = GetGameTimer() }
    cb(true)
end)

RegisterNetEvent('grumpy-robbery:server:safeResult', function(success)
    local src = source
    local t = SafeTry[src]
    SafeTry[src] = nil
    local Player = RSGCore.Functions.GetPlayer(src)
    if not t or not Player then return end
    local store, w = GR.Stores[t.store], SafeWindow[t.store]
    if not store or not w or w.cracked or w.untilTime < os.time() then return end
    if GetGameTimer() - t.started < S.MinSeconds * 1000 then return end
    if GR.Dist(src, vector3(store.safe.x, store.safe.y, store.safe.z)) > S.Distance + 1.0 then return end

    -- without the minigame the client just waits out a progress bar; the server rolls the result
    if GetResourceState('rsg-lockpick') ~= 'started' then success = math.random(100) <= S.FallbackChance end

    if success ~= true then
        w.fails = w.fails + 1
        if S.RequiredItem and math.random(100) <= S.BreakChance then
            exports['rsg-inventory']:RemoveItem(src, S.RequiredItem, 1, nil, 'grumpy-robbery-safe-break')
        end
        return GR.Notify(src, w.fails >= S.MaxAttempts and locale('safe_jammed') or locale('safe_fail'), 'error')
    end

    w.cracked = true
    local cash = math.random(S.CashMin, S.CashMax)
    Player.Functions.AddMoney(R.MoneyType, cash, 'grumpy-robbery-safe')
    for _, it in ipairs(S.Items or {}) do
        if RSGCore.Shared.Items[it.name] and math.random(100) <= (it.chance or 100) then
            local amount = math.random(it.min or 1, it.max or it.min or 1)
            if exports['rsg-inventory']:CanAddItem(src, it.name, amount) then
                exports['rsg-inventory']:AddItem(src, it.name, amount, nil, nil, 'grumpy-robbery-safe')
            end
        end
    end
    GR.Notify(src, locale('safe_success', cash), 'success')
    TriggerEvent('grumpy-robbery:server:safeCracked', src, t.store, cash)
end)

RegisterNetEvent('grumpy-robbery:server:safeCancel', function() SafeTry[source] = nil end)

AddEventHandler('playerDropped', function()
    local src = source
    busy[src], SafeTry[src] = nil, nil
    for storeId, a in pairs(Active) do
        if a.src == src then finish(storeId, false, nil, true) end
    end
end)

-- read access for shoplift.lua / exports
function GR.IsBeingRobbed(storeId) return Active[storeId] ~= nil end

exports('IsBeingRobbed', function(storeId) return Active[tonumber(storeId)] ~= nil end)
exports('GetCooldown', function(storeId) return math.max(0, (Cooldown[tonumber(storeId)] or 0) - os.time()) end)
