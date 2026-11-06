-- Every money-related query lives here, so the money code can run against an in-memory fake in tests/.
-- Amounts are integer cents.
local DB = {}
GG.DB = DB

local function now() return os.time() end

---------------------------------------------------------------------
-- Stacks (chips at a table) and pending payouts
---------------------------------------------------------------------
function DB.StackGet(cid)
    local r = MySQL.single.await('SELECT table_id, currency, amount_c FROM grumpy_gambling_stacks WHERE citizenid = ?', { cid })
    return r and { tableId = r.table_id, currency = r.currency, amount = math.tointeger(r.amount_c) or 0 } or nil
end

function DB.StackSet(cid, tableId, currency, amount)
    MySQL.query.await([[INSERT INTO grumpy_gambling_stacks (citizenid, table_id, currency, amount_c) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE table_id = VALUES(table_id), currency = VALUES(currency), amount_c = VALUES(amount_c)]],
        { cid, tableId, currency, amount })
end

function DB.StackDelete(cid)
    MySQL.query.await('DELETE FROM grumpy_gambling_stacks WHERE citizenid = ?', { cid })
end

function DB.StacksAll()
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT citizenid, table_id, currency, amount_c FROM grumpy_gambling_stacks') or {}) do
        out[#out + 1] = { cid = r.citizenid, tableId = r.table_id, currency = r.currency, amount = math.tointeger(r.amount_c) or 0 }
    end
    return out
end

function DB.PendingAdd(cid, currency, amount)
    MySQL.query.await([[INSERT INTO grumpy_gambling_pending (citizenid, currency, amount_c) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE amount_c = amount_c + VALUES(amount_c)]], { cid, currency, amount })
end

-- Reads and removes everything owed to a player: { { currency, amount } }
function DB.PendingTake(cid)
    local rows = MySQL.query.await('SELECT currency, amount_c FROM grumpy_gambling_pending WHERE citizenid = ?', { cid }) or {}
    if #rows > 0 then MySQL.query.await('DELETE FROM grumpy_gambling_pending WHERE citizenid = ?', { cid }) end
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = { currency = r.currency, amount = math.tointeger(r.amount_c) or 0 } end
    return out
end

---------------------------------------------------------------------
-- Ledger
---------------------------------------------------------------------
local LEDGER_SQL = [[INSERT INTO grumpy_gambling_ledger (ts, kind, table_id, hand_id, citizenid, currency, amount_c, note)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)]]

local function ledgerParams(e)
    return { e.ts or now(), e.kind, e.tableId, e.handId, e.cid, e.currency, e.amount, e.note and tostring(e.note):sub(1, 255) or nil }
end

function DB.Ledger(e)
    MySQL.insert(LEDGER_SQL, ledgerParams(e))
end

---------------------------------------------------------------------
-- Cashboxes, rake remainders, rates, stats
---------------------------------------------------------------------
function DB.CashboxGet(tableId)
    return math.tointeger(MySQL.scalar.await('SELECT balance_c FROM grumpy_gambling_cashboxes WHERE table_id = ?', { tableId })) or 0
end

-- Moves money in or out of a cashbox (+ in, - out). Never below zero: returns false when the box can't pay.
function DB.CashboxAdjust(tableId, currency, delta)
    if delta >= 0 then
        MySQL.query.await([[INSERT INTO grumpy_gambling_cashboxes (table_id, currency, balance_c) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE balance_c = balance_c + VALUES(balance_c)]], { tableId, currency, delta })
        return true
    end
    local r = MySQL.update.await('UPDATE grumpy_gambling_cashboxes SET balance_c = balance_c + ? WHERE table_id = ? AND balance_c >= ?',
        { delta, tableId, -delta })
    return (tonumber(r) or 0) > 0
end

function DB.CashboxDelete(tableId)
    MySQL.query.await('DELETE FROM grumpy_gambling_cashboxes WHERE table_id = ?', { tableId })
    MySQL.query.await('DELETE FROM grumpy_gambling_box_stats WHERE table_id = ?', { tableId })
end

function DB.BoxStats(tableId)
    local r = MySQL.single.await('SELECT rake_c, house_c, hands FROM grumpy_gambling_box_stats WHERE table_id = ?', { tableId })
    return { rake = r and math.tointeger(r.rake_c) or 0, house = r and math.tointeger(r.house_c) or 0, hands = r and r.hands or 0 }
end

function DB.PendingItemAdd(cid, item, amount)
    MySQL.insert.await('INSERT INTO grumpy_gambling_pending_items (citizenid, item, amount) VALUES (?, ?, ?)', { cid, item, amount or 1 })
end

-- { { id, item, amount } } owed to a player (not removed: call PendingItemDone for each one given)
function DB.PendingItems(cid)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT id, item, amount FROM grumpy_gambling_pending_items WHERE citizenid = ?', { cid }) or {}) do
        out[#out + 1] = { id = r.id, item = r.item, amount = r.amount }
    end
    return out
end

function DB.PendingItemDone(id) MySQL.query.await('DELETE FROM grumpy_gambling_pending_items WHERE id = ?', { id }) end

function DB.RemaindersAll()
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT table_id, remainder FROM grumpy_gambling_rake_remainder') or {}) do
        out[r.table_id] = tonumber(r.remainder) or 0
    end
    return out
end

function DB.RatesAll()
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT tier, kind, game, rate, samples FROM grumpy_gambling_rake_rates') or {}) do
        out[('%s:%s:%s'):format(r.kind, r.tier, r.game)] = { rate = tonumber(r.rate), samples = r.samples }
    end
    return out
end

function DB.RateSet(kind, tier, game, rate, samples)
    MySQL.query.await([[INSERT INTO grumpy_gambling_rake_rates (tier, kind, game, rate, samples) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE rate = VALUES(rate), samples = VALUES(samples)]], { tier, kind, game, rate, samples })
end

-- rows: { { day, tier, kind, game, hands, wagered, seconds, rake } } added to the day's totals
function DB.StatsAdd(rows)
    for _, r in ipairs(rows) do
        MySQL.query([[INSERT INTO grumpy_gambling_rake_stats (day, tier, kind, game, hands, wagered_c, player_seconds, rake_c)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE hands = hands + VALUES(hands),
            wagered_c = wagered_c + VALUES(wagered_c), player_seconds = player_seconds + VALUES(player_seconds),
            rake_c = rake_c + VALUES(rake_c)]], { r.day, r.tier, r.kind, r.game, r.hands, r.wagered, r.seconds, r.rake })
    end
end

function DB.StatsWindow(days)
    local out = {}
    local rows = MySQL.query.await([[SELECT tier, kind, game, SUM(hands) AS hands, SUM(wagered_c) AS wagered,
        SUM(player_seconds) AS seconds FROM grumpy_gambling_rake_stats WHERE day >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        GROUP BY tier, kind, game]], { days }) or {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { tier = r.tier, kind = r.kind, game = r.game, hands = tonumber(r.hands) or 0,
            wagered = tonumber(r.wagered) or 0, seconds = tonumber(r.seconds) or 0 }
    end
    return out
end

---------------------------------------------------------------------
-- NPC win-cap window and regulars' memory (DESIGN.md §8.3, §8.6)
---------------------------------------------------------------------
local WINDOW_SQL = 'INSERT INTO grumpy_gambling_npc_window (citizenid, ts, amount_c) VALUES (?, ?, ?)'

-- { { ts, amount } } for one player since `since`
function DB.WindowLoad(cid, since)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT ts, amount_c FROM grumpy_gambling_npc_window WHERE citizenid = ? AND ts >= ?',
        { cid, since }) or {}) do
        out[#out + 1] = { ts = r.ts, amount = math.tointeger(r.amount_c) or 0 }
    end
    return out
end

function DB.WindowPurge(before)
    MySQL.query('DELETE FROM grumpy_gambling_npc_window WHERE ts < ?', { before })
end

function DB.MemoryGet(regularId, cid)
    local r = MySQL.single.await('SELECT hands, net_c, last_seen FROM grumpy_gambling_regular_memory WHERE regular_id = ? AND citizenid = ?',
        { regularId, cid })
    return r and { hands = r.hands, net = math.tointeger(r.net_c) or 0, lastSeen = r.last_seen } or nil
end

-- rows: { { regularId, cid, hands, net, lastSeen } }: hands and net are ADDED to what's stored
function DB.MemorySave(rows)
    for _, m in ipairs(rows) do
        MySQL.query([[INSERT INTO grumpy_gambling_regular_memory (regular_id, citizenid, hands, net_c, last_seen) VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE hands = hands + VALUES(hands), net_c = net_c + VALUES(net_c), last_seen = VALUES(last_seen)]],
            { m.regularId, m.cid, m.hands, m.net, m.lastSeen })
    end
end

---------------------------------------------------------------------
-- Settlement: one transaction for everything a hand changes.
-- s = { stacks = { { cid, tableId, currency, amount } }, remainder = { tableId, value },
--       cashbox = { tableId, currency, delta } | nil, hand = {...}, ledger = { entries },
--       npcWindow = { { cid, ts, amount } } }
---------------------------------------------------------------------
function DB.Settle(s)
    local q = {}
    for _, st in ipairs(s.stacks) do
        q[#q + 1] = { query = [[INSERT INTO grumpy_gambling_stacks (citizenid, table_id, currency, amount_c) VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE table_id = VALUES(table_id), currency = VALUES(currency), amount_c = VALUES(amount_c)]],
            values = { st.cid, st.tableId, st.currency, st.amount } }
    end
    for _, p in ipairs(s.pending or {}) do
        q[#q + 1] = { query = [[INSERT INTO grumpy_gambling_pending (citizenid, currency, amount_c) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE amount_c = amount_c + VALUES(amount_c)]], values = { p.cid, p.currency, p.amount } }
    end
    if s.remainder then
        q[#q + 1] = { query = [[INSERT INTO grumpy_gambling_rake_remainder (table_id, remainder) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE remainder = VALUES(remainder)]], values = { s.remainder.tableId, s.remainder.value } }
    end
    if s.cashbox and s.cashbox.delta ~= 0 then
        q[#q + 1] = { query = [[INSERT INTO grumpy_gambling_cashboxes (table_id, currency, balance_c) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE balance_c = balance_c + VALUES(balance_c)]],
            values = { s.cashbox.tableId, s.cashbox.currency, s.cashbox.delta } }
    end
    if s.boxStats then
        q[#q + 1] = { query = [[INSERT INTO grumpy_gambling_box_stats (table_id, rake_c, house_c, hands) VALUES (?, ?, ?, 1)
            ON DUPLICATE KEY UPDATE rake_c = rake_c + VALUES(rake_c), house_c = house_c + VALUES(house_c), hands = hands + 1]],
            values = { s.boxStats.tableId, s.boxStats.rake, s.boxStats.house } }
    end
    local h = s.hand
    q[#q + 1] = { query = [[INSERT INTO grumpy_gambling_hands (id, table_id, game, tier, currency, started_at, settled_at,
        wagered_c, rake_c, house_c, data) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        values = { h.id, h.tableId, h.game, h.tier, h.currency, h.startedAt, now(), h.wagered, h.rake, h.house, json.encode(h.data) } }
    for _, e in ipairs(s.ledger) do q[#q + 1] = { query = LEDGER_SQL, values = ledgerParams(e) } end
    for _, w in ipairs(s.npcWindow or {}) do q[#q + 1] = { query = WINDOW_SQL, values = { w.cid, w.ts, w.amount } } end
    return MySQL.transaction.await(q) == true
end
