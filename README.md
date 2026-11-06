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
| rsg-hunting | `Config.Animals`: Territories drops (meat by animal type) (legendaries left to rsg-legendary); `server/butcher.lua`: butcher gives the same raw_* meat as skinning (from `Config.Animals`) | Hunting economy |
| rsg-inventory | ~56 custom images in `html/images` (seeds, meats, custom items, `legendary_pelt.png`) | Item icons |
| rsg-doorlock | `shared/doorhashes_custom.lua`: 2 custom doors | New doors |
| rsg-lottery | Ticket-seller NPCs commented out, blip off; `OpenLottery` export | grumpy-bartender sells tickets |
| rsg-loyalty | Loyalty NPCs commented out; `SetRedeemPoint` / `RemoveRedeemPoint` exports | grumpy-bartender serves loyalty |
| rsg-stores | Access points, `OpenShop`, `CreateShop` / `ShopExists` / `DeleteShop`, `'none'` model | grumpy-bartender + grumpy-pob shops |
| rsg-stores | `blockJob`, `externalSale` event, `IsReady`, `SetShopData`, image URLs | grumpy-pob business shops |
| rsg-stores | Honor/infamy buy and sell multipliers, sell-back arbitrage cap | grumpy-reputation |
| rsg-stores | Shop templates: `rsg_shops_templates` / `rsg_shops_template_items` + `template_name` column, `Config.ShopTemplates` seed, Templates tab, template picker and Push to Shops in `/createshop` (marked `[grumpy shop templates]`) | Default item lists for NPC shops; one push updates every shop of a type |
| rsg-consume | `RegisterAlias` export, alias refunds | grumpy-pob custom food/drink |
| rsg-core | `SaveJobDefinition` / `DeleteJobDefinition` exports (`server/multijob/server.lua`) | grumpy-pob business jobs |
| rsg-inventory | Core refresh on new items, `stashClosed` event, image URLs | grumpy-pob custom items, stock box |
| rsg-stables | Registered + job-only stables, per-stable caps, `capExempt`, `MoveHorses`, training exports, `OpenStable` | grumpy-pob stable businesses |
| rsg-target | `Config.Highlight.Radius` 10.0 → 1.0 | Eye markers only show for targets right next to you |
| rsg-zonenotify | `Config.Sound.Enabled` true → false (`shared/config.lua`) | Zone notifications are silent |

Every edit made for a grumpy script is marked `[grumpy-bartender hook]`, `[grumpy-pob hook]` or
`[grumpy-reputation hook]` in the code. The original patch instructions live in each script's `integrations/` folder.

**Removed on purpose** (dropped from the `upstream` branch too, so updates don't bring them back):

| Resource | Why |
|---|---|
| rsg-multijob | Built into rsg-core since 2026-10-31 (rsg-core `provide`s it). Its tables are reused as they are. |
| rsg-gangmenu | Replaced by grumpy-groups (which `provide`s rsg-gangmenu; same stash ids and gang funds). |
| rsg-trader | Replaced by grumpy-trader (imports rsg-trader data on its first start). |
| rsg-loading | Replaced by grumpy-loading (The Territories Gazette newspaper loading screen). |

## Adding a new customization

Edit the file on `main`, then commit it. That's all: the next update keeps it automatically.

## Fresh install with txAdmin (`recipe/`)

`recipe/territories.yaml` builds a complete server, one resource per step like RSG's own recipe
(with a 10-second pause every 10 downloads so GitHub doesn't throttle):

| Step | What it does |
|---|---|
| Base | `recipe/` from this repo: `server.cfg` (RSG's + `ensure [grumpy]`), logo, SQL |
| Database | `recipe/rsg/rsgcore.sql` (all RSG tables), `recipe/territories_stores.sql` (our NPC shops), `recipe/grumpy/*.sql` |
| Standalone | cfx-server-data, oxmysql, ox_lib, PolyZone and the rest, same sources as RSG's recipe |
| Framework | 83 resources: stock ones straight from Rexshack-RedM **pinned to the commit in `upstream.lock`**, customized ones from this repo |
| Grumpy | each `resources/[grumpy]/*` script from this repo |
| Extras | Nt_Blackjack, Nt_Holdem, rsg-mapping, redm-ymaps (as RSG's recipe) |

**The recipe is generated:** `python tools/build-recipe.py` (don't edit the YAML by hand). `tools/rsg-update.sh` runs it
after every update. After a hand-made customization, run it yourself so that resource switches to "from this repo".
`recipe/grumpy/` holds generated copies of each grumpy `install.sql`.

In txAdmin: **Setup → Remote URL Template**, and use
`https://raw.githubusercontent.com/JonnyLee602/TheTerritories/main/recipe/territories.yaml`.
The recipe reads this repo's `main` branch at deploy time, so push before deploying.

`recipe/territories_stores.sql` comes from the 2026-11-05 rsg-stores export. Its header lists what was cleaned
(dropped test shops, remapped item names) and the general store repricing to `doctrine/pricing.md`.
Re-running it resets every NPC shop to this list, so it is how the new prices reach a server that is
already running. To refresh it from a newer export, ask Claude to rebuild it.
`recipe/rsg/` is RSG's recipe SQL + logo, kept in step by `tools/rsg-update.sh` like any RSG resource.

To check the database steps against a local MariaDB without deploying (asks for your password):

```bash
bash tools/test-recipe-sql.sh
```

## Not in this copy

oxmysql, ox_lib, PolyZone and the other standalone, community and map resources: the recipe downloads them.
The live database, player data and txAdmin settings.
