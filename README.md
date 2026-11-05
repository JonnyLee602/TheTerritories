# The Territories: server copy

The latest RSG framework plus every Territories customization, kept in git so RSG updates can be pulled in
without losing our changes.

```
resources/[framework]/   68 rsg-* resources: RSG's latest code + our edits
resources/[grumpy]/      our own scripts (copied from rsg-redm-brain/builds)
tools/rsg-update.sh      pulls RSG updates and merges them in
upstream.lock            which RSG commit each resource is on
```

## How updates work

There are two branches:

| Branch | Holds |
|---|---|
| `upstream` | RSG's code, exactly as Rexshack released it. Never edit it by hand. |
| `main` | `upstream` + our customizations. This is what the server runs. |

`tools/rsg-update.sh` refreshes `upstream` from GitHub, then merges it into `main`. Git compares both sides
against the version they share. Lines only RSG changed come from RSG; lines only we changed stay ours.
Lines both sides changed are reported as **conflicts** and get resolved by hand.

Run it from Git Bash (or ask Claude to "update the server"):

```bash
bash tools/rsg-update.sh            # every resource
bash tools/rsg-update.sh rsg-core   # just one
```

The commit message on `upstream` lists what RSG changed in each resource. To undo an update that broke something:
`git reset --hard HEAD~1` on `main` (ask Claude first if unsure).

## Our customizations to RSG resources

| Resource | Change | Why |
|---|---|---|
| rsg-core | `shared/items.lua`: `cooked_poultry`, `cooked_game_meat`, `hardtack`, `blank_paper`, `custom_note`, `raw_game_meat`, `raw_poultry`, `raw_stringy_meat` | Custom items |
| rsg-hunting | `Config.Animals`: Territories drops (meat by animal type) + 3 legendaries using RSG's `legendary_*` items | Hunting economy |
| rsg-inventory | ~56 custom images in `html/images` (seeds, meats, custom items, `legendary_pelt.png`) | Item icons |
| rsg-doorlock | `shared/doorhashes_custom.lua`: 2 custom doors | New doors |
| rsg-lottery | Ticket-seller NPCs commented out, blip off; `OpenLottery` export | grumpy-bartender sells tickets |
| rsg-loyalty | Loyalty NPCs commented out; `SetRedeemPoint` / `RemoveRedeemPoint` exports | grumpy-bartender serves loyalty |
| rsg-stores | Access points, `OpenShop`, `CreateShop` / `ShopExists` / `DeleteShop`, `'none'` model | grumpy-bartender + grumpy-pob shops |
| rsg-stores | `blockJob`, `externalSale` event, `IsReady`, `SetShopData`, image URLs | grumpy-pob business shops |
| rsg-stores | Honor/infamy buy and sell multipliers, sell-back arbitrage cap | grumpy-reputation |
| rsg-consume | `RegisterAlias` export, alias refunds | grumpy-pob custom food/drink |
| rsg-core | `SaveJobDefinition` / `DeleteJobDefinition` exports (`server/multijob/server.lua`) | grumpy-pob business jobs |
| rsg-inventory | Core refresh on new items, `stashClosed` event, image URLs | grumpy-pob custom items, stock box |
| rsg-stables | Registered + job-only stables, per-stable caps, `capExempt`, `MoveHorses`, training exports, `OpenStable` | grumpy-pob stable businesses |

Every edit made for a grumpy script is marked `[grumpy-bartender hook]`, `[grumpy-pob hook]` or
`[grumpy-reputation hook]` in the code. The original patch instructions live in each script's `integrations/` folder.

**rsg-multijob is gone on purpose.** Since 2026-10-31 it's built into rsg-core, which `provide`s it. RSG says the
old resource must not run; its database tables are reused as they are. Remove any `ensure rsg-multijob` from server.cfg.

## Adding a new customization

Edit the file on `main`, then commit it. That's all: the next update keeps it automatically.

## Fresh install with txAdmin (`recipe/`)

`recipe/territories.yaml` builds a complete server from this repository:

| Step | What it does |
|---|---|
| Download | This repo (`main`), plus the same standalone/community/map resources RSG's recipe uses |
| `server.cfg` | `recipe/server.cfg`: RSG's server.cfg + `ensure [grumpy]` |
| Database | `recipe/rsg/rsgcore.sql` (all RSG tables), then `recipe/territories_stores.sql` (our NPC shops), then each grumpy `install.sql` |
| Resources | `resources/[framework]` (86, pinned) and `resources/[grumpy]` copied as they are in this repo |

In txAdmin: **Setup → Custom Template / Remote URL**, and use
`https://raw.githubusercontent.com/JonnyLee602/TheTerritories/main/recipe/territories.yaml`.
The recipe downloads the repo's `main` branch at deploy time, so push before deploying.

`recipe/territories_stores.sql` comes from the 2026-11-05 rsg-stores export. Its header lists what was cleaned
(dropped test shops, remapped item names). To refresh it from a newer export, ask Claude to rebuild it.
`recipe/rsg/` is RSG's recipe SQL + logo, kept in step by `tools/rsg-update.sh` like any RSG resource.

To check the database steps against a local MariaDB without deploying (asks for your password):

```bash
bash tools/test-recipe-sql.sh
```

## Not in this copy

oxmysql, ox_lib, PolyZone and the other standalone, community and map resources: the recipe downloads them.
The live database, player data and txAdmin settings.
