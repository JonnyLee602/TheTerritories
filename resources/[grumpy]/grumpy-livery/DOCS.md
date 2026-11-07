# grumpy-livery · Documentation

Developer and server-owner reference for **1.1.0** (phase 1: rsg-stables 3.4.0 + rsg-wagons 3.0.0 merged; phase 2:
pricing, papers, Thieves Landing). The plan for later versions is [DESIGN.md](DESIGN.md).

## Contents
1. [Files](#1-files)
2. [How the merge is put together](#2-how-the-merge-is-put-together)
3. [Renamed names (old → new)](#3-renamed-names-old--new)
4. [Exports](#4-exports)
5. [Events and callbacks](#5-events-and-callbacks)
6. [NUI](#6-nui)
7. [Database](#7-database)
8. [Integrations](#8-integrations)
9. [Security model](#9-security-model)
10. [Troubleshooting](#10-troubleshooting)

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | One resource, one `ui_page` |
| `shared/config.lua` | Horse config (creates the global `Config`; loaded first) |
| `shared/wagons.lua` | Wagon config (`Config = Config or {}`, so it adds to the horse config) |
| `shared/liveries.lua`, `shared/propsets.lua`, `shared/huntingcart.lua` | Wagon liveries/tints, cargo and lantern sets, hunting cart |
| `server/money.lua` | `LiveryMoney`: market, standing multiplier, account choice, ×1.30 blood money, sale cap, charge/refund/payout (loaded first) |
| `server/server.lua` | Horses: stables, buying, storing, tack, coat, needs, breeding, selling, fence, races, wild horse claim, registered stables (grumpy-pob), auto DB |
| `server/training.lua` | Horse training (ride XP + paid sessions) and the training exports grumpy-pob uses |
| `server/wagons.lua` | Wagons: yards, buying, storing, call/flee, storage, repairs, customise, hunting cart, auto DB |
| `server/migrate.lua` | One-time copy from the rsg-stables / rsg-wagons tables (§7) |
| `client/client.lua` | Horses: stable NPCs, menus, active horse, targets, whistle, needs, items |
| `client/{actions,coat,dataview,fence,horseinfo,races,salvage,spook,training,wildhorse}.lua` | Horse features, as in rsg-stables |
| `client/wagons.lua` | Wagons: yard NPCs, catalogue, preview, wagon targets, call/flee/store |
| `html/index.html` | One page: horse UI in `#st-root`, wagon UI in `#wg-root` |
| `html/style.css` | Horse UI styles, scoped under `#st-root` (theme variables and page globals live here) |
| `html/wagons.css` | Wagon UI styles, scoped under `#wg-root`, ids prefixed `wg-` |
| `html/{app,horsecard,training,actions}.js` | Horse UI |
| `html/papers.js` | Papers card (no focus, hides itself) |
| `html/wagons.js`, `html/wagons-drag.js` | Wagon UI, draggable wagon panels |
| `install.sql` / `migrate.sql` | Manual table setup / manual migration |
| `locales/*.json` | Horse and wagon strings in one file per language |

## 2. How the merge is put together
Phase 1 keeps both code bases intact and only removes the clashes:
- **Lua:** horses and wagons run in the same resource but share no locals. The only config key both used,
  `StoreDistance`, is now `Config.WagonStoreDistance` for wagons. No global function names clash.
- **NUI:** both UIs live on one page. Clashes and how they were removed:
  - Element ids (`app`, `closeBtn`, `backBtn`, `inputModal`, …): wagon ids are prefixed `wg-`. The wagon JS's `$()`
    helper adds the prefix, so its code is unchanged.
  - CSS classes (`.panel`, `.tab`, `.hidden`, …): each stylesheet is scoped to its root (`#st-root`, `#wg-root`).
  - NUI callbacks (`close`, `rotateCam`, `zoomCam`): every wagon callback is prefixed `wagon_` (the wagon JS `post()`
    adds it).
  - NUI messages (`open`, `close`, `custom`, `closeCustom`): wagon messages are `wagonOpen`, `wagonClose`,
    `wagonCustom`, `wagonCloseCustom`.
  - Document-wide queries: the horse UI's translations and the wagon UI's tab/i18n/camera queries only search their
    own root; the horse UI's A/D camera keys are ignored while its panel is hidden.
- **Locales:** merged; where a language had different text for the same shared key (`ui_back`, `ui_cancel`,
  `ui_confirm`) the horse text wins.
- Stash names (`horse_<id>`, `wagon_<id>`) and state bags (`rsgStablesOwned`, `rsgWagonId`, `rsgWagonLook`) are
  **unchanged**, so saddlebag/wagon contents and grumpy-wagonloot keep working.

## 2b. Money and papers (1.1.0)
**Every livery charge** goes through `LiveryMoney.Charge(src, livery, base, reason)` (`livery` = a `Config.Stables`
entry or `Config.Stores` yard):
`price = base × GetPriceMultiplier(src, market, 'buy') × (1.30 if the account is bloodmoney)`, rounded to cents.
The account is the player's choice (`grumpy-livery:server:setPayment`, validated against the livery's `accounts`)
or the livery's first account. Refunds go back to the same account (`LiveryMoney.Refund`).

**Every livery sale** (horse sale, wagon trade-in): `LiveryMoney.SellPrice(src, livery, base, listPrice)` =
`base × GetPriceMultiplier(src, market, 'sell')`, capped at `listPrice × buy multiplier × Config.Money.sellCap`
(training value on horses is added after the cap). Paid with `LiveryMoney.Pay` into the livery's `payout` account
(cash when legal, blood money when underground). Without grumpy-reputation every multiplier is 1.0.

Not repriced: player-to-player sales and gift fees (`chargeFlat`, cash), race entry fees and prizes, field repairs,
hunting-cart sales (rsg-hunting prices), paid training sessions (removed in phase 4). The horse fence keeps its own
payout and grumpy-reputation's sale hook (`grumpy-livery-horse-fence`) until phase 3.

The client asks `grumpy-livery:server:priceInfo(kind, key)` (`kind` `'horse'` / `'wagon'`) when a menu opens and
scales displayed prices with `mult`; the server always recalculates.

**Papers** (`grumpy_livery_horses.papers`): `'genuine'` | `'forged'` | `'none'`, plus `papers_stable` (place of
registration; forged papers name a random legal stable) and `papers_owner` (character name, updated on gifts).
| Event | Papers |
|---|---|
| Bought at a legal stable | genuine |
| Bought underground, `withPapers = true` | forged (+`Config.Papers.forgedPercent` of the price) |
| Bought underground, no papers | none |
| Wild horse claimed at a legal stable | genuine ($0.50 registration) |
| Wild horse claimed underground | none (no fee) |
| Foal, both parents papered, legal stable | genuine |
| Foal otherwise | none |

Legal stables refuse to buy (`sellQuote`) a horse with `papers = 'none'`.
`grumpy-livery:server:showPapers(horseId, netId?)` checks the owner is next to the horse (active) or at its stable
(stabled), then sends `grumpy-livery:client:papersCard` to them and every player within `Config.Papers.showRadius`.

**Thieves Landing:** `Config.Stables` entry `thieves_landing` (`market = 'underground'`, `accounts = cash + bloodmoney`,
`blip = false`, `spawnCoords`, `wagonStore = 'thieves_landing'`) and `Config.Stores.thieves_landing` (`sharedNpc`,
`spawn`, same market/accounts). The keeper is the stable's NPC; its **Browse Wagons** option calls the global
`LiveryOpenWagonShop(key)` from `client/wagons.lua`. Blood money paid out there (sales) counts for grumpy-reputation's
`blood_money` action like any other blood money.

## 3. Renamed names (old → new)
| Old | New |
|---|---|
| `rsg-stables:client:*`, `rsg-stables:server:*` | `grumpy-livery:client:*`, `grumpy-livery:server:*` |
| `rsg-wagons:client:*`, `rsg-wagons:server:*` | `grumpy-livery:wagons:client:*`, `grumpy-livery:wagons:server:*` |
| `exports['rsg-stables']:X` / `exports['rsg-wagons']:X` | `exports['grumpy-livery']:X` (same function names) |
| `rsg_stables_horses`, `rsg_stables_breeding`, `rsg_stables_races`, `player_wagons` | `grumpy_livery_horses`, `grumpy_livery_breeding`, `grumpy_livery_races`, `grumpy_livery_wagons` |
| Money reasons `rsg-stables-*` (e.g. `rsg-stables-horse-fence`) | `grumpy-livery-*` (e.g. `grumpy-livery-horse-fence`) |
| Money reasons `rsg-wagons …` | `grumpy-livery wagons …` |
| rsg-target option names `rsg_stables_*` / `rsg_wagons_*` | `livery_*` / `livery_wagon_*` |
| Wagon `Config.StoreDistance` | `Config.WagonStoreDistance` |
| Wagon NUI localStorage key `rsg-wagons:pos:` | `grumpy-livery:wagons:pos:` (panel positions reset once) |

## 4. Exports
**Server**
| Export | Returns | Used by |
|---|---|---|
| `RegisterStable(def)` | `true`/`false` | grumpy-pob. `def = { name, label, pedCoords, storeCoords?, previewCoords?, restrictJob?, maxHorses?, capExempt? }` |
| `RemoveStable(name)` | — | grumpy-pob |
| `MoveHorses(fromStable, citizenid?, toStable)` | rows moved | grumpy-pob (fired staff, deleted business) |
| `GetActiveHorse(citizenid)` | horse row or nil | grumpy-pob |
| `CanTrainHorse(horseId, stat)` | bool, reason | grumpy-pob |
| `TrainHorse(horseId, stat, xp)` | result | grumpy-pob |
| `GetActiveWagon(src)` | `{ id, netId, model }` or nil | — |
| `GetPlayerWagons(citizenid)` | list of wagon rows | — |

**Client**
| Export | Purpose |
|---|---|
| `OpenStable(name)` | Opens a (registered) stable's menu; the server still checks job and distance. Used by grumpy-pob |
| `GetHorseBonusInfo()` | Tack and training bonus ranks of the active horse |

```lua
local active = exports['grumpy-livery']:GetActiveWagon(source)
local wagons = exports['grumpy-livery']:GetPlayerWagons(Player.PlayerData.citizenid)
```

## 5. Events and callbacks
All callbacks are rsg-core server callbacks (`RSGCore.Functions.CreateCallback`).

**Horse net events (server):** `openDeadHorseInventory`, `openFieldSaddlebags`, `openHorseInventory`,
`requestExternalStables`, `saveHorsePosition`, `trainingRideTick`, `wildHorseBroken` (prefix `grumpy-livery:server:`).

**Horse net events (client):** `externalStables`, `fieldCorpse`, `horseDiedOfAge`, `raceRoute`, `trainingUpdate`,
`useBrush`, `useFeed`, `useLantern`, `useMedicine`, `useReviver`, `useStimulant` (prefix `grumpy-livery:client:`).
Local client events: `horseSpawned`, `openTraining`, `tackChanged`.

**Money / papers (1.1.0):** server event `grumpy-livery:server:setPayment(kind, key, account)`; callbacks
`grumpy-livery:server:priceInfo(kind, key)`, `grumpy-livery:server:showPapers(horseId, netId?)`; client event
`grumpy-livery:client:papersCard(card)`. `buyHorse` takes a 7th argument, `withPapers`.

**Horse callbacks** (prefix `grumpy-livery:server:`): `abortRace`, `applyHorseCoat`, `applyHorseTack`, `brushHorse`,
`buyHorse`, `claimWildHorse`, `collectFoal`, `feedHorse`, `fenceHorse`, `finishTraining`, `fleeStoreHorse`,
`getBreedingJobs`, `getHorseshoeCondition`, `getNearbyPlayers`, `getRaces`, `getSellPrice`, `getStableHorses`,
`getTraining`, `giveHorse`, `horseDied`, `horseDown`, `insureHorse`, `naturalDrink`, `naturalGraze`,
`raceCheckpoint`, `releaseHorse`, `renameHorse`, `restoreActiveHorse`, `retrieveHorse`, `reviveDownedHorse`,
`reviveHorse`, `sellHorse`, `startBreeding`, `startRace`, `startTraining`, `storeHorse`, `toggleLantern`,
`transferHorse`, `useMedicine`, `useStimulant`, `waterHorse`, `wearHorseshoe`.

**Wagon net events:** server `condition`, `openStorage`, `registerSpawned`, `restore`, `spawnFailed`; client
`restore` (prefix `grumpy-livery:wagons:server:` / `grumpy-livery:wagons:client:`).

**Wagon callbacks** (prefix `grumpy-livery:wagons:server:`): `buy`, `callWagon`, `fieldRepair`, `fleeWagon`,
`getOwned`, `rename`, `sell`, `sellCargo`, `setLook`, `store`, `storeNearest`, `stowCarcass`, `takeOut`, `yardRepair`.

## 6. NUI
**Horse UI** (unchanged from rsg-stables): messages `render`, `tackPicker`, `coatPicker`, `inputDialog`,
`alertDialog`, `statsDialog`, `hide`, `setLocale`, plus the horse card, training and actions panel messages.
Callbacks: `actionsClose`, `actionsSelect`, `alertClose`, `close`, `coatAction`, `coatUpdate`, `horseCardAction`,
`horseCardClose`, `inputCancel`, `inputSubmit`, `rotateCam`, `select`, `statsClose`, `tackCategoryNav`,
`tackCycle`, `trainingClose`, `trainingFinish`, `trainingStart`, `zoomCam`.

**Wagon UI:** messages `wagonOpen` (now with `payment = { account, accounts }`), `wagonPayment` (repriced list after a
switch), `wagonClose`, `wagonCustom`, `wagonCloseCustom`. Callbacks (all prefixed `wagon_`): `close`, `preview`,
`previewLivery`, `clearPreview`, `rotateCam`, `zoomCam`, `buy`, `yardRepair`, `rename`, `sell`, `store`, `takeOut`,
`customPreview`, `customSave`, `customClose`, `setPayment`.

**Papers card:** message `papersCard` (`card`, `seconds`, `strings`), handled by `html/papers.js`.

## 7. Database
Created on start (horses always; wagons when `Config.AutoDatabase = true`). Schema: `install.sql`.

| Table | Key | Notes |
|---|---|---|
| `grumpy_livery_horses` | `id` | One row per horse: stable, model, gender, tack/coat JSON, needs, bonding, training JSON, aging flags, saved position, papers (`papers`, `papers_stable`, `papers_owner`; added on start for older tables, existing horses = genuine) |
| `grumpy_livery_breeding` | `id` | Pending/collected foals (`parent_a`, `parent_b`, `ready_at`) |
| `grumpy_livery_races` | `citizenid, race` | Best race time per character |
| `grumpy_livery_wagons` | `id` | One row per wagon: model, name, condition, yard, livery/tint, propset/lantern, cargo |

**Migration:** `server/migrate.lua` waits for the four tables, then for each old → new pair copies the rows
(`INSERT … SELECT` over the columns both tables have, ids kept) **only if the new table is empty and the old table
exists**. It never writes to the old tables and never runs twice. Console: `[grumpy-livery] migrated N rows from … to …`.

Deleting a character: rsg-core's `playertables` list includes the four tables (`[grumpy-livery hook]` in
`rsg-core/server/player.lua`).

## 8. Integrations
| Resource | What changed for it |
|---|---|
| grumpy-pob 1.3.1 | Calls `exports['grumpy-livery']` (`STABLES` in `server/stable.lua`, `OpenStable` in `client/interact.lua`). Its old `integrations/rsg-stables.md` patch is built in and was removed |
| grumpy-reputation 1.1.1 | Payout reason `grumpy-livery-horse-fence` (action `horse_fence`, underground market) |
| grumpy-wagonloot | No change: still reads the `rsgWagonId` state bag |
| rsg-radialmenu | Lantern entry triggers `grumpy-livery:client:useLantern` (`[grumpy-livery hook]`) |
| rsg-core | `playertables` (above) |

## 9. Security model
Unchanged from the originals: every purchase, sale, claim, training, breeding and wagon action is decided on the
server (prices from server config, distance checks to the NPC and to server-side entity coords, per-player action
cooldowns, ownership checks against the database). Wild horse claims use the server's own record of who broke which
horse. NUI callbacks only forward requests; the server re-validates.

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| Two stablehands / horses whistle twice | rsg-stables or rsg-wagons is still running: stop and remove them |
| Horses or wagons missing after the switch | Check the console for `migrated … rows`. The copy only runs when the new tables are empty; if they already had rows, run `migrate.sql` lines by hand for what's missing |
| grumpy-pob "Open stable" does nothing | grumpy-pob must be 1.3.1+ and grumpy-livery started before it |
| Lantern radial entry does nothing | Apply the rsg-radialmenu hook (§8) |
| Wagon panels open in the default spot once | Expected: the saved-position key changed (§3) |
