-- Everything lives under Config.Blackjack (this resource's own Config; namespaced so tests can load it next to the
-- core's).
Config = Config or {}
Config.Blackjack = {}
local C = Config.Blackjack

-- Blackjack for grumpy-gambling (PVD: players against the house). Stakes, the rake, money and NPC players come from
-- the core: the minimum bet is the tier's big blind, the maximum Config.Pvd.MaxBetMultiplier × that.
C.GameId = 'blackjack'

-- Classic 1890s rules (chosen 2026-11-06): about 0.4% house edge; the core's rake tuner counts it (HouseEdge).
C.Rules = {
    Decks = 6,
    Penetration = 0.75,          -- reshuffle when three quarters of the shoe is gone
    HitSoft17 = false,           -- dealer stands on all 17s
    DoubleAfterSplit = true,
    MaxHands = 4,                -- split up to three times
    ResplitAces = false,         -- split aces get one card each
    Insurance = true,            -- offered when the dealer shows an ace; pays 2:1
}
C.HouseEdge = 0.0042
C.MaxPayout = 2.5           -- per unit staked, worst case for the house (a 3:2 blackjack); the core's cover check

C.Timers = {               -- milliseconds
    Bet = 15000,                 -- betting window (deals early once everyone in the round has bet)
    Insurance = 8000,
    Act = 20000,                 -- each player's turn; then the hand stands
    Card = 650,                  -- one card dealt
    DealerStep = 1100,           -- the dealer's own cards after the players
    Result = 6000,               -- results on the table
    Next = 3000,                 -- between rounds
    Shuffle = 2400,
    NpcBet = { 1500, 6000 },     -- NPCs place their bets within this
}

-- Cards on the table (the core's SetProps; x = forward, y = right from the anchor, metres). Seat cards fan out to the
-- right; split hands sit side by side. Tune these in game.
C.Layout = {
    -- From the player out: their chip stack (core models.lua chipForward 0.42), then their cards. The bets show as
    -- the core's pot in front of the dealer (core Config.Pot).
    Seat = { x = 0.58, y = -0.04, step = 0.05, rise = 0.0006, handGap = 0.15 },
    Dealer = { x = 0.32, y = -0.12, step = 0.06, rise = 0.0006 },  -- close to the dealer; the pot lies beyond (core Config.Pot)
}

-- Animations: data/rdr3_discoveries/animations/ingameanims/ingameanims_list.lua (mini_games@blackjack_mg@*). The
-- dealer's table-wide clips take the seats they reach as a suffix in Rockstar's numbering (deal_124, win_13 …):
-- Seats maps our seat numbers to theirs (swap them if the dealer reaches for the wrong chair).
C.Anim = {
    Seats = { 1, 2, 3, 4 },
    Player = {
        dict = 'mini_games@blackjack_mg@player@base', fem = 'mini_games@blackjack_mg@fem_player@base',
        bet = { clips = { 'bet_a01', 'bet_b01' }, ms = 2300 },
        double = { clips = { 'bet_a01_dbl', 'bet_b01_dbl' }, ms = 2300 },
        insurance = { clips = { 'bet_ins' }, ms = 2300 },
        hit = { clips = { 'hit_lh_a', 'hit_rh_a', 'hit_lh_b' }, ms = 1100 },
        stand = { clips = { 'stand_rh_a', 'stand_lh_a', 'stand_rh_b' }, ms = 1500 },
        split = { clips = { 'take_split' }, ms = 2000 },
        win = { clips = { 'express_win_subtle_a', 'express_win_subtle_b', 'express_win_a' }, ms = 2500 },
        lose = { clips = { 'express_loss_subtle_a', 'express_loss_subtle_b', 'express_loss_a' }, ms = 2500 },
    },
    Dealer = {
        deal = { dict = 'mini_games@blackjack_mg@dealer@actions@deal_end_in_self', prefix = 'deal_', ms = 3200 },
        hit = { dict = 'mini_games@blackjack_mg@dealer@actions@deal', prefix = 'deal_', ms = 1000 },
        self = { dict = 'mini_games@blackjack_mg@dealer@self@hit', ms = 900 },  -- clips '03' .. '11' (card number)
        reveal = { dict = 'mini_games@blackjack_mg@dealer@self@hit', clip = 'reveal', ms = 900 },
        pay = { dict = 'mini_games@blackjack_mg@dealer@actions@pay_bets', prefix = 'win_', ms = 1700 },
        collect = { dict = 'mini_games@blackjack_mg@dealer@actions@retrieve_bets', prefix = 'loss_', ms = 2200 },
        cards = { dict = 'mini_games@blackjack_mg@dealer@actions@retrieve_cards', prefix = 'retrieve_', ms = 2400 },
        shuffle = { dict = 'mini_games@blackjack_mg@dealer@actions@shuffle', clip = 'standard_shuffle', ms = 2333 },
        insurance = { dict = 'mini_games@blackjack_mg@dealer@actions@insurance', clip = 'place_bets_gesture', ms = 2000 },
        peek = { dict = 'mini_games@blackjack_mg@dealer@actions@insurance', clip = 'peek', ms = 1500 },
        peekReveal = { dict = 'mini_games@blackjack_mg@dealer@actions@insurance', clip = 'peak_reveal', ms = 1500 },
    },
}
