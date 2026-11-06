# grumpy-blackjack

Blackjack for The Territories' card tables: players against the house at a dealer table, played through
[grumpy-gambling](../grumpy-gambling/README.md) (chips, stakes, rake, NPC players, business cashboxes).

Version 0.1.0 · for RSG Framework (rsg-core 3.0.3) · see [DOCS.md](DOCS.md).

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `grumpy-gambling` 0.8.0+

## Features
- **Classic 1890s rules:** six-deck shoe (reshuffled at 75%), dealer stands on all 17s, blackjack pays 3:2, the dealer
  peeks for blackjack with an ace or a ten showing. House edge about 0.4%; the core's rake does the rest.
- **Double down** on any first two cards (also after a split), **split pairs** up to four hands (split aces get one
  card each), **insurance** when the dealer shows an ace (half your bet, pays 2:1). No surrender.
- **Rounds:** 15 s to bet (it deals at once when everyone has bet), then each player plays in turn (20 s, then the
  hand stands), the dealer draws to 17, payouts, next round.
- **At the table:** the real cards lie on the table in front of each player and the dealer (face down until turned),
  the dealer deals, peeks, collects and pays with the game's own blackjack animations, and players tap for a card, wave
  to stand, push chips to double, and react to wins and losses.
- **NPC players** (from the core) play basic strategy with their personality's mistakes; drunks sometimes take
  insurance. Their bets never touch the house's money.
- Works at public tables, Micro tables and business tables (the owner's cashbox is the house).

## Installation
```cfg
ensure grumpy-gambling
ensure grumpy-blackjack
```
No database, items or images of its own. Tables: any dealer (PVD) table with `p_blackjacktable01x` or
`p_blackjacktable02x`; players pick Blackjack in the game picker.

## Configuration (`shared/config.lua`, `Config.Blackjack`)
| Option | Default | Description |
|---|---|---|
| `Rules.Decks` / `Penetration` | `6` / `0.75` | Shoe size; reshuffle when this much is dealt |
| `Rules.HitSoft17` | `false` | Dealer hits soft 17 (raises the house edge ~0.2%) |
| `Rules.DoubleAfterSplit` / `MaxHands` / `ResplitAces` | `true` / `4` / `false` | Split rules |
| `Rules.Insurance` | `true` | Offer insurance against a dealer ace |
| `HouseEdge` / `MaxPayout` | `0.0042` / `2.5` | Told to the core (rake tuner, cover checks) |
| `Timers.*` | bet 15 s, act 20 s, insurance 8 s | Round pacing (ms); `Card`/`CardAt` time each card to the dealer's reach, `TurnBeat` a breath before each turn, `Line` the paced result lines |
| `Layout.Seat` / `Layout.Dealer` | see file | Where the cards lie, from each seat and the dealer (forward / right, metres) |
| `Anim.Seats` | `{ 1, 2, 3, 4 }` | Our seat → Rockstar's seat number in the dealer's clips; swap if he reaches for the wrong chair |
| `Anim.Player` / `Anim.Dealer` | blackjack clips | Animations (data/rdr3_discoveries ingameanims list) |

The card deck's look is the core's `Config.Cards.Style` (Valentine by default).

## How to use
Sit at a dealer table, pick **Blackjack** and the stakes, buy chips. Each round: set your bet with the slider before
the timer runs out. When it's your turn: **Hit**, **Stand**, **Double** or **Split** (when allowed). When the dealer
shows an ace you're offered **Insurance** for half your bet. Your hands, totals and the dealer's cards are in the table
panel and on the table.

## Locales
English (`locales/en.json`).
