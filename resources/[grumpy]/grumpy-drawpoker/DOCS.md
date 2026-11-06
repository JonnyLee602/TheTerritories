# grumpy-drawpoker — developer docs

A grumpy-gambling game module (read the core's DOCS.md §6b first). Version 0.1.0.

## Contents
1. Architecture
2. Hand flow
3. The draw
4. NPCs
5. Views and props
6. Security
7. Tests

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | `Config.DrawPoker`: rules, timers, card layout, table models |
| `server/game.lua` | Hand flow per table, NPC draws, the core's events, view and props. `DrawPoker.*` exposes the pure helpers for tests |

Loads `@grumpy-gambling/lib/` init, cards, poker, betting, npc_brain (shared) and server (server). No client files.

## 2. Hand flow
Blinds (`Round:Post`, heads-up: the button posts the small blind and acts first) → five cards each (sharps may
`Brain.SharpSwap`) → `bet1` (no-limit, `GGLib.Betting`) → the unmatched part of the top bet goes back (`Return`) →
`draw` (each live player from the button's left, all-ins too) → `bet2` (`Round:NewStreet` from the button's left) →
showdown (`Poker.Best` of five, `Poker.Ranking`; the core builds side pots) → `Settle` → next hand. Everyone folding
before the draw: `SetRakeable(false)` (no draw, no drop). Timeouts: check or fold; at the draw, stand pat.

## 3. The draw
The action is `{ id = 'draw', pick = { max = 3, aceMax = 4 } }`; the core's panel lets the player click cards and sends
a bitmask (card 1 = 1, card 2 = 2, card 3 = 4 …). `validDraw` allows up to `MaxDraw` cards, or `MaxDrawWithAce` when
the single card kept is an ace. Thrown cards go to the muck; if the deck runs dry, the muck is shuffled back in.

## 4. NPCs
Betting: `GGLib.NpcTurn` with `bonus` before the draw (+0.18 four-flush, +0.12 open-ended four-straight) and the
table's opponent tracker. Draw: `npcDraw` keeps made hands (stands pat on a straight or better), throws the odd cards
of pairs/two pair/trips (a lone pair keeps its highest kicker if it would throw four), draws one to a four-flush or
open-ended straight, keeps an ace and draws four, else keeps the two highest; a `bluff` roll stands pat on nothing
(reported as a tell).

## 5. Views and props
`public.phase` = `bet1` / `draw` / `bet2`; `turn` = whoever bets or draws; `seats[]` with stack, bet, folded, allin,
cards (face down until a real showdown), `label` (Drew N / Stood pat, then the hand name), dealer button.
`private[seat]` = own cards and actions. Props: five face-down `p_crd_*` cards per live seat (`Config.DrawPoker.Layout`),
turned up at a showdown; the core adds the pot in the middle.

## 6. Security
Moves only through the core's relay (seated player, active table, rate limited). The module checks the phase, the turn
and the betting engine's legality; draw masks are validated (0–31, the throw limits). NPC seats ignore player actions.

## 7. Tests
In the core's `tests/test_drawpoker.lua`: NPC draws for every hand shape, draw validation, the empty-deck reshuffle,
200 hands through the real core with four players and an NPC (random legal moves, random and illegal draws) plus
fold-before-the-draw hands that pay no rake; money conserved after every step, stable across seeds.
