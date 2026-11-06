# grumpy-gambling

The gambling core for The Territories: card tables, seating, stake tiers and (in later phases) stacks, rake, NPC players
and business tables, shared by small **game modules** (blackjack, poker, faro, …) that only define rules and odds.

Version 0.1.0 (**phase 1 of 7: foundation**) · for RSG Framework (rsg-core 3.0.3) · see [DOCS.md](DOCS.md) for
developers and [DESIGN.md](DESIGN.md) for the full design.

This is a community script. It is **not** made or supported by the RSG authors.

**Dependencies:** `rsg-core`, `rsg-target`, `rsg-gizmo`, `oxmysql`

> **Phase 1 status.** Tables can be placed, calibrated, sat at and stood up from, and the first player picks a game
> and tier. **No money moves yet** and no games exist yet (modules come after the core). Until a module is installed,
> the picker says no games are available.

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

**Players:** walk up to a seat → **Sit down**. The first player picks the game and stakes. Hold **R** to stand up;
press **G** to reopen the game picker.

## Developer example
```lua
-- a module (server) registers its game on start
exports['grumpy-gambling']:RegisterGame({
    id = 'blackjack', label = 'Blackjack', kind = 'pvd',
    minSeats = 1, maxSeats = 4, models = { 'p_blackjacktable01x', 'p_blackjacktable02x' },
    dealer = true, houseEdge = 0.005, maxPayout = 2.5,
})

AddEventHandler('grumpy-gambling:server:tableStarted', function(tableId, gameId, tier, currency)
    if gameId ~= 'blackjack' then return end
    -- set up the table's state (the hand API arrives in phase 3)
end)
```

## Locales
English (`locales/en.json`). Every player-facing string, including the NUI (`ui_*` keys) and tier names, is in the
locale file. Add a language by copying `en.json` and setting `setr rsg:locale "<lang>"`.
