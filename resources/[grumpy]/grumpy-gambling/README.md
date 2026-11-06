# grumpy-gambling

The gambling core for The Territories: card tables, seating, stake tiers and (in later phases) stacks, rake, NPC players
and business tables, shared by small **game modules** (blackjack, poker, faro, …) that only define rules and odds.

Version 0.6.0 (**phase 6 of 7: business tables**) · for RSG Framework (rsg-core 3.0.3) · see [DOCS.md](DOCS.md) for
developers and [DESIGN.md](DESIGN.md) for the full design.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `rsg-target`, `rsg-gizmo`, `oxmysql`

> **Status.** Phases 1–6 are built: tables and seating, chips/hands/rake/ledger, the **module library** game modules
> are written with (`lib/`), the **table UI**, **NPC players**, and **business tables** for grumpy-pob owners. No real game modules are released yet (blackjack,
> poker, faro … come next). Dev servers: `grumpy-gambling-test` adds two test games, `/ggbot` overrides the NPC count,
> and `Config.DevGames = true` adds placeholder games for trying chips.

## Features
- **`/gambling` admin panel** (house style NUI):
  - **New table:** name, type (**PVP** player vs player, **PVD** player vs dealer), **Public** or **Micro** (practice),
    money (**cash** or **bloodmoney**, never both), model.
  - **Place new table** with rsg-gizmo, or **Use the map table I'm next to** to bind an existing map table (nothing is
    spawned; the chairs around it are frozen). For known map tables (e.g. the saloon card table `p_tablepoker01x` in
    Smithfields) the map's own chairs become the seats automatically, so no calibration is needed.
  - Per table: teleport, move (spawned tables), rename, open/close, delete.
  - **Calibrate:** place a ghost chair on every seat (and the dealer for PVD), saved for **this table** or as the
    **model default**. The panel shows the Lua to paste into `shared/models.lua` if you also want it in code.
- **Micro tables:** at most 2, cash only, always Micro stakes.
- **Tables in the world:** spawned only near players (table, chairs, dealer for PVD), with a map blip for open cash
  tables (back-room bloodmoney tables stay off the map).
- **Seating:** target a seat → **Sit down**. One seat per player across the server. Hold **R** to stand. Players are
  stood up when they die, wander off, disconnect or log out.
- **First player picks game and tier.** The first real player at an empty table chooses the game (from installed modules
  of the table's type) and the stakes (Low, Mid, High; Micro tables are fixed). The choice holds until the last real
  player leaves. If they take longer than 2 minutes and someone else is seated, the choice passes on. Press **G** to
  reopen the picker.
- **Bloodmoney tables** offer only Low, Mid and High.
- **Chips (buy-in stacks).** When the game starts, each seated player buys chips with pocket money (cash or bloodmoney,
  the table's money) within the tier's buy-in range (13–26 big blinds). Press **G** to top up between hands. Standing
  up pays the chips back. A player who disconnects, or anything still owed after a restart, is paid on their next login.
- **Chip stacks on the table.** Every player with chips gets a stack in front of their seat, one model per tier
  (Micro, Low, Mid, High), so people walking past can tell the stakes without sitting down.
- **Crash-safe hands.** A hand's bets live in memory and are written in one database transaction when it settles. If the
  server stops mid-hand, the hand never happened: everyone keeps their pre-hand chips.
- **Rake, taken out of every bet** and **auto-tuned** so the average player loses about 3 big blinds per hour (poker) or
  2.5 minimum bets per hour (dealer games, the game's own edge included). Fractions of a cent carry between hands. Public
  tables destroy the rake (a money sink). Micro tables pay none.
- **Ledger** of every buy-in, cash-out, payout, rake and house win or loss; hands are recorded too.
- **Table UI.** While seated, a panel at the bottom of the screen shows the table without taking the mouse: the
  board or the dealer's cards, the pot, every seat (stack, bet, dealer button, folded / all-in, whose turn, wins),
  your own cards, a turn timer, the table feed, and the stakes. On your turn it takes the mouse and
  shows your moves (Fold, Check, Call $x, All in, and a Min / slider / Max for bets and raises). **Esc** gives the
  mouse back so you can look around; **G** (Your turn) takes it again. It draws whatever the game sends, so every
  module gets it for free.
- **Seated animations:** everyone at a table (players and NPCs) moves like the game's own poker players: a looping
  idle that changes every few seconds, and a clip for every check, call, bet, raise, all-in, fold, blind, buy-in and
  pot win, so the table never looks frozen (`Config.Anim`).
- **NPC players** fill empty seats so a lone player always has a game: a table keeps **one seat free** for a real
  player (6 seats, 1 player → 4 NPCs; 2 players → 3 …). When someone takes the free seat, an NPC gives up its chair
  **at the end of the hand**. NPCs leave with the last real player.
  - **Personalities** (teacher, tight, balanced, loose, aggressive, shark), mixed by tier: patient teachers at Micro,
    bolder players and sharks at High. Each NPC has a session plan: cut its losses, leave with its winnings, or get bored.
  - **Poker brain** (`lib/npc_brain.lua`): hand strength, draws, board danger, opponents, position, pot odds, stack
    pressure and a little randomness, plus **reads** on players (calls wider against players who raise everything).
  - **Tells** in the world (never in the UI): a long look around with strong cards, fidgeting on a bluff. NPCs decide
    first and act after a moment's thought, so the tell plays before the move. Watch the NPCs to get an edge.
  - **Chatter** in the table feed: joining, big wins and losses, raises, leaving. **Drunks** in the evening (looser
    play, more tells, rambling), **tilt** after a big loss (wilder for a few hands, or storming off).
  - **Regulars:** named NPCs with a fixed look and personality who prefer their home saloon and remember you ("Back
    for more, Arthur?").
  - **Cardsharps** at back-room (bloodmoney) tables sometimes cheat. A tell gives them away; **Call out cheat** (target
    the NPC) voids the hand and throws them out if you're right. A wrong accusation has a cost.
  - **Free NPC money is capped:** NPC chips are created and destroyed, so what one player can win from NPCs is capped
    over a rolling 90 minutes (20× the minimum buy-in at Micro and Low, 10× at Mid, 5× at High). At the cap the NPCs
    call it a night at your table until the window frees up; games with real players carry on.
  - At dealer tables (PVD) NPC bets are scenery: they never touch the house's money.
- **Business tables** (needs grumpy-pob 1.2.0+): the owner buys tables in grumpy-pob's Manage business → **Gambling**
  tab (paid from the business account), then uses a **Card Table** (`gambling_table_pvp`) or
  **Dealer's Table** (`gambling_table_pvd`) item inside their business (within 25 m of its clerk; 2 of each per
  business), names it, picks cash or bloodmoney (bloodmoney needs the business's back room), and places it with
  rsg-gizmo (the ghost turns red outside the business).
  - Each table has a **cashbox** owned by the placer, in the table's money. Card tables need nothing: the box collects
    half the rake. At dealer tables the **box is the house**: it pays winners and keeps losses, and only stakes it can
    cover (20 max bets) are offered; an empty box keeps the table closed.
  - **Manage table** (target the middle of your table): put money in or take it out, see what the box earned, choose
    the stakes on offer, turn NPC players on or off, rename, close/open, move, or **pack up** (box to your pocket,
    item back).
  - **Losing the business:** unpaid tax repossesses the tables (clean boxes go to the government account, dirty ones
    are destroyed, no item back). Losing it any other way closes them: empty and pack up within 7 days, or it's done
    for you (paid at your next login). Buying the business back reopens them. A law seizure of the business's books
    also seizes its dirty cashboxes. Moving the business's clerk away closes tables left outside until they're moved.
- **Module library** (`lib/`): cards and shoes, a poker hand evaluator, a no-limit betting engine (blinds, min-raise,
  short all-ins that don't reopen the betting, uncalled bets), and server wrappers for the core (register a game,
  table events, hands, views, timers). A game module is a small resource that loads these files; see DOCS.md.
- Everything is checked on the server: admin permission, distances, seat ownership, model and type, micro limits.

## Installation
1. Put `grumpy-gambling` in your resources folder (e.g. `[grumpy]`).
2. `server.cfg`, after the resources it uses:
   ```cfg
   ensure rsg-core
   ensure rsg-target
   ensure rsg-gizmo
   ensure grumpy-gambling
   ```
   Game modules go **after** `grumpy-gambling`.
3. Database: tables are created automatically. To install them by hand, set `Config.AutoDatabase = false` and import
   `install.sql`.
4. In game: `/gambling` → **New table**.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `AutoDatabase` | `true` | Create tables from `install.sql` on start |
| `AdminCommand` / `AdminPermission` | `gambling` / `'admin'` | Admin panel command and rsg-core permission |
| `PlaceDistance` | `10.0` | rsg-gizmo range when placing or moving a table |
| `BindSearchRadius` | `3.0` | How far "use the map table I'm next to" looks |
| `Micro.Max` | `2` | Number of practice tables allowed |
| `SpawnDistance` | `40.0` | Tables, chairs and dealers spawn within this range |
| `SeatZoneRadius` / `InteractDistance` | `0.6` / `2.0` | rsg-target seat zone size and reach |
| `ServerSeatDistance` | `3.5` | Server tolerance between a player and their seat |
| `SetupTimeoutSeconds` | `120` | Time to pick game and tier before it passes to another seated player |
| `Seating.Scenario` | `GENERIC_SEAT_CHAIR_TABLE_SCENARIO` | Seated scenario |
| `Seating.FemaleZ` / `FreezeWorldChairRadius` | `0.0` / `0.75` | Female sit height fix / map chair freezing |
| `Seating.StandKey` / `SetupKey` / `StandHoldMs` | R / G / `750` | Prompt keys (control hashes) |
| `HideMapChairs.Enabled` / `Radius` / `Models` | `true` / `2.2` / windsor + poker chairs | Placed tables hide the map's own chairs around them while spawned (bound map tables are never affected) |
| `Dealer.Model` / `IdleDict` / `IdleClip` / `IdleFlag` | `u_m_m_bht_saintdenissaloon` / blackjack dealer idle / `25` | PVD dealer ped; the idle plays on the upper body (`IdleDict = nil` for none) |
| `Dealer.Seated` / `Chair` / `ChairYaw` | `true` / `p_windsorchair03x` / `180.0` | The dealer sits in a chair behind the table (like Nt_Blackjack); `false` = he stands |
| `Calibration.FaceTable` | `true` | Calibrated seats face the table centre; only the chair position matters |
| `Blips.Enabled` / `Style` / `Sprites` | `true` / coords / poker, blackjack | Map blips for open cash tables |
| `Currencies` | `cash`, `bloodmoney` | Table money types |
| `Tiers` | micro, low, mid, high | Stakes per tier (blinds, buy-in range, NPC cap). See DESIGN.md §6 |
| `Pvd.MaxBetMultiplier` | `10` | Dealer games: max bet = 10 × min bet |
| `DevGames` | `false` | Dev servers: placeholder games, `/gga <action> [dollars]` to act, `/ggbot [n|clear|auto]` (admin) to override the NPC count |
| `TableUI.AutoFocus` / `FeedLines` | `true` / `8` | Take the mouse on your turn; feed lines shown |
| `Business.Items` / `Models` | `gambling_table_pvp` / `pvd` | The two items and the models they place |
| `Business.MaxDistanceFromNpc` | `25.0` | Tables must stand this close to the business's clerk |
| `Business.MaxTables` | 2 + 2 | Per business |
| `Business.BackroomForBloodmoney` | `true` | Bloodmoney tables need grumpy-pob's back room |
| `Business.PvdCoverMaxBets` | `20` | A dealer table offers a stake only if its box holds this many max bets |
| `Business.AbandonDays` | `7` | A closed table of a lost business is packed up after this |
| `Npc.Enabled` / `MaxPerTable` | `true` / `5` | NPC players on or off; most NPCs at one table |
| `Npc.CapWindowMinutes` | `90` | The win-cap window (cap multipliers are in `Tiers`) |
| `Npc.Personas` / `Mix` / `TierMods` | see config | Personalities, who sits at which tier, how tiers shift them |
| `Npc.Models` / `Names` / `BloodmoneyModels` | townsfolk | Strangers' looks and names |
| `Anim` | poker clips | Seated idles (swap time), the clip for each move, win and tell, female versions |
| `Npc.Tells` | 60%, strong ≥ 0.70 | How often tells show (× the persona's `tells`) and what counts as a strong hand |
| `Npc.Chatter` | | Chance per event, gap between lines, number of locale lines |
| `Npc.Drunk` / `Tilt` | 21:00–03:00 | Drunk hours (rsg-weather time) and modifiers; tilt trigger and effects |
| `Npc.Sharp` | 15% of back-room NPCs | Cardsharps: how often they cheat, how often it shows, call-out cooldown |
| `Npc.Regulars` | 5 regulars | Named NPCs: look, personality, skill, home saloon, tiers |
| `ChipStacks.Enabled` / `Models` / `Forward` / `Height` | `true` / one per tier / `0.6` / `0.80` | Chip stack props in front of seats with chips; a model can override `chipForward` / `chipHeight` |
| `Money.SavePlayer` / `BuyInStep` | `true` / `smallBlind` | Save the player after a buy-in or cash-out; buy-in slider step |
| `Rake.Target` | pvp `3.0`, pvd `2.5` | Average loss per player-hour: big blinds (PVP), minimum bets (PVD) |
| `Rake.Seed` / `MinRate` / `MaxRate` | see file | Starting rates per tier, and the tuner's bounds |
| `Rake.MaxDailyStep` / `MinSamples` / `WindowDays` / `TuneEveryHours` | `0.0025` / `200` / `7` / `24` | How fast and from how much play the tuner moves a rate |
| `Rake.FreeTiers` / `Pinned` | micro / none | Tiers with no rake; fixed rates that skip the tuner (`['pvp:low:holdem'] = 0.04`) |
| `Rake.Pvp.MaxPerHandBB` | `3` | Safety cap on rake per poker hand, in big blinds |
| `Rake.BusinessShare` | pvp `0.5`, pvd `0.0` | Business tables (phase 6): share of the rake to the owner's cashbox |

Table models and their seat layouts are in `shared/models.lua` (seed values; calibrate in game). **Place new table**
offers the Smithfields saloon card table (`p_tablepoker01x` with `p_windsorchair03x` chairs) for PVP and
`p_blackjacktable01x` for PVD (it comes with its own four chairs, so none are spawned); other models are recognised only when binding a map table.

## How to use
**Admins** (`/gambling`, permission `admin`):
1. **New table** → name, type, Public/Micro, money, model → **Place new table** (rsg-gizmo) or stand next to a map table
   and **Use the map table I'm next to**.
2. Open the table in the list → **Calibrate this table** (or **Calibrate model default**). Place each ghost chair where a
   chair should be, facing the table (and the dealer for PVD). Right click cancels.
3. Close (hide) or delete tables from the same screen.

**Players:** walk up to a seat → **Sit down**. The first player picks the game and stakes. Everyone then buys chips
in the Chips window. The table panel shows the game; on your turn click your move (Esc to look around, **G** to come
back). **G** also opens the game picker (while choosing) or the Chips window (to top up between hands). Hold **R** to
stand up and cash out.

## Developer example
```lua
-- a module (server) registers its game on start
exports['grumpy-gambling']:RegisterGame({
    id = 'blackjack', label = 'Blackjack', kind = 'pvd',
    minSeats = 1, maxSeats = 4, models = { 'p_blackjacktable01x', 'p_blackjacktable02x' },
    dealer = true, houseEdge = 0.005, maxPayout = 2.5,
})

-- a hand (amounts are integer cents; only the game's own resource may call these for its tables)
local handId = exports['grumpy-gambling']:BeginHand(tableId)
local ok, stake = exports['grumpy-gambling']:Bet(handId, seat, 100)       -- PVD: stake = $1 minus the rake
exports['grumpy-gambling']:Settle(handId, { payouts = { [seat] = stake * 2 } })  -- PVD: total back to each seat
-- PVP: exports['grumpy-gambling']:Settle(handId, { ranking = { { 3 }, { 1, 5 } } })  -- best first, ties grouped
```

## Locales
English (`locales/en.json`). Every player-facing string, including the NUI (`ui_*` keys) and tier names, is in the
locale file. Add a language by copying `en.json` and setting `setr rsg:locale "<lang>"`.
