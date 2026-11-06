-- Blackjack rules, pure Lua (no natives), so they can be tested on their own. Cards are GGLib cards
-- ({ r = 2..14, s }). Amounts are integer cents.
--
-- Classic rules (Config.Rules): dealer stands on all 17s, blackjack pays 3:2, the dealer peeks with an ace or a ten
-- showing, double on any first two cards (also after a split), split pairs up to MaxHands hands, split aces get one
-- card each and can't be split again, insurance pays 2:1, no surrender.
BJ = {}

function BJ.Value(card)
    if card.r == 14 then return 11 end
    if card.r >= 10 then return 10 end
    return card.r
end

-- total, soft (an ace still counted as 11)
function BJ.Score(cards)
    local total, aces = 0, 0
    for _, c in ipairs(cards) do
        total = total + BJ.Value(c)
        if c.r == 14 then aces = aces + 1 end
    end
    while total > 21 and aces > 0 do total = total - 10; aces = aces - 1 end
    return total, aces > 0
end

-- A natural: the first two cards make 21 (not after a split)
function BJ.IsBlackjack(hand) return #hand.cards == 2 and not hand.split and BJ.Score(hand.cards) == 21 end
function BJ.IsBust(cards) return BJ.Score(cards) > 21 end

function BJ.CanDouble(hand, rules)
    if #hand.cards ~= 2 or hand.doubled or hand.fromAces then return false end
    if hand.split and not rules.DoubleAfterSplit then return false end
    return true
end

function BJ.CanSplit(hand, handCount, rules)
    if #hand.cards ~= 2 or handCount >= rules.MaxHands then return false end
    if hand.fromAces and not rules.ResplitAces then return false end
    return BJ.Value(hand.cards[1]) == BJ.Value(hand.cards[2])
end

function BJ.DealerHits(cards, rules)
    local total, soft = BJ.Score(cards)
    return total < 17 or (total == 17 and soft and rules.HitSoft17)
end

-- Peek: the dealer checks the hole card for blackjack with an ace or a ten-value showing
function BJ.DealerPeeks(upcard) return BJ.Value(upcard) >= 10 end

-- 'blackjack' | 'win' | 'push' | 'lose' for one hand against the dealer's final cards
function BJ.Outcome(hand, dealerCards)
    if BJ.IsBust(hand.cards) then return 'lose' end
    local mine = BJ.IsBlackjack(hand)
    local dealerBJ = #dealerCards == 2 and BJ.Score(dealerCards) == 21
    if mine and dealerBJ then return 'push' end
    if mine then return 'blackjack' end
    if dealerBJ then return 'lose' end
    local p, d = BJ.Score(hand.cards), BJ.Score(dealerCards)
    if d > 21 or p > d then return 'win' end
    if p == d then return 'push' end
    return 'lose'
end

-- What comes back to the player for a hand (stake included): blackjack 3:2, win 1:1, push the stake back
function BJ.Payout(net, outcome)
    if outcome == 'blackjack' then return net + (net * 3) // 2 end
    if outcome == 'win' then return net * 2 end
    if outcome == 'push' then return net end
    return 0
end

function BJ.InsurancePayout(net, dealerBlackjack) return dealerBlackjack and net * 3 or 0 end

---------------------------------------------------------------------
-- Basic strategy (multi-deck, dealer stands on soft 17, double after split). Returns 'hit' | 'stand' | 'double' |
-- 'split'. up = the dealer's upcard value (2..11).
---------------------------------------------------------------------
local function between(u, a, b) return u >= a and u <= b end

function BJ.Basic(hand, upcard, canDouble, canSplit)
    local up = BJ.Value(upcard)
    local cards = hand.cards
    if canSplit then
        local v = BJ.Value(cards[1])
        local split = (v == 11) or (v == 8)
            or (v == 9 and (between(up, 2, 6) or up == 8 or up == 9))
            or (v == 7 and between(up, 2, 7))
            or (v == 6 and between(up, 2, 6))
            or (v == 4 and between(up, 5, 6))
            or ((v == 2 or v == 3) and between(up, 2, 7))
        if split then return 'split' end
    end
    local total, soft = BJ.Score(cards)
    local function dbl(otherwise) if canDouble then return 'double' end return otherwise end
    if soft and #cards >= 2 then
        if total >= 20 then return 'stand' end
        if total == 19 then return up == 6 and dbl('stand') or 'stand' end
        if total == 18 then
            if between(up, 2, 6) then return dbl('stand') end
            if up == 7 or up == 8 then return 'stand' end
            return 'hit'
        end
        if total == 17 then return between(up, 3, 6) and dbl('hit') or 'hit' end
        if total == 15 or total == 16 then return between(up, 4, 6) and dbl('hit') or 'hit' end
        if total == 13 or total == 14 then return between(up, 5, 6) and dbl('hit') or 'hit' end
        return 'hit'
    end
    if total >= 17 then return 'stand' end
    if total >= 13 then return between(up, 2, 6) and 'stand' or 'hit' end
    if total == 12 then return between(up, 4, 6) and 'stand' or 'hit' end
    if total == 11 then return up <= 10 and dbl('hit') or 'hit' end
    if total == 10 then return up <= 9 and dbl('hit') or 'hit' end
    if total == 9 then return between(up, 3, 6) and dbl('hit') or 'hit' end
    return 'hit'
end

-- An NPC's move: basic strategy, with the personality's noise as the chance of a plain mistake (hit or stand)
function BJ.NpcMove(hand, upcard, canDouble, canSplit, persona)
    local move = BJ.Basic(hand, upcard, canDouble, canSplit)
    local noise = (persona and persona.noise or 0.06) * 2.5
    if math.random() < noise then
        local total = BJ.Score(hand.cards)
        if total <= 11 then return 'hit' end
        if total >= 19 then return 'stand' end
        return math.random() < 0.5 and 'hit' or 'stand'
    end
    return move
end

-- Hand label for the table panel: "18", "Soft 17", "Blackjack", "Bust"
function BJ.Label(cards, natural)
    if #cards == 0 then return nil end
    local total, soft = BJ.Score(cards)
    if total > 21 then return 'bust' end
    if natural then return 'blackjack' end
    return soft and total < 21 and ('soft:' .. total) or tostring(total)
end
