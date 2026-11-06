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
-- Settlement: one transaction for everything a hand changes.
-- s = { stacks = { { cid, tableId, currency, amount } }, remainder = { tableId, value },
--       cashbox = { tableId, currency, delta } | nil, hand = {...}, ledger = { entries } }
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
    local h = s.hand
    q[#q + 1] = { query = [[INSERT INTO grumpy_gambling_hands (id, table_id, game, tier, currency, started_at, settled_at,
        wagered_c, rake_c, house_c, data) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        values = { h.id, h.tableId, h.game, h.tier, h.currency, h.startedAt, now(), h.wagered, h.rake, h.house, json.encode(h.data) } }
    for _, e in ipairs(s.ledger) do q[#q + 1] = { query = LEDGER_SQL, values = ledgerParams(e) } end
    return MySQL.transaction.await(q) == true
end
