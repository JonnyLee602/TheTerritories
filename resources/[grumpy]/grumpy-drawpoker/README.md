# grumpy-drawpoker

Five-Card Draw for The Territories' card tables: the period's poker, players against each other, played through
[grumpy-gambling](../grumpy-gambling/README.md) (chips, stakes, rake, NPC players, side pots).

Version 0.1.0 · for RSG Framework (rsg-core 3.0.3) · see [DOCS.md](DOCS.md).

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `grumpy-gambling` 0.9.0+

## Features
- **Blinds and no-limit betting** (table stakes: bet up to your chips), with side pots and split pots.
- **Five cards each**, a round of betting, then **the draw**: from the button's left, each player throws away up to
  three cards (four if the one card kept is an ace) and is dealt new ones, or **stands pat**. Then a second round of
  betting and the showdown: best five-card hand wins.
- **No draw, no drop:** a hand that ends before the draw pays no rake.
- **At the table:** five face-down cards in front of every player, turned up at the showdown; folded hands are mucked;
  the pot sits in the middle; everyone's moves animate (check, call, bet, raise, all-in, fold, blinds).
- **Choosing your draw:** click the cards you want to throw away in the table panel, then **Draw N** (or **Stand pat**).
- **NPC players** (from the core) bet with the poker brain, value drawing hands before the draw, draw like a sensible
  player (keep pairs and trips, draw to four-flushes and open straights, keep an ace), and sometimes stand pat on
  nothing as a bluff. Back-room cardsharps may slip themselves a card; call them out.

## Installation
```cfg
ensure grumpy-gambling
ensure grumpy-drawpoker
```
No database, items or images of its own. Tables: any card (PVP) table with `p_tablepoker01x`, `p_pokertable01x` or
`p_gen_tablepoker01x` (up to 6 seats); players pick Five-Card Draw in the game picker.

## Configuration (`shared/config.lua`, `Config.DrawPoker`)
| Option | Default | Description |
|---|---|---|
| `Rules.MaxDraw` / `MaxDrawWithAce` | `3` / `4` | Cards a player may throw away |
| `Rules.NoDrawNoDrop` | `true` | No rake when the hand ends before the draw |
| `Timers.Act` / `Draw` | 30 s / 20 s | A betting turn (then check or fold), a draw (then stand pat) |
| `Timers.Next` / `Start` | 6 s / 2.5 s | Between hands; before the first hand |
| `Timers.Deal` / `TurnBeat` / `DrawBeat` / `Replace` / `Reveal` / `Settle` | see file | Pacing: cards dealt round the table, a breath before each turn, the draw, new cards one by one, showdown hands one at a time, then the pot |
| `Layout` | see file | Where the face-down cards lie in front of each seat (forward / right, metres) |
| `Models` / `MaxSeats` | three card tables / `6` | Tables the game is offered at |

## How to use
Sit at a card table, pick **Five-Card Draw** and the stakes, buy chips. On your turn: Fold, Check, Call, Bet/Raise
(slider) or All in. At the draw, click the cards to throw away, then **Draw N**, or **Stand pat**.

## Locales
English (`locales/en.json`).
