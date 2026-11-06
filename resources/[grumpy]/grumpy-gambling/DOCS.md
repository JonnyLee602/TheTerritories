# grumpy-gambling — developer docs

Version 0.2.0, phases 1–2 (foundation, money). The full design, including later phases, is in [DESIGN.md](DESIGN.md).

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
| `server/house.lua` | Who pays dealer-game wins: the server (public/Micro) or a cashbox (business, phase 6) and its cover check |
| `server/hands.lua` | The hand API: `BeginHand`, `Bet`, `Return`, `SetRakeable`, `Settle`, `CancelHand`, `GetHand`, `GetSeats` |
| `server/wallet.lua` | Buy-in / top-up, cash-out, payouts owed to offline players, restart recovery, Chips window |
| `server/seats.lua` | Sit / stand (cashing out), one seat per player, setup choice, disconnects, sync callback |
| `server/admin.lua` | `/gambling`: create, bind, move, rename, toggle, delete, teleport, calibrate |
| `client/main.lua` | `GGC` namespace, table sync, NUI bridge |
| `client/world.lua` | Distance-gated spawning of tables, chairs, dealers; seat targets; blips |
| `client/seat.lua` | Seated scenario, stand / choose-game / chips prompts, picker and chips callbacks |
| `client/admin.lua` | Admin panel, rsg-gizmo placement/move, map table binding, calibration flow |
| `html/*` | NUI: admin panel, game/tier picker and Chips window (house style) |
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

No client exports.

## 4. Events for modules and other resources (server, local `AddEventHandler`)
| Event | Args | When |
|---|---|---|
| `grumpy-gambling:server:ready` | — | Tables loaded |
| `grumpy-gambling:server:tableStarted` | `tableId, gameId, tier, currency` | The first player picked game and tier |
| `grumpy-gambling:server:seatTaken` | `tableId, gameId, seat, src` | A player sat at an active table |
| `grumpy-gambling:server:seatLeft` | `tableId, gameId, seat, src` | A player left an active table |
| `grumpy-gambling:server:tableStopping` | `tableId, gameId, reason` | The last real player left (reason `empty`); an open hand is cancelled |
| `grumpy-gambling:server:stackChanged` | `tableId, seat, src, cents` | A player bought in or topped up |

Phase 3 adds the hand API and wraps these in the module library (DESIGN.md §11).

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
  `sink` - (the house kept a loss), `rake_box`/`paid_pending` 0. With no hand open, the sum of the ledger equals the
  stacks plus cashboxes.
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
- Tested in real Lua 5.4: 2,000 random side-pot hands, and an integration run of 600 poker + 400 dealer hands with
  buy-ins, top-ups, leavers, drops, a crash and a database failure: money conserved after every step.

## 9. Database schema
```sql
grumpy_gambling_tables (id, label, kind, source, model, bound, x, y, z, h, currency, fixed_tier, business_id, owner_cid,
                        seats JSON, dealer JSON, settings JSON, enabled, created_by, created_at)
grumpy_gambling_models (model PK, data JSON, updated_by, updated_at)   -- model calibrations
```
`business_id`, `owner_cid` and `settings` are reserved for business tables (phase 6).
Money tables (cents in `_c` columns): `grumpy_gambling_stacks` (one row per seated character), `grumpy_gambling_pending`
(owed, paid at login), `grumpy_gambling_hands` (settled hands), `grumpy_gambling_ledger`, `grumpy_gambling_cashboxes`
(phase 6), `grumpy_gambling_rake_remainder`, `grumpy_gambling_rake_stats` (tuner input), `grumpy_gambling_rake_rates`
(tuner output).

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
| No Chips window | The table hasn't started a game (no module installed). Dev: `Config.DevGames = true` |
| "Owed to you from the card tables" on login | Chips from a disconnect or restart being paid back: expected |
| How much has the rake removed? | `SELECT currency, -SUM(amount_c)/100 FROM grumpy_gambling_ledger WHERE kind = 'rake' GROUP BY currency` |
| What are the current rates? | `grumpy_gambling_rake_rates` (tuned), else `Config.Rake.Seed`; the console logs each change |
