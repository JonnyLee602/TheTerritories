-- Everything lives under Config.DrawPoker (this resource's own Config; namespaced so tests can load it next to the
-- core's).
Config = Config or {}
Config.DrawPoker = {}
local C = Config.DrawPoker

-- Five-Card Draw for grumpy-gambling (PVP: players against each other at a card table). Stakes, the rake, money and
-- NPC players come from the core: blinds are the tier's, bets are no-limit up to your stack (table stakes).
C.GameId = 'drawpoker'

-- Rules chosen 2026-11-06: blinds, no-limit, draw up to three cards (four when keeping an ace)
C.Rules = {
    MaxDraw = 3,
    MaxDrawWithAce = 4,          -- may throw four when the one card kept is an ace
    NoDrawNoDrop = true,         -- no rake when the hand ends before the draw
}

C.Timers = {                     -- milliseconds
    Act = 30000,                 -- each betting turn; then check or fold
    Draw = 20000,                -- each player's draw; then stand pat
    Start = 2500,                -- a new table, or a newcomer, before the first hand
    Next = 6000,                 -- results on show before the next hand
    NpcDraw = { 1200, 3000 },
    Deal = 170,                  -- one card dealt around the table
    TurnBeat = { 700, 1200 },    -- before each betting turn: everyone looks over, then they act
    DrawBeat = 1200,             -- before the draw starts
    Replace = 260,               -- one new card at the draw (after the thrown ones go)
    Reveal = 950,                -- the showdown: one hand turned up at a time
    Settle = 700,                -- after the last hand is shown, before the pot goes
}

-- Cards on the table (the core's SetProps; x = forward, y = right from each seat, metres). Face down until the
-- showdown; folded hands are mucked. The core puts the pot in the middle.
C.Layout = { x = 0.78, y = -0.09, step = 0.045, rise = 0.0006 }

C.Models = { 'p_tablepoker01x', 'p_pokertable01x', 'p_gen_tablepoker01x', 'p_tablepoker04x', 'p_tablepoker04ax' }
C.MaxSeats = 6
