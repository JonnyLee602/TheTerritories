-- Rake service (DESIGN.md §6.3, §7.4): current rates, per-table remainders, play stats and the daily tuner.
local Rake = { rates = {}, remainders = {}, stats = {}, lastTune = 0 }
GG.Rake = Rake

local function key(kind, tier, game) return ('%s:%s:%s'):format(kind, tier, game) end

function Rake.Load()
    Rake.rates = GG.DB.RatesAll()
    Rake.remainders = GG.DB.RemaindersAll()
end
GG.AfterLoad(Rake.Load)

-- Rate for a table's current game and tier (0..1)
function Rake.Rate(t)
    if not t.tier or not t.game or Config.Rake.FreeTiers[t.tier] then return 0.0 end
    local k = key(t.kind, t.tier, t.game)
    if Config.Rake.Pinned[k] then return Config.Rake.Pinned[k] end
    local r = Rake.rates[k]
    if r and r.rate then return r.rate end
    return (Config.Rake.Seed[t.kind] or {})[t.tier] or 0.0
end

function Rake.Remainder(tableId) return Rake.remainders[tableId] or 0.0 end
function Rake.SetRemainder(tableId, v) Rake.remainders[tableId] = v end

-- Business tables send a share of the rake to the owner's cashbox; everything else is destroyed
function Rake.Split(t, rakeC)
    if t.source ~= 'business' then return 0, rakeC end
    return GG.M.Split(rakeC, Config.Rake.BusinessShare[t.kind] or 0)
end

---------------------------------------------------------------------
-- Stats (buffered, flushed every minute)
---------------------------------------------------------------------
local function bucket(t)
    local day = os.date('%Y-%m-%d')
    local k = ('%s|%s|%s|%s'):format(day, t.tier, t.kind, t.game)
    local b = Rake.stats[k]
    if not b then
        b = { day = day, tier = t.tier, kind = t.kind, game = t.game, hands = 0, wagered = 0, seconds = 0, rake = 0 }
        Rake.stats[k] = b
    end
    return b
end

function Rake.RecordHand(t, wageredC, rakeC)
    if not t.tier or not t.game then return end
    local b = bucket(t)
    b.hands = b.hands + 1
    b.wagered = b.wagered + wageredC
    b.rake = b.rake + rakeC
end

-- Seconds a real player spent at the table with chips (the tuner's "player-hours")
function Rake.RecordSeconds(t, seconds)
    if not t.tier or not t.game or seconds <= 0 then return end
    local b = bucket(t)
    b.seconds = b.seconds + seconds
end

function Rake.Flush()
    local rows = {}
    for k, b in pairs(Rake.stats) do rows[#rows + 1] = b; Rake.stats[k] = nil end
    if #rows > 0 then GG.DB.StatsAdd(rows) end
end

---------------------------------------------------------------------
-- Tuner
---------------------------------------------------------------------
local function unitC(tier)
    local t = Config.Tiers[tier]
    return t and GG.M.ToCents(t.bigBlind) or nil
end

function Rake.Tune()
    Rake.Flush()
    local cfg = Config.Rake
    local changed = 0
    for _, s in ipairs(GG.DB.StatsWindow(cfg.WindowDays)) do
        local k = key(s.kind, s.tier, s.game)
        local unit = unitC(s.tier)
        if unit and unit > 0 and not cfg.FreeTiers[s.tier] and not cfg.Pinned[k] and cfg.Target[s.kind] then
            local game = GG.Registry.Get(s.game)
            local current = Rake.rates[k] and Rake.rates[k].rate or ((cfg.Seed[s.kind] or {})[s.tier] or 0)
            local rate, why = GG.M.TuneRate({
                hands = s.hands, wageredC = s.wagered, playerSeconds = s.seconds, unitC = unit,
                target = cfg.Target[s.kind], edge = game and game.houseEdge or 0,
                current = current, min = cfg.MinRate[s.kind], max = cfg.MaxRate[s.kind],
                step = cfg.MaxDailyStep, minSamples = cfg.MinSamples,
            })
            if why == 'tuned' then
                Rake.rates[k] = { rate = rate, samples = s.hands }
                GG.DB.RateSet(s.kind, s.tier, s.game, rate, s.hands)
                changed = changed + 1
                print(('[grumpy-gambling] rake %s: %.3f%% -> %.3f%% (%d hands, %.1f h)'):format(k, current * 100, rate * 100,
                    s.hands, s.seconds / 3600))
                if cfg.MinRate[s.kind] and rate <= cfg.MinRate[s.kind] and game and game.houseEdge > 0 then
                    print(('[grumpy-gambling] rake %s sits at the floor: the game edge alone meets the target'):format(k))
                end
            end
        end
    end
    Rake.lastTune = os.time()
    return changed
end

CreateThread(function()
    while not GG.Ready do Wait(1000) end
    Wait(60000)
    while true do
        Rake.Flush()
        if os.time() - Rake.lastTune >= Config.Rake.TuneEveryHours * 3600 then Rake.Tune() end
        Wait(60000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Rake.Flush() end
end)

exports('GetRakeRate', function(tableId)
    local t = GG.Tables.Get(tableId)
    return t and Rake.Rate(t) or nil
end)
