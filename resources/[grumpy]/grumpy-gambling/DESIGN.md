# grumpy-gambling — core design

Status: **core complete** 2026-11-06 as v0.7.0: phases 1–6 built and tested in game, phase 7 (audit, docs,
compliance) done. Next: game modules (§15). Phase 3 was tested in real Lua 5.4 (`tests/`, incl. the test games
playing full hands through the core). Phase 3 adds
`server/play.lua` (views, action relay, stakes) and the dev-only `grumpy-gambling-test` resource; `lib/flow.lua`
became timers in `lib/server.lua`, and the NPC brain moves to phase 5. Layout additions to §4.2:
`shared/geometry.lua`, `server/registry.lua` (phase 1); `server/money.lua` (pure maths), `server/db.lua` (all money SQL),
`server/wallet.lua` (stacks) (phase 2). `server/hands.lua`, `rake.lua`, `house.lua` as planned. This file is the contract every
game module is built against. Update it whenever a decision changes.

---

## Contents
1. [Goals](#1-goals)
2. [Doctrine placement](#2-doctrine-placement)
3. [Decisions at a glance](#3-decisions-at-a-glance)
4. [Architecture](#4-architecture)
5. [Tables](#5-tables)
6. [Stake tiers](#6-stake-tiers)
7. [Money](#7-money)
8. [NPC players](#8-npc-players)
9. [Business (POB) tables](#9-business-pob-tables)
10. [Client: world, seating, NUI](#10-client-world-seating-nui)
11. [Module contract](#11-module-contract)
12. [Security](#12-security)
13. [Database](#13-database)
14. [Config outline](#14-config-outline)
15. [Build phases](#15-build-phases)
16. [Open items](#16-open-items)
17. [Sources](#17-sources)

---

## 1. Goals
- **Saloons as social hubs.** A lone player can sit down and play cards in a saloon long enough that other players
  arrive, sit in, and role-play starts. Solo play must stay worth it; real players always have a seat.
- **Money sink.** Every table skims a rake and part of it leaves the economy. Public dealer (PVD) tables are tilted
  toward the house (the server).
- **One core, many small games.** `grumpy-gambling` owns everything shared: cards, seating, betting, stacks, tiers,
  poker logic, rake, NPCs, tables, NUI. Each game is a lightweight **module** resource that only defines rules,
  betting rounds and odds, and declares itself **PVP** or **PVD**.
- **Business tables.** POB owners place tables in their business with two usable items and run them off a cashbox.

Nt_Blackjack and Nt_Holdem (`[community]`, GPLv3) are **reference only**: no code is copied (the repo is public).
Game data from them (anim dicts, prop names, seat and prop offsets, flow ideas) may be reused, re-verified in
`data/rdr3_discoveries/`.

## 2. Doctrine placement
| Table | Path | Stage | Notes |
|---|---|---|---|
| Front-of-house (cash) tables | Civilian | Survival → Enterprise by tier | Doctrine: "saloon games" (Civilian, Survival) |
| Back-room (bloodmoney) tables | Hybrid | Survival → Enterprise by tier | Doctrine: "rigged card games" (Hybrid, Survival) |

Tier ↔ stage: **Micro/Low = Survival, Mid = Stability, High = Enterprise.**

- Prices and caps are in the 1890s bands (see §6, compared against the 30-tier job matrix).
- **Bloodmoney:** a table is cash *or* bloodmoney, never both. Dirty in, dirty out. Bloodmoney never reaches a POB
  business account.
- **No reputation** is gained from gambling (it isn't a job).
- **Accepted deviation (owner's choice):** NPC players sit with made-up bankrolls, so money won from them is
  created and money lost to them is destroyed. Bounded by the NPC win cap (§8.3). Logged in `doctrine/compliance.md`.
- **rsg-roulette** is installed and conflicts with the doctrine (cash only, $500 max bet, no rake, ox_lib/ox_target).
  Plan: replace it with a roulette module and remove it from the framework.

## 3. Decisions at a glance
| Topic | Decision |
|---|---|
| NT code | Reference only, no copying |
| Money at the table | **Buy-in stack** saved in the DB; bets come from the stack; standing up cashes out |
| Currency | Per table: `cash` (front of house) or `bloodmoney` (back room) |
| Table types | **PVP** (players vs players) and **PVD** (players vs dealer/house) |
| Tier choice | First real player at an empty table picks **game + tier** (Low/Mid/High). Held until no real players remain, then reset |
| Micro tier | Practice tier, **2 admin-defined tables**, tier locked, each table all-PVP or all-PVD |
| Rake | **Taken out of every bet**: a $1 bet stays $1, and $1 minus the rake reaches the pot (PVD: is what's at risk and paid on). **Auto-tuned** so the average player loses about **3 big blinds per hour (PVP)** or **2.5 minimum bets per hour (PVD)**. PVP rates above PVD, higher tiers below lower ones, Micro 0% |
| Rake destination | Public tables: 100% destroyed. Business PVP: 50% cashbox / 50% destroyed. Business PVD: mostly or entirely destroyed (owner earns the house edge) |
| NPCs | Free NPCs like NT, bankroll made up. One seat always free for a real player. Net win from NPCs capped per rolling window |
| Business tables | 2 items (PVP table, PVD table). Only a **POB owner** can place, within X m of their business NPC. Cashbox owned by the placer |
| Bloodmoney tables | Low/Mid/High only (never Micro). Business back-room tables need the POB back-room upgrade |

## 4. Architecture

### 4.1 Why "library + services"
A module can't hand the core a live Lua table: anything passed between resources is copied. So the **game state
lives in the module** (its own Lua VM) and the module calls the core for anything that touches the world, the
players or money:

- **Core services (exports + events):** tables, seats, stacks, bets, settlement, rake, house money, NPC presence,
  view push to clients, animation and prop cues, persistence.
- **Core library (shared Lua files the module loads with `@grumpy-gambling/lib/...`):** cards and shoe, poker hand
  evaluator, betting-round engine with side pots, flow/timer helper, NPC brains. These run inside the module's VM
  with no cross-resource calls, so they're fast.

**The core is the only thing that moves money**, and it checks every settlement for conservation (§7.5). A buggy
module can stall a hand, but it can't create or delete money.

### 4.2 Core resource layout (planned)
```
grumpy-gambling/
  fxmanifest.lua          deps: rsg-core, rsg-inventory, rsg-target, rsg-gizmo, oxmysql; optional grumpy-pob
  install.sql
  shared/config.lua       tiers, rake, NPCs, models, items, limits, timers
  shared/models.lua       table model profiles: seat/dealer/card/chip anchors per model
  lib/                    loaded by modules (and the core) as shared scripts
    init.lua              GG namespace, version check
    cards.lua             decks, shoes, shuffle (Fisher-Yates), public/private card views
    poker.lua             5–7 card evaluator, hand names, compare
    betting.lua           betting rounds: blinds/antes, check/call/raise/fold/all-in, min-raise, side pots
    flow.lua              step/timer state machine (100–250 ms ticks, deadlines, action tokens)
    npc_brain.lua         confidence model + personalities (poker), simple brains (blackjack-style)
    server.lua            thin wrappers around core exports (GG.Bet, GG.Settle, GG.View, ...)
  server/
    main.lua              boot, module registry, game loop host for core-owned timers
    tables.lua            table registry, persistence, lifecycle (empty → configured → active → reset)
    seats.lua             sit/stand, seat locks, one-seat-per-player, disconnect handling
    wallet.lua            stacks, buy-in/cash-out, pending payouts, currency rules
    hands.lua             hand records, Bet/Return/Settle, conservation, crash recovery
    rake.lua              per-bet skim, caps, rakeable flag, splits
    house.lua             house accounts: mint, sink, cashboxes, cover reservations
    npc.lua               NPC seating rule, bankrolls, win cap window, regulars, tier modifiers
    admin.lua             /gambling: public & micro tables, bind world tables, calibrate, delete
    business.lua          items, placement checks, cashbox, owner settings, grumpy-pob hooks
  client/
    world.lua             distance-gated spawn of tables, chairs, dealer peds, NPC players
    seat.lua              sit/stand scenario, camera, controls while seated
    props.lua             cards, chips, pot props from cues
    anims.lua             player/NPC/dealer animation cues, tells
    target.lua            rsg-target options (sit, watch, cashbox, settings)
    nui.lua               NUI bridge
    admin.lua             gizmo placement, calibration tool
  html/                   NUI shell (house style, ui/theme.css, no vignette)
  locales/en.json
  README.md  DOCS.md
```

### 4.3 Module layout (planned)
```
grumpy-gambling-blackjack/
  fxmanifest.lua     dependency 'grumpy-gambling'
                     shared_scripts { '@grumpy-gambling/lib/init.lua', '@grumpy-gambling/lib/cards.lua', ... , 'shared/config.lua' }
  shared/config.lua  rules + odds (e.g. dealer hits soft 17, blackjack pays 3:2), within core limits
  server/game.lua    registers the game, runs its hands with the lib, calls core services
  locales/en.json    game-specific text
  README.md DOCS.md
```
No NUI, no props, no money code in modules. A module may add optional client cues (game-specific animations).

## 5. Tables

### 5.1 Kinds
| Source | Placed by | House money | Currency | Tier |
|---|---|---|---|---|
| **Public** | Admin (`/gambling`) | Server: mint on player wins, destroy on player losses | cash or bloodmoney | Chosen by first player |
| **Micro** | Admin, exactly 2 | Server | cash only | Locked to Micro |
| **Business** | POB owner, with an item | Owner's **cashbox** | cash (front) or bloodmoney (back room) | Chosen by first player, limited by owner settings and cashbox cover |

Each table is **PVP** or **PVD**. The kind decides which modules can run there. Public tables may be
**spawned** (model placed with rsg-gizmo) or **bound** to an existing map table (admin targets a supported world
table; nothing is spawned, chairs are found and frozen like NT does).

### 5.2 Lifecycle
```
EMPTY ──first real player sits──▶ CONFIGURING (picks game + tier; 120 s timeout)
  ▲                                     │
  │                                     ▼
  └──last real player leaves──── ACTIVE (module runs hands; NPCs fill per §8.1)
                                        │ (business only)
                                        ▼
                               CLOSED (owner closed it, cashbox can't cover, business lost, NPC moved out of range)
```
- The tier and game hold while **any real player** is seated. NPCs don't count.
- When the last real player stands up: the hand in progress finishes or is refunded, NPCs leave, the table resets.
- Micro tables skip the tier choice (locked). The first player still picks the game among modules of the table's kind.

### 5.3 Model profiles
`shared/models.lua` defines, per supported model, seat anchors (offset + heading from the table origin), dealer
anchor (PVD), card/chip/pot anchors and the chair model to spawn. Values are **measured in game** with the admin
calibration tool (`/gambling` → Calibrate), seeded from NT's world coords. Seat count comes from the profile; a
module declares `minSeats`/`maxSeats` and the core only offers it on models that fit.

Verified models (`data/rdr3_discoveries/objects/object_list.lua`):
`p_blackjacktable01x`, `p_blackjacktable02x` (PVD), `p_pokertable01x`, `p_gen_tablepoker01x` (PVP),
chairs `p_chairpokerfancy01x` / `p_gen_chairpokerfancy01x`, caddy `p_pokercaddy02x`, chips `prop_chip_white_x10`
and family, dealer hand cards `p_cardssplit01x_rrs`, cards `p_crd_<rank>_<suit>01x_<style>`
(e.g. `p_crd_10_c01x_bla`; styles bla, camp, gk, new, rho, rrs, std, val, van).

## 6. Stake tiers

### 6.1 Tier table (approved)
Buy-in is between **13× and 26× the big blind** (the minimum is the user's rule; the range adds sink).

| Tier | Stage | Blinds (SB / BB) | Buy-in min – max | NPC cap multiplier | NPC cap per window | Job matrix comparison |
|---|---|---|---|---|---|---|
| **Micro** | Training | $0.01 / $0.02 | $0.26 – $0.52 | 20× | **$5.20** | Below tier 1 ($15) |
| **Low** | Survival | $0.05 / $0.10 | $1.30 – $2.60 | 20× | **$26** | Tier 2 ($22–26) |
| **Mid** | Stability | $0.25 / $0.50 | $6.50 – $13.00 | 10× | **$65** | Tier 5 ($55–62) |
| **High** | Enterprise | $1.00 / $2.00 | $26 – $52 | 5× | **$130** | Tier 7–8 ($102–150) |

The cap multiplier applies to the **minimum** buy-in. Anchors: a drink is $0.10–0.20 (Low big blind), a
working horse $15–35 (High buy-in).

### 6.2 PVD limits
For dealer games the big blind becomes the **minimum bet**; **maximum bet = 10× minimum** (to confirm).
Micro $0.02–0.20, Low $0.10–1.00, Mid $0.50–5.00, High $2.00–20.00. Modules may lower the maximum, never raise it.

### 6.3 Rake rates (auto-tuned, approved 2026-11-05)
**Target (approved 2026-11-05):** the average player loses about **3 big blinds per player-hour at PVP** and
**2.5 minimum bets per player-hour at PVD** (game edge included). Config: `Config.Rake.Target = { Pvp = 3.0, Pvd = 2.5 }`.
The target is tied to the stakes, like a real card room, which takes roughly 5–6 BB per player-hour; ours is
about half that. It's a sink, not a ceiling: the swings are far bigger than the average, so a big win and walking
away is real; chasing it isn't.

Average hourly loss = (rake rate + game house edge) × amount wagered per hour, so:
**rate = target ÷ wagered per hour (in BB or min bets) − game edge**, kept inside per-tier min/max bounds.

Seed rates (used until real play data exists):

| Tier | PVP assumption | PVP seed rate | PVD assumption (blackjack, edge ≈ 0.5%) | PVD seed rate |
|---|---|---|---|---|
| Micro | — | **0%** (training) | — | **0%** |
| Low | 45 hands/h, 1.5 BB wagered per hand (67 BB/h) | **≈ 4.4%** | 80 rounds/h, avg bet 1.5× min (120 min bets/h) | **≈ 1.6%** |
| Mid | 45 hands/h, 2 BB (bolder NPCs, 90 BB/h) | **≈ 3.3%** | 80 rounds/h, 2× min (160/h) | **≈ 1.1%** |
| High | 45 hands/h, 2.5 BB (boldest NPCs, 112 BB/h) | **≈ 2.7%** | 80 rounds/h, 2.5× min (200/h) | **≈ 0.75%** |

- Higher tiers come out lower because more money crosses the table per hour there.
- PVD comes out lower because dealer games run more rounds per hour and the game's own edge does part of the work.
  A game whose edge alone exceeds the target (roulette ≈ 2.7% edge) sits at the PVD floor (`MinRate`, 0.25%) and is
  **logged**; loosen that module's rules if needed.

What it means for players (estimates; short-stack poker swings about ±30 BB/h, blackjack about ±10 bets/h):

| Tier | Cost per player-hour | Feels like | Ahead after 1 h | after 4 h | after 10 h | Hours to lose $250 (poker / blackjack) |
|---|---|---|---|---|---|---|
| Low | ~$0.30 | 2–3 saloon drinks | ~45% | ~40% | ~37% | ~830 / ~1,000 |
| Mid | ~$1.25–1.50 | a couple of hotel nights | ~45% | ~40% | ~37% | ~170 / ~200 |
| High | ~$5–6 | a box of ammo plus supper | ~45% | ~40% | ~37% | ~42 / ~50 |

A minimum buy-in lasts about 4–5 hours on average at any tier. Low tables can't drain large sums at any rake (that
would take several buy-ins per hour); the real sink is High tables and dealer games, where the money is (doctrine
rule 2, risk scales with capital). Ten High players for 2 h a night remove roughly $100–120 a night.

**Launch plan:** start at 3 / 2.5. Because the rake is invisible per hand, it can be raised later without player
backlash. After 2–3 weeks, read `grumpy_gambling_rake_stats` (money removed per day, hours per tier); if money is
still piling up, raise the targets in 0.5 steps. Later lever: NPCs slightly better than the average player, so losses
to them are destroyed too (strong players still win, up to the NPC cap).

**Auto-tuning:** the core records, per tier × kind (PVP/PVD) × game, the hands per hour, average stack at the table
and amount wagered (rolling 7 days, `grumpy_gambling_rake_stats`). Once a day (and on start) it recomputes each rate
with the formula above, clamps it to `[MinRate, MaxRate]`, limits each change to `MaxDailyStep` so rates drift
rather than jump, and logs the new rates. Until a bucket has `MinSamples` hands it uses the seed rate. Admins can
pin a rate in config to override the tuner.

**Sub-cent amounts:** at small stakes most single bets rake less than a cent (4.4% of $0.10 = $0.0044), and RSG
money only goes to whole cents. Each table keeps a **rake remainder** in fractions of a cent: every bet adds its exact
rake to it, and whenever it reaches $0.01 a cent leaves the pot (or the stake at PVD). The remainder carries across
hands. Where a bet's rake is a cent or more (e.g. 4.4% of $1 = $0.044), the whole cents come out of that bet
and only the fraction is carried. Either way it's invisible per hand.

See §7.4 for when the rake is taken and where it goes.

## 7. Money

### 7.1 Accounts (core ledger)
Every movement goes between named accounts and is checked for conservation:

| Account | Holds | Persisted |
|---|---|---|
| `pocket:<cid>` | the player's rsg-core money (`cash` / `bloodmoney`) | rsg-core |
| `stack:<cid>` | the player's chips at their current table | `grumpy_gambling_stacks` |
| `pot:<hand>` | bets in the current hand (per pot, for side pots) | `grumpy_gambling_hands` |
| `rake:<hand>` | skim held until the hand settles | `grumpy_gambling_hands` |
| `cashbox:<table>` | business table bank | `grumpy_gambling_cashboxes` |
| `npc:<seat>` | made-up NPC bankroll | memory only |
| `mint` / `sink` | money created / destroyed by the server | ledger lines only |
| `pending:<cid>` | money owed to an offline player | `grumpy_gambling_pending` |

Currencies never mix: every account entry carries the table's currency.

### 7.2 Stacks: buy-in and cash-out
- **Sit down:** choose an amount in the buy-in range; it's removed from pocket money (`RemoveMoney(currency, …)`)
  and becomes the stack. One seat per player, server-wide.
- **Top up** between hands, up to the tier maximum.
- **Stand up:** after the current hand (or immediately if not in one), the stack is paid back with `AddMoney`.
- **Disconnect:** the module auto-folds or stands the seat; the stack stays in the DB and is paid on next login
  (`pending`). **Resource stop / crash:** unsettled hands are refunded into stacks, stacks are paid to online
  players, offline ones go to `pending`.

### 7.3 Hands (as built in phase 2)
- **Integer cents** everywhere inside the core; dollars only at rsg-core (`AddMoney`/`RemoveMoney`).
- `BeginHand` opens a hand **in memory**. `Bet` records bets against the live stack. Nothing is written until
  **`Settle`**, which commits every stack, payouts owed, the rake remainder, the cashbox, the hand row and the ledger in
  **one database transaction**. A crash mid-hand therefore leaves everyone's pre-hand stack: the hand never happened.
  (This replaces the planned "write contributions per betting round and refund open hands on boot".)
- **PVP rake** is computed at settlement from the hand's total bets (same result as skimming each bet; an uncalled bet
  handed back with `Return` simply never pays it). The pot players see (`GetHand().pot`) is already net of it.
- **Side pots** are built by the core (`server/money.lua`) from the bets; the module only ranks the live seats
  (`{ {best}, {tied, tied}, ... }`) and the core splits each pot, odd cents by `oddOrder` or seat order.
- **PVD:** the rake comes out of each bet as it's placed; the rest is the stake, and `Settle` takes the total paid back
  to each seat (capped at stake × the game's `maxPayout`).

### 7.4 Rake: out of every bet
The bet amount never changes: a $1 bet takes $1 from the stack. The rake (§6.3 rate, through the table's rake
remainder) comes **out of** that $1.
- **PVP:** $1 minus the rake enters the pot; the rake goes to `rake:<hand>`. Uncalled bets handed back return their
  rake. If the module marks the hand **not rakeable** (e.g. Hold'em ends before the flop: "no flop, no drop"), the
  held rake goes back into the pot before settlement. Safety cap: `Config.Rake.Pvp.MaxPerHand` (3× big blind) per hand.
- **PVD:** $1 minus the rake is the stake **at risk and paid on** (at 1.6%, an even-money win on a $1 bet returns
  $1.98 and change; sub-cent amounts follow the remainder). Paying on the full $1 would make the house pay the rake, which
  removes the tilt.
- **Split at settlement:**

| Table | PVP rake | PVD rake |
|---|---|---|
| Public / Micro | 100% sink | 100% sink |
| Business | 50% cashbox, 50% sink | `Config.Rake.Pvd.OwnerShare` (default 0%) cashbox, rest sink; the owner earns the game's edge through the cashbox |

- Players never see the rake: no rate on the table UI and none sent to clients (owner's decision 2026-11-05, replacing
  the earlier "show the rate on the info card"). Modules can read it server-side (`GetStakes().rake`).

### 7.5 Conservation check
At `Settle`, for the hand: `Σ contributions = Σ payouts + rake` (PVP), or for PVD each seat's
`stake + house delta = payout`, with the house delta drawn from `mint`, `sink` or the cashbox. A settlement that
doesn't balance is **refused**: the hand is refunded, the module gets an error event, and a ledger line is written.

### 7.6 House money and cover (PVD)
- **Public tables:** player wins come from `mint`, losses go to `sink`. Tilt = game edge + skim.
- **Business tables:** the **cashbox** is the house. Before a round deals, the core **reserves** the worst-case payout
  of every bet on the table (module provides `maxPayout(bet)`, e.g. 2.5× for blackjack with splits/doubles handled
  by re-reserving). A bet the cashbox can't cover is refused; when it can't cover one minimum bet, the dealer says the
  house is closed and the table closes until the owner refills it.
- Optional **daily stop-loss** per table (owner setting).

## 8. NPC players

### 8.1 Seating rule
- Solo play is allowed. **NPCs = max(0, seats − real players − 1)**: one seat is always free for a real player.
  Six seats: 1 player → 4 NPCs, 2 → 3, 5 → 0.
- When a real player takes the free seat, an NPC leaves **at the end of the current hand**, restoring the free seat,
  until the table is all real players.
- NPCs only join tables with at least one real player and leave when the last one does.
- NT-style flow: up to N NPCs join per hand; each stays a random number of hands; personalities have
  cut-loss and leave-with-winnings rules.

**As built (phase 5):** NPCs join one at a time between hands (a tick every 3 s plus 2.5 s after each hand); leaving
(make room, capped, bust, cut loss, take profit, bored, storm off, caught) happens only when no hand is open. The seat
count is min(table seats, the game's `maxSeats`), and at most `Config.Npc.MaxPerTable`.

### 8.2 Money
- PVP: an NPC sits with a made-up bankroll (between the tier's buy-in min and max) drawn from `mint`; what it has
  left when it leaves goes to `sink`.
- **PVD: NPC bets move no money.** They're scenery. This keeps business owners from farming their own tables.
  As built: the NPC's own made-up stack still follows the result (ledgered `npc_mint`/`npc_sink`, note
  `pvd scenery`), with no rake, cover or house result.

### 8.3 Win cap (faucet guard)
- Per player, one **shared rolling window** across all tables and tiers (`Config.Npc.CapWindowMinutes`, default 90).
- Cap = the multiplier × the **minimum buy-in** of the tier the player is seated at (table in §6.1).
- **Counted per hand:** the NPCs' combined net result. If NPCs lost money, it's attributed to the real players who
  won, in proportion to their winnings. If NPCs won money, it's credited back to the real players who lost, in
  proportion to their losses.
- When a player reaches the cap, the NPCs at their table "call it a night" at the end of the hand, and NPCs won't sit
  with that player until the window frees up. Real-player games are unaffected.
- Window entries are persisted (relogging doesn't reset it) and purged after the window.
- As built: entries are written in the hand's settle transaction (`grumpy_gambling_npc_window`). Credits are capped at
  what each player actually won or lost that hand. Losing to NPCs lowers the window total again (it's net).
  Window: 90 minutes (`Config.Npc.CapWindowMinutes`).

### 8.4 Behaviour by tier
| Tier | Personality mix | Tells | Cheats |
|---|---|---|---|
| Micro | Patient teachers: tight/balanced, small raises | ×2 | Never |
| Low | NT-style mix (tight, balanced, loose, aggressive) | Normal | Back-room tables only |
| Mid | Fewer tight players, fold less to raises | Normal | Back-room tables only |
| High | Mostly aggressive/loose, call down more, bigger raises, "shark" regulars | Fewer | Back-room tables only |

### 8.5 Poker brain (lib/npc_brain.lua)
Reimplemented from the ideas in NT's confidence model, not its code. Confidence 0–100 from:
hand strength (preflop formula / made-hand table), whether the hole cards improve the board, draws (outs ÷ unseen),
board threat, blockers, opponents, position, pot odds, stack pressure and small random variation. Personality turns
confidence into check/call/raise/all-in with bluff and slow-play chances and raise sizing tied to the blinds.
**Additions over NT:**
- **Opponent tracking:** per hand-session counts of each player's raises, calls, folds and shown bluffs; NPCs call
  wider against players who raise everything and fold more to players who rarely bluff.
- Tier modifiers (§8.4), tilt and drunk modifiers (§8.7).
- Brains run **only on the NPC's turn**, with a short human-like delay. No polling.

PVD NPCs use simple brains (e.g. blackjack basic strategy with personality noise).

**As built (phase 5):** `lib/npc_brain.lua` (`Preflop` Chen-style score, `Strength` with made hand vs board, pair
rank, draws (flush, open-ended, gutshot), board threat and a multiway penalty; `Decide`; `Tracker`; `PvdBet`;
`ThinkMs`; `SharpSwap`). The core builds each NPC's profile (`GetNpc`) from `Config.Npc.Personas` + `TierMods` +
drunk + tilt + a regular's skill (less noise). `GGLib.NpcDecide` runs the brain and reports tells and chatter. Monte
Carlo equity was left out on purpose (server cost).

**Strangers as built:** a random model from `Config.Npc.Models` (some back-room models at bloodmoney tables) and a
server-chosen outfit number, applied as an outfit preset on every client (the same person for everyone). The ambient
ped scan from NT was not used: it needs a client to report models, and the preset gives the same variety.

### 8.6 Strangers and regulars
- **Strangers:** like NT, one nearby client scans networked ambient peds in an area around the table and returns a
  model and outfit; every client spawns its own local copy in the seat.
- **Regulars:** named recurring NPCs with a fixed look, personality, skill and a home table or town (as built: defined
  in `Config.Npc.Regulars`, not a DB table, so owners edit them like any config; only their memory is in the DB).
  They prefer their home tables. Each keeps a small memory per player (hands played together, net result,
  last seen), read when the player sits down, which drives greetings and grudges ("Back for more, friend?").

### 8.7 Flavour (only where cheap)
- **Tells:** when an NPC is very strong or bluffing, it sometimes plays a small animation cue in the world (not in the
  NUI). Rate by personality and tier. Players who watch closely get an edge.
- **Chatter:** short locale lines on events (big pot, bad beat, joining, leaving, greeting a regular's acquaintance)
  in the NUI feed.
- **Drunk:** late game-hours in saloons; looser play, more tells.
- **Tilt:** after a big loss, more aggressive for a few hands, or storms off.
- **Cardsharps (back room only):** an NPC that sometimes cheats (server-side: an improved hand from the deck), leaves a
  visible sleight tell, and can be **called out** by a player through rsg-target during or right after the hand.
  Correct call: hand refunded, cheater thrown out (any payout counts toward the NPC cap). Wrong call: consequences
  (to design with the module; e.g. the NPC takes offence). Detailed at module time.
  As built: the core handles the target, the checks and the outcome; the module says whether that NPC cheated this
  hand. Right: the module cancels the hand (everyone keeps their pre-hand chips) and the NPC is thrown out. Wrong: the
  NPC takes offence and the accuser can't call anyone out for 10 minutes. Call-outs work during a hand only; "right
  after the hand" is left for the poker module.
- **Tells and seated animation as built:** first in-game test (2026-11-06): the chair scenario alone looked stiff and
  no tells were seen (preflop hands rarely counted as strong, and the move's clip replaced the tell at once). Now
  `Config.Anim` gives every seated ped a looping upper-body poker idle (flag 25, swapped every 8–20 s) and a clip for
  every move, pot win and buy-in (`SeatCue`), from `mini_games@poker_mg@base` / `fem_relaxed` (the same set Nt_Holdem
  uses). NPCs decide at the start of their think time (`GGLib.NpcTurn`), so a tell (`look_no_cards_long_*` strong,
  `no_cards_idle_subtle_*` fidget for a bluff, `peek_cheat_idle` sleight) plays before the move; strong = strength
  ≥ 0.70, 60% × persona.
- **Drunk as built:** in-game hours 21:00–03:00 from rsg-weather (`GlobalState.rsgTime`), 35% chance (5% otherwise).

## 9. Business (POB) tables

### 9.1 Items
| Item | Places | Notes |
|---|---|---|
| `gambling_table_pvp` (Card Table) | PVP table (poker table model, 6 seats) | Unique, usable |
| `gambling_table_pvd` (Dealer's Table) | PVD table (blackjack table model, 4 seats + dealer) | Unique, usable |

Price and where they're sold: open (§16). Bought with clean cash only (an asset).

### 9.2 Placement checks
Run live in the rsg-gizmo `validate` (ghost turns red) **and** again on the server:
1. The player is the **current owner** of a grumpy-pob business (staff can't place).
2. The spot is within `Config.Business.MaxDistanceFromNpc` (default 25 m) of that business's NPC
   (`biz.points.npc`).
3. `exports['rsg-gizmo']:IsPlacementValid(src, coords, maxDistance)` and `SanitiseRotation(rot)`.
4. Per-business limit (`Config.Business.MaxTables`, e.g. 2 PVP + 2 PVD).
5. Back-room (bloodmoney) tables require the business's back-room upgrade.
6. The item is removed only after the table is saved.

Re-checked when an admin edits the business: tables now out of range close until the owner moves them
(`rsg-gizmo` `Edit`, owner only).

### 9.3 Cashbox
- Owned by the **player who placed the table**; only they can open it (rsg-target on the table).
- Same currency as the table. The owner funds it from pocket money and empties it any time.
- PVP tables need no funding (the box only collects the rake share). PVD tables run off it (§7.6).
- Owner settings: open/closed, allowed games, allowed tiers (only those the box can cover are offered), stop-loss.

### 9.4 Losing the business
| Event | Tables | Cashbox |
|---|---|---|
| Owner sells or leaves | Close | Owner can still empty it and pack the table up (item returned). After `Config.Business.AbandonDays`, auto pack-up: money to `pending`, item to the owner |
| Repossession (unpaid tax) | Removed | **Clean** boxes go to the government account (`AddGovMoney`); **dirty** boxes are destroyed (the gov account is clean) |
| Law audit (books warrant) | — | Dirty boxes can be **seized** (destroyed), shown on grumpy-pob's audit screen |
| Later: grumpy-robbery | — | Dirty boxes crackable by outlaws (exposed wealth, doctrine rule 2) |

**As built (phase 6):**
- Placement as in §9.2; the client's gizmo `validate` turns the ghost red past `MaxDistanceFromNpc`; the item is used
  from within that range + 5 m of the clerk; tables start with NPCs on.
- Dealer tables offer a tier only when the box holds `PvdCoverMaxBets` (20) × its max bet, and stay closed when no
  tier is covered. Owner settings: open/closed, stakes offered, NPCs on/off, name. (Allowed games and a stop-loss were
  left out: the stakes filter and the cover rule do that job.)
- Losing the business: any reason but tax → the tables close (`settings.orphaned`), the box can still be emptied and
  the table packed up; buying the business back reopens them; after `AbandonDays` (7) the server packs up (money to
  pending, item to `grumpy_gambling_pending_items`, given at login). Tax → `Biz.Repossess`: clean box to
  `AddGovMoney`, dirty box destroyed, no item. A law seizure (books warrant) destroys the business's dirty boxes
  (what isn't covering bets in play). The audit screen does not list cashboxes yet (`GetBusinessCashboxes` is there
  for it).
- An admin moving the clerk closes tables now outside the range until the owner moves them (owner Move = gizmo
  `Edit`, nobody seated). An admin deleting a business table packs it up for its owner.
- Item images (`gambling_table_pvp.png`, `gambling_table_pvd.png`) still to be made. Sold in grumpy-pob's manager
  "Gambling" tab (owner only, from the business account, user's request 2026-11-06) at $150 / $250 (draft: no
  doctrine band yet; between a heavy rifle and the $750 back room).

### 9.5 grumpy-pob changes needed (version bump, README/DOCS)
- Export: businesses owned by a citizenid, with id, label, NPC point and back-room flag.
- Export: is this player the owner of business X.
- Server events: ownership changed (id, old cid, new cid, reason) and repossessed (id).
- Audit screen hook to list and seize dirty cashboxes (phase 2 of POB integration).
- As built in grumpy-pob 1.2.0: `GetOwnedBusinesses(cid)`, `IsOwner(id, cid)`, `HasBackroom(id)`, `IsReady()`;
  events `ownerChanged(id, oldCid, newCid, reason)` (`bought`/`tax`/`admin`/`deleted`), `businessChanged(id)`,
  `seized(id, lawSrc)`.

## 10. Client: world, seating, NUI
- **Spawning:** tables, chairs, dealer peds and NPC players are **local entities**, spawned within
  `Config.SpawnDistance` and deleted when out of range. Distance-gated loop: long sleeps when far.
- **Seating:** rsg-target on each chair/seat zone → server seat lock → `GENERIC_SEAT_CHAIR_TABLE_SCENARIO`
  at the seat anchor (`scenario_types_with_conditional_anims.lua`); player frozen; stand restores position.
- **Animations:** seated play uses `mini_games@poker_mg@base` (poker) and
  `mini_games@blackjack_mg@player@base` / `@dealer@actions@deal` / `@dealer@actions@shuffle` (blackjack), verified
  in `ingameanims_list.lua`. The server sends cues; clients play them.
- **Props:** cards, chips and pot stacks spawn from cues at the model profile's anchors. Card style per table.
- **NUI shell** (core `html/`, house style, `ui/theme.css`, no vignette):
  seats ring (name, stack, status, bet, cards face up/down), board/dealer area, pots, action bar (buttons from the
  module with optional amount slider: min/max/step), timer, chatter/log feed, table info card (game, tier, rate).
  Cards are drawn in CSS: NT's PNG card faces are Rockstar-derived and aren't reused.
- **Spectating:** players near a table can watch (public view only, no hole cards).
- **Controls:** prompt to open/close the NUI, camera toggle; `Wait(0)` only while seated.

## 11. Module contract

### 11.1 Registration (module server, on start)
```lua
exports['grumpy-gambling']:RegisterGame({
    id       = 'blackjack',           -- unique, used in events
    label    = 'Blackjack',
    kind     = 'pvd',                 -- 'pvp' | 'pvd'
    minSeats = 1, maxSeats = 4,
    models   = { 'p_blackjacktable01x', 'p_blackjacktable02x' },
    dealer   = true,                  -- spawn a dealer ped (PVD)
    rules    = { maxBetMultiplier = 10 },  -- may only narrow core limits
    houseEdge = 0.005,                -- the game's own edge per unit wagered (PVP: 0); used by the rake tuner
    maxPayout = 2.5,                  -- PVD: worst-case payout per unit bet, for cashbox cover checks
})
```

### 11.2 Core → module (server events; `GGLib.RegisterGame(def, handlers)` routes them by game id)
| Event | Data | Module must |
|---|---|---|
| `tableStarted` | tableId, tier, currency, seats, options | Set up state, start hands |
| `seatTaken` | tableId, seat (player or NPC profile) | Add to the next hand |
| `seatLeaving` | tableId, seat, reason | Fold/stand it and confirm with `GG.SeatDone` |
| `action` | tableId, seat, actionId, amount | Validate legality and apply |
| `npcTurn` | — (the module calls the brain itself) | |
| `tableStopping` | tableId, reason | Finish or cancel the hand |

### 11.3 Module → core (lib wrappers over exports)
Built in phase 2 as exports (cents): `BeginHand(tableId)` → handId · `Bet(handId, seat, cents)` → ok, net ·
`Return(handId, seat, cents)` · `SetRakeable(handId, bool)` · `Settle(handId, { ranking | payouts })` ·
`CancelHand(handId, reason)` · `GetHand(handId)` · `GetSeats(tableId)` · `GetRakeRate(tableId)`.
PVD cover is reserved automatically inside `Bet` (no separate `Reserve`). Phase 3 adds the lib wrappers and
`View(tableId, publicView, privateViews)` · `Cue(tableId, cue)` · `Stand(tableId, seat)` · `Tier(tableId)`.

### 11.4 View model (sent to the NUI shell)
```lua
{ phase = 'betting', board = { cards }, pots = { 1.20, 0.40 }, timer = 30,
  seats = { [1] = { cards = { ... }, bet = 0.10, status = 'Raised', label = 'Two Pair' }, ... },
  actions = { { id = 'fold' }, { id = 'call', amount = 0.10 }, { id = 'raise', min = 0.20, max = 2.10, step = 0.05 } },
  info = { game = 'Texas Hold\'em', tier = 'Low', rate = 5 } }
```
Private views (hole cards) go only to that seat's player.

## 12. Security
- Every client request goes through the core: rate-limited, seat-owned, near the table, correct hand and action
  token; then the module validates game legality. Amounts are checked against stack, tier limits and step.
- Money only moves in the core, with conservation checks and ledger lines.
- Cards are drawn and kept on the server; clients receive only what their seat may see.
- Business actions check the owner citizenid and distance on the server; cashbox moves are atomic SQL updates
  (`balance = balance - ? WHERE balance >= ?`).
- Placement uses rsg-gizmo's server validation. Admin actions require `Config.AdminPermission`.

## 13. Database
```sql
grumpy_gambling_tables     (id, kind, source, model, bound, x, y, z, rx, ry, rz, currency, fixed_tier,
                            business_id, owner_cid, settings JSON, state, created_at)
grumpy_gambling_cashboxes  (table_id PK, currency, balance DECIMAL(14,2))
grumpy_gambling_stacks     (citizenid PK, table_id, currency, amount DECIMAL(14,2), updated_at)
grumpy_gambling_hands      (id, table_id, game, tier, currency, started_at, settled_at, wagered_c, rake_c, house_c, data JSON)
                                                                                -- written only when a hand settles
grumpy_gambling_ledger     (id, ts, table_id, hand_id, kind, from_acc, to_acc, amount, currency, cid, note)
grumpy_gambling_pending    (citizenid, currency, amount)
grumpy_gambling_npc_window (citizenid, ts, amount)
grumpy_gambling_regulars   (id, name, gender, model, outfit, personality, skill, home_table, traits JSON)
grumpy_gambling_regular_memory (regular_id, citizenid, hands, net, last_seen)
grumpy_gambling_rake_stats (day, tier, kind, game, hands, wagered_c, player_seconds, rake_c)   -- tuner input
grumpy_gambling_rake_rates (tier, kind, game, rate, samples)                                   -- tuner output
grumpy_gambling_rake_remainder (table_id PK, remainder DOUBLE)
```
The ledger records money in and out (buy-in, cash-out, cashbox, rake, mint, sink, refunds) and one line per settled
hand, not every bet.

## 14. Config outline
`Config.Tiers` (§6.1) · `Config.Pvd.MaxBetMultiplier` · `Config.Rake` (`Target.Pvp` 3.0 BB/h, `Target.Pvd` 2.5 min bets/h, seed rates,
`MinRate`/`MaxRate` per tier × kind, `MaxDailyStep`, `MinSamples`, pinned overrides, `Pvp.MaxPerHand`, splits,
`Pvd.OwnerShare`) ·
`Config.Npc` (enabled, cap multipliers, `CapWindowMinutes`, personalities, tier modifiers, tells, chatter, drunk
hours) · `Config.Business` (items, `MaxDistanceFromNpc`, `MaxTables`, `AbandonDays`, back-room requirement) ·
`Config.Timers` (setup, action, between hands) · `Config.SpawnDistance` · `Config.AdminPermission` ·
`Config.CardStyles` · `Config.AutoDatabase`. Every money value has a comment naming its doctrine band.

## 15. Build phases
| Phase | Delivers | Proven by |
|---|---|---|
| 1. Foundation | Resource skeleton, config, SQL, table registry, model profiles, `/gambling` admin (place public/micro, bind world tables, calibrate, delete), client spawning, sit/stand | Admin places a table; players sit and stand |
| 2. Money | Stacks, buy-in/cash-out, pending payouts, hands, Bet/Return/Settle with conservation, rake out of bets with sub-cent remainder and splits, rake stats + daily auto-tuner, mint/sink/cashbox, cover reservations, crash recovery | Ledger balances across forced crashes and disconnects; tuner moves a rate toward the 3 BB/h (PVP) and 2.5 min bets/h (PVD) targets on simulated data |
| 3. Module API + lib | Registration, events, view push, flow helper, cards, poker evaluator, betting engine with side pots; two dev test modules (PVD high card, PVP heads-up showdown) | Test modules play full hands, side-pot cases |
| 4. NUI shell | Generic table UI from the view model | Test modules playable from the NUI |
| 5. NPCs | Seating rule, bankrolls, win cap window, strangers, regulars, tier mixes, poker brain, tells/chatter/drunk/tilt hooks | Solo player with NPCs; cap triggers; seat-freeing works |
| 6. Business | Items, placement checks, cashbox, owner settings, limits, grumpy-pob exports and hooks, ownership loss, repossession, back-room rule | Owner places and runs tables; repossession test |
| 7. Wrap-up | README, DOCS, audit checklist, compliance, recipe + live deploy | Checklist passes |

All seven phases done (2026-11-05 to 2026-11-06): v0.1.0 – v0.7.0, each tested in real Lua 5.4 (`tests/`, 313
assertions with money conservation checked after every step) and phases 1–6 played in game on the dev server.

**Modules after the core** (suggested order): Blackjack (PVD) · Five-Card Draw (PVP, period-correct) ·
Texas Hold'em (PVP) · Faro (PVD, *the* 1890s saloon game) · Roulette (PVD, replaces rsg-roulette) · Poker dice.

## 16. Open items
Settled while building: item labels (Card Table, Dealer's Table) and seller (grumpy-pob manager "Gambling" tab);
PVD max bet 10× (in use); `BusinessShare.pvd` 0% (the box keeps the house result instead); NPC cap window 90 min;
cardsharp call-outs (§8.7 as built); anchors are calibrated in game per model.

Still open:
- Table prices: $150 / $250 drafts (grumpy-pob `Config.Gambling.Prices`), no doctrine band yet.
- Micro tables: locations and which is PVP vs PVD (admins place them with `/gambling`, max 2).
- Rake tuner bounds (`MinRate`/`MaxRate`/`MaxDailyStep`): watch the stats after launch.
- grumpy-pob's audit screen could list a business's cashboxes (`GetBusinessCashboxes` is ready).
- Saint Denis card style (`01x_std_labastille` vs `..._std`): check when the card props come with the poker modules.
- Not yet seen in game: a bloodmoney table with a cardsharp call-out.
- Removing rsg-roulette once the roulette module exists (doctrine gap 9).

## 17. Sources
| Value | File |
|---|---|
| Table, chair, caddy, chip, card models | `data/rdr3_discoveries/objects/object_list.lua` |
| Poker / blackjack anim dicts | `data/rdr3_discoveries/animations/ingameanims/ingameanims_list.lua` |
| `GENERIC_SEAT_CHAIR_TABLE_SCENARIO` | `data/rdr3_discoveries/animations/scenarios/scenario_types_with_conditional_anims.lua` |
| Money types incl. `bloodmoney` | `framework/rsg-core.md` |
| rsg-gizmo `Place`, `Edit`, `IsPlacementValid`, `SanitiseRotation` | `framework/resources/rsg-gizmo.md` |
| rsg-target API | `framework/resources/rsg-target.md` |
| grumpy-pob accounts, exports, `points.npc` | `builds/grumpy-pob/server/accounts.lua`, `server/main.lua`, `server/admin.lua` |
| Price bands, job matrix | `doctrine/pricing.md` |
| NT reference (flow, NPC model, offsets) | live `[community]/Nt_Blackjack`, `[community]/Nt_Holdem` |
