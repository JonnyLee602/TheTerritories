# grumpy-gambling — developer docs

Version 0.7.0, core complete (foundation, money, module library, table UI, NPC players, business tables). The full design is in [DESIGN.md](DESIGN.md).

## Contents
1. Architecture
2. Data formats
3. Exports
4. Events for modules and other resources
5. Callbacks and net events
6. Integration examples
7. Persistence
8. Security model
9. Database schema
10. Server owner how-tos
11. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest |
| `shared/config.lua` | Admin, world, seating, dealer, blips, currencies, **tiers** |
| `shared/geometry.lua` | `Geo`: table-local ↔ world maths (`ToWorld`, `ToLocal`, `Ring`, `Wrap`) |
| `shared/models.lua` | `Models`: table model profiles (seats, chair, sit height, dealer) |
| `server/main.lua` | `GG` namespace, helpers, database creation, load order, `IsReady` |
| `server/money.lua` | `GG.M`: **pure** money maths in integer cents: rake with carried remainder, splits, side pots, awards, rake tuner |
| `server/db.lua` | `GG.DB`: every money query, including the one-transaction settlement |
| `server/registry.lua` | Game module registry (`RegisterGame`, `GetGames`), module stop handling |
| `server/tables.lua` | Table registry, profiles + calibration, persistence, lifecycle (empty → setup → active), sync |
| `server/rake.lua` | Current rates, per-table remainders, buffered play stats, the daily tuner, `GetRakeRate` |
| `server/house.lua` | Who pays dealer-game wins: the server (public/Micro) or a cashbox (business tables) and its cover check |
| `server/hands.lua` | The hand API: `BeginHand`, `Bet`, `Return`, `SetRakeable`, `Settle`, `CancelHand`, `GetHand`, `GetSeats` |
| `server/wallet.lua` | Buy-in / top-up, cash-out, payouts owed to offline players, restart recovery, Chips window |
| `server/seats.lua` | Sit / stand (cashing out), one seat per player, setup choice, disconnects, sync callback |
| `server/play.lua` | Views (`PushView`), player actions relayed to the game, `GetStakes`, `TableMessage`, `StandSeat` |
| `server/admin.lua` | `/gambling`: create, bind, move, rename, toggle, delete, teleport, calibrate |
| `client/main.lua` | `GGC` namespace, table sync, NUI bridge |
| `client/world.lua` | Distance-gated spawning of tables, chairs, dealers; seat targets; blips |
| `client/seat.lua` | Seated scenario, stand / choose-game / chips prompts, picker and chips callbacks |
| `client/view.lua` | Latest table view and feed for this player; dev `/gga` command (`Config.DevGames`) |
| `client/table.lua` | Table panel bridge: shows the view, takes the mouse on your turn (`GGC.MyTurn`), Esc / G focus, `act` callback |
| `server/business.lua` | Business tables: items, placement checks, cashbox, owner panel, grumpy-pob events (owner changes, repossession, seizure, NPC moves), abandonment, owed items |
| `client/business.lua` | Placing from the item (form + rsg-gizmo with a live NPC-distance check), the owner's panel, `GGC.MyTables` |
| `client/anim.lua` | Seated animations: idle loop over the chair scenario for the local player and local NPC peds, one-off cue clips |
| `server/npc.lua` | NPC players: seating rule, profiles (persona + tier + drunk + tilt), win-cap window, chatter, tells, regulars' memory, cardsharp call-outs; dev `/ggbot` |
| `lib/npc_brain.lua` | Poker brain (strength, decisions, opponent tracker), PVD bet sizing, think time, cardsharp card swap |
| `client/admin.lua` | Admin panel, rsg-gizmo placement/move, map table binding, calibration flow |
| `html/*` | NUI: admin panel, game/tier picker, Chips window (`script.js`) and the table panel (`table.js`), house style |
| `lib/*` | **Module library**, loaded by game modules (not by the core): `init.lua`, `cards.lua`, `poker.lua`, `betting.lua`, `server.lua` |
| `tests/*` | Not loaded by the game. Lua tests run in real Lua 5.4: `tests/run_tests.py` (Python 3.12 + `lupa`) |
| `locales/en.json` | All player-facing text |

## 2. Data formats
**Model profile** (`shared/models.lua`), offsets in table-local space (x right, y forward, z up, h relative heading):
```lua
p_tablepoker01x = {
    kind = 'pvp', label = 'Saloon card table', spawn = true,   -- spawn: offered in "Place new table"
    chair = 'p_windsorchair03x', sitZ = 0.5, chairYaw = 0.0,
    seats = { { x = 0.0, y = -1.28, z = 0.0, h = 0.0 }, ... },   -- chair positions (floor), facing heading
    dealer = { x = 0.0, y = -0.574, z = 1.0, h = 0.0 },          -- PVD only; z = ped root
}
```
Effective seats for a table: the table's own calibration → the model's database calibration → `shared/models.lua`.

`autoChairs = { radius = 1.7 }` (map table models): when an admin binds the table, the admin's client lists every
`chair` model within `radius` m of the table centre; the server range-checks them and saves them as the table's seats,
each facing the centre, numbered around the table. `p_tablepoker01x` (the Smithfields card table, chairs
`p_windsorchair03x`) uses it.

**Public table** (sent to clients, returned by `GetTable`):
`{ id, label, kind ('pvp'|'pvd'), source ('public'|'micro'), model, bound, x, y, z, h, currency ('cash'|'bloodmoney'),
fixedTier, enabled, seats, dealer, chair, sitZ, chairYaw, state ('empty'|'setup'|'active'), game, gameLabel, tier,
occupied = { [seat] = bool }, chips = { [seat] = bool } (has a stack), chipForward, chipHeight, version }`

**Tier** (`Config.Tiers[id]`): `{ order, label (locale key), stage, smallBlind, bigBlind, buyInMin, buyInMax
(× big blind), npcCapMultiplier, choosable, bloodmoney }`.

**Game definition** (`RegisterGame`): `{ id, label, kind, minSeats, maxSeats, models?, dealer?, houseEdge?, maxPayout?,
rules? }`. `models` (optional) limits the game to those table models; it must be models of the same kind.

## 3. Exports (server)
| Export | Returns | Notes |
|---|---|---|
| `IsReady()` | bool | Tables loaded |
| `RegisterGame(def)` | `ok, err` | Call from a module on start. The calling resource owns the game; when it stops, tables running it go back to setup |
| `GetGames()` | `{ id, label, kind, resource }[]` | Registered games |
| `GetTable(id)` | public table / nil | |
| `GetTables()` | public table[] | |
| `GetSeat(src)` | `{ tableId, seat }` / nil | Where a player sits |
| `GetSeated(tableId)` | `{ seat, src, cid, name }[]` | Real players at a table |
| `StandPlayer(src)` | bool | Stands a player up |

### Hand API (phase 2, for game modules)
Amounts are **integer cents**. Only the resource that registered a table's game may call these for that table.

| Export | Returns | Notes |
|---|---|---|
| `BeginHand(tableId)` | `handId` / `nil, err` | One open hand per table. Seats with chips join |
| `Bet(handId, seat, cents)` | `true, cents` / `false, err` | PVP: into the pot. PVD: the rake comes out and the rest is the stake at risk (returned); refused with `house_cover` if a cashbox can't cover it |
| `Return(handId, seat, cents)` | bool | PVP: hand back an uncalled bet (no rake on it) |
| `SetRakeable(handId, bool)` | bool | PVP: `false` = no rake this hand ("no flop, no drop") |
| `Settle(handId, result)` | `true, { awards, rake, house, wagered }` / `false, err` | PVP `{ ranking = { {seat}, {seat, seat} }, oddOrder? }`: best first, ties grouped, folded seats left out; the core builds side pots, takes the rake and splits. PVD `{ payouts = { [seat] = cents } }`: total back to each seat, at most stake × `maxPayout` |
| `CancelHand(handId, reason)` | bool | Nobody loses anything; players who left get their bets back |
| `GetHand(handId)` | `{ pot, wagered, rate, seats }` | `pot` is net of the rake paid so far (what players should see) |
| `GetSeats(tableId)` | `{ seat, src, cid, name, stack, available, inHand }[]` | |
| `GetRakeRate(tableId)` | number | Current rate for the table's tier and game |

Errors: `no_table`, `table_not_started`, `not_your_table`, `hand_open`, `no_players`, `game_needs_maxPayout`, `no_hand`,
`not_in_hand`, `bad_amount`, `not_enough_chips`, `house_cover`, `pvp_only`, `bad_ranking`, `bad_payouts`,
`payout_too_high`, `unbalanced`, `db_error` (the hand is cancelled).

### Play (phase 3, for game modules; only the game's own resource)
| Export | Returns | Notes |
|---|---|---|
| `PushView(tableId, public, private)` | bool | `public` goes to everyone seated; `private[seat]` only to that seat's player (hole cards, `actions`) |
| `TableMessage(tableId, src or nil, text)` | bool | A line for one player's or the whole table's feed (text already translated by the module) |
| `GetStakes(tableId)` | `{ tier, currency, kind, smallBlind, bigBlind, buyInMin, buyInMax, minBet, maxBet, rake }` | Cents |
| `StandSeat(tableId, seat)` | bool | e.g. a player who keeps timing out (NPC seats are removed) |
| `SeatNpc(tableId, seat, { name?, model?, outfit?, persona?, stack?, drunk?, sharp? })` | bool | Seats an NPC by hand (the core normally does it). NPCs have `npc = true` and no `src` in `GetSeats` |

### NPCs (phase 5, for game modules; only the game's own resource)
| Export | Returns | Notes |
|---|---|---|
| `GetNpc(tableId, seat)` | profile or nil | Persona numbers with tier/drunk/tilt applied, `think`, `sharp` (cheat chance per hand or nil), `regular`. Server only |
| `NpcEvent(tableId, seat, event)` | bool | `strong` / `bluff` (maybe a tell), `sleight` (a sharp cheated), or a move id for a chance of chatter |
| `ResolveCallOut(tableId, seat, caught)` | bool | Answer to a `callOut`: true = the NPC cheated this hand (cancel the hand first) |
| `SeatCue(tableId, seat, cue)` | bool | Plays a `Config.Anim.Cues` clip on a seat for everyone near the table; an NPC move may also get a chatter line |
| `GetTableLimits(businessId)` | `{ pvp = { item, placed, max }, pvd = ... }` | For grumpy-pob's Gambling tab |
| `GetBusinessCashboxes(businessId)` | `{ tableId, label, kind, currency, balance }[]` | Cashboxes of a business's tables (cents), e.g. for law screens |
| `GetNpcWindow(cid, tableId?)` | `{ total, cap }` | What a player has won from NPCs in the window, and the cap at that table (cents) |

No client exports.

## 4. Events for modules and other resources (server, local `AddEventHandler`)
| Event | Args | When |
|---|---|---|
| `grumpy-gambling:server:ready` | — | Tables loaded |
| `grumpy-gambling:server:tableStarted` | `tableId, gameId, tier, currency` | The first player picked game and tier |
| `grumpy-gambling:server:seatTaken` | `tableId, gameId, seat, src` | A player sat at an active table |
| `grumpy-gambling:server:seatLeft` | `tableId, gameId, seat, src` | A player left an active table |
| `grumpy-gambling:server:tableStopping` | `tableId, gameId, reason` | The last real player left (reason `empty`); an open hand is cancelled |
| `grumpy-gambling:server:stackChanged` | `tableId, gameId, seat, src, cents` | A player bought in or topped up |
| `grumpy-gambling:server:playerAction` | `tableId, gameId, seat, src, actionId, cents?` | A seated player acted (core checked seat, table and rate; the game checks the move) |
| `grumpy-gambling:server:playerCallOut` | `tableId, gameId, npcSeat, src` | A player accused a back-room NPC of cheating, during a hand. Answer with `ResolveCallOut` within 3 s (no answer = a wrong call) |

`seatTaken` / `seatLeft` also fire for NPCs, with `src = nil`.

The module library wraps these for game modules (`GGLib.RegisterGame` handlers, DESIGN.md §11).

## 5. Callbacks and net events
| Name | Side | Notes |
|---|---|---|
| `grumpy-gambling:server:sync` | callback | `{ tables, seat }` |
| `grumpy-gambling:server:adminData` | callback | Admin only |
| `grumpy-gambling:server:sit` (`tableId, seat`) | server | Distance, free seat, one seat per player |
| `grumpy-gambling:server:stand` | server | |
| `grumpy-gambling:server:requestSetup` / `configure` (`gameId, tierId`) | server | Setup player only |
| `grumpy-gambling:server:buyIn` (`dollars`) / `requestChips` | server | Seated player at an active table, not in a hand, within the buy-in range |
| `grumpy-gambling:client:chips` / `chipsClosed` | client | Chips window (amounts in cents) |
| `grumpy-gambling:server:action` (`actionId, cents?`) | server | Seated player at an active table; 250 ms rate limit |
| `grumpy-gambling:server:callOut` (`tableId, seat`) | server | Seated at that bloodmoney table, an NPC seat, a hand in play, not blocked by a wrong call |
| `grumpy-gambling:server:bizCreate` (`{ kind, businessId, label, currency, coords, heading }`) | server | Owner of that business, item in inventory, within `MaxDistanceFromNpc` of its clerk, under `MaxTables`, back room for bloodmoney; the item is removed after the table is saved |
| `grumpy-gambling:server:bizAction` (`tableId, action, value`) | server | Table owner within `ManageDistance + 2`: `deposit`/`withdraw` (dollars), `toggle`, `npcs`, `tiers` ({ id = true }), `rename`, `packup` |
| `grumpy-gambling:server:bizMove` (`tableId, coords, heading`) | server | Owner, nobody seated, still inside the business |
| `grumpy-gambling:server:bizPanel` / `bizMine` | callback | Owner panel data / the caller's table ids |
| `grumpy-gambling:client:bizPlace` / `bizPanel` / `myTables` | client | Place form, panel refresh, owned table ids |
| `grumpy-gambling:client:seatCue` (`tableId, seat, cue`) | client | Plays a clip on that seat: your own ped if it's your seat (synced by the network), else the local NPC ped |
| `grumpy-gambling:client:view` (`tableId, public, private, seat`) / `message` (`tableId, text`) | client | Table view and feed |
| NUI `act` (`{ id, amount }`) / `tableBlur` | NUI → client | A move from the action bar (sent as `server:action`); Esc on the table |
| `grumpy-gambling:server:admin*` | server | Admin only: `Create`, `Move`, `Rename`, `Toggle`, `Delete`, `Teleport`, `Calibrate`, `ResetCalibration` |
| `grumpy-gambling:client:sync` / `table` / `removeTable` | client | Table data |
| `grumpy-gambling:client:seated` / `stood` / `setup` / `setupClosed` | client | Seat state and picker |

## 6. Integration examples
```lua
-- server: is this player at a card table?
local seat = exports['grumpy-gambling']:GetSeat(src)
if seat then print(('seat %d at table %d'):format(seat.seat, seat.tableId)) end

-- server: who is at table 3?
for _, p in ipairs(exports['grumpy-gambling']:GetSeated(3) or {}) do print(p.seat, p.name) end
```

## 6b. Writing a game module
A module is a small resource; game state lives in it, money and players live in the core.

```lua
-- fxmanifest.lua
shared_scripts { '@rsg-core/shared/locale.lua', '@grumpy-gambling/lib/init.lua', '@grumpy-gambling/lib/cards.lua',
    '@grumpy-gambling/lib/poker.lua', '@grumpy-gambling/lib/betting.lua' }   -- only what the game needs
server_scripts { '@grumpy-gambling/lib/server.lua', 'server/game.lua' }
dependencies { 'rsg-core', 'grumpy-gambling' }    -- ensure the module after grumpy-gambling

-- server/game.lua
GGLib.RegisterGame({ id = 'blackjack', label = locale('label'), kind = 'pvd', minSeats = 1, maxSeats = 4,
    houseEdge = 0.005, maxPayout = 2.5 }, {
    tableStarted = function(tableId, tier, currency) end,   -- the first player picked this game
    seatTaken = function(tableId, seat, src) end,
    seatLeft = function(tableId, seat, src) end,            -- fold / stand them; bets already in stay in
    stackChanged = function(tableId, seat, src, cents) end, -- bought in or topped up: maybe start a hand
    action = function(tableId, seat, src, id, cents) end,   -- validate against your own rules
    tableStopping = function(tableId, reason) end,          -- the core already cancelled any open hand
})
```
- **Library:** `GGLib.Cards` (`NewShoe(decks)`, `:Draw()`, `Public`, `PublicList`, `Parse`, `Str`), `GGLib.Poker`
  (`Best(cards)` → score, name, five cards; `Compare`; `Ranking(entries)` → the groups `Settle` wants),
  `GGLib.Betting` (`New{order, stacks, bigBlind}`, `:Post`, `:Begin`, `:NewStreet`, `:Legal`, `:Act`, `:Remove`,
  `:Done`, `:Live`, `:Uncalled`), wrappers (`GGLib.BeginHand`, `Bet`, `Return`, `SetRakeable`, `Settle`, `Cancel`,
  `Hand`, `Seats`, `Table`, `Stakes`, `Stand`, `View`, `Say`), timers (`GGLib.After(key, ms, fn)` replaces any timer
  with the same key; `CancelTimer`, `CancelTimers(prefix)`), `GGLib.Fmt(cents)`, `GGLib.Cents(dollars)`.
- **Money:** every chip the betting engine moves (`put` from `Post`/`Act`) goes to the core with `GGLib.Bet`. Give back
  `Uncalled()` with `GGLib.Return`. Settle with a ranking (PVP) or payouts (PVD). Never touch player money yourself.
- **The table UI** draws any view: `public.board` or `public.dealer` (card lists), `pot`, `turn` (seat), `deadline`
  (os.time; the core adds `_now` so the client counts down on the server clock), `phase = 'waiting'`, `seats[]` with
  `seat, name, stack?, bet?, cards?, label?, dealer?, folded?, allin?`, and `results[]` (`seat, amount`). Action buttons
  come from `private.actions`: `{ id, amount? }` is a button, `{ id, min, max, step }` a slider. Labels use locale keys
  `ui_act_<id>` (fold, check, call, bet, raise, allin, hit, stand, double, split are included; others show the id).
  The core also adds `public._table` (label, game, tier, blinds, currency) for the header. The rake rate is never sent to
  players (owner's decision); modules can read it server-side with `GetStakes`.
- **Views** (DESIGN.md §11.4): `public` = { game, phase, pot, board, turn, deadline, seats = { { seat, name, stack,
  bet, cards, label, ... } }, results }, `private[seat]` = { cards, actions = { { id = 'fold' }, { id = 'call',
  amount }, { id = 'raise', min, max, step } } } (cents). Phase 4 draws this in the NUI.
- **NPCs:** the core seats and removes them; a module just plays their seats. `GGLib.Seats` marks them `npc = true`.
  On an NPC's poker turn call `GGLib.NpcTurn(timerKey, tid, seat, ctx, act)` (ctx: `hole, board, legal, pot,
  currentBet, myBet, stack, bigBlind, step, opponents, position, opp`): it decides at once (a tell plays while it
  "thinks") and calls `act(action, amount)` after the think time; check the turn is still theirs, then `Round:Act`.
  (`GGLib.NpcDecide` is the same without the timer.) **Animations:** call `GGLib.Cue(tid, seat, id)` for every move
  (players and NPCs: `check`, `call`, `bet`, `raise`, `allin`, `fold`, `blind`); the core cues buy-ins and pot wins. Keep a
  `GGLib.Brain.Tracker()` per table, `:Note(cid, action)` on every move and `:Shown(cid, wasBluff)` at showdown, and pass
  `tracker:Profile(cid)` of the bettor as `opp`. Dealer games size NPC bets with `GGLib.Brain.PvdBet(profile, min, max,
  available, step)`; those bets move no house money. **Cardsharps:** if `profile.sharp` and `math.random() <
  profile.sharp`, `GGLib.Brain.SharpSwap(shoe, hole, board)` swaps in a better card (deck stays whole); remember it, call
  `GGLib.NpcEvent(tid, seat, 'sleight')`, and in the `callOut` handler cancel the hand and `GGLib.ResolveCallOut(tid,
  seat, true)` if that NPC cheated, else `false`.
- **Example:** `grumpy-gambling-test` (dev only) has a full PVP game (`server/showdown.lua`, NPC brain, tracker,
  sharps and call-outs) and PVD game (`server/highcard.lua`) in about 300 and 150 lines.

## 7. Persistence and the money model
Tables (placement, money type, Micro flag, per-table calibration, open/closed) and model calibrations are saved in the
database. Seats, game and tier are runtime only: a restart empties every table and stands everyone up.

**Money** (integer cents inside the core; dollars only at rsg-core):
- **Buy-in:** `RemoveMoney` (the table's currency), then the stack row is written and the player is saved.
- **During a hand** bets live in memory. **Settle** writes every stack, payouts owed, the rake remainder, the cashbox,
  the hand and the ledger in **one transaction**. A crash before that = the hand never happened.
- **Stand up:** what isn't in an open hand is paid back (`AddMoney`); bets already in the hand stay there and any win is
  paid to the player afterwards. **Disconnect:** the chips wait in `grumpy_gambling_pending` for the next login.
- **Restart:** every stack row left behind is moved to pending; players online get it at once, others at login.
- **Ledger sign:** `amount_c` is the change in money held by the core (stacks + cashboxes): `buyin`/`topup` +,
  `cashout`/`pending`/`refund`/`recovered` -, `rake` - (destroyed), `mint` + (the house paid a dealer-game win),
  `sink` - (the house kept a loss), `npc_mint` + (an NPC's chips created when it sits), `npc_sink` - (an NPC's chips
  destroyed when it leaves, or its win after leaving; at dealer tables also an NPC's scenery win or loss, note
  `pvd scenery`), `rake_box`/`paid_pending` 0. With no hand open, the sum of the ledger equals the
  stacks plus cashboxes.
- **Business cashboxes** (`grumpy_gambling_cashboxes`): the box's rake share and (dealer tables) the house result are
  written in the hand's settle transaction (`grumpy_gambling_box_stats` keeps the totals for the owner). Deposits and
  withdrawals are conditional updates (never below zero; open hands' reserved cover can't be withdrawn). Ledger:
  `box_in` +, `box_out` -, `box_gov` - (repossessed clean box to the government account), `box_sink` - (repossessed
  dirty box destroyed), `box_seized` - (law seizure). The ledger still sums to stacks + boxes.
- **NPC money:** created when an NPC sits, destroyed when it leaves. At PVP the chips are real in the pot (players can
  win them, up to the cap). At PVD, NPC bets never reach the house: no rake, no cover, no house result.
- **NPC win cap:** each hand with NPCs adds rows to `grumpy_gambling_npc_window` inside the settle transaction: what
  the NPCs lost goes to the real winners in proportion (at most what each won); what they won comes off the real
  losers (at most what each lost). A player at or over the cap of the tier they're at gets no NPCs.
- **Rake tuner:** play stats are buffered and flushed every minute; once a day the tuner reads the last
  `WindowDays` and moves each rate toward the target (DESIGN.md §6.3).

## 8. Security model
- Admin actions require `Config.AdminPermission` on the server, plus cooldowns.
- Placement: `rsg-gizmo:IsPlacementValid` (player near the coords), heading wrapped, model must match the type,
  Micro tables limited and cash only.
- Calibration: the admin must be within 15 m; every chair and the dealer must be within 4 m of the table; nobody seated.
- Sitting: server checks the seat exists and is free, the table is open, the player isn't seated elsewhere or dead, and
  stands within `ServerSeatDistance` of the seat.
- Game/tier choice: only the setup player, only games registered for the table's type/model/seat count, only allowed
  tiers (fixed Micro, no Micro elsewhere, bloodmoney tables Low–High).
- Money only moves on the server, in the core. Buy-in amounts are re-checked against the tier range, the player's
  money (`RemoveMoney` must succeed) and an open hand. Modules can't touch money directly: `Settle` refuses rankings with
  unknown or repeated seats, payouts above stake × `maxPayout`, and any result where awards + rake don't equal the bets.
- Only the resource that registered the game can drive hands at its tables (`GetInvokingResource`).
- Only the game's own resource may push views, send table messages or stand seats for its tables.
- NPC profiles (personality, sharp flag) never leave the server; clients only get each NPC's model and outfit number.
  NPC exports answer only the table's game resource. Call-outs are checked like actions (seat, table, bloodmoney, hand
  in play) and blocked for `Sharp.CallOutCooldownSeconds` after a wrong one.
- Player actions reach the game only from a seated player at an active table running that game, at most 4 a second;
  the game decides whether the move is legal.
- Tested in real Lua 5.4 (`tests/`): 2,000 random side-pot hands; 3,000 random betting rounds; an integration run of
  600 poker + 400 dealer hands with buy-ins, top-ups, leavers, drops, a crash and a database failure; and the test
  games (a separate resource) playing 300 poker hands and 200 dealer rounds through the core with random legal
  moves, time-outs and players coming and going. Money conserved after every hand. Phase 5 adds the brain (every
  decision legal over 400 random betting rounds; personality and read checks; sharps keep the deck whole) and the NPC
  system end to end (seating rule, leaving only between hands, cap attribution and the window, scenery bets, regulars'
  memory, both call-out outcomes), conserved after every step and stable across seeds.

## 9. Database schema
```sql
grumpy_gambling_tables (id, label, kind, source, model, bound, x, y, z, h, currency, fixed_tier, business_id, owner_cid,
                        seats JSON, dealer JSON, settings JSON, enabled, created_by, created_at)
grumpy_gambling_models (model PK, data JSON, updated_by, updated_at)   -- model calibrations
```
`business_id`, `owner_cid` and `settings` are used by business tables.
Money tables (cents in `_c` columns): `grumpy_gambling_stacks` (one row per seated character), `grumpy_gambling_pending`
(owed, paid at login), `grumpy_gambling_hands` (settled hands), `grumpy_gambling_ledger`, `grumpy_gambling_cashboxes`
(business tables), `grumpy_gambling_rake_remainder`, `grumpy_gambling_rake_stats` (tuner input), `grumpy_gambling_rake_rates`
(tuner output). NPCs: `grumpy_gambling_npc_window (id, citizenid, ts, amount_c)` (purged after the window) and
`grumpy_gambling_regular_memory (regular_id, citizenid, hands, net_c, last_seen)` (saved as increments). Business:
`grumpy_gambling_box_stats (table_id, rake_c, house_c, hands)`, `grumpy_gambling_pending_items (citizenid, item,
amount)` (table items owed after an offline pack-up, given at login); tables use `business_id`, `owner_cid` and
`settings` (`npcs`, `tiers`, `orphaned` time, `outOfRange`).

## 10. Server owner how-tos
- **Add a table model:** add an entry to `Models` in `shared/models.lua` (verify the model in
  `data/rdr3_discoveries/objects/object_list.lua`). Set `spawn = true` to offer it in "Place new table"; leave it out
  for a map table that should only be bound. Restart, place or bind a table, calibrate.
- **Spawnable models (default):** PVP `p_tablepoker01x` with `p_windsorchair03x` chairs (the Smithfields table),
  PVD `p_blackjacktable01x`. Bind only: `p_pokertable01x`, `p_gen_tablepoker01x`, `p_blackjacktable02x`.
- **Map table not found by "bind":** stand next to it and try again; the F8 console lists model hashes of nearby objects.
  Add that model to `Models` if it's a card table.
- **Make a calibration permanent in code:** copy the snippet from the panel into the model's entry.
- **Move a map table's seats:** calibrate that table (bound tables keep their own calibration).
- **Give a business owner a table:** add the items to `rsg-core/shared/items.lua` (see README) with images
  `gambling_table_pvp.png` / `gambling_table_pvd.png` in rsg-inventory. Owners buy them from grumpy-pob's Gambling
  tab (`Config.Gambling.Prices` there); admins can also `/giveitem <id> gambling_table_pvp 1`.
- **A table of a lost business:** it shows "closed: its owner no longer runs the business". The placer can empty it
  and pack up; after `AbandonDays` the server does it. Deleting it from `/gambling` packs it up for its owner.
- **Add a regular:** add an entry to `Config.Npc.Regulars.List` (unique `id`, a model from
  `data/rdr3_discoveries/peds/peds_list.lua`, an `outfit` number, a persona, `home` coords + radius and/or
  `roams = true`, optional `tiers`). Regulars are only at one table at a time.
- **Turn NPCs off:** `Config.Npc.Enabled = false` (or per business table later via settings).
- **Check a player's NPC winnings:** `exports['grumpy-gambling']:GetNpcWindow(cid)` or
  `SELECT SUM(amount_c) FROM grumpy_gambling_npc_window WHERE citizenid = ? AND ts > UNIX_TIMESTAMP() - 5400`.

## 11. Troubleshooting
| Problem | Fix |
|---|---|
| Players float or sink when seated | Adjust the model's `sitZ` (or `Seating.FemaleZ` for women) |
| Map chairs pile up around a placed table | Add their model to `Config.HideMapChairs.Models` (or raise `Radius`); find the model with bind's F8 list |
| Doubled chairs at a placed table | The table model already includes chairs (like `p_blackjacktable01x`): set its `chair = nil` and a `ghostChair` for calibration |
| Dealer sits in mid-air | `Config.Dealer.IdleFlag` must be upper body (25); full body (1) plays the seated clip |
| Dealer's chair faces away from the table | `Config.Dealer.ChairYaw = 180.0` |
| Dealer's chair is in the table or too far back | Calibrate the model: the last ghost is the dealer's chair |
| Seats don't line up with a table's built-in chairs | Built-in chairs aren't separate objects, so they can't be found automatically: **Calibrate model default** once and place a ghost on each chair |
| Chairs face the wrong way | Set the model's `chairYaw` (e.g. 180), then recalibrate |
| Seats are in the wrong place | Calibrate the table or the model |
| "No games are installed" | No module of that table type is running; ensure modules after grumpy-gambling |
| Table skipped on start (console) | Its model has no profile in `shared/models.lua` |
| Chip stacks float or sit inside the table | Tune `Config.ChipStacks.Forward` / `Height`, or per model `chipForward` / `chipHeight` in `shared/models.lua` |
| Can't move a table | Map (bound) tables can't move; spawned tables need nobody seated |
| Table panel never takes the mouse | `Config.TableUI.AutoFocus`; a window (chips, picker) open takes priority; press G (Your turn) |
| "Only a business owner can set up a gambling table" | The player must be the grumpy-pob owner (staff can't) and grumpy-pob 1.2.0+ must be running |
| "The table must stand inside your business" | Use the item within `MaxDistanceFromNpc` (+5 m) of the business's clerk; the ghost must stay inside that range |
| Dealer table says the house can't cover bets | Put money in its cashbox (Manage table); each stake needs `PvdCoverMaxBets` × its max bet |
| No "Manage table" option | Only the placer sees it, from the middle of the table, while not seated |
| No NPCs sit down | `Config.Npc.Enabled`; the table needs a started game and a real player; a player at the NPC cap gets none (`GetNpcWindow`); one seat always stays free |
| NPCs look the same everywhere / invisible | Outfit numbers pick a preset per model; a model with no presets falls back to a random outfit |
| No tells | `Config.Npc.Tells.Chance` × the persona's `tells`, only when strength ≥ `Tells.Strong` or bluffing; High-tier NPCs and sharks show fewer by design. `Config.Debug` prints each cue in F8 |
| Seated players look frozen | `Config.Anim.Enabled`; the module must call `GGLib.Cue` for moves; check F8 for anim dict load failures |
| No "Call out cheat" option | Only at bloodmoney tables, only while seated at that table |
| No Chips window | The table hasn't started a game (no module installed). Dev: `Config.DevGames = true` |
| "Owed to you from the card tables" on login | Chips from a disconnect or restart being paid back: expected |
| How much has the rake removed? | `SELECT currency, -SUM(amount_c)/100 FROM grumpy_gambling_ledger WHERE kind = 'rake' GROUP BY currency` |
| What are the current rates? | `grumpy_gambling_rake_rates` (tuned), else `Config.Rake.Seed`; the console logs each change |
