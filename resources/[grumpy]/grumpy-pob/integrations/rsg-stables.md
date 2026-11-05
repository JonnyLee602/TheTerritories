# rsg-stables patch (grumpy-pob)

Adds stables that other resources register while the server runs (one per stable business), lets them be limited to
one job, gives them their own per-player horse limit, and exposes horse-training exports so business staff can train
customers' horses.
These are local changes to an RSG resource: re-apply after updating rsg-stables, or offer them upstream.

What a registered stable does:
- It has no ped or blip of its own (grumpy-pob spawns the business NPC and opens the menu with `OpenStable`).
- Only players holding `restrictJob` can buy, claim, retrieve, store, breed, collect foals or transfer horses there.
- `maxHorses` replaces `Config.MaxHorsesPerStable` for that stable.
- `capExempt = true`: horses kept there don't count toward `Config.MaxOwnedHorses`.

## server/server.lua

### 1. Registered stables
Below the `getStableConfig` function (in `-- ===================== HELPERS =====================`) add:

```lua
-- ===================== REGISTERED STABLES (other resources, e.g. grumpy-pob) =====================
local function toV4(p)
    if not p then return nil end
    return vector4((p.x or 0) + 0.0, (p.y or 0) + 0.0, (p.z or 0) + 0.0, (p.w or 0) + 0.0)
end

local function removeStableByName(name)
    for i = #Config.Stables, 1, -1 do
        if Config.Stables[i].name == name then table.remove(Config.Stables, i) end
    end
end

local function externalList()
    local list = {}
    for _, s in ipairs(Config.Stables) do
        if s.external then
            list[#list + 1] = { name = s.name, label = s.label, pedCoords = s.pedCoords, storeCoords = s.storeCoords,
                previewCoords = s.previewCoords, restrictJob = s.restrictJob }
        end
    end
    return list
end

local function broadcastExternal(target)
    TriggerClientEvent('rsg-stables:client:externalStables', target or -1, externalList())
end

-- def = { name, label, pedCoords, storeCoords?, previewCoords?, restrictJob?, maxHorses?, capExempt? }
exports('RegisterStable', function(def)
    if type(def) ~= 'table' or type(def.name) ~= 'string' or not def.pedCoords then return false end
    removeStableByName(def.name)
    Config.Stables[#Config.Stables + 1] = {
        name = def.name, label = def.label or def.name,
        pedCoords = toV4(def.pedCoords), storeCoords = toV4(def.storeCoords or def.pedCoords),
        previewCoords = toV4(def.previewCoords or def.pedCoords),
        restrictJob = type(def.restrictJob) == 'string' and def.restrictJob or nil,
        maxHorses = tonumber(def.maxHorses), capExempt = def.capExempt == true,
        external = GetInvokingResource() or 'unknown',
    }
    broadcastExternal()
    return true
end)

exports('RemoveStable', function(name)
    removeStableByName(name)
    broadcastExternal()
end)

AddEventHandler('onResourceStop', function(res)
    local changed = false
    for i = #Config.Stables, 1, -1 do
        if Config.Stables[i].external == res then table.remove(Config.Stables, i) changed = true end
    end
    if changed then broadcastExternal() end
end)

RegisterNetEvent('rsg-stables:server:requestExternalStables', function()
    broadcastExternal(source)
end)

-- Restricted stables: only holders of restrictJob (any grade, any duty)
local function canUseStable(src, stable)
    if not stable or not stable.restrictJob then return true end
    local ok, held = pcall(function() return exports['rsg-core']:HasPlayerJob(src, stable.restrictJob) end)
    return ok and held == true
end

-- Per-stable horse limit
local function stableCap(stableName)
    local s = getStableConfig(stableName)
    return (s and s.maxHorses) or Config.MaxHorsesPerStable
end

-- Moves horses out of a stable (fired staff, deleted business). citizenid nil = everyone's.
exports('MoveHorses', function(fromStable, citizenid, toStable)
    if type(fromStable) ~= 'string' or type(toStable) ~= 'string' or not getStableConfig(toStable) then return 0 end
    if citizenid then
        MySQL.update.await('UPDATE rsg_stables_breeding SET stable = ? WHERE stable = ? AND citizenid = ?', { toStable, fromStable, citizenid })
        return MySQL.update.await('UPDATE rsg_stables_horses SET stable = ? WHERE stable = ? AND citizenid = ?', { toStable, fromStable, citizenid }) or 0
    end
    MySQL.update.await('UPDATE rsg_stables_breeding SET stable = ? WHERE stable = ?', { toStable, fromStable })
    return MySQL.update.await('UPDATE rsg_stables_horses SET stable = ? WHERE stable = ?', { toStable, fromStable }) or 0
end)
```

### 2. Access checks
In `isNearStable(src, stable, maxDist)` add as the **first** line inside the function (after `if not stable then return false end`):

```lua
    if not canUseStable(src, stable) then return false end
```

This covers buying, claiming wild horses, retrieving, breeding, collecting foals and giving horses.

In `nearestStable(src, maxDist)`, change the loop line

```lua
    for _, stable in ipairs(Config.Stables) do
```

to

```lua
    for _, stable in ipairs(Config.Stables) do if canUseStable(src, stable) then
```

and add one `end` before the loop's own `end` (so stables the player can't use are skipped when storing a horse).

In `rsg-stables:server:transferHorse`, after `if not stable then return false, locale('invalid_stable') end` add:

```lua
    if not canUseStable(source, stable) then return false, locale('invalid_stable') end
```

### 3. Per-stable limits
Replace each `Config.MaxHorsesPerStable` in `server/server.lua` with `stableCap(...)`, passing the stable name used in
the `COUNT(*)` query just above it:

| Callback | Replace with |
|---|---|
| `buyHorse` | `stableCap(stableName)` |
| `claimWildHorse` | `stableCap(stableName)` |
| `storeActive` (`atStable < ...`) | `stableCap(storeAt.name)` |
| `transferHorse` | `stableCap(newStable)` |
| `giveHorse` | `stableCap(h.stable)` |
| `collectFoal` | `stableCap(job.stable)` |

These helpers are defined in step 1, which sits above all of these callbacks.

### 4. Exempt stables don't count toward MaxOwnedHorses
Replace `countOwnedHorses` with:

```lua
local function countOwnedHorses(citizenid)
    local exempt = {}
    for _, s in ipairs(Config.Stables) do if s.capExempt then exempt[#exempt + 1] = s.name end end
    if #exempt == 0 then
        return MySQL.prepare.await('SELECT COUNT(*) FROM rsg_stables_horses WHERE citizenid = ?', { citizenid }) or 0
    end
    local marks = ('?,'):rep(#exempt):sub(1, -2)
    return MySQL.prepare.await(('SELECT COUNT(*) FROM rsg_stables_horses WHERE citizenid = ? AND (stable IS NULL OR stable NOT IN (%s))'):format(marks),
        { citizenid, table.unpack(exempt) }) or 0
end
```

Step 1 must sit above `isNearStable` (it does when placed right below `getStableConfig`), because `isNearStable` calls
`canUseStable`.

## server/training.lua

At the **end of the file** add (after the `playerDropped` handler):

```lua
-- ===================== EXPORTS (grumpy-pob: staff train other players' horses) =====================
local function horseRow(horseId)
    return MySQL.single.await('SELECT id, name, model, training, alive FROM rsg_stables_horses WHERE id = ?', { tonumber(horseId) or 0 })
end

exports('GetActiveHorse', function(citizenid)
    local h = getActiveHorse(citizenid)
    return h and { id = h.id, name = h.name, model = h.model } or nil
end)

local function canTrain(horseId, stat)
    if type(stat) ~= 'string' or not T.stats[stat] then return false, locale('training_invalid_stat') end
    local horse = horseRow(horseId)
    if not horse or (horse.alive ~= 1 and horse.alive ~= true) then return false, locale('no_active_horse') end
    local data = decode(horse.training)
    if os.time() < data.lastSession + T.session.cooldown then
        return false, locale('training_cooldown', math.ceil(((data.lastSession + T.session.cooldown) - os.time()) / 60))
    end
    if levelFor(data.stats[stat]) >= MAX_LEVEL then return false, locale('training_max_level') end
    return true, nil, horse, data
end

exports('CanTrainHorse', function(horseId, stat)
    local ok, err = canTrain(horseId, stat)
    return ok, err
end)

-- Adds xp to one stat and starts the normal session cooldown. Returns ok, summary | errText
exports('TrainHorse', function(horseId, stat, xp)
    local ok, err, horse, data = canTrain(horseId, stat)
    if not ok then return false, err end
    data.lastSession = os.time()
    local ups = addXp(horse, data, { [stat] = math.max(0, tonumber(xp) or 0) })
    local owner = MySQL.scalar.await('SELECT citizenid FROM rsg_stables_horses WHERE id = ?', { horse.id })
    local P = owner and RSGCore.Functions.GetPlayerByCitizenId(owner)
    if P then
        notifyLevelUps(P.PlayerData.source, horse.name, ups)
        TriggerClientEvent('rsg-stables:client:trainingUpdate', P.PlayerData.source, horse.id, summary(data))
    end
    return true, summary(data)
end)
```

Note: `training.lua` returns early when `Config.Training.enabled = false`, so these exports only exist with training on
(grumpy-pob then reports training as unavailable).

## client/client.lua

At the **end of the file** add:

```lua
-- ===================== REGISTERED STABLES (grumpy-pob) =====================
RegisterNetEvent('rsg-stables:client:externalStables', function(list)
    for i = #Config.Stables, 1, -1 do
        if Config.Stables[i].external then table.remove(Config.Stables, i) end
    end
    for _, s in ipairs(list or {}) do
        s.external = true
        Config.Stables[#Config.Stables + 1] = s
    end
end)

CreateThread(function() TriggerServerEvent('rsg-stables:server:requestExternalStables') end)

-- Opens the stable menu for a registered stable (the server still checks job and distance)
exports('OpenStable', function(name)
    for _, s in ipairs(Config.Stables) do
        if s.name == name then return OpenStableMenu(s) end
    end
end)
```

In the transfer sub-menu (inside `OpenStableMenu`, the loop `for _, s in ipairs(Config.Stables) do` that builds
`transferOptions`), change

```lua
                    if s.name ~= stable.name then
```

to

```lua
                    if s.name ~= stable.name and not s.restrictJob then
```

so job-only stables aren't offered as transfer targets to everyone (staff store horses there directly instead).

## Check it worked
- Create a stable business, buy it, then use **Open stable** on its NPC: the rsg-stables menu opens.
- A player without the job gets "not close to a stable" when trying to use it.
- `/storehorse` next to the business NPC stores an employee's horse there.
