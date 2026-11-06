-- In-memory replacement for server/db.lua (same functions), loaded after the server files (tests only).
local F = { stacks = {}, pending = {}, ledger = {}, cashboxes = {}, remainders = {}, rates = {}, stats = {}, hands = {},
    failSettle = false }
FakeDB = F
local DB = GG.DB

function DB.StackGet(cid) local r = F.stacks[cid]; return r and { tableId = r.tableId, currency = r.currency, amount = r.amount } end
function DB.StackSet(cid, tableId, currency, amount) F.stacks[cid] = { tableId = tableId, currency = currency, amount = amount } end
function DB.StackDelete(cid) F.stacks[cid] = nil end
function DB.StacksAll()
    local out = {}
    for cid, r in pairs(F.stacks) do out[#out + 1] = { cid = cid, tableId = r.tableId, currency = r.currency, amount = r.amount } end
    return out
end
function DB.PendingAdd(cid, currency, amount)
    local k = cid .. '|' .. currency
    F.pending[k] = { cid = cid, currency = currency, amount = (F.pending[k] and F.pending[k].amount or 0) + amount }
end
function DB.PendingTake(cid)
    local out = {}
    for k, p in pairs(F.pending) do
        if p.cid == cid then out[#out + 1] = { currency = p.currency, amount = p.amount }; F.pending[k] = nil end
    end
    return out
end
function DB.Ledger(e) F.ledger[#F.ledger + 1] = e end
function DB.CashboxGet(tableId) return F.cashboxes[tableId] or 0 end
function DB.RemaindersAll() return {} end
function DB.RatesAll() return {} end
function DB.RateSet(kind, tier, game, rate) F.rates[kind .. ':' .. tier .. ':' .. game] = rate end
function DB.StatsAdd(rows) for _, r in ipairs(rows) do F.stats[#F.stats + 1] = r end end
function DB.StatsWindow() return F.window or {} end

function DB.Settle(s)
    if F.failSettle then return false end
    for _, st in ipairs(s.stacks) do F.stacks[st.cid] = { tableId = st.tableId, currency = st.currency, amount = st.amount } end
    for _, p in ipairs(s.pending or {}) do DB.PendingAdd(p.cid, p.currency, p.amount) end
    if s.remainder then F.remainders[s.remainder.tableId] = s.remainder.value end
    if s.cashbox then F.cashboxes[s.cashbox.tableId] = (F.cashboxes[s.cashbox.tableId] or 0) + s.cashbox.delta end
    F.hands[#F.hands + 1] = s.hand
    for _, e in ipairs(s.ledger) do F.ledger[#F.ledger + 1] = e end
    return true
end
