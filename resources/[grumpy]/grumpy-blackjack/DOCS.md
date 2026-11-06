# grumpy-blackjack — developer docs

A grumpy-gambling game module (read the core's DOCS.md §6b first). Version 0.1.0.

## Contents
1. Architecture
2. Round flow
3. Money
4. Views, props and animations
5. Security
6. Tests
7. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | `Config.Blackjack`: rules, timers, card layout, animations |
| `server/rules.lua` | Pure rules (`BJ.*`): score, soft totals, naturals, outcomes, payouts, can double/split, dealer draws, basic strategy, NPC moves, hand labels |
| `server/game.lua` | Round flow per table, the core's events and the view, props and animations |

Loads `@grumpy-gambling/lib/` init, cards, poker, npc_brain (shared) and server (server). No client files: the
core draws the table panel, the cards on the table and the animations.

## 2. Round flow
`startRound` (BeginHand; seats with chips; NPCs bet with `Brain.PvdBet`) → bets (`bet` slider: min bet … max bet in
min-bet steps) → `closeBetting` (no bets: CancelHand; shoe past `Penetration`: new shoe + shuffle clip) → deal (two
cards each, the dealer's second face down; cards appear one at a time) → insurance when the dealer shows an ace
(`insurance` = half the bet / `no_insurance`; NPCs decline unless drunk or noisy) → peek with an ace or ten: dealer
blackjack settles at once → turns in seat order, hand by hand (`hit`, `stand`, `double`, `split`; 20 s then stand;
NPCs use `BJ.NpcMove` = basic strategy with persona noise) → the dealer reveals and draws to 17 (only if some hand is
still live) → `Settle` with payouts → win/loss clips, collect/pay → cards collected → next round.

A player who leaves keeps their bets in: their hands stand and the core pays them any win. A player who buys in during
the betting window joins that round.

## 3. Money
Every chip goes through the core: the bet, a double, a split and insurance are each `GGLib.Bet` (the core takes the
rake from each and returns the net stake). Payouts per seat are the sum over its hands of `BJ.Payout(net, outcome)`
(blackjack net + 1.5 × net, win 2 × net, push net) plus insurance 3 × its net if the dealer had blackjack.
`maxPayout = 2.5` covers the worst case per unit staked; the core refuses anything more. NPC bets are scenery.

## 4. Views, props and animations
- View: `public.dealer` (hole card face down until turned), `public.dealerLabel` (the upcard, then the total),
  `public.seats[]` with `hands = { { cards, label, active } }` (one row per hand; the core's table panel draws them),
  `bet` (all chips staked), `label` = Insured; `private.actions` as above.
- Cards on the table: `GGLib.Props` with `at = 'seat'` (each hand side by side, cards fanning right) and
  `at = 'dealer'`, offsets from `Config.Blackjack.Layout`. Clients near the table spawn `p_crd_*` models.
- Animations: `GGLib.SeatAnim` (bet, double, insurance, hit, stand, split, win, lose; female set where it exists) and
  `GGLib.DealerAnim` (deal, hit, self hit `03`–`11`, reveal, peek, insurance gesture, pay, collect, retrieve cards,
  shuffle). Table-wide dealer clips get the seats they reach as a suffix in Rockstar's numbering (`Anim.Seats`).

## 5. Security
Moves come only through the core's action relay (seated player, active table, rate limited); the module checks the
phase, the turn, the hand and the free chips for every move. NPC seats ignore player actions. Amounts for doubles,
splits and insurance are fixed by the hand, never taken from the client; bets must be in min-bet steps within the
limits.

## 6. Tests
In the core's `tests/test_blackjack.lua`: rules and basic strategy cases, a 40,000-hand basic-strategy simulation
(edge well under 2.5%), and 250 rounds through the real core with three players and an NPC making random legal moves
(doubles, splits, insurance, naturals, dealer blackjacks, pushes all occur) with money conserved after every step.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| Blackjack isn't in the game picker | It needs a dealer (PVD) table with a blackjack table model; ensure it after grumpy-gambling |
| Cards float or sit in the table | Core `Config.Cards.Height`; per game `Config.Blackjack.Layout` |
| The dealer reaches for the wrong chair | Reorder `Config.Blackjack.Anim.Seats` |
| A clip doesn't play | Check F8; the dict/clip names are in data/rdr3_discoveries ingameanims_list.lua |
