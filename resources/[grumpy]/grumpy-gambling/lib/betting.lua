-- No-limit betting rounds (blinds, check, call, bet/raise to, all-in, fold) shared by every poker-style game.
--
-- The round only does the bookkeeping and the rules. Each chip it moves (the `put` returned by Post and Act) is what
-- the module then sends to the core with Bet(handId, seat, put). Amounts are integer cents. Raises are "raise TO"
-- a street total, the way players say it.
--
-- Rules: the minimum raise is the size of the last full raise (the big blind to start a street). An all-in for less
-- than a full raise doesn't reopen the betting to players who already acted: they may only call or fold.
local Betting = {}
GGLib.Betting = Betting

local Round = {}
Round.__index = Round

-- o = { order = { seat, ... } (table order, used to find who acts next), stacks = { [seat] = cents },
--       bigBlind = cents }
function Betting.New(o)
    local r = setmetatable({
        order = {}, stack = {}, bet = {}, total = {}, folded = {}, allin = {}, acted = {},
        currentBet = 0, minRaise = o.bigBlind, bb = o.bigBlind, turn = nil,
    }, Round)
    for i, seat in ipairs(o.order) do
        r.order[i] = seat
        r.stack[seat] = o.stacks[seat] or 0
        r.bet[seat], r.total[seat] = 0, 0
        if r.stack[seat] <= 0 then r.allin[seat] = true end
    end
    return r
end

local function index(r, seat)
    for i, s in ipairs(r.order) do if s == seat then return i end end
end

function Round:Eligible(seat) return not self.folded[seat] and not self.allin[seat] end

function Round:Live()
    local list = {}
    for _, s in ipairs(self.order) do if not self.folded[s] then list[#list + 1] = s end end
    return list
end

-- Forced bet (blind / ante). Doesn't count as acting. Returns the chips actually put in.
function Round:Post(seat, amount)
    local put = math.min(amount, self.stack[seat] or 0)
    self.stack[seat] = self.stack[seat] - put
    self.bet[seat] = self.bet[seat] + put
    self.total[seat] = self.total[seat] + put
    if self.bet[seat] > self.currentBet then self.currentBet = self.bet[seat] end
    if self.stack[seat] == 0 then self.allin[seat] = true end
    return put
end

-- A new street: bets reset, the first eligible seat at or after `firstSeat` acts
function Round:NewStreet(firstSeat)
    for _, s in ipairs(self.order) do self.bet[s] = 0; self.acted[s] = false end
    self.currentBet, self.minRaise = 0, self.bb
    self.turn = nil
    self:Begin(firstSeat)
end

-- Sets who acts first (blinds already posted). First eligible seat at or after `firstSeat`.
function Round:Begin(firstSeat)
    local start = index(self, firstSeat) or 1
    self.turn = nil
    for k = 0, #self.order - 1 do
        local s = self.order[(start - 1 + k) % #self.order + 1]
        if self:Eligible(s) then self.turn = s break end
    end
    if self:Done() then self.turn = nil end
end

local function needsToAct(r, s)
    return r:Eligible(s) and (not r.acted[s] or r.bet[s] < r.currentBet)
end

-- The betting is over: one player left, or everyone who can still act has acted and matched the bet
function Round:Done()
    local live, eligible = 0, 0
    for _, s in ipairs(self.order) do
        if not self.folded[s] then
            live = live + 1
            if not self.allin[s] then eligible = eligible + 1 end
        end
    end
    if live <= 1 then return true end
    if eligible == 0 then return true end
    if eligible == 1 then
        -- a lone player who isn't all-in only acts if they still owe chips to call
        for _, s in ipairs(self.order) do
            if self:Eligible(s) then return self.bet[s] >= self.currentBet end
        end
    end
    for _, s in ipairs(self.order) do if needsToAct(self, s) then return false end end
    return true
end

-- What `seat` may do now. call = chips to add; raise = { min, max } as street totals ("raise to").
function Round:Legal(seat)
    if seat ~= self.turn or not self:Eligible(seat) then return nil end
    local stack, bet = self.stack[seat], self.bet[seat]
    local toCall = self.currentBet - bet
    local legal = { fold = true }
    if toCall <= 0 then legal.check = true else legal.call = math.min(toCall, stack) end
    local maxTo = bet + stack
    if not self.acted[seat] and maxTo > self.currentBet then
        local minTo = self.currentBet + self.minRaise
        if maxTo < minTo then minTo = maxTo end -- all-in for less than a full raise
        legal.raise = { min = minTo, max = maxTo }
    end
    return legal
end

local function advance(r)
    if r:Done() then r.turn = nil return end
    local start = index(r, r.turn) or 0
    for k = 1, #r.order do
        local s = r.order[(start - 1 + k) % #r.order + 1]
        if needsToAct(r, s) then r.turn = s return end
    end
    r.turn = nil
end

-- action: 'fold' | 'check' | 'call' | 'raise' (with `to` = street total) | 'allin'
-- Returns true, put (chips to send to the core) or false, err.
function Round:Act(seat, action, to)
    local legal = self:Legal(seat)
    if not legal then return false, 'not_your_turn' end
    local put = 0
    if action == 'allin' then
        if legal.raise and legal.raise.max == self.bet[seat] + self.stack[seat] then
            action, to = 'raise', legal.raise.max
        elseif legal.call then
            action = 'call'
        else
            return false, 'illegal'
        end
    end
    if action == 'fold' then
        self.folded[seat] = true
    elseif action == 'check' then
        if not legal.check then return false, 'illegal' end
    elseif action == 'call' then
        if not legal.call then return false, 'illegal' end
        put = legal.call
    elseif action == 'raise' then
        to = math.tointeger(to)
        if not legal.raise or not to or to < legal.raise.min or to > legal.raise.max then return false, 'illegal' end
        put = to - self.bet[seat]
        local size = to - self.currentBet
        if size >= self.minRaise then
            self.minRaise = size
            -- a full raise reopens the betting for everyone else
            for _, s in ipairs(self.order) do if s ~= seat then self.acted[s] = false end end
        end
        self.currentBet = to
    else
        return false, 'illegal'
    end
    self.stack[seat] = self.stack[seat] - put
    self.bet[seat] = self.bet[seat] + put
    self.total[seat] = self.total[seat] + put
    if self.stack[seat] == 0 and not self.folded[seat] then self.allin[seat] = true end
    self.acted[seat] = true
    advance(self)
    return true, put
end

-- A player left or timed out: fold them, and move the turn on if it was theirs
function Round:Remove(seat)
    if self.folded[seat] then return end
    self.folded[seat] = true
    if self.turn == seat then advance(self) elseif self:Done() then self.turn = nil end
end

-- After the betting: the part of the top bet nobody matched goes back to that player (no rake on it).
-- Returns seat, cents (or nil).
function Round:Uncalled()
    local top, topSeat, second = -1, nil, 0
    for _, s in ipairs(self.order) do
        local b = self.bet[s]
        if b > top then second = math.max(second, top); top, topSeat = b, s
        elseif b > second then second = b end
    end
    if topSeat and top > second and not self.folded[topSeat] then
        local amount = top - math.max(second, 0)
        self.stack[topSeat] = self.stack[topSeat] + amount
        self.bet[topSeat] = self.bet[topSeat] - amount
        self.total[topSeat] = self.total[topSeat] - amount
        if self.stack[topSeat] > 0 then self.allin[topSeat] = nil end
        return topSeat, amount
    end
    return nil
end

-- What the betting looks like for a view
function Round:State()
    return { currentBet = self.currentBet, minRaise = self.minRaise, turn = self.turn }
end
