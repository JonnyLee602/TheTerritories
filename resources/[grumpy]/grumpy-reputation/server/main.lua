RSGCore = exports['rsg-core']:GetCoreObject()

local S = Config.Standing
local DAY = 86400

-----------------------------------------------------------------------
-- storage: standing lives in metadata.rep[RepKey] (next to hunting, fishing, ...),
-- bookkeeping in metadata.grumpyrep = { last, decayedAt, day, used = { [action] = points } }
-----------------------------------------------------------------------
local function getRepTable(Player)
    local rep = Player.PlayerData.metadata.rep
    if type(rep) ~= 'table' then rep = {} end
    return rep
end

local function getMeta(Player)
    local meta = Player.PlayerData.metadata.grumpyrep
    if type(meta) ~= 'table' then meta = {} end
    meta.used = type(meta.used) == 'table' and meta.used or {}
    return meta
end

local function readStanding(Player)
    local v = tonumber(getRepTable(Player)[S.RepKey])
    return v and Rep.Clamp(v) or S.Start
end

local function save(Player, standing, meta)
    local rep = getRepTable(Player)
    rep[S.RepKey] = standing
    Player.Functions.SetMetaData({ rep = rep, grumpyrep = meta }) -- one UpdatePlayerData call
end

local function notify(src, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = description, type = nType or 'inform', duration = 6000 })
end

-----------------------------------------------------------------------
-- core change: every standing change goes through here
-----------------------------------------------------------------------
---@return number applied delta (0 if nothing changed)
local function change(Player, delta, reason, meta, touch)
    local src = Player.PlayerData.source
    meta = meta or getMeta(Player)
    local old = readStanding(Player)
    local new = Rep.Clamp(old + delta)
    if touch then meta.last, meta.decayedAt = os.time(), nil end
    if new == old then
        if touch then save(Player, old, meta) end
        return 0
    end
    save(Player, new, meta)

    local oldTier, newTier = Rep.TierFor(old), Rep.TierFor(new)
    if Config.Debug then print(('[grumpy-reputation] %s %s: %d -> %d (%s)'):format(src, reason or '?', old, new, newTier)) end
    TriggerEvent('grumpy-reputation:server:changed', src, old, new, reason, oldTier, newTier)
    TriggerClientEvent('grumpy-reputation:client:changed', src, new, newTier)

    if Config.NotifyTierChange and oldTier ~= newTier then
        notify(src, locale('tier_now', locale('tier_' .. newTier)), new > old and 'success' or 'warning')
    elseif Config.NotifyEveryChange then
        notify(src, locale(new > old and 'standing_up' or 'standing_down'), 'inform')
    end
    return new - old
end

local function today() return os.date('%Y-%m-%d') end

-----------------------------------------------------------------------
-- public functions
-----------------------------------------------------------------------
Reputation = {}

---Raw change with no daily cap. Positive = legit, negative = outlaw.
function Reputation.Adjust(src, amount, reason)
    amount = tonumber(amount)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not amount or amount ~= amount or amount == 0 then return 0 end
    return change(Player, math.floor(amount + 0.5), reason or 'adjust', nil, true)
end

---Apply a configured action (Config.Actions), respecting its daily cap.
---@param mult number|nil optional multiplier (e.g. 2 for a bigger job)
function Reputation.Action(src, name, mult)
    local cfg = Config.Actions[name]
    local Player = RSGCore.Functions.GetPlayer(src)
    if not cfg or not Player then return 0 end
    mult = tonumber(mult) or 1
    if mult ~= mult or mult <= 0 then return 0 end

    local amount
    if cfg.towardZero then
        -- penalty: shrink whatever reputation the player has (outlaw or legit) toward 0, never past it
        local v = readStanding(Player)
        amount = math.min(math.floor(math.abs(cfg.amount) * mult + 0.5), math.abs(v))
        if v > 0 then amount = -amount end
    else
        amount = math.floor(cfg.amount * mult + 0.5)
    end
    if amount == 0 then return 0 end

    local meta = getMeta(Player)
    if meta.day ~= today() then meta.day, meta.used = today(), {} end
    if cfg.dailyCap then
        local room = cfg.dailyCap - (meta.used[name] or 0)
        if room <= 0 then return 0 end
        if math.abs(amount) > room then amount = amount > 0 and room or -room end
    end

    local applied = change(Player, amount, name, meta, true)
    if cfg.dailyCap and applied ~= 0 then
        meta.used[name] = (meta.used[name] or 0) + math.abs(applied)
        save(Player, readStanding(Player), meta)
    end
    return applied
end

function Reputation.GetStanding(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and readStanding(Player) or nil
end

function Reputation.GetTier(src)
    local v = Reputation.GetStanding(src)
    if not v then return nil end
    return (Rep.TierFor(v))
end

---true when min <= standing <= max (either bound may be nil)
function Reputation.InRange(src, min, max)
    local v = Reputation.GetStanding(src)
    if not v then return false end
    return (not min or v >= min) and (not max or v <= max)
end

function Reputation.SetStanding(src, value, reason)
    local Player = RSGCore.Functions.GetPlayer(src)
    value = tonumber(value)
    if not Player or not value then return false end
    change(Player, Rep.Clamp(value) - readStanding(Player), reason or 'set', nil, true)
    return true
end

---Every rep value the player has (standing + hunting, fishing, ...)
function Reputation.GetAllRep(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local out = {}
    for k, v in pairs(getRepTable(Player)) do out[k] = tonumber(v) or v end
    out[S.RepKey] = readStanding(Player)
    return out
end

-----------------------------------------------------------------------
-- decay toward 0 after Config.Decay.afterDays without a change
-----------------------------------------------------------------------
local function applyDecay(Player)
    local D = Config.Decay
    if not D.enabled or D.perDay <= 0 then return end
    local meta = getMeta(Player)
    local now = os.time()
    if not meta.last then meta.last = now; return save(Player, readStanding(Player), meta) end

    local from = math.max(meta.last + D.afterDays * DAY, tonumber(meta.decayedAt) or 0)
    local days = math.floor((now - from) / DAY)
    if days <= 0 then return end

    local v = readStanding(Player)
    local step = math.min(math.abs(v), days * D.perDay)
    meta.decayedAt = from + days * DAY
    if step == 0 then return save(Player, v, meta) end
    change(Player, v > 0 and -step or step, 'decay', meta, false)
end

-----------------------------------------------------------------------
-- offline queue: changes for characters that aren't online (e.g. they disconnected mid-robbery)
-- are saved and applied the next time that character loads
-----------------------------------------------------------------------
if Config.AutoDatabase then
    MySQL.ready(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `grumpy_reputation_pending` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `action` VARCHAR(50) NOT NULL,
                `mult` FLOAT NOT NULL DEFAULT 1,
                `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                KEY `citizenid` (`citizenid`)
            )
        ]])
    end)
end

---Apply an action to a character by citizenid. Online: applied now. Offline (or queueOnly): saved and
---applied on their next login. Use queueOnly from playerDropped, where the core may already have saved them.
function Reputation.ActionByCitizenId(citizenid, name, mult, queueOnly)
    if type(citizenid) ~= 'string' or not Config.Actions[name] then return false end
    if not queueOnly then
        local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
        if Player then
            Reputation.Action(Player.PlayerData.source, name, mult)
            return true
        end
    end
    MySQL.insert('INSERT INTO grumpy_reputation_pending (citizenid, action, mult) VALUES (?, ?, ?)',
        { citizenid, name, tonumber(mult) or 1 })
    return true
end

local function applyPending(Player)
    local src, cid = Player.PlayerData.source, Player.PlayerData.citizenid
    local rows = MySQL.query.await('SELECT id, action, mult FROM grumpy_reputation_pending WHERE citizenid = ? ORDER BY id', { cid }) or {}
    if #rows == 0 then return end
    local ids = {}
    for _, r in ipairs(rows) do ids[#ids + 1] = r.id end
    MySQL.query.await(('DELETE FROM grumpy_reputation_pending WHERE id IN (%s)'):format(('?,'):rep(#ids):sub(1, -2)), ids)
    for _, r in ipairs(rows) do
        if Config.Actions[r.action] then Reputation.Action(src, r.action, tonumber(r.mult) or 1) end
    end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    applyDecay(Player)
    applyPending(Player)
end)

CreateThread(function()
    while true do
        Wait(60 * 60 * 1000) -- hourly for players who stay online for days
        for _, src in ipairs(RSGCore.Functions.GetPlayers()) do
            local Player = RSGCore.Functions.GetPlayer(src)
            if Player then applyDecay(Player) end
        end
    end
end)

-----------------------------------------------------------------------
-- exports
-----------------------------------------------------------------------
exports('Adjust', Reputation.Adjust)
exports('Action', Reputation.Action)
exports('ActionByCitizenId', Reputation.ActionByCitizenId)
exports('GetStanding', Reputation.GetStanding)
exports('GetTier', Reputation.GetTier)
exports('InRange', Reputation.InRange)
exports('SetStanding', Reputation.SetStanding)
exports('GetAllRep', Reputation.GetAllRep)
exports('TierFor', function(value) return (Rep.TierFor(value)) end)
exports('TierRange', Rep.TierRange)
