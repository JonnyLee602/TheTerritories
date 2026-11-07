local RSGCore = exports['rsg-core']:GetCoreObject()

-- rsg-core server callback with return-style handlers: fn(source, ...) returns the reply values
local function registerCallback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...) cb(fn(source, ...)) end)
end
math.randomseed(os.time()) -- foal stat variance (collectFoal's inherit()) shouldn't repeat the same sequence every server restart

-- ===================== AUTO DATABASE INSTALL =====================
-- Creates every table in one go on start (same schema as installation/install.sql,
-- which is kept for manual installs).

local SCHEMA = {
    [[
CREATE TABLE IF NOT EXISTS `grumpy_livery_horses` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `stable` VARCHAR(50) DEFAULT NULL,
  `model` VARCHAR(100) NOT NULL,
  `breed_label` VARCHAR(100) NOT NULL,
  `gender` VARCHAR(6) DEFAULT NULL,
  `breed_cooldown` BIGINT(20) NOT NULL DEFAULT 0,
  `died_of_age` TINYINT(1) NOT NULL DEFAULT 0,
  `name` VARCHAR(50) NOT NULL DEFAULT 'Unnamed Horse',
  `outfit` INT(11) NOT NULL DEFAULT 0,
  `tack` TEXT DEFAULT NULL,
  `shoe_wear` FLOAT NOT NULL DEFAULT 0,
  `coat` TEXT DEFAULT NULL,
  `health` FLOAT NOT NULL DEFAULT 100,
  `stamina` FLOAT NOT NULL DEFAULT 100,
  `hunger` FLOAT NOT NULL DEFAULT 100,
  `thirst` FLOAT NOT NULL DEFAULT 100,
  `bonding` FLOAT NOT NULL DEFAULT 0,
  `training` TEXT DEFAULT NULL,
  `speed` INT(11) NOT NULL DEFAULT 50,
  `accel` INT(11) NOT NULL DEFAULT 50,
  `handling` INT(11) NOT NULL DEFAULT 50,
  `maxhealth` INT(11) NOT NULL DEFAULT 50,
  `alive` TINYINT(1) NOT NULL DEFAULT 1,
  `insured` TINYINT(1) NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 0,
  `pos_x` FLOAT DEFAULT NULL,
  `pos_y` FLOAT DEFAULT NULL,
  `pos_z` FLOAT DEFAULT NULL,
  `pos_h` FLOAT DEFAULT NULL,
  `papers` VARCHAR(8) NOT NULL DEFAULT 'genuine',
  `papers_stable` VARCHAR(100) DEFAULT NULL,
  `papers_owner` VARCHAR(100) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `stable` (`stable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
CREATE TABLE IF NOT EXISTS `grumpy_livery_breeding` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `stable` VARCHAR(50) NOT NULL,
  `parent_a` INT(11) NOT NULL,
  `parent_b` INT(11) NOT NULL,
  `ready_at` BIGINT(20) NOT NULL,
  `collected` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `stable` (`stable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
CREATE TABLE IF NOT EXISTS `grumpy_livery_races` (
  `citizenid` VARCHAR(50) NOT NULL,
  `race` VARCHAR(50) NOT NULL,
  `rider` VARCHAR(100) NOT NULL DEFAULT '',
  `horse` VARCHAR(50) NOT NULL DEFAULT '',
  `best_ms` INT(11) NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `race`),
  KEY `race_best` (`race`, `best_ms`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

-- columns added after the first release; ensures older databases get them too
local MIGRATION_COLUMNS = { 'pos_x', 'pos_y', 'pos_z', 'pos_h' }

local function ensureDatabase()
    local ok, err = pcall(MySQL.transaction.await, SCHEMA)
    if not ok or err == false then
        print(('^1[grumpy-livery] Failed to create database tables: %s - import installation/install.sql manually.^7'):format(tostring(err)))
        return
    end

    local existing = {}
    local rows = MySQL.query.await([[
        SELECT COLUMN_NAME AS col FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'grumpy_livery_horses'
    ]]) or {}
    for _, r in ipairs(rows) do existing[r.col] = true end

    for _, col in ipairs(MIGRATION_COLUMNS) do
        if not existing[col] then
            local okCol, errCol = pcall(MySQL.query.await, ('ALTER TABLE `grumpy_livery_horses` ADD COLUMN `%s` FLOAT DEFAULT NULL'):format(col))
            if not okCol then
                print(('^1[grumpy-livery] Failed to add column %s: %s^7'):format(col, tostring(errCol)))
            end
        end
    end

    if not existing.coat then
        local okCoat, errCoat = pcall(MySQL.query.await, 'ALTER TABLE `grumpy_livery_horses` ADD COLUMN `coat` TEXT DEFAULT NULL AFTER `tack`')
        if not okCoat then
            print(('^1[grumpy-livery] Failed to add column coat: %s^7'):format(tostring(errCoat)))
        end
    end

    if not existing.gender then
        pcall(MySQL.query.await, 'ALTER TABLE `grumpy_livery_horses` ADD COLUMN `gender` VARCHAR(6) DEFAULT NULL AFTER `breed_label`')
    end
    if not existing.breed_cooldown then
        pcall(MySQL.query.await, 'ALTER TABLE `grumpy_livery_horses` ADD COLUMN `breed_cooldown` BIGINT(20) NOT NULL DEFAULT 0 AFTER `gender`')
    end
    if not existing.died_of_age then
        pcall(MySQL.query.await, 'ALTER TABLE `grumpy_livery_horses` ADD COLUMN `died_of_age` TINYINT(1) NOT NULL DEFAULT 0 AFTER `breed_cooldown`')
    end
    if not existing.training then
        pcall(MySQL.query.await, 'ALTER TABLE `grumpy_livery_horses` ADD COLUMN `training` TEXT DEFAULT NULL AFTER `bonding`')
    end
    if not existing.shoe_wear then
        pcall(MySQL.query.await, 'ALTER TABLE `grumpy_livery_horses` ADD COLUMN `shoe_wear` FLOAT NOT NULL DEFAULT 0 AFTER `tack`')
    end
    -- papers (grumpy-livery 1.1.0): 'genuine' | 'forged' | 'none'; horses from before papers existed count as genuine
    if not existing.papers then
        pcall(MySQL.query.await, "ALTER TABLE `grumpy_livery_horses` ADD COLUMN `papers` VARCHAR(8) NOT NULL DEFAULT 'genuine' AFTER `pos_h`")
    end
    if not existing.papers_stable then
        pcall(MySQL.query.await, 'ALTER TABLE `grumpy_livery_horses` ADD COLUMN `papers_stable` VARCHAR(100) DEFAULT NULL AFTER `papers`')
    end
    if not existing.papers_owner then
        pcall(MySQL.query.await, 'ALTER TABLE `grumpy_livery_horses` ADD COLUMN `papers_owner` VARCHAR(100) DEFAULT NULL AFTER `papers_stable`')
    end
    -- horses bought before genders existed get a random one
    pcall(MySQL.query.await, "UPDATE `grumpy_livery_horses` SET `gender` = IF(RAND() < 0.5, 'male', 'female') WHERE `gender` IS NULL")

    print('^2[grumpy-livery] Database ready.^7')
end

MySQL.ready(ensureDatabase)


-- ===================== HELPERS =====================

local function getStableConfig(stableName)
    for _, s in ipairs(Config.Stables) do
        if s.name == stableName then return s end
    end
    return nil
end

-- ===================== REGISTERED STABLES (other resources, e.g. grumpy-pob) =====================
-- [grumpy-pob hook]
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
    TriggerClientEvent('grumpy-livery:client:externalStables', target or -1, externalList())
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

RegisterNetEvent('grumpy-livery:server:requestExternalStables', function()
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
        MySQL.update.await('UPDATE grumpy_livery_breeding SET stable = ? WHERE stable = ? AND citizenid = ?', { toStable, fromStable, citizenid })
        return MySQL.update.await('UPDATE grumpy_livery_horses SET stable = ? WHERE stable = ? AND citizenid = ?', { toStable, fromStable, citizenid }) or 0
    end
    MySQL.update.await('UPDATE grumpy_livery_breeding SET stable = ? WHERE stable = ?', { toStable, fromStable })
    return MySQL.update.await('UPDATE grumpy_livery_horses SET stable = ? WHERE stable = ?', { toStable, fromStable }) or 0
end)

-- breed handling class -> stored 0..100 handling value (unknown classes fall back to 50)
local HandlingMap = {
    Heavy = 35,
    Standard = 50,
    Race = 65,
    Elite = 80,
}

local function breedHandlingValue(breed)
    return HandlingMap[breed.handling] or tonumber(breed.handling) or 50
end

-- Server-side proximity check so stable actions can't be fired remotely by a modified client
local STABLE_INTERACT_DISTANCE = 15.0

local function isNearStable(src, stable, maxDist)
    if not stable then return false end
    if not canUseStable(src, stable) then return false end -- [grumpy-pob hook]
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    maxDist = maxDist or STABLE_INTERACT_DISTANCE
    for _, point in ipairs({ stable.pedCoords, stable.storeCoords, stable.previewCoords }) do
        if point and #(coords - vector3(point.x, point.y, point.z)) <= maxDist then
            return true
        end
    end
    return false
end

local function nearStableByName(src, stableName)
    return isNearStable(src, getStableConfig(stableName))
end

-- closest stable to the player within maxDist (nil if none)
local function nearestStable(src, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    local best, bestDist = nil, maxDist
    for _, stable in ipairs(Config.Stables) do if canUseStable(src, stable) then -- [grumpy-pob hook]
        for _, point in ipairs({ stable.pedCoords, stable.storeCoords, stable.previewCoords }) do
            if point then
                local d = #(coords - vector3(point.x, point.y, point.z))
                if d <= bestDist then best, bestDist = stable, d end
            end
        end
    end end
    return best
end

local function toId(v)
    v = tonumber(v)
    if not v or v < 1 or v ~= math.floor(v) then return nil end
    return v
end

local function randomGender()
    return math.random(1, 2) == 1 and 'male' or 'female'
end

-- true while the horse is a parent in a breeding whose foal hasn't been collected
local function isHorseBreeding(horseId)
    if not (Config.Breeding.enabled and Config.Breeding.lockParents) then return false end
    return MySQL.single.await('SELECT id FROM grumpy_livery_breeding WHERE (parent_a = ? OR parent_b = ?) AND collected = 0', { horseId, horseId }) ~= nil
end

-- 'young' | 'adult' | 'old' from days owned (nil when aging is disabled)
local function horseStage(ageDays)
    local cfg = Config.HorseAging
    if not (cfg and cfg.enabled) then return nil end
    ageDays = tonumber(ageDays) or 0
    if ageDays < (cfg.youngUntilDays or 7) then return 'young' end
    if ageDays >= (cfg.oldFromDays or 60) then return 'old' end
    return 'adult'
end

local AGE_SQL = 'DATEDIFF(NOW(), created_at) AS age_days'

-- Config.Breeds stores signed backtick hashes while the server can return unsigned ones: compare unsigned
local function getBreedConfig(model)
    model = tonumber(model)
    if not model then return nil end
    model = math.floor(model) & 0xFFFFFFFF
    for _, b in ipairs(Config.Breeds) do
        if (math.floor(tonumber(b.model) or 0) & 0xFFFFFFFF) == model then return b end
    end
    return nil
end

-- Livery purchases: price by market, standing and account (server/money.lua). stable = config entry or name.
-- Returns ok, paid, account (paid/account are what to refund if a later step fails).
local function chargePlayer(Player, amount, stable, reason)
    if type(stable) ~= 'table' then stable = getStableConfig(stable) end
    return LiveryMoney.Charge(Player.PlayerData.source, stable, amount, reason)
end

-- Flat charge in Config.PaymentAccount: player-to-player deals (gift fee, asking price), never repriced
local function chargeFlat(Player, amount)
    local account = Config.PaymentAccount
    local funds = Player.PlayerData.money[account] or 0
    if funds < amount then return false end
    local removed = Player.Functions.RemoveMoney(account, amount, 'grumpy-livery')
    if removed == false then return false end
    return true
end

-- ===================== PAPERS =====================
-- Every horse row carries papers: 'genuine' (legal stables, foals of papered parents, registered wild horses),
-- 'forged' (bought with forged papers at an underground livery) or 'none'. Forged papers read exactly like
-- genuine ones: they name a random legal stable as the place of registration.
local function isUnderground(stable) return LiveryMoney.Market(stable) == 'underground' end

local function legalStableLabel()
    local list = {}
    for _, s in ipairs(Config.Stables) do
        if not isUnderground(s) and not s.external then list[#list + 1] = s.label end
    end
    return list[math.random(1, math.max(1, #list))] or 'Valentine Stables'
end

local function ownerName(Player)
    local c = Player and Player.PlayerData and Player.PlayerData.charinfo
    if c and c.firstname then return ('%s %s'):format(c.firstname, c.lastname or '') end
    return Player and GetPlayerName(Player.PlayerData.source) or '?'
end

local locks = {}
local function withLock(key, fn)
    while locks[key] do Wait(25) end
    locks[key] = true
    local ok, r1, r2 = pcall(fn)
    locks[key] = nil
    if not ok then
        print(('[grumpy-livery] ERROR in locked section (%s): %s'):format(key, tostring(r1)))
        return false, locale('generic_error')
    end
    return r1, r2
end

-- [grumpy-pob hook] horses in capExempt stables don't count toward MaxOwnedHorses
local function countOwnedHorses(citizenid)
    local exempt = {}
    for _, s in ipairs(Config.Stables) do if s.capExempt then exempt[#exempt + 1] = s.name end end
    if #exempt == 0 then
        return MySQL.prepare.await('SELECT COUNT(*) FROM grumpy_livery_horses WHERE citizenid = ?', { citizenid }) or 0
    end
    local marks = ('?,'):rep(#exempt):sub(1, -2)
    return MySQL.prepare.await(('SELECT COUNT(*) FROM grumpy_livery_horses WHERE citizenid = ? AND (stable IS NULL OR stable NOT IN (%s))'):format(marks),
        { citizenid, table.unpack(exempt) }) or 0
end

local function isTrue(v)
    return v == true or v == 1
end

-- true if the entity's model is the stored horse model (hashes compared unsigned)
local function isHorseModel(entity, model)
    model = tonumber(model)
    if not model or not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    return (GetEntityModel(entity) & 0xFFFFFFFF) == (math.floor(model) & 0xFFFFFFFF)
end

local tackItemIndex = {}
for categoryKey, items in pairs(Config.TackItems) do
    tackItemIndex[categoryKey] = {}
    for _, item in ipairs(items) do
        tackItemIndex[categoryKey][tostring(item.hash)] = item
    end
end

-- tack JSON a new horse starts with (shoes fitted when Config.Horseshoes.newHorsesShod)
local function newHorseTack()
    local cfg = Config.Horseshoes
    local shoes = Config.TackItems.horseshoe and Config.TackItems.horseshoe[1]
    if cfg and cfg.enabled and cfg.newHorsesShod and shoes then
        return json.encode({ horseshoe = shoes.hash })
    end
    return '{}'
end

local function getTackItem(categoryKey, itemHash)
    local byHash = tackItemIndex[categoryKey]
    if not byHash then return nil end
    return byHash[tostring(itemHash)]
end

local function sanitizeName(name)
    if type(name) ~= 'string' then return nil end
    -- strip control chars and markup characters (names are shown in markdown/NUI dialogs to other players)
    name = name:gsub('[%c<>%[%]%*_`#|\\]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return nil end
    return name
end

-- true if the horse's saddlebag stash still holds items
local function saddlebagsHaveItems(horseId)
    local stash = exports['rsg-inventory']:GetInventory('horse_' .. horseId)
    return stash and type(stash.items) == 'table' and next(stash.items) ~= nil
end

local function deleteSaddlebags(horseId)
    local stashId = 'horse_' .. horseId
    pcall(function() exports['rsg-inventory']:DeleteInventory(stashId) end)
    MySQL.update('DELETE FROM inventories WHERE identifier = ?', { stashId })
end

local function decodeTack(raw)
    if not raw or raw == '' then return {} end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == 'table' then return t end
    return {}
end

-- ===================== ACTIVE HORSE SESSIONS (server-authoritative needs) =====================

local CARE_COOLDOWN = 60000 -- ms; mirrors client.lua's CARE_COOLDOWN, enforced here too so a
                             -- modified client can't spam feed/water/brush via direct server events
local activeSessions = {}

local function startSession(citizenid, horseId, hunger, thirst, bonding, model)
    activeSessions[citizenid] = {
        horseId = horseId,
        model = model,
        hunger = math.max(0, math.min(100, tonumber(hunger) or 100)),
        thirst = math.max(0, math.min(100, tonumber(thirst) or 100)),
        bonding = math.max(0, math.min(100, tonumber(bonding) or 0)),
        lastDecayAt = os.time() * 1000,
        lastFeedAt = 0, lastWaterAt = 0, lastBrushAt = 0,
    }
end

local function endSession(citizenid)
    activeSessions[citizenid] = nil
end

local function applyDecay(session)
    if not (Config.HorseNeeds and Config.HorseNeeds.enabled) then return end
    local now = os.time() * 1000
    local interval = Config.HorseNeeds.decayInterval or 60000
    local elapsed = now - (session.lastDecayAt or now)
    local ticks = math.floor(elapsed / interval)
    if ticks <= 0 then return end
    session.hunger = math.max(0, session.hunger - ticks * (Config.HorseNeeds.hungerDecayPerTick or 0))
    session.thirst = math.max(0, session.thirst - ticks * (Config.HorseNeeds.thirstDecayPerTick or 0))
    session.lastDecayAt = session.lastDecayAt + ticks * interval
end

-- Writes the in-memory needs of an active horse back to the DB (horse stays active = 1)
local function persistSession(citizenid)
    local session = activeSessions[citizenid]
    if not session then return end
    applyDecay(session)
    MySQL.update('UPDATE grumpy_livery_horses SET hunger = ?, thirst = ?, bonding = ? WHERE id = ? AND citizenid = ? AND active = 1', {
        session.hunger, session.thirst, session.bonding, session.horseId, citizenid
    })
end


-- ===================== ACTIVE HORSE ENTITY CHECK =====================
-- true if netId is a live entity of the session's horse model within maxDist of the player
local function activeHorseNear(src, session, netId, maxDist)
    local function fail(why)
        if Config.DebugHorseChecks then print(('[grumpy-livery] horse check failed for %s: %s'):format(src, why)) end
        return false
    end
    netId = tonumber(netId)
    if not session then return fail('no session') end
    if not netId then return fail('client sent no net id (horse not networked)') end
    local entity = NetworkGetEntityFromNetworkId(math.floor(netId))
    if not entity or entity == 0 or not DoesEntityExist(entity) then return fail('net id ' .. netId .. ' has no entity on server') end
    -- no server-side health check: RedM's server GetEntityHealth returns 0 for peds, so it rejected every live horse.
    -- Dead horses are blocked on the client and by the session's own death/down handling.
    if session.model and not isHorseModel(entity, session.model) then
        return fail(('model mismatch: entity %s, session %s'):format(GetEntityModel(entity), tostring(session.model)))
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return fail('no player ped') end
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(entity))
    if dist > maxDist then return fail(('too far: %.1fm (max %.1fm)'):format(dist, maxDist)) end
    return true, entity
end

-- ===================== PLAYER CLEANUP =====================
-- Server-only event (fired by rsg-core). Previously a RegisterNetEvent, which let any client
-- pass another player's id and wipe their horse session.
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        persistSession(Player.PlayerData.citizenid)
        endSession(Player.PlayerData.citizenid)
    end
end)

-- ===================== ACTIVE HORSE POSITION =====================

RegisterNetEvent('grumpy-livery:server:saveHorsePosition', function(horseId, x, y, z, h, health)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    local session = activeSessions[citizenid]
    horseId = tonumber(horseId)
    if not session or not horseId or session.horseId ~= horseId then return end

    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h) or 0.0
    if not (x and y and z) then return end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then return end

    local now = GetGameTimer()
    if session.lastPosSaveAt and (now - session.lastPosSaveAt) < 2000 then return end
    session.lastPosSaveAt = now

    applyDecay(session)
    health = math.max(0, math.min(100, tonumber(health) or 100))

    MySQL.update('UPDATE grumpy_livery_horses SET pos_x = ?, pos_y = ?, pos_z = ?, pos_h = ?, health = ?, hunger = ?, thirst = ?, bonding = ? WHERE id = ? AND citizenid = ? AND active = 1', {
        x, y, z, h, health, session.hunger, session.thirst, session.bonding, horseId, citizenid
    })
end)

-- ===================== CALLBACKS =====================

registerCallback('grumpy-livery:server:getStableHorses', function(source, stableName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not getStableConfig(stableName) then return {} end
    local rows = MySQL.query.await('SELECT *, ' .. AGE_SQL .. ' FROM grumpy_livery_horses WHERE citizenid = ? AND stable = ? AND active = 0', {
        Player.PlayerData.citizenid, stableName
    }) or {}
    for _, r in ipairs(rows) do r.stage = horseStage(r.age_days) end
    return rows
end)

-- Called on login: if the player left a horse out, keep it out and hand its data (incl. last
-- saved position) back to the client so a whistle can bring it to them.
registerCallback('grumpy-livery:server:restoreActiveHorse', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local citizenid = Player.PlayerData.citizenid

    return withLock('citizen:' .. citizenid, function()
        local row = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM grumpy_livery_horses WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
        if not row then
            endSession(citizenid)
            return nil
        end

        if not isTrue(row.alive) then
            MySQL.update.await('UPDATE grumpy_livery_horses SET active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL WHERE id = ?', { row.id })
            endSession(citizenid)
            return nil
        end

        -- keep an existing session for this horse: re-calling this callback must not reset
        -- the feed/water/brush cooldowns or roll hunger/thirst back to stale DB values
        local session = activeSessions[citizenid]
        if session and session.horseId == row.id then
            session.model = row.model
            applyDecay(session)
            row.hunger, row.thirst, row.bonding = session.hunger, session.thirst, session.bonding
        else
            startSession(citizenid, row.id, row.hunger, row.thirst, row.bonding, row.model)
        end
        return row
    end)
end)

-- ===================== HORSE FEED ITEMS =====================
for _, feedItem in ipairs(Config.HorseFeedItems) do
    RSGCore.Functions.CreateUseableItem(feedItem.item, function(source)
        TriggerClientEvent('grumpy-livery:client:useFeed', source, feedItem.item)
    end)
end

-- ===================== HORSE BRUSH ITEM =====================
RSGCore.Functions.CreateUseableItem(Config.HorseBrushItem or 'horse_brush', function(source)
    TriggerClientEvent('grumpy-livery:client:useBrush', source)
end)

-- ===================== HORSE LANTERN =====================
if Config.HorseLantern and Config.HorseLantern.enabled then
    RSGCore.Functions.CreateUseableItem(Config.HorseLantern.item, function(source)
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then return end
        TriggerClientEvent('grumpy-livery:client:useLantern', source)
    end)
end

-- toggles the lantern on the player's active horse and saves it in the horse's tack
registerCallback('grumpy-livery:server:toggleLantern', function(source)
    local cfg = Config.HorseLantern
    if not (cfg and cfg.enabled) then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    local citizenid = Player.PlayerData.citizenid

    local session = activeSessions[citizenid]
    if not session then return false, locale('no_active_horse') end

    local lantern = Player.Functions.GetItemByName(cfg.item)
    if not lantern or (lantern.amount or 0) < 1 then return false end

    return withLock('citizen:' .. citizenid, function()
        local row = MySQL.single.await('SELECT tack FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND active = 1 LIMIT 1', { session.horseId, citizenid })
        if not row then return false, locale('no_active_horse') end
        local tack = decodeTack(row.tack)
        local on = not tack.lantern
        tack.lantern = on or nil
        MySQL.update.await('UPDATE grumpy_livery_horses SET tack = ? WHERE id = ?', { json.encode(tack), session.horseId })
        return true, on
    end)
end)

-- ===================== HORSE STIMULANT =====================
if Config.HorseStimulant and Config.HorseStimulant.enabled then
    RSGCore.Functions.CreateUseableItem(Config.HorseStimulant.item, function(source)
        TriggerClientEvent('grumpy-livery:client:useStimulant', source)
    end)
end

registerCallback('grumpy-livery:server:useStimulant', function(source, horseNetId)
    local cfg = Config.HorseStimulant
    if not (cfg and cfg.enabled) then return false, locale('stimulant_disabled') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end
    -- the horse must really be next to the player (item was otherwise consumable from anywhere)
    if not activeHorseNear(source, session, horseNetId, (cfg.useDistance or 3.0) + 3.0) then return false, locale('must_be_near_horse') end

    local now = os.time()
    if not cfg.allowReuse and (session.stimulantUntil or 0) > now then
        local left = session.stimulantUntil - now
        return false, locale('stimulant_already_active', left // 60, left % 60)
    end

    if not Player.Functions.GetItemByName(cfg.item) then
        return false, locale('missing_item', cfg.label)
    end
    if not Player.Functions.RemoveItem(cfg.item, 1, nil, 'grumpy-livery-stimulant') then
        return false, locale('item_use_failed')
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[cfg.item], 'remove', 1)

    session.stimulantUntil = now + cfg.duration
    return true, { duration = cfg.duration }
end)

registerCallback('grumpy-livery:server:feedHorse', function(source, preferredItem, horseNetId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end
    if not activeHorseNear(source, session, horseNetId, (Config.HorseBrushDistance or 3.0) + 3.0) then return false, locale('must_be_near_horse') end

    local now = os.time() * 1000
    if now - (session.lastFeedAt or 0) < CARE_COOLDOWN then
        return false, locale('not_hungry')
    end

    -- item used from the inventory is tried first, then any other feed item the player carries
    local feedList = {}
    for _, feedItem in ipairs(Config.HorseFeedItems) do
        if feedItem.item == preferredItem then table.insert(feedList, 1, feedItem) else feedList[#feedList + 1] = feedItem end
    end

    for _, feedItem in ipairs(feedList) do
        local owned = Player.Functions.GetItemByName(feedItem.item)
        if owned and (owned.amount or 0) > 0 then
            local removed = Player.Functions.RemoveItem(feedItem.item, 1, nil, 'grumpy-livery-feed')
            if removed then
                TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[feedItem.item], 'remove', 1)
                applyDecay(session)
                session.hunger = math.max(0, math.min(100, session.hunger + (feedItem.hunger or 0)))
                if Config.HorseBonding.enabled then
                    session.bonding = math.max(0, math.min(100, session.bonding + (Config.HorseBonding.feedGain or 0)))
                end
                session.lastFeedAt = now
                return true, {
                    label = feedItem.label,
                    health = feedItem.health,
                    stamina = feedItem.stamina,
                    hunger = session.hunger,
                    bonding = session.bonding,
                }
            end
        end
    end

    return false, locale('need_feed')
end)

registerCallback('grumpy-livery:server:waterHorse', function(source, horseNetId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end
    if not activeHorseNear(source, session, horseNetId, (Config.HorseBrushDistance or 3.0) + 3.0) then return false, locale('must_be_near_horse') end

    local now = os.time() * 1000
    if now - (session.lastWaterAt or 0) < CARE_COOLDOWN then
        return false, locale('not_thirsty')
    end

    for _, drinkItem in ipairs(Config.HorseDrinkItems) do
        local owned = Player.Functions.GetItemByName(drinkItem.item)
        if owned and (owned.amount or 0) > 0 then
            local removed = Player.Functions.RemoveItem(drinkItem.item, 1, nil, 'grumpy-livery-water')
            if removed then
                TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[drinkItem.item], 'remove', 1)
                applyDecay(session)
                session.thirst = math.max(0, math.min(100, session.thirst + (drinkItem.thirst or 0)))
                if Config.HorseBonding.enabled then
                    session.bonding = math.max(0, math.min(100, session.bonding + (Config.HorseBonding.waterGain or 0)))
                end
                session.lastWaterAt = now
                return true, {
                    label = drinkItem.label,
                    stamina = drinkItem.stamina,
                    thirst = session.thirst,
                    bonding = session.bonding,
                }
            end
        end
    end

    return false, locale('need_water')
end)

-- Horse drank from a river/lake/trough on its own (no item needed)
registerCallback('grumpy-livery:server:naturalDrink', function(source, horseNetId)
    local cfg = Config.HorseNaturalDrink
    if not (cfg and cfg.enabled) then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false end
    -- the horse must really be out, alive and near its owner (stops free refills from anywhere)
    local near = activeHorseNear(source, session, horseNetId, (cfg.maxPlayerDistance or 50.0))
    if not near then return false end

    local now = os.time() * 1000
    if now - (session.lastNaturalDrinkAt or 0) < (cfg.cooldown or 120000) then return false end

    applyDecay(session)
    if session.thirst > (cfg.thirstThreshold or 40) then return false end

    session.thirst = math.max(session.thirst, math.min(100, cfg.thirstRestore or 100))
    session.lastNaturalDrinkAt = now
    return true, { thirst = session.thirst }
end)

registerCallback('grumpy-livery:server:naturalGraze', function(source, horseNetId)
    local cfg = Config.HorseNaturalGraze
    if not (cfg and cfg.enabled) then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false end
    -- the horse must really be out, alive and near its owner (stops free refills from anywhere)
    local near = activeHorseNear(source, session, horseNetId, (cfg.maxPlayerDistance or 50.0))
    if not near then return false end

    local now = os.time() * 1000
    if now - (session.lastNaturalGrazeAt or 0) < (cfg.cooldown or 120000) then return false end

    applyDecay(session)
    if session.hunger > (cfg.hungerThreshold or 40) then return false end

    session.hunger = math.max(session.hunger, math.min(100, cfg.hungerRestore or 100))
    session.lastNaturalGrazeAt = now
    return true, { hunger = session.hunger }
end)

registerCallback('grumpy-livery:server:brushHorse', function(source, horseNetId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end
    if not activeHorseNear(source, session, horseNetId, (Config.HorseBrushDistance or 3.0) + 3.0) then return false, locale('must_be_near_horse') end

    local now = os.time() * 1000
    if now - (session.lastBrushAt or 0) < CARE_COOLDOWN then
        return false, locale('already_clean')
    end

    local brushItem = Config.HorseBrushItem or 'horse_brush'
    local brush = Player.Functions.GetItemByName(brushItem)
    if not brush or (brush.amount or 0) < 1 then
        return false, locale('need_brush')
    end

    session.lastBrushAt = now
    if Config.HorseBonding.enabled then
        applyDecay(session)
        session.bonding = math.max(0, math.min(100, session.bonding + (Config.HorseBonding.brushGain or 0)))
    end

    return true, { bonding = session.bonding }
end)

registerCallback('grumpy-livery:server:buyHorse', function(source, stableName, model, horseName, outfit, gender, withPapers)
    if gender ~= 'male' and gender ~= 'female' then gender = randomGender() end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local stable = getStableConfig(stableName)
    if not stable then return false, locale('invalid_stable') end

    if not isNearStable(source, stable) then return false, locale('not_close_to_stable') end

    local breed = getBreedConfig(model)
    if not breed then return false, locale('invalid_breed') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local owned = countOwnedHorses(Player.PlayerData.citizenid)
        if owned >= Config.MaxOwnedHorses then
            return false, locale('max_horses_owned', Config.MaxOwnedHorses)
        end

        return withLock('stable:' .. stableName, function()
            local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM grumpy_livery_horses WHERE citizenid = ? AND stable = ?', { Player.PlayerData.citizenid, stableName })
            if atStable and atStable >= stableCap(stableName) then
                return false, locale('stable_full')
            end

            -- papers: genuine at legal stables; at an underground livery forged (optional, for a fee) or none
            local papers, papersStable, price = 'genuine', stable.label, tonumber(breed.price) or 0
            if isUnderground(stable) then
                if withPapers == true and Config.Papers.forgedPercent then
                    papers, papersStable = 'forged', legalStableLabel()
                    price = price + price * Config.Papers.forgedPercent
                else
                    papers, papersStable = 'none', nil
                end
            end

            local paidOk, paid, account = chargePlayer(Player, price, stable, 'grumpy-livery-buy-horse')
            if not paidOk then
                return false, locale('insufficient_funds')
            end

            local safeName = sanitizeName(horseName) or locale('unnamed_horse')
            safeName = safeName:sub(1, 40)

            local maxOutfits = breed.outfits or 1
            local safeOutfit = math.floor(tonumber(outfit) or 0)
            if safeOutfit < 0 or safeOutfit >= maxOutfits then safeOutfit = 0 end

            local ok, insertId = pcall(function()
                return MySQL.insert.await([[
                    INSERT INTO grumpy_livery_horses
                        (citizenid, stable, model, breed_label, gender, name, outfit, tack, health, stamina, speed, accel, handling, maxhealth, alive, insured, active, papers, papers_stable, papers_owner)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 100, 100, ?, ?, ?, ?, 1, 0, 0, ?, ?, ?)
                ]], {
                    Player.PlayerData.citizenid, stableName, breed.model, breed.label, gender, safeName, safeOutfit, newHorseTack(),
                    breed.speed, breed.acceleration, breedHandlingValue(breed), breed.health,
                    papers, papersStable, papers ~= 'none' and ownerName(Player) or nil
                })
            end)

            if not ok or not insertId or insertId == 0 then
                print(('[grumpy-livery] ERROR: buyHorse insert failed for citizenid %s: %s'):format(
                    Player.PlayerData.citizenid, tostring(insertId)
                ))
                LiveryMoney.Refund(source, account, paid)
                return false, locale('buy_save_failed')
            end

            return true, insertId
        end)
    end)
end)

-- ===================== WILD HORSE CLAIM =====================
-- brokenWild[src] = { netId = int, at = os.time() }  (one pending horse per player)
local brokenWild = {}
local POP_MISSION = 7 -- population type of script-created peds (owned / spawned horses)

local function isClaimableEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if GetEntityType(entity) ~= 1 then return false end -- must be a ped
    if GetEntityPopulationType and GetEntityPopulationType(entity) == POP_MISSION then return false end
    if IsPedAPlayer(entity) then return false end
    return true
end

RegisterNetEvent('grumpy-livery:server:wildHorseBroken', function(netId)
    local src = source
    if not (Config.WildHorse and Config.WildHorse.enabled) then return end
    netId = toId(netId)
    if not netId then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not isClaimableEntity(entity) then return end
    if not getBreedConfig(GetEntityModel(entity)) then return end
    -- must be next to the horse when it's broken
    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity))
    if dist > 5.0 then return end
    -- the same horse can't be registered by two players
    for other, rec in pairs(brokenWild) do
        if other ~= src and rec.netId == netId then return end
    end
    brokenWild[src] = { netId = netId, at = os.time() }
end)

registerCallback('grumpy-livery:server:claimWildHorse', function(source, stableName, netId, horseName)
    local cfg = Config.WildHorse
    if not (cfg and cfg.enabled) then return false, locale('wild_not_claimable') end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local stable = getStableConfig(stableName)
    if not stable then return false, locale('invalid_stable') end
    if not isNearStable(source, stable) then return false, locale('not_close_to_stable') end

    netId = toId(netId)
    local rec = brokenWild[source]
    if not netId or not rec or rec.netId ~= netId then return false, locale('wild_not_broken') end
    if os.time() - rec.at > (cfg.claimWindow or 1800) then
        brokenWild[source] = nil
        return false, locale('wild_expired')
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not isClaimableEntity(entity) then
        brokenWild[source] = nil
        return false, locale('wild_not_claimable')
    end

    local model = GetEntityModel(entity)
    local breed = getBreedConfig(model)
    if not breed then return false, locale('wild_not_claimable') end

    local horseCoords = GetEntityCoords(entity)
    local maxDist = cfg.horseDistance or 15.0
    if #(GetEntityCoords(GetPlayerPed(source)) - horseCoords) > maxDist
        or not isNearStable(source, stable, STABLE_INTERACT_DISTANCE + maxDist) then
        return false, locale('wild_too_far')
    end

    local citizenid = Player.PlayerData.citizenid
    return withLock('citizen:' .. citizenid, function()
        if countOwnedHorses(citizenid) >= Config.MaxOwnedHorses then
            return false, locale('max_horses_owned', Config.MaxOwnedHorses)
        end
        return withLock('stable:' .. stableName, function()
            local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM grumpy_livery_horses WHERE citizenid = ? AND stable = ?', { citizenid, stableName })
            if atStable and atStable >= stableCap(stableName) then
                return false, locale('stable_full')
            end

            -- registration fee = genuine papers; an underground livery registers nothing (no papers, no fee)
            local underground = isUnderground(stable)
            local fee = underground and 0 or (tonumber(cfg.claimFee) or 0)
            local paid, account = 0, nil
            if fee > 0 then
                local paidOk
                paidOk, paid, account = chargePlayer(Player, fee, stable, 'grumpy-livery-register')
                if not paidOk then return false, locale('insufficient_funds') end
            end

            local safeName = (sanitizeName(horseName) or locale('unnamed_horse')):sub(1, 40)

            local ok, insertId = pcall(function()
                return MySQL.insert.await([[
                    INSERT INTO grumpy_livery_horses
                        (citizenid, stable, model, breed_label, gender, name, outfit, tack, health, stamina, speed, accel, handling, maxhealth, alive, insured, active, papers, papers_stable, papers_owner)
                    VALUES (?, ?, ?, ?, ?, ?, 0, '{}', 100, 100, ?, ?, ?, ?, 1, 0, 0, ?, ?, ?)
                ]], {
                    citizenid, stableName, breed.model, breed.label, randomGender(), safeName,
                    breed.speed, breed.acceleration, breedHandlingValue(breed), breed.health,
                    underground and 'none' or 'genuine', not underground and stable.label or nil, not underground and ownerName(Player) or nil
                })
            end)

            if not ok or not insertId or insertId == 0 then
                print(('[grumpy-livery] ERROR: claimWildHorse insert failed for citizenid %s: %s'):format(citizenid, tostring(insertId)))
                if account then LiveryMoney.Refund(source, account, paid) end
                return false, locale('buy_save_failed')
            end

            brokenWild[source] = nil
            -- the wild horse goes into the stable: remove the world entity
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            return true, safeName
        end)
    end)
end)

registerCallback('grumpy-livery:server:retrieveHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.active) then return false, locale('horse_already_out') end
        if not isTrue(horse.alive) then return false, locale('horse_dead_revive_first') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end
        if isHorseBreeding(horseId) then return false, locale('horse_is_breeding') end

        local existingActive = MySQL.single.await('SELECT id FROM grumpy_livery_horses WHERE citizenid = ? AND active = 1', {
            Player.PlayerData.citizenid
        })
        if existingActive then return false, locale('already_have_horse') end

        MySQL.update.await('UPDATE grumpy_livery_horses SET active = 1 WHERE id = ?', { horseId })
        startSession(Player.PlayerData.citizenid, horse.id, horse.hunger, horse.thirst, horse.bonding, horse.model)

        return true, horse
    end)
end)

-- Shared by normal store (must be at a stable) and flee-store (Config.HorseFlee.storeOnFlee)
local function storeActive(source, horseId, health, stamina, requireStable)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_out') end
    local storeAt
    if requireStable then
        storeAt = nearestStable(source, (Config.StoreDistance or 8.0) + 10.0)
        if not storeAt then return false, locale('not_close_to_stable') end
    end
    local citizenid = Player.PlayerData.citizenid

    return withLock('citizen:' .. citizenid, function()
        local horse = MySQL.single.await('SELECT id, stable FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND active = 1', {
            horseId, citizenid
        })
        if not horse then return false, locale('horse_not_out') end

        -- the horse is kept at the stable it was put away at (falls back to its old stable if that one is full)
        local stableName = horse.stable
        if storeAt and storeAt.name ~= horse.stable then
            local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM grumpy_livery_horses WHERE citizenid = ? AND stable = ?', { citizenid, storeAt.name })
            if not atStable or atStable < stableCap(storeAt.name) then stableName = storeAt.name end
        end

        health = math.max(0, math.min(100, tonumber(health) or 100))
        stamina = math.max(0, math.min(100, tonumber(stamina) or 100))

        local session = activeSessions[citizenid]
        local hunger, thirst, bonding = 100, 100, 0
        if session then
            applyDecay(session)
            hunger, thirst, bonding = session.hunger, session.thirst, session.bonding
        end

        MySQL.update.await('UPDATE grumpy_livery_horses SET active = 0, stable = ?, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL, health = ?, stamina = ?, hunger = ?, thirst = ?, bonding = ? WHERE id = ?', {
            stableName, health, stamina, hunger, thirst, bonding, horseId
        })
        endSession(citizenid)
        return true
    end)
end

registerCallback('grumpy-livery:server:storeHorse', function(source, horseId, health, stamina)
    return storeActive(source, horseId, health, stamina, true)
end)

registerCallback('grumpy-livery:server:fleeStoreHorse', function(source, horseId, health, stamina)
    if not (Config.HorseFlee.enabled and Config.HorseFlee.storeOnFlee) then return false end
    return storeActive(source, horseId, health, stamina, false)
end)

-- ===================== DEATH VERIFICATION =====================
-- RedM's server GetEntityHealth returns 0 for every ped, so the server can't see whether a horse is dead.
-- Instead, other players who have the horse streamed in are asked; if any of them sees it alive the report
-- is rejected. If nobody else is around the report is accepted, but the horse entity is deleted, so a
-- false report only costs the player their horse/insurance and gains nothing.
local WITNESS_RANGE, WITNESS_MAX, WITNESS_TIMEOUT = 150.0, 4, 2500

local function witnessesSayAlive(src, entity, netId)
    local coords = GetEntityCoords(entity)
    local list = {}
    for _, pid in ipairs(GetPlayers()) do
        pid = tonumber(pid)
        if pid ~= src then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 then
                local d = #(GetEntityCoords(ped) - coords)
                if d <= WITNESS_RANGE then list[#list + 1] = { id = pid, d = d } end
            end
        end
    end
    if #list == 0 then return false end
    table.sort(list, function(a, b) return a.d < b.d end)

    local alive, pending = false, math.min(#list, WITNESS_MAX)
    for i = 1, pending do
        RSGCore.Functions.TriggerClientCallback('grumpy-livery:client:isHorseDead', list[i].id, function(dead)
            if dead == false then alive = true end -- nil = witness doesn't have the horse streamed: no vote
            pending = pending - 1
        end, netId)
    end
    local deadline = GetGameTimer() + WITNESS_TIMEOUT
    while pending > 0 and not alive and GetGameTimer() < deadline do Wait(100) end
    if alive then
        print(('[grumpy-livery] player %s reported horse (net %s) dead/down but a nearby player sees it alive - rejected'):format(src, netId))
    end
    return alive
end

local killHorseRecord -- defined below

registerCallback('grumpy-livery:server:horseDied', function(source, horseId, netId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    horseId = toId(horseId)
    if not horseId then return false end

    -- a living horse can't be reported dead (stops a free insured heal + store-from-anywhere)
    -- the report must point at an existing entity (a missing netId used to skip this check)
    netId = toId(netId)
    local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if entity == 0 or not DoesEntityExist(entity) then
        return false
    end
    if witnessesSayAlive(source, entity, netId) then return false end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        -- only the horse that is actually out can die (stops a client killing/"insurance-healing" stabled horses)
        local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND active = 1', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false end
        -- the dead entity must be this horse's model (stops reporting any dead ped to get a free insured heal / remote store)
        if not isHorseModel(entity, horse.model) then return false end

        -- remove the entity so a horse that was falsely reported dead can't carry on being used
        local corpse = { coords = GetEntityCoords(entity), heading = GetEntityHeading(entity) }
        if DoesEntityExist(entity) then DeleteEntity(entity) end
        endSession(Player.PlayerData.citizenid)
        return killHorseRecord(horse, source, corpse)
    end)
end)

-- ===================== FIELD SALVAGE =====================
-- fieldCorpses[citizenid] = { horseId, coords, expires } : where an uninsured horse died, so its
-- saddlebags can be searched there for a while (Config.HorseSalvage)
local fieldCorpses = {}

-- marks an active horse dead (or returns it via insurance); src may be nil (player dropped)
-- corpse = { coords, heading } of the body (nil = no field salvage)
killHorseRecord = function(horse, source, corpse)
    if isTrue(horse.insured) then
        MySQL.update.await('UPDATE grumpy_livery_horses SET active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL, alive = 1, insured = 0, health = 100, stamina = 100, hunger = 100, thirst = 100 WHERE id = ?', { horse.id })
        if source then RSGCore.Functions.Notify(source, { description = locale('horse_insured_returned'), type = 'inform' }) end
        return true, 'insured'
    end
    MySQL.update.await('UPDATE grumpy_livery_horses SET active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL, alive = 0 WHERE id = ?', { horse.id })
    if source then RSGCore.Functions.Notify(source, { description = locale('horse_dead'), type = 'error' }) end
    local S = Config.HorseSalvage
    if source and corpse and S and S.enabled and Config.HorseInventory and Config.HorseInventory.enabled then
        fieldCorpses[horse.citizenid] = { horseId = horse.id, coords = corpse.coords, expires = os.time() + S.duration }
        TriggerClientEvent('grumpy-livery:client:fieldCorpse', source, {
            horseId = horse.id, model = horse.model, outfit = horse.outfit, name = horse.name,
            coords = corpse.coords, heading = corpse.heading, duration = S.duration,
        })
    end
    return true, 'dead'
end

-- ===================== HORSE DOWN / FIELD REVIVE =====================
-- validates that netId is this player's active horse and that it is really dead
local function validateDownedHorse(src, citizenid, netId)
    local session = activeSessions[citizenid]
    if not session then return nil end
    netId = toId(netId)
    local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if entity == 0 or not DoesEntityExist(entity) then return nil end
    local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND active = 1', { session.horseId, citizenid })
    if not horse or not isHorseModel(entity, horse.model) then return nil end
    if #(GetEntityCoords(entity) - GetEntityCoords(GetPlayerPed(src))) > 300.0 then return nil end
    if witnessesSayAlive(src, entity, netId) then return nil end
    return session, horse
end

registerCallback('grumpy-livery:server:horseDown', function(source, netId)
    local cfg = Config.HorseReviver
    if not (cfg and cfg.enabled) then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    local session = validateDownedHorse(source, Player.PlayerData.citizenid, netId)
    if not session then return false end
    if not session.downAt then
        session.downAt = os.time()
        if (cfg.bondingLoss or 0) > 0 then
            session.bonding = math.max(0, (session.bonding or 0) - cfg.bondingLoss)
        end
    end
    return true, math.max(0, session.downAt + cfg.window - os.time())
end)

if Config.HorseReviver and Config.HorseReviver.enabled then
    RSGCore.Functions.CreateUseableItem(Config.HorseReviver.item, function(source)
        TriggerClientEvent('grumpy-livery:client:useReviver', source)
    end)
end

registerCallback('grumpy-livery:server:reviveDownedHorse', function(source, netId)
    local cfg = Config.HorseReviver
    if not (cfg and cfg.enabled) then return false, locale('reviver_disabled') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    local citizenid = Player.PlayerData.citizenid
    return withLock('citizen:' .. citizenid, function()
        local session, horse = validateDownedHorse(source, citizenid, netId)
        if not session or not session.downAt then return false, locale('reviver_not_down') end
        if os.time() > session.downAt + cfg.window + 5 then return false, locale('reviver_too_late') end
        local entity = NetworkGetEntityFromNetworkId(toId(netId))
        if #(GetEntityCoords(entity) - GetEntityCoords(GetPlayerPed(source))) > cfg.useDistance + 2.0 then
            return false, locale('must_be_near_horse')
        end
        if not Player.Functions.GetItemByName(cfg.item) then return false, locale('missing_item', cfg.label) end
        if not Player.Functions.RemoveItem(cfg.item, 1, nil, 'grumpy-livery-reviver') then return false, locale('item_use_failed') end
        TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[cfg.item], 'remove', 1)
        session.downAt = nil
        MySQL.update.await('UPDATE grumpy_livery_horses SET health = ?, bonding = ? WHERE id = ?', { cfg.revivedHealth, session.bonding, horse.id })
        horse.health, horse.bonding, horse.hunger, horse.thirst = cfg.revivedHealth, session.bonding, session.hunger, session.thirst
        return true, horse
    end)
end)

-- ===================== PLAYER DROPPED =====================
-- The horse is NOT stored on logout: it stays active at its last saved position so it can be
-- whistled on return. Logging out while the horse is down must not keep it alive.
AddEventHandler('playerDropped', function()
    local src = source
    brokenWild[src] = nil
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local session = activeSessions[citizenid]
    if session and session.downAt then
        local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND active = 1', { session.horseId })
        if horse then killHorseRecord(horse, nil) end
    else
        persistSession(citizenid)
    end
    endSession(citizenid)
end)

-- ===================== HORSE MEDICINE =====================
if Config.HorseMedicine and Config.HorseMedicine.enabled then
    RSGCore.Functions.CreateUseableItem(Config.HorseMedicine.item, function(source)
        TriggerClientEvent('grumpy-livery:client:useMedicine', source)
    end)
end

registerCallback('grumpy-livery:server:useMedicine', function(source, horseNetId)
    local cfg = Config.HorseMedicine
    if not (cfg and cfg.enabled) then return false, locale('medicine_disabled') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end
    if not activeHorseNear(source, session, horseNetId, (cfg.useDistance or 3.0) + 3.0) then return false, locale('must_be_near_horse') end
    if session.downAt then return false, locale('medicine_horse_down') end
    local now = os.time()
    if now < (session.medicineAt or 0) + cfg.cooldown then return false, locale('medicine_cooldown') end
    if not Player.Functions.GetItemByName(cfg.item) then return false, locale('missing_item', cfg.label) end
    if not Player.Functions.RemoveItem(cfg.item, 1, nil, 'grumpy-livery-medicine') then return false, locale('item_use_failed') end
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[cfg.item], 'remove', 1)
    session.medicineAt = now
    return true, { healPercent = cfg.healPercent, fillCore = cfg.fillCore }
end)

registerCallback('grumpy-livery:server:renameHorse', function(source, horseId, newName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    newName = sanitizeName(newName)
    if not newName then return false, locale('invalid_name') end
    newName = newName:sub(1, 40)
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT id, stable FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        if not chargePlayer(Player, Config.RenameCost, horse.stable) then return false, locale('insufficient_funds') end

        MySQL.update.await('UPDATE grumpy_livery_horses SET name = ? WHERE id = ?', { newName, horseId })
        return true, newName
    end)
end)

registerCallback('grumpy-livery:server:insureHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.insured) then return false, locale('already_insured') end
        if not isTrue(horse.alive) then return false, locale('horse_is_dead') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        if not chargePlayer(Player, Config.InsuranceCost, horse.stable) then return false, locale('insufficient_funds') end

        MySQL.update.await('UPDATE grumpy_livery_horses SET insured = 1 WHERE id = ?', { horseId })
        return true
    end)
end)

registerCallback('grumpy-livery:server:reviveHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.alive) then return false, locale('horse_not_dead') end
        if isTrue(horse.died_of_age) then return false, locale('horse_died_of_age_final') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        if not chargePlayer(Player, Config.ReviveCost, horse.stable) then return false, locale('insufficient_funds') end

        MySQL.update.await('UPDATE grumpy_livery_horses SET alive = 1, health = 100, stamina = 100, hunger = 100, thirst = 100, insured = 0 WHERE id = ?', { horseId })
        return true
    end)
end)

-- Remove a dead horse for good (frees the owned-horse slot; horses that died of old age can never be revived)
registerCallback('grumpy-livery:server:releaseHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT id, stable, alive FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.alive) then return false, locale('horse_not_dead') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end
        -- a parent of an uncollected foal can't be removed (the foal would be lost)
        if MySQL.single.await('SELECT id FROM grumpy_livery_breeding WHERE (parent_a = ? OR parent_b = ?) AND collected = 0', { horseId, horseId }) then
            return false, locale('horse_is_breeding')
        end
        -- saddlebags must be emptied first, or the items would be lost with the horse
        if saddlebagsHaveItems(horseId) then return false, locale('release_saddlebags_not_empty') end

        local deleted = MySQL.update.await('DELETE FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND alive = 0', { horseId, Player.PlayerData.citizenid })
        if not deleted or deleted == 0 then return false, locale('release_failed') end
        deleteSaddlebags(horseId) -- tidy up the (empty) stash
        return true
    end)
end)

registerCallback('grumpy-livery:server:transferHorse', function(source, horseId, newStable)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local stable = getStableConfig(newStable)
    if not stable then return false, locale('invalid_stable') end
    if not canUseStable(source, stable) then return false, locale('invalid_stable') end -- [grumpy-pob hook]
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
      return withLock('stable:' .. newStable, function()
        local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.active) then return false, locale('store_horse_first') end
        if horse.stable == newStable then return false, locale('already_stabled_there') end
        if isHorseBreeding(horseId) then return false, locale('horse_is_breeding') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM grumpy_livery_horses WHERE citizenid = ? AND stable = ?', { Player.PlayerData.citizenid, newStable })
        if atStable and atStable >= stableCap(newStable) then
            return false, locale('destination_full')
        end

        MySQL.update.await('UPDATE grumpy_livery_horses SET stable = ? WHERE id = ?', { newStable, horseId })
        return true
      end)
    end)
end)

-- ===================== GIVE HORSE TO ANOTHER PLAYER =====================
local function charName(P)
    local ci = P.PlayerData.charinfo or {}
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

local function nearbyPlayers(src, maxDist)
    local list = {}
    local myPed = GetPlayerPed(src)
    if not myPed or myPed == 0 then return list end
    local myCoords = GetEntityCoords(myPed)
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src then
            local ped = GetPlayerPed(id)
            local P = RSGCore.Functions.GetPlayer(id)
            if P and ped and ped ~= 0 and #(GetEntityCoords(ped) - myCoords) <= maxDist then
                list[#list + 1] = { id = id, name = charName(P) }
            end
        end
    end
    return list
end

local pendingOffers = {}

registerCallback('grumpy-livery:server:getNearbyPlayers', function(source)
    if not (Config.HorseGive and Config.HorseGive.enabled) or not RSGCore.Functions.GetPlayer(source) then return {} end
    return nearbyPlayers(source, Config.HorseGive.distance or 5.0)
end)

registerCallback('grumpy-livery:server:giveHorse', function(source, horseId, targetId, price)
    local cfg = Config.HorseGive
    if not (cfg and cfg.enabled) then return false, locale('give_disabled') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId, targetId = toId(horseId), toId(targetId)
    if not horseId then return false, locale('horse_not_found') end
    if not targetId or targetId == source then return false, locale('give_target_invalid') end
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then return false, locale('give_target_invalid') end

    price = math.floor(tonumber(price) or 0)
    if price < 0 or price > (cfg.maxPrice or 100000) then return false, locale('give_price_invalid', cfg.maxPrice or 100000) end
    local function targetCanPay(T)
        return price == 0 or (T.PlayerData.money[Config.PaymentAccount] or 0) >= price
    end
    if not targetCanPay(Target) then return false, locale('give_target_cant_afford', price) end

    local function targetNearby()
        for _, p in ipairs(nearbyPlayers(source, cfg.distance or 5.0)) do
            if p.id == targetId then return true end
        end
        return false
    end

    -- pre-checks before bothering the other player
    local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', { horseId, Player.PlayerData.citizenid })
    if not horse then return false, locale('horse_not_found') end
    if not isTrue(horse.alive) then return false, locale('horse_is_dead') end
    if isTrue(horse.active) then return false, locale('store_horse_first') end
    if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end
    if saddlebagsHaveItems(horseId) then return false, locale('give_saddlebags_not_empty') end
    if not targetNearby() then return false, locale('give_target_too_far') end

    if horse.papers == 'none' then
        RSGCore.Functions.Notify(targetId, { description = locale('give_no_papers_warning', horse.name), type = 'inform', duration = 10000 })
    end

    -- ask the receiver (one offer at a time per receiver, so popups can't stack or be spammed)
    if pendingOffers[targetId] then return false, locale('give_target_busy') end
    pendingOffers[targetId] = true
    local okAsk, accepted = pcall(RSGCore.Functions.AwaitClientCallback, 'grumpy-livery:client:confirmHorseGift', targetId, (cfg.timeout or 30000) + 2000, charName(Player), horse.name, horse.breed_label, price)
    pendingOffers[targetId] = nil
    if not okAsk or accepted ~= true then return false, locale('give_declined') end

    local giverCid, targetCid = Player.PlayerData.citizenid, Target.PlayerData.citizenid
    -- lock both players in a fixed order so two simultaneous gifts can't deadlock
    local first, second = giverCid, targetCid
    if second < first then first, second = second, first end

    return withLock('citizen:' .. first, function()
      return withLock('citizen:' .. second, function()
        -- re-check everything: state may have changed while the receiver was deciding
        local h = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', { horseId, giverCid })
        if not h then return false, locale('horse_not_found') end
        if not isTrue(h.alive) then return false, locale('horse_is_dead') end
        if isTrue(h.active) then return false, locale('store_horse_first') end
        if isHorseBreeding(horseId) then return false, locale('horse_is_breeding') end
        if not nearStableByName(source, h.stable) then return false, locale('not_close_to_stable') end
        if saddlebagsHaveItems(horseId) then return false, locale('give_saddlebags_not_empty') end
        Target = RSGCore.Functions.GetPlayer(targetId)
        if not Target or Target.PlayerData.citizenid ~= targetCid or not targetNearby() then return false, locale('give_target_too_far') end

        if countOwnedHorses(targetCid) >= Config.MaxOwnedHorses then return false, locale('give_target_full') end
        local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM grumpy_livery_horses WHERE citizenid = ? AND stable = ?', { targetCid, h.stable })
        if atStable and atStable >= stableCap(h.stable) then return false, locale('give_target_stable_full') end

        if not targetCanPay(Target) then
            RSGCore.Functions.Notify(targetId, { description = locale('give_you_cant_afford', price), type = 'error' })
            return false, locale('give_target_cant_afford', price)
        end
        if (cfg.fee or 0) > 0 and not chargeFlat(Player, cfg.fee) then return false, locale('insufficient_funds') end
        if price > 0 and not chargeFlat(Target, price) then
            if (cfg.fee or 0) > 0 then Player.Functions.AddMoney(Config.PaymentAccount, cfg.fee, 'grumpy-livery-refund') end
            return false, locale('give_target_cant_afford', price)
        end

        local changed = MySQL.update.await("UPDATE grumpy_livery_horses SET citizenid = ?, bonding = 0, papers_owner = IF(papers = 'none', NULL, ?) WHERE id = ? AND citizenid = ? AND active = 0", { targetCid, ownerName(Target), horseId, giverCid })
        if not changed or changed == 0 then
            if (cfg.fee or 0) > 0 then Player.Functions.AddMoney(Config.PaymentAccount, cfg.fee, 'grumpy-livery-refund') end
            if price > 0 then Target.Functions.AddMoney(Config.PaymentAccount, price, 'grumpy-livery-refund') end
            return false, locale('give_failed')
        end

        if price > 0 then
            Player.Functions.AddMoney(Config.PaymentAccount, price, 'grumpy-livery-horse-sale')
            RSGCore.Functions.Notify(targetId, { description = locale('give_bought', h.name, charName(Player), price), type = 'success' })
        else
            RSGCore.Functions.Notify(targetId, { description = locale('give_received', h.name, charName(Player)), type = 'success' })
        end
        return true, price
      end)
    end)
end)

-- ===================== HORSESHOES =====================
-- The client reports riding time on the active horse; the server caps it to the real time since the
-- last report, adds it to shoe_wear and takes the shoes off once they are fully worn.
local function shoeCondition(wear)
    local max = math.max(1, tonumber(Config.Horseshoes.wearSeconds) or 14400)
    return math.max(0, math.floor((1 - (tonumber(wear) or 0) / max) * 100 + 0.5))
end

registerCallback('grumpy-livery:server:getHorseshoeCondition', function(source)
    local cfg = Config.Horseshoes
    if not (cfg and cfg.enabled) then return nil end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return nil end
    local row = MySQL.single.await('SELECT tack, shoe_wear FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? LIMIT 1', { session.horseId, Player.PlayerData.citizenid })
    if not row then return nil end
    local tack = decodeTack(row.tack)
    if not tack.horseshoe or tack.horseshoe == 0 then return { shod = false, condition = 0 } end
    session.lastShoeReportAt = os.time()
    return { shod = true, condition = shoeCondition(row.shoe_wear) }
end)

registerCallback('grumpy-livery:server:wearHorseshoe', function(source, horseNetId, seconds)
    local cfg = Config.Horseshoes
    if not (cfg and cfg.enabled) then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    local citizenid = Player.PlayerData.citizenid
    local session = activeSessions[citizenid]
    if not session or not activeHorseNear(source, session, horseNetId, 4.0) then return false end

    -- never accept more wear than real time has passed (allowing for the fast-riding multiplier)
    local now = os.time()
    local elapsed = now - (session.lastShoeReportAt or (now - (cfg.reportInterval or 60)))
    session.lastShoeReportAt = now
    local maxMult = math.max(1.0, tonumber(cfg.gallopWearMultiplier) or 1.0)
    seconds = tonumber(seconds) or 0
    if seconds ~= seconds or seconds <= 0 then return false end -- NaN / nothing to add
    seconds = math.min(seconds, (elapsed + 2) * maxMult)

    return withLock('citizen:' .. citizenid, function()
        local row = MySQL.single.await('SELECT tack, shoe_wear FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND active = 1 LIMIT 1', { session.horseId, citizenid })
        if not row then return false end
        local tack = decodeTack(row.tack)
        if not tack.horseshoe or tack.horseshoe == 0 then return false end
        local wear = (tonumber(row.shoe_wear) or 0) + seconds
        if wear >= (tonumber(cfg.wearSeconds) or 14400) then
            tack.horseshoe = nil
            MySQL.update.await('UPDATE grumpy_livery_horses SET tack = ?, shoe_wear = 0 WHERE id = ?', { json.encode(tack), session.horseId })
            return true, { worn = true, tack = tack, condition = 0 }
        end
        MySQL.update.await('UPDATE grumpy_livery_horses SET shoe_wear = ? WHERE id = ?', { wear, session.horseId })
        return true, { worn = false, condition = shoeCondition(wear) }
    end)
end)

-- ===================== TACK =====================

registerCallback('grumpy-livery:server:applyHorseTack', function(source, horseId, selections)
    if not Config.Tack.enabled then return false, locale('tack_disabled') end
    if type(selections) ~= 'table' then return false, locale('invalid_selections') end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if not isTrue(horse.alive) then return false, locale('horse_is_dead') end
        if isTrue(horse.active) then return false, locale('store_horse_first') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        local tack = decodeTack(horse.tack)
        local total = 0
        local changes = {} -- categoryKey -> new hash-or-nil, applied only after every pick validates

        for _, category in ipairs(Config.TackCategories) do
            local sel = selections[category.key]
            if sel ~= nil then
                sel = math.floor(tonumber(sel) or 0)
                if sel == 0 then
                    if category.required then return false, locale('tack_required', category.label) end
                    if tack[category.key] then
                        changes[category.key] = false -- false = explicit removal, distinct from "untouched"
                    end
                else
                    local item = getTackItem(category.key, sel)
                    if not item then return false, locale('invalid_tack_item', category.label) end
                    if tostring(tack[category.key]) ~= tostring(sel) then
                        total = total + item.price
                        changes[category.key] = sel
                    end
                end
            end
        end

        for _, category in ipairs(Config.TackCategories) do
            if category.required and not (changes[category.key] or tack[category.key]) then
                return false, locale('tack_required', category.label)
            end
        end

        if next(changes) == nil then
            return false, locale('no_tack_changes')
        end

        local charged = 0
        if total > 0 then
            local paidOk, paid = chargePlayer(Player, total, horse.stable, 'grumpy-livery-tack')
            if not paidOk then return false, locale('insufficient_funds') end
            charged = paid
        end

        for key, value in pairs(changes) do
            tack[key] = value or nil
        end

        if changes.horseshoe ~= nil then
            -- new shoes fitted (or removed): start the wear count again
            MySQL.update.await('UPDATE grumpy_livery_horses SET tack = ?, shoe_wear = 0 WHERE id = ?', { json.encode(tack), horseId })
        else
            MySQL.update.await('UPDATE grumpy_livery_horses SET tack = ? WHERE id = ?', { json.encode(tack), horseId })
        end
        return true, { tack = tack, charged = charged }
    end)
end)

-- ===================== COAT =====================

local COAT_LIMITS = { tint0 = 254, tint1 = 255, tint2 = 255, mane = 254, tail = 254 }

local function normalizeCoat(raw)
    if type(raw) == 'string' then
        local ok, decoded = pcall(json.decode, raw)
        raw = ok and decoded or nil
    end
    if type(raw) ~= 'table' then return nil end
    local coat = {}
    for key, max in pairs(COAT_LIMITS) do
        local v = tonumber(raw[key])
        if not v then return nil end
        v = math.floor(v)
        if v < 0 or v > max then return nil end
        coat[key] = v
    end
    return coat
end

local function sameCoat(a, b)
    if not a or not b then return false end
    for key in pairs(COAT_LIMITS) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

-- rawCoat = { tint0, tint1, tint2, mane, tail } or the string 'reset' to restore the natural coat
registerCallback('grumpy-livery:server:applyHorseCoat', function(source, horseId, rawCoat)
    if not (Config.Coat and Config.Coat.enabled) then return false, locale('coat_disabled') end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    local reset = rawCoat == 'reset'
    local coat = not reset and normalizeCoat(rawCoat) or nil
    if not reset and not coat then return false, locale('invalid_coat') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if not isTrue(horse.alive) then return false, locale('horse_is_dead') end
        if isTrue(horse.active) then return false, locale('store_horse_first') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        if reset then
            if not horse.coat or horse.coat == '' then return false, locale('no_coat_changes') end
            MySQL.update.await('UPDATE grumpy_livery_horses SET coat = NULL WHERE id = ?', { horseId })
            return true, { coat = nil, charged = 0 }
        end

        if sameCoat(coat, normalizeCoat(horse.coat)) then
            return false, locale('no_coat_changes')
        end

        local price = tonumber(Config.Coat.price) or 0
        if price > 0 then
            local paidOk, paid = chargePlayer(Player, price, horse.stable, 'grumpy-livery-coat')
            if not paidOk then return false, locale('insufficient_funds') end
            price = paid
        end

        MySQL.update.await('UPDATE grumpy_livery_horses SET coat = ? WHERE id = ?', { json.encode(coat), horseId })
        return true, { coat = coat, charged = price }
    end)
end)

-- ===================== BREEDING =====================

registerCallback('grumpy-livery:server:startBreeding', function(source, stableName, idA, idB)
    if not Config.Breeding.enabled then return false, locale('breeding_disabled') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    idA, idB = toId(idA), toId(idB)
    if not idA or not idB then return false, locale('horse_not_found') end
    if idA == idB then return false, locale('breed_choose_different') end

    local stable = getStableConfig(stableName)
    if not stable then return false, locale('invalid_stable') end
    if not isNearStable(source, stable) then return false, locale('not_close_to_stable') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horseA = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', { idA, Player.PlayerData.citizenid })
        local horseB = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', { idB, Player.PlayerData.citizenid })
        if not horseA or not horseB then return false, locale('horse_not_found') end
        local stA, stB = horseStage(horseA.age_days), horseStage(horseB.age_days)
        if stA == 'young' or stB == 'young' then return false, locale('breed_too_young') end
        if stA == 'old' or stB == 'old' then return false, locale('breed_too_old') end
        if not isTrue(horseA.alive) or not isTrue(horseB.alive) then return false, locale('breed_both_alive') end
        if isTrue(horseA.active) or isTrue(horseB.active) then return false, locale('breed_both_stabled') end
        if Config.Breeding.sameStableOnly ~= false and (horseA.stable ~= stableName or horseB.stable ~= stableName) then
            return false, locale('breed_both_stabled_here')
        end

        if Config.Breeding.requireOppositeGender ~= false and (not horseA.gender or horseA.gender == horseB.gender) then
            return false, locale('breed_need_opposite_gender')
        end

        local pending = MySQL.single.await('SELECT id FROM grumpy_livery_breeding WHERE (parent_a = ? OR parent_b = ? OR parent_a = ? OR parent_b = ?) AND collected = 0', {
            idA, idA, idB, idB
        })
        if pending then return false, locale('breed_already_breeding') end

        local now = os.time() * 1000
        if (tonumber(horseA.breed_cooldown) or 0) > now or (tonumber(horseB.breed_cooldown) or 0) > now then
            return false, locale('breed_parent_cooldown')
        end

        local paidOk, paid, account = chargePlayer(Player, Config.Breeding.cost, stable, 'grumpy-livery-breeding')
        if not paidOk then return false, locale('insufficient_funds') end

        local readyAt = now + Config.Breeding.time
        local okIns, insertId = pcall(MySQL.insert.await, [[
            INSERT INTO grumpy_livery_breeding (citizenid, stable, parent_a, parent_b, ready_at, collected)
            VALUES (?, ?, ?, ?, ?, 0)
        ]], { Player.PlayerData.citizenid, stableName, idA, idB, readyAt })
        if not okIns or not insertId or insertId == 0 then
            -- refund instead of keeping the fee for a breeding that was never saved
            LiveryMoney.Refund(source, account, paid)
            return false, locale('generic_error')
        end
        if (Config.Breeding.parentCooldown or 0) > 0 then
            MySQL.update.await('UPDATE grumpy_livery_horses SET breed_cooldown = ? WHERE id IN (?, ?)', { now + Config.Breeding.parentCooldown, idA, idB })
        end

        return true, readyAt
    end)
end)

registerCallback('grumpy-livery:server:getBreedingJobs', function(source, stableName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not getStableConfig(stableName) then return {} end
    local rows = MySQL.query.await('SELECT * FROM grumpy_livery_breeding WHERE citizenid = ? AND stable = ? AND collected = 0', {
        Player.PlayerData.citizenid, stableName
    }) or {}
    -- send remaining time from the SERVER clock (client clocks can't be trusted / differ)
    local now = os.time() * 1000
    for _, r in ipairs(rows) do
        r.ms_left = math.max(0, (tonumber(r.ready_at) or 0) - now)
        r.ready = r.ms_left == 0
    end
    return rows
end)

registerCallback('grumpy-livery:server:collectFoal', function(source, breedingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    breedingId = toId(breedingId)
    if not breedingId then return false, locale('breed_job_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local job = MySQL.single.await('SELECT * FROM grumpy_livery_breeding WHERE id = ? AND citizenid = ? AND collected = 0', {
            breedingId, Player.PlayerData.citizenid
        })
        if not job then return false, locale('breed_job_not_found') end
        if (os.time() * 1000) < job.ready_at then return false, locale('foal_not_ready') end
        if not nearStableByName(source, job.stable) then return false, locale('not_close_to_stable') end

        local owned = countOwnedHorses(Player.PlayerData.citizenid)
        if owned >= Config.MaxOwnedHorses then return false, locale('horse_limit_reached') end

        local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM grumpy_livery_horses WHERE citizenid = ? AND stable = ?', { Player.PlayerData.citizenid, job.stable })
        if atStable and atStable >= stableCap(job.stable) then
            return false, locale('foal_stable_full')
        end

        local parentA = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ?', { job.parent_a })
        local parentB = MySQL.single.await('SELECT * FROM grumpy_livery_horses WHERE id = ?', { job.parent_b })
        if not parentA or not parentB then return false, locale('parent_data_missing') end

        -- inherit stats on the breed's 1..BreedStatMax scale (handling uses its own 0..100 scale)
        local cfgB = Config.Breeding
        local function inherit(a, b, lo, hi, variance)
            a, b = tonumber(a) or lo, tonumber(b) or lo
            local value
            if math.random(1, 100) <= (cfgB.betterParentChance or 0) then
                value = math.max(a, b)
            else
                value = math.floor((a + b) / 2 + 0.5)
            end
            value = value + math.random(-variance, variance)
            return math.max(lo, math.min(hi, value))
        end
        local statMax = Config.BreedStatMax or 10
        local v = cfgB.statVariance or 1

        -- papers: genuine when both parents have papers and the foal is born at a legal stable
        local foalStable = getStableConfig(job.stable) or { label = job.stable }
        local foalPapers = (parentA.papers ~= 'none' and parentB.papers ~= 'none' and not isUnderground(foalStable)) and 'genuine' or 'none'
        -- foal takes the model/breed of a random parent
        local foalParent = math.random(1, 2) == 1 and parentA or parentB

        -- claim the job first so a double-click / second request can't create two foals
        local claimed = MySQL.update.await('UPDATE grumpy_livery_breeding SET collected = 1 WHERE id = ? AND collected = 0', { breedingId })
        if not claimed or claimed == 0 then return false, locale('breed_job_not_found') end

        local ok, insertId = pcall(function()
            return MySQL.insert.await([[
                INSERT INTO grumpy_livery_horses
                    (citizenid, stable, model, breed_label, gender, name, outfit, tack, health, stamina, speed, accel, handling, maxhealth, alive, insured, active, papers, papers_stable, papers_owner)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 100, 100, ?, ?, ?, ?, 1, 0, 0, ?, ?, ?)
            ]], {
                Player.PlayerData.citizenid, job.stable, foalParent.model, foalParent.breed_label, randomGender(), locale('unnamed_foal'), foalParent.outfit or 0, newHorseTack(),
                inherit(parentA.speed, parentB.speed, 1, statMax, v),
                inherit(parentA.accel, parentB.accel, 1, statMax, v),
                inherit(parentA.handling, parentB.handling, 0, 100, v * 5),
                inherit(parentA.maxhealth, parentB.maxhealth, 1, statMax, v),
                foalPapers, foalPapers ~= 'none' and foalStable.label or nil, foalPapers ~= 'none' and ownerName(Player) or nil
            })
        end)

        if not ok or not insertId or insertId == 0 then
            print(('[grumpy-livery] ERROR: collectFoal insert failed for citizenid %s: %s'):format(
                Player.PlayerData.citizenid, tostring(insertId)
            ))
            MySQL.update.await('UPDATE grumpy_livery_breeding SET collected = 0 WHERE id = ?', { breedingId }) -- give the job back
            return false, locale('foal_collect_error')
        end

        return true
    end)
end)


-- ===================== HORSE INVENTORY =====================
-- Opens the rsg-inventory stash for the player's active (checked-out) horse.
RegisterNetEvent('grumpy-livery:server:openHorseInventory', function(horseId, horseNetId)
    local src = source
    if not Config.HorseInventory or not Config.HorseInventory.enabled then return end
    horseId = toId(horseId)
    if not horseId then return end

    -- the player must actually be standing next to the horse entity (stops remote stash access)
    local horseEntity = tonumber(horseNetId) and NetworkGetEntityFromNetworkId(tonumber(horseNetId)) or 0
    local ped = GetPlayerPed(src)
    if not horseEntity or horseEntity == 0 or not DoesEntityExist(horseEntity) or ped == 0 then return end
    if #(GetEntityCoords(ped) - GetEntityCoords(horseEntity)) > (Config.HorseInventory.distance or 2.5) + 2.0 then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local row = MySQL.single.await('SELECT id, name, tack, model FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND active = 1 LIMIT 1', {
        horseId, Player.PlayerData.citizenid
    })
    if not row or not isHorseModel(horseEntity, row.model) then return end

    -- optional: no saddlebags fitted = nowhere to store items
    if Config.HorseInventory.requireSaddlebags then
        local tack = decodeTack(row.tack)
        if not tack or not tack.saddlebags then
            TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('no_saddlebags_title'), description = locale('no_saddlebags_desc'), type = 'error' })
            return
        end
    end

    exports['rsg-inventory']:OpenInventory(src, 'horse_' .. row.id, {
        label = row.name or locale('your_horse'),
        maxweight = Config.HorseInventory.maxweight,
        slots = Config.HorseInventory.slots,
    })
end)


-- Saddlebags of a horse that just died out in the world, opened at its body
RegisterNetEvent('grumpy-livery:server:openFieldSaddlebags', function(horseId)
    local src = source
    local S = Config.HorseSalvage
    if not (S and S.enabled and Config.HorseInventory and Config.HorseInventory.enabled) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local rec = fieldCorpses[Player.PlayerData.citizenid]
    if not rec or rec.horseId ~= toId(horseId) then return end
    if os.time() > rec.expires then fieldCorpses[Player.PlayerData.citizenid] = nil return end
    if #(GetEntityCoords(GetPlayerPed(src)) - rec.coords) > (S.distance or 3.0) + 2.0 then return end

    local row = MySQL.single.await('SELECT id, name FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND alive = 0 LIMIT 1', {
        rec.horseId, Player.PlayerData.citizenid
    })
    if not row then fieldCorpses[Player.PlayerData.citizenid] = nil return end
    exports['rsg-inventory']:OpenInventory(src, 'horse_' .. row.id, {
        label = row.name or locale('your_horse'),
        maxweight = Config.HorseInventory.maxweight,
        slots = Config.HorseInventory.slots,
    })
end)

-- Dead horses can't be taken out, so their saddlebags can be emptied at their stable instead
RegisterNetEvent('grumpy-livery:server:openDeadHorseInventory', function(horseId)
    local src = source
    if not Config.HorseInventory or not Config.HorseInventory.enabled then return end
    horseId = toId(horseId)
    if not horseId then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local row = MySQL.single.await('SELECT id, name, stable FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND alive = 0 LIMIT 1', {
        horseId, Player.PlayerData.citizenid
    })
    if not row then return end
    if not nearStableByName(src, row.stable) then
        TriggerClientEvent('RSGCore:Client:Notify', src, { description = locale('not_close_to_stable'), type = 'error' })
        return
    end

    exports['rsg-inventory']:OpenInventory(src, 'horse_' .. row.id, {
        label = row.name or locale('your_horse'),
        maxweight = Config.HorseInventory.maxweight,
        slots = Config.HorseInventory.slots,
    })
end)


-- ===================== NATURAL DEATH (old age) =====================
CreateThread(function()
    while true do
        local cfg = Config.HorseAging
        Wait((cfg and cfg.checkInterval) or 600000)
        if cfg and cfg.enabled and (cfg.lifespanDays or 0) > 0 then
            local rows = MySQL.query.await('SELECT id, citizenid, name, active FROM grumpy_livery_horses WHERE alive = 1 AND DATEDIFF(NOW(), created_at) >= ?', { cfg.lifespanDays }) or {}
            for _, r in ipairs(rows) do
                withLock('citizen:' .. r.citizenid, function()
                    MySQL.update.await('UPDATE grumpy_livery_horses SET alive = 0, died_of_age = 1, insured = 0, active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL WHERE id = ? AND alive = 1', { r.id })
                    -- cancel any breeding this horse was part of
                    MySQL.update.await('UPDATE grumpy_livery_breeding SET collected = 1 WHERE (parent_a = ? OR parent_b = ?) AND collected = 0 AND ready_at > ?', { r.id, r.id, os.time() * 1000 })
                    if isTrue(r.active) then endSession(r.citizenid) end
                    local Player = RSGCore.Functions.GetPlayerByCitizenId(r.citizenid)
                    if Player then
                        TriggerClientEvent('grumpy-livery:client:horseDiedOfAge', Player.PlayerData.source, r.id, r.name)
                    end
                end)
            end
        end
    end
end)

-- ===================== SELLING HORSES =====================
local function trainedLevels(rawTraining)
    local T = Config.Training
    if not (T and T.enabled and rawTraining and rawTraining ~= '') then return 0 end
    local ok, data = pcall(json.decode, rawTraining)
    if not ok or type(data) ~= 'table' or type(data.stats) ~= 'table' then return 0 end
    local total = 0
    for _, xp in pairs(data.stats) do
        xp = tonumber(xp) or 0
        for _, need in ipairs(T.levelXp) do if xp >= need then total = total + 1 end end
    end
    return total
end

-- returns price, breakdown (the appraisal shown to the player before selling)
local function sellPrice(horse)
    local cfg = Config.HorseSell
    local breed = getBreedConfig(horse.model)
    local base = math.floor((breed and tonumber(breed.price) or 0) * cfg.percent)
    local training = trainedLevels(horse.training) * (cfg.perTrainedLevel or 0)
    local info = { base = base, training = training, condition = 100, bonding = 0, stageMult = 1.0, shod = 0 }
    local price = base
    local A = cfg.appraisal
    if A and A.enabled then
        local condition = ((tonumber(horse.health) or 100) + (tonumber(horse.hunger) or 100) + (tonumber(horse.thirst) or 100)) / 3
        condition = math.max(0, math.min(100, condition))
        local bonding = math.max(0, math.min(100, tonumber(horse.bonding) or 0))
        local stage = horseStage(horse.age_days)
        local stageMult = (stage and A.stage and A.stage[stage]) or 1.0
        price = base * (1 - (A.conditionWeight or 0) * (1 - condition / 100)) * (1 + (A.bondingBonus or 0) * bonding / 100) * stageMult
        local tack = decodeTack(horse.tack)
        if tack.horseshoe and tack.horseshoe ~= 0 then info.shod = A.shodBonus or 0 end
        info.condition, info.bonding, info.stageMult, info.stage = math.floor(condition + 0.5), math.floor(bonding + 0.5), stageMult, stage
    end
    price = math.max(cfg.minPrice or 0, math.floor(price + training + info.shod))
    info.price = price
    return price, info
end

-- What this player gets for the horse at the stable it's kept in: the appraisal x standing (market of that livery),
-- capped at Config.Money.sellCap x what they'd pay for the breed there (plus training, which they paid for).
-- Legal stables only buy horses with papers. Returns price, info  |  nil, reason
local function sellQuote(src, horse)
    local stable = getStableConfig(horse.stable)
    if not isUnderground(stable) and horse.papers == 'none' then return nil, locale('sell_no_papers') end
    local base, info = sellPrice(horse)
    local breed = getBreedConfig(horse.model)
    local listPrice = breed and tonumber(breed.price) or nil
    local price, mult, cap = LiveryMoney.SellPrice(src, stable, base - (info.training or 0), listPrice)
    price = LiveryMoney.Round(math.max(Config.HorseSell.minPrice or 0, price + (info.training or 0)))
    info.standingMult, info.cap, info.price = mult, cap, price
    info.account = LiveryMoney.PayoutAccount(stable)
    return price, info
end

registerCallback('grumpy-livery:server:getSellPrice', function(source, horseId)
    if not (Config.HorseSell and Config.HorseSell.enabled) then return nil end
    local Player = RSGCore.Functions.GetPlayer(source)
    horseId = toId(horseId)
    if not Player or not horseId then return nil end
    local horse = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', { horseId, Player.PlayerData.citizenid })
    if not horse then return nil end
    local price, info = sellQuote(source, horse)
    if not price then return nil, info end
    return price, info
end)

registerCallback('grumpy-livery:server:sellHorse', function(source, horseId)
    if not (Config.HorseSell and Config.HorseSell.enabled) then return false, locale('generic_error') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end
    local citizenid = Player.PlayerData.citizenid

    return withLock('citizen:' .. citizenid, function()
        local horse = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', { horseId, citizenid })
        if not horse then return false, locale('horse_not_found') end
        if not isTrue(horse.alive) then return false, locale('horse_dead_revive_first') end
        if isTrue(horse.active) then return false, locale('horse_already_out') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end
        if MySQL.single.await('SELECT id FROM grumpy_livery_breeding WHERE (parent_a = ? OR parent_b = ?) AND collected = 0', { horseId, horseId }) then
            return false, locale('horse_is_breeding')
        end
        if saddlebagsHaveItems(horseId) then return false, locale('release_saddlebags_not_empty') end

        local price, why = sellQuote(source, horse)
        if not price then return false, why end
        local deleted = MySQL.update.await('DELETE FROM grumpy_livery_horses WHERE id = ? AND citizenid = ? AND active = 0', { horseId, citizenid })
        if not deleted or deleted == 0 then return false, locale('generic_error') end
        deleteSaddlebags(horseId)

        LiveryMoney.Pay(source, getStableConfig(horse.stable), price, 'grumpy-livery-sell-horse')
        return true, price
    end)
end)

-- ===================== HORSE FENCE =====================
local fenceCooldown = {}

registerCallback('grumpy-livery:server:fenceHorse', function(source, fenceIndex, netId)
    local cfg = Config.HorseFence
    if not (cfg and cfg.enabled) then return false, locale('generic_error') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    local fence = cfg.locations[tonumber(fenceIndex) or 0]
    if not fence then return false, locale('generic_error') end
    local citizenid = Player.PlayerData.citizenid

    local now = os.time()
    if now < (fenceCooldown[citizenid] or 0) then
        return false, locale('fence_cooldown', math.ceil((fenceCooldown[citizenid] - now) / 60))
    end

    netId = toId(netId)
    local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if not isClaimableEntity(entity) then return false, locale('fence_no_horse') end
    -- (no server GetEntityHealth check: RedM's server returns 0 for peds, which blocked every fence sale)
    -- owned horses are script-spawned (rejected above); the state bag is a second check, but it is
    -- client-writable so it can't be the only one (a cleared bag let players fence their own horse,
    -- whistle it back and fence it again for endless money)
    if Entity(entity).state.rsgStablesOwned then return false, locale('fence_owned') end

    local breed = getBreedConfig(GetEntityModel(entity))
    if not breed then return false, locale('fence_not_wanted') end

    local fc = vector3(fence.coords.x, fence.coords.y, fence.coords.z)
    local pc = GetEntityCoords(GetPlayerPed(source))
    if #(pc - fc) > cfg.sellDistance or #(GetEntityCoords(entity) - fc) > cfg.sellDistance then
        return false, locale('fence_too_far')
    end

    local price = math.max(1, math.floor((tonumber(breed.price) or 0) * cfg.percent))
    DeleteEntity(entity)
    fenceCooldown[citizenid] = now + cfg.cooldown
    Player.Functions.AddMoney(cfg.account, price, 'grumpy-livery-horse-fence')
    TriggerEvent('rsg-log:server:CreateLog', 'rsgstables', 'Horse Fenced', 'red',
        ('%s (%s) fenced a %s for $%s'):format(GetPlayerName(source), citizenid, breed.label, price))
    return true, { price = price, label = breed.label }
end)

-- ===================== HORSE RACES =====================
-- Server-authoritative checkpoint races (Config.HorseRaces). The client only reports "I'm at checkpoint n";
-- the server checks order, distance to the checkpoint, that the player is on their own horse, and that each
-- leg took at least as long as riding it at Config.HorseRaces.maxSpeed would.
local RACES = Config.HorseRaces
local raceById = {}
if RACES and RACES.enabled then
    for _, r in ipairs(RACES.races or {}) do raceById[r.id] = r end
end
local raceRuns = {}     -- [src] = { race, idx, startedAt, legAt, lastPos }
local raceNextAt = {}   -- [citizenid .. ':' .. raceId] = os.time() the race can be entered again

local function raceLeaderboard(raceId)
    return MySQL.query.await('SELECT rider, horse, best_ms FROM grumpy_livery_races WHERE race = ? ORDER BY best_ms ASC LIMIT ?', {
        raceId, RACES.leaderboardSize or 5
    }) or {}
end

registerCallback('grumpy-livery:server:getRaces', function(source, stableName)
    if not (RACES and RACES.enabled) then return {} end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not nearStableByName(source, stableName) then return {} end
    local cid = Player.PlayerData.citizenid
    local list = {}
    for _, r in ipairs(RACES.races or {}) do
        if r.stable == stableName and #(r.checkpoints or {}) > 0 then
            local mine = MySQL.single.await('SELECT best_ms FROM grumpy_livery_races WHERE citizenid = ? AND race = ?', { cid, r.id })
            list[#list + 1] = {
                id = r.id, label = r.label, entryFee = r.entryFee or 0, prize = r.prize or 0,
                goalTime = r.goalTime, timeLimit = r.timeLimit, checkpoints = #r.checkpoints,
                best = mine and mine.best_ms or nil,
                cooldownLeft = math.max(0, (raceNextAt[cid .. ':' .. r.id] or 0) - os.time()),
                leaderboard = raceLeaderboard(r.id),
            }
        end
    end
    return list
end)

registerCallback('grumpy-livery:server:startRace', function(source, raceId, horseNetId)
    if not (RACES and RACES.enabled) then return false, locale('race_disabled') end
    local race = raceById[raceId]
    if not race then return false, locale('race_not_found') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    if raceRuns[source] then return false, locale('race_already_running') end
    if not nearStableByName(source, race.stable) then return false, locale('not_close_to_stable') end
    local cid = Player.PlayerData.citizenid
    local session = activeSessions[cid]
    -- must be sitting on (right next to) their own active horse
    if not activeHorseNear(source, session, horseNetId, 4.0) then return false, locale('race_need_horse') end
    local key = cid .. ':' .. race.id
    local now = os.time()
    if now < (raceNextAt[key] or 0) then
        return false, locale('race_cooldown', math.ceil((raceNextAt[key] - now) / 60))
    end
    local fee = math.max(0, math.floor(tonumber(race.entryFee) or 0))
    if fee > 0 and not chargeFlat(Player, fee) then return false, locale('insufficient_funds') end
    raceNextAt[key] = now + (race.cooldown or 600)
    raceRuns[source] = {
        race = race, idx = 0, startedAt = GetGameTimer(), legAt = GetGameTimer(),
        lastPos = GetEntityCoords(GetPlayerPed(source)), horseNetId = horseNetId,
    }
    return true, { checkpoints = race.checkpoints, timeLimit = race.timeLimit, goalTime = race.goalTime, radius = RACES.radius }
end)

registerCallback('grumpy-livery:server:raceCheckpoint', function(source, idx)
    local run = raceRuns[source]
    if not run then return false, locale('race_not_running') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then raceRuns[source] = nil return false end
    local race = run.race
    local now = GetGameTimer()
    idx = toId(idx)
    if idx ~= run.idx + 1 then return false end
    if race.timeLimit and now - run.startedAt > race.timeLimit * 1000 then
        raceRuns[source] = nil
        return false, locale('race_time_up')
    end
    local cp = race.checkpoints[idx]
    local pos = GetEntityCoords(GetPlayerPed(source))
    if #(pos - cp) > (RACES.radius or 8.0) * 1.5 + 3.0 then return false end
    if not activeHorseNear(source, activeSessions[Player.PlayerData.citizenid], run.horseNetId, 4.0) then
        raceRuns[source] = nil
        return false, locale('race_need_horse')
    end
    -- leg can't be quicker than riding it at maxSpeed (teleports / modified clients)
    local minMs = #(cp - run.lastPos) / (RACES.maxSpeed or 25.0) * 1000
    if now - run.legAt < minMs then
        raceRuns[source] = nil
        print(('[grumpy-livery] race %s: player %s reached checkpoint %d too fast - run cancelled'):format(race.id, source, idx))
        return false, locale('race_invalid')
    end
    run.idx, run.legAt, run.lastPos = idx, now, cp
    if idx < #race.checkpoints then return true, { finished = false, next = idx + 1 } end

    -- finished
    raceRuns[source] = nil
    local ms = now - run.startedAt
    local cid = Player.PlayerData.citizenid
    local won = race.goalTime and ms <= race.goalTime * 1000
    local prize = 0
    if won and (race.prize or 0) > 0 then
        prize = math.floor(race.prize)
        Player.Functions.AddMoney(Config.PaymentAccount, prize, 'grumpy-livery-race-prize')
    end
    local prev = MySQL.single.await('SELECT best_ms FROM grumpy_livery_races WHERE citizenid = ? AND race = ?', { cid, race.id })
    local newBest = not prev or ms < prev.best_ms
    if newBest then
        local ci = Player.PlayerData.charinfo or {}
        local horseName = ''
        local session = activeSessions[cid]
        if session then
            local h = MySQL.single.await('SELECT name FROM grumpy_livery_horses WHERE id = ?', { session.horseId })
            horseName = h and h.name or ''
        end
        MySQL.insert.await([[
            INSERT INTO grumpy_livery_races (citizenid, race, rider, horse, best_ms) VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE rider = VALUES(rider), horse = VALUES(horse), best_ms = VALUES(best_ms)
        ]], { cid, race.id, ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):sub(1, 100), horseName:sub(1, 50), ms })
    end
    return true, { finished = true, ms = ms, won = won == true, prize = prize, newBest = newBest }
end)

registerCallback('grumpy-livery:server:abortRace', function(source)
    raceRuns[source] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    raceRuns[source] = nil
end)

if RACES and RACES.enabled and RACES.routeCommand then
    RSGCore.Commands.Add(RACES.routeCommand, locale('race_route_help'), { { name = 'action', help = 'add | print | clear' } }, true, function(source, args)
        TriggerClientEvent('grumpy-livery:client:raceRoute', source, args[1])
    end, 'admin')
end


-- ===================== CHECK PAPERS =====================
-- The owner shows a horse's papers: the card goes to them and to every player within Config.Papers.showRadius.
-- Active horse: the owner must be next to it. Stabled horse: the owner must be at its stable.
-- Forged papers read exactly like genuine ones.
local papersCooldown = {}

registerCallback('grumpy-livery:server:showPapers', function(source, horseId, horseNetId)
    local Player = RSGCore.Functions.GetPlayer(source)
    horseId = toId(horseId)
    if not Player or not horseId then return false, locale('horse_not_found') end
    local now = GetGameTimer()
    if now < (papersCooldown[source] or 0) then return false end
    papersCooldown[source] = now + 3000

    local cid = Player.PlayerData.citizenid
    local horse = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM grumpy_livery_horses WHERE id = ? AND citizenid = ?', { horseId, cid })
    if not horse then return false, locale('horse_not_found') end
    if isTrue(horse.active) then
        local session = activeSessions[cid]
        if not session or session.horseId ~= horseId or not activeHorseNear(source, session, horseNetId, 6.0) then
            return false, locale('papers_too_far')
        end
    elseif not nearStableByName(source, horse.stable) then
        return false, locale('not_close_to_stable')
    end

    local card = {
        name = horse.name,
        breed = horse.breed_label,
        sex = horse.gender and locale(horse.gender == 'male' and 'gender_stallion' or 'gender_mare') or nil,
        stage = horseStage(horse.age_days) and locale('stage_' .. horseStage(horse.age_days)) or nil,
        hasPapers = horse.papers ~= 'none',
        owner = horse.papers_owner or charName(Player),
        registered = horse.papers_stable,
        shownBy = charName(Player),
    }
    local radius = (Config.Papers and Config.Papers.showRadius) or 5.0
    TriggerClientEvent('grumpy-livery:client:papersCard', source, card)
    for _, p in ipairs(nearbyPlayers(source, radius)) do
        TriggerClientEvent('grumpy-livery:client:papersCard', p.id, card)
    end
    return true
end)
